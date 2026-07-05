import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app/browser, with a platform-default fallback.
/// Relative DTF paths (starting with `/`) are made absolute first.
Future<void> openExternalUrl(String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (u.startsWith('www.')) u = 'https://$u';
  if (u.startsWith('/')) u = 'https://dtf.ru$u';
  final uri = Uri.tryParse(u);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }
}
