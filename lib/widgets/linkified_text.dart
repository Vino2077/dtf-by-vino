import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../util/external_link.dart';

/// Renders text that may contain HTML `<a href>` links and/or bare URLs,
/// turning every link into a tappable blue span.
class LinkifiedText extends StatefulWidget {
  final String html;
  final TextStyle style;
  final int? maxLines;

  const LinkifiedText(this.html, {super.key, required this.style, this.maxLines});

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final _anchorRe = RegExp(r'''<a\s[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false, dotAll: true);
  static final _urlRe = RegExp(r'(https?://[^\s<]+|www\.[^\s<]+)', caseSensitive: false);

  // link style is resolved from theme in build()

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  String _decode(String s) => s
      .replaceAll('<br>', '\n')
      .replaceAll('<br/>', '\n')
      .replaceAll('<br />', '\n')
      .replaceAll('</p>', '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&mdash;', '—');

  TapGestureRecognizer _recognizer(String url) {
    final r = TapGestureRecognizer()..onTap = () => openExternalUrl(url);
    _recognizers.add(r);
    return r;
  }

  List<InlineSpan> _linkifyPlain(String text, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in _urlRe.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final url = m.group(0)!;
      spans.add(TextSpan(
          text: url, style: linkStyle, recognizer: _recognizer(url)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
        color: Theme.of(context).colorScheme.primary);
    final html = widget.html;
    final spans = <InlineSpan>[];
    int last = 0;

    for (final m in _anchorRe.allMatches(html)) {
      if (m.start > last) {
        spans.addAll(_linkifyPlain(
            _decode(html.substring(last, m.start)), linkStyle));
      }
      final href = m.group(1)!;
      final label = _decode(m.group(2)!).trim();
      spans.add(TextSpan(
        text: label.isEmpty ? href : label,
        style: linkStyle,
        recognizer: _recognizer(href),
      ));
      last = m.end;
    }
    if (last < html.length) {
      spans.addAll(_linkifyPlain(_decode(html.substring(last)), linkStyle));
    }

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
