import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// Labels of the bundled model, in output order (RecycleNet, TrashNet classes).
const modelLabels = ['cardboard', 'glass', 'metal', 'paper', 'plastic', 'trash'];

/// Below this top probability the app says it is not sure. Not tuned on a
/// large dataset; a conservative starting value.
const minConfidence = 0.60;

class ScanResult {
  /// Raw probability per model label (sums to about 1).
  final Map<String, double> probabilities;

  /// Winning model label, or null when the model is not sure.
  final String? label;
  final double topConfidence;

  /// Bin key (plastic, metal, glass, paper) or null if unknown / not recyclable.
  final String? bin;

  /// Which scanner produced this: 'standard' (bundled RecycleNet) or 'experimental'.
  final String engine;
  const ScanResult(this.probabilities, this.label, this.topConfidence, this.bin, {this.engine = 'standard', this.organicUnsupported = false});

  /// Experimental scanner only: organic waste won. The app does not support organic, so it must say so and
  /// let the user choose, never show another label.
  final bool organicUnsupported;

  /// The standard scanner's top probability is a softmax output. The experimental score is not a probability.
  bool get hasProbability => engine == 'standard';

  bool get isUnknown => label == null;
}

/// Replaceable model interface.
abstract class WasteClassifier {
  Future<void> load();
  Future<ScanResult> classify(Uint8List imageBytes);
}

/// Bin key for a model label; null for the non-recyclable class (and organic, which has no bin here).
String? binForLabel(String label) => switch (label) {
      'cardboard' || 'paper' => 'paper',
      'glass' => 'glass',
      'metal' => 'metal',
      'plastic' => 'plastic',
      _ => null,
    };

/// Pure post-processing, unit-tested without the native runtime.
ScanResult interpretLogits(List<double> logits, {String engine = 'standard'}) {
  final maxV = logits.reduce(math.max);
  final exps = logits.map((l) => math.exp(l - maxV)).toList();
  final sum = exps.reduce((a, b) => a + b);
  final probs = {
    for (var i = 0; i < modelLabels.length; i++) modelLabels[i]: exps[i] / sum,
  };
  var top = 0;
  for (var i = 1; i < probs.length; i++) {
    if (exps[i] > exps[top]) top = i;
  }
  final conf = exps[top] / sum;
  final label = modelLabels[top];
  if (conf < minConfidence) return ScanResult(probs, null, conf, null, engine: engine);
  return ScanResult(probs, label, conf, binForLabel(label), engine: engine);
}

/// Runs the bundled ONNX model on the device. No network.
class OnnxWasteClassifier implements WasteClassifier {
  OrtSession? _session;
  static const _mean = [0.485, 0.456, 0.406];
  static const _std = [0.229, 0.224, 0.225];

  @override
  Future<void> load() async {
    if (_session != null) return;
    OrtEnv.instance.init();
    final raw = await rootBundle.load('assets/models/recyclenet-small.onnx');
    _session = OrtSession.fromBuffer(
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        OrtSessionOptions());
  }

  @override
  Future<ScanResult> classify(Uint8List imageBytes) async {
    await load();
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw const FormatException('unreadable image');
    final r = img.copyResize(decoded, width: 224, height: 224, interpolation: img.Interpolation.average);
    final data = Float32List(3 * 224 * 224);
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = r.getPixel(x, y);
        final c = [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        for (var k = 0; k < 3; k++) {
          data[k * 224 * 224 + y * 224 + x] = (c[k] - _mean[k]) / _std[k];
        }
      }
    }
    final input = OrtValueTensor.createTensorWithDataList(data, [1, 3, 224, 224]);
    final runOptions = OrtRunOptions();
    final outputs = _session!.run(runOptions, {'image': input});
    final logits = (outputs[0]!.value as List).first as List;
    input.release();
    runOptions.release();
    for (final o in outputs) {
      o?.release();
    }
    return interpretLogits(logits.map((e) => (e as num).toDouble()).toList());
  }
}
