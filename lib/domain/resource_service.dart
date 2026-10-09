import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/paths.dart';
import '../data/zipx.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Resource packs & shader packs management (real files, real metadata).
class ResourceService {
  ResourceService(this.core);
  final NovaCore core;

  Future<List<PackInfo>> listPacks(String kind) async {
    final dir = Directory(kind == 'resourcepack'
        ? core.paths.resourcePacks
        : core.paths.shaderPacks);
    final out = <PackInfo>[];
    if (!dir.existsSync()) return out;
    for (final e in dir.listSync()) {
      final name = p.basename(e.path);
      if (e is File && name.endsWith('.zip')) {
        out.add(_fromZip(e, kind, name));
      } else if (e is Directory) {
        out.add(PackInfo(
          name: name,
          path: e.path,
          kind: kind,
          sizeBytes: NovaPaths.dirSize(e),
        ));
      }
    }
    return out;
  }

  PackInfo _fromZip(File f, String kind, String name) {
    int? packFormat;
    String? preview;
    try {
      final archive = ZipDecoder().decodeBytes(f.readAsBytesSync());
      final meta = archive.findFile('pack.mcmeta');
      if (meta != null) {
        final j = jsonDecode(String.fromCharCodes(meta.bytes()))
            as Map<String, dynamic>;
        packFormat = (j['pack']?['pack_format'] as num?)?.toInt();
      }
      final icon = archive.findFile('pack.png');
      if (icon != null) {
        final cache = File(p.join(core.paths.config, 'preview_${name.hashCode}.png'));
        if (!cache.existsSync()) {
          cache.writeAsBytesSync(icon.bytes());
        }
        preview = cache.path;
      }
    } catch (_) {
      // Not a valid zip — still list it, without fake metadata.
    }
    return PackInfo(
      name: name,
      path: f.path,
      kind: kind,
      sizeBytes: f.lengthSync(),
      previewPath: preview,
      mcMetaVersion: packFormat,
    );
  }

  Future<void> import(String srcPath, String kind) async {
    final dest = Directory(kind == 'resourcepack'
        ? core.paths.resourcePacks
        : core.paths.shaderPacks);
    await dest.create(recursive: true);
    await File(srcPath).copy(p.join(dest.path, p.basename(srcPath)));
  }

  Future<void> remove(PackInfo pack) async {
    final f = File(pack.path);
    if (f.existsSync()) await f.delete();
    final d = Directory(pack.path);
    if (d.existsSync()) await d.delete(recursive: true);
  }

  /// Writes enabled packs into options.txt the way Minecraft reads them.
  Future<void> setEnabledPacks(String kind, List<String> names) async {
    final options = File(core.paths.optionsTxt);
    final lines = options.existsSync()
        ? options.readAsLinesSync()
        : <String>[];
    final map = <String, String>{};
    for (final l in lines) {
      final i = l.indexOf(':');
      if (i > 0) map[l.substring(0, i)] = l.substring(i + 1);
    }
    if (kind == 'resourcepack') {
      final val = names.isEmpty
          ? '[]'
          : '[${names.map((n) => '"file/$n"').join(',')}]';
      map['resourcePacks'] = val;
    } else {
      map['shaderPack'] = names.isEmpty ? '' : names.first;
    }
    final out = map.entries.map((e) => '${e.key}:${e.value}').join('\n');
    await options.writeAsString('$out\n');
  }
}
