import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/app_strings.dart';

/// Address-only directory of collection points listed by their operator. NOT map pins: no coordinates, no distance,
/// no navigation button. Each row opens the owner's own published map link on tap.
class CollectionDirectory extends StatefulWidget {
  final bool arabic;
  final Future<String> Function()? load;
  final Future<bool> Function(Uri)? launcher;
  const CollectionDirectory({super.key, required this.arabic, this.load, this.launcher});
  @override
  State<CollectionDirectory> createState() => _CollectionDirectoryState();
}

class _CollectionDirectoryState extends State<CollectionDirectory> {
  late final Future<List<Map<String, dynamic>>> _f = _read();
  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await (widget.load ?? () => rootBundle.loadString('assets/data/directory.json'))();
    final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    for (final r in rows) {
      if ((r['name'] ?? '').toString().isEmpty || (r['source'] ?? '').toString().isEmpty || !(r['owner_map_url'] ?? '').toString().startsWith('https://')) {
        throw const FormatException('directory row needs name, source and an https owner map link');
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ar = widget.arabic;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _f,
      builder: (c, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final rows = snap.data!;
        Widget group(String city) {
          final items = rows.where((r) => r['city'] == city).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(s.t(city == 'alexandria' ? 'cityAlex' : 'cityCairo'), style: const TextStyle(fontWeight: FontWeight.w600))),
            for (final r in items)
              ListTile(
                key: Key('dir_${r['name']}'),
                title: Text(r[ar ? 'name_ar' : 'name'] as String),
                subtitle: Text([
                  (r[ar ? 'address_ar' : 'address'] as String?) ?? s.t('dirNoAddress'),
                  s.t('dirAccepts'),
                  '${s.t('sourceLabel')}: ${r[ar ? 'source_ar' : 'source']}',
                ].join('\n')),
                isThreeLine: true,
                trailing: IconButton(
                  key: Key('dir_open_${r['name']}'),
                  tooltip: s.t('dirOpenMap'),
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => (widget.launcher ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(Uri.parse(r['owner_map_url'] as String)),
                ),
              ),
          ]);
        }

        return Column(key: const Key('collection_directory'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(s.t('dirTitle'), style: const TextStyle(fontWeight: FontWeight.bold))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('dirNote'), style: const TextStyle(fontSize: 12.5))),
          group('alexandria'),
          group('cairo'),
        ]);
      },
    );
  }
}
