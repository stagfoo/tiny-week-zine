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
import 'sticker_catalog.dart';

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
  String pack = stickerPacks.first.$1; // sticker pack shown in the tray

  @override
  void initState() {
    super.initState();
    st.onWarn = (m) => toast(context, m);
    // Repaint once sticker images finish decoding.
    Future.wait([for (final k in _packKeys()) widget.images.load(k), for (final id in st.lib.keys) widget.images.load('u:$id')])
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
        pack = 'yours';
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
              final wide = c.maxWidth >= 860;
              return SingleChildScrollView(
                physics: g != null ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _header(z, c.maxWidth >= 600),
                      _tabs(z),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 500, child: LayoutBuilder(builder: (_, cc) => _stage(z, cc.maxWidth))),
                          const SizedBox(width: 20),
                          Expanded(child: _panel(z)),
                        ])
                      else ...[
                        LayoutBuilder(builder: (_, cc) => _stage(z, cc.maxWidth)),
                        const SizedBox(height: 16),
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

  Future<void> _pickWeek() async {
    final d = await showDatePicker(context: context, initialDate: parseKey(st.cur), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      st.setWeek(d);
      sel = null;
    });
  }

  /// Ruled top bar: wordmark, what it is, and the week.
  Widget _header(Zc z, bool roomy) {
    final ds = st.dates;
    final rule = VerticalDivider(width: 1, thickness: 1, color: z.line);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: z.line)),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: Text('TINY WEEK\nZINE', style: TextStyle(fontFamily: fHead, fontWeight: FontWeight.w800, fontSize: 26, height: .92, color: z.fg)),
          ),
          if (roomy) ...[
            rule,
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('8 PAGES\nONE A4 SHEET\nONE CUT', style: monoLabel(z)),
            ),
          ],
          const Spacer(),
          rule,
          InkWell(
            onTap: _pickWeek,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('WEEK ${isoWeek(ds[0])}  ↓', style: monoLabel(z)),
                const SizedBox(height: 4),
                Text('${fmtD(ds[0])} – ${fmtD(ds[6])}', style: monoLabel(z, color: z.fg, size: 12.5).copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  /// The eight pages as one ruled row.
  Widget _tabs(Zc z) {
    final ds = st.dates;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: z.line), right: BorderSide(color: z.line), bottom: BorderSide(color: z.line))),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < 8; i++) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, color: z.line),
            Expanded(
              child: Material(
                color: i == cur ? z.fg : Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() {
                    cur = i;
                    sel = null;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(i == 0 ? 'COVER' : days[i - 1], style: monoLabel(z, color: i == cur ? z.bg : z.muted, size: 9.5)),
                      const SizedBox(height: 3),
                      Text(i == 0 ? 'W${isoWeek(ds[0])}' : '${ds[i - 1].day}',
                          style: TextStyle(fontFamily: fHead, fontWeight: FontWeight.w800, fontSize: 20, height: 1, color: i == cur ? z.bg : z.fg)),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
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
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: z.line), boxShadow: [BoxShadow(color: z.line, offset: const Offset(6, 6))]),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: fill, border: Border.all(color: Colors.white, width: 1.5)),
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
              right: _p - 14,
              bottom: _p - 14,
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
              left: _p - 14,
              top: _p - 14,
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

  List<String> _packKeys() => pack == 'yours'
      ? [for (final id in st.lib.keys.toList().reversed) 'u:$id']
      : [for (final (n, _) in stickerPacks.firstWhere((p) => p.$1 == pack).$3) 'b:$pack/$n'];

  void _openPack(String id) {
    setState(() => pack = id);
    Future.wait([for (final k in _packKeys()) widget.images.load(k)]).then((_) => mounted ? setState(() {}) : null);
  }

  /// A square hairline tag, filled when chosen.
  Widget _tag(Zc z, String label, bool on, VoidCallback onTap) => Material(
        color: on ? z.fg : Colors.transparent,
        shape: Border.all(color: z.line),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(label.toUpperCase(), style: monoLabel(z, color: on ? z.bg : z.fg, size: 10.5)),
          ),
        ),
      );

  Widget _panel(Zc z) {
    final ds = st.dates;
    final curLay = page.layout ?? (cur > 0 ? 'daily' : 'blank');
    final packs = [if (st.lib.isNotEmpty) ('yours', 'Yours'), for (final p in stickerPacks) (p.$1, p.$2)];
    final keys = _packKeys();
    final desktop = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Section(
        label: 'Layout',
        meta: cur == 0 ? 'cover · page 1' : '${days[cur - 1]} · page ${cur + 1}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 12, children: [
            for (final (id, name) in cur > 0 ? dayLayouts : coverLayouts)
              GestureDetector(
                key: ValueKey(id),
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
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: id == curLay ? z.line : z.soft, width: id == curLay ? 2 : 1),
                        boxShadow: id == curLay ? [BoxShadow(color: z.line, offset: const Offset(3, 3))] : null,
                      ),
                      child: SizedBox(
                        width: 64,
                        height: 90.5,
                        child: CustomPaint(painter: PagePainter(pn: cur + 1, page: page, dates: ds, layoutOverride: id, stamp: '${st.cur}|$cur')),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      color: id == curLay ? z.fg : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(name.toUpperCase(), style: monoLabel(z, color: id == curLay ? z.bg : z.muted, size: 9.5)),
                    ),
                  ]),
                ),
              ),
          ]),
          if (cur > 0) ...[
            const SizedBox(height: 14),
            GhostButton(
              label: 'Use on all 7 days',
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
        ]),
      ),
      const SizedBox(height: 16),
      Section(
        label: 'Stickers',
        meta: '${keys.length} in ${packs.firstWhere((p) => p.$1 == pack, orElse: () => packs.first).$2}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [for (final (id, name) in packs) _tag(z, name, id == pack, () => _openPack(id))]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Semantics(
              button: true,
              label: 'Add your own image',
              child: InkWell(
                onTap: pickImages,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(border: Border.all(color: z.line)),
                  alignment: Alignment.center,
                  child: Text('+\nIMAGE', textAlign: TextAlign.center, style: monoLabel(z, color: z.fg, size: 10)),
                ),
              ),
            ),
            for (final k in keys)
              Semantics(
                button: true,
                label: k.startsWith('u:') ? 'Add your image' : 'Add sticker',
                child: InkWell(
                  onTap: () => addSticker(k, stickerAspect(k, st.lib)),
                  child: Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: z.surface, border: Border.all(color: z.soft)),
                    child: widget.images.get(k) == null ? null : RawImage(image: widget.images.get(k), fit: BoxFit.contain),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Text(
            desktop
                ? 'Tap to add · drag to move · scroll or handle to resize · delete to remove'
                : 'Tap to add · drag to move · pinch or handle to resize and turn',
            style: monoLabel(z, size: 10),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Section(
        label: 'Print',
        meta: 'one sheet · one cut',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SpecRow('Paper', 'A4 · single-sided'),
          const SpecRow('Margins', 'spine 6mm · edge 8mm'),
          const SpecRow('Pages print', 'blank, ready for pen', last: true),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(
              label: 'Make print sheet',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SheetScreen(store: st, images: widget.images))),
            ),
          ),
        ]),
      ),
    ]);
  }
}
