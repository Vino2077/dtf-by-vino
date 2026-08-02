import '../../../core/api/result.dart';
import '../../../models/channel.dart';
import '../../../models/message.dart';

abstract interface class ChatRepository {
  Future<Result<List<Channel>>> loadChannels({int page = 1});
  Future<Result<List<Message>>> loadMessages(
    int channelId, {
    String beforeTime = '0',
  });
  Future<Result<void>> markRead(int channelId);
  Future<Result<void>> send({
    required int channelId,
    required String text,
    String? replyToId,
  });
}
