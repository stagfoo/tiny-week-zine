import 'dart:io';
import 'dart:typed_data';

import 'printer_margins.dart';

bool get canCheckPrinters => Platform.isLinux || Platform.isMacOS;

Future<List<PrinterMargins>> checkPrinters() async {
  if (!canCheckPrinters) return const [];
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final req = await client.postUrl(Uri.parse('http://localhost:631/'));
    req.headers.contentType = ContentType('application', 'ipp');
    req.add(cupsGetPrintersRequest());
    final res = await req.close().timeout(const Duration(seconds: 5));
    final b = BytesBuilder();
    await for (final chunk in res) {
      b.add(chunk);
    }
    return parseCupsPrinters(Uint8List.fromList(b.toBytes()));
  } finally {
    client.close(force: true);
  }
}
