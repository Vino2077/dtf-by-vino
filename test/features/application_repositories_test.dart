import 'package:dtf_app/core/api/api_client.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/bookmarks/data/dtf_bookmarks_repository.dart';
import 'package:dtf_app/features/notifications/data/dtf_notifications_repository.dart';
import 'package:dtf_app/features/profile/data/dtf_profile_repository.dart';
import 'package:dtf_app/features/search/data/dtf_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi implements ApiClient {
  final Map<String, Result<Object?>> responses = {};
  final paths = <String>[];

  Result<Object?> response(String path) =>
      responses[path] ?? const Success<Object?>(null);

  @override
  Future<Result<Object?>> get(String path, {String? apiVersion}) async {
    paths.add(path);
    return response(path);
  }

  @override
  Future<Result<Object?>> postForm(
    String path, {
    String? apiVersion,
    Map<String, String> body = const {},
  }) async {
    paths.add(path);
    return response(path);
  }

  @override
  Future<Result<Object?>> postMultipart(
    String path, {
    String? apiVersion,
    Map<String, String> fields = const {},
  }) async {
    paths.add(path);
    return response(path);
  }

  @override
  void close() {}
}

void main() {
  test('search repository parses landing and post results', () async {
    final api = FakeApi()
      ..responses['discovery/blogs'] = const Success([
        {'id': 1, 'name': 'Blog'},
      ])
      ..responses['comments/popular'] = const Success([
        {'id': 2, 'text': 'Comment'},
      ])
      ..responses['search?query=query&section=entries&count=20'] =
          const Success({
            'contents': [
              {
                'data': {'id': 3, 'title': 'Post'},
              },
            ],
          });
    final repository = DtfSearchRepository(api);

    final landing = await repository.loadLanding();
    final posts = await repository.search('query');

    expect(landing.valueOrNull?.blogs.single.name, 'Blog');
    expect(landing.valueOrNull?.comments.single.id, 2);
    expect(posts.valueOrNull?.single.id, 3);
  });

  test(
    'bookmarks repository keeps post and comment domains separate',
    () async {
      final api = FakeApi()
        ..responses['bookmarks?type=posts&count=30&offset=0'] = const Success([
          {
            'data': {'id': 1, 'title': 'Post'},
          },
        ])
        ..responses['bookmarks?type=comments&count=30&offset=0'] =
            const Success([
              {
                'data': {'id': 2, 'text': 'Comment'},
              },
            ]);
      final repository = DtfBookmarksRepository(api);

      expect((await repository.load('posts')).valueOrNull?.posts.single.id, 1);
      expect(
        (await repository.load('comments')).valueOrNull?.comments.single.id,
        2,
      );
    },
  );

  test('notifications repository parses updates and unread count', () async {
    final api = FakeApi()
      ..responses['subsite/me/updates?html=true&is_read=2'] = const Success({
        'items': [
          {'id': 9, 'type': 'reply'},
        ],
      })
      ..responses['subsite/me/updates/count'] = const Success({'count': 4});
    final repository = DtfNotificationsRepository(api);

    expect((await repository.load()).valueOrNull?.single.id, 9);
    expect((await repository.unreadCount()).valueOrNull, 4);
  });

  test('profile repository preserves pagination cursor', () async {
    final path = 'timeline?subsitesIds=7&sorting=new&count=20';
    final api = FakeApi()
      ..responses[path] = const Success({
        'items': [
          {
            'type': 'entry',
            'data': {'id': 1, 'title': 'Post'},
          },
        ],
        'lastId': 123,
        'lastSortingValue': 'score',
      });

    final page = await DtfProfileRepository(api).loadPosts(7);

    expect(page.valueOrNull?.items.single.id, 1);
    expect(page.valueOrNull?.cursor?.lastId, 123);
    expect(page.valueOrNull?.cursor?.lastSortingValue, 'score');
  });
}
