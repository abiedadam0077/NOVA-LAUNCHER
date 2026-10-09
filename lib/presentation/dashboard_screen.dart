import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/colors.dart';
import '../core/utils.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';
import 'widgets/skin_widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Restore persisted selection once the manifest is ready.
    Future.microtask(() async {
      final core = ref.read(coreProvider);
      if (ref.read(selectedVersionIdProvider) == null) {
        ref.read(selectedVersionIdProvider.notifier).state =
            core.prefs.selectedVersion;
      }
    });
  }

  Future<void> _onPlay() async {
    final t = ref.read(stringsProvider);
    final state = ref.read(playStateProvider);
    if (state == PlayState.ready) {
      final runtimes = await ref.read(runtimeBridgeProvider).installedRuntimes();
      if (runtimes.isEmpty) {
        _showRuntimeDialog(t);
        return;
      }
      final ok = await ref
          .read(runtimeBridgeProvider)
          .launch(runtimes.first.packageName,
              versionId: ref.read(selectedVersionIdProvider));
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('error.generic'))));
      }
      ref.invalidate(runtimesProvider);
      return;
    }
    if (state == PlayState.notInstalled) {
      await _startInstall();
    }
  }

  Future<void> _startInstall() async {
    final t = ref.read(stringsProvider);
    try {
      final manifest = await ref.read(manifestProvider.future);
      final releases =
          manifest.where((v) => v.type == ReleaseType.release).toList();
      if (releases.isEmpty) return;
      var selectedId = ref.read(selectedVersionIdProvider);
      if (selectedId == null ||
          !manifest.any((v) => v.id == selectedId)) {
        selectedId = releases.first.id;
        ref.read(selectedVersionIdProvider.notifier).state = selectedId;
        await ref.read(coreProvider).prefs.setSelectedVersion(selectedId);
      }
      final version = manifest.firstWhere((v) => v.id == selectedId);
      final loader = ref.read(selectedLoaderProvider);
      final ok = await ref
          .read(installControllerProvider.notifier)
          .install(version, loader);
      if (mounted) {
        await ref.read(installedProvider.notifier).reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? t('common.success') : t('error.network'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('error.network'))));
      }
    }
  }

  void _showRuntimeDialog(String Function(String) t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('home.runtimeMissing')),
        content: Text(t('home.runtimeHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('common.close')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/settings');
            },
            child: Text(t('home.installRuntime')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);
    final current = profiles.where((p) => p.isDefault).toList();
    final profile = current.isNotEmpty ? current.first : (profiles.isNotEmpty ? profiles.first : null);
    final selected = ref.watch(selectedVersionIdProvider);
    final installed = ref.watch(installedProvider);
    final selectedInstalled =
        installed.where((v) => v.id == selected).toList();
    final playState = ref.watch(playStateProvider);
    final install = ref.watch(installControllerProvider);
    final specsAsync = ref.watch(deviceSpecsProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: NovaColors.brandGradient,
                ),
                child: Image.asset('assets/images/nova_logo.png',
                    width: 26, height: 26),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) =>
                        NovaColors.brandGradient.createShader(r),
                    child: Text('NOVA',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2)),
                  ),
                  Text(t('app.tagline'),
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: NovaColors.textSecondary)),
                ],
              ),
              const Spacer(),
              SkinAvatar(skinPath: profile?.skinPath, size: 40),
            ],
          ),
          const SizedBox(height: 16),

          // Version card
          staggered(0,
            NovaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('home.selectedVersion'),
                                style: const TextStyle(
                                    color: NovaColors.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              selected ?? t('home.chooseVersion'),
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        backgroundColor: NovaColors.violet.withOpacity(0.2),
                        side: BorderSide.none,
                        label: Text(
                          ref.watch(selectedLoaderProvider).name.toUpperCase(),
                          style: const TextStyle(
                              color: NovaColors.violet, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _stat(t('home.installStatus'),
                          selectedInstalled.isNotEmpty
                              ? t('versions.installed')
                              : t('home.notInstalled')),
                      _stat(t('home.storage'),
                          selectedInstalled.isNotEmpty
                              ? NovaUtils.formatBytes(
                                  selectedInstalled.first.sizeBytes)
                              : '—'),
                      _stat(
                          t('home.ram'),
                          specsAsync.when(
                              data: (s) => s.totalRamMb > 0
                                  ? '${NovaUtils.formatBytes(s.availableRamBytes)} / ${NovaUtils.formatBytes(s.totalRamBytes)}'
                                  : '—',
                              loading: () => '…',
                              error: (_, __) => '—')),
                      _stat(t('home.performance'),
                          t('perf.${ref.read(coreProvider).prefs.perfProfile.name}')),
                      if (profile != null)
                        _stat(t('home.lastProfile'), profile.name),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: NovaGradientButton(
                      label: _playLabel(t, playState),
                      icon: _playIcon(playState),
                      onPressed: playState == PlayState.preparing
                          ? null
                          : _onPlay,
                    ),
                  ),
                  if (install.kind == InstallKind.downloading) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: install.totalBytes > 0
                            ? (install.doneBytes / install.totalBytes)
                                .clamp(0.0, 1.0)
                            : null,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NovaUtils.formatBytes(install.doneBytes)} / ${NovaUtils.formatBytes(install.totalBytes)}  •  ${NovaUtils.formatSpeed(install.speed)}',
                      style: const TextStyle(
                          fontSize: 11, color: NovaColors.textSecondary),
                    ),
                  ],
                  if (install.kind == InstallKind.failed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: NovaColors.danger, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(install.error,
                              style: const TextStyle(
                                  color: NovaColors.danger, fontSize: 12)),
                        ),
                        NovaOutlineButton(
                          label: t('versions.retry'),
                          onPressed: _startInstall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Runtime bridge card
          staggered(1, _RuntimeCard(onMissing: () => _showRuntimeDialog(t))),
          const SizedBox(height: 14),

          // Shortcuts
          staggered(2, SectionTitle(t('home.shortcuts'))),
          staggered(3,
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                _shortcut(Icons.extension_outlined, t('home.mods'), () {
                  ref.read(contentTabProvider.notifier).state = 0;
                  context.go('/content');
                }),
                _shortcut(Icons.map_outlined, t('home.maps'), () {
                  ref.read(contentTabProvider.notifier).state = 1;
                  context.go('/content');
                }),
                _shortcut(Icons.palette_outlined, t('home.resources'), () {
                  ref.read(contentTabProvider.notifier).state = 2;
                  context.go('/content');
                }),
                _shortcut(Icons.inventory_2_outlined, t('home.modpacks'), () {
                  ref.read(contentTabProvider.notifier).state = 3;
                  context.go('/content');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _playLabel(String Function(String) t, PlayState s) {
    switch (s) {
      case PlayState.notInstalled:
        return t('home.install');
      case PlayState.needsDownload:
        return t('home.download');
      case PlayState.preparing:
        return t('home.preparing');
      case PlayState.running:
        return t('home.running');
      case PlayState.ready:
        return t('home.play');
    }
  }

  IconData _playIcon(PlayState s) {
    switch (s) {
      case PlayState.ready:
        return Icons.play_arrow_rounded;
      case PlayState.preparing:
        return Icons.hourglass_top;
      case PlayState.running:
        return Icons.videogame_asset;
      default:
        return Icons.download_rounded;
    }
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: NovaColors.surfaceLight.withOpacity(0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5, color: NovaColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: NovaColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _shortcut(IconData icon, String label, VoidCallback onTap) {
    return NovaGlassCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: NovaColors.electricBlue, size: 26),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _RuntimeCard extends ConsumerWidget {
  const _RuntimeCard({required this.onMissing});
  final VoidCallback onMissing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final runtimesAsync = ref.watch(runtimesProvider);
    return NovaGlassCard(
      child: runtimesAsync.when(
        data: (runtimes) => runtimes.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: NovaColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(t('home.runtimeMissing'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t('home.runtimeHint'),
                      style: const TextStyle(
                          fontSize: 12, color: NovaColors.textSecondary)),
                  const SizedBox(height: 10),
                  NovaOutlineButton(
                    label: t('home.installRuntime'),
                    icon: Icons.download_rounded,
                    onPressed: () => context.go('/settings'),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.videogame_asset,
                      color: NovaColors.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('home.runtime'),
                            style: const TextStyle(
                                fontSize: 11,
                                color: NovaColors.textSecondary)),
                        Text(
                          runtimes.map((r) => r.name).join(', '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  NovaGradientButton(
                    label: t('home.launchRuntime'),
                    height: 42,
                    onPressed: () async {
                      await ref
                          .read(runtimeBridgeProvider)
                          .launch(runtimes.first.packageName,
                              versionId: ref.read(selectedVersionIdProvider));
                      ref.invalidate(runtimesProvider);
                    },
                  ),
                ],
              ),
        loading: () => const SizedBox(
            height: 40, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text(t('error.generic')),
      ),
    );
  }
}
