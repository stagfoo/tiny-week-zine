import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'dither.dart';
import 'model.dart';

/// Decoded sticker images, shared by the editor and the print sheet.
class Images {
  Images(this.store);
  final ZineStore store;
  final Map<String, ui.Image> _cache = {};
  final Map<String, Future<ui.Image?>> _pending = {};

  ui.Image? get(String key) => _cache[key];

  String _ditherKey(Sticker k) {
    final (w, h) = ditherSize(k.w, k.a, k.dots ?? 4);
    return '${k.src}|dither|$w|$h|${(k.tone ?? 0).toStringAsFixed(2)}';
  }

  /// The picture a sticker shows: its dithered version when that's on and ready.
  ui.Image? forSticker(Sticker k) => k.dither == true ? (_cache[_ditherKey(k)] ?? _cache[k.src]) : _cache[k.src];

  /// Makes the dithered version for the sticker's current size and settings.
  Future<void> dither(Sticker k) async {
    if (k.dither != true) return;
    final key = _ditherKey(k);
    if (_cache[key] != null) return;
    final src = await load(k.src);
    if (src == null) return;
    final (w, h) = ditherSize(k.w, k.a, k.dots ?? 4);
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawImageRect(src, ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high);
    final small = await rec.endRecording().toImage(w, h);
    final rgba = (await small.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    small.dispose();
    final out = atkinson(rgba, w, h, tone: k.tone ?? 0);
    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    _cache[key] = (await (await desc.instantiateCodec()).getNextFrame()).image;
  }

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
