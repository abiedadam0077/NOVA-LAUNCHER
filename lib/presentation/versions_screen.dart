import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/utils.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';

class VersionsScreen extends ConsumerStatefulWidget {
  const VersionsScreen({super.key});

  @override
  ConsumerState<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends ConsumerState<VersionsScreen> {
  String _query = '';
  String _filter = 'release';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final manifest = ref.watch(manifestProvider);
    final installed = ref.watch(installedProvider);
    final installedIds = installed.map((v) => v.id).toSet();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Text(t('versions.title'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (installed.isNotEmpty)
                  Chip(
                    backgroundColor: NovaColors.success.withOpacity(0.15),
                    side: BorderSide.none,
                    label: Text('${installed.length} ${t('versions.installed')}',
                        style: const TextStyle(
                            color: NovaColors.success, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: NovaColors.textPrimary),
              decoration: InputDecoration(
                hintText: t('versions.search'),
                hintStyle: const TextStyle(color: NovaColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    color: NovaColors.textSecondary),
                filled: true,
                fillColor: NovaColors.surface.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              children: [
                _chip(t('versions.releases'), 'release'),
                const SizedBox(width: 8),
                _chip(t('versions.snapshots'), 'snapshot'),
              ],
            ),
          ),
          Expanded(
            child: manifest.when(
              data: (versions) {
                final filtered = versions
                    .where((v) =>
                        (_filter == 'release'
                            ? v.type == ReleaseType.release
                            : v.type == ReleaseType.snapshot))
                    .where((v) => v.id
                        .toLowerCase()
                        .contains(_query.toLowerCase()))
                    .toList();
                if (filtered.isEmpty) {
                  return NovaEmpty(message: t('common.empty'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final v = filtered[i];
                    final isInstalled = installedIds.contains(v.id);
                    final isSelected =
                        ref.watch(selectedVersionIdProvider) == v.id;
                    return NovaGlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      onTap: () => _openDetail(v, isInstalled),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isInstalled
                                  ? NovaColors.success
                                  : NovaColors.textSecondary.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.id,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  v.type.name,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: NovaColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: NovaColors.electricBlue, size: 18),
                          if (isInstalled)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(t('versions.installed'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: NovaColors.success)),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => NovaLoading(label: t('common.loading')),
              error: (e, __) => NovaError(
                message: t('error.network'),
                details: e.toString(),
                onRetry: () => ref.invalidate(manifestProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: NovaColors.electricBlue.withOpacity(0.3),
      labelStyle: TextStyle(
        color: selected ? NovaColors.electricBlue : NovaColors.textSecondary,
        fontSize: 12,
      ),
      side: BorderSide.none,
      backgroundColor: NovaColors.surface.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _openDetail(McVersion v, bool isInstalled) async {
    final t = ref.read(stringsProvider);
    var loader = ref.read(selectedLoaderProvider);
    int? estimate;
    int? java;
    try {
      final core = ref.read(coreProvider);
      final detail = await core.piston.getVersionDetail(v.url);
      java = detail.javaMajor;
      estimate = await ref.read(versionServiceProvider).estimateSize(v);
    } catch (_) {
      estimate = null;
      java = null;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NovaColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(v.id,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (estimate != null)
                    Text('${t('versions.size')}: ${NovaUtils.formatBytes(estimate)}',
                        style: const TextStyle(
                            fontSize: 12, color: NovaColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                java == null
                    ? t('versions.java')
                    : '${t('versions.java')} $java',
                style: const TextStyle(
                    fontSize: 12, color: NovaColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Text(t('versions.loader'),
                  style: const TextStyle(
                      fontSize: 12, color: NovaColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: LoaderType.values.map((l) {
                  final supported =
                      l == LoaderType.vanilla || l == LoaderType.fabric;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.name),
                        if (!supported)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.lock_outline, size: 12),
                          ),
                      ],
                    ),
                    selected: loader == l,
                    onSelected: supported
                        ? (_) => setSheet(() => loader = l)
                        : null,
                    selectedColor: NovaColors.violet.withOpacity(0.35),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: supported
                          ? NovaColors.textPrimary
                          : NovaColors.textSecondary,
                    ),
                    side: BorderSide.none,
                    backgroundColor: NovaColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: NovaGradientButton(
                      label: isInstalled ? t('versions.select') : t('versions.install'),
                      icon: isInstalled
                          ? Icons.check_rounded
                          : Icons.download_rounded,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (isInstalled) {
                          ref
                              .read(selectedVersionIdProvider.notifier)
                              .state = v.id;
                          ref.read(selectedLoaderProvider.notifier).state =
                              loader;
                          await ref
                              .read(coreProvider)
                              .prefs
                              .setSelectedVersion(v.id);
                          await ref
                              .read(coreProvider)
                              .prefs
                              .setSelectedLoader(loader);
                        } else {
                          final ok = await ref
                              .read(installControllerProvider.notifier)
                              .install(v, loader);
                          if (mounted) {
                            await ref
                                .read(installedProvider.notifier)
                                .reload();
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(ok
                                        ? t('common.success')
                                        : t('error.network'))));
                          }
                        }
                      },
                    ),
                  ),
                  if (isInstalled) ...[
                    const SizedBox(width: 10),
                    NovaOutlineButton(
                      label: t('versions.delete'),
                      danger: true,
                      icon: Icons.delete_outline,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(versionServiceProvider).delete(v.id);
                        await ref.read(installedProvider.notifier).reload();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
