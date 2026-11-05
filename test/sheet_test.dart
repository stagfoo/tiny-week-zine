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
}
