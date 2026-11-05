import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'model.dart';

/// Decoded sticker images, shared by the editor and the print sheet.
class Images {
  Images(this.store);
  final ZineStore store;
  final Map<String, ui.Image> _cache = {};
  final Map<String, Future<ui.Image?>> _pending = {};

  ui.Image? get(String key) => _cache[key];

  Future<ui.Image?> load(String key) {
    if (_cache[key] != null) return Future.value(_cache[key]);
    return _pending[key] ??= _decode(key).then((im) {
      if (im != null) _cache[key] = im;
      _pending.remove(key);
      return im;
    });
  }

  Future<ui.Image?> _decode(String key) async {
    try {
      final Uint8List? bytes = key.startsWith('b:')
          ? (await rootBundle.load('assets/stickers/${key.substring(2)}.png')).buffer.asUint8List()
          : store.imageBytes(key.substring(2));
      if (bytes == null) return null;
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  /// Shrinks an imported picture to at most 900px on its long side and
  /// stores it: PNG when it may have transparency, JPEG for photos.
  Future<String?> import(Uint8List bytes, String name) async {
    try {
      final probe = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
      final w = probe.image.width, h = probe.image.height;
      probe.image.dispose();
      final k = 900 / (w > h ? w : h);
      final codec = k < 1
          ? await ui.instantiateImageCodec(bytes, targetWidth: (w * k).round(), targetHeight: (h * k).round())
          : await ui.instantiateImageCodec(bytes);
      final im = (await codec.getNextFrame()).image;
      final alpha = RegExp(r'\.(png|webp|gif|svg)$', caseSensitive: false).hasMatch(name);
      final Uint8List out;
      if (alpha) {
        out = (await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      } else {
        final rgba = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        final pic = img.Image.fromBytes(width: im.width, height: im.height, bytes: rgba.buffer, numChannels: 4);
        out = img.encodeJpg(pic, quality: 86);
      }
      final id = uid();
      _cache['u:$id'] = im;
      await store.putImage(id, out, w / h);
      return 'u:$id';
    } catch (_) {
      return null;
    }
  }
}
