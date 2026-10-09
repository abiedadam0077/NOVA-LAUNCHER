import 'dart:convert';
import 'dart:io';

import '../data/nbt.dart';
import '../data/server_ping.dart';
import '../domain/core.dart';
import '../domain/models.dart';

/// Servers CRUD + real sync to Minecraft's servers.dat + real SLP ping.
class ServerService {
  ServerService(this.core);
  final NovaCore core;

  Future<List<ServerEntry>> list() => core.db.servers();

  Future<void> save(ServerEntry s) async {
    await core.db.saveServer(s);
    await syncServersDat();
  }

  Future<void> delete(int id) async {
    await core.db.deleteServer(id);
    await syncServersDat();
  }

  /// Rewrites servers.dat in the game directory so the server appears
  /// inside Minecraft's own Multiplayer screen.
  Future<void> syncServersDat() async {
    final servers = await core.db.servers();
    final bytes = Nbt.writeServersDat(servers);
    await File(core.paths.serversDat).writeAsBytes(bytes);
    core.logs.add('servers', 'servers.dat synced (${servers.length} servers)');
  }

  /// Import list previously written by Minecraft (one-way convenience).
  Future<int> importFromGame() async {
    final f = File(core.paths.serversDat);
    if (!f.existsSync()) return 0;
    final read = Nbt.readServersDat(await f.readAsBytes());
    int added = 0;
    final existing = await core.db.servers();
    for (final s in read) {
      if (!existing.any((e) => e.address == s.address && e.port == s.port)) {
        await core.db.saveServer(s);
        added++;
      }
    }
    return added;
  }

  Future<ServerStatus> ping(ServerEntry s) =>
      ServerPing.ping(s.address, s.port);

  Future<String> exportJson() async {
    final servers = await core.db.servers();
    return jsonEncode(servers
        .map((s) => {
              'name': s.name,
              'address': s.address,
              'port': s.port,
              'description': s.description,
            })
        .toList());
  }

  Future<int> importJson(String body) async {
    final list = jsonDecode(body) as List;
    int added = 0;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      await core.db.saveServer(ServerEntry(
        id: null,
        name: m['name'] as String? ?? 'Server',
        address: m['address'] as String? ?? '',
        port: (m['port'] as num?)?.toInt() ?? 25565,
        description: m['description'] as String? ?? '',
        position: added,
      ));
      added++;
    }
    await syncServersDat();
    return added;
  }
}
