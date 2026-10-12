import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/core/utils.dart';

void main() {
  test('version comparison is numeric-aware', () {
    expect(NovaUtils.compareVersions('1.20.1', '1.20'), greaterThan(0));
    expect(NovaUtils.compareVersions('1.9', '1.10'), lessThan(0));
    expect(NovaUtils.compareVersions('1.20', '1.20'), 0);
    expect(NovaUtils.compareVersions('1.7.10', '1.8.9'), lessThan(0));
  });

  test('byte formatting', () {
    expect(NovaUtils.formatBytes(512), '512 B');
    expect(NovaUtils.formatBytes(2048), '2.0 KB');
    expect(NovaUtils.formatBytes(5 * 1024 * 1024), '5.0 MB');
  });
}
