import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'game_data.dart';
import 'item_picture.dart';

const _all = ['plastic', 'metal', 'glass', 'paper', 'organic'];
// level: (items to sort, bins shown). Harder levels show more bins.
const sortLevels = [(6, 3), (8, 4), (10, 5)];

List<GameItem> allItems() => [for (final l in gameLevels) ...l];

class SortGame extends StatefulWidget {
  final int seed;
  const SortGame({super.key, this.seed = 7});
  @override
  State<SortGame> createState() => _SortGameState();
}

class _SortGameState extends State<SortGame> {
  int? _level;
  List<GameItem> _queue = [];
  List<String> _bins = [];
  int _i = 0, _wrong = 0;
  String? _flash;
  bool? _flashOk;

  void _start(int level) {
    final r = Random(widget.seed + level);
    final (count, binCount) = sortLevels[level];
    final bins = ([..._all]..shuffle(r)).take(binCount).toList();
    final pool = allItems().where((e) => bins.contains(e.answer)).toList()..shuffle(r);
    setState(() {
      _level = level;
      _bins = bins;
      _queue = pool.take(count).toList();
      _i = 0;
      _wrong = 0;
      _flash = null;
    });
  }

  void _drop(String bin) {
    final item = _queue[_i];
    final ok = item.answer == bin;
    setState(() {
      if (ok) {
        _i++;
      } else {
        _wrong++;
      }
      _flashOk = ok;
      _flash = ok ? 'right' : 'wrong';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.ar ? 'اسحب للحاوية' : 'Drag to the bin')),
      body: _level == null ? _menu(s) : (_i >= _queue.length ? _done(s) : _play(s)),
    );
  }

  Widget _menu(S s) => ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < sortLevels.length; i++)
          Card(
            child: ListTile(
              key: Key('sort_level_$i'),
              leading: const Icon(Icons.play_circle, color: AppColors.primary),
              title: Text('${s.t('level')} ${i + 1}'),
              subtitle: Text(s.ar
                  ? '${sortLevels[i].$1} قطع، ${sortLevels[i].$2} حاويات'
                  : '${sortLevels[i].$1} items, ${sortLevels[i].$2} bins'),
              onTap: () => _start(i),
            ),
          ),
      ]);

  Widget _play(S s) {
    final item = _queue[_i];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text('${_i + 1}/${_queue.length}   ${s.ar ? "غلطات" : "Mistakes"}: $_wrong'),
      ),
      Expanded(
        child: Center(
          child: Draggable<String>(
            key: const Key('sort_item'),
            data: item.answer,
            feedback: Material(color: Colors.transparent, child: ItemPicture(item.pic, size: 90)),
            childWhenDragging: Opacity(opacity: .3, child: _itemCard(s, item)),
            child: _itemCard(s, item),
          ),
        ),
      ),
      if (_flash != null)
        Text(_flashOk! ? s.t('right') : s.t('wrong'),
            style: TextStyle(color: _flashOk! ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold)),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final b in _bins)
            DragTarget<String>(
              onAcceptWithDetails: (_) => _drop(b),
              builder: (c, cand, rej) => Container(
                key: Key('bin_$b'),
                width: 104,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cand.isNotEmpty ? AppColors.secondary : Colors.white,
                  border: Border.all(color: AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(s.t(b), style: const TextStyle(color: AppColors.textDark)),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _itemCard(S s, GameItem item) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.secondary)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ItemPicture(item.pic, size: 80),
          Text(s.ar ? item.ar : item.en),
        ]),
      );

  Widget _done(S s) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.ar ? 'خلصت المستوى' : 'Level finished', style: Theme.of(context).textTheme.headlineSmall),
        Text('${s.ar ? "غلطات" : "Mistakes"}: $_wrong'),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => _start(_level!), child: Text(s.t('again'))),
        TextButton(onPressed: () => setState(() => _level = null), child: Text(s.t('backToLevels'))),
      ]);
}
