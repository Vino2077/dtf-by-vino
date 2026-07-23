import '../../../core/api/result.dart';
import '../../../models/post.dart';
import '../../../models/subsite.dart';

abstract interface class EditorRepository {
  Future<Result<Map<String, dynamic>>> extractMedia(String url);
  Future<Result<Map<String, dynamic>>> uploadMedia(String filePath);
  Future<Result<List<Subsite>>> loadMySubsites();
  Future<Result<List<Post>>> loadDrafts();
  Future<Result<int>> save({
    required String title,
    required List<Map<String, dynamic>> blocks,
    required int subsiteId,
    required bool publish,
    required bool isNsfw,
  });
}
