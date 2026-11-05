import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// An A4 page for measuring what a printer loses at each end. Each end has a
/// ladder of lines 1mm apart, numbered by their distance from the paper edge:
/// the first line that prints is how many mm that end loses. A 100mm bar in
/// the middle checks the page printed at actual size.
Future<Uint8List> testPagePdf() async {
  const mm = PdfPageFormat.mm;
  final f = PdfPageFormat.a4;
  final green = PdfColor.fromHex('#1e8a4c'), ink = PdfColor.fromHex('#2a2340'), navy = PdfColor.fromHex('#24305e');
  final doc = pw.Document(title: 'Printer check');
  final font = pw.Font.helvetica(), bold = pw.Font.helveticaBold();

  doc.addPage(pw.Page(
    pageFormat: f,
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(children: [
      pw.CustomPaint(
        size: PdfPoint(f.width, f.height),
        painter: (g, size) {
          // PDF space: origin bottom-left, y up.
          for (final top in [true, false]) {
            for (var d = 1; d <= 24; d++) {
              final y = top ? f.height - d * mm : d * mm;
              final long = d % 10 == 0;
              g
                ..setStrokeColor(long ? green : ink)
                ..setLineWidth(long ? .6 : .3)
                ..drawLine(35 * mm, y, (long ? 175 : 160) * mm, y)
                ..strokePath();
            }
          }
          // 100mm scale bar, with end ticks.
          final y0 = f.height / 2 - 30 * mm, x0 = (f.width - 100 * mm) / 2;
          g
            ..setStrokeColor(navy)
            ..setLineWidth(.8)
            ..drawLine(x0, y0, x0 + 100 * mm, y0)
            ..drawLine(x0, y0 - 3 * mm, x0, y0 + 3 * mm)
            ..drawLine(x0 + 100 * mm, y0 - 3 * mm, x0 + 100 * mm, y0 + 3 * mm)
            ..strokePath();
        },
      ),
      // Ladder numbers, both sides of both ladders.
      for (final top in [true, false])
        for (var d = 2; d <= 24; d += 2)
          for (final x in [24 * mm, 178 * mm])
            pw.Positioned(
              left: x,
              top: (top ? d * mm : f.height - d * mm) - 2.9,
              child: pw.Text('$d', style: pw.TextStyle(font: d % 10 == 0 ? bold : font, fontSize: 5.5, color: d % 10 == 0 ? green : ink)),
            ),
      pw.Positioned(
        left: 30 * mm,
        right: 30 * mm,
        top: 40 * mm,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('TINY WEEK ZINE · PRINTER CHECK', style: pw.TextStyle(font: bold, fontSize: 14, color: navy)),
          pw.SizedBox(height: 10),
          pw.Text('Each end of this page has a ladder of lines 1 mm apart, numbered by their distance from the paper edge.',
              style: pw.TextStyle(font: font, fontSize: 10.5, color: ink, lineSpacing: 3)),
          pw.SizedBox(height: 8),
          pw.Text('At the TOP of the page and at the BOTTOM, find the first line that printed all the way across. '
              'Its number is how many mm that end loses. Enter both numbers in the app, on the print sheet screen.',
              style: pw.TextStyle(font: font, fontSize: 10.5, color: ink, lineSpacing: 3)),
          pw.SizedBox(height: 8),
          pw.Text('If every line printed, that end loses less than 1 mm: enter 0.',
              style: pw.TextStyle(font: font, fontSize: 10.5, color: ink, lineSpacing: 3)),
          pw.SizedBox(height: 8),
          pw.Text('Use the same printer and settings you will print the zine with (Actual size / 100%).',
              style: pw.TextStyle(font: font, fontSize: 10.5, color: ink, lineSpacing: 3)),
        ]),
      ),
      pw.Positioned(
        left: 0,
        right: 0,
        top: f.height / 2 + 34 * mm,
        child: pw.Center(
          child: pw.Text('This bar should measure exactly 100 mm. If not, the print was scaled: turn off "Fit to page".',
              style: pw.TextStyle(font: font, fontSize: 9, color: navy)),
        ),
      ),
      pw.Positioned(left: 0, right: 0, top: 30 * mm, child: pw.Center(child: pw.Text('TOP  (fed first)', style: pw.TextStyle(font: bold, fontSize: 9, color: green)))),
      pw.Positioned(left: 0, right: 0, bottom: 30 * mm, child: pw.Center(child: pw.Text('BOTTOM', style: pw.TextStyle(font: bold, fontSize: 9, color: green)))),
    ]),
  ));
  return doc.save();
}
