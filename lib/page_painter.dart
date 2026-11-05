import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'images.dart';
import 'model.dart';
import 'objects.dart';

const navy = Color(0xFF24305E), gridc = Color(0xFFC6D0DC), ink = Color(0xFF2A2340), green = Color(0xFF1E8A4C);
const lilac = Color(0xFFB3A5DF), faint = Color(0xFF8B83A6);
const fArch = 'Archivo', fMono = 'PlexMono';
const lh = 3.7;

/// Printers can't reach the paper edge and drift a few mm, so each layout is
/// drawn shrunk toward its spine and the middle fold. That leaves at least
/// 8mm clear on the sheet's outer edges while the panels stay full size.
const printSafe = .93;

/// Odd pages have the spine on the left.
({double l, double r}) margins(int pn) => pn.isOdd ? (l: 6, r: 4) : (l: 4, r: 6);

/// Adds an HTML-canvas-style arc (continuing the current path) to [p].
void arcTo(Path p, double cx, double cy, double r, double a0, double a1, {bool ccw = false}) {
  const tau = math.pi * 2;
  double sweep;
  if (!ccw) {
    sweep = a1 - a0;
    if (sweep >= tau) {
      sweep = tau;
    } else {
      sweep %= tau;
    }
  } else {
    sweep = a0 - a1;
    if (sweep >= tau) {
      sweep = tau;
    } else {
      sweep %= tau;
    }
    sweep = -sweep;
  }
  p.arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), a0, sweep, false);
}

Path dashed(Path src, double on, double off) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += on + off) {
      out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
    }
  }
  return out;
}

/// Outline weather icons in one ink colour. cx, cy, u in pixels.
void drawWeather(Canvas c, String t, double cx, double cy, double u, Color inkc) {
  final stroke = Paint()
    ..color = inkc
    ..style = PaintingStyle.stroke
    ..strokeWidth = u * .042
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final white = Paint()..color = Colors.white;
  void line(double x1, double y1, double x2, double y2) => c.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);
  void cloud(double x, double y, double k) {
    final p = Path()..moveTo(x - .3 * u * k, y + .14 * u * k);
    arcTo(p, x - .17 * u * k, y + .02 * u * k, .13 * u * k, math.pi * .6, math.pi * 1.55);
    arcTo(p, x + .03 * u * k, y - .06 * u * k, .18 * u * k, math.pi * 1.1, math.pi * 1.95);
    arcTo(p, x + .2 * u * k, y + .04 * u * k, .12 * u * k, math.pi * 1.4, math.pi * .45);
    p.close();
    c.drawPath(p, white);
    c.drawPath(p, stroke);
  }

  void sun(double x, double y, double r) {
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      line(x + math.cos(a) * r * 1.55, y + math.sin(a) * r * 1.55, x + math.cos(a) * r * 2, y + math.sin(a) * r * 2);
    }
    c.drawCircle(Offset(x, y), r, white);
    c.drawCircle(Offset(x, y), r, stroke);
  }

  switch (t) {
    case 'sun':
      sun(cx, cy, u * .16);
    case 'partly':
      sun(cx - u * .12, cy - u * .1, u * .12);
      cloud(cx + u * .05, cy + u * .06, .85);
    case 'cloud':
      cloud(cx, cy, 1);
    case 'rain':
      cloud(cx, cy - u * .08, .95);
      for (final x in [-.14, 0.0, .14]) {
        line(cx + (x + .03) * u, cy + .15 * u, cx + (x - .02) * u, cy + .28 * u);
      }
    case 'storm':
      cloud(cx, cy - u * .08, .95);
      c.drawPath(
          Path()
            ..moveTo(cx + .03 * u, cy + .12 * u)
            ..lineTo(cx - .05 * u, cy + .24 * u)
            ..lineTo(cx + .03 * u, cy + .24 * u)
            ..lineTo(cx - .04 * u, cy + .36 * u),
          stroke);
    case 'wind':
      for (final (y, e) in [(-.13, .1), (0.0, .2), (.13, .04)]) {
        final p = Path()
          ..moveTo(cx - .3 * u, cy + y * u)
          ..lineTo(cx + e * u, cy + y * u);
        arcTo(p, cx + e * u, cy + (y - .065) * u, .065 * u, math.pi / 2, -math.pi * .9, ccw: true);
        c.drawPath(p, stroke);
      }
  }
}

