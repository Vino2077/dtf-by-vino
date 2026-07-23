import 'dart:convert';
import 'package:http/http.dart' as http;

/// A GIF result (named generically so the picker/storage stay backend-agnostic).
class GifResult {
  final String id;
  final String previewUrl; // small looping preview for the grid
  final String fullUrl;    // full gif url, used for extraction/sending

  const GifResult({required this.id, required this.previewUrl, required this.fullUrl});

  // A direct .gif URL that DTF's /uploader/extract accepts.
  String get extractUrl => fullUrl;

  Map<String, dynamic> toJson() => {'id': id, 'previewUrl': previewUrl, 'fullUrl': fullUrl};

  factory GifResult.fromStored(Map<String, dynamic> m) => GifResult(
        id: m['id'] as String,
        previewUrl: m['previewUrl'] as String,
        fullUrl: m['fullUrl'] as String,
      );
}

/// GIF search backed by GIPHY (Tenor was retired by Google).
class GiphyService {
  static const _apiKey = 'OI6FLxolAF3njlTQKScW2UlGhmkBGaod';
  static const _base = 'https://api.giphy.com/v1/gifs';

  static Future<List<GifResult>> search(String query, {int offset = 0}) async {
    final q = query.trim();
    final endpoint = q.isEmpty
        ? '$_base/trending?api_key=$_apiKey&limit=24&offset=$offset&rating=pg-13&bundle=messaging_non_clips'
        : '$_base/search?api_key=$_apiKey&q=${Uri.encodeComponent(q)}&limit=24&offset=$offset&rating=pg-13&bundle=messaging_non_clips';
    try {
      final res = await http.get(Uri.parse(endpoint));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'] as List? ?? [];
        return data.map((g) {
          final images = g['images'] ?? {};
          final preview = images['fixed_width']?['url'] ??
              images['fixed_width_small']?['url'] ??
              images['preview_gif']?['url'] ??
              '';
          final full = images['original']?['url'] ??
              images['downsized']?['url'] ??
              preview;
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
