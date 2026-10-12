import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/core.dart';
import '../domain/models.dart';

/// NOVA SMART PERFORMANCE — device-derived presets written to options.txt.
class PerformanceService {
  PerformanceService(this.core);
  final NovaCore core;

  static const MethodChannel _ch = MethodChannel('nova/device');

  /// Reads only legal Android device info; unknown values stay unknown.
  Future<DeviceSpecs> readDeviceSpecs() async {
    try {
      final map = await _ch.invokeMapMethod('getDeviceInfo');
      if (map == null) return DeviceSpecs.unknown;
      return DeviceSpecs.fromMap(map);
    } catch (_) {
      return DeviceSpecs.unknown; // e.g. running in tests
    }
  }

  PerfPreset presetFor(PerfProfileId id, DeviceSpecs specs) =>
      PerfPreset.forDevice(specs, id);

  /// Merges the preset into the real options.txt of the game directory.
  Future<void> applyOptions(PerfPreset preset) async {
    final f = File(core.paths.optionsTxt);
    final map = <String, String>{};
    if (f.existsSync()) {
      for (final l in f.readAsLinesSync()) {
        final i = l.indexOf(':');
        if (i > 0) map[l.substring(0, i)] = l.substring(i + 1);
      }
    }
    map.addAll(preset.toOptions());
    await f.writeAsString(
        map.entries.map((e) => '${e.key}:${e.value}').join('\n') + '\n');
    core.logs.add('performance', 'Applied preset ${preset.id.name}');
  }
}
