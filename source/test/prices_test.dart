import 'dart:convert';
import 'dart:io';

import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/prices/prices_screen.dart';
import 'package:environmental_challenges/models/waste_price.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/repositories/centers_repository.dart';
import 'package:environmental_challenges/repositories/prices_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget wrap(Widget w) => ChangeNotifierProvider(create: (_) => LocaleProvider(), child: MaterialApp(home: w));

void main() {
  test('every shipped price row has a source, a date and a valid range', () async {
    final repo = AssetPricesRepository(load: () async => File('assets/data/prices.json').readAsString());
    final rows = await repo.fetch();
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect(r.source, isNotEmpty);
      expect(r.sourceUrl, startsWith('https://'));
      expect(r.maxPerKg, greaterThanOrEqualTo(r.minPerKg));
      expect(['plastic', 'metal', 'paper', 'glass', 'other'], contains(r.material));
    }
    // glass has only the Big Scrappers buyer row; it must stay attributed to that buyer
    final glass = rows.where((r) => r.material == 'glass').toList();
    expect(glass.single.source, contains('Big Scrappers'));
    expect(glass.single.dateIsAccess, isTrue);
    expect(glass.single.points, 1);
    expect(glass.single.unitUnspecified, isTrue, reason: 'the owner table prints no unit');
    // only rows whose source states EGP/kg may be shown per kg
    for (final r in rows.where((r) => !r.unitUnspecified)) {
      expect(r.source, anyOf(contains('Vetogate'), contains('per kg as stated')));
      expect(r.currency, 'EGP');
    }
  });

  test('a row without a source or date is rejected, not shown', () {
    expect(() => WastePrice.fromJson({'material': 'plastic', 'min': 5, 'updated': '2026-01-01'}), throwsFormatException);
    expect(() => WastePrice.fromJson({'material': 'plastic', 'min': 5, 'source': 'x'}), throwsFormatException);
    expect(() => WastePrice.fromJson({'material': 'plastic', 'min': 9, 'max': 5, 'source': 'x', 'updated': '2026-01-01'}), throwsFormatException);
  });

  test('centers file: every row needs a name, source and valid coordinates; shipped facilities each have source, access caveat and Alexandria coordinates', () async {
    // Google Places coordinates may not be bundled (Google terms). Shipped centers must come from an independent source.
    // El-Salam is held back (conflicting address labels, ~80 m owner-source variation, no gate confirmation). Record kept in docs/source_records.
    final shipped = await AssetCentersRepository(load: () async => File('assets/data/centers.json').readAsString()).fetch();
    expect(shipped.map((c) => c.name).toList(), ['Orange Nasr City Shop', 'Big Scrappers Nasr City warehouse', 'Big Scrappers New Cairo hub', 'Ismailia Square Orange Shop', 'Orange Zamalek Shop', 'Uptown Cairo Shop (Orange)', 'Katameya Downtown Mall Orange Shop', 'Roushdy Orange Shop', 'Saint Stefano Orange Shop', 'Alex City Light (Orange, City Light Mall)', 'Toby City Stars Mall', 'Toby Roxy', 'Toby Al Bustan Mall']);
    for (final c in shipped) {
      final cairo = c.lat >= 29.9 && c.lat <= 30.2 && c.lon >= 31.2 && c.lon <= 31.6;
      final alex = c.lat >= 31.05 && c.lat <= 31.35 && c.lon >= 29.75 && c.lon <= 30.1;
      expect(cairo || alex, isTrue, reason: 'Cairo or Alexandria only: ${c.name}');
      expect(c.source, isNot(contains('Google')));
      expect(c.noteEn, anyOf(contains('not confirmed'), contains('does not say')));
    }
    expect(shipped.first.materials, ['e-waste']);
    expect(shipped.skip(1).take(2).every((c) => c.sourceUrl == 'https://bigscrappers.com/stores' && c.materials.isEmpty), isTrue);
    expect(shipped.skip(3).take(7).every((c) => c.materials.contains('e-waste') && c.sourceUrl!.startsWith('https://store.orange.eg/')), isTrue);
    expect(shipped.skip(10).every((c) => c.materials.contains('e-waste') && c.name.startsWith('Toby') && c.sourceUrl == 'https://2b.com.eg/en/mw-store-locator'), isTrue);
    expect(shipped[10].noteEn ?? '', contains('pin is the mall'));
    final held = await AssetCentersRepository(load: () async => File('docs/source_records/el_salam_candidate.json').readAsString()).fetch();
    expect(held.single.name, contains('El-Salam'));
    final ok = jsonEncode([{'name': 'A', 'lat': 31.2, 'lon': 29.9, 'source': 'test'}]);
    expect((await AssetCentersRepository(load: () async => ok).fetch()).single.name, 'A');
    final bad = jsonEncode([{'name': 'A', 'lat': 31.2, 'lon': 29.9}]);
    expect(() => AssetCentersRepository(load: () async => bad).fetch(), throwsFormatException);
  });

  testWidgets('screen shows ranges with source and date, and attributes glass and other rows to their buyer', (t) async {
    final json = File('assets/data/prices.json').readAsStringSync();
    final repo = AssetPricesRepository(load: () async => json);
    t.view.physicalSize = const Size(1080, 9000);
    t.view.devicePixelRatio = 2.75;
    await t.pumpWidget(wrap(PricesScreen(repository: repo)));
    await t.pumpAndSettle();
    expect(find.textContaining('18 - 18.5'), findsOneWidget);
    expect(find.textContaining('فيتو'), findsWidgets); // Arabic source label by default
    expect(find.byIcon(Icons.open_in_new), findsWidgets);
    expect(find.byKey(const Key('none_glass')), findsNothing);
    expect(find.textContaining('بيج سكرابرز'), findsWidgets);
    expect(find.byKey(const Key('none_plastic')), findsNothing);
  });

  testWidgets('load error shows the error text', (t) async {
    await t.pumpWidget(wrap(PricesScreen(repository: AssetPricesRepository(load: () async => 'not json'))));
    await t.pumpAndSettle();
    expect(find.text(const S(true).t('pricesError')), findsOneWidget);
  });
}
