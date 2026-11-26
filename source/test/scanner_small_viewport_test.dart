import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/scanner/scanner_screen.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/services/lost_photo.dart';
import 'package:environmental_challenges/services/scan_history.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LostPicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse(
      file: XFile.fromData(File('test/fixtures/Plastic_bottle.jpg').readAsBytesSync(), name: 'cam.jpg'), type: RetrieveType.image);
}

class _Fixed implements WasteClassifier {
  final ScanResult r;
  _Fixed(this.r);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async => r;
}

/// Small phone (360x640 logical) and the 600px-tall regression viewport: no overflow, everything reachable by scrolling.
void main() {
  for (final size in [const Size(360, 640), const Size(360, 600)]) {
    for (final ar in [true, false]) {
      testWidgets('scanner on ${size.width.toInt()}x${size.height.toInt()} ${ar ? 'ar' : 'en'}: no overflow, bars reachable by scrolling', (t) async {
        final dir = Platform.environment['SHOT_DIR'];
        for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf'}.entries) {
          final l = FontLoader(f.key)..addFont(Future.value(ByteData.sublistView(File(f.value).readAsBytesSync())));
          await t.runAsync(() => l.load());
        }
        final old = ImagePickerPlatform.instance;
        addTearDown(() => ImagePickerPlatform.instance = old);
        ImagePickerPlatform.instance = _LostPicker();
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        LostPhoto.reset();
        SharedPreferences.setMockInitialValues({'pendingPhotoOwner': 'scanner'});
        final lp = LocaleProvider();
        if (!ar) lp.toggle();
        final key = GlobalKey();
        await t.pumpWidget(ChangeNotifierProvider.value(
            value: lp,
            child: MaterialApp(
              theme: AppTheme.light,
              locale: lp.locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
              home: RepaintBoundary(key: key, child: ScannerScreen(key: UniqueKey(), classifier: _Fixed(interpretLogits([0, 0, 0, 0, 9, 0])), history: ScanHistory())),
            )));
        await t.pumpAndSettle();
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
        await t.pumpAndSettle(const Duration(milliseconds: 200));
        Future<void> shot(String n) async {
          if (dir == null) return;
          await t.runAsync(() async {
            final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final img = await b.toImage(pixelRatio: 2);
            File('$dir/${size.width.toInt()}x${size.height.toInt()}_${ar ? 'ar' : 'en'}_$n.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
          });
        }
        await shot('top');
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('organicLimit')), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
          await t.pumpAndSettle();
        }
        await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
        await t.pumpAndSettle();
        await shot('bottom');
        expect(find.byType(LinearProgressIndicator), findsWidgets);
        expect(find.byKey(const Key('resultCard')), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  }
}
