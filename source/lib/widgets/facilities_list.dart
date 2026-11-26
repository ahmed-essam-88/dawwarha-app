import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/app_strings.dart';

/// Text-only reference list (no map markers, no coordinates). Not a claim that any place accepts the public.
class FacilitiesList extends StatefulWidget {
  final bool arabic;
  final Future<String> Function()? load;
  const FacilitiesList({super.key, required this.arabic, this.load});
  @override
  State<FacilitiesList> createState() => _FacilitiesListState();
}

class _FacilitiesListState extends State<FacilitiesList> {
  late final Future<List<Map<String, dynamic>>> _f = _read();
  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await (widget.load ?? () => rootBundle.loadString('assets/data/facilities.json'))();
    final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    for (final r in rows) {
      if ((r['source'] ?? '').toString().isEmpty || !(r['url'] ?? '').toString().startsWith('https://')) {
        throw const FormatException('facility without source');
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
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text(s.t('facilitiesTitle'), style: const TextStyle(fontWeight: FontWeight.bold))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.t('facilitiesNote'), style: const TextStyle(fontSize: 12.5))),
          for (final r in snap.data!)
            ListTile(
              key: Key('facility_${r['name_en']}'),
              title: Text(r[ar ? 'name_ar' : 'name_en'] as String),
              subtitle: Text([
                r[ar ? 'address_ar' : 'address_en'],
                if (r['phone'] != null) r['phone'],
                r[ar ? 'info_ar' : 'info_en'],
                '${s.t('sourceLabel')}: ${r[ar ? 'source_ar' : 'source']}',
              ].join('\n')),
              isThreeLine: true,
              trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => launchUrl(Uri.parse(r['url'] as String), mode: LaunchMode.externalApplication)),
            ),
        ]);
      },
    );
  }
}
