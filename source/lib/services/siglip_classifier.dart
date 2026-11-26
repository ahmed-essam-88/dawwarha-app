import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import 'siglip_preprocess.dart';
import 'waste_classifier.dart';

/// EXPERIMENTAL scanner: google/siglip-base-patch16-224 (Apache-2.0 per its model card), vision tower only,
/// weight-only int8 (per-channel int8 weights, fp32 activations) so it does not break on last-bit input
/// differences. Zero-shot: the image feature is compared with fixed text prompts per class.
/// Not part of the default app. Enabled only in a build made with --dart-define=EXPERIMENTAL_SIGLIP=true
/// that also bundles experimental/siglip/ (see docs/EXPERIMENTAL_SIGLIP_BUILD.md), and only when the user
/// switches it on. The standard scanner stays the default and the fallback.
const bool experimentalSiglipBuild = bool.fromEnvironment('EXPERIMENTAL_SIGLIP');

const siglipModelAsset = 'experimental/siglip/sig_v_wo8.onnx';
const siglipTextAsset = 'experimental/siglip/siglip_text.json';

/// PROVISIONAL, not calibrated on reserved data. The "score" is a similarity softmax, not a probability.
/// Pipeline outcomes on reused dev sets are in docs/ml_scripts/pipeline_eval_2026-11-25.txt.
const siglipTemperature = 100.0;
const siglipMinScore = 0.60;

const siglipClasses = ['cardboard', 'glass', 'metal', 'organic', 'paper', 'plastic', 'trash'];

/// Pure decision, all 7 classes kept: organic winning is reported as organic-unsupported (never relabelled),
/// a weak top score is unknown, otherwise the winning class.
ScanResult interpretSiglip(List<double> feature, List<List<double>> text, List<String> owner) {
  var n = 0.0;
  for (final v in feature) {
    n += v * v;
  }
  n = math.sqrt(n);
  final best = {for (final c in siglipClasses) c: -1e9};
  for (var i = 0; i < text.length; i++) {
    var d = 0.0;
    for (var k = 0; k < feature.length; k++) {
      d += feature[k] * text[i][k];
    }
    d /= n;
    if (d > best[owner[i]]!) best[owner[i]] = d;
  }
  final z = [for (final c in siglipClasses) best[c]! * siglipTemperature];
  final m = z.reduce(math.max);
  final e = [for (final v in z) math.exp(v - m)];
  final sum = e.reduce((a, b) => a + b);
  final probs = {for (var i = 0; i < siglipClasses.length; i++) siglipClasses[i]: e[i] / sum};
  var top = 0;
  for (var i = 1; i < e.length; i++) {
    if (e[i] > e[top]) top = i;
  }
  final label = siglipClasses[top];
  final score = e[top] / sum;
  if (label == 'organic') {
    return ScanResult(probs, 'organic', score, null, engine: 'experimental', organicUnsupported: true);
  }
  if (score < siglipMinScore) return ScanResult(probs, null, score, null, engine: 'experimental');
  return ScanResult(probs, label, score, binForLabel(label), engine: 'experimental');
}

/// Decode, apply EXIF orientation, drop alpha and run the SigLIP preprocessing. Pure Dart, runs in an isolate.
/// The whole photo is squashed to 224x224 as the SigLIP processor does (the evaluation used object crops).
Float32List preprocessPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('unreadable image');
  final oriented = img.bakeOrientation(decoded);
  final rgb = oriented.convert(numChannels: 3, format: img.Format.uint8);
  final data = rgb.getBytes(order: img.ChannelOrder.rgb);
  return siglipPreprocess(Uint8List.fromList(data), rgb.width, rgb.height);
}

class ExperimentalUnavailable implements Exception {
  final String reason;
  const ExperimentalUnavailable(this.reason);
  @override
  String toString() => 'ExperimentalUnavailable($reason)';
}

/// A classifier whose in-flight work can be stopped and whose memory can be released.
abstract class CancellableClassifier {
  Future<void> cancelAndRelease();

  /// True while a native run that was cancelled has not actually returned yet (cannot be stopped from Dart).
  bool get nativeMayStillRun;
}

/// Thrown instead of any inference while an earlier native run may still be executing. The caller shows "try later".
class ExperimentalBusy implements Exception {
  const ExperimentalBusy();
  @override
  String toString() => 'ExperimentalBusy';
}

// ---- worker isolate: owns the ONNX session; every message gets exactly one reply, errors included ----

