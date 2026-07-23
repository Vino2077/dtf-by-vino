import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/dtf_api.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../services/settings_service.dart';
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
  List<dynamic> _commentItems = [];
  List<Post> _posts = [];
  bool _loading = true;

  // The post id a bookmarked comment belongs to. Tries the structured `entry`
  // object first, then a `url` field (dtf.ru/subsite/12345-slug?comment=…).
  int? _commentPostId(dynamic data) {
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
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsService>();
    if (widget.type == 'posts') {
      final posts = await DtfApi.getPostBookmarks(settings);
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } else {
      final comments = await DtfApi.getBookmarks(settings, type: widget.type);
      if (!mounted) return;
      setState(() {
        _commentItems = comments;
        _loading = false;
      });
    }
  }

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
            final raw = _commentItems[i];
            final data = raw['data'] ?? raw;
            final postId = _commentPostId(data);
            final commentId = data['id'] as int?;
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
                  key: ValueKey(data['id']),
                  comment: Comment.fromJson(
                    Map<String, dynamic>.from(data as Map),
                  ),
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
