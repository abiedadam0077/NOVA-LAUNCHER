import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/download_manager.dart';

import '../core/colors.dart';
import '../core/utils.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';

class ContentScreen extends ConsumerWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final tab = ref.watch(contentTabProvider);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Text(t('nav.content'),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _tab(ref, t('content.mods'), 0, tab),
                _tab(ref, t('content.maps'), 1, tab),
                _tab(ref, t('content.resources'), 2, tab),
                _tab(ref, t('content.modpacks'), 3, tab),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: [
              const _ModsTab(),
              const _MapsTab(),
              const _ResourcesTab(),
              const _ModpacksTab(),
            ][tab],
          ),
        ],
      ),
    );
  }

  Widget _tab(WidgetRef ref, String label, int i, int current) {
    final selected = i == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) =>
            ref.read(contentTabProvider.notifier).state = i,
        showCheckmark: false,
        selectedColor: NovaColors.electricBlue.withOpacity(0.25),
        labelStyle: TextStyle(
          color: selected ? NovaColors.electricBlue : NovaColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        side: BorderSide.none,
        backgroundColor: NovaColors.surface.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// =================================================================== MODS

class _ModsTab extends ConsumerStatefulWidget {
  const _ModsTab();

  @override
  ConsumerState<_ModsTab> createState() => _ModsTabState();
}

class _ModsTabState extends ConsumerState<_ModsTab> {
  bool _catalog = false;
  String _query = '';
  List<CatalogProject> _results = const [];
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final mods = ref.watch(modsProvider);
    final filtered = mods
        .where((m) =>
            (m.title ?? m.fileName).toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: NovaGradientButton(
                  label: t('mods.optimize'),
                  icon: Icons.speed,
                  height: 46,
                  onPressed: _optimize,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    if (_catalog) _searchCatalog();
                  }),
                  style: const TextStyle(color: NovaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: t('common.search'),
                    hintStyle:
                        const TextStyle(color: NovaColors.textSecondary),
                    filled: true,
                    fillColor: NovaColors.surface.withOpacity(0.7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: t('mods.import'),
                icon: const Icon(Icons.file_upload_outlined,
                    color: NovaColors.electricBlue),
                onPressed: _importMod,
              ),
              IconButton(
                tooltip: t('mods.browse'),
                icon: Icon(
                  _catalog ? Icons.library_add_check : Icons.travel_explore,
                  color: NovaColors.violet,
                ),
                onPressed: () {
                  setState(() => _catalog = !_catalog);
                  if (_catalog) _searchCatalog();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _catalog ? _catalogList() : _localList(filtered),
        ),
      ],
    );
  }

  Widget _localList(List<ModInfo> mods) {
    final t = ref.read(stringsProvider);
    if (mods.isEmpty) return NovaEmpty(message: t('common.empty'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      itemCount: mods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = mods[i];
        final duplicate = mods
            .where((o) => o.fileName == m.fileName && o.id != m.id)
            .isNotEmpty;
        return NovaGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.extension,
                  color: m.enabled
                      ? NovaColors.electricBlue
                      : NovaColors.textSecondary,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title ?? m.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (m.modVersion != null)
                          _tag('v${m.modVersion}'),
                        if (m.loader != null) _tag(m.loader!),
                        if (m.mcVersion != null) _tag('MC ${m.mcVersion}'),
                        if (m.category != null) _tag(m.category!),
                        if (duplicate)
                          _tag(t('mods.duplicate'), color: NovaColors.warning),
                        if (m.enabled)
                          _tag(t('mods.enabled'), color: NovaColors.success)
                        else
                          _tag(t('mods.disabled')),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: m.enabled,
                activeColor: NovaColors.electricBlue,
                onChanged: (v) async {
                  await ref.read(modServiceProvider).setEnabled(m, v);
                  await ref.read(modsProvider.notifier).reload();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: NovaColors.danger, size: 20),
                onPressed: () async {
                  await ref.read(modServiceProvider).remove(m);
                  await ref.read(modsProvider.notifier).reload();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _catalogList() {
    final t = ref.read(stringsProvider);
    if (_searching) return NovaLoading(label: t('common.loading'));
    if (_results.isEmpty) return NovaEmpty(message: t('common.empty'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = _results[i];
        return NovaGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => _openCatalogProject(p),
          child: Row(
            children: [
              if (p.iconUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(p.iconUrl!,
                      width: 40, height: 40,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.extension, color: NovaColors.textSecondary)),
                )
              else
                const Icon(Icons.extension, color: NovaColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${p.downloads} downloads',
                      style: const TextStyle(
                          fontSize: 11, color: NovaColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: NovaColors.textSecondary),
            ],
          ),
        );
      },
    );
  }

  Widget _tag(String s, {Color color = NovaColors.textSecondary}) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.15),
        ),
        child: Text(s, style: TextStyle(fontSize: 10, color: color)),
      );

  Future<void> _importMod() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['jar']);
    if (res == null || res.files.single.path == null) return;
    final svc = ref.read(modServiceProvider);
    final imported = await svc.importFile(res.files.single.path!);
    await ref.read(modsProvider.notifier).reload();
    if (mounted) {
      final t = ref.read(stringsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(imported == null
              ? t('mods.duplicate')
              : t('common.success'))));
    }
  }

  Future<void> _searchCatalog() async {
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(coreProvider)
          .modrinth
          .search(query: _query, projectType: 'mod', limit: 25);
      if (mounted) setState(() => _results = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openCatalogProject(CatalogProject p) async {
    final t = ref.read(stringsProvider);
    final versions = await ref.read(coreProvider).modrinth.versions(p.slug);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(p.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(p.description,
              style: const TextStyle(
                  fontSize: 12, color: NovaColors.textSecondary)),
          const SizedBox(height: 6),
          Text('${t('mods.source')}: modrinth.com',
              style: const TextStyle(
                  fontSize: 11, color: NovaColors.textSecondary)),
          const SizedBox(height: 14),
          ...versions.take(10).map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    '${v.loaders.join(', ')} • ${v.mcVersions.take(3).join(', ')}',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.download_rounded,
                      color: NovaColors.electricBlue),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (v.files.isEmpty) return;
                    final file = v.files.first;
                    final core = ref.read(coreProvider);
                    final dest = '${core.paths.mods}/${file.fileName}';
                    final results = await core.downloads.runAll([
                      DownloadTask(
                        id: 'cat:${p.slug}:${v.id}',
                        url: file.url,
                        destPath: dest,
                        expectedSize: file.size,
                      ),
                    ]);
                    if (results.values.first == true) {
                      await ref.read(modServiceProvider).importFile(dest,
                          versionId: ref.read(selectedVersionIdProvider));
                      await ref.read(modsProvider.notifier).reload();
                    }
                  },
                ),
              )),
          TextButton(
            onPressed: () => launchUrl(Uri.parse(p.projectUrl),
                mode: LaunchMode.externalApplication),
            child: Text(t('mods.source')),
          ),
        ],
      ),
    );
  }



  Future<void> _optimize() async {
    final t = ref.read(stringsProvider);
    final version = ref.read(selectedVersionIdProvider);
    if (version == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('home.chooseVersion'))));
      return;
    }
    final loader = ref.read(selectedLoaderProvider).name;
    final mods = ref.read(modsProvider);
    showDialog(
      context: context,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    final plan = await ref.read(modServiceProvider).optimizePlan(
          gameVersion: version,
          loader: loader,
          alreadyInstalled: mods,
        );
    if (!mounted) return;
    Navigator.pop(context);
    if (plan.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('common.empty'))));
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('mods.optimizeTitle')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: plan
                .map((s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.speed,
                          color: NovaColors.electricBlue, size: 20),
                      title: Text(s.title, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                          '${s.loaders.join(', ')} • ${s.mcVersions.join(', ')}',
                          style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('mods.optimizeApply'))),
        ],
      ),
    );
    if (approved == true) {
      await ref.read(modServiceProvider).backup();
      final done =
          await ref.read(modServiceProvider).applySuggestions(plan);
      await ref.read(modsProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t('common.success')} ($done)')));
      }
    }
  }
}



