import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/core/strings.dart';

void main() {
  test('all locales cover core keys', () {
    const keys = [
      'nav.home',
      'home.play',
      'versions.title',
      'settings.title',
      'servers.add',
      'mods.optimize',
    ];
    for (final locale in ['en', 'ar', 'fr']) {
      for (final k in keys) {
        expect(NovaStrings.tr(locale, k), isNot(equals(k)),
            reason: '$locale missing $k');
      }
    }
  });

  test('arabic values are arabic', () {
    expect(NovaStrings.tr('ar', 'nav.home'), 'الرئيسية');
    expect(NovaStrings.tr('ar', 'home.play'), 'تشغيل');
  });

  test('unknown keys fall back to the key', () {
    expect(NovaStrings.tr('en', 'no.such.key'), 'no.such.key');
  });
}
