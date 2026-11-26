import 'package:environmental_challenges/app.dart';
import 'package:environmental_challenges/features/game/game_data.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every game item has a valid answer and 5 per level', () {
    for (final l in gameLevels) {
      expect(l.length, 5);
      for (final i in l) {
        expect(i.expAr.isNotEmpty && i.expEn.isNotEmpty, true);
      }
      for (final i in l) {
        expect(['plastic', 'metal', 'glass', 'paper', 'organic'], contains(i.answer));
      }
    }
  });

  testWidgets('level 1 can be played, passing unlocks level 2', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(ChangeNotifierProvider(create: (_) => LocaleProvider(), child: const EnvChallengesApp()));
    await t.pumpAndSettle();
    await t.tap(find.text('لعبة التدوير'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('g_quiz'))); await t.pumpAndSettle();
    expect(find.text('المستوى 2'), findsOneWidget);
    expect(find.text('اضغط للعب'), findsOneWidget); // only level 1 open
    await t.tap(find.text('المستوى 1'));
    await t.pumpAndSettle();
    const ar = {'plastic': 'البلاستيك', 'metal': 'المعادن', 'glass': 'الزجاج', 'paper': 'الورق', 'organic': 'المخلفات العضوية'};
    for (final item in gameLevels[0]) {
      await t.tap(find.widgetWithText(OutlinedButton, ar[item.answer]!));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'التالي'));
      await t.pumpAndSettle();
    }
    expect(find.text('5 / 5'), findsOneWidget);
    await t.tap(find.text('رجوع للمستويات'));
    await t.pumpAndSettle();
    expect(find.text('اضغط للعب'), findsNWidgets(2));
  });
}
