import '../../../api/api_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../../../util/json_safe.dart';
import 'post_repository.dart';

class DtfPostRepository implements PostRepository {
  const DtfPostRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<Post>> load(int postId) async {
    final result = await _apiClient.get('content?id=$postId');
    return switch (result) {
      Failure<Object?>(:final failure) => Failure<Post>(failure),
      Success<Object?>(:final value) => _parsePost(value),
    };
  }

  Result<Post> _parsePost(Object? value) {
    final postValue = value is Map && value['entry'] != null
        ? value['entry']
        : value;
    if (postValue is! Map) {
      return const Failure(ParsingFailure('Post response is invalid'));
    }
    try {
      return Success(Post.fromJson(asMap(postValue)));
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<void>> setFavorite(int postId, {required bool value}) async {
    final result = await _apiClient.postForm(
      value ? 'favorite' : 'unfavorite',
      body: {'id': '$postId', 'type': '1'},
    );
    return _voidResult(result);
  }

  @override
  Future<Result<void>> setReaction(int postId, int reactionId) async {
    final result = await _apiClient.postMultipart(
      'content/$postId/react',
      apiVersion: ApiConfig.vComments,
      fields: {'type': '$reactionId', 'referer': 'feed'},
    );
    return _voidResult(result);
  }

  Result<void> _voidResult(Result<Object?> result) => switch (result) {
    Failure<Object?>(:final failure) => Failure<void>(failure),
    Success<Object?>() => const Success<void>(null),
  };
}
