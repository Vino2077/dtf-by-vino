import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api/app_failure.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/feed/models/feed_type.dart';
import '../features/feed/presentation/feed_controller.dart';
import '../features/feed/presentation/feed_state.dart';
import '../models/block.dart';
import '../models/post.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../util/osnova_image.dart';
import '../widgets/post_card.dart';
import '../widgets/shimmer.dart';
import 'post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // (feedType, fullLabel, shortLabel) — order matches the Figma redesign.
  final _tabs = [
    (FeedType.popular, 'Популярное', 'Топ'),
    (FeedType.fresh, 'Свежее', 'Св.'),
    (FeedType.personal, 'Моя лента', 'Моя'),
    (FeedType.editorial, 'Новости', 'Нов.'),
  ];

  // One key per tab so the active feed list can be scrolled to top (e.g. when
  // the "Главная" nav tab is tapped while already on the feed).
  late final List<GlobalKey<FeedListState>> _listKeys =
      List.generate(_tabs.length, (_) => GlobalKey<FeedListState>());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Rebuild when active tab changes so labels update.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  /// Scrolls the currently-visible feed tab back to the top.
  void scrollActiveToTop() {
    _listKeys[_tabController.index].currentState?.scrollToTop();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _tabController.index;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              // Figma light theme puts the feed tabs on a white strip.
              color: AppColors.isLight ? AppColors.topBar : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                tabs: _tabs.asMap().entries.map((e) {
                  final selected = e.key == activeIndex;
                  // Selected tab shows full name; others show short abbreviation.
                  return Tab(text: selected ? e.value.$2 : e.value.$3);
                }).toList(),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs
                    .asMap()
                    .entries
                    .map((e) => FeedList(
                        key: _listKeys[e.key], feedType: e.value.$1))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact news digest shown at the top of "Популярное".
/// Shows up to 4 editorial posts as title + subsite name + thumbnail cards.
class _NewsDigestBlock extends StatelessWidget {
  final List<Post> posts;
  final void Function(Post post) onTap;

  const _NewsDigestBlock({required this.posts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox();
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Column(
        children: [
          for (int i = 0; i < posts.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1,
                  indent: 16, endIndent: 16),
            _NewsItem(post: posts[i], onTap: () => onTap(posts[i])),
          ],
        ],
      ),
    );
  }
}

class _NewsItem extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _NewsItem({required this.post, required this.onTap});

  String? get _imageUuid {
    for (final block in post.blocks) {
      if (block is MediaBlock && block.items.isNotEmpty) {
        return block.items.first.uuid;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uuid = _imageUuid;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    post.subsite?.name ?? '',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (uuid != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: OsnovaImage(uuid).preview(160),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  placeholder: (_, _) =>
                      Container(width: 72, height: 72, color: AppColors.bgElevated),
                  errorWidget: (_, _, _) =>
                      Container(width: 72, height: 72, color: AppColors.bgElevated),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single self-loading, paginated feed list. Kept alive across tab swipes.
class FeedList extends StatefulWidget {
  final FeedType feedType;
  const FeedList({super.key, required this.feedType});

  @override
  State<FeedList> createState() => FeedListState();
}

class FeedListState extends State<FeedList> with AutomaticKeepAliveClientMixin {
  late final FeedController _controller;
  late final SettingsService _settings;
  final _scrollController = ScrollController();
  var _lastRefreshFailureVersion = 0;
  late bool _wasLoggedIn;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsService>();
    _wasLoggedIn = _settings.isLoggedIn;
    _controller = FeedController(
      context.read<FeedRepository>(),
      () => _settings.isLoggedIn,
      type: widget.feedType,
    )..addListener(_onControllerChanged);
    _settings.addListener(_onSettingsChanged);
    _scrollController.addListener(_onScroll);
    _controller.load();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 500) {
      _controller.loadMore();
    }
  }

  void _onSettingsChanged() {
    final isLoggedIn = _settings.isLoggedIn;
    if (widget.feedType == FeedType.personal && isLoggedIn != _wasLoggedIn) {
      _wasLoggedIn = isLoggedIn;
      _controller.load();
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final state = _controller.state;
    setState(() {});
    if (state.refreshFailureVersion > _lastRefreshFailureVersion) {
      _lastRefreshFailureVersion = state.refreshFailureVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || state.refreshFailure == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.refreshFailure!.message)),
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _settings.removeListener(_onSettingsChanged);
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  /// Scrolls this feed list back to the top (invoked from the "Главная" nav
  /// tab). Safe to call before the list has been laid out.
  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = _controller.state;

    if (state.requiresAuthentication) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Войди в аккаунт, чтобы видеть свою ленту',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ),
      );
    }
    if (state.isInitialLoading) return const FeedSkeleton();
    if (state.initialFailure != null) {
      return _FeedInitialError(
        failure: state.initialFailure!,
        onRetry: _controller.retryInitial,
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom + 86;
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: state.posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPad),
              children: [
                const SizedBox(height: 200),
                Center(
                  child: Text('Нет постов',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            )
          : _buildPosts(state, bottomPad),
    );
  }

  Widget _buildPosts(FeedState state, double bottomPad) {
    final hasDigest =
        widget.feedType == FeedType.popular && state.editorialPosts.isNotEmpty;
    final hasFooter = state.isLoadingMore || state.paginationFailure != null;
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(top: 8, bottom: bottomPad),
      itemCount: state.posts.length + (hasDigest ? 1 : 0) + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && hasDigest) {
          return _NewsDigestBlock(
            posts: state.editorialPosts,
            onTap: (post) => _openPost(context, post),
          );
        }
        final postIndex = hasDigest ? index - 1 : index;
        if (postIndex == state.posts.length) {
          if (state.paginationFailure != null) {
            return _PaginationError(
              message: state.paginationFailure!.message,
              onRetry: _controller.retryPagination,
            );
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final post = state.posts[postIndex];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          onTap: () => _openPost(context, post),
          onTapComments: () => _openPost(context, post, comments: true),
        );
      },
    );
  }

  void _openPost(BuildContext context, Post post, {bool comments = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostScreen(
          postId: post.id,
          title: post.title,
          postData: post,
          openToComments: comments,
        ),
      ),
    );
  }
}

class _FeedInitialError extends StatelessWidget {
  const _FeedInitialError({required this.failure, required this.onRetry});

  final AppFailure failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(failure.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _PaginationError extends StatelessWidget {
  const _PaginationError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('$message · Повторить'),
          ),
        ),
      );
}
