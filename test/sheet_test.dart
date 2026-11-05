import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_week_zine/images.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/page_painter.dart';

// The test font draws every glyph as a full em square, which overflows
// layouts that fit with the real fonts, so load the bundled ones.
Future<void> loadFonts() async {
  const fams = {
    'Archivo': ['Archivo-400', 'Archivo-500', 'Archivo-600'],
    'PlexMono': ['IBMPlexMono-Regular', 'IBMPlexMono-Medium', 'IBMPlexMono-SemiBold'],
  };
  for (final e in fams.entries) {
    final l = FontLoader(e.key);
    for (final f in e.value) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f.ttf').readAsBytesSync())));
    }
    await l.load();
  }
}

void main() {
  setUpAll(loadFonts);

  // Printers can't reach the paper edge and drift a few mm; a scanned test
  // print lost Friday's header this way. Every layout must leave the outer
  // band of the sheet blank.
  test('nothing but paper within 6.5mm of the sheet edge, in every layout', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ZineStore.open();
    store.setWeek(DateTime(2026, 11, 2));
    const s = 4.0; // px per mm
    for (final cover in coverLayouts) {
      for (final day in dayLayouts) {
        final w = store.week;
        w[0].layout = cover.$1;
        for (final p in w.skip(1)) {
          p.layout = day.$1;
        }
        final im = await renderSheet(w, store.dates, Images(store), s);
        final px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final band = (6.5 * s).floor();
        final ink = <String>[];
        for (var y = 0; y < im.height; y++) {
          for (var x = 0; x < im.width; x++) {
            if (x >= band && x < im.width - band && y >= band && y < im.height - band) continue;
            final o = (y * im.width + x) * 4;
            if (px.getUint8(o) < 250 || px.getUint8(o + 1) < 250 || px.getUint8(o + 2) < 250) {
              ink.add('(${(x / s).toStringAsFixed(1)}, ${(y / s).toStringAsFixed(1)})mm');
            }
          }
        }
        expect(ink, isEmpty, reason: '${cover.$1} + ${day.$1}: ink at ${ink.take(5).join(' ')}');
      }
    }
  });

  // A DeskJet 2800 loses 12.7mm at one end: the top with HP's driver, the
  // bottom without it. That end gets a strip with a printable TRIM line, the
  // zine shrinks onto the rest, and nothing lands where the printer can't reach.
  for (final (topDead, bottomDead) in [(0.0, 12.7), (12.7, 0.0), (12.7, 12.7)]) {
    test('dead zone top $topDead / bottom $bottomDead gets TRIM lines and nothing past them', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ZineStore.open();
      store.setWeek(DateTime(2026, 11, 2));
      const s = 4.0;
      final a = stripFor(topDead), len = zineLength(topDead, bottomDead), b = a + len;
      final im = await renderSheet(store.week, store.dates, Images(store), s, deadTop: topDead, deadBottom: bottomDead);
      final px = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      bool inked(double xmm, double ymm) {
        final o = ((ymm * s).floor() * im.width + (xmm * s).floor()) * 4;
        return px.getUint8(o) < 250 || px.getUint8(o + 1) < 250 || px.getUint8(o + 2) < 250;
      }

      final bad = <String>[];
      for (var y = 0.0; y < 210; y += .25) {
        for (var x = 0.0; x < 297; x += .25) {
          final dead = x < topDead || x >= 297 - bottomDead || x < 6.5 || x >= 290.5;
          final nearTrim = (a > 0 && x > a + .5 && x < a + 6.5) || (b < 297 && x > b - 6.5 && x < b - .5);
          final edge = (y < 6.5 || y > 203.5) && x > a + .5 && x < b - .5;
          if ((dead || nearTrim || edge) && inked(x, y)) bad.add('($x, $y)');
        }
      }
      expect(bad, isEmpty, reason: 'ink at ${bad.take(5).join(' ')}');
      for (final x in [if (a > 0) a, if (b < 297) b]) {
        var dashes = 0;
        for (var y = 7.0; y < 203; y += .25) {
          if (inked(x, y)) dashes++;
        }
        expect(dashes, greaterThan(300), reason: 'the TRIM line at ${x}mm should print');
      }
    });
  }

  test('ends that lose little need no strip', () {
    expect(stripFor(2.96), 0);
    expect(zineLength(2.96, 2.96), 297);
    expect(zineLength(0, 12.7), closeTo(297 - 16.7, 1e-9));
  });
}
