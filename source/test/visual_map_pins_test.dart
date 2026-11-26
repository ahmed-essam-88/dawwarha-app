import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/map/map_screen.dart';
import 'package:environmental_challenges/widgets/osm_map.dart';
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
  testWidgets('five-plus pins: viewport and every list card (screenshots when SHOT_DIR is set)', (t) async {
    final dir = Platform.environment['SHOT_DIR'];
    for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf', 'MaterialIcons': '/tmp/asm/flutter_assets/fonts/MaterialIcons-Regular.otf'}.entries) {
      final bytes = ByteData.sublistView(File(f.value).readAsBytesSync());
      final l = FontLoader(f.key)..addFont(Future.value(bytes));
      await t.runAsync(() => l.load());
    }
    final centers = File('assets/data/centers.json').readAsStringSync();
    final key = GlobalKey();
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    final lp = LocaleProvider();
    Future<void> shot(String name) async {
      if (dir == null) return;
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('$dir/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }

    void expectAllPinsOnScreen(int n) {
      final map = t.getRect(find.byType(OsmMap));
      final pins = find.byKey(const Key('center_marker'));
      expect(pins, findsNWidgets(13), reason: 'all 13 shipped pins are placed on the map');
      var inside = 0;
      for (var i = 0; i < 13; i++) {
        if (map.contains(t.getRect(pins.at(i)).center)) inside++;
      }
      expect(inside, n, reason: 'pins of the user\'s city that must be visible at start');
    }
    Widget app(double la, double lo) => ChangeNotifierProvider.value(value: lp, child: MaterialApp(theme: AppTheme.light, home: RepaintBoundary(key: key, child: MapScreen(key: ValueKey('$la'), repository: AssetCentersRepository(load: () async => centers), location: _Loc(la, lo), showTiles: false))));
    await t.pumpWidget(app(30.0608, 31.2222));
    await t.pumpAndSettle();
    expectAllPinsOnScreen(10);
    await shot('pins_cairo_viewport');
    final list = find.byType(ListView).last;
    for (var i = 0; i < 6; i++) {
      await t.drag(list, const Offset(0, -380));
      await t.pumpAndSettle();
      await shot('pins_list_cairo_$i');
    }
    await t.pumpWidget(app(31.2332, 29.9468));
    await t.pumpAndSettle();
    expectAllPinsOnScreen(3);
    await shot('pins_alex_viewport');
    for (var i = 0; i < 3; i++) {
      await t.drag(find.byType(ListView).last, const Offset(0, -380));
      await t.pumpAndSettle();
      await shot('pins_list_alex_$i');
    }
  });
}
