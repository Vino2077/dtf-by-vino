enum FeedType {
  popular,
  fresh,
  personal,
  editorial;

  String get apiName => switch (this) {
    FeedType.popular => 'popular',
    FeedType.fresh => 'new',
    FeedType.personal => 'my',
    FeedType.editorial => 'editorial',
  };
}
