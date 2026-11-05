import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_week_zine/printer_margins.dart';

/// A CUPS-Get-Printers response holding one printer group per entry.
Uint8List response(List<Map<String, List<Object>>> printers) {
  final b = BytesBuilder()..add([2, 0, 0, 0, 0, 0, 0, 1, 0x01]);
  void attr(int tag, String name, List<int> v) {
    final n = utf8.encode(name);
    b
      ..add([n.length >> 8, n.length & 255, ...n].toList()..insert(0, tag))
      ..add([v.length >> 8, v.length & 255, ...v]);
  }

  attr(0x47, 'attributes-charset', utf8.encode('utf-8'));
  for (final p in printers) {
    b.addByte(0x04);
    p.forEach((name, values) {
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        attr(v is int ? 0x21 : 0x42, i == 0 ? name : '',
            v is int ? (ByteData(4)..setInt32(0, v)).buffer.asUint8List() : utf8.encode(v as String));
      }
    });
  }
  b.addByte(0x03);
  return b.toBytes();
}

void main() {
  test('reads each printer and its top/bottom margins in mm', () {
    final got = parseCupsPrinters(response([
      {'printer-name': ['hpcups'], 'printer-info': ['DeskJet'], 'media-top-margin-supported': [1270], 'media-bottom-margin-supported': [296]},
      {'printer-name': ['usb'], 'media-top-margin-supported': [296], 'media-bottom-margin-supported': [1270]},
    ]));
    expect(got.map((p) => (p.name, p.info, p.top, p.bottom)), [('hpcups', 'DeskJet', 12.7, 2.96), ('usb', '', 2.96, 12.7)]);
  });

  test('borderless (0) is ignored when plain-paper margins are offered too', () {
    final got = parseCupsPrinters(response([
      {'printer-name': ['photo'], 'media-top-margin-supported': [0, 300], 'media-bottom-margin-supported': [0]},
    ]));
    expect((got.single.top, got.single.bottom), (3.0, 0.0));
  });

  test('the request asks CUPS-Get-Printers for the margins', () {
    final r = cupsGetPrintersRequest();
    expect(r.sublist(0, 4), [2, 0, 0x40, 0x02]);
    expect(utf8.decode(r, allowMalformed: true), contains('media-bottom-margin-supported'));
    expect(r.last, 0x03);
  });
}
