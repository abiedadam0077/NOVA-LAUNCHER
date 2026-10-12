import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/domain/models.dart';

void main() {
  test('no selection -> not installed', () {
    expect(
      PlayRules.compute(
          selectedVersion: null, installedIds: {}, downloading: false),
      PlayState.notInstalled,
    );
  });

  test('selected but missing files -> not installed', () {
    expect(
      PlayRules.compute(
          selectedVersion: '1.20.1', installedIds: {}, downloading: false),
      PlayState.notInstalled,
    );
  });

  test('downloading -> preparing even when installed', () {
    expect(
      PlayRules.compute(
          selectedVersion: '1.20.1',
          installedIds: {'1.20.1'},
          downloading: true),
      PlayState.preparing,
    );
  });

  test('installed + selected -> ready', () {
    expect(
      PlayRules.compute(
          selectedVersion: '1.20.1',
          installedIds: {'1.20.1', '1.19.4'},
          downloading: false),
      PlayState.ready,
    );
  });
}
