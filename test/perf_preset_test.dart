import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/domain/models.dart';

DeviceSpecs _specs(int ramMb) => DeviceSpecs(
      totalRamBytes: ramMb * 1024 * 1024,
      cpuName: 'test',
      androidVersion: '14',
    );

void main() {
  test('RAM allocation never exceeds half of device RAM', () {
    final low = PerfPreset.forDevice(_specs(2048), PerfProfileId.visual);
    expect(low.ramMb, lessThanOrEqualTo(1024));
    final high = PerfPreset.forDevice(_specs(12288), PerfProfileId.visual);
    expect(high.ramMb, lessThanOrEqualTo(4096));
  });

  test('LITE is strictly lighter than VISUAL', () {
    final lite = PerfPreset.forDevice(_specs(4096), PerfProfileId.lite);
    final visual = PerfPreset.forDevice(_specs(4096), PerfProfileId.visual);
    expect(lite.renderDistance, lessThan(visual.renderDistance));
    expect(lite.ramMb, lessThan(visual.ramMb));
  });

  test('options.txt keys are written', () {
    final p = PerfPreset.forDevice(_specs(4096), PerfProfileId.balanced);
    final opts = p.toOptions();
    expect(opts.containsKey('renderDistance'), true);
    expect(opts.containsKey('maxFps'), true);
    expect(opts['graphics'], 'true');
  });
}
