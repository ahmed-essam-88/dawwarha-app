import 'dart:async';
import 'dart:typed_data';

import 'package:environmental_challenges/services/siglip_classifier.dart';
import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _HangingPrimary implements WasteClassifier, CancellableClassifier {
  final bool busyAfterCancel; // whether the native run is still executing after cancel
  bool busy = false;
  int cancels = 0;
  _HangingPrimary(this.busyAfterCancel);
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) => Completer<ScanResult>().future; // never returns: stuck native run
  @override
  Future<void> cancelAndRelease() async {
    cancels++;
    busy = busyAfterCancel;
  }
  @override
  bool get nativeMayStillRun => busy;
}

class _CountingStd implements WasteClassifier {
  int calls = 0;
  @override
  Future<void> load() async {}
  @override
  Future<ScanResult> classify(Uint8List b) async {
    calls++;
    return interpretLogits([0, 9, 0, 0, 0, 0]);
  }
}

void main() {
  final img = Uint8List(4);
  test('timeout while the native run did not return: no standard inference, ExperimentalBusy, ownership kept', () async {
    final p = _HangingPrimary(true);
    final std = _CountingStd();
    final fb = FallbackWasteClassifier(p, std, timeout: const Duration(milliseconds: 50));
    await expectLater(fb.classify(img), throwsA(isA<ExperimentalBusy>()));
    expect(std.calls, 0);
    expect(p.cancels, 1);
    // while it is still running every later scan is refused without inference and without a second cancel/session
    await expectLater(fb.classify(img), throwsA(isA<ExperimentalBusy>()));
    await expectLater(fb.classify(img), throwsA(isA<ExperimentalBusy>()));
    expect(std.calls, 0);
    expect(p.cancels, 1);
    // native run finally returned: standard scanner works again, the experimental path is not retried
    p.busy = false;
    final r = await fb.classify(img);
    expect(r.engine, 'standard');
    expect(std.calls, 1);
    expect(p.cancels, 1);
  });

  test('timeout when the native run ended cleanly: falls back to standard as before', () async {
    final p = _HangingPrimary(false);
    final std = _CountingStd();
    final fb = FallbackWasteClassifier(p, std, timeout: const Duration(milliseconds: 50));
    final r = await fb.classify(img);
    expect(r.engine, 'standard');
    expect(fb.lastUsedFallback, true);
    expect(std.calls, 1);
  });

  test('a new classifier cannot load a second session while a cancelled native run has not returned', () async {
    SiglipWasteClassifier.debugSetOrphans(1);
    final c = SiglipWasteClassifier();
    await expectLater(c.load(), throwsA(isA<ExperimentalBusy>()));
    expect(c.nativeMayStillRun, true);
    SiglipWasteClassifier.debugSetOrphans(0);
  });

  test('releasePrimary stops the experimental scanner without running any inference', () async {
    final p = _HangingPrimary(false);
    final std = _CountingStd();
    final fb = FallbackWasteClassifier(p, std);
    fb.releasePrimary();
    await Future<void>.delayed(Duration.zero);
    expect(p.cancels, 1);
    expect(std.calls, 0);
  });
}
