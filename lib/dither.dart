import 'dart:math' as math;
import 'dart:typed_data';

/// Atkinson dithering: RGBA in, ink-or-clear RGBA out. Light areas become
/// transparent (paper), so a dithered picture prints as pure ink dots.
/// [tone] shifts brightness, -1 (darker) to 1 (lighter).
Uint8List atkinson(Uint8List rgba, int w, int h, {double tone = 0, int ink = 0xFF141413}) {
  final lum = Float32List(w * h);
  final alpha = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    final a = rgba[i * 4 + 3] / 255;
    // Composite on white paper, then Rec. 709 luminance.
    double ch(int o) => rgba[i * 4 + o] / 255 * a + (1 - a);
    lum[i] = (.2126 * ch(0) + .7152 * ch(1) + .0722 * ch(2) + tone * .5).clamp(0, 1);
    alpha[i] = rgba[i * 4 + 3];
  }
  final out = Uint8List(w * h * 4);
  final r = ink >> 16 & 255, g = ink >> 8 & 255, b = ink & 255;
  void spread(int x, int y, double e) {
    if (x < 0 || x >= w || y >= h) return;
    lum[y * w + x] += e;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x, old = lum[i];
      final dark = old < .5 && alpha[i] > 8;
      final err = (old - (dark ? 0 : 1)) / 8;
      if (dark) {
        out[i * 4] = r;
        out[i * 4 + 1] = g;
        out[i * 4 + 2] = b;
        out[i * 4 + 3] = 255;
      }
      spread(x + 1, y, err);
      spread(x + 2, y, err);
      spread(x - 1, y + 1, err);
      spread(x, y + 1, err);
      spread(x + 1, y + 1, err);
      spread(x, y + 2, err);
    }
  }
  return out;
}

/// Dither resolution for a sticker [wMm] wide at [dotsPerMm], capped so huge
/// stickers stay quick.
(int, int) ditherSize(double wMm, double aspect, double dotsPerMm) {
  final w = math.max(8, math.min(900, (wMm * dotsPerMm).round()));
  return (w, math.max(8, (w / aspect).round()));
}
