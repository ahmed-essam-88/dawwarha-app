import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../education/education_data.dart';

/// One habit card: text from the app's own education pages, and whether it is a good habit.
class Habit {
  final String text, material;
  final bool good;
  const Habit(this.text, this.material, this.good);
}

/// Good habits come from the 'sorting' and 'tips' lists, bad ones from 'mistakes'.
List<Habit> habitPool(bool arabic) => [
      for (final e in eduContents)
        for (final k in ['sorting', 'tips', 'mistakes'])
          for (final t in e.forLang(arabic)[k] ?? const <String>[]) Habit(t, e.category.key, k != 'mistakes')
    ];

/// A shuffled round of n habits with both good and bad ones.
List<Habit> habitRound(bool arabic, int n, int seed) {
  final r = Random(seed);
  final pool = habitPool(arabic);
  final good = pool.where((h) => h.good).toList()..shuffle(r);
  final bad = pool.where((h) => !h.good).toList()..shuffle(r);
  final nBad = n ~/ 2;
  return [...bad.take(nBad), ...good.take(n - nBad)]..shuffle(r);
}

/// The process steps (in correct order) for each material.
List<List<String>> stepSets(bool arabic) => [for (final e in eduContents) e.forLang(arabic)['process']!];

List<int> shuffledOrder(int n, int seed) {
  final r = Random(seed);
  List<int> o;
  do {
    o = List.generate(n, (i) => i)..shuffle(r);
  } while (n > 1 && List.generate(n, (i) => i).toString() == o.toString());
  return o;
}

class HabitGame extends StatefulWidget {
  final int seed;
  const HabitGame({super.key, this.seed = 7});
  @override
  State<HabitGame> createState() => _HabitGameState();
}

class _HabitGameState extends State<HabitGame> {
  static const rounds = 8;
  int _round = 0, _score = 0, _run = 0;
  bool? _last; // null = unanswered, else was the answer right
  late List<Habit> _cards;
  bool _init = false;

  void _begin(bool ar) {
    _cards = habitRound(ar, rounds, widget.seed + _run);
    _round = 0;
    _score = 0;
    _last = null;
    _init = true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!_init) _begin(s.ar);
    final done = _round >= rounds;
    return Scaffold(
      appBar: AppBar(title: Text(s.ar ? 'عادة صح ولا غلط؟' : 'Good habit or mistake?')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: done
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$_score / $rounds', key: const Key('habit_score'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                FilledButton(
                    key: const Key('habit_again'),
                    onPressed: () => setState(() {
                          _run++;
                          _begin(s.ar);
                        }),
                    child: Text(s.t('again'))),
              ])
            : _card(s),
      ),
    );
  }

  Widget _card(S s) {
    final h = _cards[_round];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${_round + 1}/$rounds', textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Text(s.t(h.material), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(h.text, key: const Key('habit_text'), style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      if (_last == null)
        Row(children: [
          Expanded(child: FilledButton.icon(key: const Key('habit_good'), icon: const Icon(Icons.thumb_up), onPressed: () => _answer(h, true), label: Text(s.ar ? 'عادة صح' : 'Good habit'))),
          const SizedBox(width: 12),
          Expanded(child: OutlinedButton.icon(key: const Key('habit_bad'), icon: const Icon(Icons.thumb_down), onPressed: () => _answer(h, false), label: Text(s.ar ? 'غلط' : 'Mistake'))),
        ])
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_last! ? Icons.check_circle : Icons.cancel, color: _last! ? AppColors.primary : Colors.red.shade700),
          const SizedBox(width: 8),
          Text(_last! ? s.t('right') : '${s.t('wrong')}: ${h.good ? (s.ar ? "عادة صح" : "good habit") : (s.ar ? "غلط" : "mistake")}', key: const Key('habit_feedback')),
        ]),
        const SizedBox(height: 8),
        FilledButton(key: const Key('habit_next'), onPressed: () => setState(() { _round++; _last = null; }), child: Text(s.t('next'))),
      ],
    ]);
  }

  void _answer(Habit h, bool saidGood) => setState(() {
        _last = saidGood == h.good;
        if (_last!) _score++;
      });
}

class StepsGame extends StatefulWidget {
  final int seed;
  const StepsGame({super.key, this.seed = 11});
  @override
  State<StepsGame> createState() => _StepsGameState();
}

class _StepsGameState extends State<StepsGame> {
  int _set = 0, _mistakes = 0, _total = 0;
  final List<int> _placed = [];
  late List<int> _order;
  bool _init = false;
  bool _finished = false;

  void _load(bool ar) {
    _order = shuffledOrder(stepSets(ar)[_set].length, widget.seed + _set);
    _placed.clear();
    _init = true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sets = stepSets(s.ar);
    if (!_init) _load(s.ar);
    return Scaffold(
      appBar: AppBar(title: Text(s.ar ? 'رتّب خطوات التدوير' : 'Put the steps in order')),
      body: _finished
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${s.ar ? "الأخطاء" : "Mistakes"}: $_total', key: const Key('steps_total')),
                const SizedBox(height: 12),
                FilledButton(key: const Key('steps_again'), onPressed: () => setState(() { _set = 0; _total = 0; _mistakes = 0; _finished = false; _load(s.ar); }), child: Text(s.t('again'))),
              ]),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('${s.t(eduContents[_set].category.key)}  ${_set + 1}/${sets.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(s.ar ? 'اضغط الخطوات بالترتيب الصح' : 'Tap the steps in the right order'),
              const SizedBox(height: 12),
              for (var i = 0; i < _order.length; i++)
                Card(
                  color: _placed.contains(_order[i]) ? AppColors.background : null,
                  child: ListTile(
                    key: Key('step_$i'),
                    leading: _placed.contains(_order[i])
                        ? CircleAvatar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, child: Text('${_placed.indexOf(_order[i]) + 1}'))
                        : const CircleAvatar(child: Icon(Icons.radio_button_unchecked, size: 18)),
                    title: Text(sets[_set][_order[i]]),
                    onTap: () => _tap(s, sets, i),
                  ),
                ),
              Text('${s.ar ? "الأخطاء" : "Mistakes"}: $_mistakes', key: const Key('steps_mistakes')),
            ]),
    );
  }

  void _tap(S s, List<List<String>> sets, int i) {
    final step = _order[i];
    if (_placed.contains(step)) return;
    setState(() {
      if (step == _placed.length) {
        _placed.add(step);
        if (_placed.length == _order.length) {
          _total += _mistakes;
          if (_set + 1 >= sets.length) {
            _finished = true;
          } else {
            _set++;
            _mistakes = 0;
            _load(s.ar);
          }
        }
      } else {
        _mistakes++;
      }
    });
  }
}
