import 'package:dtf_app/core/api/app_failure.dart';
import 'package:dtf_app/core/api/result.dart';
import 'package:dtf_app/features/feed/data/feed_repository.dart';
import 'package:dtf_app/features/feed/models/feed_page.dart';
import 'package:dtf_app/features/feed/models/feed_type.dart';
import 'package:dtf_app/screens/feed_screen.dart';
import 'package:dtf_app/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository(this.responses);

  final List<Result<FeedPage>> responses;
  var calls = 0;

  @override
  Future<Result<FeedPage>> loadPage({
    required FeedType type,
    FeedCursor? cursor,
  }) async {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return responses[index];
  }
}

Future<void> pumpFeed(
  WidgetTester tester, {
  required FeedRepository repository,
  required FeedType type,
}) => tester.pumpWidget(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsService()),
      Provider<FeedRepository>.value(value: repository),
    ],
    child: MaterialApp(
      home: Scaffold(body: FeedList(feedType: type)),
    ),
  ),
);

void main() {
  testWidgets('shows initial failure and retries', (tester) async {
    final repository = _FakeFeedRepository([
      const Failure<FeedPage>(NetworkFailure('Нет сети')),
      Success(FeedPage.empty),
    ]);

    await pumpFeed(tester, repository: repository, type: FeedType.fresh);
    await tester.pumpAndSettle();

    expect(find.text('Нет сети'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Нет постов'), findsOneWidget);
  });

  testWidgets('personal feed does not request data while logged out', (
    tester,
  ) async {
    final repository = _FakeFeedRepository([Success(FeedPage.empty)]);

    await pumpFeed(tester, repository: repository, type: FeedType.personal);
    await tester.pumpAndSettle();

    expect(repository.calls, 0);
    expect(
      find.text('Войди в аккаунт, чтобы видеть свою ленту'),
      findsOneWidget,
    );
  });
}
