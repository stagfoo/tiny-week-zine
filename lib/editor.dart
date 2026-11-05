import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'images.dart';
import 'main.dart';
import 'model.dart';
import 'page_painter.dart';
import 'sheet.dart';

/// Space around the paper so sticker handles stay grabbable at the edges.
const _m = 24.0;

/// Padding inside a sticker's box that holds its handles.
const _p = 17.0;

class Editor extends StatefulWidget {
  const Editor({super.key, required this.store, required this.images});
  final ZineStore store;
  final Images images;

  @override
  State<Editor> createState() => _EditorState();
}

class _Gesture {
  _Gesture(this.id, this.kind, this.s0, {this.p0 = Offset.zero, this.d0 = 1, this.a0 = 0, this.m0 = Offset.zero});
  final String id, kind; // drag | handle | pinch
  final Sticker s0;
  final Offset p0, m0;
  final double d0, a0;
}

class _EditorState extends State<Editor> {
  ZineStore get st => widget.store;
  int cur = 0;
  String? sel;
  double mm = 4;
  final ptrs = <int, Offset>{};
  _Gesture? g;
  (String, String)? _hit; // set by a sticker part on pointer down, read by the stage
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    st.onWarn = (m) => toast(context, m);
    // Repaint once sticker images finish decoding.
    Future.wait([for (final k in builtinStickers.keys) widget.images.load('b:$k'), for (final id in st.lib.keys) widget.images.load('u:$id')])
        .then((_) => mounted ? setState(() {}) : null);
  }

  ZPage get page => st.week[cur];
  Sticker? findS(String id) => page.stickers.where((s) => s.id == id).firstOrNull;

  void _save() => st.save();

  // ---------- stickers ----------
  void addSticker(String src, double a, [double? x, double? y]) {
    final s = Sticker(
        id: uid(), src: src, a: a, x: x ?? pw / 2, y: y ?? ph / 2,
        w: src.startsWith('u:') ? 40 : (a >= 2 ? 34 : 20), rot: (math.Random().nextDouble() - .5) * .3);
    widget.images.load(src).then((_) => mounted ? setState(() {}) : null);
    setState(() {
      page.stickers.add(s);
      sel = s.id;
    });
    _save();
  }

  void delSticker(String id) {
    setState(() {
      page.stickers.removeWhere((s) => s.id == id);
      sel = null;
      g = null;
      ptrs.clear();
    });
    _save();
  }

  Future<void> pickImages() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (res == null) return;
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final k = await widget.images.import(bytes, f.name);
      if (!mounted) return;
      if (k == null) {
        toast(context, 'That image could not be opened.');
      } else {
        addSticker(k, st.lib[k.substring(2)]!);
      }
    }
  }

  // ---------- gestures (a port of the web version's pointer logic) ----------
  Offset _toMm(Offset local) => (local - const Offset(_m, _m)) / mm;
  static double _ang(Offset a, Offset b) => math.atan2(b.dy - a.dy, b.dx - a.dx);

  void _down(PointerDownEvent e) {
    final p = _toMm(e.localPosition);
    final hit = _hit;
    _hit = null;
    if (hit?.$2 == 'del') {
      delSticker(hit!.$1);
      return;
    }
    if (g != null && ptrs.length == 1) {
      ptrs[e.pointer] = p;
      final [a, b] = ptrs.values.toList();
      final dd = (b - a).distance;
      g = _Gesture(g!.id, 'pinch', findS(g!.id)!.copy(), d0: dd == 0 ? 1 : dd, a0: _ang(a, b), m0: (a + b) / 2);
      return;
    }
    if (hit == null) {
      if (sel != null) setState(() => sel = null);
      return;
    }
    final s = findS(hit.$1);
    if (s == null) return;
    setState(() {
      sel = s.id;
      page.stickers
        ..remove(s)
        ..add(s);
      ptrs
        ..clear()
        ..[e.pointer] = p;
      g = _Gesture(s.id, hit.$2, s.copy(), p0: p);
    });
  }

  void _move(PointerMoveEvent e) {
    final gg = g;
    if (gg == null || !ptrs.containsKey(e.pointer)) return;
    final p = _toMm(e.localPosition);
    ptrs[e.pointer] = p;
    final s = findS(gg.id), s0 = gg.s0;
    if (s == null) return;
    if (gg.kind == 'drag') {
      s.x = s0.x + p.dx - gg.p0.dx;
      s.y = s0.y + p.dy - gg.p0.dy;
    } else if (gg.kind == 'handle') {
      final h0 = s0.w / s0.a, base = math.sqrt(s0.w * s0.w / 4 + h0 * h0 / 4);
      s.w = (s0.w * (p - Offset(s0.x, s0.y)).distance / base).clamp(5, 140);
      s.rot = math.atan2(p.dy - s0.y, p.dx - s0.x) - math.atan2(h0 / 2, s0.w / 2);
    } else {
      final [a, b] = ptrs.values.toList();
      s.w = (s0.w * (b - a).distance / gg.d0).clamp(5, 140);
      s.rot = s0.rot + _ang(a, b) - gg.a0;
      final mid = (a + b) / 2;
      s.x = s0.x + mid.dx - gg.m0.dx;
      s.y = s0.y + mid.dy - gg.m0.dy;
    }
    s.x = s.x.clamp(-8, pw + 8);
    s.y = s.y.clamp(-8, ph + 8);
    setState(() {});
  }

  void _up(PointerEvent e) {
    if (!ptrs.containsKey(e.pointer)) return;
    ptrs.remove(e.pointer);
    final gg = g;
    if (gg == null) return;
    if (ptrs.length == 1 && gg.kind == 'pinch') {
      g = _Gesture(gg.id, 'drag', findS(gg.id)!.copy(), p0: ptrs.values.first);
    } else if (ptrs.isEmpty) {
      setState(() => g = null);
      _save();
    }
  }

  // Mouse wheel over the page resizes the selected sticker.
  void _wheel(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || sel == null) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (ev) {
      final s = findS(sel!);
      if (s == null) return;
      setState(() => s.w = (s.w * math.exp(-(ev as PointerScrollEvent).scrollDelta.dy / 600)).clamp(5, 140));
      _save();
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): () => sel != null ? delSticker(sel!) : null,
        const SingleActivator(LogicalKeyboardKey.backspace): () => sel != null ? delSticker(sel!) : null,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: z.bg,
          body: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 820;
              return SingleChildScrollView(
                physics: g != null ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _header(z),
                      const SizedBox(height: 14),
                      _tabs(z),
                      const SizedBox(height: 14),
                      if (wide)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 470, child: LayoutBuilder(builder: (_, cc) => _stage(z, cc.maxWidth))),
                          const SizedBox(width: 18),
                          Expanded(child: _panel(z)),
                        ])
                      else ...[
                        LayoutBuilder(builder: (_, cc) => _stage(z, cc.maxWidth)),
                        const SizedBox(height: 18),
                        _panel(z),
                      ],
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _header(Zc z) {
    final mono = TextStyle(fontFamily: fMono, fontSize: 11, letterSpacing: .8, color: z.muted);
    return Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 12, runSpacing: 10, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Tiny Week Zine', style: TextStyle(fontFamily: 'Mochiy', fontSize: 21, height: 1.1, color: z.fg)),
        const SizedBox(height: 4),
        Text('8 PAGES · ONE A4 SHEET · ONE CUT', style: mono.copyWith(fontSize: 10.5)),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('WEEK OF', style: mono),
        const SizedBox(width: 8),
        Material(
          color: z.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: z.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: parseKey(st.cur), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d == null) return;
              setState(() {
                st.setWeek(d);
                sel = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text('${fmtD(parseKey(st.cur))} ${parseKey(st.cur).year}', style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w500, fontSize: 13.5, color: z.fg)),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _tabs(Zc z) {
    final ds = st.dates;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: i == cur ? z.fg : z.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: i == cur ? z.fg : z.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  cur = i;
                  sel = null;
                }),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
                  child: DefaultTextStyle(
                    style: TextStyle(fontFamily: fMono, fontSize: 10, letterSpacing: .6, color: i == cur ? z.bg : z.muted, fontWeight: FontWeight.w500),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(i == 0 ? 'COVER' : days[i - 1]),
                      Text(i == 0 ? 'W${isoWeek(ds[0])}' : '${ds[i - 1].day}',
                          style: TextStyle(fontFamily: 'ZenMaru', fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: 0, color: i == cur ? z.bg : z.fg)),
                      Opacity(opacity: .75, child: Text('p${i + 1}', style: const TextStyle(fontSize: 9))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _stage(Zc z, double maxW) {
    final w = math.min(math.max(200.0, maxW - 2 * _m), 440.0);
    mm = w / pw;
    final h = ph * mm;
    final eager = <Type, GestureRecognizerFactory>{
      EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(EagerGestureRecognizer.new, (_) {}),
    };
    return Center(
      child: SizedBox(
        width: w + 2 * _m,
        height: h + 2 * _m,
        child: RawGestureDetector(
          // While a sticker is being moved, every finger on the page belongs to it.
          gestures: g != null ? eager : const {},
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            onPointerSignal: _wheel,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: _m,
                top: _m,
                width: w,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: z.accent, offset: const Offset(7, 7))]),
                  child: CustomPaint(
                    painter: PagePainter(
                        pn: cur + 1, page: page, dates: st.dates, editor: true,
                        stamp: '${st.cur}|$cur|${page.layout}|${page.stickers.isEmpty}|$mm'),
                  ),
                ),
              ),
              for (final s in page.stickers) _sticker(z, s, eager),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sticker(Zc z, Sticker s, Map<Type, GestureRecognizerFactory> eager) {
    final h = s.w / s.a, on = s.id == sel;
    final im = widget.images.get(s.src);
    Widget part(String kind, Widget child) => RawGestureDetector(
          gestures: eager,
          child: Listener(onPointerDown: (_) => _hit = (s.id, kind), child: child),
        );
    Widget knob(Color fill, Widget child) => Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          alignment: Alignment.center,
          child: child,
        );
    return Positioned(
      key: ValueKey(s.id),
      left: _m + (s.x - s.w / 2) * mm - _p,
      top: _m + (s.y - h / 2) * mm - _p,
      width: s.w * mm + 2 * _p,
      height: h * mm + 2 * _p,
      child: Transform.rotate(
        angle: s.rot,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            left: _p,
            top: _p,
            right: _p,
            bottom: _p,
            child: part(
              'drag',
              MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(border: on ? Border.all(color: z.accent, width: 1.5) : null),
                  child: im == null ? const SizedBox.expand() : RawImage(image: im, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
              ),
            ),
          ),
          if (on)
            Positioned(
              right: _p - 15,
              bottom: _p - 15,
              child: part(
                'handle',
                MouseRegion(
                  cursor: SystemMouseCursors.resizeUpLeftDownRight,
                  child: knob(z.accent, Icon(Icons.rotate_right, size: 16, color: z.accentInk)),
                ),
              ),
            ),
          if (on)
            Positioned(
              left: _p - 15,
              top: _p - 15,
              child: Semantics(
                button: true,
                label: 'Remove sticker',
                child: part('del', knob(z.fg, Text('×', style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w700, fontSize: 16, height: 1, color: z.bg)))),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _label(Zc z, String t) =>
      Text(t.toUpperCase(), style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w600, fontSize: 10.5, letterSpacing: 1.4, color: z.muted));
  Widget _hint(Zc z, String t) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(t, style: TextStyle(fontSize: 13, color: z.muted, height: 1.45)),
      );

  Widget _panel(Zc z) {
    final ds = st.dates;
    final curLay = page.layout ?? (cur > 0 ? 'daily' : 'blank');
    final tile = BoxDecoration(color: z.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: z.line));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(z, 'Layout'),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (id, name) in cur > 0 ? dayLayouts : coverLayouts)
            Padding(
              key: ValueKey(id),
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: z.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), side: BorderSide(color: id == curLay ? z.accent : z.line, width: id == curLay ? 2 : 1)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      page.layout = id;
                      if (cur > 0) {
                        st.defDay = id;
                      } else {
                        st.defCover = id;
                      }
                    });
                    _save();
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: z.line)),
                        child: SizedBox(
                          width: 64,
                          height: 90.5,
                          child: CustomPaint(painter: PagePainter(pn: cur + 1, page: page, dates: ds, layoutOverride: id, stamp: '${st.cur}|$cur')),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(name,
                          style: TextStyle(
                              fontFamily: fMono, fontWeight: FontWeight.w600, fontSize: 11, color: id == curLay ? z.fg : z.muted)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
      if (cur > 0) ...[
        const SizedBox(height: 8),
        GhostButton(
          label: 'Use this layout on all 7 days',
          onTap: () {
            setState(() {
              for (final p in st.week.skip(1)) {
                p.layout = curLay;
              }
              st.defDay = curLay;
            });
            _save();
            toast(context, 'All 7 days now use this layout.');
          },
        ),
      ],
      const SizedBox(height: 8),
      _hint(z, 'Everything prints blank, ready for pen.'),
      const SizedBox(height: 18),
      _label(z, 'Stickers & photos'),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: pickImages,
              child: Container(
                width: 62,
                height: 62,
                decoration: tile.copyWith(border: Border.all(color: z.accent)),
                alignment: Alignment.center,
                child: Text('+ PNG\nor photo',
                    textAlign: TextAlign.center, style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w700, fontSize: 11, height: 1.15, color: z.accent)),
              ),
            ),
          ),
          for (final k in [...st.lib.keys.toList().reversed.map((id) => 'u:$id'), ...builtinStickers.keys.map((b) => 'b:$b')])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                label: k.startsWith('b:') ? 'Add ${k.substring(2)} sticker' : 'Add your image',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => addSticker(k, k.startsWith('b:') ? builtinStickers[k.substring(2)]! : st.lib[k.substring(2)]!),
                  child: Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(6),
                    decoration: tile,
                    child: widget.images.get(k) == null ? null : RawImage(image: widget.images.get(k), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      _hint(
          z,
          'Tap a sticker to add it. Drag to move it, and pinch or drag the pink handle to resize and turn it. '
          '${kIsWeb || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS ? 'With a mouse, scroll over the page to resize the selected sticker and press Delete to remove it.' : ''}'),
      const SizedBox(height: 18),
      Divider(color: z.line, height: 1),
      const SizedBox(height: 14),
      _label(z, 'Print'),
      const SizedBox(height: 8),
      PinkButton(
        label: 'Make print sheet',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SheetScreen(store: st, images: widget.images))),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final t in ['A4', 'single-sided', 'spine margin 6mm', 'edge margin 8mm'])
          Text(t, style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w500, fontSize: 11.5, color: z.muted)),
      ]),
    ]);
  }
}
