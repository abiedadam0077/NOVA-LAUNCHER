import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../domain/core.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';
import 'widgets/skin_widgets.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final profiles = ref.watch(profilesProvider);
    final current = profiles.where((p) => p.isDefault).toList();
    final profile =
        current.isNotEmpty ? current.first : (profiles.isNotEmpty ? profiles.first : null);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        children: [
          Text(t('account.title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // Current profile card + 3D viewer
          NovaGlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    SkinAvatar(skinPath: profile?.skinPath, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.name ?? '—',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: profile?.type == 'microsoft'
                                  ? NovaColors.success.withOpacity(0.15)
                                  : NovaColors.violet.withOpacity(0.15),
                            ),
                            child: Text(
                              profile?.type == 'microsoft'
                                  ? t('account.microsoft')
                                  : t('account.localProfile'),
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: profile?.type == 'microsoft'
                                      ? NovaColors.success
                                      : NovaColors.violet),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t('account.addLocal'),
                      icon: const Icon(Icons.person_add_alt_1_outlined,
                          color: NovaColors.electricBlue),
                      onPressed: _addProfile,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: SkinViewer3D(
                    skinPath: profile?.skinPath,
                    slim: profile?.skinModel == 'slim',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NovaOutlineButton(
                      label: t('account.chooseSkin'),
                      icon: Icons.image_outlined,
                      onPressed: () => _chooseSkin(profile),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: Text(t(profile?.skinModel == 'slim'
                          ? 'account.skinSlim'
                          : 'account.skinClassic')),
                      selected: true,
                      onSelected: (_) async {
                        if (profile == null) return;
                        final next =
                            profile.skinModel == 'slim' ? 'classic' : 'slim';
                        await ref
                            .read(accountServiceProvider)
                            .setSkin(profile, profile.skinPath, model: next);
                        await ref.read(profilesProvider.notifier).reload();
                      },
                      selectedColor: NovaColors.electricBlue.withOpacity(0.25),
                      side: BorderSide.none,
                      backgroundColor: NovaColors.surfaceLight,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(t('nav.account')),
          ...profiles.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NovaGlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      SkinAvatar(skinPath: p.skinPath, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (p.isDefault)
                        const Icon(Icons.star,
                            color: NovaColors.warning, size: 18),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: NovaColors.textSecondary),
                        onPressed: () => _rename(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: NovaColors.danger),
                        onPressed: () async {
                          await ref.read(accountServiceProvider).remove(p);
                          await ref.read(profilesProvider.notifier).reload();
                        },
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),

          // Microsoft connect
          NovaGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key_outlined,
                        color: NovaColors.electricBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t('account.microsoft'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                NovaOutlineButton(
                  label: t('account.msConnect'),
                  icon: Icons.login_outlined,
                  onPressed: () => _connectMicrosoft(profile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfile() async {
    final t = ref.read(stringsProvider);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('account.addLocal')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: NovaColors.textPrimary),
          decoration: InputDecoration(hintText: t('account.username')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t('common.confirm'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(accountServiceProvider).createLocal(name);
    await ref.read(profilesProvider.notifier).reload();
  }

  Future<void> _rename(UserProfile p) async {
    final t = ref.read(stringsProvider);
    final ctrl = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('account.username')),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: NovaColors.textPrimary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t('common.confirm'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(accountServiceProvider).rename(p, name);
    await ref.read(profilesProvider.notifier).reload();
  }

  Future<void> _chooseSkin(UserProfile? profile) async {
    if (profile == null) return;
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['png']);
    if (res?.files.single.path == null) return;
    final svc = ref.read(accountServiceProvider);
    final path = await svc.importSkin(res!.files.single.path!);
    await svc.setSkin(profile, path, model: profile.skinModel);
    await ref.read(profilesProvider.notifier).reload();
  }

  Future<void> _connectMicrosoft(UserProfile? profile) async {
    final t = ref.read(stringsProvider);
    final core = NovaCore.instance;
    final clientId = core.prefs.msClientId;
    final auth = core.msAuth;
    if (!auth.hasClientId(clientId)) {
      final ctrl = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NovaColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Microsoft Azure Client ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Microsoft requires a registered Azure application for Minecraft sign-in. '
                'Enter your Azure client id; NOVA never sees your password (device flow).',
                style: TextStyle(
                    fontSize: 12, color: NovaColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: NovaColors.textPrimary),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('common.cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(t('common.confirm'))),
          ],
        ),
      );
      if (entered == null || entered.isEmpty) return;
      await core.prefs.setMsClientId(entered);
    }
    final id = core.prefs.msClientId;
    if (id == null) return;

    final code = await auth.startDeviceCode(id);
    if (code == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('error.network'))));
      }
      return;
    }
    bool cancelled = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('account.msConnect')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('account.msCode')),
            const SizedBox(height: 10),
            Text(code.userCode,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: NovaColors.electricBlue)),
            const SizedBox(height: 10),
            Text(code.verificationUri,
                style: const TextStyle(
                    fontSize: 12, color: NovaColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.pop(ctx);
              },
              child: Text(t('common.cancel'))),
        ],
      ),
    );
    final token = await auth.pollToken(
      clientId: id,
      code: code,
      isCancelled: () => cancelled,
    );
    if (mounted && context.mounted) Navigator.pop(context);
    if (token == null) return;
    await ref.read(accountServiceProvider).storeMsToken(token);
    final mcProfile = await auth.completeChain(token);
    if (mcProfile == null) return;
    final svc = ref.read(accountServiceProvider);
    final pr = UserProfile(
      id: 'ms_${mcProfile.uuid}',
      name: mcProfile.name,
      type: 'microsoft',
      isDefault: true,
    );
    await svc.setSkin(pr, null);
    await core.db.saveProfile(pr);
    await ref.read(profilesProvider.notifier).reload();
  }
}
