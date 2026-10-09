import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/download_manager.dart';
import '../domain/core.dart';
import '../domain/models.dart';
import '../domain/version_service.dart';

/// Mods management: import/enable/disable/delete/dedupe/backup + catalog.
class ModService {
  ModService(this.core);
  final NovaCore core;

  Future<List<ModInfo>> list({String? versionId}) =>
      core.db.mods(versionId: versionId);

  /// Imports a local .jar. Returns null when duplicated.
  Future<ModInfo?> importFile(String srcPath, {String? versionId}) async {
    final src = File(srcPath);
    if (!src.existsSync()) return null;
    final fileName = p.basename(srcPath);

    final existing = await core.db.mods();
    if (existing.any((m) => m.fileName == fileName)) return null;

    final dest = File(p.join(core.paths.mods, fileName));
    if (p.absolute(src.path) != p.absolute(dest.path)) {
      await src.copy(dest.path);
    }

    final meta = VersionService.readModMeta(dest);
    String? loader;
    String? modVersion;
    String? title;
    String? mcVersion;
    if (meta != null) {
      if (meta.containsKey('id')) {
        loader = 'fabric';
        title = meta['name'] as String?;
        modVersion = meta['version'] as String?;
      } else if (meta.containsKey('modid')) {
        loader = 'forge';
        title = meta['name'] as String?;
        modVersion = meta['version'] as String?;
        final mc = meta['mcversion'];
        mcVersion = mc is String ? mc : null;
      } else if (meta.containsKey('raw')) {
        loader = 'forge';
      }
    }

    final info = ModInfo(
      id: null,
      fileName: fileName,
      path: dest.path,
      enabled: true,
      loader: loader,
      modVersion: modVersion,
      title: title,
      mcVersion: mcVersion,
    );
    await core.db.saveMod(info, versionId: versionId);
    return info;
  }

  Future<void> setEnabled(ModInfo m, bool enabled) async {
    final from = File(m.path);
    final toDir = enabled ? core.paths.mods : core.paths.disabledMods;
    final to = File(p.join(toDir, m.fileName));
    if (from.existsSync() && to.path != from.path) {
      await to.parent.create(recursive: true);
      await from.copy(to.path);
      await from.delete();
    }
    await core.db.updateMod(m.copyWith(enabled: enabled));
  }

  Future<void> remove(ModInfo m) async {
    for (final dir in [core.paths.mods, core.paths.disabledMods]) {
      final f = File(p.join(dir, m.fileName));
      if (f.existsSync()) await f.delete();
    }
    if (m.id != null) await core.db.deleteMod(m.id!);
  }

  /// Zip backup of the whole mods directory before bulk changes.
  Future<String> backup() async {
    final dir = Directory(core.paths.mods);
    final archive = Archive();
    if (dir.existsSync()) {
      for (final f in dir.listSync(recursive: true)) {
        if (f is File) {
          final rel = p.relative(f.path, from: core.paths.mods);
          archive.addFile(ArchiveFile(rel, f.lengthSync(), f.readAsBytesSync()));
        }
      }
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = File(p.join(core.paths.backups, 'mods_$ts.zip'));
    out.writeAsBytesSync(ZipEncoder().encode(archive)!);
    await core.db.addBackup('mods', core.paths.mods, out.path);
    return out.path;
  }

  // ------------------------------------------------------------- optimizer

  static const List<String> _perfSlugs = [
    'sodium',
    'lithium',
    'ferritecore',
    'entityculling',
    'modernfix',
    'immediatelyfast',
    'indium',
  ];

  /// Honest optimizer: checks the catalog per game version + loader and only
  /// suggests mods that actually have a compatible build.
  Future<List<OptimizeSuggestion>> optimizePlan({
    required String gameVersion,
    required String loader,
    List<ModInfo>? alreadyInstalled,
  }) async {
    final installedTitles = (alreadyInstalled ?? [])
        .map((m) => (m.title ?? m.fileName).toLowerCase())
        .toList();
    final out = <OptimizeSuggestion>[];
    for (final slug in _perfSlugs) {
      try {
        final versions = await core.modrinth.versions(
          slug,
          gameVersion: gameVersion,
          loader: loader,
        );
        if (versions.isEmpty) continue;
        final best = versions.first;
        if (best.files.isEmpty) continue;
        if (installedTitles.contains(slug) ||
            installedTitles.contains(best.name.toLowerCase())) {
          continue;
        }
        out.add(OptimizeSuggestion(
          slug: slug,
          title: best.name,
          versionName: best.name,
          file: best.files.first,
          loaders: best.loaders,
          mcVersions: best.mcVersions,
        ));
      } catch (_) {
        // Network issue: skip this candidate silently (no fake data).
      }
    }
    return out;
  }

  /// Downloads approved suggestions and registers them.
  Future<int> applySuggestions(List<OptimizeSuggestion> plan) async {
    final tasks = plan
        .map((s) => DownloadTask(
              id: 'opt:${s.slug}',
              url: s.file.url,
              destPath: p.join(core.paths.mods, s.file.fileName),
              expectedSize: s.file.size,
            ))
        .toList();
    final results = await core.downloads.runAll(tasks);
    int done = 0;
    for (final s in plan) {
      if (results['opt:${s.slug}'] == true) {
        done++;
        await core.db.saveMod(ModInfo(
          id: null,
          fileName: s.file.fileName,
          path: p.join(core.paths.mods, s.file.fileName),
          enabled: true,
          slug: s.slug,
          title: s.title,
          loader: s.loaders.isEmpty ? null : s.loaders.first,
          sourceUrl: 'https://modrinth.com/mod/$s.slug',
        ));
      }
    }
    return done;
  }

  /// Removes previously applied optimization mods (revert).
  Future<void> revert(List<OptimizeSuggestion> plan) async {
    final mods = await core.db.mods();
    for (final s in plan) {
      for (final m in mods.where((m) => m.slug == s.slug)) {
        await remove(m);
      }
    }
  }
}

class OptimizeSuggestion {
  const OptimizeSuggestion({
    required this.slug,
    required this.title,
    required this.versionName,
    required this.file,
    required this.loaders,
    required this.mcVersions,
  });
  final String slug;
  final String title;
  final String versionName;
  final CatalogVersionFile file;
  final List<String> loaders;
  final List<String> mcVersions;
}
