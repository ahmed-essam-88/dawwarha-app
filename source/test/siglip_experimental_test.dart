import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:environmental_challenges/features/scanner/scanner_screen.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/services/scan_history.dart';
import 'package:environmental_challenges/services/siglip_classifier.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ok implements WasteClassifier {
  final String engine;
  _Ok(this.engine);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async => interpretLogits([0, 9, 0, 0, 0, 0], engine: engine);
}

class _Boom implements WasteClassifier {
  int calls = 0;
  @override
  Future<void> load() async => throw StateError('no model');
  @override
  Future<ScanResult> classify(Uint8List b) async {
    calls++;
    throw StateError('out of memory');
  }
}

class _Slow implements WasteClassifier, CancellableClassifier {
  final List<String> events;
  bool cancelled = false, lateResultDelivered = false;
  _Slow(this.events);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async {
    events.add('experimental-start');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (cancelled) throw StateError('cancelled');
    lateResultDelivered = true;
    return interpretLogits([0, 9, 0, 0, 0, 0], engine: 'experimental');
  }

  @override
  bool get nativeMayStillRun => false;

  @override
  Future<void> cancelAndRelease() async {
    events.add('cancel-start');
    cancelled = true;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    events.add('cancel-done');
  }
}

class _Order implements WasteClassifier {
  final List<String> events;
  _Order(this.events);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async {
    events.add('standard-run');
    return interpretLogits([0, 9, 0, 0, 0, 0]);
  }
}

