// Runs the real Dart classifier code and the real bundled ONNX model on the
// desktop. Needs libonnxruntime.so on LD_LIBRARY_PATH. Not an Android test.
import 'dart:io';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final c = OnnxWasteClassifier();
  Future<ScanResult> run(String n) =>
      c.classify(File('test/fixtures/$n').readAsBytesSync());
  test('real model on real photos', skip: Platform.environment['LD_LIBRARY_PATH'] == null ? 'needs libonnxruntime.so on LD_LIBRARY_PATH' : false, () async {
    final out = <String, ScanResult>{};
    for (final n in ['Glass_bottle.jpg', 'Newspaper.jpg', 'Plastic_bottle.jpg', 'Banana.jpg']) {
      out[n] = await run(n);
      final r = out[n]!;
      // ignore: avoid_print
      print('$n label=${r.label} bin=${r.bin} top=${r.topConfidence.toStringAsFixed(2)} '
          '${r.probabilities.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(2)}').join(' ')}');
    }
    expect(out['Newspaper.jpg']!.bin, 'paper');
    expect(out['Glass_bottle.jpg']!.probabilities['glass']!, greaterThan(0.4));
    expect(out['Plastic_bottle.jpg']!.probabilities['plastic']!, greaterThan(0.4));
    // Known limit: the model has no organic class, so a banana gets a wrong
    // answer. Printed above on purpose; not asserted as correct.
  });
}
