import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_week_zine/images.dart';
import 'package:tiny_week_zine/main.dart';
import 'package:tiny_week_zine/model.dart';
import 'package:tiny_week_zine/objects.dart';

void main() {
  late ZineStore store;
  setUp(() => useGoogleFonts = false);

  Future<void> boot(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    await t.runAsync(() async {
      store = await ZineStore.open();
      store.setWeek(DateTime(2026, 11, 4));
    });
    final images = Images(store);
    t.view.physicalSize = const Size(1000, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    store.week[1].stickers.add(Sticker(id: 's', src: 'b:bunny/01', a: 1, x: 37, y: 50, w: 20, rot: 0));
    await t.pumpWidget(ZineApp(store: store, images: images));
    await t.tap(find.text('MON'));
    await t.pump();
  }

  Finder stickerAt() => find.byKey(const ValueKey('s'));

  testWidgets('week starts on the Monday of the picked day', (t) async {
    await boot(t);
    expect(store.cur, '2026-11-02');
    expect(isoWeek(store.dates[0]), 45);
    await t.pump(const Duration(seconds: 1)); // flush the debounced save
  });

  testWidgets('dragging a sticker moves it by the same distance in mm', (t) async {
    await boot(t);
    final s = store.week[1].stickers.single;
    // The sticker's box is its width in mm plus 17px of handle room each side.
    final mm = (t.getSize(stickerAt()).width - 34) / 20;
    await t.dragFrom(t.getCenter(stickerAt()), const Offset(60, 30));
    await t.pump();
    expect(s.x, closeTo(37 + 60 / mm, .5));
    expect(s.y, closeTo(50 + 30 / mm, .5));
    await t.pump(const Duration(seconds: 1)); // flush the debounced save
  });

  testWidgets('pinching scales and turns the sticker', (t) async {
    await boot(t);
    final s = store.week[1].stickers.single;
    final c = t.getCenter(stickerAt());
    final a = await t.startGesture(c - const Offset(10, 0));
    await t.pump();
    final b = await t.startGesture(c + const Offset(10, 0));
    await t.pump();
    await a.moveTo(c - const Offset(0, 20));
    await b.moveTo(c + const Offset(0, 20));
    await t.pump();
    await a.up();
    await b.up();
    await t.pump();
    expect(s.w, closeTo(40, 1));
    expect(s.rot, closeTo(1.5708, .05));
    await t.pump(const Duration(seconds: 1)); // flush the debounced save
  });

  testWidgets('selected sticker can be removed with its × knob', (t) async {
    await boot(t);
    await t.tap(stickerAt(), warnIfMissed: false);
    await t.pump();
    await t.tap(find.text('×'));
    await t.pump();
    expect(store.week[1].stickers, isEmpty);
    await t.pump(const Duration(seconds: 1)); // flush the debounced save
  });

  testWidgets('a text box can be added and typed into; Backspace edits, not deletes', (t) async {
    await boot(t);
    await t.tap(find.text('+ TEXT'));
    await t.pump();
    final k = store.week[1].stickers.last;
    expect(k.isText, isTrue);
    await t.enterText(find.byType(TextField), 'Gym 7am');
    await t.pump();
    expect(k.text, 'Gym 7am');
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    expect(store.week[1].stickers, contains(k), reason: 'still there');
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('shapes are added from the panel', (t) async {
    await boot(t);
    await t.tap(find.text('CIRCLE'));
    await t.pump();
    expect(store.week[1].stickers.last.src, 's:circle');
    await t.pump(const Duration(seconds: 1));
  });
}
