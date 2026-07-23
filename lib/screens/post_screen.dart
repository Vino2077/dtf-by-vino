import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../features/comments/data/comments_repository.dart';
import '../features/editor/data/editor_repository.dart';
import '../features/comments/presentation/comments_controller.dart';
import '../features/posts/data/post_repository.dart';
import '../features/posts/presentation/post_controller.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../services/settings_service.dart';
import '../services/restorer_service.dart';
import '../theme.dart';
import '../util/osnova_image.dart';
import '../widgets/avatar.dart';
import '../widgets/blocks/block_view.dart';
import '../widgets/comment_thread.dart';
import '../widgets/profile_navigation.dart';
import '../widgets/reactions.dart';
import '../widgets/gif_picker.dart';
import '../widgets/badges.dart';

class PostScreen extends StatefulWidget {
  final int postId;
  final String title;
  final Post? postData;
  final int? scrollToCommentId; // optional: open straight to a comment
  final bool openToComments; // optional: open straight to the comments section

  const PostScreen({
    super.key,
    required this.postId,
    required this.title,
    this.postData,
    this.scrollToCommentId,
    this.openToComments = false,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late final PostController _postController;
  late final CommentsController _commentsController;
  Post? get _post => _postController.state.post;
  List<Comment> get _comments => _commentsController.state.comments;
  CommentTreeIndex _commentTree = CommentTreeIndex.fromComments(const []);
  List<VisibleComment> _visibleComments = const [];
  Set<int> get _collapsedCommentIds => _commentsController.state.collapsedIds;
  bool get _loadingPost => _postController.state.isLoading;
  bool get _postFailed => _postController.state.loadFailure != null;
  bool _loadingComments = true;
  bool _commentsStarted = false;
  String _commentSort = 'hotness'; // 'hotness' (popular) | 'date' (new)
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey(); // for scrolling to the comments section
  final _targetCommentKey = GlobalKey(); // for scrolling to a specific comment

  // Comment composer
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  bool _sending = false;
  int? _replyToId;
  String? _replyToName;
  final List<dynamic> _attachments = []; // DTF media objects to attach
  bool _attaching = false;

  @override
  void initState() {
    super.initState();
    _postController = PostController(
      context.read<PostRepository>(),
      initialPost: widget.postData,
    )..addListener(_onPostChanged);
    _commentsController = CommentsController(context.read<CommentsRepository>())
      ..addListener(_onCommentsChanged);
    if (widget.postData != null) {
      _commentsStarted = true;
      _fetchComments();
    } else {
      _postController.load(widget.postId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsService>().markViewed(widget.postId);
    });
  }

  @override
  void dispose() {
    _postController
      ..removeListener(_onPostChanged)
      ..dispose();
    _commentsController
      ..removeListener(_onCommentsChanged)
      ..dispose();
    _scrollController.dispose();
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _onPostChanged() {
    if (!mounted) return;
    setState(() {});
    if (_post != null && !_commentsStarted) {
      _commentsStarted = true;
      _fetchComments();
    }
  }

  Future<void> _fetchPost() async {
    _commentsStarted = false;
    setState(() => _loadingComments = true);
    await _postController.load(widget.postId);
  }

  bool _didScrollToComments = false;

  Future<void> _fetchComments() async {
    await _commentsController.load(
      widget.postId,
      sorting: _commentSort,
      count: widget.scrollToCommentId != null ? 500 : 200,
    );
    if (!mounted || _commentsController.state.loadFailure != null) return;
    if ((widget.scrollToCommentId != null || widget.openToComments) &&
        !_didScrollToComments) {
      _didScrollToComments = true;
      if (widget.scrollToCommentId != null &&
          !_comments.any((comment) => comment.id == widget.scrollToCommentId)) {
        await _ensureTargetLoaded(widget.scrollToCommentId!);
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComments());
    }
    _enrichWithArchive();
  }

  void _onCommentsChanged() {
    if (!mounted) return;
    _loadingComments = _commentsController.state.isLoading;
    _rebuildCommentIndex();
    setState(() {});
  }

  // Cached community-archive data, so lazily-loaded thread branches can also
  // be enriched without re-fetching.
  Map<String, dynamic> _archiveComments = const {};
  Map<String, dynamic> _archiveEdits = const {};

  // Best-effort: pull the community archive to restore deleted comments' text
  // and attach edit history. Runs after the DTF comments are already shown.
  Future<void> _enrichWithArchive() async {
    final results = await Future.wait([
      RestorerService.fetchPostComments(widget.postId),
      RestorerService.fetchPostEdits(widget.postId),
    ]);
    if (!mounted) return;
    _archiveComments = results[0];
    _archiveEdits = results[1];
    if (_archiveComments.isEmpty && _archiveEdits.isEmpty) return;
    if (_applyArchive(_comments)) setState(() {});
  }

  /// Applies cached archive data to [list]. Returns true if anything changed.
  /// A comment counts as deleted/hidden when DTF flags it, when its text is the
  /// moderator placeholder, or when it's empty — all of those get restored.
  bool _applyArchive(List<Comment> list) {
    if (_archiveComments.isEmpty && _archiveEdits.isEmpty) return false;
    var changed = false;
    final updated = <Comment>[];
    for (final comment in list) {
      final data = comment.toJson();
      final id = '${comment.id}';
      if (data['_restoredText'] == null && data['_restoredMedia'] == null) {
        final text = comment.text.trim();
        final hasMedia = (data['media'] as List?)?.isNotEmpty ?? false;
        final isDeleted =
            data['isRemoved'] == true ||
            data['isRemovedByModerator'] == true ||
            data['isHiddenByBan'] == true ||
            (text.isEmpty && !hasMedia);
        if (isDeleted && _archiveComments[id] is Map) {
          final archive = _archiveComments[id] as Map;
          final restoredText = (archive['text'] ?? '').toString();
          final restoredMedia = archive['media'];
          if (restoredText.isNotEmpty ||
              (restoredMedia is List && restoredMedia.isNotEmpty)) {
            data['_restoredText'] = restoredText;
            data['_restoredMedia'] = restoredMedia;
            changed = true;
          }
        }
      }
      if (data['_edits'] == null && _archiveEdits[id] is Map) {
        data['_edits'] = _archiveEdits[id];
        changed = true;
      }
      updated.add(Comment.fromJson(data));
    }
    if (changed) _commentsController.replaceAll(updated);
    return changed;
  }

  /// Scrolls down to the target comment (from a notification / search) or, when
  /// there's no specific target, to the comments-section header.
  ///
  /// The post body + comments live in a lazy [CustomScrollView], so slivers
  /// below the viewport aren't built yet and their [GlobalKey] context is null.
  /// A single `ensureVisible` therefore did nothing (it stayed at the top of the
  /// post). Here we step the scroll down until the target sliver gets built and
  /// its context appears, then center it.
  Future<void> _scrollToComments() async {
    final wantTarget = widget.scrollToCommentId != null;

    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted || !_scrollController.hasClients) return;

      // If the target comment is already built, centre it and we're done.
      final targetCtx = wantTarget ? _targetCommentKey.currentContext : null;
      if (targetCtx != null) {
        if (!targetCtx.mounted) return;
        await Scrollable.ensureVisible(
          targetCtx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
        return;
      }

      // As soon as the comments header is built, jump to it. The target
      // branch is promoted to the top of the list, so it renders right below
      // — no need to crawl through every comment (that caused the old "scroll
      // for 3s then snap back to the comments start" behaviour).
      final headerCtx = _commentsKey.currentContext;
      if (headerCtx != null) {
        if (!headerCtx.mounted) return;
        await Scrollable.ensureVisible(
          headerCtx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.0,
        );
        if (!wantTarget) return;
        // Give the promoted target a few frames to build, then centre it.
        for (var t = 0; t < 8; t++) {
          if (!mounted) return;
          await Future.delayed(const Duration(milliseconds: 50));
          final tc = _targetCommentKey.currentContext;
          if (tc != null) {
            if (!tc.mounted) return;
            await Scrollable.ensureVisible(
              tc,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.15,
            );
            return;
          }
        }
        // Target isn't in the loaded set — stay at the comments start rather
        // than scrolling away to the bottom.
        return;
      }

      // Comments section not built yet — advance toward it.
      final pos = _scrollController.position;
      final next = (pos.pixels + pos.viewportDimension * 1.5).clamp(
        0.0,
        pos.maxScrollExtent,
      );
      if (next <= pos.pixels + 1) return; // nothing more to scroll
      await _scrollController.animateTo(
        next,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
      );
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _changeCommentSort(String sort) async {
    if (_commentSort == sort) return;
    setState(() {
      _commentSort = sort;
      _loadingComments = true;
    });
    await _fetchComments();
  }

  Set<String> get _loadingThreads => _commentsController.state.loadingThreadIds;

  Future<void> _loadThread(String threadId) async {
    await _commentsController.loadThread(widget.postId, threadId);
    if (!mounted) return;
    _applyArchive(_comments);
  }

  void _rebuildCommentIndex() {
    _commentTree = CommentTreeIndex.fromComments(_comments);
    _rebuildVisibleComments();
  }

  void _rebuildVisibleComments() {
    _visibleComments = _commentTree.flatten(
      collapsedIds: _collapsedCommentIds,
      promoteCommentId: widget.scrollToCommentId,
    );
  }

  void _toggleCommentBranch(int commentId) {
    _commentsController.toggleCollapse(commentId);
  }

  // Threads already bulk-loaded while hunting for a notification's target
  // comment, so we don't fetch them twice.
  final Set<String> _autoLoadedThreads = {};

  /// The main /comments call only returns levels 0-1, so a comment linked from
  /// a notification is often a deeper reply that isn't loaded yet (it sits
  /// behind a "show N replies" button — the user sees it as "collapsed"). Here
  /// we load the branches that still have unloaded replies (each identified by
  /// its shared [threadId]) until the target comment appears, so scroll-to can
  /// reach it. Bounded, and stops as soon as the target is found.
  Future<bool> _ensureTargetLoaded(int targetId) async {
    if (_comments.any((comment) => comment.id == targetId)) return true;
    final loadedChildren = <int, int>{};
    for (final comment in _comments) {
      if (comment.replyTo != 0) {
        loadedChildren[comment.replyTo] =
            (loadedChildren[comment.replyTo] ?? 0) + 1;
      }
    }
    final threadIds = <String>{};
    for (final comment in _comments) {
      final threadId = comment.threadId;
      if (threadId == null ||
          threadId.isEmpty ||
          _autoLoadedThreads.contains(threadId)) {
        continue;
      }
      if (comment.replyCount > (loadedChildren[comment.id] ?? 0)) {
        threadIds.add(threadId);
      }
    }
    for (final threadId in threadIds.take(40)) {
      if (!mounted) return false;
      _autoLoadedThreads.add(threadId);
      await _commentsController.loadThread(widget.postId, threadId);
      if (_comments.any((comment) => comment.id == targetId)) return true;
    }
    _applyArchive(_comments);
    return _comments.any((comment) => comment.id == targetId);
  }

  void _startReply(int commentId, String name) {
    setState(() {
      _replyToId = commentId;
      _replyToName = name;
    });
    _commentFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Войди в аккаунт, чтобы комментировать'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final attachments = _attachments
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final comment = await _commentsController.add(
      postId: widget.postId,
      text: text,
      replyTo: _replyToId,
      attachments: attachments,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (comment != null) {
      _commentController.clear();
      _commentFocus.unfocus();
      setState(() {
        _replyToId = null;
        _replyToName = null;
        _attachments.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Комментарий добавлен'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось: ${_commentsController.state.actionFailure?.message ?? 'ошибка'}',
          ),
          backgroundColor: AppColors.bgElevated,
        ),
      );
    }
  }

  Future<void> _attachGif() async {
    final settings = context.read<SettingsService>();
    final editorRepository = context.read<EditorRepository>();
    final gif = await showGifPicker(context);
    if (gif == null || !mounted) return;
    setState(() => _attaching = true);
    // Save to recents, then resolve to a DTF media object via uploader.
    await settings.addRecentGif(gif.toJson());
    final result = await editorRepository.extractMedia(gif.extractUrl);
    final media = result.valueOrNull;
    if (!mounted) return;
    setState(() {
      _attaching = false;
      if (media != null) {
        _attachments.add(media);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось прикрепить GIF'),
            backgroundColor: AppColors.bgElevated,
          ),
        );
      }
    });
  }

  Future<void> _attachFromGallery() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Войди в аккаунт'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    final picker = ImagePicker();
    final XFile? file = await picker.pickMedia();
    if (file == null || !mounted) return;
    setState(() => _attaching = true);
    final result = await context.read<EditorRepository>().uploadMedia(
      file.path,
    );
    final media = result.valueOrNull;
    if (!mounted) return;
    setState(() {
      _attaching = false;
      if (media != null) {
        _attachments.add(media);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить файл'),
            backgroundColor: AppColors.bgElevated,
          ),
        );
      }
    });
  }

  Future<void> _reactToPost(int reactionId) async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Войди в аккаунт'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    final before = _post?.reactions.selectedId ?? 0;
    final failureVersion = _postController.state.actionFailureVersion;
    await _postController.toggleReaction(reactionId);
    if (!mounted) return;
    final state = _postController.state;
    if (state.actionFailureVersion > failureVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Реакция: ${state.actionFailure!.message}'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    final selected = state.post?.reactions.selectedId ?? 0;
    showReactionToast(
      context,
      reactionId,
      added: selected != 0 && selected != before,
    );
  }

  Future<void> _toggleBookmark() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Войди в аккаунт'),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    final wasFavorite = _post?.isFavorited;
    if (wasFavorite == null) return;
    final failureVersion = _postController.state.actionFailureVersion;
    await _postController.toggleFavorite();
    if (!mounted) return;
    final state = _postController.state;
    if (state.actionFailureVersion > failureVersion) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.actionFailure!.message),
          backgroundColor: AppColors.bgElevated,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !wasFavorite ? 'Добавлено в закладки' : 'Убрано из закладок',
        ),
        backgroundColor: AppColors.bgElevated,
      ),
    );
  }

  void _showPostMenu() {
    final settings = context.read<SettingsService>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.emoji_emotions_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                'Реакции',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Кто поставил реакцию на пост',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showReactionUsers(
                  context: context,
                  id: widget.postId,
                  isComment: false,
                  settings: settings,
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.add_reaction_outlined,
                color: AppColors.textPrimary,
              ),
              title: Text(
                'Поставить реакцию',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showReactionPicker(context, _reactToPost);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _post?.subsite?.name ?? widget.title,
          style: TextStyle(fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _post?.isFavorited == true
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: _post?.isFavorited == true
                  ? accent
                  : AppColors.textPrimary,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: _showPostMenu,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.small(
          onPressed: () => _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          ),
          backgroundColor: AppColors.bgElevated,
          child: Icon(
            Icons.keyboard_arrow_up,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      // Composer lives in the body so resizeToAvoidBottomInset lifts it above
      // the keyboard (a bottomNavigationBar would stay hidden behind it).
      body: _loadingPost
          ? const Center(child: CircularProgressIndicator())
          : _postFailed
          ? _buildLoadError()
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: _buildPostHeader()),
                      const SliverToBoxAdapter(child: Divider(height: 1)),
                      SliverToBoxAdapter(child: _buildPostBody()),
                      SliverToBoxAdapter(child: _buildReactions()),
                      SliverToBoxAdapter(child: _buildStats()),
                      const SliverToBoxAdapter(child: Divider()),
                      SliverToBoxAdapter(child: _buildCommentsHeader()),
                      ..._buildCommentSlivers(),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
                _buildComposer(),
              ],
            ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              'Не удалось загрузить пост',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Проверь соединение или попробуй ещё раз',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final post = _post;
    if (post == null) return const SizedBox();
    final author = post.author;
    final date = post.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Avatar.fromData(
            author?.avatar,
            size: 42,
            onTap: () => openUserProfile(context, author?.rawJson),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => openUserProfile(context, author?.rawJson),
                  child: Row(
                    children: [
                      Text(
                        author?.name ?? '',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      AuthorBadge(author: author?.rawJson, size: 14),
                    ],
                  ),
                ),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions() {
    final post = _post;
    if (post == null) return const SizedBox();
    final myReaction = post.reactions.selectedId;
    final reactions =
        post.reactions.counters.where((reaction) => reaction.count > 0).toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...reactions.map((r) {
            final mine = r.id == myReaction;
            return BurstTap(
              onTap: () => _reactToPost(r.id),
              onLongPress: () => showReactionUsers(
                context: context,
                id: widget.postId,
                isComment: false,
                settings: context.read<SettingsService>(),
              ),
              burstColor: accent,
              scale: 0.90,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mine
                      ? accent.withValues(alpha: 0.18)
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: mine ? Border.all(color: accent, width: 1.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReactionIcon(id: r.id, size: 18, animated: false),
                    const SizedBox(width: 6),
                    Text(
                      '${r.count}',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          AddReactionButton(onPick: _reactToPost),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final post = _post;
    if (post == null) return const SizedBox();
    final counters = post.counters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(
            Icons.remove_red_eye_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            '${counters.hits}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.bookmark_border,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            '${counters.favorites}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.chat_bubble_outline,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            '${counters.comments}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPostBody() {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              children: [
                TextSpan(text: _post?.title ?? widget.title),
                if (_post?.isEditorial == true) ...[
                  const WidgetSpan(child: SizedBox(width: 6)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.verified, size: 20, color: accent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...?_post?.blocks.map((block) => BlockView(block: block)),
        ],
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Column(
      key: _commentsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Комментарии',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_comments.length})',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _commentSortChip('Популярные', 'hotness'),
              const SizedBox(width: 8),
              _commentSortChip('Новые', 'date'),
            ],
          ),
        ),
      ],
    );
  }

  // Returns a list of slivers — loading spinner, empty state, or lazy SliverList.
  List<Widget> _buildCommentSlivers() {
    if (_loadingComments) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ];
    }
    if (_comments.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Комментариев нет',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((ctx, i) {
            final row = _visibleComments[i];
            final id = row.comment.id;
            return CommentRow(
              key: ValueKey(id),
              row: row,
              onReply: (commentId, name) => _startReply(commentId, name),
              onReactionChanged: _fetchComments,
              onToggleCollapse: row.hasChildren
                  ? () => _toggleCommentBranch(id)
                  : null,
              branchCollapsed: _collapsedCommentIds.contains(id),
              onLoadThread: _loadThread,
              loadingThreadIds: _loadingThreads,
              highlightCommentId: widget.scrollToCommentId,
              highlightKey: _targetCommentKey,
            );
          }, childCount: _visibleComments.length),
        ),
      ),
    ];
  }

  Widget _commentSortChip(String label, String value) {
    final active = _commentSort == value;
    final accent = Theme.of(context).colorScheme.primary;
    return PressableScale(
      onTap: () => _changeCommentSort(value),
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.18) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: active ? Border.all(color: accent, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? accent : AppColors.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                color: AppColors.bgDeep,
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ответ для $_replyToName',
                        style: TextStyle(color: accent, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            // Attachment previews
            if (_attachments.isNotEmpty || _attaching)
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  children: [
                    ..._attachments.asMap().entries.map((e) {
                      final uuid = e.value['data']?['uuid'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: OsnovaImage(uuid).preview(120),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  width: 64,
                                  height: 64,
                                  color: AppColors.bgElevated,
                                ),
                                errorWidget: (_, _, _) => Container(
                                  width: 64,
                                  height: 64,
                                  color: AppColors.bgElevated,
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              top: 2,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _attachments.removeAt(e.key),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_attaching)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _attachGif,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'GIF',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.image_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: _attachFromGallery,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocus,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Комментарий...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.bgElevated,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: accent),
                          onPressed: _sendComment,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
