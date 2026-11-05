import 'package:flutter/material.dart';

import 'editor.dart';
import 'images.dart';
import 'model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ZineStore.open();
  final images = Images(store);
  for (final id in store.lib.keys) {
    images.load('u:$id');
  }
  runApp(ZineApp(store: store, images: images));
}

/// Colour tokens, light and dark: paper, ink, hairlines, one accent.
class Zc extends ThemeExtension<Zc> {
  const Zc({required this.bg, required this.surface, required this.fg, required this.muted, required this.line, required this.soft, required this.accent, required this.accentInk});
  final Color bg, surface, fg, muted, line, soft, accent, accentInk;

  static const light = Zc(
      bg: Color(0xFFEEEBE3), surface: Color(0xFFF6F4EE), fg: Color(0xFF141413), muted: Color(0xFF6E6A61),
      line: Color(0xFF141413), soft: Color(0xFFD5D0C5), accent: Color(0xFFE2328B), accentInk: Colors.white);
  static const dark = Zc(
      bg: Color(0xFF151513), surface: Color(0xFF1D1C19), fg: Color(0xFFECE9E1), muted: Color(0xFF9B978D),
      line: Color(0xFFECE9E1), soft: Color(0xFF36342F), accent: Color(0xFFFF62AD), accentInk: Color(0xFF1A0D16));

  static Zc of(BuildContext context) => Theme.of(context).extension<Zc>()!;

  @override
  Zc copyWith() => this;
  @override
  Zc lerp(Zc? other, double t) => t < .5 ? this : (other ?? this);
}

/// Headline type: heavy condensed uppercase.
const fHead = 'ArchivoX';

/// Small uppercase monospace label.
TextStyle monoLabel(Zc z, {Color? color, double size = 10.5}) =>
    TextStyle(fontFamily: 'PlexMono', fontWeight: FontWeight.w500, fontSize: size, letterSpacing: 1.1, height: 1.3, color: color ?? z.muted);

ThemeData _theme(Zc z, Brightness b) => ThemeData(
      brightness: b,
      fontFamily: 'Archivo',
      scaffoldBackgroundColor: z.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: z.fg, brightness: b, primary: z.fg, onPrimary: z.bg, surface: z.surface, onSurface: z.fg),
      extensions: [z],
      splashFactory: NoSplash.splashFactory,
      snackBarTheme: SnackBarThemeData(
          backgroundColor: z.fg,
          shape: const RoundedRectangleBorder(),
          contentTextStyle: TextStyle(color: z.bg, fontFamily: 'PlexMono', fontWeight: FontWeight.w500, fontSize: 12.5)),
      sliderTheme: SliderThemeData(
        activeTrackColor: z.fg,
        inactiveTrackColor: z.soft,
        thumbColor: z.fg,
        overlayColor: z.fg.withValues(alpha: .08),
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 0, pressedElevation: 0),
      ),
      datePickerTheme: DatePickerThemeData(backgroundColor: z.surface, shape: RoundedRectangleBorder(side: BorderSide(color: z.line))),
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

/// Primary action: solid ink, square, with an arrow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return Material(
      color: onTap == null ? z.muted : z.fg,
      child: InkWell(
        onTap: onTap,
        hoverColor: z.accent.withValues(alpha: .25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text('${label.toUpperCase()}  →', style: monoLabel(z, color: z.bg, size: 12).copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// Secondary action: hairline box.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return Material(
      color: Colors.transparent,
      shape: Border.all(color: z.line),
      child: InkWell(
        onTap: onTap,
        hoverColor: z.soft.withValues(alpha: .6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Text(label.toUpperCase(), style: monoLabel(z, color: z.fg, size: 11)),
        ),
      ),
    );
  }
}

/// A ruled section: a label strip over its body, like a spec table.
class Section extends StatelessWidget {
  const Section({super.key, required this.label, this.meta, required this.child, this.pad = const EdgeInsets.all(12)});
  final String label;
  final String? meta;
  final Widget child;
  final EdgeInsets pad;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: z.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: z.line))),
          child: Row(children: [
            Expanded(child: Text(label.toUpperCase(), style: monoLabel(z, color: z.fg).copyWith(fontWeight: FontWeight.w600))),
            if (meta != null) Text(meta!.toUpperCase(), style: monoLabel(z)),
          ]),
        ),
        Padding(padding: pad, child: child),
      ]),
    );
  }
}

/// One row of a spec table: label on the left, value on the right.
class SpecRow extends StatelessWidget {
  const SpecRow(this.label, this.value, {super.key, this.last = false});
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final z = Zc.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: z.soft))),
      child: Row(children: [
        Expanded(child: Text(label.toUpperCase(), style: monoLabel(z))),
        Text(value.toUpperCase(), style: monoLabel(z, color: z.fg)),
      ]),
    );
  }
}
