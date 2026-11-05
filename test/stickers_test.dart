import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('your own photos resolve, and the retired drawn stickers fall back', () {
    expect(stickerAspect('u:abc', const {'abc': 1.5}), 1.5);
    expect(stickerAspect('b:star', const {}), 1);
  });

  test('saved zines lose the retired drawn stickers on load, keep the rest', () async {
    SharedPreferences.setMockInitialValues({
      'tiny-week-zine.v1': jsonEncode({
        'cur': '2026-11-02',
        'weeks': {
          '2026-11-02': [
            {
              'layout': 'blank',
              'stickers': [
                {'id': 'a', 'src': 'b:star', 'a': 1, 'x': 1, 'y': 1, 'w': 20, 'rot': 0},
                {'id': 'b', 'src': 'b:bunny/01', 'a': 1, 'x': 1, 'y': 1, 'w': 20, 'rot': 0},
                {'id': 'c', 'src': 'u:xyz', 'a': 1, 'x': 1, 'y': 1, 'w': 20, 'rot': 0},
              ]
            },
          ],
        },
      }),
    });
    final store = await ZineStore.open();
    expect(store.week.first.stickers.map((s) => s.id), ['b', 'c']);
  });
}
