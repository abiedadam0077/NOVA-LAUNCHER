import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/paths.dart';
import '../data/zipx.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Worlds (saves) management: scan, import, backup, restore, delete.
class MapService {
  MapService(this.core);
  final NovaCore core;

  /// Worlds present in the game saves directory (real data only).
  Future<List<WorldInfo>> listWorlds() async {
    final dir = Directory(core.paths.saves);
    final out = <WorldInfo>[];
    if (!dir.existsSync()) return out;
    for (final e in dir.listSync()) {
      if (e is Directory && File(p.join(e.path, 'level.dat')).existsSync()) {
        out.add(WorldInfo(
          name: p.basename(e.path),
          path: e.path,
          sizeBytes: NovaPaths.dirSize(e),
          lastPlayed: e.statSync().modified,
        ));
      }
    }
    return out;
  }

  /// Imports a world zip into saves/ without overwriting existing worlds.
  /// Returns false when the target already exists (confirmation handled in UI).
  Future<bool> importZip(String zipPath, {bool overwrite = false}) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final baseName = p.basenameWithoutExtension(zipPath);
    final target = Directory(p.join(core.paths.saves, baseName));
    if (target.existsSync() && !overwrite) return false;
    if (target.existsSync()) await target.delete(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name;
      if (name.contains('..')) continue; // path traversal safety
      final out = File(p.join(core.paths.saves, name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.bytes());
    }
    return true;
  }

  Future<String> backupWorld(WorldInfo w) async {
    final archive = Archive();
    for (final f in Directory(w.path).listSync(recursive: true)) {
      if (f is File) {
        final rel = p.relative(f.path, from: w.path);
        archive.addFile(ArchiveFile(rel, f.lengthSync(), f.readAsBytesSync()));
      }
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = File(p.join(core.paths.backups, 'world_${w.name}_$ts.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    await core.db.addBackup('world', w.name, out.path);
    return out.path;
  }

  Future<void> restoreWorld(String backupPath, String worldName) async {
    final bytes = File(backupPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final target = Directory(p.join(core.paths.saves, worldName));
    if (target.existsSync()) await target.delete(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name.contains('..')) continue;
      final out = File(p.join(core.paths.saves, f.name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(f.bytes());
    }
  }

  Future<void> deleteWorld(WorldInfo w) async {
    final dir = Directory(w.path);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
