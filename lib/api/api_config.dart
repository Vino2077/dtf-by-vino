/// Single source of truth for DTF API host and versions.
///
/// If DTF bumps an API version or moves the host, change it HERE only — every
/// request is built through [url]. Versions are intentionally per-feature
/// because DTF serves different routes on different versions.
class ApiConfig {
  static const host = 'https://api.dtf.ru';

  // Per-feature API versions (as observed in the DTF web client).
  static const vDefault = 'v2.31'; // feed, content, profile, search, bookmarks…
  static const vComments = 'v2.10'; // comments tree, reactions (react)
  static const vAssets = 'v2.9';   // reaction image registry
  static const vEditor = 'v2.11';  // editor (POST editor, POST editor/{id}/publish)

  // Network behaviour
  static const timeout = Duration(seconds: 20);
  static const userAgent = 'dtf-app/2.0.0 (Android; ru)';

  /// Build a full URL: [path] is the route after the version, e.g. 'feed?count=10'.
  static Uri url(String path, {String version = vDefault}) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$host/$version/$clean');
  }
}
