import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'game_data.dart';
import 'item_picture.dart';

const _materials = ['plastic', 'metal', 'glass', 'paper', 'organic'];
const _prefsKey = 'game_unlocked_level';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _unlocked = 0; // highest level index the player may open
  int? _level; // level in play
  int _q = 0;
  int _correct = 0;
  String? _picked;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _unlocked = (p.getInt(_prefsKey) ?? 0).clamp(0, gameLevels.length - 1));
    }).catchError((_) {});
  }

  void _start(int level) => setState(() {
        _level = level;
        _q = 0;
        _correct = 0;
        _picked = null;
        _done = false;
      });

  void _answer(String m) {
    if (_picked != null) return;
    final item = gameLevels[_level!][_q];
    setState(() {
      _picked = m;
      if (m == item.answer) _correct++;
    });
  }

  Future<void> _next() async {
    if (_q + 1 < gameLevels[_level!].length) {
      setState(() {
        _q++;
        _picked = null;
      });
      return;
    }
    final passed = _correct >= passMark;
    if (passed && _level! < gameLevels.length - 1 && _unlocked < _level! + 1) {
      _unlocked = _level! + 1;
      try {
        (await SharedPreferences.getInstance()).setInt(_prefsKey, _unlocked);
      } catch (_) {}
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('game'))),
      body: _level == null ? _levels(s) : (_done ? _summary(s) : _question(s)),
    );
  }

  Widget _levels(S s) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.t('gameIntro')),
        const SizedBox(height: 12),
        for (var i = 0; i < gameLevels.length; i++)
          Card(
            child: ListTile(
              enabled: i <= _unlocked,
              leading: Icon(i <= _unlocked ? Icons.play_circle : Icons.lock, color: AppColors.primary),
              title: Text('${s.t('level')} ${i + 1}'),
              subtitle: Text(i <= _unlocked ? s.t('levelOpen') : s.t('levelLocked')),
              onTap: i <= _unlocked ? () => _start(i) : null,
            ),
          ),
      ]);

  Widget _question(S s) {
    final items = gameLevels[_level!];
    final item = items[_q];
    final answered = _picked != null;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${s.t('level')} ${_level! + 1}  •  ${_q + 1}/${items.length}'),
      const SizedBox(height: 16),
      Text(s.t('whereDoesItGo'), style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 8),
      Center(child: ItemPicture(item.pic, size: 80)),
      const SizedBox(height: 8),
      Text(s.ar ? item.ar : item.en, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      for (final m in _materials)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textDark,
              side: BorderSide(
                  color: answered && m == item.answer
                      ? Colors.green.shade700
                      : (answered && m == _picked ? Colors.red.shade700 : Colors.grey.shade500),
                  width: answered && (m == item.answer || m == _picked) ? 2 : 1),
              backgroundColor: !answered
                  ? null
                  : (m == item.answer
                      ? Colors.green.shade100
                      : (m == _picked ? Colors.red.shade100 : null)),
            ),
            onPressed: () => _answer(m),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s.t(m)),
              if (answered && m == item.answer) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Icon(Icons.check_circle, size: 20, color: Colors.green.shade800)),
              if (answered && m == _picked && m != item.answer) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Icon(Icons.cancel, size: 20, color: Colors.red.shade800)),
            ]),
          ),
        ),
      if (answered) ...[
        const SizedBox(height: 12),
        Text(_picked == item.answer ? s.t('right') : '${s.t('wrong')}: ${s.t(item.answer)}'),
        const SizedBox(height: 6),
        Text(s.ar ? item.expAr : item.expEn),
        const SizedBox(height: 8),
        FilledButton(onPressed: _next, child: Text(s.t('next'))),
      ],
    ]);
  }

  Widget _summary(S s) {
    final passed = _correct >= passMark;
    final last = _level! == gameLevels.length - 1;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('$_correct / ${gameLevels[_level!].length}', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 8),
      Text(passed ? (last ? s.t('allDone') : s.t('levelPassed')) : s.t('levelFailed')),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => _start(_level!), child: Text(s.t('again'))),
      TextButton(onPressed: () => setState(() => _level = null), child: Text(s.t('backToLevels'))),
    ]);
  }
}
