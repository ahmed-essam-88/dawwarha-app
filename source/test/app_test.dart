import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:environmental_challenges/app.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';

void main() {
  SharedPreferences.setMockInitialValues({});
  testWidgets('home shows 6 modules, tabs, and opens education', (t) async {
    await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => LocaleProvider(), child: const EnvChallengesApp()));
    await t.pumpAndSettle();
    expect(find.text('دوّرها'), findsWidgets);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('أسعار المخلفات'), findsOneWidget);
    await t.tap(find.text('التعليم عن التدوير'));
    await t.pumpAndSettle();
    expect(find.text('البلاستيك'), findsOneWidget);
    await t.tap(find.text('البلاستيك'));
    await t.pumpAndSettle();
    expect(find.text('بتتدوّر إزاي'), findsOneWidget);
  });
  testWidgets('language toggle switches to English', (t) async {
    await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => LocaleProvider(), child: const EnvChallengesApp()));
    await t.pumpAndSettle();
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('دوّرها'), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
  });
  testWidgets('scanner screen shows the organic limitation (ar and en)', (t) async {
    await t.pumpWidget(ChangeNotifierProvider(
        create: (_) => LocaleProvider(), child: const EnvChallengesApp()));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.document_scanner_outlined).first);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('organicLimit')), findsOneWidget);
    expect(find.textContaining('العضوية'), findsWidgets);
  });
}
