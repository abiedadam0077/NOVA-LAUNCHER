import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Standard .minecraft-compatible layout under the app's private storage.
/// Kept compatible so external runtimes can consume the same directories.
class NovaPaths {
  NovaPaths._();

  late final Directory root;

  Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    root = Directory(p.join(docs.path, 'nova_mc'));
    await root.create(recursive: true);
    for (final d in [
      'versions',
      'libraries',
      'assets/indexes',
      'assets/objects',
      'mods',
      'mods/disabled',
      'resourcepacks',
      'shaderpacks',
      'saves',
      'screenshots',
      'logs',
      'config',
      'backups',
      'skins',
      'runtimes',
      'maps',
      'modpacks',
    ]) {
      await Directory(p.join(root.path, d)).create(recursive: true);
    }
  }

  String get mods => p.join(root.path, 'mods');
  String get disabledMods => p.join(root.path, 'mods', 'disabled');
  String get resourcePacks => p.join(root.path, 'resourcepacks');
  String get shaderPacks => p.join(root.path, 'shaderpacks');
  String get saves => p.join(root.path, 'saves');
  String get logs => p.join(root.path, 'logs');
  String get config => p.join(root.path, 'config');
  String get backups => p.join(root.path, 'backups');
  String get skins => p.join(root.path, 'skins');
  String get runtimes => p.join(root.path, 'runtimes');
  String get maps => p.join(root.path, 'maps');
  String get modpacks => p.join(root.path, 'modpacks');

  String versionDir(String id) => p.join(root.path, 'versions', id);
  String versionJson(String id) => p.join(versionDir(id), '$id.json');
  String versionJar(String id) => p.join(versionDir(id), '$id.jar');
  String get libraries => p.join(root.path, 'libraries');
  String get assets => p.join(root.path, 'assets');
  String get serversDat => p.join(root.path, 'servers.dat');
  String get optionsTxt => p.join(root.path, 'options.txt');

  static int dirSize(Directory dir) {
    if (!dir.existsSync()) return 0;
    int total = 0;
    try {
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += e.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }
}
