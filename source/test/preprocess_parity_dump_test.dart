// Dumps the app's real softmax output (same Dart decode, resize, normalisation
// and model as the app) for every image in a folder, to compare with Python.
// Usage: PARITY_DIR=/path/to/images PARITY_OUT=out.csv LD_LIBRARY_PATH=<dir of libonnxruntime.so>
//        flutter test test/preprocess_parity_dump_test.dart
import 'dart:io';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['PARITY_DIR'];
  final out = Platform.environment['PARITY_OUT'];
  test('dump app probabilities', skip: dir == null || out == null || Platform.environment['LD_LIBRARY_PATH'] == null ? 'set PARITY_DIR, PARITY_OUT, LD_LIBRARY_PATH' : false, () async {
    final c = OnnxWasteClassifier();
    final files = Directory(dir!).listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    final sink = File(out!).openWrite();
    for (final f in files) {
      final r = await c.classify(f.readAsBytesSync());
      final p = r.probabilities;
      sink.writeln([f.uri.pathSegments.last, ...modelLabels.map((l) => p[l]!.toStringAsFixed(7))].join(','));
    }
    await sink.close();
  }, timeout: const Timeout(Duration(minutes: 40)));
}
