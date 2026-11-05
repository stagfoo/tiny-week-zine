import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/objects.dart';

Sticker textBox(String text) {
  final k = Sticker(id: 't1', src: 't', a: 1, x: 30, y: 30, w: 30, rot: 0, text: text, font: 'Caveat', color: inkColors.first);
  k.a = textAspect(k);
  return k;
}

void main() {
  setUp(() => useGoogleFonts = false);

  test('editing the words keeps the letters the same size', () {
    final k = textBox('Hello');
    final size = textSize(k), h = k.w / k.a;
    retext(k, text: 'Hello there, week');
    expect(textSize(k), closeTo(size, .01));
    expect(k.w / k.a, closeTo(h, .01), reason: 'one line stays one line high');
    retext(k, text: 'Two\nlines');
    expect(textSize(k), closeTo(size, .01));
    expect(k.w / k.a, greaterThan(h * 1.8));
  });

  test('text and shape settings survive saving', () {
    final t = textBox('Hi')..color = inkColors[2];
    final s = Sticker(id: 's1', src: 's:round', a: 2, x: 1, y: 2, w: 30, rot: .3, color: inkColors[3], weight: 1.2);
    for (final k in [t, s]) {
      final back = Sticker.fromJson(k.toJson());
      expect(back.toJson(), k.toJson());
    }
    expect(Sticker.fromJson(Sticker(id: 'p', src: 'b:bunny/01', a: 1, x: 0, y: 0, w: 1, rot: 0).toJson()).text, isNull);
  });

  for (final (kind, _, w, a) in shapeKinds) {
    test('$kind draws inside its box', () async {
      const s = 6.0, pad = 10;
      final k = Sticker(id: kind, src: 's:$kind', a: a, x: 0, y: 0, w: w, rot: 0, weight: 1.5);
      final bw = (w * s).ceil(), bh = (w / a * s).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..drawColor(Colors.white, BlendMode.src);
      c.translate(bw / 2 + pad, bh / 2 + pad);
      drawObject(c, k, s);
      final im = await rec.endRecording().toImage(bw + 2 * pad, bh + 2 * pad);
      final px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var inside = 0, outside = 0;
      for (var y = 0; y < im.height; y++) {
        for (var x = 0; x < im.width; x++) {
          if (px.getUint8((y * im.width + x) * 4) > 200) continue;
          final inBox = x >= pad - 1 && x <= pad + bw && y >= pad - 1 && y <= pad + bh;
          inBox ? inside++ : outside++;
        }
      }
      expect(inside, greaterThan(0), reason: 'draws something');
      expect(outside, 0, reason: 'stays inside its box');
    });
  }
}