/// Small outline shapes for trackers. cx, cy, r in pixels.
void drawShape(Canvas c, String kind, double cx, double cy, double r, Paint p) {
  Path union(List<Rect> ovals) =>
      ovals.skip(1).fold(Path()..addOval(ovals.first), (acc, o) => Path.combine(PathOperation.union, acc, Path()..addOval(o)));
  Rect circ(double x, double y, double rr) => Rect.fromCircle(center: Offset(x, y), radius: rr);
  Path star(int points, double inner) {
    final path = Path();
    for (var k = 0; k < points * 2; k++) {
      final a = -math.pi / 2 + k * math.pi / points, rr = k.isEven ? r : r * inner;
      final o = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr);
      k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  final path = switch (kind) {
    'heart' => Path()
      ..moveTo(cx, cy + r * .9)
      ..cubicTo(cx - r * 1.6, cy - r * .1, cx - r * .9, cy - r * 1.3, cx, cy - r * .45)
      ..cubicTo(cx + r * .9, cy - r * 1.3, cx + r * 1.6, cy - r * .1, cx, cy + r * .9),
    'star' => star(5, .45),
    'sparkle' => star(4, .32),
    'flower' => union([circ(cx, cy, r * .62), for (var k = 0; k < 6; k++) circ(cx + math.cos(k * math.pi / 3) * r * .58, cy + math.sin(k * math.pi / 3) * r * .58, r * .42)]),
    'cloud' => union([circ(cx - r * .5, cy + r * .15, r * .5), circ(cx, cy - r * .2, r * .62), circ(cx + r * .52, cy + r * .15, r * .48)]),
    'arch' => Path()
      ..moveTo(cx - r * .8, cy + r)
      ..lineTo(cx - r * .8, cy)
      ..arcTo(circ(cx, cy, r * .8), math.pi, math.pi, false)
      ..lineTo(cx + r * .8, cy + r)
      ..close(),
    'drop' => Path()
      ..moveTo(cx, cy - r * 1.3)
      ..cubicTo(cx + r * .3, cy - r * .7, cx + r, cy - r * .1, cx + r, cy + r * .35)
      ..arcTo(circ(cx, cy + r * .35, r), 0, math.pi, false)
      ..cubicTo(cx - r, cy - r * .1, cx - r * .3, cy - r * .7, cx, cy - r * 1.3),
    _ => Path()..addOval(circ(cx, cy, r)),
  };
  c.drawPath(path, p);
}

/// A mood face, 0 (great) to 4 (awful). cx, cy, r in pixels.
void drawFace(Canvas c, int mood, double cx, double cy, double r, Paint p) {
  c.drawCircle(Offset(cx, cy), r, p);
  final eye = Paint()..color = p.color;
  for (final dx in [-.35, .35]) {
    c.drawCircle(Offset(cx + dx * r, cy - .18 * r), r * .09, eye);
  }
  final curve = [.35, .2, 0.0, -.2, -.35][mood];
  c.drawPath(
      Path()
        ..moveTo(cx - .38 * r, cy + .32 * r)
        ..quadraticBezierTo(cx, cy + (.32 + curve) * r, cx + .38 * r, cy + .32 * r),
      p);
}

/// Draws page [pn] (1..8) with its top-left at the canvas origin.
/// [s] is px per mm. Every layout is print-and-pen.
void drawPage(Canvas c, int pn, ZPage pg, double s, List<DateTime> ds,
    {bool editor = false, Images? stickers, String? layoutOverride}) {
  final m = margins(pn);
  final x0 = m.l, x1 = pw - m.r;

  TextPainter tp(String txt, double w, double size, String fam, Color col) => TextPainter(
      text: TextSpan(text: txt, style: TextStyle(fontFamily: fam, fontWeight: FontWeight.values[(w ~/ 100) - 1], fontSize: size * s, color: col, height: 1)),
      textDirection: TextDirection.ltr)
    ..layout();
  // Text with its alphabetic baseline at (x, y) mm, like canvas fillText.
  void t(String txt, double x, double y, double w, double size, String fam, Color col, [String al = 'left']) {
    final p = tp(txt, w, size, fam, col);
    final base = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final dx = al == 'right' ? p.width : (al == 'center' ? p.width / 2 : 0.0);
    p.paint(c, Offset(x * s - dx, y * s - base));
  }

  // Text turned to read bottom-to-top; returns its length in mm.
  double vt(String txt, double x, double y, double w, double size, String fam, Color col, [String al = 'left']) {
    final p = tp(txt, w, size, fam, col);
    final base = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    c.save();
    c.translate(x * s, y * s);
    c.rotate(-math.pi / 2);
    final dx = al == 'center' ? p.width / 2 : 0.0;
    p.paint(c, Offset(-dx, -base));
    c.restore();
    return p.width / s;
  }

  Paint stroke(Color col, double lw) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = lw * s;
  void line(double ax, double ay, double bx, double by, Color col, double lw) =>
      c.drawLine(Offset(ax * s, ay * s), Offset(bx * s, by * s), stroke(col, lw));
  void box(double x, double y, double w, double h, Color col, double lw) =>
      c.drawRect(Rect.fromLTWH(x * s, y * s, w * s, h * s), stroke(col, lw));
  void fill(double x, double y, double w, double h, Color col) => c.drawRect(Rect.fromLTWH(x * s, y * s, w * s, h * s), Paint()..color = col);
  void dot(double x, double y, double r, Color col) => c.drawCircle(Offset(x * s, y * s), r * s, Paint()..color = col);
  void grid(double gx0, double gy0, double gx1, double gy1, double step, Color col, double lw) {
    c.save();
    c.clipRect(Rect.fromLTRB(gx0 * s, gy0 * s, gx1 * s, gy1 * s));
    final p = Path();
    for (var x = gx0; x <= gx1 + .05; x += step) {
      p
        ..moveTo(x * s, gy0 * s)
        ..lineTo(x * s, gy1 * s);
    }
    for (var y = gy0; y <= gy1 + .05; y += step) {
      p
        ..moveTo(gx0 * s, y * s)
        ..lineTo(gx1 * s, y * s);
    }
    c.drawPath(p, stroke(col, lw));
    c.restore();
  }

  void stipple(double x, double y, double w, double h) {
    var sd = 9;
    double r() => (sd = (sd * 16807) % 2147483647) / 2147483647;
    final paint = Paint()..color = ink;
    for (var k = 0, n = (w * h * 1.15).round(); k < n; k++) {
      final px = x + .7 + r() * (w - 1.4);
      final py = y + .7 + r() * (h - 1.4);
      c.drawCircle(Offset(px * s, py * s), .21 * s, paint);
    }
  }

  ({double cell, List<Rect> b}) modular(List<List<int>> blocks) {
    final cell = (x1 - x0) / 8;
    const y0 = 5.0;
    grid(x0, y0, x1, y0 + 12 * cell, cell, ink, .2);
    return (
      cell: cell,
      b: [
        for (final q in blocks)
          () {
            final r = Rect.fromLTWH(x0 + q[0] * cell, y0 + q[1] * cell, q[2] * cell, q[3] * cell);
            fill(r.left, r.top, r.width, r.height, Colors.white);
            box(r.left, r.top, r.width, r.height, ink, .2);
            return r;
          }()
      ]
    );
  }

  c.save();
  c.clipRect(Rect.fromLTWH(0, 0, pw * s, ph * s));
  c.drawRect(Rect.fromLTWH(0, 0, pw * s, ph * s), Paint()..color = Colors.white);
  final lay = layoutOverride ?? pg.layout ?? (pn == 1 ? 'blank' : 'daily');
  final i = pn - 2;
  final d = i >= 0 ? ds[i] : ds[0];
  final spineX = (pn.isOdd ? m.l : pw - m.r) * s;
  c.save();
  c.translate(spineX, 0);
  c.scale(printSafe);
  c.translate(-spineX, 0);

  switch (lay) {
    case 'blank':
      final a = ds[0], b = ds[6];
      t('W${isoWeek(a)} · ${fmtD(a)} – ${fmtD(b)}', x1, 103.4, 500, 2, fMono, faint, 'right');
      if (editor && pg.stickers.isEmpty) t('blank cover · add stickers', (x0 + x1) / 2, ph / 2, 500, 2.4, fMono, lilac, 'center');
    case 'thisweek':
      final a = ds[0], b = ds[6];
      final mo = modular([
        [0, 1, 2, 2],
        [2, 1, 6, 2],
        [4, 3, 4, 1],
        [1, 4, 7, 7]
      ]);
      final [wk, tt, sp, ls] = mo.b;
      t('WEEK', wk.left + 1.5, wk.top + 3.4, 500, 1.7, fMono, ink);
      t('${isoWeek(a)}', wk.left + 1.3, wk.bottom - 2.2, 500, 8, fArch, ink);
      t('THIS WEEK', tt.left + 2, tt.top + 9.4, 500, 7.4, fArch, ink);
      t('${fmtD(a)} – ${fmtD(b)} ${b.year}', tt.left + 2.2, tt.top + 13.6, 500, 1.8, fMono, ink);
      stipple(sp.left, sp.top, sp.width, sp.height);
      for (var k = 0; k < 7; k++) {
        final dk = ds[k], y = ls.top + k * mo.cell;
        t('${days[k]} ${pad(dk.day)}.${pad(dk.month)}', ls.left + 2, y + 3.6, 500, 2.2, fArch, ink);
        line(ls.left + 17, y + mo.cell - 2, ls.right - 2, y + mo.cell - 2, lilac, .15);
      }
    case 'daily':
      t(days[i], x0, 11.6, 500, 6.4, fArch, navy);
      t(fmtD(d), x1, 11.6, 400, 2.5, fArch, navy, 'right');
      line(x0, 14.6, x1, 14.6, navy, .3);
      const wx = ['sun', 'partly', 'cloud', 'rain', 'storm', 'wind'];
      for (var k = 0; k < wx.length; k++) {
        drawWeather(c, wx[k], (x0 + 2.6 + k * 6.6) * s, 20.2 * s, 6.4 * s, navy);
      }
      line(x1 - 14, 22.4, x1 - 2.4, 22.4, navy, .15);
      t('°', x1, 21.6, 400, 2.8, fArch, navy, 'right');
      line(x0, 25.6, x1, 25.6, navy, .15);
      t('to do', x0, 30.4, 400, 2.4, fArch, navy);
      for (var k = 0; k < 4; k++) {
        final y = 33 + k * 5.2;
        box(x0, y, 2.8, 2.8, navy, .2);
        line(x0 + 5, y + 2.8, x1, y + 2.8, gridc, .15);
      }
      line(x0, 55.4, x1, 55.4, navy, .15);
      t('notes', x0, 60.2, 400, 2.4, fArch, navy);
      for (var y = 63.0; y <= 101; y += 3.7) {
        for (var x = x0; x <= x1 + .01; x += 3.7) {
          dot(x, y, .16, navy);
        }
      }
    case 'gridnote':
      t('date', x0 + .6, 9.4, 400, 3, fArch, navy);
      t('${pad(d.day)}  /  ${pad(d.month)}', x0 + 10.5, 9.4, 400, 3, fArch, navy);
      const letters = 'mtwtfss';
      for (var k = 0; k < 7; k++) {
        final x = x0 + 1.8 + k * 3.9;
        t(letters[k], x, 14, 400, 2.6, fArch, navy, 'center');
        if (k == i) c.drawCircle(Offset(x * s, 13.15 * s), 1.75 * s, stroke(navy, .2));
      }
      grid(x0, 22, x1, 100.8, 3.7, gridc, .12);
      box(x0, 16, x1 - x0, 84.8, navy, .3);
      line(x0, 22, x1, 22, navy, .3);
      t('title', x0 + 1.8, 20, 400, 2.9, fArch, navy);
    case 'drafting':
      final step = (x1 - x0) / 13, y0 = 8.0, y1 = 101.0, bw = 2 * step;
      t('WEEK ${isoWeek(ds[0])}', x0, 6.3, 500, 1.9, fMono, navy);
      t('${days[i]} ${fmtD(d)}', x1, 6.3, 500, 1.9, fMono, navy, 'right');
      grid(x0, y0, x1, y1, step, const Color(0xFF7E86AB), .1);
      final ya = y0 + 3 * step, yb = y0 + 9 * step, yc = y0 + 12 * step;
      fill(x0, y0, bw, yc - y0, Colors.white);
      line(x0, ya, x0 + bw, ya, navy, .4);
      line(x0, yb, x0 + bw, yb, navy, .4);
      line(x0 + step, ya, x0 + step, yb, navy, .4);
      box(x0, y0, bw, yc - y0, navy, .4);
      void blank(double x, double yBot, double yTop, String txt) {
        final w = vt(txt, x, yBot - 1.2, 600, 1.9, fArch, navy);
        line(x + .5, yBot - 1.2 - w - .8, x + .5, yTop + 1.2, navy, .15);
      }
      vt('RATING', x0 + step - 1.2, ya - 1.2, 600, 1.9, fArch, navy);
      line(x0 + 2 * step - 1, ya - 1.2, x0 + 2 * step - 1, y0 + 1.2, navy, .15);
      blank(x0 + step - 1.4, yb, ya, 'TITLE');
      blank(x0 + 2 * step - 1.4, yb, ya, 'MOOD');
      final wd = vt('DAY', x0 + step - 1.2, yc - 1.2, 600, 1.9, fArch, navy);
      final cy = yc - 1.2 - wd - 3;
      c.drawCircle(Offset((x0 + step * .55) * s, cy * s), 1.9 * s, stroke(navy, .3));
      vt('${d.day}', x0 + step * .55 + .75, cy, 600, 2, fArch, navy, 'center');
      vt('MONTH  ${mons[d.month - 1]}', x0 + 2 * step - 1.2, yc - 1.2, 600, 1.9, fArch, navy);
      box(x0, y0, x1 - x0, y1 - y0, navy, .55);
    case 'modular':
      final mo = modular([
        [0, 1, 6, 2],
        [6, 1, 2, 2],
        [0, 4, 3, 3],
        [0, 7, 3, 2],
        [3, 4, 5, 6]
      ]);
      final [hd, dt, nt, sp, sc] = mo.b;
      t(days[i], hd.left + 2, hd.top + 12.4, 500, 11, fArch, ink);
      t('${d.day}', dt.center.dx, dt.top + 9.4, 500, 7, fArch, ink, 'center');
      t(mons[d.month - 1], dt.center.dx, dt.top + 13.4, 500, 1.8, fMono, ink, 'center');
      t('NOTE', nt.left + 1.5, nt.top + 3.2, 500, 1.7, fMono, ink);
      stipple(sp.left, sp.top, sp.width, sp.height);
      final rowH = (sc.height - 3) / 7;
      const hours = ['08', '10', '12', '14', '16', '18', '20'];
      for (var k = 0; k < 7; k++) {
        final y = sc.top + 1.5 + k * rowH;
        t(hours[k], sc.left + 2, y + 4.3, 500, 2, fMono, ink);
        line(sc.left + 7.5, y + 4.8, sc.right - 2, y + 4.8, lilac, .15);
      }
    case 'weekly':
      final a = ds[0], b = ds[6];
      t('WEEKLY', x0, 11.6, 600, 6, fArch, navy);
      t('W${isoWeek(a)} · ${fmtD(a)} – ${fmtD(b)}', x1, 11.6, 500, 1.8, fMono, navy, 'right');
      const gap = 2.4, top = 16.0;
      final bw = (x1 - x0 - gap) / 2, bh = (101 - top - 3 * gap) / 4;
      for (var k = 0; k < 8; k++) {
        final x = x0 + (k % 2) * (bw + gap), y = top + (k ~/ 2) * (bh + gap);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x * s, y * s, bw * s, bh * s), Radius.circular(2.4 * s)), stroke(navy, .3));
        t(k < 7 ? days[k].substring(0, 1) + days[k].substring(1).toLowerCase() : 'memo', x + 2, y + 4, 400, 2.4, fArch, navy);
        if (k < 7) t('${ds[k].day}', x + bw - 2, y + 4, 500, 1.8, fMono, faint, 'right');
      }
    case 'habits':
      t('HABITS', x0, 11.6, 600, 6, fArch, navy);
      t('W${isoWeek(ds[0])}', x1, 11.6, 500, 1.9, fMono, navy, 'right');
      line(x0, 14.6, x1, 14.6, navy, .3);
      const shapes = ['circle', 'heart', 'star', 'flower', 'arch', 'sparkle', 'cloud', 'drop'];
      final col0 = x0 + 25.0, colW = (x1 - col0) / 7;
      for (var k = 0; k < 7; k++) {
        t('mtwtfss'[k], col0 + (k + .5) * colW, 20, 500, 2.4, fArch, navy, 'center');
      }
      for (var row = 0; row < 8; row++) {
        final y = 25.0 + row * 8.2;
        line(x0, y + 3, col0 - 2.5, y + 3, gridc, .15);
        for (var k = 0; k < 7; k++) {
          drawShape(c, shapes[row], (col0 + (k + .5) * colW) * s, (y + 1.6) * s, 1.45 * s, stroke(navy, .2));
        }
      }
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 * s, 92.4 * s, 11 * s, 4.6 * s), Radius.circular(2.3 * s)), Paint()..color = navy);
      t('goal', x0 + 5.5, 95.6, 600, 2.3, fArch, Colors.white, 'center');
      line(x0 + 13, 96.6, x1, 96.6, gridc, .15);
    case 'routine':
      t(days[i], x0, 11.6, 500, 6.4, fArch, navy);
      t(fmtD(d), x1, 11.6, 400, 2.5, fArch, navy, 'right');
      line(x0, 14.6, x1, 14.6, navy, .3);
      const parts = ['morning', 'afternoon', 'evening'];
      for (var k = 0; k < 3; k++) {
        final top = 18.5 + k * 23;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 * s, top * s, 5 * s, 20 * s), Radius.circular(2.5 * s)), stroke(navy, .25));
        vt(parts[k], x0 + 3.3, top + 10, 400, 2.2, fArch, navy, 'center');
        for (var r = 0; r < 3; r++) {
          final y = top + 4.5 + r * 6.2;
          c.drawCircle(Offset((x0 + 8.6) * s, y * s), .9 * s, stroke(navy, .2));
          line(x0 + 11, y + .9, x1, y + .9, gridc, .15);
        }
      }
      t('water', x0, 94.2, 400, 2.4, fArch, navy);
      for (var k = 0; k < 8; k++) {
        drawShape(c, 'drop', (x0 + 13 + k * 6.6) * s, (93 * s), 1.35 * s, stroke(navy, .2));
      }
    case 'checklist':
      t(days[i], x0, 11.6, 500, 6.4, fArch, navy);
      t(fmtD(d), x1, 11.6, 400, 2.5, fArch, navy, 'right');
      line(x0, 14.6, x1, 14.6, navy, .3);
      t('check list', x0, 20.4, 400, 2.4, fArch, navy);
      for (var k = 0; k < 11; k++) {
        final y = 23 + k * 5.6;
        box(x0, y, 2.6, 2.6, navy, .2);
        line(x0 + 4.6, y + 2.6, x1, y + 2.6, gridc, .15);
      }
      line(x0, 87.4, x1, 87.4, navy, .15);
      t('mood', x0, 93.2, 400, 2.4, fArch, navy);
      for (var k = 0; k < 5; k++) {
        drawFace(c, k, (x0 + 17 + k * 10.6) * s, 92.4 * s, 2.3 * s, stroke(navy, .2)..strokeCap = StrokeCap.round);
      }
  }

  if (pn != 1) t('$pn', pn.isOdd ? x1 : x0, 103.6, 500, 1.9, fMono, faint, pn.isOdd ? 'right' : 'left');
  c.restore();

  if (pn == 1) {
    // Staple marks on the cover, by the spine. Not shrunk: they belong to the spine.
    for (final y in [24.0, 81.0]) {
      const x = 2.6, w = .9, h = 6.4;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x * s, (y - h / 2) * s, w * s, h * s), Radius.circular(.45 * s));
      c.drawPath(dashed(Path()..addRRect(r), .6 * s, .5 * s), stroke(lilac, .25));
    }
  }

  if (stickers != null) {
    for (final k in pg.stickers) {
      if (k.isText || k.isShape) {
        c.save();
        c.translate(k.x * s, k.y * s);
        c.rotate(k.rot);
        drawObject(c, k, s);
        c.restore();
        continue;
      }
      final im = stickers.get(k.src);
      if (im == null) continue;
      final h = k.w / k.a;
      c.save();
      c.translate(k.x * s, k.y * s);
      c.rotate(k.rot);
      c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
          Rect.fromLTWH(-k.w / 2 * s, -h / 2 * s, k.w * s, h * s), Paint()..filterQuality = FilterQuality.high);
      c.restore();
    }
  }
  c.restore();
}

