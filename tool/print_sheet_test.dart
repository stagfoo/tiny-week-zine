// Makes the print-sheet PDF from the zine saved by the desktop app, without
// building the app. For tuning print layout against a real printer:
//
//   flutter test tool/print_sheet_test.dart [--dart-define=DEAD=12.7]
//   lp -d <printer> -o print-scaling=none dist/print-test.pdf
//
// Writes dist/print-test.pdf. DEAD overrides the saved printer dead zone.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_week_zine/images.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/page_painter.dart';
import 'package:tiny_week_zine/sheet.dart';

import '../test/sheet_test.dart' show loadFonts;

void main() {
  test('print sheet PDF', () async {
    await loadFonts();
    final saved = File('${Platform.environment['HOME']}/.local/share/com.stagfoo.tiny_week_zine/shared_preferences.json');
    final prefs = saved.existsSync() ? jsonDecode(saved.readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
    SharedPreferences.setMockInitialValues({
      for (final e in prefs.entries) e.key.replaceFirst('flutter.', ''): e.value,
    });
    final store = await ZineStore.open();
    const dead = String.fromEnvironment('DEAD');
    if (dead.isNotEmpty) store.deadZone = double.parse(dead);
    final images = Images(store);
    for (final p in store.week) {
      for (final k in p.stickers) {
        await images.load(k.src);
      }
    }
    final im = await renderSheet(store.week, store.dates, images, 7, deadZone: store.deadZone);
    final pdf = await sheetPdf(im, 'print test');
    File('dist/print-test.pdf')
      ..createSync(recursive: true)
      ..writeAsBytesSync(pdf);
    // ignore: avoid_print
    print('week ${store.cur}, dead zone ${store.deadZone} mm, '
        '${store.week.fold(0, (n, p) => n + p.stickers.length)} stickers -> dist/print-test.pdf');
  });
}