void _siglipWorker(SendPort main) {
  final port = ReceivePort();
  main.send(port.sendPort);
  OrtSession? session;
  port.listen((dynamic m) {
    final msg = m as List;
    final reply = msg.last as SendPort;
    try {
      switch (msg[0]) {
        case 'load':
          OrtEnv.instance.init();
          final opts = OrtSessionOptions()..setIntraOpNumThreads(2);
          // Arena off: measured on desktop, the default memory arena kept growing (peak 876 MB after 2 runs) while
          // with it off RSS stayed about 310 MB over 4 runs at the same speed. Not measured on a phone.
          opts.appendCPUProvider(CPUFlags.useNone);
          session = OrtSession.fromFile(File(msg[1] as String), opts);
          reply.send('ok');
        case 'run':
          final data = (msg[1] as TransferableTypedData).materialize().asFloat32List();
          final input = OrtValueTensor.createTensorWithDataList(data, [1, 3, 224, 224]);
          final ro = OrtRunOptions.fromAddress(msg[2] as int); // owned and released by the main isolate
          List<OrtValue?>? out;
          try {
            out = session!.run(ro, {'x': input});
            final f = (out[0]!.value as List).first as List;
            reply.send(Float32List.fromList([for (final e in f) (e as num).toDouble()]));
          } finally {
            input.release();
            for (final o in out ?? const <OrtValue?>[]) {
              o?.release();
            }
          }
        case 'close':
          session?.release();
          session = null;
          reply.send('closed');
          port.close();
      }
    } catch (e) {
      reply.send('error: $e');
    }
  });
}

class SiglipWasteClassifier implements WasteClassifier, CancellableClassifier {
  Isolate? _isolate;
  SendPort? _worker;
  List<List<double>>? _text;
  List<String>? _owner;
  Future<void>? _loading;
  OrtRunOptions? _activeRun;
  Completer<Object?>? _activeReply;
  bool _cancelled = false;

  Future<Object?> _ask(List<Object?> parts, {Duration? timeout}) {
    final rp = ReceivePort();
    final c = Completer<Object?>();
    rp.listen((m) {
      if (!c.isCompleted) c.complete(m);
      rp.close();
    });
    _worker!.send([...parts, rp.sendPort]);
    _activeReply = c;
    final f = timeout == null ? c.future : c.future.timeout(timeout);
    return f;
  }

  @override
  Future<void> load() {
    if (_orphans > 0 && _loading == null) return Future<void>.error(const ExperimentalBusy());
    return _load0();
  }

  Future<void> _load0() => _loading ??= _load().catchError((Object e) {
        _loading = null; // allow a later retry
        throw e is ExperimentalUnavailable ? e : ExperimentalUnavailable('$e');
      });

