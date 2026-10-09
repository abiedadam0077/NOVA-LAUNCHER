import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../domain/core.dart';
import '../domain/models.dart';
import '../domain/providers.dart';
import 'widgets/core_widgets.dart';

/// Advanced game settings — validated before writing options.txt.
class GameSettingsScreen extends ConsumerStatefulWidget {
  const GameSettingsScreen({super.key});

  @override
  ConsumerState<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends ConsumerState<GameSettingsScreen> {
  double _render = 12;
  double _sim = 10;
  double _ram = 2048;
  bool _fancy = true;
  bool _vsync = false;
  int _particles = 1;
  final _jvm = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = NovaCore.instance.prefs;
    _render = (prefs.p.getInt('renderDistance') ?? 12).toDouble();
    _sim = (prefs.p.getInt('simDistance') ?? 10).toDouble();
    _ram = (prefs.p.getInt('ramMb') ?? 2048).toDouble();
    _jvm.text = prefs.p.getString('jvmArgs') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final specsAsync = ref.watch(deviceSpecsProvider);
    final maxRam = (specsAsync.value?.totalRamMb ?? 4096) ~/ 2;
    return Scaffold(
      backgroundColor: NovaColors.bg,
      appBar: AppBar(
        title: Text(t('settings.gameSettings')),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          NovaGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t('settings.renderDistance')}: ${_render.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: _render,
                  min: 2,
                  max: 32,
                  divisions: 30,
                  activeColor: NovaColors.electricBlue,
                  onChanged: (v) => setState(() => _render = v),
                ),
                Text('${t('settings.simDistance')}: ${_sim.toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: _sim,
                  min: 5,
                  max: 32,
                  divisions: 27,
                  activeColor: NovaColors.electricBlue,
                  onChanged: (v) => setState(() => _sim = v),
                ),
                Text(
                    '${t('settings.ram')}: ${(_ram / 1024).toStringAsFixed(1)} GB '
                    '(max $maxRam MB)',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: _ram.clamp(256, maxRam.toDouble().clamp(256, 8192)),
                  min: 256,
                  max: maxRam.toDouble().clamp(512, 8192),
                  divisions: 30,
                  activeColor: NovaColors.violet,
                  onChanged: (v) => setState(() => _ram = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: NovaColors.electricBlue,
                  title: Text(t('settings.graphics')),
                  subtitle: Text(_fancy ? 'Fancy' : 'Fast'),
                  value: _fancy,
                  onChanged: (v) => setState(() => _fancy = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: NovaColors.electricBlue,
                  title: Text(t('settings.vsync')),
                  value: _vsync,
                  onChanged: (v) => setState(() => _vsync = v),
                ),
                const Text('Particles',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                DropdownButton<int>(
                  value: _particles,
                  dropdownColor: NovaColors.surface,
                  underline: const SizedBox(),
                  items: [0, 1, 2]
                      .map((i) => DropdownMenuItem(
                          value: i, child: Text(['All', 'Decreased', 'Minimal'][i])))
                      .toList(),
                  onChanged: (v) => setState(() => _particles = v ?? 1),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _jvm,
                  style: const TextStyle(color: NovaColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: t('settings.jvmArgs'),
                    labelStyle:
                        const TextStyle(color: NovaColors.textSecondary),
                    filled: true,
                    fillColor: NovaColors.surfaceLight.withOpacity(0.5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: NovaGradientButton(
                    label: t('common.apply'),
                    icon: Icons.save_outlined,
                    onPressed: () async {
                      final prefs = NovaCore.instance.prefs;
                      await prefs.p.setInt('renderDistance', _render.toInt());
                      await prefs.p.setInt('simDistance', _sim.toInt());
                      await prefs.p.setInt('ramMb', _ram.toInt());
                      await prefs.p.setString('jvmArgs', _jvm.text);
                      final preset = PerfPreset(
                        id: PerfProfileId.custom,
                        renderDistance: _render.toInt(),
                        simulationDistance: _sim.toInt(),
                        graphicsFancy: _fancy,
                        particles: _particles,
                        vsync: _vsync,
                        maxFps: _vsync ? 60 : 260,
                        ao: 2,
                        ramMb: _ram.toInt(),
                      );
                      await ref
                          .read(perfServiceProvider)
                          .applyOptions(preset);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t('common.success'))));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


