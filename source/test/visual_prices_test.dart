import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/prices/prices_screen.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/repositories/prices_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Renders the prices screen to PNG with the app's bundled fonts (no emulator on the build box).
/// Writes only when SHOT_DIR is set; otherwise it just checks the screen builds.
void main() {
  testWidgets('prices screen renders (screenshot when SHOT_DIR is set)', (t) async {
    final dir = Platform.environment['SHOT_DIR'];
    for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf'}.entries) {
      final bytes = ByteData.sublistView(File(f.value).readAsBytesSync());
      final l = FontLoader(f.key)..addFont(Future.value(bytes));
      await t.runAsync(() => l.load());
    }
    final json = File('assets/data/prices.json').readAsStringSync();
    final key = GlobalKey();
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final lp = LocaleProvider();
    final ar = Platform.environment['SHOT_LANG'] != 'en';
    if (!ar) lp.toggle();
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: lp,
      child: MaterialApp(theme: AppTheme.light, locale: Locale(ar ? 'ar' : 'en'), home: RepaintBoundary(key: key, child: PricesScreen(repository: AssetPricesRepository(load: () async => json)))),
    ));
    await t.pumpAndSettle();
    if (dir != null) {
      final suffix = Platform.environment['SHOT_SCROLL'] ?? '0';
      if (suffix != '0') await t.drag(find.byType(ListView), Offset(0, -double.parse(suffix)));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('$dir/prices_${ar ? 'ar' : 'en'}_$suffix.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
  });
}
