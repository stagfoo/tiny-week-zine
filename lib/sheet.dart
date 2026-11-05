import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'images.dart';
import 'main.dart';
import 'model.dart';
import 'page_painter.dart';

/// Builds the imposed A4 print sheet and offers it as a PDF to print or share.
class SheetScreen extends StatefulWidget {
  const SheetScreen({super.key, required this.store, required this.images});
  final ZineStore store;
  final Images images;

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  static const s = 7.0; // px per mm, about 180 dpi
  String busy = 'Laying out 8 pages…';
  ui.Image? sheet;
  Uint8List? pdf;
  bool failed = false;
  int _gen = 0; // newest build wins when the slider moves mid-build
  late double dead = widget.store.deadZone;

  int get wk => isoWeek(widget.store.dates[0]);
  String get name => 'week-$wk-zine.pdf';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _tick() => Future.delayed(const Duration(milliseconds: 16));

  Future<void> _build() async {
    final gen = ++_gen;
    setState(() {
      pdf = null;
      failed = false;
    });
    try {
      final w = widget.store.week;
      setState(() => busy = 'Getting stickers ready…');
      await Future.wait([for (final p in w) for (final k in p.stickers) widget.images.load(k.src)]);
      setState(() => busy = 'Laying out pages…');
      await _tick();
      final im = await renderSheet(w, widget.store.dates, widget.images, s, deadZone: widget.store.deadZone);
      if (!mounted || gen != _gen) return;
      setState(() {
        sheet = im;
        busy = 'Making the PDF…';
      });
      await _tick();
      final bytes = await _pdf(im);
      if (!mounted || gen != _gen) return;
      setState(() => pdf = bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          failed = true;
          busy = 'The sheet could not be built ($e). Go back and try again.';
        });
      }
    }
  }

  /// Turns the landscape sheet upright so it fills a portrait A4 page exactly.
  Future<Uint8List> _pdf(ui.Image im) async {
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..translate(im.height.toDouble(), 0)
      ..rotate(math.pi / 2)
      ..drawImage(im, Offset.zero, Paint());
    final up = await rec.endRecording().toImage(im.height, im.width);
    final rgba = (await up.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final jpg = img.encodeJpg(img.Image.fromBytes(width: up.width, height: up.height, bytes: rgba.buffer, numChannels: 4), quality: 92);
    up.dispose();
    final doc = pw.Document(title: 'Week $wk zine');
    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox(
            width: PdfPageFormat.a4.width, height: PdfPageFormat.a4.height, child: pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.fill))));
    return doc.save();
  }

  Future<void> _print() async {
    try {
      await Printing.layoutPdf(onLayout: (_) async => pdf!, name: name, format: PdfPageFormat.a4);
    } catch (e) {
      if (mounted) toast(context, 'Printing did not work here. Try Save or share instead.');
    }
  }

  Future<void> _share() async {
    try {
      await Printing.sharePdf(bytes: pdf!, filename: name);
    } catch (e) {
      if (mounted) toast(context, 'Sharing did not work here ($e).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    final steps = [
      ('Get the sheet out:', ' save or print the PDF at Actual size (100%), not Fit to page. It is an exact A4 page, so no margin settings are needed.'),
      ('Print', ' on A4 portrait, single-sided.'),
      if (widget.store.deadZone > 0) ('Trim', ' off the strip at the end along the pink TRIM line. Do this first: the folds below assume the shorter sheet.'),
      ('Crease', ' into 8 panels: fold in half top to bottom, then in half left to right, then each end into the middle. Unfold.'),
      ('Cut', ' along the pink dashed line: fold top to bottom again and cut from the folded edge through the middle two panels only.'),
      ('Fold', ' lengthwise, push the ends together so the slit opens, then flatten into a booklet with the week cover on the front.'),
      ('Bind:', ' stack the weeks with week 1 on top, then staple through the two dashed marks on the cover, about 3mm from the spine. Each zine is 8 layers of paper at the spine, so a standard stapler manages 2–3 weeks. For a full month use a heavy-duty stapler, a binder clip or a washi tape spine.'),
    ];
    return Scaffold(
      backgroundColor: z.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Week $wk print sheet', style: TextStyle(fontFamily: 'Mochiy', fontSize: 18, color: z.fg))),
                    GhostButton(label: 'Back to zine', onTap: () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 14),
                  if (sheet != null)
                    Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: z.line), boxShadow: [BoxShadow(color: z.accent, offset: const Offset(5, 5))]),
                      child: AspectRatio(aspectRatio: 297 / 210, child: RawImage(image: sheet, fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
                    ),
                  const SizedBox(height: 18),
                  Text('PRINTER DEAD ZONE  ${dead.toStringAsFixed(1)} mm',
                      style: TextStyle(fontFamily: fMono, fontWeight: FontWeight.w600, fontSize: 10.5, letterSpacing: 1.4, color: z.muted)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Slider(
                      value: dead,
                      min: 0,
                      max: 20,
                      onChanged: (v) => setState(() => dead = v),
                      onChangeEnd: (v) {
                        widget.store.deadZone = v < .5 ? 0 : v;
                        widget.store.save();
                        setState(() => dead = widget.store.deadZone);
                        _build();
                      },
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      dead == 0
                          ? 'Leave at 0 if the whole sheet prints. If your printer cuts off the cover/Monday end, set how many mm it loses there; '
                              'the sheet gets a strip to trim off first so all eight pages stay the same size.'
                          : 'The zine is laid out on ${zineLength(dead).toStringAsFixed(0)} mm of the sheet. Cut the strip past the pink TRIM line off before folding.',
                      style: TextStyle(fontSize: 13, color: z.muted, height: 1.45),
                    ),
                  ),
                  if (pdf == null || failed) ...[
                    const SizedBox(height: 14),
                    Text(busy, style: TextStyle(fontFamily: fMono, color: z.muted)),
                  ],
                  if (pdf != null) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      PinkButton(label: 'Print', onTap: _print),
                      GhostButton(label: 'Save or share PDF', onTap: _share),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  for (var k = 0; k < steps.length; k++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 22, child: Text('${k + 1}.', style: TextStyle(fontFamily: fMono, color: z.accent, fontWeight: FontWeight.w600))),
                          Expanded(
                            child: Text.rich(TextSpan(style: TextStyle(color: z.fg, height: 1.45), children: [
                              TextSpan(text: steps[k].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextSpan(text: steps[k].$2),
                            ])),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
