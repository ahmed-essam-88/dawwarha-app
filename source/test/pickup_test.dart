import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/pickup/pickup_screen.dart';
import 'package:environmental_challenges/models/pickup_request.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Loc implements LocationService {
  @override
  Future<UserPosition> current() async => const UserPosition(31.2001, 29.9187);
}

Widget wrap(Widget w) => ChangeNotifierProvider(create: (_) => LocaleProvider(), child: MaterialApp(home: w));
const ar = S(true);

void main() {
  test('validation: need items or kg, positive numbers, valid phone', () {
    String? v(String i, String k, String p) => PickupRequest.validate(itemsText: i, kgText: k, phone: p);
    expect(v('', '', '+201000000000'), 'errQuantity');
    expect(v('0', '', '+201000000000'), 'errQuantity');
    expect(v('3', '', '+201000000000'), isNull);
    expect(v('', '2,5', '01000000000'), isNull);
    expect(v('', '-1', '01000000000'), 'errQuantity');
    expect(v('2', '1', 'abc'), 'errPhone');
  });

  test('message has category, amounts, time, phone and a Google Maps link, and no acceptance claim', () {
    final r = PickupRequest(material: 'plastic', items: 4, kg: 2.5, phone: '01000000000', when: DateTime(2026, 11, 26, 9, 5), lat: 31.2001, lon: 29.9187);
    final t = r.shareText(materialLabel: 'Plastic', labels: {'material': 'Type', 'items': 'Items', 'kg': 'Kg', 'time': 'Time', 'phone': 'Phone', 'location': 'Location'});
    expect(t, contains('Type: Plastic'));
    expect(t, contains('Items: 4'));
    expect(t, contains('Kg: 2.5'));
    expect(t, contains('Time: 2026-11-26 09:05'));
    expect(t, contains('Phone: 01000000000'));
    expect(t, contains('https://www.google.com/maps?q=31.200100,29.918700'));
    expect(t.toLowerCase(), isNot(contains('accepted')));
  });

  testWidgets('fill, add location and photo, share by WhatsApp, SMS and share sheet', (t) async {
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 2.75;
    final launched = <Uri>[];
    String? sheetText, sheetImage;
    await t.pumpWidget(wrap(PickupScreen(
      location: _Loc(),
      launcher: (u) async {
        launched.add(u);
        return true;
      },
      pickImage: (src) async => '/nonexistent/photo.jpg',
      shareSheet: (text, img) async {
        sheetText = text;
        sheetImage = img;
      },
    )));
    // invalid: shows a validation error, nothing launched
    await t.tap(find.byKey(const Key('shareWa')));
    await t.pump();
    expect(launched, isEmpty);
    expect(find.byKey(const Key('pickup_error')), findsOneWidget);

    await t.enterText(find.byKey(const Key('items')), '3');
    await t.enterText(find.byKey(const Key('kg')), '1.5');
    await t.enterText(find.byKey(const Key('phone')), '+201000000000');
    await t.tap(find.byKey(const Key('useLoc')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('takePhoto')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.byKey(const Key('coords')), findsOneWidget);
    expect(find.textContaining('31.200100'), findsWidgets);
    expect(find.textContaining('29.918700'), findsWidgets);
    expect(find.textContaining('google.com/maps?q=31.200100,29.918700'), findsOneWidget);

    await t.tap(find.byKey(const Key('shareWa')));
    await t.pump();
    expect(launched.last.host, 'wa.me');
    expect(launched.last.queryParameters['text'], contains('google.com/maps'));
    expect(launched.last.toString().split('text=').last.contains('+'), isFalse);
    await t.tap(find.byKey(const Key('shareSms')));
    await t.pump();
    expect(launched.last.scheme, 'sms');
    final rawBody = launched.last.toString().split('body=').last;
    expect(rawBody.contains('+'), isFalse, reason: 'a space must be %20, not +, or SMS apps show a literal plus');
    expect(rawBody, contains('%20'));
    expect(Uri.decodeComponent(rawBody), contains('google.com/maps'));
    await t.ensureVisible(find.byKey(const Key('shareSheet')));
    await t.tap(find.byKey(const Key('shareSheet')));
    await t.pump();
    expect(sheetImage, '/nonexistent/photo.jpg');
    expect(sheetText, contains('+201000000000'));
  });
}
