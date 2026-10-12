import 'package:flutter/services.dart';

import '../data/download_manager.dart';
import '../data/jsonx.dart';
import '../data/paths.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Bridges NOVA to real Minecraft-Java runtimes on Android.
/// The game is prepared by NOVA (official files); execution requires a
/// JVM+LWJGL port — provided by open-source runtimes (Amethyst/Pojav/Zalith).
class RuntimeBridge {
  RuntimeBridge(this.core);
  final NovaCore core;

  static const MethodChannel _ch = MethodChannel('nova/app');

  Future<List<RuntimeApp>> installedRuntimes() async {
    try {
      final list = await _ch.invokeListMethod<Map>('getInstalledRuntimes');
      return (list ?? [])
          .map((m) => RuntimeApp(
                packageName: m['package'] as String? ?? '',
                name: m['name'] as String? ?? '',
                version: m['version'] as String? ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> launch(String packageName, {String? versionId}) async {
    try {
      final ok = await _ch.invokeMethod<bool>('launchRuntime', {
        'package': packageName,
        'versionId': versionId,
        'gameDir': core.paths.root.path,
      });
      core.logs.add('runtime', 'Launched $packageName -> $ok');
      return ok == true;
    } catch (e) {
      core.logs.add('runtime', 'Launch failed: $e', level: 'ERROR');
      return false;
    }
  }

  /// Latest Amethyst-Android (Pojav successor, LGPL-3.0) release APK.
  Future<RuntimeRelease?> latestRelease() async {
    final res = await core.http.get(
      'https://api.github.com/repos/AngelAuraMC/Amethyst-Android/releases/latest',
    );
    if (res.statusCode != 200) return null;
    final j = jsonMap(res.body);
    final assets = j['assets'] as List? ?? [];
    for (final a in assets) {
      final m = a as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return RuntimeRelease(
          version: j['tag_name'] as String? ?? '',
          fileName: name,
          url: m['browser_download_url'] as String? ?? '',
          size: (m['size'] as num?)?.toInt() ?? 0,
        );
      }
    }
    return null;
  }

  /// Downloads the runtime APK locally (user consent required in UI),
  /// then asks Android to install it.
  Future<bool> installRuntime(RuntimeRelease rel) async {
    final tasks = [
      DownloadTask(
        id: 'runtime',
        url: rel.url,
        destPath: '${core.paths.runtimes}/${rel.fileName}',
        expectedSize: rel.size,
      ),
    ];
    final results = await core.downloads.runAll(tasks);
    if (results['runtime'] != true) return false;
    try {
      return await _ch.invokeMethod<bool>('installApk', {
            'path': '${core.paths.runtimes}/${rel.fileName}',
          }) ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canInstallPackages() async {
    try {
      return await _ch.invokeMethod<bool>('canInstallPackages') == true;
    } catch (_) {
      return false;
    }
  }
}

class RuntimeRelease {
  const RuntimeRelease({
    required this.version,
    required this.fileName,
    required this.url,
    required this.size,
  });
  final String version;
  final String fileName;
  final String url;
  final int size;
}
