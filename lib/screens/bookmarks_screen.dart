import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/bookmarks/data/bookmarks_repository.dart';
import '../features/bookmarks/presentation/bookmarks_controller.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../theme.dart';
import '../widgets/post_card.dart';
import '../widgets/comment_widget.dart';
import 'post_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = [('posts', 'Посты'), ('comments', 'Комментарии')];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Закладки', style: TextStyle(color: AppColors.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _BookmarksList(type: t.$1)).toList(),
      ),
    );
  }
}

class _BookmarksList extends StatefulWidget {
  final String type; // 'posts' | 'comments'
  const _BookmarksList({required this.type});

  @override
  State<_BookmarksList> createState() => _BookmarksListState();
}

class _BookmarksListState extends State<_BookmarksList>
    with AutomaticKeepAliveClientMixin {
  late final BookmarksController _controller;
  List<Comment> get _commentItems => _controller.comments;
  List<Post> get _posts => _controller.posts;
  bool get _loading => _controller.isLoading;

  // The post id a bookmarked comment belongs to. Tries the structured `entry`
  // object first, then a `url` field (dtf.ru/subsite/12345-slug?comment=…).
  int? _commentPostId(Comment comment) {
    final data = comment.rawJson;
    final entryId = data['entry']?['id'];
    if (entryId is int) return entryId;
    final url = data['url'] ?? data['entry']?['url'];
    if (url is String && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        for (final seg in uri.pathSegments.reversed) {
          final m = RegExp(r'^(\d{4,})').firstMatch(seg);
          if (m != null) return int.tryParse(m.group(1)!);
        }
      }
    }
    return null;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = BookmarksController(
      context.read<BookmarksRepository>(),
      widget.type,
    )..addListener(_onChanged);
    _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.load();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    final itemCount = widget.type == 'posts'
        ? _posts.length
        : _commentItems.length;
    if (itemCount == 0) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('Пусто', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (ctx, i) {
          if (widget.type == 'comments') {
            // Comment bookmarks wrap the actual comment in `data`.
            final comment = _commentItems[i];
            final data = comment.rawJson;
            final postId = _commentPostId(comment);
            final commentId = comment.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              // Tap on the comment body → open the post and scroll to this
              // exact comment. Reactions/reply keep their own tap handlers
              // (deferToChild), so only "empty" taps trigger navigation.
              child: GestureDetector(
                onTap: postId != null
                    ? () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => PostScreen(
                            postId: postId,
                            title: data['entry']?['title'] ?? '',
                            scrollToCommentId: commentId,
                          ),
                        ),
                      )
                    : null,
                child: CommentWidget(
                  key: ValueKey(comment.id),
                  comment: comment,
                ),
              ),
            );
          }
          final post = _posts[i];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => PostScreen(
                  postId: post.id,
                  title: post.title,
                  postData: post,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
