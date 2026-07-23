import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import 'auth_service.dart';
import 'current_user_service.dart';
import 'notification_service.dart';
import 'preferences_service.dart';

export 'auth_service.dart' show AuthStorageException;

/// Compatibility facade while screens migrate to focused services.
class SettingsService extends ChangeNotifier {
  SettingsService._(
    this.auth,
    this.preferences,
    this.currentUser,
    this.notifications,
  ) {
    auth.addListener(_forwardChange);
    preferences.addListener(_forwardChange);
    currentUser.addListener(_forwardChange);
    notifications.addListener(_forwardChange);
  }

  final AuthService auth;
  final PreferencesService preferences;
  final CurrentUserService currentUser;
  final NotificationService notifications;

  static Future<SettingsService> load({
    SecureTokenStorage? secureTokenStorage,
    LegacyTokenStorage? legacyTokenStorage,
    SharedPreferences? sharedPreferences,
    bool? useLegacyTokenStorage,
  }) async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    final auth = AuthService(
      secureTokenStorage ??
          const FlutterSecureTokenStorage(FlutterSecureStorage()),
      legacyTokenStorage ?? SharedPreferencesTokenStorage(prefs),
      useLegacyTokenStorage ?? _useInsecureWebStorage,
    );
    final preferences = PreferencesService(prefs)..initialize();
    await auth.initialize();
    return SettingsService._(
      auth,
      preferences,
      CurrentUserService(),
      NotificationService(),
    );
  }

  /// Web Crypto is unavailable on a regular HTTP origin. Keep the legacy
  /// SharedPreferences behaviour only for that explicitly unsupported case.
  static bool get _useInsecureWebStorage {
    if (!kIsWeb || Uri.base.scheme != 'http') return false;
    final host = Uri.base.host.toLowerCase();
    return host != 'localhost' && host != '127.0.0.1' && host != '::1';
  }

  String? get token => auth.token;
  bool get isLoggedIn => auth.isLoggedIn;
  String? get authStorageError => auth.storageError;

  bool get showDeletedComments => preferences.showDeletedComments;
  bool get autoCollapseViewed => preferences.autoCollapseViewed;
  bool get autoExpandComments => preferences.autoExpandComments;
  bool get blackTheme => preferences.blackTheme;
  bool get lightTheme => preferences.lightTheme;
  bool get hideCompanyPosts => preferences.hideCompanyPosts;
  List<String> get filterKeywords => preferences.filterKeywords;
  Map<int, String> get userNotes => preferences.userNotes;
  Set<int> get viewedPostIds => preferences.viewedPostIds;
  Set<int> get favoriteSubsites => preferences.favoriteSubsites;
  Map<int, int> get reactionUsage => preferences.reactionUsage;
  int get batchSize => preferences.batchSize;
  List<Map<String, dynamic>> get recentGifs => preferences.recentGifs;
  String? get bgImagePath => preferences.bgImagePath;
  double get bgBlur => preferences.bgBlur;
  double get bgDim => preferences.bgDim;
  Color get accentColor => preferences.accentColor;

  int get notificationCount => notifications.unreadCount;
  int? get myUserId => currentUser.userId;
  bool get myIsPlus => currentUser.isPlus;

  Future<void> saveToken(String token) => auth.saveToken(token);

  Future<void> clearToken() async {
    await auth.clearToken();
    currentUser.clear();
    notifications.clear();
  }

  void setNotificationCount(int value) =>
      notifications.updateUnreadCount(value);

  void setCurrentUser(int? id, bool isPlus) => currentUser.update(id, isPlus);

  Future<void> setBlackTheme(bool value) => preferences.setBlackTheme(value);

  Future<void> setLightTheme(bool value) => preferences.setLightTheme(value);

  Future<void> setHideCompanyPosts(bool value) =>
      preferences.setHideCompanyPosts(value);

  Future<void> recordReactionUse(int reactionId) =>
      preferences.recordReactionUse(reactionId);

  Future<void> setAccentColor(Color color) => preferences.setAccentColor(color);

  Future<void> resetAccentColor() => preferences.resetAccentColor();

  Future<void> setBgImagePath(String? path) => preferences.setBgImagePath(path);

  Future<void> setBgBlur(double value) => preferences.setBgBlur(value);

  Future<void> setBgDim(double value) => preferences.setBgDim(value);

  Future<void> addRecentGif(Map<String, dynamic> gif) =>
      preferences.addRecentGif(gif);

  Future<void> setShowDeletedComments(bool value) =>
      preferences.setShowDeletedComments(value);

  Future<void> setAutoCollapseViewed(bool value) =>
      preferences.setAutoCollapseViewed(value);

  Future<void> setAutoExpandComments(bool value) =>
      preferences.setAutoExpandComments(value);

  Future<void> setBatchSize(int value) => preferences.setBatchSize(value);

  Future<void> addFilterKeyword(String keyword) =>
      preferences.addFilterKeyword(keyword);

  Future<void> removeFilterKeyword(String keyword) =>
      preferences.removeFilterKeyword(keyword);

  Future<void> setUserNote(int userId, String note) =>
      preferences.setUserNote(userId, note);

  bool isFavoriteSubsite(int id) => preferences.isFavoriteSubsite(id);

  Future<void> toggleFavoriteSubsite(int id) =>
      preferences.toggleFavoriteSubsite(id);

  Future<void> markViewed(int postId) => preferences.markViewed(postId);

  bool isFiltered(Post post) => preferences.isFiltered(post);

  void _forwardChange() => notifyListeners();

  @override
  void dispose() {
    auth.removeListener(_forwardChange);
    preferences.removeListener(_forwardChange);
    currentUser.removeListener(_forwardChange);
    notifications.removeListener(_forwardChange);
    auth.dispose();
    preferences.dispose();
    currentUser.dispose();
    notifications.dispose();
    super.dispose();
  }
}
