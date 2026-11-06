import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Public-domain book illustrations from the Internet Archive Book Images
/// collection, found through Wikimedia Commons' search API (no key needed).
///
/// This is an optional extra: every call here can fail (offline, Commons
/// down, API changed) and the callers treat that as "not available right
/// now". Pictures you add are copied into your own images, so nothing in a
/// zine depends on this service afterwards.
class BookImage {
  const BookImage(this.title, this.thumb);
  final String title, thumb;
}

const bookImageIdeas = ['cat', 'bird', 'flower', 'botanical', 'moon', 'insect', 'ornament', 'map', 'fish', 'tree'];

const _api = 'https://commons.wikimedia.org/w/api.php';
const _agent = 'TinyWeekZine/1.0 (https://github.com/stagfoo/tiny-week-zine)';
const _timeout = Duration(seconds: 12);

/// Licences the collection is published under; anything else is skipped.
bool _freeToUse(String licence) {
  final l = licence.toLowerCase();
  return l.contains('no restrictions') || l.contains('public domain') || l.contains('cc0') || l == 'pd';
}

Future<List<BookImage>> searchBookImages(String query, {int limit = 24}) async {
  final uri = Uri.parse(_api).replace(queryParameters: {
    'action': 'query',
    'format': 'json',
    'origin': '*',
    'generator': 'search',
    'gsrnamespace': '6',
    'gsrlimit': '$limit',
    'gsrsearch': 'insource:"internetarchivebookimages" filetype:bitmap $query',
    'prop': 'imageinfo',
    'iiprop': 'url|extmetadata',
    'iiextmetadatafilter': 'LicenseShortName',
    'iiurlwidth': '600',
  });
  final res = await http.get(uri, headers: {'Api-User-Agent': _agent}).timeout(_timeout);
  if (res.statusCode != 200) throw Exception('Commons answered ${res.statusCode}');
  final pages = ((jsonDecode(res.body) as Map)['query'] as Map?)?['pages'] as Map? ?? {};
  final hits = pages.values.toList()..sort((a, b) => ((a['index'] ?? 0) as int).compareTo((b['index'] ?? 0) as int));
  return [
    for (final p in hits)
      if (p['imageinfo'] is List && (p['imageinfo'] as List).isNotEmpty)
        if (_freeToUse('${(p['imageinfo'][0]['extmetadata'] ?? {})['LicenseShortName']?['value'] ?? ''}'))
          if (p['imageinfo'][0]['thumburl'] is String)
            BookImage(
              '${p['title']}'.replaceFirst('File:', '').replaceAll(RegExp(r'\s*\(\d+\)\.\w+$'), ''),
              p['imageinfo'][0]['thumburl'] as String,
            ),
  ];
}

Future<Uint8List> downloadBookImage(BookImage b) async {
  final res = await http.get(Uri.parse(b.thumb), headers: {'Api-User-Agent': _agent}).timeout(_timeout);
  if (res.statusCode != 200) throw Exception('Image answered ${res.statusCode}');
  return res.bodyBytes;
}
