import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';

/// Servers management — synced into Minecraft's own Multiplayer list.
class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final servers = ref.watch(serversProvider);
    return Scaffold(
      backgroundColor: NovaColors.bg,
      appBar: AppBar(
        title: Text(t('settings.servers')),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: t('servers.synced'),
            icon: const Icon(Icons.sync_outlined, color: NovaColors.electricBlue),
            onPressed: () async {
              final added = await ref.read(serverServiceProvider).importFromGame();
              await ref.read(serversProvider.notifier).reload();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('+ $added')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: NovaColors.success.withOpacity(0.08),
                border: Border.all(color: NovaColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: NovaColors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t('servers.synced'),
                        style: const TextStyle(
                            fontSize: 11, color: NovaColors.success)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: servers.isEmpty
                ? NovaEmpty(message: t('common.empty'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    itemCount: servers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _ServerTile(server: servers[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NovaColors.violet,
        foregroundColor: Colors.white,
        onPressed: () => _edit(ref, context, null),
        label: Text(t('servers.add')),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _edit(WidgetRef ref, BuildContext context, ServerEntry? s) async {
    final t = ref.read(stringsProvider);
    final name = TextEditingController(text: s?.name);
    final addr = TextEditingController(text: s?.address);
    final port = TextEditingController(text: '${s?.port ?? 25565}');
    final desc = TextEditingController(text: s?.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('servers.add')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(labelText: t('servers.name')),
            ),
            TextField(
              controller: addr,
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(labelText: t('servers.address')),
            ),
            TextField(
              controller: port,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(labelText: t('servers.port')),
            ),
            TextField(
              controller: desc,
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(labelText: t('common.details')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('common.confirm'))),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || addr.text.trim().isEmpty) return;
    await ref.read(serverServiceProvider).save(ServerEntry(
          id: s?.id,
          name: name.text.trim(),
          address: addr.text.trim(),
          port: int.tryParse(port.text) ?? 25565,
          description: desc.text.trim(),
          position: s?.position ?? 999,
        ));
    await ref.read(serversProvider.notifier).reload();
  }
}

class _ServerTile extends ConsumerStatefulWidget {
  const _ServerTile({required this.server});
  final ServerEntry server;

  @override
  ConsumerState<_ServerTile> createState() => _ServerTileState();
}

class _ServerTileState extends ConsumerState<_ServerTile> {
  ServerStatus? _status;
  bool _pinging = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final s = widget.server;
    return NovaGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            _status == null
                ? Icons.dns_outlined
                : _status!.online
                    ? Icons.wifi
                    : Icons.wifi_off,
            color: _status == null
                ? NovaColors.textSecondary
                : _status!.online
                    ? NovaColors.success
                    : NovaColors.danger,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  _status?.online == true
                      ? '${s.ip} • ${_status!.playersOnline ?? 0}/${_status!.maxPlayers ?? 0} • ${_status!.latencyMs}ms'
                      : s.ip,
                  style: const TextStyle(
                      fontSize: 11, color: NovaColors.textSecondary),
                ),
                if (_status?.online == true && _status!.motd != null)
                  Text(_status!.motd!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: NovaColors.neonCyan)),
              ],
            ),
          ),
          IconButton(
            tooltip: t('servers.ping'),
            icon: _pinging
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.network_ping_outlined,
                    color: NovaColors.electricBlue, size: 20),
            onPressed: _pinging
                ? null
                : () async {
                    setState(() => _pinging = true);
                    final st = await ref.read(serverServiceProvider).ping(s);
                    if (mounted) {
                      setState(() {
                        _status = st;
                        _pinging = false;
                      });
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: NovaColors.danger),
            onPressed: () async {
              if (s.id == null) return;
              await ref.read(serverServiceProvider).delete(s.id!);
              await ref.read(serversProvider.notifier).reload();
            },
          ),
        ],
      ),
    );
  }
}
