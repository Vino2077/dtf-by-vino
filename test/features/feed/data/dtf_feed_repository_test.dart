import 'package:dtf_app/core/api/api_client.dart';
import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/feed/data/dtf_feed_repository.dart';
import 'package:dtf_app/features/feed/models/feed_page.dart';
import 'package:dtf_app/features/feed/models/feed_type.dart';
import 'package:dtf_app/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiClient implements ApiClient {
  Result<Object?> result = const Success<Object?>(null);
  String? lastPath;

  @override
  Future<Result<Object?>> get(String path, {String? apiVersion}) async {
    lastPath = path;
    return result;
  }

  @override
  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  }) => throw UnimplementedError();

  @override
  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  }) => throw UnimplementedError();

  @override
  void close() {}
}

Map<String, dynamic> postJson(int id, {String title = ''}) => {
  'id': id,
  'title': title,
  'blocks': const [],
};

void main() {
  late _FakeApiClient apiClient;
  late SettingsService settings;
  late DtfFeedRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'batch_size': 20});
    apiClient = _FakeApiClient();
    settings = await SettingsService.load(useLegacyTokenStorage: true);
    repository = DtfFeedRepository(apiClient, settings);
  });

  test(
    'builds fresh-feed path and preserves opaque pagination cursor',
    () async {
      apiClient.result = Success<Object?>({
        'items': [
          {'type': 'entry', 'data': postJson(1)},
        ],
        'lastId': 10,
        'lastSortingValue': '12668.587636617',
      });

      final first = await repository.loadPage(type: FeedType.fresh);
      final page = (first as Success<FeedPage>).value;
      await repository.loadPage(type: FeedType.fresh, cursor: page.cursor);

      expect(page.items.single.id, 1);
      expect(page.cursor?.lastSortingValue, '12668.587636617');
      expect(apiClient.lastPath, contains('lastSortingValue=12668.587636617'));
      expect(apiClient.lastPath, contains('pageName=new'));
      expect(apiClient.lastPath, contains('sorting=all'));
    },
  );

  test('skips news blocks in regular feeds and filters posts', () async {
    settings.preferences.filterKeywords = ['скрыть'];
    apiClient.result = Success<Object?>({
      'items': [
        {
          'type': 'news',
          'data': {
            'news': [postJson(1)],
          },
        },
        {'type': 'entry', 'data': postJson(2, title: 'Скрыть это')},
        {'type': 'entry', 'data': postJson(3, title: 'Оставить это')},
      ],
    });

    final result = await repository.loadPage(type: FeedType.popular);
    final page = (result as Success<FeedPage>).value;

    expect(page.items.map((post) => post.id), [3]);
  });

  test('returns parsing failure for an invalid response envelope', () async {
    apiClient.result = const Success<Object?>('invalid');

    final result = await repository.loadPage(type: FeedType.popular);

    expect(result, isA<Failure<FeedPage>>());
    expect((result as Failure<FeedPage>).failure, isA<ParsingFailure>());
  });

  test('forwards API failures unchanged', () async {
    apiClient.result = const Failure<Object?>(TimeoutFailure());

    final result = await repository.loadPage(type: FeedType.popular);

    expect((result as Failure<FeedPage>).failure, isA<TimeoutFailure>());
  });
}
