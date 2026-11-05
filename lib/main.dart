import 'package:flutter/material.dart';

import 'editor.dart';
import 'images.dart';
import 'model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ZineStore.open();
  final images = Images(store);
  for (final k in builtinStickers.keys) {
    images.load('b:$k');
  }
  for (final id in store.lib.keys) {
    images.load('u:$id');
  }
  runApp(ZineApp(store: store, images: images));
}

/// Colour tokens, light and dark.
class Zc extends ThemeExtension<Zc> {
  const Zc({required this.bg, required this.surface, required this.fg, required this.muted, required this.line, required this.accent, required this.accentInk});
  final Color bg, surface, fg, muted, line, accent, accentInk;

  static const light = Zc(
      bg: Color(0xFFEBE9F2), surface: Color(0xFFF7F6FB), fg: Color(0xFF231D38), muted: Color(0xFF67617E),
      line: Color(0xFFD4D0E2), accent: Color(0xFFE2328B), accentInk: Colors.white);
  static const dark = Zc(
      bg: Color(0xFF15121E), surface: Color(0xFF211D2E), fg: Color(0xFFECE8F6), muted: Color(0xFFA59FBE),
      line: Color(0xFF3A3450), accent: Color(0xFFFF62AD), accentInk: Color(0xFF1A0D16));

  static Zc of(BuildContext context) => Theme.of(context).extension<Zc>()!;

  @override
  Zc copyWith() => this;
  @override
  Zc lerp(Zc? other, double t) => t < .5 ? this : (other ?? this);
}

ThemeData _theme(Zc z, Brightness b) => ThemeData(
      brightness: b,
      fontFamily: 'ZenMaru',
      scaffoldBackgroundColor: z.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: z.accent, brightness: b, primary: z.accent, surface: z.surface),
      extensions: [z],
      snackBarTheme: SnackBarThemeData(backgroundColor: z.fg, contentTextStyle: TextStyle(color: z.bg, fontFamily: 'ZenMaru', fontWeight: FontWeight.w500)),
    );

class ZineApp extends StatelessWidget {
  const ZineApp({super.key, required this.store, required this.images});
  final ZineStore store;
  final Images images;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tiny Week Zine',
        debugShowCheckedModeBanner: false,
        theme: _theme(Zc.light, Brightness.light),
        darkTheme: _theme(Zc.dark, Brightness.dark),
        home: Editor(store: store, images: images),
      );
}

void toast(BuildContext context, String m) {
  final sm = ScaffoldMessenger.of(context);
  sm.hideCurrentSnackBar();
  sm.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 3200)));
}

/// The pink button with a hard ink shadow.
class PinkButton extends StatefulWidget {
  const PinkButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<PinkButton> createState() => _PinkButtonState();
}

class _PinkButtonState extends State<PinkButton> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    final off = down ? 1.0 : 3.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapUp: (_) => setState(() => down = false),
      onTapCancel: () => setState(() => down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(3 - off, 3 - off, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: widget.onTap == null ? z.muted : z.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: z.fg, offset: Offset(off, off))],
        ),
        child: Text(widget.label, style: TextStyle(color: z.accentInk, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return Material(
      color: z.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: z.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: TextStyle(color: z.fg, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
