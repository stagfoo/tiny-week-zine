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
import 'printer_check.dart';
import 'printer_margins.dart';
import 'test_page.dart';

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
  late double top = widget.store.deadTop, bottom = widget.store.deadBottom;

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
      final im = await renderSheet(w, widget.store.dates, widget.images, s, deadTop: widget.store.deadTop, deadBottom: widget.store.deadBottom);
      if (!mounted || gen != _gen) return;
      setState(() {
        sheet = im;
        busy = 'Making the PDF…';
      });
      await _tick();
      final bytes = await sheetPdf(im, 'Week $wk zine');
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

  Future<void> _print() async {
    try {
      await Printing.layoutPdf(onLayout: (_) async => pdf!, name: name, format: PdfPageFormat.a4);
    } catch (e) {
      if (mounted) toast(context, 'Printing did not work here. Try Save or share instead.');
    }
  }

  void _setDead(double t, double b) {
    widget.store
      ..deadTop = t < .5 ? 0 : t
      ..deadBottom = b < .5 ? 0 : b
      ..save();
    setState(() {
      top = widget.store.deadTop;
      bottom = widget.store.deadBottom;
    });
    _build();
  }

  Future<void> _testPage() async {
    try {
      await Printing.layoutPdf(onLayout: (_) => testPagePdf(), name: 'printer-check.pdf', format: PdfPageFormat.a4);
    } catch (e) {
      if (mounted) toast(context, 'Printing did not work here ($e).');
    }
  }

  Future<void> _checkPrinters() async {
    List<PrinterMargins> found;
    try {
      found = await checkPrinters();
    } catch (e) {
      if (mounted) toast(context, 'Could not reach the print service here ($e). Use the test page instead.');
      return;
    }
    if (!mounted) return;
    if (found.isEmpty) {
      toast(context, 'No printers found. Use the test page instead.');
      return;
    }
    final z = Zc.of(context);
    final pick = await showModalBottomSheet<PrinterMargins>(
      context: context,
      backgroundColor: z.surface,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text('Pick the printer you will print the zine on. It reports what it can\'t reach at each end.',
                style: TextStyle(color: z.muted, fontSize: 13, height: 1.4)),
          ),
          for (final p in found)
            ListTile(
              title: Text(p.info.isNotEmpty && p.info != p.name ? '${p.info}  ·  ${p.name}' : p.name, style: TextStyle(color: z.fg, fontWeight: FontWeight.w700)),
              subtitle: Text(
                'top ${p.top.toStringAsFixed(1)} mm · bottom ${p.bottom.toStringAsFixed(1)} mm'
                '${stripFor(p.top) == 0 && stripFor(p.bottom) == 0 ? '  ·  no trimming needed' : '  ·  needs a trim strip'}',
                style: TextStyle(fontFamily: fMono, fontSize: 12, color: z.muted),
              ),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    _setDead(pick.top, pick.bottom);
    toast(context, 'Set from ${pick.name}. Print the zine to that same printer.');
  }

  Widget _printerSection(Zc z) {
    final label = TextStyle(fontFamily: fMono, fontWeight: FontWeight.w600, fontSize: 10.5, letterSpacing: 1.4, color: z.muted);
    Widget slider(String name, double v, void Function(double) onChanged, void Function(double) onEnd) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name  ${v.toStringAsFixed(1)} mm', style: label),
            Slider(value: v, min: 0, max: 20, onChanged: onChanged, onChangeEnd: onEnd),
          ],
        );
    final trims = [if (stripFor(top) > 0) 'the Friday end', if (stripFor(bottom) > 0) 'the cover end'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PRINTER', style: label),
        const SizedBox(height: 8),
        Text(
          'Printers can\'t reach the very ends of the paper. Set how many mm yours loses at each end of the page. '
          'An end that loses more than ${stripMin.toStringAsFixed(0)} mm gets a strip to trim off first, so all eight pages stay the same size.',
          style: TextStyle(fontSize: 13, color: z.muted, height: 1.45),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (canCheckPrinters) GhostButton(label: 'Check printer', onTap: _checkPrinters),
          GhostButton(label: 'Print test page', onTap: _testPage),
        ]),
        const SizedBox(height: 12),
        slider('TOP OF PAGE · FRIDAY END', top, (v) => setState(() => top = v), (v) => _setDead(v, bottom)),
        slider('BOTTOM OF PAGE · COVER END', bottom, (v) => setState(() => bottom = v), (v) => _setDead(top, v)),
        Text(
          trims.isEmpty
              ? 'No trimming needed: the whole zine fits inside what your printer can reach.'
              : 'Trim ${trims.join(' and ')} along the pink TRIM line before folding. '
                  'The zine is laid out on ${zineLength(top, bottom).toStringAsFixed(0)} mm of the sheet.',
          style: TextStyle(fontSize: 13, color: z.muted, height: 1.45),
        ),
      ]),
    );
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
      if (stripFor(widget.store.deadTop) + stripFor(widget.store.deadBottom) > 0)
        ('Trim', ' off the strip along each pink TRIM line. Do this first: the folds below assume the shorter sheet.'),
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
                  _printerSection(z),
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

/// Turns the landscape sheet upright so it fills a portrait A4 page exactly.
Future<Uint8List> sheetPdf(ui.Image im, String title) async {
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..translate(im.height.toDouble(), 0)
    ..rotate(math.pi / 2)
    ..drawImage(im, Offset.zero, Paint());
  final up = await rec.endRecording().toImage(im.height, im.width);
  final rgba = (await up.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final jpg = img.encodeJpg(img.Image.fromBytes(width: up.width, height: up.height, bytes: rgba.buffer, numChannels: 4), quality: 92);
  up.dispose();
  final doc = pw.Document(title: title);
  doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.SizedBox(
          width: PdfPageFormat.a4.width, height: PdfPageFormat.a4.height, child: pw.Image(pw.MemoryImage(jpg), fit: pw.BoxFit.fill))));
  return doc.save();
}