/// One page as a widget-sized painting (editor background and layout thumbnails).
class PagePainter extends CustomPainter {
  PagePainter({required this.pn, required this.page, required this.dates, this.editor = false, this.layoutOverride, required this.stamp});
  final int pn;
  final ZPage page;
  final List<DateTime> dates;
  final bool editor;
  final String? layoutOverride;

  /// Anything that should trigger a repaint, folded into one value.
  final Object stamp;

  @override
  void paint(Canvas canvas, Size size) =>
      drawPage(canvas, pn, page, size.width / pw, dates, editor: editor, layoutOverride: layoutOverride);

  @override
  bool shouldRepaint(PagePainter old) => old.stamp != stamp || old.pn != pn || old.layoutOverride != layoutOverride;
}

/// How far the trim line sits inside a printer's dead zone, so it still prints.
const trimSafety = 4.0;

/// Ends that lose less than this are already covered by the pages' own
/// margins (8mm+, less a little printer drift), so they get no strip.
const stripMin = 6.0;

/// Width of the strip to trim off an end that loses [dead] mm.
double stripFor(double dead) => dead > stripMin ? dead + trimSafety : 0;

/// Zine length along the sheet once any trim strips are cut off.
double zineLength(double deadTop, double deadBottom) => 297 - stripFor(deadTop) - stripFor(deadBottom);

