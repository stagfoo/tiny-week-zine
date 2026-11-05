// Renders the itch.io cover (630x500 @2x) and banner (960 wide @2x) in the
// app's own type and stickers:  flutter test tool/itch_art_test.dart
// Writes itch/cover.png and itch/banner.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/page_painter.dart';

const paper = Color(0xFFEEEBE3), ink = Color(0xFF141413), pinkHi = Color(0xFFE2328B);

Future<void> _font(String fam, List<String> files) async {
  final l = FontLoader(fam);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

final _ds = List.generate(7, (i) => DateTime(2026, 11, 2 + i));
final _stickers = <String, ui.Image>{};

Future<ui.Image> _img(String key) async {
  final bytes = File('assets/stickers/${key.substring(2)}.png').readAsBytesSync();
  return (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
}

TextStyle _mono(double size, [Color c = ink]) => TextStyle(fontFamily: 'PlexMono', fontWeight: FontWeight.w500, fontSize: size, letterSpacing: size * .1, height: 1.35, color: c);
TextStyle _head(double size, [Color c = ink]) => TextStyle(fontFamily: 'ArchivoX', fontWeight: FontWeight.w800, fontSize: size, height: .86, color: c);

/// A zine page as a card with a hard ink shadow, stickers placed in mm.
Widget _page(int pn, String layout, double width, List<(String, double, double, double, double)> st) {
  final pg = ZPage(layout: layout, stickers: [
    for (final (src, x, y, w, rot) in st) Sticker(id: src, src: src, a: _stickers[src]!.width / _stickers[src]!.height, x: x, y: y, w: w, rot: rot)
  ]);
  return Container(
    width: width,
    height: width * ph / pw,
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: ink, width: 1.5), boxShadow: const [BoxShadow(color: ink, offset: Offset(8, 8))]),
    child: CustomPaint(painter: _PagePaint(pn, pg)),
  );
}

class _PagePaint extends CustomPainter {
  _PagePaint(this.pn, this.pg);
  final int pn;
  final ZPage pg;
  @override
  void paint(Canvas c, Size size) {
    final s = size.width / pw;
    drawPage(c, pn, pg, s, _ds);
    for (final k in pg.stickers) {
      final im = _stickers[k.src]!;
      final h = k.w / k.a;
      c.save();
      c.translate(k.x * s, k.y * s);
      c.rotate(k.rot);
      c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), Rect.fromLTWH(-k.w / 2 * s, -h / 2 * s, k.w * s, h * s),
          Paint()..filterQuality = FilterQuality.high);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

Widget _sticker(String key, double h, [double rot = 0]) => Transform.rotate(angle: rot, child: SizedBox(height: h, child: RawImage(image: _stickers[key], fit: BoxFit.contain)));

Widget _cover() => Container(
      color: paper,
      padding: const EdgeInsets.all(14),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: ink, width: 1.5)),
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ink, width: 1.5))),
              child: Row(children: [
                Text('PRINT · FOLD · CUT', style: _mono(11)),
                const Spacer(),
                Text('8 PAGES / ONE A4 SHEET', style: _mono(11)),
              ]),
            ),
          ),
          Positioned(left: 22, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TINY', style: _head(112)),
            Text('WEEK', style: _head(112)),
            Container(
              color: pinkHi,
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
              child: Text('ZINE', style: _head(112, Colors.white)),
            ),
          ])),
          Positioned(right: 128, top: 74, child: Transform.rotate(angle: -.07, child: _page(1, 'weekly', 150, [('b:bunny/05', 22, 92, 18, -.1), ('b:mushroom/08', 54, 91, 20, .1)]))),
          Positioned(right: 26, top: 96, child: Transform.rotate(angle: .06, child: _page(2, 'routine', 150, [('b:tabby/03', 44, 8.5, 12, .1), ('b:mushroom/11', 60, 97, 14, -.08)]))),
          Positioned(right: 236, bottom: 46, child: _sticker('b:chonk/05', 58, -.12)),
          Positioned(right: 30, bottom: 16, child: Text('FREE · WEB · ANDROID · DESKTOP', style: _mono(10.5))),
        ]),
      ),
    );

Widget _banner() => Container(
      color: paper,
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: ink, width: 1.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 26, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('TINY WEEK', style: _head(78)),
              Row(children: [
                Container(color: pinkHi, padding: const EdgeInsets.fromLTRB(3, 4, 6, 0), child: Text('ZINE', style: _head(78, Colors.white))),
              ]),
            ]),
          ),
          Container(width: 1.5, color: ink),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('8 PAGES\nONE A4 SHEET\nONE CUT', style: _mono(12.5)),
              Text('A WEEK PLANNER\nYOU PRINT, FOLD\nAND FILL IN BY HAND', style: _mono(12.5, const Color(0xFF6E6A61))),
            ]),
          ),
          Container(width: 1.5, color: ink),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
                _sticker('b:bunny/05', 84, -.06),
                _sticker('b:tabby/01', 58, .08),
                _sticker('b:mushroom/08', 90, -.04),
              ]),
            ),
          ),
        ]),
      ),
    );

Future<void> _render(WidgetTester t, Widget w, Size size, String path) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: RepaintBoundary(key: key, child: w)));
  await t.pump();
  await t.runAsync(() async {
    final im = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync((await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
  t.view.reset();
}

void main() {
  testWidgets('itch art', (t) async {
    await t.runAsync(() async {
      await _font('Archivo', ['assets/fonts/Archivo-400.ttf', 'assets/fonts/Archivo-500.ttf', 'assets/fonts/Archivo-600.ttf']);
      await _font('ArchivoX', ['assets/fonts/ArchivoNarrow-800.ttf']);
      await _font('PlexMono', ['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-Medium.ttf', 'assets/fonts/IBMPlexMono-SemiBold.ttf']);
      for (final k in ['b:bunny/05', 'b:mushroom/08', 'b:tabby/03', 'b:mushroom/11', 'b:chonk/05', 'b:tabby/01', 'b:fries/07']) {
        _stickers[k] = await _img(k);
      }
    });
    await _render(t, _cover(), const Size(630, 500), 'itch/cover.png');
    await _render(t, _banner(), const Size(960, 250), 'itch/banner.png');
  });
}
