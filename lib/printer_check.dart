// Asks the local CUPS print service (Linux, macOS) for each printer's margins.
// Elsewhere there is no such service, and the test page is the way to measure.
export 'printer_check_stub.dart' if (dart.library.io) 'printer_check_cups.dart';
