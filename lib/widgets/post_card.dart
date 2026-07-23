import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/dtf_api.dart';
import '../models/block.dart';
import '../models/post.dart';
import '../models/reaction.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../util/osnova_image.dart';
import 'avatar.dart';
import 'badges.dart';
import 'profile_navigation.dart';
import 'reactions.dart';
import 'media_view.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onTapComments;

  const PostCard({super.key, required this.post, this.onTap, this.onTapComments});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _collapsed = false;
  late bool _isFavorited;
  late PostReactions _reactions;
  late String _cachedPreviewText;
  late Map<String, dynamic>? _cachedPreviewMedia;

  // Popular comment shown under posts with 30+ reactions (like the official app).
  static const _popularCommentThreshold = 30;
  static final _topCommentCache = <int, dynamic>{};
  dynamic _topComment;
  bool _topCommentRequested = false;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.post.isFavorited;
    _reactions = widget.post.reactions;
    _cachedPreviewText = _previewText();
    _cachedPreviewMedia = _previewMedia();
    final settings = context.read<SettingsService>();
    if (settings.autoCollapseViewed &&
        settings.viewedPostIds.contains(widget.post.id)) {
      _collapsed = true;
    }
    _maybeLoadTopComment();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.post, widget.post)) {
      _isFavorited = widget.post.isFavorited;
      _reactions = widget.post.reactions;
      _cachedPreviewText = _previewText();
      _cachedPreviewMedia = _previewMedia();
    }
    if (oldWidget.post.id != widget.post.id) {
      _topComment = null;
      _topCommentRequested = false;
      _maybeLoadTopComment();
    }
  }

  Future<void> _maybeLoadTopComment() async {
    if (_topCommentRequested) return;
    final post = widget.post;
    final cached = _topCommentCache[post.id];
    if (cached != null) {
      _topComment = cached;
      _topCommentRequested = true;
      return;
    }
    if (post.counters.reactions < _popularCommentThreshold ||
        post.counters.comments == 0) {
      return;
    }
    _topCommentRequested = true;
    final settings = context.read<SettingsService>();
    final comment = await DtfApi.getTopComment(post.id, settings);
    if (!mounted || comment == null) return;
    _topCommentCache[post.id] = comment;
    setState(() => _topComment = comment);
  }

  Future<void> _toggleBookmark() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Войди в аккаунт')));
      return;
    }
    final postId = widget.post.id;
    final newState = !_isFavorited;
    setState(() => _isFavorited = newState);
    final ok = await DtfApi.toggleFavorite(postId, 1, newState, settings);
    if (!mounted) return;
    if (!ok) setState(() => _isFavorited = !newState);
  }

  Future<void> _react(int reactionId) async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Войди в аккаунт')));
      return;
    }
    final postId = widget.post.id;
    final snapshot = _reactions;
    final before = snapshot.selectedId;
    final updated = snapshot.toggle(reactionId);
    setState(() => _reactions = updated);
    final added = updated.selectedId != 0 && updated.selectedId != before;
    if (added) settings.recordReactionUse(reactionId);
    showReactionToast(context, reactionId, added: added);

    final result = await DtfApi.setReaction(
        id: postId, isComment: false, reactionId: reactionId, settings: settings);
    if (!mounted) return;
    if (result['ok'] != true) {
      setState(() => _reactions = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Реакция: ${result['error'] ?? 'ошибка'}')),
      );
    }
  }

  Map<String, dynamic>? _previewMedia() {
    for (final block in widget.post.blocks) {
      if (block is MediaBlock && block.items.isNotEmpty) {
        final raw = block.items.first.raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    }
    return null;
  }

  String _previewText() {
    for (final block in widget.post.blocks) {
      if (block is TextBlock) {
        return block.html.replaceAll(RegExp(r'<[^>]*>'), '');
      }
    }
    return '';
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (diff.inHours < 24) return '${diff.inHours}ч';
    if (diff.inDays < 30) return '${diff.inDays}д';
    return '${(diff.inDays / 30).floor()}мес';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final post = widget.post;
    final author = post.author;
    final subsite = post.subsite;
    final counters = post.counters;
    final postId = post.id;
    final authorId = author?.id;

    final isViewed = context.select<SettingsService, bool>(
        (settings) => settings.viewedPostIds.contains(postId));
    final userNote = context.select<SettingsService, String?>(
        (s) => authorId != null ? s.userNotes[authorId] : null);

    final myReaction = _reactions.selectedId;
    final reactions = _reactions.counters.where((item) => item.count > 0).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final previewText = _cachedPreviewText;
    final previewMedia = _cachedPreviewMedia;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        isViewed: isViewed,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Avatar.fromData(
                    author?.avatar,
                    size: 36,
                    onTap: () => openUserProfile(context, author?.rawJson),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () => openUserProfile(context, author?.rawJson),
                              child: Text(
                                author?.name ?? '',
                                style: TextStyle(
                                  color: isViewed
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          AuthorBadge(author: author?.rawJson, size: 13),
                          if (userNote != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(userNote,
                                  style: TextStyle(
                                      color: accent, fontSize: 11)),
                            ),
                          ],
                        ]),
                        Row(children: [
                          Text(subsite?.name ?? '',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text('  ·  ',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          Text(_timeAgo(post.date),
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _collapsed = !_collapsed),
                    child: Icon(
                      _collapsed
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showPostMenu(context),
                    child: Icon(Icons.more_vert,
                        color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
            ),
            if (!_collapsed) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: isViewed
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(text: post.title),
                          if (post.isEditorial) ...[
                            const WidgetSpan(
                                child: SizedBox(width: 5)),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(Icons.verified,
                                  size: 17, color: accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.4),
                      ),
                    ],
                    if (previewMedia != null) ...[
                      const SizedBox(height: 10),
                      MediaView(media: previewMedia, maxHeight: 640),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...reactions.take(8).map((r) {
                          final mine = r.id == myReaction;
                          return BurstTap(
                            onTap: () => _react(r.id),
                            onLongPress: () => showReactionUsers(
                                context: context,
                                id: postId,
                                isComment: false,
                                settings: context.read<SettingsService>()),
                            burstColor: accent,
                            scale: 0.90,
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: mine
                                    ? accent.withValues(alpha: 0.18)
                                    : AppColors.bgElevated,
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: mine
                                    ? Border.all(
                                        color: accent, width: 1.2)
                                    : null,
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReactionIcon(
                                        id: r.id,
                                        size: 16,
                                        animated: false),
                                    const SizedBox(width: 4),
                                    Text('${r.count}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  ]),
                            ),
                          );
                        }),
                        AddReactionButton(onPick: _react, size: 26),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      GestureDetector(
                        onTap: widget.onTapComments ?? widget.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 15,
                              color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('${counters.comments}',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _toggleBookmark,
                        behavior: HitTestBehavior.opaque,
                        child: Row(children: [
                          Icon(
                            _isFavorited
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 15,
                            color: _isFavorited
                                ? accent
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                              '${counters.favorites}',
                              style: TextStyle(
                                  color: _isFavorited
                                      ? accent
                                      : AppColors.textMuted,
                                  fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _sharePost(context),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.share_outlined,
                            size: 16, color: AppColors.textMuted),
                      ),
                      const Spacer(),
                      if (counters.hits > 0) ...[
                        Text(_fmtCount(counters.hits),
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(Icons.remove_red_eye_outlined,
                            size: 15, color: AppColors.textMuted),
                      ],
                    ]),
                    if (_topComment != null) ...[
                      const SizedBox(height: 12),
                      _PopularCommentPreview(
                        comment: _topComment,
                        onTap: widget.onTapComments ?? widget.onTap,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ],
          ],
          ),   // Column
        ),     // GlassCard
    );         // GestureDetector
  }

  void _sharePost(BuildContext context) {
    final postId = widget.post.id;
    final url = widget.post.url ?? 'https://dtf.ru/$postId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')));
  }

  void _showPostMenu(BuildContext context) {
    final settings = context.read<SettingsService>();
    final author = widget.post.author;
    final authorId = author?.id;
    final authorName = author?.name ?? '';
    final currentNote =
        authorId != null ? settings.userNotes[authorId] : null;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (authorId != null)
              ListTile(
                leading: Icon(Icons.label_outline,
                    color: AppColors.textPrimary),
                title: Text(
                  currentNote != null
                      ? 'Изменить заметку для $authorName'
                      : 'Добавить заметку для $authorName',
                  style:
                      TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showNoteDialog(context, settings, authorId,
                      authorName, currentNote);
                },
              ),
            ListTile(
              leading: Icon(
                _collapsed ? Icons.expand_more : Icons.expand_less,
                color: AppColors.textPrimary,
              ),
              title: Text(
                _collapsed ? 'Развернуть' : 'Свернуть',
                style:
                    TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() => _collapsed = !_collapsed);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog(BuildContext context, SettingsService settings,
      int userId, String name, String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Заметка для $name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration:
              const InputDecoration(hintText: 'Напиши заметку...'),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () {
                settings.setUserNote(userId, '');
                Navigator.pop(context);
              },
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              settings.setUserNote(userId, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

/// Compact number: 1234 → "1.2K", 1200000 → "1.2M".
String _fmtCount(dynamic n) {
  final v = (n is num) ? n.toInt() : int.tryParse('$n') ?? 0;
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}

/// Most-popular comment shown under a high-reaction post in the feed:
/// avatar + author + text, with a small media thumbnail on the right if any.
class _PopularCommentPreview extends StatelessWidget {
  final dynamic comment;
  final VoidCallback? onTap;
  const _PopularCommentPreview({required this.comment, this.onTap});

  String? _mediaUuid() {
    final media = comment['media'];
    if (media is List && media.isNotEmpty && media[0] is Map) {
      final data = media[0]['data'] ?? media[0]['image']?['data'];
      final uuid = data?['uuid'];
      if (uuid is String && uuid.isNotEmpty) return uuid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final author = comment['author'];
    final text = (comment['text'] ?? '')
        .toString()
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    final uuid = _mediaUuid();
    if (text.isEmpty && uuid == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar.fromData(
              author?['avatar'],
              size: 26,
              onTap: () => openUserProfile(context, author),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author?['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.35),
                    ),
                  ],
                ],
              ),
            ),
            if (uuid != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: OsnovaImage(uuid).preview(120),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  memCacheWidth: 140,
                  placeholder: (_, _) => Container(
                      width: 48, height: 48, color: AppColors.bgCard),
                  errorWidget: (_, _, _) => Container(
                      width: 48, height: 48, color: AppColors.bgCard),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
