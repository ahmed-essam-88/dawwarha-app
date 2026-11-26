import 'package:flutter/material.dart' show BackButton;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:environmental_challenges/app.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await l.load();
}

void main() {
  testWidgets('screens', (t) async {
    SharedPreferences.setMockInitialValues({});
    const d = '/usr/share/fonts/truetype/noto/';
    await loadFont('NotoSans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
    await loadFont('NotoNaskh', ['assets/fonts/NotoNaskhArabic-Regular.ttf', 'assets/fonts/NotoNaskhArabic-Bold.ttf']);
    await loadFont('NotoEmoji', ['assets/fonts/NotoEmoji.ttf']);
    await loadFont('MaterialIcons', [Platform.environment['HOME']! + '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 2.75;
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: ChangeNotifierProvider(
        create: (_) => LocaleProvider(), child: const EnvChallengesApp())));
    await t.pumpAndSettle();
    Future<void> shot(String n) async {
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('/tmp/$n.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await shot('home_ar');
    await t.tap(find.text('الفحص')); await t.pumpAndSettle();
    await shot('scan_ar');
    await t.tap(find.text('الرئيسية')); await t.pumpAndSettle();
    await t.tap(find.text('لعبة التدوير')); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('g_quiz'))); await t.pumpAndSettle();
    await t.tap(find.text('المستوى 1')); await t.pumpAndSettle();
    await t.tap(find.text('البلاستيك')); await t.pumpAndSettle();
    await shot('game_ar');
    await t.tap(find.text('التالي')); await t.pumpAndSettle();
    await t.tap(find.text('البلاستيك')); await t.pumpAndSettle();
    await shot('game_wrong_ar');
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await shot('hub_ar');
    await t.tap(find.byKey(const Key('g_sort'))); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('sort_level_1'))); await t.pumpAndSettle();
    await shot('sort_ar');
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('g_memory'))); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('mem_level_1'))); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('card_0'))); await t.pumpAndSettle();
    await shot('memory_ar');
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('g_catch'))); await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('catch_level_0'))); await t.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 25; i++) { await t.pump(const Duration(milliseconds: 100)); }
    await shot('catch_ar');
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.text('التعليم عن التدوير')); await t.pumpAndSettle();
    await t.tap(find.text('البلاستيك')); await t.pumpAndSettle();
    await shot('edu_ar');
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.byType(BackButton).first); await t.pumpAndSettle();
    await t.tap(find.text('English')); await t.pumpAndSettle();
    await shot('home_en');
    await t.tap(find.text('Recycling Education')); await t.pumpAndSettle();
    await t.tap(find.text('Glass')); await t.pumpAndSettle();
    await shot('edu_en');
  });
}
