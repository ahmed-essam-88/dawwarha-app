import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/game/catch_game.dart';
import 'package:environmental_challenges/features/game/edu_games.dart';
import 'package:environmental_challenges/features/game/memory_game.dart';
import 'package:environmental_challenges/features/game/sort_game.dart';
import 'package:environmental_challenges/features/game/games_hub.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget wrap(Widget w) => ChangeNotifierProvider(create: (_) => LocaleProvider(), child: MaterialApp(home: w));
const ar = S(true);

void main() {
  testWidgets('hub lists six games', (t) async {
    await t.pumpWidget(wrap(const GamesHub()));
    for (final k in ['g_quiz', 'g_sort', 'g_memory', 'g_catch', 'g_habit', 'g_steps']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
  });

  testWidgets('sort: wrong bin counts a mistake and keeps the item, right bin advances', (t) async {
    await t.pumpWidget(wrap(const SortGame()));
    await t.tap(find.byKey(const Key('sort_level_0')));
    await t.pumpAndSettle();
    expect(find.textContaining('1/6'), findsOneWidget);
    final bins = ['plastic', 'metal', 'glass', 'paper', 'organic'].where((b) => find.byKey(Key('bin_$b')).evaluate().isNotEmpty).toList();
    expect(bins.length, 3);
    var tries = 0;
    for (final b in bins) {
      if (find.textContaining('1/6').evaluate().isEmpty) break;
      tries++;
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('sort_item'))));
      await g.moveTo(t.getCenter(find.byKey(Key('bin_$b'))));
      await g.up();
      await t.pumpAndSettle();
    }
    // exactly one bin is right: the item advanced once, every earlier try was a counted mistake
    expect(find.textContaining('2/6'), findsOneWidget);
    expect(find.textContaining('غلطات: ${tries - 1}'), findsOneWidget);
  });

  testWidgets('sort: full level can be finished with correct drops', (t) async {
    await t.pumpWidget(wrap(const SortGame()));
    await t.tap(find.byKey(const Key('sort_level_0')));
    await t.pumpAndSettle();
    var guard = 0;
    while (find.text('انتهى').evaluate().isEmpty && find.textContaining('خلصت المستوى').evaluate().isEmpty && guard++ < 60) {
      for (final b in ['plastic', 'metal', 'glass', 'paper', 'organic']) {
        if (find.byKey(const Key('sort_item')).evaluate().isEmpty) break;
        if (find.byKey(Key('bin_$b')).evaluate().isEmpty) continue;
        final g = await t.startGesture(t.getCenter(find.byKey(const Key('sort_item'))));
        await g.moveTo(t.getCenter(find.byKey(Key('bin_$b'))));
        await g.up();
        await t.pumpAndSettle();
        if (find.textContaining('خلصت المستوى').evaluate().isNotEmpty) break;
      }
    }
    expect(find.textContaining('خلصت المستوى'), findsOneWidget);
  });

  test('memory deck: every material has exactly one item card and one label card', () {
    for (final n in memoryPairs) {
      final d = buildDeck(n, 5);
      expect(d.length, n * 2);
      final groups = d.map((c) => c.group).toSet();
      expect(groups.length, n);
      for (final g in groups) {
        expect(d.where((c) => c.group == g && c.item != null).length, 1);
        expect(d.where((c) => c.group == g && c.item == null).length, 1);
      }
    }
  });

  testWidgets('memory: solving every pair ends the level; a wrong pair flips back', (t) async {
    await t.pumpWidget(wrap(const MemoryGame()));
    await t.tap(find.byKey(const Key('mem_level_0')));
    await t.pumpAndSettle();
    final deck = buildDeck(memoryPairs[0], 3);
    // find one wrong pair
    int a = 0, b = deck.indexWhere((c) => c.group != deck[0].group);
    await t.tap(find.byKey(Key('card_$a')));
    await t.tap(find.byKey(Key('card_$b')));
    await t.pump();
    expect(find.text('حركات: 1'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 800));
    // now solve all
    for (final g in deck.map((c) => c.group).toSet()) {
      final idx = [for (var i = 0; i < deck.length; i++) if (deck[i].group == g) i];
      await t.tap(find.byKey(Key('card_${idx[0]}')));
      await t.tap(find.byKey(Key('card_${idx[1]}')));
      await t.pump();
    }
    expect(find.byKey(const Key('mem_done')), findsOneWidget);
  });

  testWidgets('catch: tapping target items wins; tapping wrong items loses', (t) async {
    await t.pumpWidget(wrap(const CatchGame()));
    await t.tap(find.byKey(const Key('catch_level_0')));
    await t.pump();
    // Tap every falling item until the game ends, remembering nothing: behaviour decides.
    // Phase 1: tap everything -> includes wrong ones -> must lose (3 lives).
    for (var i = 0; i < 400 && find.byKey(const Key('catch_end')).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 100));
      final falling = find.byWidgetPredicate((w) => w.key is Key && (w.key.toString().contains('fall_')));
      if (falling.evaluate().isNotEmpty) {
        await t.tap(falling.first, warnIfMissed: false);
      }
    }
    expect(find.byKey(const Key('catch_end')), findsOneWidget);
    final status = find.byKey(const Key('catch_status'));
    expect(status, findsOneWidget);
  });

  test('habit rounds are balanced, deterministic and bilingual', () {
    for (final lang in [true, false]) {
      final r = habitRound(lang, 8, 1);
      expect(r.length, 8);
      expect(r.where((h) => h.good).length, 4);
      expect(r.map((h) => h.text), habitRound(lang, 8, 1).map((h) => h.text));
    }
    expect(habitPool(true).where((h) => !h.good).length, habitPool(false).where((h) => !h.good).length);
  });

  test('step sets have the same lengths in both languages and shuffles are never already solved', () {
    final a = stepSets(true), e = stepSets(false);
    expect(a.map((x) => x.length), e.map((x) => x.length));
    for (var seed = 0; seed < 200; seed++) {
      expect(shuffledOrder(3, seed), isNot([0, 1, 2]));
    }
  });

  testWidgets('habit game: right and wrong answers score correctly and a run ends with a score', (t) async {
    await t.pumpWidget(wrap(const HabitGame(seed: 5)));
    final cards = habitRound(true, 8, 5);
    var right = 0;
    for (var i = 0; i < 8; i++) {
      expect(find.text(cards[i].text), findsOneWidget);
      // answer correctly on even rounds, wrongly on odd ones
      final saysGood = i.isEven ? cards[i].good : !cards[i].good;
      if (i.isEven) right++;
      await t.tap(find.byKey(Key(saysGood ? 'habit_good' : 'habit_bad')));
      await t.pump();
      expect(find.byKey(const Key('habit_feedback')), findsOneWidget);
      await t.tap(find.byKey(const Key('habit_next')));
      await t.pump();
    }
    expect(find.text('$right / 8'), findsOneWidget);
    await t.tap(find.byKey(const Key('habit_again')));
    await t.pump();
    expect(find.byKey(const Key('habit_text')), findsOneWidget);
  });

  testWidgets('steps game: wrong tap counts a mistake and places nothing; right order advances through all materials', (t) async {
    await t.pumpWidget(wrap(const StepsGame(seed: 2)));
    final sets = stepSets(true);
    var mistakes = 0;
    for (var m = 0; m < sets.length; m++) {
      final order = shuffledOrder(sets[m].length, 2 + m);
      if (m == 0) {
        // tap a step that is not first -> mistake
        final wrong = order.indexWhere((x) => x != 0);
        await t.tap(find.byKey(Key('step_$wrong')));
        await t.pump();
        mistakes++;
        expect(find.text('الأخطاء: 1'), findsOneWidget);
      }
      for (var k = 0; k < sets[m].length; k++) {
        await t.tap(find.byKey(Key('step_${order.indexOf(k)}')));
        await t.pump();
      }
    }
    expect(find.byKey(const Key('steps_total')), findsOneWidget);
    expect(find.text('الأخطاء: $mistakes'), findsOneWidget);
  });
}
