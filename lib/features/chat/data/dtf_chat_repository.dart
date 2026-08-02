import '../../../api/api_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/app_failure.dart';
import '../../../core/api/result.dart';
import '../../../models/channel.dart';
import '../../../models/message.dart';
import '../../../util/json_safe.dart';
import 'chat_repository.dart';

class DtfChatRepository implements ChatRepository {
  const DtfChatRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<Channel>>> loadChannels({int page = 1}) async => _list(
    await _api.get('m/channels?page=$page', apiVersion: ApiConfig.vMessenger),
    'channels',
    Channel.fromJson,
  );

  @override
  Future<Result<List<Message>>> loadMessages(
    int channelId, {
    String beforeTime = '0',
  }) async => _list(
    await _api.get(
      'm/messages?channelId=$channelId&beforeTime=$beforeTime',
      apiVersion: ApiConfig.vMessenger,
    ),
    'messages',
    Message.fromJson,
  );

  Result<List<T>> _list<T>(
    Result<Object?> result,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (result case Failure<Object?>(:final failure)) return Failure(failure);
    try {
      return Success(
        asList(
          dig((result as Success<Object?>).value, [key]),
        ).whereType<Map>().map((value) => parse(asMap(value))).toList(),
      );
    } on FormatException catch (error) {
      return Failure(ParsingFailure(error.message));
    }
  }

  @override
  Future<Result<void>> markRead(int channelId) async => _void(
    await _api.postForm(
      'm/markAsRead',
      apiVersion: ApiConfig.vMessenger,
      body: {'channelId': '$channelId'},
    ),
  );

  @override
  Future<Result<void>> send({
    required int channelId,
    required String text,
    String? replyToId,
  }) async {
    final body = <String, String>{
      'channelId': '$channelId',
      'text': text,
      'media': '[]',
      'idTmp': '${DateTime.now().microsecondsSinceEpoch % 1000000000}',
      'ts': (DateTime.now().millisecondsSinceEpoch / 1000).toStringAsFixed(3),
    };
    if (replyToId != null) body['replyToId'] = replyToId;
    return _void(
      await _api.postForm(
        'm/send',
        apiVersion: ApiConfig.vMessenger,
        body: body,
      ),
    );
  }

  Result<void> _void(Result<Object?> result) => switch (result) {
    Success<Object?>() => const Success(null),
    Failure<Object?>(:final failure) => Failure(failure),
  };
}
