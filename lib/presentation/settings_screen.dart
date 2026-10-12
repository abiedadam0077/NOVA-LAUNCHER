import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/colors.dart';
import '../core/motion.dart';
import '../core/utils.dart';
import '../data/paths.dart';
import '../domain/core.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import '../domain/runtime_bridge.dart';
import 'widgets/core_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _installingRuntime = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final core = ref.read(coreProvider);
    final locale = ref.watch(localeProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        children: [
          Text(t('settings.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),

          // ---------------- GENERAL
          SectionTitle(t('settings.general')),
          NovaGlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_outlined,
                        color: NovaColors.electricBlue),
                    const SizedBox(width: 12),
                    Text(t('settings.language')),
                    const Spacer(),
                    DropdownButton<String>(
                      value: locale,
                      dropdownColor: NovaColors.surface,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        ref.read(localeProvider.notifier).state = v;
                        await core.prefs.setLocale(v);
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: NovaColors.electricBlue,
                  title: Text(t('settings.reducedMotion')),
                  value: NovaMotion.reduced,
                  onChanged: (v) async {
                    NovaMotion.reduced = v;
                    await core.prefs.setReducedMotion(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---------------- MINECRAFT
          SectionTitle(t('settings.minecraft')),
          NovaGlassCard(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                _row(Icons.folder_outlined, t('settings.fileManager'),
                    () => context.go('/settings/files')),
                _row(Icons.dns_outlined, t('settings.servers'),
                    () => context.go('/settings/servers')),
                _row(Icons.tune_outlined, t('settings.gameSettings'),
                    () => context.go('/settings/game')),
                _row(Icons.info_outline, t('settings.about'),
                    () => context.go('/settings/about')),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---------------- RUNTIME
          SectionTitle(t('home.runtime')),
          NovaGlassCard(
            child: _RuntimeInstallRow(
              installing: _installingRuntime,
              onInstall: () async {
                setState(() => _installingRuntime = true);
                try {
                  final bridge = ref.read(runtimeBridgeProvider);
                  final rel = await bridge.latestRelease();
                  if (rel == null) throw Exception('no release');
                  final ok = await bridge.installRuntime(rel);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? t('common.success') : t('error.generic'))));
                    ref.invalidate(runtimesProvider);
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('error.network'))));
                  }
                } finally {
                  if (mounted) setState(() => _installingRuntime = false);
                }
              },
            ),
          ),
          const SizedBox(height: 14),

          // ---------------- PERFORMANCE
          SectionTitle(t('settings.performance')),
          NovaGlassCard(child: const _PerformanceBlock()),
          const SizedBox(height: 14),

          // ---------------- STORAGE
          SectionTitle(t('settings.storage')),
          NovaGlassCard(child: const _StorageBlock()),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Icon(icon, color: NovaColors.electricBlue),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: NovaColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _RuntimeInstallRow extends ConsumerWidget {
  const _RuntimeInstallRow({required this.onInstall, required this.installing});
  final VoidCallback onInstall;
  final bool installing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final runtimesAsync = ref.watch(runtimesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        runtimesAsync.when(
          data: (runtimes) => runtimes.isEmpty
              ? Text(t('home.runtimeHint'),
                  style: const TextStyle(
                      fontSize: 12, color: NovaColors.textSecondary))
              : Text(
                  '${t('home.runtime')}: ${runtimes.map((r) => '${r.name} ${r.version}').join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        installing
            ? const Center(child: CircularProgressIndicator())
            : NovaOutlineButton(
                label: t('home.installRuntime'),
                icon: Icons.download_rounded,
                onPressed: onInstall,
              ),
        const SizedBox(height: 6),
        const Text(
          'Open-source runtimes: Amethyst (LGPL-3.0) / PojavLauncher / Zalith / FCL',
          style: TextStyle(fontSize: 10, color: NovaColors.textSecondary),
        ),
      ],
    );
  }
}

