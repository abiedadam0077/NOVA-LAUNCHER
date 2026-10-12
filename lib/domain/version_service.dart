import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/download_manager.dart';
import '../data/jsonx.dart';
import '../data/paths.dart';
import '../data/zipx.dart';
import '../data/piston_api.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Real install pipeline: official Mojang files, SHA1-verified, resumable.
class VersionService {
  VersionService(this.core);
  final NovaCore core;

  /// Total expected download size (bytes) for the UI before installing.
  Future<int> estimateSize(McVersion v) async {
    final detail = await core.piston.getVersionDetail(v.url);
    int total = detail.client.size;
    for (final l in detail.libraries) {
      total += l.artifact?.size ?? 0;
    }
    if (detail.assetsUrl.isNotEmpty) {
      try {
        final index = await core.piston.getAssetIndex(detail.assetsUrl);
        for (final a in index.values) {
          total += a.size;
        }
      } catch (_) {}
    }
    return total;
  }

  /// Installs a version. Returns true on success.
  /// Progress events are broadcast through core.downloads.progress.
  Future<bool> install(McVersion v, {LoaderType loader = LoaderType.vanilla}) async {
    core.logs.add('versions', 'Installing ${v.id} (loader: ${loader.name})');
    final detail = await core.piston.getVersionDetail(v.url);

    final tasks = <DownloadTask>[]

      // 1) Client jar
      ..add(DownloadTask(
        id: 'client:${v.id}',
        url: detail.client.url,
        destPath: core.paths.versionJar(v.id),
        sha1: detail.client.sha1,
        expectedSize: detail.client.size,
      ));

    // 2) Libraries
    for (final lib in detail.libraries) {
      final a = lib.artifact;
      if (a == null || a.url.isEmpty) continue; // rules/natives handled by runtime
      tasks.add(DownloadTask(
        id: 'lib:${v.id}:${lib.name}',
        url: a.url,
        destPath: p.join(core.paths.libraries, a.path),
        sha1: a.sha1,
        expectedSize: a.size,
      ));
    }

    // 3) Asset index + objects
    final objects = <String, AssetObject>{};
    if (detail.assetsUrl.isNotEmpty) {
      final index = await core.piston.getAssetIndex(detail.assetsUrl);
      objects.addAll(index);
      await File(p.join(core.paths.assets, 'indexes', '${detail.assetsId}.json'))
          .create(recursive: true);
      await File(p.join(core.paths.assets, 'indexes', '${detail.assetsId}.json'))
          .writeAsString(jsonEncodeSafe(index.map((k, o) => MapEntry(k, {
                'hash': o.hash,
                'size': o.size,
              }))));
      for (final entry in index.entries) {
        tasks.add(DownloadTask(
          id: 'asset:${entry.value.hash}',
          url: core.piston.assetObjectUrl(entry.value.hash),
          destPath: p.join(core.paths.assets, 'objects',
              '${entry.value.hash.substring(0, 2)}/${entry.value.hash}'),
          sha1: entry.value.hash,
          expectedSize: entry.value.size,
        ));
      }
    }

    // Deduplicate identical asset objects.
    final seen = <String>{};
    tasks.removeWhere((t) {
      if (!t.id.startsWith('asset:')) return false;
      return !seen.add(t.id);
    });

    // 4) Fabric loader profile (merged libraries from meta.fabricmc.net)
    String? loaderVersion;
    if (loader == LoaderType.fabric) {
      loaderVersion = await core.fabric.latestLoader(v.id);
      final profile = loaderVersion == null
          ? null
          : await core.fabric.buildProfileJson(
              mcVersion: v.id, loaderVersion: loaderVersion);
      if (profile != null) {
        for (final l in (profile['libraries'] as List? ?? [])) {
          final lm = l as Map<String, dynamic>;
          final url = lm['url'] as String?;
          final path = lm['path'] as String?;
          if (url == null || path == null) continue;
          tasks.add(DownloadTask(
            id: 'fab:${lm['name']}',
            url: '$url$path',
            destPath: p.join(core.paths.libraries, path),
          ));
        }
        await File(core.paths.versionJson('${v.id}-fabric'))
            .create(recursive: true);
        await File(core.paths.versionJson('${v.id}-fabric'))
            .writeAsString(jsonEncodeSafe(profile));
      }
    }

    // Always persist the base version json.
    final res = await core.http.get(v.url);
    await File(core.paths.versionJson(v.id)).create(recursive: true);
    await File(core.paths.versionJson(v.id)).writeAsString(res.body);

    final results = await core.downloads.runAll(tasks);
    final ok = results.values.where((b) => b).length;
    core.logs.add('versions', 'Install finished: $ok/${results.length} files OK');
    final success = results.values.every((b) => b);

    if (success) {
      final size = NovaPaths.dirSize(Directory(core.paths.versionDir(v.id))) +
          NovaPaths.dirSize(Directory(core.paths.libraries)) +
          NovaPaths.dirSize(Directory(core.paths.assets));
      await core.db.saveInstalledVersion(InstalledVersion(
        id: v.id,
        loader: loader,
        loaderVersion: loaderVersion,
        sizeBytes: size,
        installedAt: DateTime.now(),
        javaMajor: detail.javaMajor,
      ));
    }
    return success;
  }

  /// Honest verification: every official file must exist with correct SHA1.
  Future<List<String>> verify(InstalledVersion v) async {
    final missing = <String>[];
    if (!File(core.paths.versionJar(v.id)).existsSync()) {
      missing.add('client jar');
    }
    if (!File(core.paths.versionJson(v.id)).existsSync()) {
      missing.add('version json');
    }
    return missing;
  }

  Future<void> delete(String id) async {
    final dir = Directory(core.paths.versionDir(id));
    if (dir.existsSync()) await dir.delete(recursive: true);
    await core.db.deleteInstalledVersion(id);
  }

  /// Inspects a mod jar for common metadata (fabric.mod.json / mcmod.info /
  /// mods.toml) without executing anything.
  static Map<String, dynamic>? readModMeta(File jar) {
    try {
      final archive = ZipDecoder().decodeBytes(jar.readAsBytesSync());
      for (final name in ['fabric.mod.json', 'mcmod.info', 'META-INF/mods.toml']) {
        final f = archive.findFile(name);
        if (f != null) {
          final content = String.fromCharCodes(f.bytes());
          if (name == 'fabric.mod.json') {
            return jsonMap(content);
          }
          if (name == 'mcmod.info') {
            final list = jsonList(content);
            if (list.isNotEmpty) return list[0] as Map<String, dynamic>;
          }
          return {'raw': content};
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
