import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';

/// Opens a user/subsite profile if the author has a valid id.
/// `author` is the raw author/subsite map from the API.
void openUserProfile(BuildContext context, dynamic author) {
  if (author == null) return;
  final id = author['id'] as int?;
  if (id == null || id <= 0) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => UserProfileScreen(
        subsiteId: id,
        initialName: author['name'] as String?,
        initialAvatar: author['avatar']?['data']?['uuid'] as String?,
      ),
    ),
  );
}
