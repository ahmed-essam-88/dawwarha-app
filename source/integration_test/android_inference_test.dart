// On-device smoke test: real bundled ONNX model + real ORT native library, on Android.
// Build in a SEPARATE copy: add dev_dependency `integration_test: {sdk: flutter}` and an asset entry
// for test/fixtures/ in that copy's pubspec only (the release pubspec stays untouched).
// Not run anywhere yet. Reports what it checks: model load, inference on 4 photos, 20 repeated runs.
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('ORT loads and classifies on this device', (tester) async {
    final c = OnnxWasteClassifier();
    Future<ScanResult> run(String n) async =>
        c.classify((await rootBundle.load('test/fixtures/$n')).buffer.asUint8List());
    final news = await run('Newspaper.jpg');
    final plastic = await run('Plastic_bottle.jpg');
    final glass = await run('Glass_bottle.jpg');
    await run('Banana.jpg');
    expect(news.bin, 'paper');
    expect(plastic.probabilities['plastic']!, greaterThan(0.4));
    expect(glass.probabilities['glass']!, greaterThan(0.4));
    for (final r in [news, plastic, glass]) {
      final s = r.probabilities.values.fold<double>(0, (a, b) => a + b);
      expect(s, closeTo(1.0, 0.02));
    }
    for (var i = 0; i < 20; i++) {
      final r = await run('Newspaper.jpg');
      expect(r.bin, 'paper');
    }
  });
}
