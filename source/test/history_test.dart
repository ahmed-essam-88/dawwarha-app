import 'package:environmental_challenges/services/scan_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('history keeps the newest 30 entries, survives reload, can be cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final h = ScanHistory();
    expect(await h.load(), isEmpty);
    for (var i = 0; i < 35; i++) {
      await h.add(ScanEntry(DateTime(2026, 1, 1, 0, i), i.isEven ? 'plastic' : null, 0.5 + i / 100));
    }
    final l = await ScanHistory().load();
    expect(l.length, 30);
    expect(l.first.at, DateTime(2026, 1, 1, 0, 34));
    expect(l.first.label, 'plastic');
    expect(l[1].label, isNull);
    await h.clear();
    expect(await h.load(), isEmpty);
  });
}
