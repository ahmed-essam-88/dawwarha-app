import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:environmental_challenges/services/siglip_classifier.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';

/// Repeated app-like lifecycle on the REAL model, desktop only (needs SIG_MODEL and the ORT 1.15.1 library on
/// LD_LIBRARY_PATH). Not Android proof.
void main() {
  final modelPath = Platform.environment['SIG_MODEL'];
  final skip = modelPath == null ? 'set SIG_MODEL to run' : false;
  final text = jsonDecode(File('experimental/siglip/siglip_text.json').readAsStringSync()) as Map<String, dynamic>;
  final vec = [for (final r in text['vectors'] as List) [for (final x in r as List) (x as num).toDouble()]];
  final owner = (text['owner'] as List).cast<String>();
  final bytes = File('test/fixtures/Glass_bottle.jpg').readAsBytesSync();
  SiglipWasteClassifier make() => SiglipWasteClassifier()..useModelFile(modelPath!)..setPrompts(vec, owner);

  test('8 cycles: load, classify, cancel mid-run at varying moments, dispose, with a standard-style session alive', () async {
    OrtEnv.instance.init();
    final std = OrtSession.fromFile(File(modelPath!), OrtSessionOptions()); // stands in for the standard scanner's resident session
    final log = <String>[];
    for (var i = 0; i < 8; i++) {
      final c = make();
      expect((await c.classify(bytes)).label, 'glass', reason: 'cycle $i warm run');
      final f = c.classify(bytes);
      var o = 'result';
      final h = f.then((_) => o = 'result', onError: (_) => o = 'error');
      await Future<void>.delayed(Duration(milliseconds: 20 + i * 60)); // cancel during preprocess, at the start, middle and end of the native run
      await c.cancelAndRelease();
      await h;
      log.add('cycle $i cancel after ${20 + i * 60}ms -> $o');
      // ignore: avoid_print
      print(log.last);
      await c.cancelAndRelease(); // double dispose must be harmless
    }
    std.release();
    // ignore: avoid_print
    print(log.join('\n'));
  }, skip: skip, timeout: const Timeout(Duration(seconds: 110)));

  test('fallback with the real model and a 150 ms timeout, three times in a row, then a normal scan', () async {
    for (var i = 0; i < 3; i++) {
      final fb = FallbackWasteClassifier(make(), _Std(), timeout: const Duration(milliseconds: 150));
      final r = await fb.classify(bytes);
      expect(r.engine, 'standard', reason: 'cycle $i');
      expect(fb.lastUsedFallback, true);
    }
    final c = make();
    expect((await c.classify(bytes)).label, 'glass');
    await c.cancelAndRelease();
  }, skip: skip, timeout: const Timeout(Duration(seconds: 110)));

  test('classify while another is running is refused, not queued on the native session', () async {
    final c = make();
    await c.classify(bytes);
    final a = c.classify(bytes);
    Object? err;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await c.classify(bytes);
    } catch (e) {
      err = e;
    }
    await a;
    expect(err, isA<ExperimentalUnavailable>());
    await c.cancelAndRelease();
  }, skip: skip, timeout: const Timeout(Duration(seconds: 110)));
}

class _Std implements WasteClassifier {
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async => interpretLogits([0, 9, 0, 0, 0, 0]);
}
