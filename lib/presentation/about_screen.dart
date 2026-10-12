import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import 'widgets/core_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.bg,
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          NovaGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/nova_logo.png',
                        width: 44, height: 44),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOVA Launcher',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('v0.1.0',
                            style: TextStyle(
                                fontSize: 12,
                                color: NovaColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'A Premium Minecraft Java Launcher for Android.\n'
                  'NOVA prepares official game files and bridges to open-source '
                  'Android runtimes. Not affiliated with Mojang or Microsoft.',
                  style: TextStyle(fontSize: 12, color: NovaColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NovaGlassCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Licenses',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text(
                  '• NOVA Launcher code — MIT\n'
                  '• Amethyst/PojavLauncher runtime — LGPL-3.0\n'
                  '• Zalith/FoldCraft references — GPL-3.0\n'
                  '• Minecraft — © Mojang AB (files downloaded by the user '
                  'from official Mojang servers)\n'
                  '• Mod catalog data — Modrinth API (content under each '
                  'mod\'s own license)',
                  style:
                      TextStyle(fontSize: 12, color: NovaColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NovaGlassCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text(
                  'NOVA collects no personal data. Profiles, servers, mods and '
                  'settings stay on your device. Microsoft sign-in uses the '
                  'official device-code flow; NOVA never sees your password. '
                  'Network calls go only to Mojang, Fabric, Modrinth and '
                  'GitHub release endpoints.',
                  style:
                      TextStyle(fontSize: 12, color: NovaColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
