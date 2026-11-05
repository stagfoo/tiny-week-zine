import 'dart:convert';
import 'dart:typed_data';

/// What a printer reports it can't reach at the top and bottom of a page, in mm.
class PrinterMargins {
  const PrinterMargins({required this.name, required this.info, required this.top, required this.bottom});
  final String name, info;
  final double top, bottom;
}

/// An IPP CUPS-Get-Printers request asking for each printer's name and the
/// smallest top/bottom margins it supports (RFC 8011 encoding).
Uint8List cupsGetPrintersRequest() {
  final b = BytesBuilder();
  void u8(int v) => b.addByte(v);
  void u16(int v) => b.add([v >> 8 & 255, v & 255]);
  void attr(int tag, String name, String value) {
    final n = utf8.encode(name), v = utf8.encode(value);
    u8(tag);
    u16(n.length);
    b.add(n);
    u16(v.length);
    b.add(v);
  }

  b.add([2, 0]); // IPP 2.0
  u16(0x4002); // CUPS-Get-Printers
  b.add([0, 0, 0, 1]); // request id
  u8(0x01); // operation attributes
  attr(0x47, 'attributes-charset', 'utf-8');
  attr(0x48, 'attributes-natural-language', 'en');
  const wanted = ['printer-name', 'printer-info', 'media-top-margin-supported', 'media-bottom-margin-supported'];
  for (var i = 0; i < wanted.length; i++) {
    attr(0x44, i == 0 ? 'requested-attributes' : '', wanted[i]);
  }
  u8(0x03); // end
  return b.toBytes();
}

/// Reads a CUPS-Get-Printers response. Margins come in hundredths of a mm;
/// a printer that also offers borderless (0) is judged by its smallest
/// non-zero margin, since plain paper uses that.
List<PrinterMargins> parseCupsPrinters(Uint8List data) {
  final bd = ByteData.sublistView(data);
  final groups = <Map<String, List<Object>>>[];
  Map<String, List<Object>>? cur;
  String? last;
  var i = 8;
  while (i < data.length) {
    final tag = data[i++];
    if (tag == 0x03) break;
    if (tag < 0x10) {
      cur = tag == 0x04 ? (groups..add({})).last : null;
      continue;
    }
    final nl = bd.getUint16(i);
    final name = utf8.decode(data.sublist(i + 2, i + 2 + nl));
    i += 2 + nl;
    final vl = bd.getUint16(i);
    final raw = data.sublist(i + 2, i + 2 + vl);
    i += 2 + vl;
    if (name.isNotEmpty) last = name;
    if (cur == null || last == null) continue;
    final Object value = tag == 0x21 && vl == 4 ? ByteData.sublistView(raw).getInt32(0) : utf8.decode(raw, allowMalformed: true);
    (cur[last] ??= []).add(value);
  }

  double margin(List<Object>? vs) {
    final ints = (vs ?? []).whereType<int>().toList();
    final plain = ints.where((v) => v > 0).toList();
    final pick = plain.isNotEmpty ? plain : ints;
    return pick.isEmpty ? 0 : pick.reduce((a, b) => a < b ? a : b) / 100;
  }

  return [
    for (final g in groups)
      if (g['printer-name'] != null)
        PrinterMargins(
          name: g['printer-name']!.first as String,
          info: (g['printer-info']?.first as String?) ?? '',
          top: margin(g['media-top-margin-supported']),
          bottom: margin(g['media-bottom-margin-supported']),
        ),
  ];
}
