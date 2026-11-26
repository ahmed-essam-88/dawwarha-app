import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/map/map_screen.dart';
import 'package:environmental_challenges/models/recycling_center.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/repositories/centers_repository.dart';
import 'package:environmental_challenges/services/location_service.dart';
import 'package:environmental_challenges/widgets/osm_map.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repo implements CentersRepository {
  final List<RecyclingCenter> rows;
  _Repo(this.rows);
  @override
  Future<List<RecyclingCenter>> fetch() async => rows;
}

class _Loc implements LocationService {
  final UserPosition? p;
  final LocationFailure? fail;
  _Loc({this.p, this.fail});
  @override
  Future<UserPosition> current() async => fail != null ? throw LocationException(fail!) : p!;
}

Widget wrap(Widget w) => ChangeNotifierProvider(create: (_) => LocaleProvider(), child: MaterialApp(home: w));
const ar = S(true);
// Test fixtures only (not shipped): two points about 1.1 km and 11 km north of 30.0, 31.0
const near = RecyclingCenter(id: 1, name: 'TEST near', lat: 30.01, lon: 31.0, source: 'test fixture');
const far = RecyclingCenter(id: 2, name: 'TEST far', lat: 30.1, lon: 31.0, source: 'test fixture');

void main() {
  test('mercator projection round trip and known tile', () {
    // Greenwich-ish check: lon 0, lat 0 is the center of the world at any zoom
    expect(lonToX(0, 3), 4);
    expect(latToY(0, 3), closeTo(4, 1e-9));
    // Alexandria, Egypt (31.2, 29.9) is tile 4/9 at zoom 4? verify by round trip instead of recall
    final x = lonToX(29.9, 12), y = latToY(31.2, 12);
    expect(xToLon(x, 12), closeTo(29.9, 1e-9));
    expect(yToLat(y, 12), closeTo(31.2, 1e-9));
  });

  test('distance and directions link', () {
    final d = distanceMeters(30.0, 31.0, 30.01, 31.0);
    expect(d, closeTo(1112, 15));
    final u = directionsUri(const UserPosition(30, 31), 30.01, 31.0);
    expect(u.host, 'www.openstreetmap.org');
    expect(u.toString(), contains('30.0%2C31.0%3B30.01%2C31.0'));
  });

  testWidgets('sorted by distance, shows distance, markers and navigates', (t) async {
    Uri? opened;
    await t.pumpWidget(wrap(MapScreen(
      repository: _Repo([far, near]),
      location: _Loc(p: const UserPosition(30.0, 31.0)),
      launcher: (u) async { opened = u; return true; },
      showTiles: false,
    )));
    await t.pumpAndSettle();
    final tiles = t.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title as Text).data, 'TEST near');
    expect(find.textContaining(RegExp(r'^1\.1 km')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^11\.1 km')), findsOneWidget);
    expect(find.byKey(const Key('me_marker')), findsOneWidget);
    expect(find.byKey(const Key('center_marker')), findsNWidgets(2));
    expect(find.byKey(const Key('coverage_note')), findsOneWidget);
    await t.tap(find.byKey(const Key('nav_1')));
    await t.pump();
    expect(opened!.queryParameters['route'], '30.0,31.0;30.01,31.0');
  });

  testWidgets('permission denied: message shown, no fake distance', (t) async {
    await t.pumpWidget(wrap(MapScreen(repository: _Repo([near]), location: _Loc(fail: LocationFailure.denied), showTiles: false)));
    await t.pumpAndSettle();
    expect(find.text(ar.t('locDenied')), findsOneWidget);
    expect(find.textContaining(ar.t('distUnknown')), findsOneWidget);
    expect(find.byKey(const Key('me_marker')), findsNothing);
  });

  testWidgets('no centers: honest empty state; ', (t) async {
    final fac = (await t.runAsync(() => File('assets/data/facilities.json').readAsString()))!;
    await t.pumpWidget(wrap(MapScreen(repository: _Repo([]), location: _Loc(fail: LocationFailure.serviceOff), facilitiesLoad: () async => fac, showTiles: false)));
    await t.pumpAndSettle();
    for (var i = 0; i < 20 && find.byKey(const Key('facility_Tilestic (plastic recycler)'), skipOffstage: false).evaluate().isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump();
    }
    expect(find.text(ar.t('centersEmpty')), findsOneWidget);
    expect(find.byKey(const Key('facility_Tilestic (plastic recycler)'), skipOffstage: false), findsOneWidget);
    expect(find.textContaining(ar.t('facilitiesNote')), findsOneWidget);
    expect(find.byKey(const Key('center_marker')), findsNothing);

  });

  testWidgets('center markers are red and the user marker is green', (t) async {
    await t.pumpWidget(wrap(MapScreen(repository: _Repo([near]), location: _Loc(p: const UserPosition(30.0, 31.0)), showTiles: false)));
    await t.pumpAndSettle();
    final icon = t.widget<Icon>(find.byKey(const Key('center_marker')));
    expect(icon.color, Colors.red.shade700);
    final me = t.widget<Container>(find.byKey(const Key('me_marker')));
    expect((me.decoration as BoxDecoration).color, Colors.green.shade600);
  });

  testWidgets('shipped El-Salam row: red marker, source and caveat, distance, directions to its coordinate (test GPS fixture only)', (t) async {
    Uri? opened;
    final raw = (await t.runAsync(() => File('docs/source_records/el_salam_candidate.json').readAsString()))!;
    final repo = AssetCentersRepository(load: () async => raw);
    await t.pumpWidget(wrap(MapScreen(
      repository: repo,
      location: _Loc(p: const UserPosition(31.20, 29.92)), // fixture position only, never an app default
      launcher: (u) async { opened = u; return true; },
      showTiles: false,
    )));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('center_marker')), findsOneWidget);
    expect(t.widget<Icon>(find.byKey(const Key('center_marker'))).color, Colors.red.shade700);
    expect(find.byKey(const Key('me_marker')), findsOneWidget);
    expect(find.textContaining('NOT confirmed'), findsNothing); // Arabic UI shows the Arabic caveat
    expect(find.textContaining('مش مؤكد'), findsWidgets);
    expect(find.textContaining('+20 3 3612794'), findsOneWidget);
    await t.tap(find.byKey(const Key('nav_0')));
    await t.pump();
    expect(opened!.queryParameters['route'], contains('31.17497565667561'));
    expect(opened!.queryParameters['route'], contains('29.906942721769298'));
  });

  group('marker tap dialog', () {
    Future<List<Uri>> open(WidgetTester t) async {
      final launched = <Uri>[];
      final raw = (await t.runAsync(() => File('docs/source_records/el_salam_candidate.json').readAsString()))!;
      await t.pumpWidget(wrap(MapScreen(
        repository: AssetCentersRepository(load: () async => raw),
        location: _Loc(p: const UserPosition(31.20, 29.92)),
        launcher: (u) async { launched.add(u); return true; },
        showTiles: false,
      )));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('center_marker')));
      await t.pumpAndSettle();
      return launched;
    }

    testWidgets('tap shows the place name and the question', (t) async {
      final l = await open(t);
      expect(find.byKey(const Key('open_dialog')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('open_dialog')), matching: find.textContaining('السلام')), findsOneWidget);
      expect(find.text(ar.t('openGmapsQ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('open_dialog')), matching: find.textContaining('مش مؤكد')), findsOneWidget);
      expect(find.textContaining('(مصنع ورق)'), findsNothing);
      expect(l, isEmpty); // nothing launches before an answer
    });

    testWidgets('No closes the dialog and never launches', (t) async {
      final l = await open(t);
      await t.tap(find.byKey(const Key('open_no')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('open_dialog')), findsNothing);
      expect(l, isEmpty);
    });

    testWidgets('Yes launches Google Maps once at the center coordinate', (t) async {
      final l = await open(t);
      await t.tap(find.byKey(const Key('open_yes')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('open_dialog')), findsNothing);
      expect(l.length, 1);
      expect(l.single.host, 'www.google.com');
      expect(l.single.queryParameters['query'], '31.17497565667561,29.906942721769298');
    });
  });
}
