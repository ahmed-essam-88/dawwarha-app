import 'dart:typed_data';

/// Isolated spike: SigLIP image preprocessing (RGB, bicubic resize to size x size, x/255, (x-0.5)/0.5, NCHW float32).
/// The bicubic resize follows Pillow's Resample.c (a = -0.5, support scaled when downsampling, 22-bit fixed point,
/// uint8 rounding after the horizontal pass and again after the vertical pass), because the Python reference
/// that produced the evaluation numbers used PIL.Image.BICUBIC.
class Coeffs {
  final List<int> start; final List<int> count; final List<Int32List> k;
  Coeffs(this.start, this.count, this.k);
}

double _cubic(double x) {
  const a = -0.5;
  x = x.abs();
  if (x < 1.0) return ((a + 2.0) * x - (a + 3.0)) * x * x + 1;
  if (x < 2.0) return (((x - 5) * x + 8) * x - 4) * a;
  return 0.0;
}

Coeffs _coeffs(int inSize, int outSize) {
  final scale = inSize / outSize;
  final fs = scale < 1.0 ? 1.0 : scale;
  final support = 2.0 * fs;
  final start = <int>[], count = <int>[], ks = <Int32List>[];
  for (var xx = 0; xx < outSize; xx++) {
    final center = (xx + 0.5) * scale;
    var xmin = (center - support + 0.5).toInt();
    if (xmin < 0) xmin = 0;
    var xmax = (center + support + 0.5).toInt();
    if (xmax > inSize) xmax = inSize;
    xmax -= xmin;
    final w = List<double>.filled(xmax, 0);
    var sum = 0.0;
    for (var x = 0; x < xmax; x++) {
      final v = _cubic((x + xmin - center + 0.5) / fs);
      w[x] = v; sum += v;
    }
    final k = Int32List(xmax);
    for (var x = 0; x < xmax; x++) {
      final v = sum != 0 ? w[x] / sum : w[x];
      k[x] = (v * (1 << 22) + (v < 0 ? -0.5 : 0.5)).toInt();
    }
    start.add(xmin); count.add(xmax); ks.add(k);
  }
  return Coeffs(start, count, ks);
}

final Float32List _f = Float32List(1);
/// float32 arithmetic step by step, like numpy float32: v/255, then -0.5, then /0.5. Doing it in double differs
/// in the last bit and the int8 model amplifies that (measured: cos 0.987, 4/24 class flips).
double _r(double x) { _f[0] = x; return _f[0]; }
double _norm(int v) => _r(_r(_r(v.toDouble()) / 255.0) - 0.5) / 0.5;

int _clip(int v) { final r = v >> 22; return r < 0 ? 0 : (r > 255 ? 255 : r); }

/// rgb: interleaved RGB bytes, width*height*3.
Float32List siglipPreprocess(Uint8List rgb, int w, int h, {int size = 224}) {
  final ch = _coeffs(w, size), cv = _coeffs(h, size);
  // horizontal pass: h rows x size cols
  final tmp = Uint8List(h * size * 3);
  for (var y = 0; y < h; y++) {
    for (var xx = 0; xx < size; xx++) {
      final k = ch.k[xx], s = ch.start[xx];
      for (var c = 0; c < 3; c++) {
        var ss = 1 << 21;
        for (var x = 0; x < ch.count[xx]; x++) { ss += rgb[(y * w + s + x) * 3 + c] * k[x]; }
        tmp[(y * size + xx) * 3 + c] = _clip(ss);
      }
    }
  }
  final out = Float32List(3 * size * size);
  for (var yy = 0; yy < size; yy++) {
    final k = cv.k[yy], s = cv.start[yy];
    for (var xx = 0; xx < size; xx++) {
      for (var c = 0; c < 3; c++) {
        var ss = 1 << 21;
        for (var y = 0; y < cv.count[yy]; y++) { ss += tmp[((s + y) * size + xx) * 3 + c] * k[y]; }
        final v = _clip(ss);
        out[c * size * size + yy * size + xx] = _norm(v);
      }
    }
  }
  return out;
}
