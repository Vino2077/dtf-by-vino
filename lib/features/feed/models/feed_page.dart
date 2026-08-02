import 'dart:collection';

import '../../../models/post.dart';

class FeedCursor {
  const FeedCursor({required this.lastId, this.lastSortingValue});

  final int lastId;
  final String? lastSortingValue;
}

class FeedPage {
  FeedPage({required List<Post> items, this.cursor})
    : items = UnmodifiableListView(List<Post>.from(items));

  final List<Post> items;
  final FeedCursor? cursor;

  bool get isEmpty => items.isEmpty;
  bool get hasMore => cursor != null;

  static final empty = FeedPage(items: const []);
}
