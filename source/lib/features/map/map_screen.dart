import 'dart:math' show min, max, sqrt, cos, pi;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recycling_center.dart';
import '../../repositories/centers_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/osm_map.dart';
import '../../widgets/facilities_list.dart';
import '../../widgets/collection_directory.dart';
import '../../providers/locale_provider.dart';
import 'package:provider/provider.dart';

/// Google Maps URL for a point (documented Maps URLs scheme), built only from our own sourced coordinates.
Uri googleMapsPlaceUri(double lat, double lon) => Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lon'});

class MapScreen extends StatefulWidget {
  final CentersRepository? repository;
  final LocationService? location;
  final Future<bool> Function(Uri)? launcher;
  final Future<String> Function()? facilitiesLoad;
  final Future<String> Function()? directoryLoad;
  final bool showTiles; // false in tests: no network
  const MapScreen({super.key, this.repository, this.location, this.launcher, this.facilitiesLoad, this.directoryLoad, this.showTiles = true});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<RecyclingCenter>? _centers;
  bool _centersError = false;
  UserPosition? _me;
  String? _locMsgKey;
  bool _loading = false;

  late final CentersRepository _repo = widget.repository ?? AssetCentersRepository();
  LocationService get _loc => widget.location ?? DeviceLocationService();

  @override
  void initState() {
    super.initState();
    _loadCenters();
    _locate();
  }

