import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/map/map_screen.dart';
import 'package:environmental_challenges/features/prices/prices_screen.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/repositories/centers_repository.dart';
import 'package:environmental_challenges/repositories/prices_repository.dart';
import 'package:environmental_challenges/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Loc implements LocationService {
  final double la, lo;
  const _Loc(this.la, this.lo);
  @override
  Future<UserPosition> current() async => UserPosition(la, lo); // TEST FIXTURE position, not a real user
}

/// Renders the shipped data on the real screens with real fonts when SHOT_DIR is set (no tiles, no emulator).
void main() {
  testWidgets('map list + prices link icons render (screenshots when SHOT_DIR is set)', (t) async {
    final dir = Platform.environment['SHOT_DIR'];
    for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf', 'MaterialIcons': '/tmp/asm/flutter_assets/fonts/MaterialIcons-Regular.otf'}.entries) {
      final bytes = ByteData.sublistView(File(f.value).readAsBytesSync());
      final l = FontLoader(f.key)..addFont(Future.value(bytes));
      await t.runAsync(() => l.load());
    }
    final centers = File('assets/data/centers.json').readAsStringSync();
    final prices = File('assets/data/prices.json').readAsStringSync();
    final key = GlobalKey();
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final lp = LocaleProvider();
    Future<void> shot(Widget w, String name) async {
      await t.pumpWidget(ChangeNotifierProvider.value(value: lp, child: MaterialApp(theme: AppTheme.light, home: RepaintBoundary(key: key, child: w))));
      await t.pumpAndSettle();
      if (dir == null) return;
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('$dir/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
    await shot(MapScreen(repository: AssetCentersRepository(load: () async => centers), location: const _Loc(30.05, 31.34), showTiles: false), 'map_ar');
    await shot(PricesScreen(repository: AssetPricesRepository(load: () async => prices)), 'prices_icons_ar');
  });
}
