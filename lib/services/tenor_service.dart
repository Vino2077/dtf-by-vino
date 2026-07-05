import 'dart:convert';
import 'package:http/http.dart' as http;

/// A GIF result (named generically so the picker/storage stay backend-agnostic).
class GifResult {
  final String id;
  final String previewUrl; // small looping preview for the grid
  final String fullUrl;     // full gif url, used for extraction/sending

  const GifResult({required this.id, required this.previewUrl, required this.fullUrl});

  // Tenor already gives a direct .gif URL that DTF's /uploader/extract accepts.
  String get extractUrl => fullUrl;

  Map<String, dynamic> toJson() => {'id': id, 'previewUrl': previewUrl, 'fullUrl': fullUrl};

  factory GifResult.fromStored(Map<String, dynamic> m) => GifResult(
        id: m['id'] as String,
        previewUrl: m['previewUrl'] as String,
        fullUrl: m['fullUrl'] as String,
      );
}

class TenorService {
  // Public Tenor (Google) demo key. Replace with your own for production limits.
  static const _apiKey = 'AIzaSyAyimkuYQYF_FXVALexPuGQctUWRURdCYQ';
  static const _base = 'https://tenor.googleapis.com/v2';

  static Future<List<GifResult>> search(String query, {String? pos}) async {
    final q = query.trim();
    final endpoint = q.isEmpty
        ? '$_base/featured?key=$_apiKey&limit=24&media_filter=tinygif,gif&contentfilter=medium${pos != null ? '&pos=$pos' : ''}'
        : '$_base/search?key=$_apiKey&q=${Uri.encodeComponent(q)}&limit=24&media_filter=tinygif,gif&contentfilter=medium${pos != null ? '&pos=$pos' : ''}';
    try {
      final res = await http.get(Uri.parse(endpoint));
      if (res.statusCode == 200) {
        final results = jsonDecode(res.body)['results'] as List? ?? [];
        return results.map((g) {
          final mf = g['media_formats'] ?? {};
          final preview = mf['tinygif']?['url'] ?? mf['nanogif']?['url'] ?? mf['gif']?['url'] ?? '';
          final full = mf['gif']?['url'] ?? mf['mediumgif']?['url'] ?? preview;
          return GifResult(
            id: g['id'].toString(),
            previewUrl: preview,
            fullUrl: full,
          );
        }).where((g) => g.fullUrl.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }
}
