import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'catch_game.dart';
import 'edu_games.dart';
import 'game_screen.dart';
import 'memory_game.dart';
import 'sort_game.dart';

class GamesHub extends StatelessWidget {
  const GamesHub({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget card(String key, IconData icon, String title, String sub, Widget page) => Card(
          child: ListTile(
            key: Key(key),
            leading: Icon(icon, color: AppColors.primary, size: 32),
            title: Text(title),
            subtitle: Text(sub),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.t('game'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        card('g_quiz', Icons.quiz, s.ar ? 'اسئلة الفرز' : 'Sorting quiz',
            s.ar ? '٣ مستويات، اختار الحاوية الصح' : '3 levels, pick the right bin', const GameScreen()),
        card('g_sort', Icons.move_down, s.ar ? 'اسحب للحاوية' : 'Drag to the bin',
            s.ar ? 'اسحب كل قطعة للحاوية بتاعتها' : 'Drag each item into its bin', const SortGame()),
        card('g_memory', Icons.grid_view, s.ar ? 'لعبة الذاكرة' : 'Memory match',
            s.ar ? 'وصّل كل قطعة بنوع خامتها' : 'Match each item with its material', const MemoryGame()),
        card('g_catch', Icons.touch_app, s.ar ? 'التقط وتجنب' : 'Collect and avoid',
            s.ar ? 'المخلفات بتتحرك: اضغط على الصح وتجنب الغلط' : 'Items move: tap the right ones, avoid wrong ones', const CatchGame()),
        card('g_habit', Icons.thumbs_up_down, s.ar ? 'عادة صح ولا غلط؟' : 'Good habit or mistake?',
            s.ar ? '٨ بطاقات من نصايح الفرز وأخطاء التدوير' : '8 cards from sorting tips and common mistakes', const HabitGame()),
        card('g_steps', Icons.format_list_numbered, s.ar ? 'رتّب خطوات التدوير' : 'Put the steps in order',
            s.ar ? 'رتّب مراحل تدوير كل خامة' : 'Order the recycling process of each material', const StepsGame()),
      ]),
    );
  }
}
