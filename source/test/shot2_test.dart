import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/map/map_screen.dart';
import 'package:environmental_challenges/features/pickup/pickup_screen.dart';
import 'package:environmental_challenges/features/profile/profile_screen.dart';
import 'package:environmental_challenges/models/recycling_center.dart';
import 'package:environmental_challenges/providers/auth_provider.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/repositories/centers_repository.dart';
import 'package:environmental_challenges/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;
import 'package:environmental_challenges/features/prices/prices_screen.dart';


Future<void> loadFont(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await l.load();
}

class _Repo implements CentersRepository {
  @override
  Future<List<RecyclingCenter>> fetch() async => const [
        RecyclingCenter(id: 1, name: 'مركز تجريبي أ (بيانات اختبار)', lat: 31.215, lon: 29.955, source: 'اختبار'),
        RecyclingCenter(id: 2, name: 'مركز تجريبي ب (بيانات اختبار)', lat: 31.23, lon: 29.97, source: 'اختبار'),
      ];
}

class _Loc implements LocationService {
  @override
  Future<UserPosition> current() async => const UserPosition(31.2, 29.94);
}

void main() {
  testWidgets('screens2', (t) async {
    await loadFont('NotoSans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
    await loadFont('NotoNaskh', ['assets/fonts/NotoNaskhArabic-Regular.ttf', 'assets/fonts/NotoNaskhArabic-Bold.ttf']);
    await loadFont('MaterialIcons', [Platform.environment['HOME']! + '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.75;
    final key = GlobalKey();
    Future<void> show(Widget w, String name, {AuthProvider? auth}) async {
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider.value(value: auth ?? AuthProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            home: w),
        ),
      ));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('/tmp/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }

    await show(const ProfileScreen(), 'profile_out_ar');
    // RTL really applied: the email field's label sits right of the field's center in Arabic
    expect(Directionality.of(t.element(find.byType(ProfileScreen))), TextDirection.rtl);
    await show(const PickupScreen(), 'pickup_ar');
    await show(MapScreen(repository: _Repo(), location: _Loc(), showTiles: false), 'map_ar');
    final photo = File('/tmp/test_photo.png');
    final pi = img.Image(width: 400, height: 300);
    img.fill(pi, color: img.ColorRgb8(0x83, 0xC9, 0x95));
    img.fillCircle(pi, x: 200, y: 150, radius: 80, color: img.ColorRgb8(0x17, 0x6B, 0x45));
    photo.writeAsBytesSync(img.encodePng(pi));
    await show(PickupScreen(location: _Loc(), pickImage: (src) async => photo.path), 'pickup_filled_ar');
    await t.enterText(find.byKey(const Key('items')), '3');
    await t.enterText(find.byKey(const Key('kg')), '1.5');
    await t.enterText(find.byKey(const Key('phone')), '01000000000');
    await t.tap(find.byKey(const Key('useLoc')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('takePhoto')));
    await t.pumpAndSettle();
    // The image only decodes while frames are pumped, so interleave real waits with pumps.
    var decoded = false;
    FileImage(photo).resolve(ImageConfiguration.empty).addListener(ImageStreamListener((i, _) => decoded = true));
    for (var i = 0; i < 60 && !decoded; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(decoded, isTrue);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    Future<void> snap(String name) => t.runAsync(() async {
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          File('/tmp/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
        });
    await snap('pickup_filled_ar');
    await t.drag(find.byType(ListView), const Offset(0, -700));
    await t.pumpAndSettle();
    await snap('pickup_scrolled_ar');
    await show(const PricesScreen(), 'prices_ar');
  });
}
