import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScanEntry {
  final DateTime at;
  final String? label; // null = the model was not sure
  final double confidence;
  const ScanEntry(this.at, this.label, this.confidence);
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'label': label, 'confidence': confidence};
  static ScanEntry fromJson(Map<String, dynamic> j) => ScanEntry(DateTime.parse(j['at'] as String), j['label'] as String?, (j['confidence'] as num).toDouble());
}

/// Scan history kept only on this phone (label, confidence and time; no photos).
class ScanHistory {
  static const _key = 'scan_history', maxEntries = 30;

  Future<List<ScanEntry>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => ScanEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ScanEntry e) async {
    final list = [e, ...await load()].take(maxEntries).toList();
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(list.map((x) => x.toJson()).toList()));
  }

  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}
