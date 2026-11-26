import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:environmental_challenges/core/theme/app_theme.dart';
import 'package:environmental_challenges/features/map/map_screen.dart';
import 'package:environmental_challenges/features/scanner/scanner_screen.dart';
import 'package:environmental_challenges/features/game/edu_games.dart';
import 'package:environmental_challenges/features/game/games_hub.dart';
import 'package:environmental_challenges/features/shell/main_shell.dart';
import 'package:environmental_challenges/app.dart';
import 'dart:io' show HttpOverrides;
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


class _Empty implements CentersRepository {
  @override
  Future<List<RecyclingCenter>> fetch() async => const [];
}

void main() {
  SharedPreferences.setMockInitialValues({});
  testWidgets('shot3', (t) async {
    HttpOverrides.global = null;
    await loadFont('NotoSans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
    await loadFont('NotoNaskh', ['assets/fonts/NotoNaskhArabic-Regular.ttf', 'assets/fonts/NotoNaskhArabic-Bold.ttf']);
    await loadFont('MaterialIcons', [Platform.environment['HOME']! + '/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.75;
    final key = GlobalKey();
    Future<void> show(Widget w, String name, {int ms = 0}) async {
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => LocaleProvider()), ChangeNotifierProvider.value(value: AuthProvider())],
          child: MaterialApp(
            theme: AppTheme.light, debugShowCheckedModeBanner: false, locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            home: w),
        ),
      ));
      for (var i = 0; i < ms ~/ 100; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('/tmp/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
    Future<void> snap(String name) async {
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 1);
        File('/tmp/$name.png').writeAsBytesSync((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(RepaintBoundary(key: key, child: ChangeNotifierProvider(create: (_) => LocaleProvider(), child: const EnvChallengesApp())));
    await t.pumpAndSettle();
    await t.tap(find.text('English'));
    await snap('home_en');
    await t.tap(find.text('Scan'));
    await snap('scan_en');
    await t.tap(find.text('Pickup'));
    await snap('pickup_en');
    await t.tap(find.text('Profile'));
    await snap('profile_en');
  });
}