/// Lays the eight pages out on a landscape A4 sheet at [s] px/mm, with fold
/// ticks and the cut line. Classic one-cut mini zine; top row upside down.
///
/// The sheet's left end (Friday) becomes the top of the portrait PDF page and
/// its right end (cover/Monday) the bottom. [deadTop] and [deadBottom] are how
/// much of those ends the printer can't reach. An end that loses too much gets
/// a strip marked by a TRIM line, cut off before folding, and the zine is laid
/// out evenly on what's left, so all eight panels stay the same size.
Future<ui.Image> renderSheet(List<ZPage> week, List<DateTime> ds, Images images, double s,
    {double deadTop = 0, double deadBottom = 0}) async {
  const top = [5, 4, 3, 2], bot = [6, 7, 8, 1];
  final a = stripFor(deadTop), len = zineLength(deadTop, deadBottom), q = len / 297, p = pw * q;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, 297 * s, 210 * s), Paint()..color = Colors.white);
  c.save();
  c.translate(a * s, 0);
  for (var col = 0; col < 4; col++) {
    // Each page keeps its design and shrinks evenly into a narrower panel,
    // hanging from the middle fold.
    c.save();
    c.translate((col + 1) * p * s, ph * s);
    c.rotate(math.pi);
    c.scale(q);
    drawPage(c, top[col], week[top[col] - 1], s, ds, stickers: images);
    c.restore();
    c.save();
    c.translate(col * p * s, ph * s);
    c.scale(q);
    drawPage(c, bot[col], week[bot[col] - 1], s, ds, stickers: images);
    c.restore();
  }
  Paint st(Color col) => Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = .3 * s;
  void ln(double ax, double ay, double bx, double by, Paint pt) => c.drawLine(Offset(ax * s, ay * s), Offset(bx * s, by * s), pt);
  TextPainter label(String txt) => TextPainter(
      text: TextSpan(text: txt, style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w600, fontSize: 1.8 * s, color: green, height: 1)),
      textDirection: TextDirection.ltr)
    ..layout();
  for (final x in [p, p * 2, p * 3]) {
    ln(x, 7, x, 10, st(lilac));
    ln(x, 200, x, 203, st(lilac));
  }
  ln(7, ph, 10, ph, st(lilac));
  ln(len - 10, ph, len - 7, ph, st(lilac));
  c.drawPath(dashed(Path()..moveTo(p * s, ph * s)..lineTo(p * 3 * s, ph * s), 2 * s, 1.4 * s), st(green)..strokeWidth = .35 * s);
  final cut = label('CUT');
  cut.paint(c, Offset(p * 2 * s - cut.width / 2, (ph + 2.6) * s - cut.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  // TRIM lines, labelled on the strip side.
  final trim = label('TRIM THIS STRIP OFF FIRST');
  for (final (x, side) in [if (a > 0) (0.0, -1.0), if (stripFor(deadBottom) > 0) (len, 1.0)]) {
    c.drawPath(dashed(Path()..moveTo(x * s, 7 * s)..lineTo(x * s, 203 * s), 2 * s, 1.4 * s), st(green)..strokeWidth = .35 * s);
    for (final y in [ph / 2, ph * 1.5]) {
      c.save();
      c.translate((x + side * 1.2) * s, y * s);
      c.rotate(side * math.pi / 2);
      trim.paint(c, Offset(-trim.width / 2, -trim.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
      c.restore();
    }
  }
  c.restore();
  return rec.endRecording().toImage((297 * s).round(), (210 * s).round());
}
