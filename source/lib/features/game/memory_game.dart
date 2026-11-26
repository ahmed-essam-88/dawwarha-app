import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'game_data.dart';
import 'item_picture.dart';
import 'sort_game.dart' show allItems;

const memoryPairs = [3, 4, 5];

class MemCard {
  final GameItem? item; // item card, or
  final String? material; // material label card
  const MemCard.item(this.item) : material = null;
  const MemCard.mat(this.material) : item = null;
  String get group => item?.answer ?? material!;
}

/// Builds a shuffled deck: for each of `pairs` materials one item card and one
/// material-label card. Matching = same material.
List<MemCard> buildDeck(int pairs, int seed) {
  final r = Random(seed);
  final mats = (['plastic', 'metal', 'glass', 'paper', 'organic']..shuffle(r)).take(pairs).toList();
  final deck = <MemCard>[];
  for (final m in mats) {
    final cands = allItems().where((e) => e.answer == m).toList()..shuffle(r);
    deck..add(MemCard.item(cands.first))..add(MemCard.mat(m));
  }
  return deck..shuffle(r);
}

class MemoryGame extends StatefulWidget {
  final int seed;
  const MemoryGame({super.key, this.seed = 3});
  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  int? _level;
  List<MemCard> _deck = [];
  final Set<int> _matched = {};
  final List<int> _open = [];
  int _moves = 0;
  bool _busy = false;

  void _start(int l) => setState(() {
        _level = l;
        _deck = buildDeck(memoryPairs[l], widget.seed + l);
        _matched.clear();
        _open.clear();
        _moves = 0;
        _busy = false;
      });

  Future<void> _tap(int i) async {
    if (_busy || _matched.contains(i) || _open.contains(i)) return;
    setState(() => _open.add(i));
    if (_open.length < 2) return;
    _moves++;
    final a = _deck[_open[0]], b = _deck[_open[1]];
    final ok = a.group == b.group && (a.item == null) != (b.item == null);
    if (ok) {
      setState(() {
        _matched.addAll(_open);
        _open.clear();
      });
    } else {
      _busy = true;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _open.clear();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.ar ? 'لعبة الذاكرة' : 'Memory match')),
      body: _level == null
          ? ListView(padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < memoryPairs.length; i++)
                Card(
                  child: ListTile(
                    key: Key('mem_level_$i'),
                    leading: const Icon(Icons.play_circle, color: AppColors.primary),
                    title: Text('${s.t('level')} ${i + 1}'),
                    subtitle: Text(s.ar ? '${memoryPairs[i]} أزواج' : '${memoryPairs[i]} pairs'),
                    onTap: () => _start(i),
                  ),
                ),
            ])
          : Column(children: [
              Padding(padding: const EdgeInsets.all(12), child: Text('${s.ar ? "حركات" : "Moves"}: $_moves')),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.all(12),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [for (var i = 0; i < _deck.length; i++) _cell(s, i)],
                ),
              ),
              if (_matched.length == _deck.length)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(s.ar ? 'كملت كل الأزواج' : 'All pairs found', key: const Key('mem_done')),
                    FilledButton(onPressed: () => _start(_level!), child: Text(s.t('again'))),
                    TextButton(onPressed: () => setState(() => _level = null), child: Text(s.t('backToLevels'))),
                  ]),
                ),
            ]),
    );
  }

  Widget _cell(S s, int i) {
    final shown = _open.contains(i) || _matched.contains(i);
    final c = _deck[i];
    return InkWell(
      key: Key('card_$i'),
      onTap: () => _tap(i),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _matched.contains(i) ? Colors.green.shade100 : (shown ? Colors.white : AppColors.primary),
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: !shown
            ? const Icon(Icons.eco, color: Colors.white)
            : (c.item != null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ItemPicture(c.item!.pic, size: 48),
                    Text(s.ar ? c.item!.ar : c.item!.en, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textDark)),
                  ])
                : Text(s.t(c.material!), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark))),
      ),
    );
  }
}
