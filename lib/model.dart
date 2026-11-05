import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'sticker_catalog.dart';

/// Page size in mm: an A4 sheet cut into eight panels.
const double pw = 74.25, ph = 105;

const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const mons = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// Layout ids and names, cover first then day pages.
const coverLayouts = [('blank', 'Blank'), ('thisweek', 'This week'), ('weekly', 'Weekly'), ('habits', 'Habits')];
const dayLayouts = [
  ('daily', 'Daily'), ('gridnote', 'Grid note'), ('drafting', 'Drafting'), ('modular', 'Modular'), ('routine', 'Routine'), ('checklist', 'Check list'),
];

/// Width/height of any sticker: `b:<pack>/<nn>` or `u:<id>`.
double stickerAspect(String key, Map<String, double> lib) {
  final k = key.substring(2);
  if (key.startsWith('u:')) return lib[k] ?? 1;
  final slash = k.indexOf('/');
  if (slash < 0) return 1;
  final pack = stickerPacks.where((p) => p.$1 == k.substring(0, slash)).firstOrNull;
  return pack?.$3.where((e) => e.$1 == k.substring(slash + 1)).firstOrNull?.$2 ?? 1;
}

String pad(int n) => n.toString().padLeft(2, '0');
String keyOf(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';
DateTime parseKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
String fmtD(DateTime d) => '${pad(d.day)} ${mons[d.month - 1]}';

int isoWeek(DateTime d) {
  final t = DateTime.utc(d.year, d.month, d.day);
  final th = t.add(Duration(days: 4 - t.weekday));
  final y0 = DateTime.utc(th.year, 1, 1);
  return ((th.difference(y0).inDays + 1) / 7).ceil();
}

final _rng = math.Random();
String uid() => List.generate(7, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[_rng.nextInt(36)]).join();

/// A sticker on a page. Position is its centre in mm, w is its width in mm,
/// a is width/height, rot is radians. src is `b:<builtin>` or `u:<image id>`.
class Sticker {
  Sticker({required this.id, required this.src, required this.a, required this.x, required this.y, required this.w, required this.rot});
  final String id, src;
  final double a;
  double x, y, w, rot;

  Sticker copy() => Sticker(id: id, src: src, a: a, x: x, y: y, w: w, rot: rot);
  Map<String, dynamic> toJson() => {'id': id, 'src': src, 'a': a, 'x': x, 'y': y, 'w': w, 'rot': rot};
  factory Sticker.fromJson(Map<String, dynamic> j) => Sticker(
      id: j['id'], src: j['src'], a: (j['a'] as num).toDouble(), x: (j['x'] as num).toDouble(),
      y: (j['y'] as num).toDouble(), w: (j['w'] as num).toDouble(), rot: (j['rot'] as num).toDouble());
}

class ZPage {
  ZPage({this.layout, List<Sticker>? stickers}) : stickers = stickers ?? [];
  String? layout;
  List<Sticker> stickers;

  Map<String, dynamic> toJson() => {'layout': layout, 'stickers': stickers.map((s) => s.toJson()).toList()};
  factory ZPage.fromJson(Map<String, dynamic> j) => ZPage(
      layout: j['layout'],
      stickers: [for (final s in (j['stickers'] as List? ?? [])) Sticker.fromJson(Map<String, dynamic>.from(s))]);
}

/// Everything the app remembers. Images live under their own keys so the
/// main JSON stays small and quick to save.
class ZineStore {
  ZineStore._(this._prefs);
  static const _key = 'tiny-week-zine.v1';
  final SharedPreferences _prefs;

  late String cur;
  final Map<String, List<ZPage>> weeks = {};
  final Map<String, double> lib = {}; // user image id -> aspect
  String? defDay, defCover;

  /// mm this printer can't reach at the top of the portrait page (the
  /// Friday end, fed first) and at the bottom (the cover end). 0 = none.
  double deadTop = 0, deadBottom = 0;
  void Function(String message)? onWarn;
  bool _warned = false;
  Timer? _t;

  static Future<ZineStore> open() async {
    final s = ZineStore._(await SharedPreferences.getInstance());
    s._load();
    return s;
  }

  void _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        cur = j['cur'];
        defDay = j['defDay'];
        defCover = j['defCover'];
        deadTop = (j['deadTop'] as num?)?.toDouble() ?? 0;
        // 1.0.3 had one setting, for the bottom.
        deadBottom = (j['deadBottom'] as num? ?? j['deadZone'] as num?)?.toDouble() ?? 0;
        (j['weeks'] as Map).forEach((k, v) => weeks[k] = [for (final p in v) ZPage.fromJson(Map<String, dynamic>.from(p))]);
        // Up to 1.0.5 there were six drawn stickers ('b:star'…); they're gone.
        for (final w in weeks.values) {
          for (final p in w) {
            p.stickers.removeWhere((s) => s.src.startsWith('b:') && !s.src.contains('/'));
          }
        }
        (j['lib'] as Map? ?? {}).forEach((k, v) => lib[k] = (v as num).toDouble());
      }
    } catch (_) {
      weeks.clear();
    }
    if (weeks.isEmpty) cur = keyOf(mondayOf(DateTime.now()));
    weeks.putIfAbsent(cur, blankWeek);
  }

  List<ZPage> blankWeek() => [ZPage(layout: defCover ?? 'blank'), for (var i = 0; i < 7; i++) ZPage(layout: defDay ?? 'daily')];

  List<ZPage> get week => weeks[cur]!;
  List<DateTime> get dates {
    final b = parseKey(cur);
    return List.generate(7, (i) => DateTime(b.year, b.month, b.day + i));
  }

  void setWeek(DateTime anyDay) {
    cur = keyOf(mondayOf(anyDay));
    weeks.putIfAbsent(cur, blankWeek);
    save();
  }

  void save() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 300), saveNow);
  }

  Future<void> saveNow() async {
    final j = {
      'v': 1,
      'cur': cur,
      'defDay': defDay,
      'defCover': defCover,
      'deadTop': deadTop,
      'deadBottom': deadBottom,
      'weeks': weeks.map((k, v) => MapEntry(k, v.map((p) => p.toJson()).toList())),
      'lib': lib,
    };
    await _guard(() => _prefs.setString(_key, jsonEncode(j)));
  }

  Uint8List? imageBytes(String id) {
    final b = _prefs.getString('img.$id');
    return b == null ? null : base64Decode(b);
  }

  Future<void> putImage(String id, Uint8List bytes, double aspect) async {
    lib[id] = aspect;
    await _guard(() => _prefs.setString('img.$id', base64Encode(bytes)));
    save();
  }

  Future<void> _guard(Future<bool> Function() f) async {
    try {
      await f();
    } catch (_) {
      if (!_warned) {
        _warned = true;
        onWarn?.call('Storage is full here, so big photos may not survive a reload.');
      }
    }
  }
}
