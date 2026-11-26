import 'package:environmental_challenges/services/waste_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('confident glass maps to glass bin', () {
    final r = interpretLogits([0, 4, 0, 0, 0, 0]);
    expect(r.label, 'glass');
    expect(r.bin, 'glass');
    expect(r.probabilities.values.reduce((a, b) => a + b), closeTo(1, 1e-9));
  });
  test('cardboard goes to the paper bin', () {
    expect(interpretLogits([5, 0, 0, 0, 0, 0]).bin, 'paper');
  });
  test('low confidence is unknown', () {
    final r = interpretLogits([1, 0.9, 1, 0.8, 0.7, 0]);
    expect(r.isUnknown, true);
    expect(r.bin, isNull);
  });
  test('trash class has no bin', () {
    final r = interpretLogits([0, 0, 0, 0, 0, 6]);
    expect(r.label, 'trash');
    expect(r.bin, isNull);
  });
}
