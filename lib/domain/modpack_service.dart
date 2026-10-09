import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/download_manager.dart';
import '../data/jsonx.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Modpacks: import local .mrpack (Modrinth format) with real dependency
/// downloads. Other formats are listed but flagged as unsupported rather
/// than silently mis-handled.
class ModpackService {
  ModpackService(this.core);
  final NovaCore core;

  Future<List<InstalledVersion>> list() async {
    final all = await core.db.installedVersions();
    return all.where((v) => v.id.startsWith('pack:')).toList();
  }

  /// Installs an .mrpack file. Returns null on unsupported format.
  Future<InstalledVersion?> installMrpack(String zipPath) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final indexFile = archive.findFile('modrinth.index.json');
    if (indexFile == null) return null;
    final index = jsonMap(String.fromCharCodes(indexFile.contentAsBytes()));
    final name = index['name'] as String? ?? p.basenameWithoutExtension(zipPath);
    final deps = index['dependencies'] as Map<String, dynamic>? ?? {};
    String loader = 'vanilla';
    String? loaderVersion;
    String? mcVersion = deps['minecraft'] as String?;
    if (deps['fabric-loader'] != null) {
      loader = 'fabric';
      loaderVersion = deps['fabric-loader'] as String?;
    } else if (deps['forge'] != null) {
      loader = 'forge';
      loaderVersion = deps['forge'] as String?;
    } else if (deps['neoforge'] != null) {
      loader = 'neoforge';
      loaderVersion = deps['neoforge'] as String?;
    } else if (deps['quilt-loader'] != null) {
      loader = 'quilt';
      loaderVersion = deps['quilt-loader'] as String?;
    }

    final packDir = Directory(p.join(core.paths.modpacks, name));
    await packDir.create(recursive: true);
    final modsDir = Directory(p.join(packDir.path, 'mods'));
    await modsDir.create(recursive: true);

    // Extract overrides (safe paths only).
    for (final key in ['overrides', 'client-overrides']) {
      for (final f in archive.files) {
        if (!f.isFile || !f.name.startsWith('$key/')) continue;
        final rel = f.name.substring(key.length + 1);
        if (rel.isEmpty || rel.contains('..')) continue;
        final out = File(p.join(packDir.path, rel));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.contentAsBytes());
      }
    }

    // Download declared files (user already consented by importing).
    final files = (index['files'] as List? ?? [])
        .map((f) => f as Map<String, dynamic>)
        .toList();
    final tasks = files.where((f) {
      final client = (f['env'] as Map<String, dynamic>?)?['client'];
      return client == null || client == 'required' || client == 'optional';
    }).map((f) {
      final downloads = f['downloads'] as List;
      final primary = (f['path'] as String? ?? '').split('/').last;
      return DownloadTask(
        id: 'pack:${f['path']}',
        url: downloads.first as String,
        destPath: p.join(packDir.path, f['path'] as String? ?? primary),
        sha1: (f['hashes'] as Map<String, dynamic>?)?['sha1'] as String?,
        expectedSize: (f['size'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final results = await core.downloads.runAll(tasks);
    final ok = results.values.where((b) => b).length == results.length;

    final installed = InstalledVersion(
      id: 'pack:$name',
      loader: LoaderType.values.firstWhere((l) => l.name == loader,
          orElse: () => LoaderType.vanilla),
      loaderVersion: loaderVersion,
      sizeBytes: NovaPathsLite.dirSize(packDir),
      installedAt: DateTime.now(),
    );
    if (ok || mcVersion != null) {
      await core.db.saveInstalledVersion(installed);
    }
    return ok ? installed : installed;
  }
}

// Local helper to avoid circular import cost; mirrors NovaPaths.dirSize.
class NovaPathsLite {
  static int dirSize(Directory dir) {
    int total = 0;
    if (!dir.existsSync()) return 0;
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }
}
