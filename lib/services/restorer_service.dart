import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for the community "dtfrandomizer" archive, which stores DTF comments
/// as they appear (via a browser extension) so that later-deleted or edited
/// text can still be read.
///
/// DTF itself returns deleted comments with an empty `text` but full structure
/// (id, author, replyTo, level). We match those ids against this archive to
/// restore the original text — and expose edit history for edited comments.
class RestorerService {
  static const _base = 'https://api.dtfrandomizer.xyz/api';
  static const _timeout = Duration(seconds: 15);

  /// All archived comments for a post, keyed by comment id (as String).
  /// Each value is the inner `data` object: `{date, text, media, user}`.
  /// Empty map on any failure — this is a best-effort enrichment.
  static Future<Map<String, dynamic>> fetchPostComments(int postId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/comments/post/$postId'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const {};
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final list = body is Map ? body['data'] : null;
      if (list is! List) return const {};
      final out = <String, dynamic>{};
      for (final item in list) {
        if (item is Map && item['id'] != null && item['data'] is Map) {
          out['${item['id']}'] = item['data'];
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Edit history for a post's comments, keyed by comment id (as String).
  /// Each value is `{original: {...}, edits: [{date, data:{...}}, ...]}`.
  static Future<Map<String, dynamic>> fetchPostEdits(int postId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/comments/post/$postId/edits'))
          .timeout(_timeout);
      if (res.statusCode != 200) return const {};
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final data = body is Map ? body['data'] : null;
      return data is Map ? data.cast<String, dynamic>() : const {};
    } catch (_) {
      return const {};
    }
  }
}
