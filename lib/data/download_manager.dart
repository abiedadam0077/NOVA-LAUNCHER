import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/models.dart';
import 'http.dart';

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.destPath,
    this.sha1,
    this.expectedSize = 0,
  });

  final String id;
  final String url;
  final String destPath;
  final String? sha1;
  final int expectedSize;
}

/// Real, resumable, hash-verified download engine.
/// No fake progress: bytes are counted from the network stream.
class DownloadManager {
  DownloadManager({required this.http, this.concurrency = 4});

  final NovaHttp http;
  final int concurrency;

  final StreamController<DownloadProgress> _ctrl =
      StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progress => _ctrl.stream;

  final Map<String, _TaskHandle> _handles = {};
  final List<DownloadTask> _queue = [];
  int _running = 0;
  bool _closed = false;

  /// Schedules tasks and resolves when every task is done/failed/cancelled.
  /// Returns a map taskId -> success.
  Future<Map<String, bool>> runAll(List<DownloadTask> tasks) async {
    final results = <String, bool>{};
    final completer = Completer<void>();
    int pending = tasks.length;
    if (pending == 0) return results;

    void oneDone(String id, bool ok) {
      results[id] = ok;
      pending--;
      if (pending == 0 && !completer.isCompleted) completer.complete();
    }

    _queue.addAll(tasks);
    _pump();

    final subs = _ctrl.stream.listen((p) {
      final h = _handles[p.taskId];
      if (h == null) return;
      switch (p.state) {
        case DownloadTaskState.done:
          h.finish(true);
          oneDone(p.taskId, true);
          break;
        case DownloadTaskState.failed:
          h.finish(false);
          oneDone(p.taskId, false);
          break;
        case DownloadTaskState.cancelled:
          h.finish(false);
          oneDone(p.taskId, false);
          break;
        default:
          break;
      }
    });

    await completer.future;
    await subs.cancel();
    return results;
  }

  void _pump() {
    while (_running < concurrency && _queue.isNotEmpty && !_closed) {
      final t = _queue.removeAt(0);
      _running++;
      _runTask(t).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  void cancel(String taskId) {
    _handles[taskId]?.cancel();
  }

  void close() {
    _closed = true;
    for (final h in _handles.values) {
      h.cancel();
    }
    _ctrl.close();
  }

  Future<void> _runTask(DownloadTask task) async {
    final handle = _TaskHandle();
    _handles[task.id] = handle;

    _emit(task.id, 0, task.expectedSize, 0, DownloadTaskState.queued);

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (handle.cancelled) {
        _emit(task.id, 0, task.expectedSize, 0, DownloadTaskState.cancelled);
        return;
      }
      try {
        final file = File(task.destPath);
        await file.parent.create(recursive: true);

        int existing = 0;
        if (file.existsSync()) existing = file.lengthSync();
        bool resuming = false;
        if (task.expectedSize > 0 && existing > 0 && existing < task.expectedSize) {
          resuming = true;
        } else if (task.expectedSize > 0 && existing == task.expectedSize) {
          // Already fully present; still verify below.
        } else if (existing > 0) {
          await file.delete();
          existing = 0;
        }

        final bool needFetch = !(task.expectedSize > 0 && existing == task.expectedSize);
        int done = existing;

        if (needFetch) {
          final res = await http.openStream(
            task.url,
            fromByte: resuming ? existing : null,
          );
          final isPartial = res.statusCode == 206;
          if (res.statusCode != 200 && !isPartial) {
            throw DownloadHttpException(res.statusCode);
          }
          if (!isPartial && resuming) {
            // Server ignored Range: start over.
            done = 0;
          }
          final total = res.contentLength != null && res.contentLength! > 0
              ? (isPartial ? done + res.contentLength! : res.contentLength!)
              : task.expectedSize;

          final mode = (isPartial && done > 0) ? FileMode.append : FileMode.write;
          final sink = file.openWrite(mode: mode);
          final stopwatch = Stopwatch()..start();
          int windowBytes = 0;
          DateTime windowStart = DateTime.now();

          await for (final chunk in res.stream) {
            if (handle.cancelled) {
              await sink.close();
              _emit(task.id, done, total, 0, DownloadTaskState.cancelled);
              return;
            }
            sink.add(chunk);
            done += chunk.length;
            windowBytes += chunk.length;
            final now = DateTime.now();
            double speed = 0;
            if (now.difference(windowStart).inMilliseconds > 400) {
              speed = windowBytes /
                  (now.difference(windowStart).inMilliseconds / 1000.0);
              windowBytes = 0;
              windowStart = now;
            }
            _emit(task.id, done, total, speed, DownloadTaskState.running);
          }
          await sink.flush();
          await sink.close();
          stopwatch.stop();
        }

        // Verify hash when provided (honest integrity check).
        if (task.sha1 != null) {
          final actual = await _fileSha1(file);
          if (actual != task.sha1) {
            await file.delete();
            if (attempt == maxAttempts) {
              _emit(task.id, done, task.expectedSize, 0, DownloadTaskState.failed,
                  error: 'SHA1 mismatch for ${task.destPath}');
              return;
            }
            continue; // retry from scratch
          }
        }
        _emit(task.id, done, task.expectedSize > 0 ? task.expectedSize : done, 0,
            DownloadTaskState.done);
        return;
      } on DownloadHttpException catch (e) {
        if (attempt == maxAttempts) {
          _emit(task.id, 0, task.expectedSize, 0, DownloadTaskState.failed,
              error: 'HTTP ${e.status}');
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      } catch (e) {
        if (handle.cancelled) {
          _emit(task.id, 0, task.expectedSize, 0, DownloadTaskState.cancelled);
          return;
        }
        if (attempt == maxAttempts) {
          _emit(task.id, 0, task.expectedSize, 0, DownloadTaskState.failed,
              error: e.toString());
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  void _emit(String id, int done, int total, double speed,
      DownloadTaskState state,
      {String? error}) {
    if (!_closed) {
      _ctrl.add(DownloadProgress(
        taskId: id,
        doneBytes: done,
        totalBytes: total,
        bytesPerSec: speed,
        state: state,
        error: error,
      ));
    }
  }

  static Future<String> _fileSha1(File f) async {
    final digest = await sha1.bind(f.openRead()).first;
    return digest.toString();
  }

  static String sha1Bytes(List<int> bytes) => sha1.convert(bytes).toString();
  static String sha1String(String s) => sha1.convert(utf8.encode(s)).toString();
}

class DownloadHttpException implements Exception {
  DownloadHttpException(this.status);
  final int status;
}

class _TaskHandle {
  bool cancelled = false;
  final Completer<void> done = Completer<void>();

  void cancel() => cancelled = true;

  void finish(bool ok) {
    if (!done.isCompleted) done.complete();
  }
}
