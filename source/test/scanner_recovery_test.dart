import 'dart:io';
import 'dart:typed_data';

import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:environmental_challenges/features/scanner/scanner_screen.dart';
import 'package:environmental_challenges/services/lost_photo.dart';
import 'package:environmental_challenges/services/scan_history.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LostPicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  final LostDataResponse response;
  _LostPicker(this.response);
  @override
  Future<LostDataResponse> getLostData() async => response;
}

class _Fake implements WasteClassifier {
  int calls = 0;
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List imageBytes) async {
    calls++;
    return interpretLogits([0, 0, 0, 9, 0, 0]);
  }
}

Widget _host(WasteClassifier c) => ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(home: ScannerScreen(classifier: c, history: ScanHistory())),
    );

void main() {
  setUp(() {
    LostPhoto.reset();
    SharedPreferences.setMockInitialValues({'pendingPhotoOwner': 'scanner'});
  });

  testWidgets('a photo returned after Android killed the app is classified on restart', (t) async {
    final old = ImagePickerPlatform.instance;
    addTearDown(() => ImagePickerPlatform.instance = old);
    ImagePickerPlatform.instance = _LostPicker(LostDataResponse(
        file: XFile.fromData(File('test/fixtures/Plastic_bottle.jpg').readAsBytesSync(), name: 'cam.jpg'), type: RetrieveType.image));
    await t.binding.setSurfaceSize(const Size(800, 2400)); // taller viewport: the tip box is longer, bars are built lazily
    addTearDown(() => t.binding.setSurfaceSize(null));
    final c = _Fake();
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(c.calls, 1);
    expect(find.byType(Image), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets); // one bar per model class
  });

  testWidgets('no lost photo means nothing is classified', (t) async {
    final old = ImagePickerPlatform.instance;
    addTearDown(() => ImagePickerPlatform.instance = old);
    ImagePickerPlatform.instance = _LostPicker(LostDataResponse.empty());
    final c = _Fake();
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(c.calls, 0);
  });

  testWidgets('a photo taken from Pickup is not consumed by the scanner', (t) async {
    final old = ImagePickerPlatform.instance;
    addTearDown(() => ImagePickerPlatform.instance = old);
    SharedPreferences.setMockInitialValues({'pendingPhotoOwner': 'pickup'});
    ImagePickerPlatform.instance = _LostPicker(LostDataResponse(
        file: XFile.fromData(File('test/fixtures/Plastic_bottle.jpg').readAsBytesSync(), name: 'cam.jpg'), type: RetrieveType.image));
    final c = _Fake();
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(c.calls, 0, reason: 'the scanner must not classify a pickup photo');
    // The same single recovered photo is still available to the screen that asked.
    expect(await LostPhoto.recover('pickup'), isNotNull);
    expect(await LostPhoto.recover('scanner'), isNull);
  });
}
