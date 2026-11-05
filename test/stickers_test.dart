import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/sticker_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sticker in every pack is bundled and matches its aspect', () async {
    var n = 0;
    for (final (pack, _, items) in stickerPacks) {
      for (final (stem, aspect) in items) {
        final key = 'b:$pack/$stem';
        final bytes = await rootBundle.load('assets/stickers/$pack/$stem.png');
        final im = (await (await ui.instantiateImageCodec(bytes.buffer.asUint8List())).getNextFrame()).image;
        expect(im.width / im.height, closeTo(aspect, .01), reason: key);
        expect(stickerAspect(key, const {}), aspect, reason: key);
        n++;
      }
    }
    expect(n, greaterThan(150));
  });

  test('the basics and your own photos still resolve', () {
    expect(stickerAspect('b:tape', const {}), 3.0);
    expect(stickerAspect('u:abc', const {'abc': 1.5}), 1.5);
  });
}