  Future<void> _load() async {
    _cancelled = false;
    final j = jsonDecode(await rootBundle.loadString(siglipTextAsset)) as Map<String, dynamic>;
    _text = [for (final r in j['vectors'] as List) [for (final x in r as List) (x as num).toDouble()]];
    _owner = (j['owner'] as List).cast<String>();
    // Copied once to app storage so the runtime reads the model from a file and the app does not keep a second
    // 98 MB copy in memory. If copy or load fails, the caller falls back to the standard scanner.
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/sig_v_wo8.onnx');
    final asset = await rootBundle.load(siglipModelAsset);
    if (!await f.exists() || await f.length() != asset.lengthInBytes) {
      await f.writeAsBytes(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes), flush: true);
    }
    await startWorker(f.path);
  }

  /// Starts the worker and loads the model file. Public so tests can load a model from a path.
  Future<void> startWorker(String path) async {
    final rp = ReceivePort();
    _isolate = await Isolate.spawn(_siglipWorker, rp.sendPort);
    _worker = await rp.first as SendPort;
    final r = await _ask(['load', path], timeout: const Duration(seconds: 120));
    if (r != 'ok') throw ExperimentalUnavailable('$r');
  }

  /// Test hook: load the model from a file path instead of the bundled asset.
  void useModelFile(String path) => _loading = startWorker(path);

  void setPrompts(List<List<double>> text, List<String> owner) {
    _text = text;
    _owner = owner;
  }

  @override
  Future<ScanResult> classify(Uint8List imageBytes) async {
    await load();
    if (_activeRun != null) throw const ExperimentalUnavailable('busy');
    final data = await Isolate.run(() => preprocessPhoto(imageBytes));
    if (_cancelled) throw const ExperimentalUnavailable('cancelled');
    final ro = OrtRunOptions();
    _activeRun = ro;
    final Object? r;
    try {
      r = await _ask(['run', TransferableTypedData.fromList([data.buffer.asUint8List()]), ro.address]);
    } finally {
      _activeRun = null; // cleared before release so cancel never touches a freed pointer
      ro.release();
    }
    if (_cancelled) throw const ExperimentalUnavailable('cancelled');
    if (r is! Float32List) throw ExperimentalUnavailable('$r');
    return interpretSiglip(r, _text!, _owner!);
  }

  /// Stops the running inference (ONNX Runtime checks the terminate flag between operators), waits for the worker
  /// to give the run back, then frees the session and the worker isolate. A result that arrives after this is
  /// discarded. If the worker does not answer within [wait], it is killed and a native run may still finish in
  /// the background; that case cannot be detected from Dart.
  @override
  Future<void> cancelAndRelease({Duration wait = const Duration(seconds: 8)}) async {
    _cancelled = true;
    _loading = null;
    final worker = _worker, isolate = _isolate;
    _activeRun?.setTerminate();
    final pending = _activeReply;
    var ended = true; // true when no native run is known to be in flight
    if (pending != null && !pending.isCompleted) {
      try {
        await pending.future.timeout(wait);
      } catch (_) {
        ended = false;
      }
    }
    if (!ended) {
      // The native run did not give control back in time. Killing the isolate would not stop it, so the worker is
      // left alone and is closed and killed only when its reply finally arrives. [nativeMayStillRun] stays true
      // until then so callers do not start another heavy native run on the strength of "cancelled".
      _orphans++;
      _isolate = null;
      _worker = null;
      _activeReply = null;
      // ignore: unawaited_futures
      pending!.future.then((_) {
        try {
          worker?.send(['close', ReceivePort().sendPort]);
        } catch (_) {}
        Future<void>.delayed(const Duration(seconds: 1), () => isolate?.kill(priority: Isolate.immediate));
        _orphans--;
      });
      return;
    }
    if (worker != null) {
      final rp = ReceivePort();
      worker.send(['close', rp.sendPort]);
      try {
        await rp.first.timeout(const Duration(seconds: 3));
      } catch (_) {}
      rp.close();
    }
    isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _worker = null;
    _activeReply = null;
  }

  /// Number of cancelled native runs (across ALL instances, so a screen dispose/recreate cannot start a second
  /// session on top of one) that have not returned yet.
  static int _orphans = 0;

  /// Test hook: pretend [n] cancelled native runs have not returned.
  static void debugSetOrphans(int n) => _orphans = n;

  /// True while any cancelled native run has not returned yet.
  @override
  bool get nativeMayStillRun => _orphans > 0;
}

/// Tries the experimental scanner; on ANY failure (model missing, load, memory, inference) or after [timeout] it
/// stops and frees the experimental session FIRST, then asks the standard scanner. The standard result is never
/// altered, a late experimental result is discarded, and the experimental path is not retried in that session.
class FallbackWasteClassifier implements WasteClassifier {
  final WasteClassifier primary;
  final WasteClassifier fallback;
  final Duration timeout;
  bool lastUsedFallback = false;
  bool _primaryBroken = false;
  FallbackWasteClassifier(this.primary, this.fallback, {this.timeout = const Duration(seconds: 25)});

  /// Stops and frees the experimental scanner (screen dispose or switch off). Does not start any inference.
  void releasePrimary() {
    _primaryBroken = true;
    final p = primary;
    if (p is CancellableClassifier) {
      // ignore: unawaited_futures
      (p as CancellableClassifier).cancelAndRelease().catchError((_) {});
    }
  }

  @override
  Future<void> load() => fallback.load();

  @override
  Future<ScanResult> classify(Uint8List imageBytes) async {
    lastUsedFallback = false;
    final own = primary is CancellableClassifier ? primary as CancellableClassifier : null;
    // A cancelled native run that has not returned keeps ownership: no standard inference, no new session.
    if (own != null && own.nativeMayStillRun) throw const ExperimentalBusy();
    if (!_primaryBroken) {
      try {
        return await primary.classify(imageBytes).timeout(timeout);
      } catch (_) {
        _primaryBroken = true;
        final p = primary;
        if (p is CancellableClassifier) {
          try {
            await (p as CancellableClassifier).cancelAndRelease();
          } catch (_) {}
          if ((p as CancellableClassifier).nativeMayStillRun) throw const ExperimentalBusy();
        }
      }
    }
    lastUsedFallback = true;
    return fallback.classify(imageBytes);
  }
}
