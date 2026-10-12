import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// Local SQLite store: profiles, installed versions, mods, servers, backups.
class NovaDb {
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    return openDatabase(
      p.join(dir.path, 'nova.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE profiles(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            skinPath TEXT,
            skinModel TEXT,
            isDefault INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE installed_versions(
            id TEXT PRIMARY KEY,
            loader TEXT NOT NULL,
            loaderVersion TEXT,
            sizeBytes INTEGER NOT NULL,
            installedAt INTEGER NOT NULL,
            javaMajor INTEGER NOT NULL DEFAULT 8
          )''');
        await db.execute('''
          CREATE TABLE mods(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            versionId TEXT,
            fileName TEXT NOT NULL,
            path TEXT NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 1,
            slug TEXT,
            title TEXT,
            modVersion TEXT,
            loader TEXT,
            mcVersion TEXT,
            category TEXT,
            sourceUrl TEXT,
            license TEXT
          )''');
        await db.execute('''
          CREATE TABLE servers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            address TEXT NOT NULL,
            port INTEGER NOT NULL DEFAULT 25565,
            description TEXT NOT NULL DEFAULT '',
            position INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE backups(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            target TEXT NOT NULL,
            path TEXT NOT NULL,
            createdAt INTEGER NOT NULL
          )''');
      },
    );
  }

  // ------------------------------------------------------------ profiles
  Future<List<UserProfile>> profiles() async {
    final rows = await (await db).query('profiles', orderBy: 'isDefault DESC, name');
    return rows.map(UserProfile.fromMap).toList();
  }

  Future<void> saveProfile(UserProfile pr) async {
    final d = await db;
    if (pr.isDefault) {
      await d.update('profiles', {'isDefault': 0});
    }
    await d.insert('profiles', pr.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProfile(String id) async {
    await (await db).delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ versions
  Future<List<InstalledVersion>> installedVersions() async {
    final rows = await (await db).query('installed_versions');
    return rows.map(InstalledVersion.fromMap).toList();
  }

  Future<void> saveInstalledVersion(InstalledVersion v) async {
    await (await db).insert('installed_versions', v.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteInstalledVersion(String id) async {
    await (await db).delete('installed_versions', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ mods
  Future<List<ModInfo>> mods({String? versionId}) async {
    final d = await db;
    final rows = versionId == null
        ? await d.query('mods')
        : await d.query('mods', where: 'versionId = ?', whereArgs: [versionId]);
    return rows.map(_modFromMap).toList();
  }

  Future<int> saveMod(ModInfo m, {String? versionId}) async {
    return (await db).insert(
      'mods',
      {
        'versionId': versionId,
        'fileName': m.fileName,
        'path': m.path,
        'enabled': m.enabled ? 1 : 0,
        'slug': m.slug,
        'title': m.title,
        'modVersion': m.modVersion,
        'loader': m.loader,
        'mcVersion': m.mcVersion,
        'category': m.category,
        'sourceUrl': m.sourceUrl,
        'license': m.license,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMod(ModInfo m) async {
    if (m.id == null) return;
    await (await db).update(
      'mods',
      {
        'enabled': m.enabled ? 1 : 0,
        'category': m.category,
        'title': m.title,
        'modVersion': m.modVersion,
        'loader': m.loader,
        'mcVersion': m.mcVersion,
        'sourceUrl': m.sourceUrl,
        'license': m.license,
      },
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteMod(int id) async {
    await (await db).delete('mods', where: 'id = ?', whereArgs: [id]);
  }

  ModInfo _modFromMap(Map<String, Object?> m) => ModInfo(
        id: m['id'] as int?,
        fileName: m['fileName'] as String,
        path: m['path'] as String,
        enabled: (m['enabled'] as int? ?? 1) == 1,
        slug: m['slug'] as String?,
        title: m['title'] as String?,
        modVersion: m['modVersion'] as String?,
        loader: m['loader'] as String?,
        mcVersion: m['mcVersion'] as String?,
        category: m['category'] as String?,
        sourceUrl: m['sourceUrl'] as String?,
        license: m['license'] as String?,
      );

  // ------------------------------------------------------------ servers
  Future<List<ServerEntry>> servers() async {
    final rows = await (await db).query('servers', orderBy: 'position');
    return rows
        .map((m) => ServerEntry(
              id: m['id'] as int?,
              name: m['name'] as String,
              address: m['address'] as String,
              port: (m['port'] as num?)?.toInt() ?? 25565,
              description: m['description'] as String? ?? '',
              position: (m['position'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<void> saveServer(ServerEntry s) async {
    final d = await db;
    final map = {
      'name': s.name,
      'address': s.address,
      'port': s.port,
      'description': s.description,
      'position': s.position,
    };
    if (s.id == null) {
      await d.insert('servers', map);
    } else {
      await d.update('servers', map, where: 'id = ?', whereArgs: [s.id]);
    }
  }

  Future<void> deleteServer(int id) async {
    await (await db).delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------ backups
  Future<List<Map<String, Object?>>> backups() async =>
      (await db).query('backups', orderBy: 'createdAt DESC');

  Future<void> addBackup(String kind, String target, String path) async {
    await (await db).insert('backups', {
      'kind': kind,
      'target': target,
      'path': path,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteBackup(int id) async {
    await (await db).delete('backups', where: 'id = ?', whereArgs: [id]);
  }
}
