// Prints each local CUPS printer's top/bottom margins, as the app sees them.
//   dart run tool/check_printers.dart
// ignore_for_file: avoid_print
import 'package:tiny_week_zine/printer_check_cups.dart';

Future<void> main() async {
  for (final p in await checkPrinters()) {
    print('${p.name}  top ${p.top} mm  bottom ${p.bottom} mm  (${p.info})');
  }
}
