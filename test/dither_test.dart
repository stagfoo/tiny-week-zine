import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_week_zine/dither.dart';

Uint8List flat(int w, int h, int grey, [int alpha = 255]) =>
    Uint8List.fromList([for (var i = 0; i < w * h; i++) ...[grey, grey, grey, alpha]]);

double inked(Uint8List out) {
  var n = 0;
  for (var i = 3; i < out.length; i += 4) {
    if (out[i] == 255) n++;
  }
  return n / (out.length / 4);
}

void main() {
  test('white is paper, black is ink, nothing in between', () {
    expect(inked(atkinson(flat(40, 30, 255), 40, 30)), 0);
    expect(inked(atkinson(flat(40, 30, 0), 40, 30)), 1);
    final out = atkinson(flat(40, 30, 128), 40, 30);
    for (var i = 3; i < out.length; i += 4) {
      expect(out[i], anyOf(0, 255));
    }
  });

  test('mid grey comes out as roughly half dots, and tone shifts it', () {
    final mid = inked(atkinson(flat(80, 80, 128), 80, 80));
    expect(mid, closeTo(.5, .12));
    expect(inked(atkinson(flat(80, 80, 128), 80, 80, tone: .6)), lessThan(mid - .1));
    expect(inked(atkinson(flat(80, 80, 128), 80, 80, tone: -.6)), greaterThan(mid + .1));
  });

  test('transparent areas stay clear', () {
    expect(inked(atkinson(flat(20, 20, 0, 0), 20, 20)), 0);
  });

  test('dot grid follows the printed size and keeps the aspect', () {
    expect(ditherSize(40, 2, 4), (160, 80));
    expect(ditherSize(400, 1, 8).$1, 900, reason: 'capped');
  });
}