class _PerformanceBlock extends ConsumerStatefulWidget {
  const _PerformanceBlock();

  @override
  ConsumerState<_PerformanceBlock> createState() => _PerformanceBlockState();
}

class _PerformanceBlockState extends ConsumerState<_PerformanceBlock> {
  PerfProfileId? _current;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => setState(
        () => _current = ref.read(coreProvider).prefs.perfProfile));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final specsAsync = ref.watch(deviceSpecsProvider);
    final current = _current ?? PerfProfileId.balanced;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        specsAsync.when(
          data: (s) => _specsText(s, t),
          loading: () => const Text('…', style: TextStyle(fontSize: 12)),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PerfProfileId.values.map((id) {
            final selected = id == current;
            return ChoiceChip(
              label: Text(t('perf.${id.name}')),
              selected: selected,
              onSelected: (_) async {
                await ref.read(coreProvider).prefs.setPerfProfile(id);
                final specs = specsAsync.value ?? DeviceSpecs.unknown;
                await ref
                    .read(perfServiceProvider)
                    .applyOptions(PerfPreset.forDevice(specs, id));
                setState(() => _current = id);
              },
              selectedColor: NovaColors.electricBlue.withOpacity(0.25),
              side: BorderSide.none,
              backgroundColor: NovaColors.surfaceLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _specsText(DeviceSpecs s, String Function(String) t) {
    if (s.totalRamBytes == 0) {
      return const Text('Device info unavailable',
          style: TextStyle(fontSize: 12, color: NovaColors.textSecondary));
    }
    return Text(
      '${s.deviceModel}\nCPU: ${s.cpuName} (${s.abis.join(', ')})\nRAM: ${NovaUtils.formatBytes(s.totalRamBytes)} • Android ${s.androidVersion}\n${t('home.storage')}: ${NovaUtils.formatBytes(s.internalStorageFreeBytes)} free',
      style: const TextStyle(fontSize: 12, color: NovaColors.textSecondary),
    );
  }
}

class _StorageBlock extends ConsumerStatefulWidget {
  const _StorageBlock();

  @override
  ConsumerState<_StorageBlock> createState() => _StorageBlockState();
}

class _StorageBlockState extends ConsumerState<_StorageBlock> {
  Map<String, int> _sizes = {};

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final core = ref.read(coreProvider);
    final sizes = <String, int>{
      'versions': NovaPaths.dirSize(_dirOf(core, 'versions')),
      'libraries': NovaPaths.dirSize(_dirOf(core, 'libraries')),
      'assets': NovaPaths.dirSize(_dirOf(core, 'assets')),
      'mods': NovaPaths.dirSize(_dirOf(core, 'mods')),
      'saves': NovaPaths.dirSize(_dirOf(core, 'saves')),
      'resourcepacks': NovaPaths.dirSize(_dirOf(core, 'resourcepacks')),
      'shaderpacks': NovaPaths.dirSize(_dirOf(core, 'shaderpacks')),
    };
    if (mounted) setState(() => _sizes = sizes);
  }

  Directory _dirOf(NovaCore core, String name) =>
      Directory('${core.paths.root.path}/$name');

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final total = _sizes.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${t('home.storage')}: ${NovaUtils.formatBytes(total)}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._sizes.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(e.key,
                      style: const TextStyle(
                          fontSize: 12, color: NovaColors.textSecondary)),
                  const Spacer(),
                  Text(NovaUtils.formatBytes(e.value),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            )),
        const SizedBox(height: 8),
        NovaOutlineButton(
          label: t('settings.cleanCache'),
          icon: Icons.cleaning_services_outlined,
          onPressed: () async {
            final core = ref.read(coreProvider);
            final cfg = Directory(core.paths.config);
            if (cfg.existsSync()) {
              for (final f in cfg.listSync()) {
                if (f.path.contains('preview_')) await f.delete();
              }
            }
            _compute();
          },
        ),
      ],
    );
  }
}
