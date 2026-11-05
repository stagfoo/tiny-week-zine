// Renders app screenshots (for the itch.io page and design review) without
// building the app:  flutter test tool/screens_test.dart
// Writes PNGs to itch/screens/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_week_zine/images.dart';
import 'package:tiny_week_zine/main.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/sheet.dart';

Future<void> _font(String fam, List<String> files) async {
  final l = FontLoader(fam);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

Future<void> _fonts() async {
  await _font('Archivo', ['assets/fonts/Archivo-400.ttf', 'assets/fonts/Archivo-500.ttf', 'assets/fonts/Archivo-600.ttf']);
  await _font('ArchivoX', ['assets/fonts/ArchivoNarrow-800.ttf']);
  await _font('PlexMono', ['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-Medium.ttf', 'assets/fonts/IBMPlexMono-SemiBold.ttf']);
  final flutter = Platform.environment['FLUTTER_ROOT']!;
  await _font('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

Sticker _s(String src, double a, double x, double y, double w, double rot) => Sticker(id: src, src: src, a: a, x: x, y: y, w: w, rot: rot);

Future<void> _shoot(WidgetTester t, GlobalKey key, String name) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump();
  }
  await t.runAsync(() async {
    final im = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: t.view.devicePixelRatio);
    File('itch/screens/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync((await im.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
  });
}

void main() {
  late ZineStore store;
  late Images images;

  Future<Widget> app(WidgetTester t, {Widget? home}) async {
    await t.runAsync(_fonts);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      store = await ZineStore.open();
      store.setWeek(DateTime(2026, 11, 2));
      images = Images(store);
      final w = store.week;
      w[0].layout = 'weekly';
      w[0].stickers.addAll([
        _s('b:mushroom/08', stickerAspect('b:mushroom/08', {}), 52, 92, 20, .12),
        _s('b:bunny/05', stickerAspect('b:bunny/05', {}), 20, 93, 16, -.1),
      ]);
      w[1].layout = 'routine';
      w[1].stickers.addAll([
        _s('b:tabby/03', stickerAspect('b:tabby/03', {}), 44, 8.5, 11, .1),
        _s('b:mushroom/11', stickerAspect('b:mushroom/11', {}), 60, 97, 13, -.08),
      ]);
      for (final p in w) {
        for (final s in p.stickers) {
          await images.load(s.src);
        }
      }
    });
    return home == null ? ZineApp(store: store, images: images) : MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(fontFamily: 'Archivo', extensions: const [Zc.light]), home: home);
  }

  for (final (name, size, dpr, page) in [('editor-wide', const Size(1180, 880), 1.5, 1), ('editor-phone', const Size(390, 1500), 2.5, 0)]) {
    testWidgets(name, (t) async {
      t.view.physicalSize = size * dpr;
      t.view.devicePixelRatio = dpr;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(key: key, child: await app(t)));
      await t.tap(find.text(page == 0 ? 'COVER' : 'MON'));
      await _shoot(t, key, name);
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('sheet-wide', (t) async {
    const dpr = 1.5;
    t.view.physicalSize = const Size(1180, 1500) * dpr;
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    final a = await app(t);
    await t.pumpWidget(RepaintBoundary(key: key, child: a));
    store.deadBottom = 12.7;
    final ctx = t.element(find.byType(Scaffold).first);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => SheetScreen(store: store, images: images)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await _shoot(t, key, 'sheet-wide');
    await t.pump(const Duration(seconds: 1));
  });
}
