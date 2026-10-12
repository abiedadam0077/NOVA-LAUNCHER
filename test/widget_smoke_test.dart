import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_launcher/core/colors.dart';
import 'package:nova_launcher/core/theme.dart';
import 'package:nova_launcher/presentation/widgets/core_widgets.dart';

Widget _app({String locale = 'en', required Widget child}) {
  return MaterialApp(
    theme: NovaTheme.dark,
    locale: Locale(locale),
    supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      backgroundColor: NovaColors.bg,
      body: Center(child: child),
    ),
  );
}

void main() {
  testWidgets('gradient button renders label and taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(_app(
      child: NovaGradientButton(label: 'PLAY', onPressed: () => taps++),
    ));
    expect(find.text('PLAY'), findsOneWidget);
    await tester.tap(find.text('PLAY'));
    expect(taps, 1);
  });

  testWidgets('RTL layout is applied for Arabic', (tester) async {
    await tester.pumpWidget(_app(
      locale: 'ar',
      child: const Row(
        textDirection: TextDirection.rtl,
        children: [
          Text('أ'),
          Text('ب'),
        ],
      ),
    ));
    final a = tester.getTopRight(find.text('أ'));
    final b = tester.getTopRight(find.text('ب'));
    // In RTL the first item sits to the right of the second.
    expect(a.dx, greaterThan(b.dx));
  });

  testWidgets('error state shows retry', (tester) async {
    int retries = 0;
    await tester.pumpWidget(_app(
      child: NovaError(message: 'boom', onRetry: () => retries++),
    ));
    expect(find.text('boom'), findsOneWidget);
  });
}
