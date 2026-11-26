import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/scanner/scanner_screen.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/services/lost_photo.dart';
import 'package:environmental_challenges/services/scan_history.dart';
import 'package:environmental_challenges/services/siglip_classifier.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter/material.dart';
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
      file: XFile.fromData(File('test/fixtures/Glass_bottle.jpg').readAsBytesSync(), name: 'cam.jpg'), type: RetrieveType.image);
}

class _Fixed implements WasteClassifier {
  final ScanResult r;
  _Fixed(this.r);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async => r;
}

class _Boom implements WasteClassifier {
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async => throw StateError('model failed to load');
}

/// Renders the scanner states on the real screen with real fonts (screenshots when SHOT_DIR is set).
void main() {
  final text = jsonDecode(File('experimental/siglip/siglip_text.json').readAsStringSync()) as Map<String, dynamic>;
  final vec = [for (final r in text['vectors'] as List) [for (final x in r as List) (x as num).toDouble()]];
  final owner = (text['owner'] as List).cast<String>();
  ScanResult res(String cls) => interpretSiglip(vec[owner.indexOf(cls)], vec, owner);
  final e0 = List<double>.filled(768, 0)..[0] = 1, e1 = List<double>.filled(768, 0)..[1] = 1;
  final unknown = interpretSiglip(List<double>.generate(768, (k) => e0[k] + e1[k]), [e0, e1], ['glass', 'metal']);

  testWidgets('scanner states render and behave (screenshots when SHOT_DIR is set)', (t) async {
    final dir = Platform.environment['SHOT_DIR'];
    for (final f in {'NotoSans': 'assets/fonts/NotoSans-Regular.ttf', 'NotoNaskh': 'assets/fonts/NotoNaskhArabic-Regular.ttf', 'MaterialIcons': '/tmp/asm/flutter_assets/fonts/MaterialIcons-Regular.otf'}.entries) {
      final l = FontLoader(f.key)..addFont(Future.value(ByteData.sublistView(File(f.value).readAsBytesSync())));
      await t.runAsync(() => l.load());
    }
    final old = ImagePickerPlatform.instance;
    addTearDown(() => ImagePickerPlatform.instance = old);
    ImagePickerPlatform.instance = _LostPicker();
    final key = GlobalKey();
    t.view.physicalSize = const Size(1080, 3000);
    t.view.devicePixelRatio = 2.75;
    final lp = LocaleProvider();
    Future<void> show(String name, {required bool on, WasteClassifier? experimental, WasteClassifier? standard, bool withPhoto = true}) async {
      LostPhoto.reset();
      SharedPreferences.setMockInitialValues({if (withPhoto) 'pendingPhotoOwner': 'scanner', 'experimentalScanner': on});
      await t.pumpWidget(ChangeNotifierProvider.value(
          value: lp,
          child: MaterialApp(
            theme: AppTheme.light,
            home: RepaintBoundary(
                key: key,
                child: ScannerScreen(
                    key: UniqueKey(),
                    classifier: standard ?? _Fixed(interpretLogits([0, 9, 0, 0, 0, 0])),
                    history: ScanHistory(),
                    experimentalAvailable: true,
                    experimentalFactory: () => experimental ?? _Fixed(res('glass')))),
          )));
      await t.pumpAndSettle();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400))); // let the photo decode
      await t.pumpAndSettle(const Duration(milliseconds: 200));
      if (dir == null) return;
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('$dir/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }

    // 1 default: switch present, OFF, the standard scanner answered
    await show('scan_1_switch_off', on: false);
    expect(t.widget<SwitchListTile>(find.byKey(const Key('experimentalSwitch'))).value, false);
    expect(find.byKey(const Key('experimentalResult')), findsNothing);
    // 2 switch on, experimental answer: banner, no percent, no probability bars
    await show('scan_2_experimental_result', on: true);
    expect(find.byKey(const Key('experimentalResult')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    // 3 experimental unknown: manual choice offered, choosing shows only the user's own choice
    await show('scan_3_unknown_manual', on: true, experimental: _Fixed(unknown));
    expect(find.byKey(const Key('manual_paper')), findsOneWidget);
    await t.tap(find.byKey(const Key('manual_paper')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('manualChosen')), findsOneWidget);
    if (dir != null) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await t.pump();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('$dir/scan_3b_unknown_manual_chosen.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
    // 4 organic: unsupported warning, no bin, manual choice
    await show('scan_4_organic_unsupported', on: true, experimental: _Fixed(res('organic')));
    expect(find.text('شكله مخلفات عضوية (مش مدعومة)'), findsOneWidget);
    expect(find.byKey(const Key('manual_organic')), findsOneWidget);
    expect(find.text('عضوي'), findsWidgets);
    // 5 experimental fails: the standard scanner answers and the screen says so
    await show('scan_5_fallback', on: true, experimental: _Boom());
    expect(find.byKey(const Key('experimentalFallback')), findsOneWidget);
    expect(find.byKey(const Key('experimentalResult')), findsNothing);
    // 6 standard unknown does not get manual chips (default scanner behaviour unchanged)
    await show('scan_6_standard_unknown_unchanged', on: false, standard: _Fixed(interpretLogits([1, 0.9, 1, 0.8, 0.7, 0])));
    expect(find.byKey(const Key('manual_paper')), findsNothing);
    // 7 English, organic unsupported (cardboard chip present as its own material)
    lp.toggle();
    await show('scan_7_en_organic_unsupported', on: true, experimental: _Fixed(res('organic')));
    expect(find.text('Looks like organic waste (not supported)'), findsOneWidget);
    expect(find.byKey(const Key('manual_cardboard')), findsOneWidget);
    await t.tap(find.byKey(const Key('manual_cardboard')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('manualChosen')), findsOneWidget);
    await show('scan_8_en_unknown', on: true, experimental: _Fixed(unknown));
    expect(find.text('Not sure'), findsWidgets);
    await show('scan_9_en_fallback', on: true, experimental: _Boom());
    expect(find.text('The experimental scanner reported an error, so the standard scanner answered.'), findsOneWidget);
  });
}
