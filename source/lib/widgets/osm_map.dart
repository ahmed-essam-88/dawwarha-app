import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Minimal OpenStreetMap slippy map: Web Mercator tiles, drag to pan, +/- zoom.
/// Tiles come from tile.openstreetmap.org with an identifying User-Agent and are
/// cached in memory (OSM tile usage policy: https://operations.osmfoundation.org/policies/tiles/).
class MapMarker {
  final double lat, lon;
  final Widget child;
  final double size;
  /// Box width (defaults to size) and where, inside the box, the coordinate sits (defaults to the centre).
  final double? width, anchorY;
  const MapMarker(this.lat, this.lon, this.child, {this.size = 36, this.width, this.anchorY});
}

/// Projection helpers (public for tests).
double lonToX(double lon, int z) => (lon + 180) / 360 * (1 << z);
double latToY(double lat, int z) {
  final r = lat * pi / 180;
  return (1 - log(tan(r) + 1 / cos(r)) / pi) / 2 * (1 << z);
}

double xToLon(double x, int z) => x / (1 << z) * 360 - 180;
double yToLat(double y, int z) {
  final n = pi - 2 * pi * y / (1 << z);
  return 180 / pi * atan(0.5 * (exp(n) - exp(-n)));
}

final Map<String, Uint8List> _cache = {};
final HttpClient _http = HttpClient()..userAgent = 'com.envchallenges.environmental_challenges/0.3 (Flutter)';

Future<Uint8List?> fetchOsmTile(int z, int x, int y) async {
  final k = '$z/$x/$y';
  final hit = _cache[k];
  if (hit != null) return hit;
  try {
    final req = await _http.getUrl(Uri.https('tile.openstreetmap.org', '/$z/$x/$y.png')).timeout(const Duration(seconds: 10));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    final b = BytesBuilder();
    await for (final c in res) {
      b.add(c);
    }
    final bytes = b.takeBytes();
    if (_cache.length > 200) _cache.remove(_cache.keys.first);
    return _cache[k] = bytes;
  } catch (_) {
    return null;
  }
}

class OsmMap extends StatefulWidget {
  final double lat, lon;
  final int zoom;
  final List<MapMarker> markers;
  final bool showTiles;
  const OsmMap({super.key, required this.lat, required this.lon, this.zoom = 13, this.markers = const [], this.showTiles = true});
  @override
  State<OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends State<OsmMap> {
  late double _cx, _cy; // center in tile coordinates at _z
  late int _z;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _z = widget.zoom;
    _cx = lonToX(widget.lon, _z);
    _cy = latToY(widget.lat, _z);
  }

  @override
  void didUpdateWidget(covariant OsmMap old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lon != widget.lon || old.zoom != widget.zoom) _reset();
  }

  void _zoom(int d) {
    final nz = (_z + d).clamp(3, 18);
    if (nz == _z) return;
    final lat = yToLat(_cy, _z), lon = xToLon(_cx, _z);
    setState(() {
      _z = nz;
      _cx = lonToX(lon, nz);
      _cy = latToY(lat, nz);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      const ts = 256.0;
      final n = 1 << _z;
      final x0 = ((_cx - w / 2 / ts).floor()), x1 = ((_cx + w / 2 / ts).floor());
      final y0 = ((_cy - h / 2 / ts).floor()), y1 = ((_cy + h / 2 / ts).floor());
      Offset toPx(double lat, double lon) => Offset(w / 2 + (lonToX(lon, _z) - _cx) * ts, h / 2 + (latToY(lat, _z) - _cy) * ts);
      return ClipRect(
        child: GestureDetector(
          onPanUpdate: (d) => setState(() {
            _cx -= d.delta.dx / ts;
            _cy -= d.delta.dy / ts;
          }),
          child: Container(
            color: const Color(0xFFE8EEE8),
            child: Stack(children: [
              if (widget.showTiles)
                for (var ty = y0; ty <= y1; ty++)
                  for (var tx = x0; tx <= x1; tx++)
                    if (ty >= 0 && ty < n)
                      Positioned(
                        left: w / 2 + (tx - _cx) * ts,
                        top: h / 2 + (ty - _cy) * ts,
                        width: ts,
                        height: ts,
                        child: _Tile(z: _z, x: ((tx % n) + n) % n, y: ty),
                      ),
              for (final m in widget.markers)
                Builder(builder: (_) {
                  final p = toPx(m.lat, m.lon);
                  return Positioned(left: p.dx - (m.width ?? m.size) / 2, top: p.dy - (m.anchorY ?? m.size / 2), width: m.width ?? m.size, height: m.size, child: m.child);
                }),
              Positioned(
                right: 8,
                top: 8,
                child: Column(children: [
                  IconButton.filled(key: const Key('zoom_in'), style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 2, side: BorderSide.none), onPressed: () => _zoom(1), icon: const Icon(Icons.add)),
                  const SizedBox(height: 6),
                  IconButton.filled(key: const Key('zoom_out'), style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 2, side: BorderSide.none), onPressed: () => _zoom(-1), icon: const Icon(Icons.remove)),
                ]),
              ),
              const Positioned(
                left: 4,
                bottom: 2,
                child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black87, backgroundColor: Color(0xCCFFFFFF))),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _Tile extends StatelessWidget {
  final int z, x, y;
  const _Tile({required this.z, required this.x, required this.y});
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: fetchOsmTile(z, x, y),
        builder: (c, s) => s.data == null ? const SizedBox.shrink() : Image.memory(s.data!, fit: BoxFit.fill, gaplessPlayback: true),
      );
}