  Future<void> _loadCenters() async {
    try {
      final c = await _repo.fetch();
      if (mounted) setState(() => _centers = c);
    } catch (_) {
      if (mounted) setState(() => _centersError = true);
    }
  }

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _locMsgKey = null;
    });
    try {
      final p = await _loc.current();
      if (mounted) setState(() => _me = p);
    } on LocationException catch (e) {
      if (mounted) {
        setState(() => _locMsgKey = switch (e.reason) {
              LocationFailure.serviceOff => 'locOff',
              LocationFailure.denied => 'locDenied',
              LocationFailure.deniedForever => 'locDeniedForever',
              LocationFailure.failed => 'locFailed',
            });
      }
    } catch (_) {
      if (mounted) setState(() => _locMsgKey = 'locFailed');
    }
    if (mounted) setState(() => _loading = false);
  }

  double? _dist(RecyclingCenter c) => _me == null ? null : distanceMeters(_me!.lat, _me!.lon, c.lat, c.lon);

  Future<void> _navigate(RecyclingCenter c) async {
    final uri = directionsUri(_me, c.lat, c.lon);
    final ok = await (widget.launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S(context.read<LocaleProvider>().isArabic).t('navFailed'))));
  }

  /// Tapping a red marker names the place and asks whether to open it in Google Maps. Yes opens it, No only closes the dialog.
  Future<void> _askOpen(RecyclingCenter c) async {
    final ar = context.read<LocaleProvider>().isArabic;
    final s = S(ar);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        key: const Key('open_dialog'),
        title: Text(ar && c.nameAr != null ? c.nameAr! : c.name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((ar ? c.noteAr : c.noteEn) != null) Padding(key: const Key('open_caveat'), padding: const EdgeInsets.only(bottom: 12), child: Text((ar ? c.noteAr : c.noteEn)!, style: const TextStyle(fontSize: 13))),
          Text(s.t('openGmapsQ')),
        ]),
        actions: [
          TextButton(key: const Key('open_no'), onPressed: () => Navigator.of(dctx).pop(false), child: Text(s.t('no'))),
          FilledButton(key: const Key('open_yes'), onPressed: () => Navigator.of(dctx).pop(true), child: Text(s.t('yes'))),
        ],
      ),
    );
    if (yes == true && mounted) {
      final ok = await (widget.launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(googleMapsPlaceUri(c.lat, c.lon));
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('navFailed'))));
    }
  }

  static double _km(double la1, double lo1, double la2, double lo2) {
    final dy = (la1 - la2) * 111.32, dx = (lo1 - lo2) * 111.32 * cos((la1 + la2) / 2 * pi / 180);
    return sqrt(dx * dx + dy * dy);
  }

  String _fmt(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ar = context.read<LocaleProvider>().isArabic;
    final centers = [...?_centers];
    if (_me != null) centers.sort((a, b) => _dist(a)!.compareTo(_dist(b)!));
    // Frame the user (when known) and every center in the same city (within 60 km of the user, or of the first center)
    // so all pins of that city are on screen at the start, not only the nearest one.
    var center = _me != null ? (_me!.lat, _me!.lon) : (centers.isNotEmpty ? (centers.first.lat, centers.first.lon) : (30.0444, 31.2357));
    var zoom = _me != null || centers.isNotEmpty ? 13 : 5;
    if (centers.isNotEmpty) {
      final ref = _me != null ? (_me!.lat, _me!.lon) : (centers.first.lat, centers.first.lon);
      final pts = <(double, double)>[
        if (_me != null) (_me!.lat, _me!.lon),
        for (final c in centers)
          if (_km(ref.$1, ref.$2, c.lat, c.lon) <= 60) (c.lat, c.lon),
      ];
      if (pts.isEmpty) pts.add((centers.first.lat, centers.first.lon));
      final minLa = pts.map((e) => e.$1).reduce(min), maxLa = pts.map((e) => e.$1).reduce(max);
      final minLo = pts.map((e) => e.$2).reduce(min), maxLo = pts.map((e) => e.$2).reduce(max);
      center = ((minLa + maxLa) / 2, (minLo + maxLo) / 2);
      zoom = 3;
      for (var z = 15; z >= 3; z--) {
        final dx = (lonToX(maxLo, z) - lonToX(minLo, z)).abs() * 256, dy = (latToY(minLa, z) - latToY(maxLa, z)).abs() * 256;
        if (dx < 300 && dy < 260) {
          zoom = z;
          break;
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.t('map')), actions: [
        IconButton(key: const Key('locate'), onPressed: _loading ? null : _locate, icon: const Icon(Icons.my_location)),
      ]),
      body: Column(children: [
        Expanded(
          flex: 3,
          child: OsmMap(
            lat: center.$1,
            lon: center.$2,
            zoom: zoom,
            showTiles: widget.showTiles,
            markers: [
              for (final c in centers)
                MapMarker(
                  c.lat,
                  c.lon,
                  GestureDetector(
                    key: Key('center_tap_${c.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _askOpen(c),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on, color: Colors.red.shade700, size: 38, key: const Key('center_marker')),
                      Container(
                        key: Key('center_label_${c.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.88), borderRadius: BorderRadius.circular(4)),
                        child: Text(_shortName(c, ar), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                      ),
                    ]),
                  ),
                  size: 58,
                  width: 120,
                  anchorY: 38, // the pin's tip (bottom of the 38 px icon) sits on the coordinate
                ),
              if (_me != null)
                MapMarker(
                  _me!.lat,
                  _me!.lon,
                  Container(
                    key: const Key('me_marker'),
                    decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  ),
                  size: 28,
                ),
            ],
          ),
        ),
        if (_locMsgKey != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(s.t(_locMsgKey!), key: const Key('loc_msg'))),
        Expanded(flex: 2, child: _list(s, centers)),
      ]),
    );
  }

  Widget _list(S s, List<RecyclingCenter> centers) {
    final ar = context.read<LocaleProvider>().isArabic;
    if (_centersError) return _msg(s.t('centersError'));
    if (_centers == null) return const Center(child: CircularProgressIndicator());
    if (centers.isEmpty) {
      return ListView(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(s.t('centersEmpty'), textAlign: TextAlign.center)),
        CollectionDirectory(arabic: ar, load: widget.directoryLoad, launcher: widget.launcher),
        FacilitiesList(arabic: ar, load: widget.facilitiesLoad),
      ]);
    }
    return ListView(children: [
      Padding(key: const Key('coverage_note'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text(s.t('coverageNote'), style: const TextStyle(fontSize: 12, color: AppColors.textGray))),
      for (final c in centers)
        ListTile(
          key: Key('center_${c.id}'),
          title: Text(ar && c.nameAr != null ? c.nameAr! : c.name),
          subtitle: Text([
            if (_dist(c) != null) _fmt(_dist(c)!) else s.t('distUnknown'),
            if (c.address != null) (ar && c.addressAr != null ? c.addressAr! : c.address!),
            if (c.phone != null) '\u2066${c.phone}\u2069',
            if (c.hours != null) c.hours!,
            if ((ar ? c.noteAr : c.noteEn) != null) (ar ? c.noteAr! : c.noteEn!),
            '${s.t('sourceLabel')}: ${ar ? c.sourceAr : c.source}',
          ].join('\n')),
          isThreeLine: true,
          onLongPress: c.sourceUrl == null ? null : () => launchUrl(Uri.parse(c.sourceUrl!), mode: LaunchMode.externalApplication),
          trailing: IconButton(key: Key('nav_${c.id}'), icon: const Icon(Icons.directions, color: AppColors.primary), onPressed: () => _navigate(c)),
        ),
      CollectionDirectory(arabic: ar, load: widget.directoryLoad, launcher: widget.launcher),
      FacilitiesList(arabic: ar, load: widget.facilitiesLoad),
    ]);
  }

  /// Marker label: the place name without the trailing "(...)" qualifier.
  String _shortName(RecyclingCenter c, bool ar) {
    final n = ar && c.nameAr != null ? c.nameAr! : c.name;
    return n.replaceAll(RegExp(r'\s*\(.*\)\s*$'), '').trim();
  }

  Widget _msg(String m) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(m, textAlign: TextAlign.center)));
}