void main() {
  final text = jsonDecode(File('experimental/siglip/siglip_text.json').readAsStringSync()) as Map<String, dynamic>;
  final vec = [for (final r in text['vectors'] as List) [for (final x in r as List) (x as num).toDouble()]];
  final owner = (text['owner'] as List).cast<String>();

  test('7-class decision: class vector answers, organic is flagged unsupported (not relabelled)', () {
    final r = interpretSiglip(vec[owner.indexOf('glass')], vec, owner);
    expect(r.label, 'glass');
    expect(r.bin, 'glass');
    expect(r.engine, 'experimental');
    expect(r.hasProbability, false);
    final org = interpretSiglip(vec[owner.indexOf('organic')], vec, owner);
    expect(org.organicUnsupported, true);
    expect(org.label, 'organic');
    expect(org.bin, isNull);
    expect(org.probabilities.containsKey('organic'), true);
  });

  test('two equally good classes give unknown', () {
    final e0 = List<double>.filled(768, 0)..[0] = 1, e1 = List<double>.filled(768, 0)..[1] = 1;
    final f = List<double>.generate(768, (k) => e0[k] + e1[k]);
    final r = interpretSiglip(f, [e0, e1], ['glass', 'metal']);
    expect(r.isUnknown, true);
    expect(r.bin, isNull);
    expect(r.organicUnsupported, false);
  });

  test('EXIF orientation is applied before preprocessing', () {
    // left half red, right half blue, 120x60, stored with EXIF orientation 6 (needs 90 degrees clockwise)
    final im = img.Image(width: 120, height: 60);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 120; x++) {
        im.setPixelRgb(x, y, x < 60 ? 255 : 0, 0, x < 60 ? 0 : 255);
      }
    }
    im.exif.imageIfd.orientation = 6;
    final withExif = Uint8List.fromList(img.encodeJpg(im, quality: 100));
    final plain = img.Image.from(im)..exif.imageIfd.orientation = 1;
    final withoutExif = Uint8List.fromList(img.encodeJpg(plain, quality: 100));
    final a = preprocessPhoto(withExif), b = preprocessPhoto(withoutExif);
    // orientation 6: the red (left) half ends up on TOP. channel 0 = red; top row red high, bottom row low.
    double px(Float32List t, int c, int y, int x) => t[c * 224 * 224 + y * 224 + x];
    expect(px(a, 0, 10, 112), greaterThan(0.8));
    expect(px(a, 0, 213, 112), lessThan(-0.8));
    // without the tag the red half stays on the LEFT
    expect(px(b, 0, 112, 10), greaterThan(0.8));
    expect(px(b, 0, 112, 213), lessThan(-0.8));
  });

  test('PNG with alpha and grayscale decode to 3 channels', () {
    final rgba = Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30, numChannels: 4)));
    expect(preprocessPhoto(rgba).length, 3 * 224 * 224);
    final gray = Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30, numChannels: 1)));
    expect(preprocessPhoto(gray).length, 3 * 224 * 224);
    expect(() => preprocessPhoto(Uint8List.fromList([1, 2, 3])), throwsA(isA<FormatException>()));
  });

  test('fallback: a failing experimental scanner returns the standard answer and stops retrying', () async {
    final boom = _Boom();
    final fb = FallbackWasteClassifier(boom, _Ok('standard'));
    final r1 = await fb.classify(Uint8List(1));
    expect(r1.engine, 'standard');
    expect(fb.lastUsedFallback, true);
    await fb.classify(Uint8List(1));
    expect(boom.calls, 1);
    final good = FallbackWasteClassifier(_Ok('experimental'), _Ok('standard'));
    expect((await good.classify(Uint8List(1))).engine, 'experimental');
    expect(good.lastUsedFallback, false);
  });

  test('timeout: experimental is cancelled and released BEFORE the standard scanner runs; late result discarded', () async {
    final events = <String>[];
    final slow = _Slow(events);
    final std = _Order(events);
    final fb = FallbackWasteClassifier(slow, std, timeout: const Duration(milliseconds: 50));
    final r = await fb.classify(Uint8List(1));
    expect(r.engine, 'standard');
    expect(fb.lastUsedFallback, true);
    expect(events, ['experimental-start', 'cancel-start', 'cancel-done', 'standard-run']);
    await Future<void>.delayed(const Duration(milliseconds: 300)); // the slow run would finish now
    expect(slow.lateResultDelivered, false);
  });

  Widget host({required bool available, WasteClassifier Function()? factory}) => ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: ScannerScreen(classifier: _Ok('standard'), history: ScanHistory(), experimentalAvailable: available, experimentalFactory: factory),
        ),
      );

  testWidgets('default build shows no experimental switch', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(host(available: false));
    await t.pump();
    expect(find.byKey(const Key('experimentalSwitch')), findsNothing);
  });

  testWidgets('switch is off by default, turning it on is saved', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(host(available: true, factory: () => _Ok('experimental')));
    await t.pump();
    final sw = find.byKey(const Key('experimentalSwitch'));
    expect(sw, findsOneWidget);
    expect(t.widget<SwitchListTile>(sw).value, false);
    await t.tap(sw);
    await t.pump();
    expect(t.widget<SwitchListTile>(sw).value, true);
    expect((await SharedPreferences.getInstance()).getBool('experimentalScanner'), true);
  });

  // Real model through the real Dart path, desktop only. Run with SIG_MODEL=/path/sig_v_wo8.onnx and
  // LD_LIBRARY_PATH pointing at libonnxruntime.so.1.15.1 (see docs/EXPERIMENTAL_SIGLIP_BUILD.md).
  final modelPath = Platform.environment['SIG_MODEL'];
  test('real wo8 model on the four fixture photos (desktop)', () async {
    OrtEnv.instance.init();
    final s = OrtSession.fromFile(File(modelPath!), OrtSessionOptions());
    final out = StringBuffer();
    for (final n in ['Banana', 'Glass_bottle', 'Newspaper', 'Plastic_bottle']) {
      final bytes = File('test/fixtures/$n.jpg').readAsBytesSync();
      final t0 = DateTime.now();
      final data = preprocessPhoto(bytes);
      final tp = DateTime.now().difference(t0).inMilliseconds;
      final input = OrtValueTensor.createTensorWithDataList(data, [1, 3, 224, 224]);
      final ro = OrtRunOptions();
      final o = s.run(ro, {'x': input});
      final f = ((o[0]!.value as List).first as List).map((e) => (e as num).toDouble()).toList();
      final r = interpretSiglip(f, vec, owner);
      final ms = DateTime.now().difference(t0).inMilliseconds;
      out.writeln('$n -> ${r.label} ${(r.topConfidence * 100).toStringAsFixed(0)}% (preprocess ${tp}ms, total ${ms}ms)');
      input.release();
      ro.release();
      for (final x in o) {
        x?.release();
      }
    }
    s.release();
    // ignore: avoid_print
    print(out);
  }, skip: modelPath == null ? 'set SIG_MODEL to run' : false);

  test('real model: cancel mid-inference stops it, frees the worker, and a fresh scanner still works (desktop)', () async {
    final bytes = File('test/fixtures/Glass_bottle.jpg').readAsBytesSync();
    final c = SiglipWasteClassifier()..useModelFile(modelPath!)..setPrompts(vec, owner);
    final warm = await c.classify(bytes); // normal run works through the worker isolate
    expect(warm.label, 'glass');
    final running = c.classify(bytes);
    var outcome = 'result';
    final handled = running.then((_) => outcome = 'result', onError: (_) => outcome = 'error');
    await Future<void>.delayed(const Duration(milliseconds: 250)); // preprocess done, native run in progress
    final sw = Stopwatch()..start();
    await c.cancelAndRelease();
    final cancelMs = sw.elapsedMilliseconds;
    await handled;
    // ignore: avoid_print
    print('cancel took ${cancelMs}ms, in-flight call ended as: $outcome');
    expect(outcome, 'error'); // a result computed after cancel is never delivered
    final c2 = SiglipWasteClassifier()..useModelFile(modelPath)..setPrompts(vec, owner);
    expect((await c2.classify(bytes)).label, 'glass');
    await c2.cancelAndRelease();
  }, skip: modelPath == null ? 'set SIG_MODEL to run' : false, timeout: const Timeout(Duration(seconds: 90)));
}
