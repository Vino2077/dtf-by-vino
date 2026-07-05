import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/dtf_api.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/profile_navigation.dart';
import '../widgets/shimmer.dart';
import 'post_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int? _lastId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    final items = await DtfApi.getNotifications(settings);
    if (!mounted) return;
    setState(() {
      _items = items;
      _lastId = items.isNotEmpty ? items.last['id'] as int? : null;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastId == null) return;
    setState(() => _loadingMore = true);
    final settings = context.read<SettingsService>();
    final more = await DtfApi.getNotifications(settings, lastId: _lastId);
    if (!mounted) return;
    setState(() {
      _items.addAll(more);
      _lastId = more.isNotEmpty ? more.last['id'] as int? : null;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    if (!settings.isLoggedIn) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('Войди в аккаунт, чтобы видеть уведомления',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const NotificationsSkeleton()
            : _items.isEmpty
                ? const Center(
                    child: Text('Нет уведомлений',
                        style: TextStyle(color: AppColors.textSecondary)))
                : RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _loading = true;
                        _lastId = null;
                      });
                      await _load();
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >
                            n.metrics.maxScrollExtent - 400) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: Builder(builder: (ctx) {
                        final bottomPad =
                            MediaQuery.of(ctx).padding.bottom + 86;
                        return ListView.builder(
                          padding: EdgeInsets.only(bottom: bottomPad),
                          itemCount:
                              _items.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _items.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _NotificationTile(item: _items[i]);
                          },
                        );
                      }),
                    ),
                  ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final dynamic item;
  const _NotificationTile({required this.item});

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (diff.inHours < 24) return '${diff.inHours}ч';
    return '${diff.inDays}д';
  }

  // The payload may sit on the item directly or under `data`.
  dynamic get _d => item['data'] is Map ? item['data'] : item;

  String get _type => (item['type'] ?? _d['type'] ?? '').toString();

  IconData _icon() {
    final type = _type.toLowerCase();
    if (type.contains('comment') || type.contains('reply')) return Icons.chat_bubble_outline;
    if (type.contains('like') || type.contains('vote') || type.contains('react')) {
      return Icons.favorite_outline;
    }
    if (type.contains('mention')) return Icons.alternate_email;
    if (type.contains('subscrib')) return Icons.person_add_alt;
    return Icons.notifications_none;
  }

  // ── Robust extraction (the API shape varies, so search the whole item) ──

  // Find the notification's HTML text: the longest string holding an <a> tag,
  // otherwise the longest plain string that reads like a sentence.
  String? _deepFindHtml(dynamic node, [int depth = 0]) {
    if (depth > 6) return null;
    String? best;
    void consider(String s) {
      if (s.contains('<a ') || s.contains('</a>')) {
        if (best == null || s.length > best!.length) best = s;
      }
    }
    if (node is String) {
      consider(node);
    } else if (node is Map) {
      for (final v in node.values) {
        final r = _deepFindHtml(v, depth + 1);
        if (r != null && (best == null || r.length > best!.length)) best = r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _deepFindHtml(v, depth + 1);
        if (r != null && (best == null || r.length > best!.length)) best = r;
      }
    }
    return best;
  }

  // Plain-text fallback when there's no HTML.
  String _plainFallback() {
    final t = _d['text'] ?? item['text'] ?? _d['title'] ?? item['title'];
    if (t != null && t.toString().trim().isNotEmpty) {
      return t.toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    final type = _type.toLowerCase();
    if (type.contains('reply')) return 'ответил(а) вам';
    if (type.contains('comment')) return 'оставил(а) комментарий';
    if (type.contains('like') || type.contains('react') || type.contains('vote')) return 'оценил(а)';
    if (type.contains('subscrib')) return 'подписался(ась) на вас';
    if (type.contains('mention')) return 'упомянул(а) вас';
    return 'Новое уведомление';
  }

  // APK-confirmed: Notification.User serializes its avatar as `avatar_url`
  // (snake_case) — a complete Leonardo CDN URL string. The old camelCase
  // `avatarUrl` lookup always returned null, so no avatars ever showed.
  String? _getAvatarUrl() {
    final users = item['users'];
    if (users is List && users.isNotEmpty && users[0] is Map) {
      final url = users[0]['avatar_url'] ?? users[0]['avatarUrl'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  // Resolve where a notification should navigate: a post (+optional comment),
  // or a profile. Sources in priority order:
  // 1. href links inside the HTML notification text
  // 2. item['url'] — direct notification URL (confirmed from APK: Notification.url)
  // 3. item['meta']['entityId'] (confirmed from APK: Notification.Meta.entityId)
  // 4. Structured data fields
  // When the URL is a bare profile link (dtf.ru/id290515, dtf.ru/u/12345),
  // profileId is returned instead — subscription/mention notifications open
  // the actor's profile rather than a post.
  (int?, int?, int?) _targetIds(String? html) {
    int? postId;
    int? commentId;
    int? profileId;

    int? parsePostUrl(String rawUrl) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.pathSegments.isEmpty) return null;
      final last = uri.pathSegments.last;
      final idm = RegExp(r'^(\d{4,})').firstMatch(last);
      return idm != null ? int.tryParse(idm.group(1)!) : null;
    }

    if (html != null) {
      final hrefRe = RegExp(r'''href\s*=\s*["']([^"']+)["']''', caseSensitive: false);
      for (final m in hrefRe.allMatches(html)) {
        final uri = Uri.tryParse(m.group(1)!);
        if (uri == null || uri.pathSegments.isEmpty) continue;
        final last = uri.pathSegments.last;
        final idm = RegExp(r'^(\d{4,})').firstMatch(last);
        final c = uri.queryParameters['comment'];
        if (idm != null) {
          postId = int.tryParse(idm.group(1)!);
          if (c != null) commentId = int.tryParse(c);
          if (commentId != null) break;
        }
      }
    }

    // Direct URL field from Notification object (APK-confirmed)
    if (postId == null) {
      final directUrl = item['url'];
      if (directUrl is String && directUrl.isNotEmpty) {
        final uri = Uri.tryParse(directUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final id = parsePostUrl(directUrl);
          if (id != null) {
            postId = id;
            final c = uri.queryParameters['comment'];
            if (c != null) commentId = int.tryParse(c);
          }
        }
      }
    }

    // meta.entityId fallback (APK-confirmed)
    if (postId == null) {
      final meta = item['meta'];
      if (meta is Map) {
        final entityId = meta['entityId'];
        if (entityId is int) postId = entityId;
      }
    }

    // Structured fields fallback
    final d = _d;
    postId ??= _firstInt([
      d['post_id'], d['content_id'], d['contentId'], d['postId'], d['id'],
      d['content']?['id'], d['entry']?['id'], d['post']?['id'],
    ]);
    commentId ??= _firstInt([d['comment_id'], d['commentId'], d['comment']?['id']]);

    // No post → maybe it's a profile link (single path segment like id290515).
    if (postId == null) {
      final directUrl = item['url'];
      if (directUrl is String && directUrl.isNotEmpty) {
        final uri = Uri.tryParse(directUrl);
        if (uri != null && uri.pathSegments.length == 1) {
          final seg = uri.pathSegments.first;
          final m = RegExp(r'^(?:id|u/?)?(\d{4,})$').firstMatch(seg);
          if (m != null) profileId = int.tryParse(m.group(1)!);
        }
      }
    }
    return (postId, commentId, profileId);
  }

  int? _firstInt(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is int) return c;
      if (c is String) { final v = int.tryParse(c); if (v != null) return v; }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final html = _deepFindHtml(item);
    final avatarUrl = _getAvatarUrl();
    final date = _d['date'] ?? item['date'] ?? _d['dateAdded'] ?? item['dateAdded'] ??
        _d['datePublished'] ?? item['datePublished'];

    final (entryId, commentId, profileId) = _targetIds(html);

    final spans = <InlineSpan>[];
    if (html != null) {
      final anchorRe = RegExp(r'''<a\s[^>]*?href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>''',
          caseSensitive: false, dotAll: true);
      int last = 0;
      for (final m in anchorRe.allMatches(html)) {
        if (m.start > last) {
          spans.add(TextSpan(text: _clean(html.substring(last, m.start))));
        }
        spans.add(TextSpan(text: _clean(m.group(2)!),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)));
        last = m.end;
      }
      if (last < html.length) spans.add(TextSpan(text: _clean(html.substring(last))));
    } else {
      spans.add(TextSpan(text: _plainFallback()));
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarUrl != null
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Avatar(uuid: null, size: 42),
                  ),
                )
              : Avatar(uuid: null, size: 42),
          Positioned(
            bottom: -2,
            right: -2,
            child: Builder(builder: (ctx) {
              final accent = Theme.of(ctx).colorScheme.primary;
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: AppColors.bgCard, shape: BoxShape.circle),
                child: Icon(_icon(), size: 13, color: accent),
              );
            }),
          ),
        ],
      ),
      title: Text.rich(
        TextSpan(
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.35),
          children: spans,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: date != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_timeAgo(date),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            )
          : null,
      onTap: (profileId != null || entryId != null)
          ? () {
              if (profileId != null) {
                final users = item['users'];
                final name = users is List && users.isNotEmpty
                    ? users[0]['name']
                    : null;
                openUserProfile(context, {'id': profileId, 'name': name});
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostScreen(
                        postId: entryId!, title: '', scrollToCommentId: commentId),
                  ),
                );
              }
            }
          : null,
    );
  }

  String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&mdash;', '—')
      .replaceAll('&#39;', "'");
}
