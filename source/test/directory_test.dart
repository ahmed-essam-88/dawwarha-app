import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/widgets/collection_directory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final raw = File('assets/data/directory.json').readAsStringSync();
  final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  test('data: 3 Alexandria + 5 Cairo, owner-listed e-waste only, no coordinates, https owner links', () {
    expect(rows.where((r) => r['city'] == 'alexandria').length, 3);
    expect(rows.where((r) => r['city'] == 'cairo').length, 5);
    for (final r in rows) {
      expect(r.containsKey('lat') || r.containsKey('lon'), false, reason: '${r['name']} must not carry coordinates');
      expect(r['accepts'], ['e-waste']);
      expect((r['owner_map_url'] as String).startsWith('https://maps.app.goo.gl/'), true);
      expect(r['source_url'], 'https://onecircle-eg.com/collection-locator/');
    }
    // no invented address: the owner gives none for Saint Stefano
    final ss = rows.firstWhere((r) => r['name'] == 'Saint Stefano Orange Shop');
    expect(ss['address'], isNull);
    expect(raw.contains('Nasr City'), false, reason: 'Nasr City is already a map pin, not repeated here');
  });

  Future<void> fonts(WidgetTester t) async {
    for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf', 'MaterialIcons': '/tmp/asm/flutter_assets/fonts/MaterialIcons-Regular.otf'}.entries) {
      final l = FontLoader(f.key)..addFont(Future.value(ByteData.sublistView(File(f.value).readAsBytesSync())));
      await t.runAsync(() => l.load());
    }
  }

  testWidgets('renders, shows no navigation/distance, tap opens the owner link only (screenshots when SHOT_DIR set)', (t) async {
    await fonts(t);
    final dir = Platform.environment['SHOT_DIR'];
    final opened = <Uri>[];
    final key = GlobalKey();
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    for (final ar in [true, false]) {
      final lp = LocaleProvider();
      if (lp.isArabic != ar) lp.toggle();
      await t.pumpWidget(ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(body: RepaintBoundary(key: key, child: Directionality(textDirection: ar ? TextDirection.rtl : TextDirection.ltr, child: Container(color: Colors.white, child: SingleChildScrollView(child: CollectionDirectory(arabic: ar, load: () async => raw, launcher: (u) async { opened.add(u); return true; })))))))));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.directions), findsNothing);
      expect(find.textContaining(' km'), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(8));
      if (!ar) {
        expect(find.textContaining('The owner lists no street address'), findsOneWidget);
      }
      if (dir != null) {
        await t.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          File('$dir/directory_${ar ? 'ar' : 'en'}.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
      }
    }
    await t.tap(find.byKey(const Key('dir_open_Roushdy Orange Shop')));
    expect(opened.single.toString(), 'https://maps.app.goo.gl/YLgBg2hAGZoATfjd8');
  });
}