// =================================================================== MAPS

class _MapsTab extends ConsumerStatefulWidget {
  const _MapsTab();

  @override
  ConsumerState<_MapsTab> createState() => _MapsTabState();
}

class _MapsTabState extends ConsumerState<_MapsTab> {
  List<WorldInfo> _worlds = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final worlds = await ref.read(mapServiceProvider).listWorlds();
    if (mounted) {
      setState(() {
        _worlds = worlds;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: NovaOutlineButton(
            label: t('maps.import'),
            icon: Icons.file_upload_outlined,
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles(
                  type: FileType.custom, allowedExtensions: ['zip']);
              if (res?.files.single.path == null) return;
              final ok = await ref
                  .read(mapServiceProvider)
                  .importZip(res!.files.single.path!);
              if (!ok && mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: NovaColors.surface,
                    title: Text(t('common.confirm')),
                    content: Text(t('common.error')),
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
                if (confirm == true) {
                  await ref
                      .read(mapServiceProvider)
                      .importZip(res.files.single.path!, overwrite: true);
                }
              }
              _load();
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? NovaLoading(label: t('common.loading'))
              : _worlds.isEmpty
                  ? NovaEmpty(message: t('common.empty'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      itemCount: _worlds.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final w = _worlds[i];
                        return NovaGlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.map_outlined,
                                  color: NovaColors.neonCyan, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(w.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      '${NovaUtils.formatBytes(w.sizeBytes)} • ${w.category}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: NovaColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: t('maps.backup'),
                                icon: const Icon(Icons.backup_outlined,
                                    size: 20, color: NovaColors.electricBlue),
                                onPressed: () async {
                                  await ref
                                      .read(mapServiceProvider)
                                      .backupWorld(w);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(t('common.success'))));
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: t('maps.delete'),
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: NovaColors.danger),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: NovaColors.surface,
                                      title: Text(t('common.delete')),
                                      content: Text(w.name),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(t('common.cancel'))),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(t('common.confirm'))),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await ref
                                        .read(mapServiceProvider)
                                        .deleteWorld(w);
                                    _load();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ============================================================== RESOURCES

class _ResourcesTab extends ConsumerStatefulWidget {
  const _ResourcesTab();

  @override
  ConsumerState<_ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends ConsumerState<_ResourcesTab> {
  String _kind = 'resourcepack';
  List<PackInfo> _packs = const [];
  bool _loading = true;
  final Set<String> _enabled = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final packs = await ref.read(resourceServiceProvider).listPacks(_kind);
    if (mounted) {
      setState(() {
        _packs = packs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              _kindChip('Resource Packs', 'resourcepack'),
              const SizedBox(width: 8),
              _kindChip('Shaders', 'shaderpack'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.file_upload_outlined,
                    color: NovaColors.electricBlue),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['zip']);
                  if (res?.files.single.path == null) return;
                  await ref
                      .read(resourceServiceProvider)
                      .import(res!.files.single.path!, _kind);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? NovaLoading(label: t('common.loading'))
              : _packs.isEmpty
                  ? NovaEmpty(message: t('common.empty'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      itemCount: _packs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final pack = _packs[i];
                        final on = _enabled.contains(pack.name);
                        return NovaGlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              pack.previewPath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                          File(pack.previewPath!),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.palette),
                                      ),
                                    )
                                  : const Icon(Icons.palette_outlined,
                                      color: NovaColors.violet, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pack.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      '${NovaUtils.formatBytes(pack.sizeBytes)}${pack.mcMetaVersion != null ? ' • pack_format ${pack.mcMetaVersion}' : ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: NovaColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: on,
                                activeColor: NovaColors.violet,
                                onChanged: (v) async {
                                  setState(() {
                                    if (v) {
                                      _enabled.add(pack.name);
                                    } else {
                                      _enabled.remove(pack.name);
                                    }
                                  });
                                  await ref
                                      .read(resourceServiceProvider)
                                      .setEnabledPacks(
                                          _kind, _enabled.toList());
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: NovaColors.danger),
                                onPressed: () async {
                                  await ref
                                      .read(resourceServiceProvider)
                                      .remove(pack);
                                  _load();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _kindChip(String label, String kind) {
    final selected = _kind == kind;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _kind = kind;
          _enabled.clear();
        });
        _load();
      },
      selectedColor: NovaColors.violet.withOpacity(0.3),
      labelStyle: TextStyle(
          fontSize: 12,
          color: selected ? NovaColors.violet : NovaColors.textSecondary),
      side: BorderSide.none,
      backgroundColor: NovaColors.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ============================================================== MODPACKS

class _ModpacksTab extends ConsumerStatefulWidget {
  const _ModpacksTab();

  @override
  ConsumerState<_ModpacksTab> createState() => _ModpacksTabState();
}

class _ModpacksTabState extends ConsumerState<_ModpacksTab> {
  List<CatalogProject> _results = const [];
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final r = await ref
          .read(coreProvider)
          .modrinth
          .search(query: _query, projectType: 'modpack', limit: 20);
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(color: NovaColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: t('common.search'),
                    hintStyle:
                        const TextStyle(color: NovaColors.textSecondary),
                    filled: true,
                    fillColor: NovaColors.surface.withOpacity(0.7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: NovaColors.electricBlue),
                onPressed: _search,
              ),
              IconButton(
                tooltip: t('maps.import'),
                icon: const Icon(Icons.file_upload_outlined,
                    color: NovaColors.violet),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['mrpack']);
                  if (res?.files.single.path == null) return;
                  await ref
                      .read(modpackServiceProvider)
                      .installMrpack(res!.files.single.path!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('common.success'))));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _searching
              ? NovaLoading(label: t('common.loading'))
              : _results.isEmpty
                  ? NovaEmpty(message: t('common.empty'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        return NovaGlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          onTap: () => _downloadPack(p),
                          child: Row(
                            children: [
                              if (p.iconUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(p.iconUrl!,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.inventory_2_outlined)),
                                )
                              else
                                const Icon(Icons.inventory_2_outlined,
                                    color: NovaColors.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text('${p.downloads}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: NovaColors.textSecondary)),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _downloadPack(CatalogProject p) async {
    final t = ref.read(stringsProvider);
    final versions = await ref.read(coreProvider).modrinth.versions(p.slug);
    if (versions.isEmpty || versions.first.files.isEmpty) return;
    final file = versions.first.files.first;
    final core = ref.read(coreProvider);
    final dest = '${core.paths.modpacks}/${file.fileName}';
    final results = await core.downloads.runAll([
      DownloadTask(
        id: 'modpack:${p.slug}',
        url: file.url,
        destPath: dest,
        expectedSize: file.size,
      ),
    ]);
    if (results.values.first == true) {
      await ref.read(modpackServiceProvider).installMrpack(dest);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('common.success'))));
      }
    }
  }
}


