import 'dart:convert';
import 'package:http/http.dart' as http;

class PWorldService {
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
  static const _headers = {
    'User-Agent': _ua,
    'Accept-Language': 'ja,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml',
  };

  /// P-WORLDでホール名を検索する
  static Future<List<String>> searchHalls(String keyword) async {
    if (keyword.trim().length < 2) return [];
    try {
      final uri = Uri.https(
        'www.p-world.co.jp',
        '/search/',
        {'keyword': keyword.trim()},
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final body = _decodeBody(res);
      return _extract(body, [
        RegExp(r'class="(?:shopname|shop_name|shop-name)[^"]*"[^>]*>\s*([^<]{2,40}?)\s*<'),
        RegExp(r'<p class="name"[^>]*>\s*<a[^>]+>\s*([^<]{2,40}?)\s*</a>'),
        RegExp(r'<h3[^>]*>\s*<a[^>]+>\s*([^<]{2,40}?)\s*</a>\s*</h3>'),
        RegExp(r'data-name="([^"]{2,40})"'),
      ]);
    } catch (_) {
      return [];
    }
  }

  /// P-WORLDでパチスロ機種名を検索する
  static Future<List<String>> searchMachines(String keyword) async {
    if (keyword.trim().length < 2) return [];
    try {
      final uri = Uri.https(
        'www.p-world.co.jp',
        '/kigyo/list/',
        {'m_type': '2', 'keyword': keyword.trim()},
      );
      final res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final body = _decodeBody(res);
      return _extract(body, [
        RegExp(r'<a href="/kigyo/\d+/?[^"]*">\s*([^<]{2,40}?)\s*</a>'),
        RegExp(r'class="(?:kigyo_name|machine_name|machinename)[^"]*"[^>]*>\s*([^<]{2,40}?)\s*<'),
        RegExp(r'<td[^>]*>\s*<a[^>]+href="/kigyo/[^"]+">([^<]{2,40}?)</a>'),
      ]);
    } catch (_) {
      return [];
    }
  }

  static String _decodeBody(http.Response res) {
    final ct = res.headers['content-type'] ?? '';
    if (ct.toLowerCase().contains('utf-8')) {
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    }
    // Shift-JIS系はそのまま（文字化けする場合はcharset_converterパッケージが必要）
    return res.body;
  }

  static List<String> _extract(String html, List<RegExp> patterns) {
    final seen = <String>{};
    final results = <String>[];
    for (final pattern in patterns) {
      for (final m in pattern.allMatches(html)) {
        final raw = m.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (raw != null && raw.isNotEmpty && raw.length <= 40 && seen.add(raw)) {
          results.add(raw);
        }
      }
    }
    return results.take(15).toList();
  }
}
