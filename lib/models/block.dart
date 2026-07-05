import '../util/json_safe.dart';

/// A single Osnova post-content block ("Andropov"). Posts are `data: [{type,
/// data}, ...]`; each block is rendered by its own widget — see
/// lib/widgets/blocks/block_view.dart.
///
/// Field shapes for text/header/media/quote/list/delimiter/tweet are taken
/// from real DTF post JSON (proven in production). Shapes for the rarer
/// embed/link/code/audio/quiz/person/button/telegram/spotify/yamusic/game
/// types are not yet confirmed by traffic capture, so [parseBlock] probes a
/// few plausible keys and falls back to [LinkCardBlock] or [UnsupportedBlock]
/// rather than guessing a bespoke layout that could be silently wrong.
sealed class Block {
  const Block();
}

class TextBlock extends Block {
  final String html;
  const TextBlock(this.html);
}

class HeaderBlock extends Block {
  final String text;
  final int level;
  const HeaderBlock(this.text, {this.level = 2});
}

class MediaItem {
  final String uuid;
  final String? caption;
  // Original `image` object, passed through to MediaView unchanged — it
  // already knows how to tell image/gif/video apart from this shape.
  final dynamic raw;
  const MediaItem({required this.uuid, this.caption, this.raw});
}

class MediaBlock extends Block {
  final List<MediaItem> items;
  const MediaBlock(this.items);
}

class QuoteBlock extends Block {
  final String text;
  final String? subtitle;
  const QuoteBlock(this.text, this.subtitle);
}

class ListBlock extends Block {
  final bool ordered;
  final List<String> items;
  const ListBlock(this.ordered, this.items);
}

class DividerBlock extends Block {
  const DividerBlock();
}

class CodeBlock extends Block {
  final String code;
  final String? lang;
  const CodeBlock(this.code, this.lang);
}

class AudioBlock extends Block {
  final String uuid;
  final String? title;
  const AudioBlock(this.uuid, this.title);
}

class QuizItem {
  final String text;
  final int votes;
  const QuizItem(this.text, this.votes);
}

class QuizBlock extends Block {
  final String? title;
  final List<QuizItem> items;
  const QuizBlock(this.title, this.items);
}

/// Catch-all for embeds/links/social cards whose exact JSON shape is
/// unconfirmed (tweet/embed/link/telegram/spotify/yamusic/game/button/
/// person). Renders as one tappable "open externally" card instead of
/// either a confidently-wrong bespoke widget or silently rendering nothing.
class LinkCardBlock extends Block {
  final String service;
  final String? url;
  final String? title;
  final String? subtitle;
  final String? thumbUuid;
  const LinkCardBlock({
    required this.service,
    this.url,
    this.title,
    this.subtitle,
    this.thumbUuid,
  });
}

class UnsupportedBlock extends Block {
  final String type;
  const UnsupportedBlock(this.type);
}

Block parseBlock(dynamic raw) {
  if (raw is! Map) return const UnsupportedBlock('?');
  final type = (raw['type'] ?? '').toString();
  final data = raw['data'] is Map ? raw['data'] as Map : const {};

  switch (type) {
    case 'text':
      return TextBlock(asStringOr(data['text']));

    case 'header':
      return HeaderBlock(asStringOr(data['text']), level: data['style'] == 'h3' ? 3 : 2);

    case 'media':
      final items = <MediaItem>[];
      for (final it in asList(data['items'])) {
        if (it is! Map) continue;
        final image = it['image'];
        final uuid = digString(image, ['data', 'uuid']);
        if (uuid == null || uuid.isEmpty) continue;
        items.add(MediaItem(uuid: uuid, caption: it['title']?.toString(), raw: image));
      }
      return MediaBlock(items);

    case 'quote':
      return QuoteBlock(asStringOr(data['text']), data['subTitle']?.toString());

    case 'list':
      return ListBlock(
        data['type'] == 'ordered',
        asList(data['items']).map((e) => e.toString()).toList(),
      );

    case 'delimiter':
      return const DividerBlock();

    case 'code':
      return CodeBlock(asStringOr(data['text']), data['lang']?.toString());

    case 'audio':
      final uuid = digString(data, ['data', 'uuid']) ?? data['uuid']?.toString();
      if (uuid == null || uuid.isEmpty) return const UnsupportedBlock('audio');
      return AudioBlock(uuid, data['title']?.toString());

    case 'quiz':
      final items = asList(data['items']).map((e) {
        if (e is Map) {
          final text = asStringOr(e['text'] ?? e['title']);
          final votes = asIntOr(e['votes'] ?? e['count'] ?? e['percent'], 0);
          return QuizItem(text, votes);
        }
        return QuizItem(e.toString(), 0);
      }).where((q) => q.text.isNotEmpty).toList();
      return QuizBlock(data['title']?.toString() ?? data['question']?.toString(), items);

    case 'tweet':
      final url = digString(data, ['tweet', 'data', 'url']);
      return LinkCardBlock(service: 'tweet', url: url, title: url);

    case 'telegram':
    case 'spotify':
    case 'yamusic':
    case 'game':
      return LinkCardBlock(service: type, url: _firstUrl(data));

    case 'embed':
    case 'video':
      return LinkCardBlock(
        service: asStringOr(data['service'] ?? data['type'], type),
        url: _firstUrl(data),
        title: data['title']?.toString(),
        thumbUuid: digString(data, ['thumb', 'data', 'uuid']) ?? digString(data, ['cover', 'data', 'uuid']),
      );

    case 'link':
      return LinkCardBlock(
        service: 'link',
        url: _firstUrl(data),
        title: data['title']?.toString(),
        subtitle: data['description']?.toString(),
        thumbUuid: digString(data, ['image', 'data', 'uuid']),
      );

    case 'button':
      return LinkCardBlock(
        service: 'button',
        url: _firstUrl(data),
        title: data['text']?.toString() ?? data['title']?.toString(),
      );

    case 'person':
      return LinkCardBlock(
        service: 'person',
        url: _firstUrl(data),
        title: data['name']?.toString(),
        subtitle: data['description']?.toString(),
        thumbUuid: digString(data, ['avatar', 'data', 'uuid']),
      );

    default:
      return UnsupportedBlock(type);
  }
}

/// Best-effort URL lookup for blocks whose key names aren't confirmed yet.
String? _firstUrl(Map data) {
  for (final key in const ['url', 'link', 'href']) {
    final v = data[key];
    if (v is String && v.isNotEmpty) return v;
  }
  for (final key in const ['embed', 'video', 'tweet', 'cover']) {
    final url = digString(data, [key, 'data', 'url']) ?? digString(data, [key, 'url']);
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}
