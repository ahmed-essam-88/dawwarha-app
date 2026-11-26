import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/shell/main_shell.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ar = S(true);

Future<void> boot(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(393 * 2, 728 * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: const MainShell())));
  await t.pumpAndSettle();
}

Future<void> tapModule(WidgetTester t, String label) async {
  final f = find.text(label);
  await t.scrollUntilVisible(f, 100, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
  // The card must sit fully above the bottom navigation bar (not hidden behind it).
  final nav = t.getTopLeft(find.byType(NavigationBar)).dy;
  expect(t.getBottomLeft(f).dy, lessThan(nav), reason: '$label hidden behind the nav bar');
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> back(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).last)).pop();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('every home module is reachable by scrolling and opens its screen', (t) async {
    await boot(t);
    await tapModule(t, ar.t('education'));
    expect(find.text(ar.t('plastic')), findsWidgets);
    await back(t);
    await t.pumpAndSettle();
    await tapModule(t, ar.t('game'));
    expect(find.byKey(const Key('g_habit')), findsOneWidget);
    await back(t);
    await t.pumpAndSettle();
    await tapModule(t, ar.t('prices'));
    expect(find.textContaining('ج.م'), findsWidgets);
    await back(t);
    await t.pumpAndSettle();
    await tapModule(t, ar.t('scanner'));
    expect(find.byKey(const Key('organicLimit')), findsOneWidget);
    await t.tap(find.text(ar.t('tabHome')));
    await t.pumpAndSettle();
    await tapModule(t, ar.t('collection'));
    expect(find.byKey(const Key('useLoc')), findsOneWidget);
  });

  testWidgets('bottom tabs switch screens (home, scan, pickup, profile)', (t) async {
    await boot(t);
    await t.tap(find.text(ar.t('tabScan')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('organicLimit')), findsOneWidget);
    await t.tap(find.text(ar.t('tabPickup')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('useLoc')), findsOneWidget);
    await t.tap(find.text(ar.t('tabProfile')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('email')), findsOneWidget);
    await t.tap(find.text(ar.t('tabHome')));
    await t.pumpAndSettle();
    expect(find.text(ar.t('features')), findsOneWidget);
  });
}
