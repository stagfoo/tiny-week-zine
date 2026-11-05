import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'model.dart';

/// Fonts offered first: handwriting, display, mono and cute, all Google Fonts.
const zineFonts = [
  'Caveat', 'Patrick Hand', 'Gaegu', 'Kalam', 'Indie Flower', 'Permanent Marker', 'Archivo Black', 'Bebas Neue',
  'DM Serif Display', 'Fraunces', 'Space Mono', 'IBM Plex Mono', 'Pacifico', 'Silkscreen', 'Mochiy Pop One', 'Yomogi',
];

/// Ink colours for text and shapes.
const inkColors = [0xFF141413, 0xFF24305E, 0xFF1E8A4C, 0xFFD9483B, 0xFF7A5230, 0xFF8B83A6];

/// Shapes: kind, name, starting width (mm) and width/height.
const shapeKinds = [
  ('box', 'Box', 30.0, 1.4), ('round', 'Rounded', 30.0, 1.4), ('circle', 'Circle', 20.0, 1.0),
  ('line', 'Line', 40.0, 12.0), ('dashed', 'Dashed', 40.0, 12.0), ('arrow', 'Arrow', 30.0, 6.0),
];

/// Lines and arrows have no height to stretch.
bool isLineShape(String kind) => kind == 'line' || kind == 'dashed' || kind == 'arrow';

/// Off in tests, which have no network: text falls back to Archivo.
bool useGoogleFonts = true;

TextStyle textStyle(String? font, double size, Color color) {
  const base = TextStyle(fontFamily: 'Archivo', height: 1.15);
  if (useGoogleFonts && font != null) {
    try {
      return GoogleFonts.getFont(font, fontSize: size, color: color, height: 1.15);
    } catch (_) {}
  }
  return base.copyWith(fontSize: size, color: color);
}

/// Waits for these fonts to arrive (or fail), so text measures and prints right.
Future<void> loadFonts(Iterable<String?> fonts) async {
  if (!useGoogleFonts) return;
  try {
    await GoogleFonts.pendingFonts([for (final f in fonts.toSet()) if (f != null) textStyle(f, 10, Colors.black)]);
  } catch (_) {
    // Offline or blocked: the text still draws, in the fallback face.
  }
}

TextPainter _layout(Sticker k, double size) => TextPainter(
      text: TextSpan(text: (k.text ?? '').isEmpty ? ' ' : k.text, style: textStyle(k.font, size, Color(k.color ?? inkColors.first))),
      textDirection: TextDirection.ltr,
    )..layout();

/// Width/height of a text box's words in their font.
double textAspect(Sticker k) {
  final p = _layout(k, 10);
  return p.width / p.height;
}

/// Font size in mm that makes the words fill the box's width.
double textSize(Sticker k) => 10 * k.w / _layout(k, 10).width;

/// Changes a text box's words or font while keeping its letters the same size.
void retext(Sticker k, {String? text, String? font}) {
  final size = textSize(k);
  if (text != null) k.text = text;
  if (font != null) k.font = font;
  k.a = textAspect(k);
  k.w = size * _layout(k, 10).width / 10;
}

/// Draws a text box or shape centred on the origin, at [s] px per mm.
void drawObject(Canvas c, Sticker k, double s) {
  final w = k.w * s, h = k.w / k.a * s;
  final color = Color(k.color ?? inkColors.first);
  if (k.isText) {
    final p = _layout(k, 10 * w / _layout(k, 10).width);
    p.paint(c, Offset(-p.width / 2, -p.height / 2));
    return;
  }
  final pen = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = (k.weight ?? .5) * s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final half = pen.strokeWidth / 2;
  final box = Rect.fromCenter(center: Offset.zero, width: math.max(1, w - pen.strokeWidth), height: math.max(1, h - pen.strokeWidth));
  switch (k.shape) {
    case 'box':
      c.drawRect(box, pen);
    case 'round':
      c.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(math.min(box.width, box.height) * .22)), pen);
    case 'circle':
      c.drawOval(box, pen);
    case 'line':
      c.drawLine(Offset(-w / 2 + half, 0), Offset(w / 2 - half, 0), pen);
    case 'dashed':
      final dash = 2.2 * s, gap = 1.6 * s;
      for (var x = -w / 2 + half; x < w / 2 - half; x += dash + gap) {
        c.drawLine(Offset(x, 0), Offset(math.min(x + dash, w / 2 - half), 0), pen);
      }
    case 'arrow':
      final tip = Offset(w / 2 - half, 0), head = math.max(0.0, math.min(h / 2 - half, w * .3));
      c.drawLine(Offset(-w / 2 + half, 0), tip, pen);
      c.drawPath(
          Path()
            ..moveTo(tip.dx - head, -head)
            ..lineTo(tip.dx, 0)
            ..lineTo(tip.dx - head, head),
          pen);
  }
}

/// A text box or shape as a widget, for the editor.
class ObjectPainter extends CustomPainter {
  ObjectPainter(this.k, this.mm);
  final Sticker k;
  final double mm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    drawObject(canvas, k, mm);
  }

  @override
  bool shouldRepaint(ObjectPainter old) => true;
}
