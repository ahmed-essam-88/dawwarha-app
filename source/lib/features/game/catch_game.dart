import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'game_data.dart';
import 'item_picture.dart';
import 'sort_game.dart' show allItems;

/// (target count to collect, fall speed in px/s, lives)
const catchLevels = [(5, 70.0, 3), (8, 110.0, 3), (10, 150.0, 2)];

class _Falling {
  final int id;
  final GameItem item;
  double x; // 0..1
  double y; // px
  _Falling(this.id, this.item, this.x, this.y);
}

class CatchGame extends StatefulWidget {
  final int seed;
  const CatchGame({super.key, this.seed = 11});
  @override
  State<CatchGame> createState() => _CatchGameState();
}

class _CatchGameState extends State<CatchGame> with SingleTickerProviderStateMixin {
  int? _level;
  late Random _r;
  late Ticker _ticker;
  Duration _last = Duration.zero;
  double _spawnIn = 0;
  int _nextId = 0;
  final List<_Falling> _items = [];
  String _target = 'plastic';
  int _got = 0, _lives = 3;
  bool _won = false, _lost = false;
  double _height = 500;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start(int l) {
    _r = Random(widget.seed + l);
    final mats = ['plastic', 'metal', 'glass', 'paper', 'organic'];
    setState(() {
      _level = l;
      _target = mats[_r.nextInt(mats.length)];
      _got = 0;
      _lives = catchLevels[l].$3;
      _won = false;
      _lost = false;
      _items.clear();
      _spawn();
      _spawnIn = 1.2;
    });
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _spawn() {
    // About half of the items belong to the target material.
    final pool = allItems();
    final good = _r.nextBool();
    final cands = pool.where((e) => (e.answer == _target) == good).toList();
    _items.add(_Falling(_nextId++, cands[_r.nextInt(cands.length)], 0.1 + _r.nextDouble() * 0.7, -40));
  }

  void _tick(Duration t) {
    if (_level == null || _won || _lost) return;
    final dt = _last == Duration.zero ? 0.0 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    final speed = catchLevels[_level!].$2;
    setState(() {
      for (final f in _items) {
        f.y += speed * dt;
      }
      // A target item that falls off the bottom costs a life.
      final missed = _items.where((f) => f.y > _height && f.item.answer == _target).length;
      _items.removeWhere((f) => f.y > _height);
      if (missed > 0) _hurt(missed);
      _spawnIn -= dt;
      if (_spawnIn <= 0 && !_won && !_lost) {
        _spawn();
        _spawnIn = 1.3 - _level! * 0.25;
      }
    });
  }

  void _hurt(int n) {
    _lives -= n;
    if (_lives <= 0) {
      _lives = 0;
      _lost = true;
    }
  }

  void _tapItem(_Falling f) {
    if (_won || _lost) return;
    setState(() {
      _items.remove(f);
      if (f.item.answer == _target) {
        _got++;
        if (_got >= catchLevels[_level!].$1) _won = true;
      } else {
        _hurt(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.ar ? 'التقط وتجنب' : 'Collect and avoid')),
      body: _level == null
          ? ListView(padding: const EdgeInsets.all(16), children: [
              Text(s.ar ? 'اضغط على المخلفات من نوع الهدف، وتجنب الباقي. الغلط بيخسرك محاولة.' : 'Tap items of the target material and avoid the rest. A wrong tap costs a life.'),
              for (var i = 0; i < catchLevels.length; i++)
                Card(
                  child: ListTile(
                    key: Key('catch_level_$i'),
                    leading: const Icon(Icons.play_circle, color: AppColors.primary),
                    title: Text('${s.t('level')} ${i + 1}'),
                    subtitle: Text(s.ar ? 'التقط ${catchLevels[i].$1}' : 'Collect ${catchLevels[i].$1}'),
                    onTap: () => _start(i),
                  ),
                ),
            ])
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${s.ar ? "الهدف" : "Target"}: ${s.t(_target)}   $_got/${catchLevels[_level!].$1}   ${s.ar ? "محاولات" : "Lives"}: $_lives',
                    key: const Key('catch_status')),
              ),
              Expanded(
                child: LayoutBuilder(builder: (c, box) {
                  _height = box.maxHeight;
                  return Stack(children: [
                    for (final f in _items)
                      Positioned(
                        key: Key('fall_${f.id}'),
                        left: f.x * (box.maxWidth - 90),
                        top: f.y,
                        child: GestureDetector(
                          onTap: () => _tapItem(f),
                          child: Container(
                            width: 90,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.secondary)),
                            child: Column(children: [
                              ItemPicture(f.item.pic, size: 44),
                              Text(s.ar ? f.item.ar : f.item.en, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10, color: AppColors.textDark)),
                            ]),
                          ),
                        ),
                      ),
                    if (_won || _lost)
                      Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(_won ? (s.ar ? 'كسبت المستوى' : 'Level won') : (s.ar ? 'خسرت المحاولات' : 'Out of lives'), key: const Key('catch_end')),
                              FilledButton(onPressed: () => _start(_level!), child: Text(s.t('again'))),
                              TextButton(onPressed: () => setState(() => _level = null), child: Text(s.t('backToLevels'))),
                            ]),
                          ),
                        ),
                      ),
                  ]);
                }),
              ),
            ]),
    );
  }
}
