import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageException implements Exception {
  final String message;
  const AuthStorageException(this.message);

  @override
  String toString() => message;
}

class SettingsService extends ChangeNotifier {
  static const _kToken = 'dtf_token';
  static const _kShowDeleted = 'show_deleted_comments';
  static const _kAutoCollapse = 'auto_collapse_viewed';
  static const _kFilterKeywords = 'filter_keywords';
  static const _kUserNotes = 'user_notes';
  static const _kViewedPosts = 'viewed_posts';
  static const _kBatchSize = 'batch_size';
  static const _kAutoExpandComments = 'auto_expand_comments';
  static const _kRecentGifs = 'recent_gifs';
  static const _kAccentColor = 'accent_color';
  static const _kBgImagePath = 'bg_image_path';
  static const _kBgBlur = 'bg_blur';
  static const _kBgDim = 'bg_dim';
  static const _kBlackTheme = 'black_theme';
  static const _kReactionUsage = 'reaction_usage';
  static const _kFavoriteSubsites = 'favorite_subsites';
  static const _kHideCompanyPosts = 'hide_company_posts';
  static const _secureStorage = FlutterSecureStorage();

  static const _defaultAccent = 0xFF5B82F2; // DTF blue (redesign accent)

  bool showDeletedComments = true;
  bool autoCollapseViewed = false;
  bool autoExpandComments = true;
  bool blackTheme = false;
  // Hide posts from company blogs (the black "✓" verified-company mark).
  bool hideCompanyPosts = false;
  List<String> filterKeywords = [];
  Map<int, String> userNotes = {};
  Set<int> viewedPostIds = {};
  // Subsite ids the user pinned as favorites in the drawer (starred → top).
  Set<int> favoriteSubsites = {};
  // How many times each reaction id has been used, for "most used first"
  // ordering in the reaction picker.
  Map<int, int> reactionUsage = {};
  int batchSize = 20;
  // Recently used GIFs (each is a stored GiphyGif json map), newest first, max 100.
  List<Map<String, dynamic>> recentGifs = [];
  int _accentColor = _defaultAccent;
  String? _bgImagePath;
  double _bgBlur = 10.0;
  double _bgDim = 0.45;
  String? _token;
  String? _authStorageError;

  String? get bgImagePath => _bgImagePath;
  double get bgBlur => _bgBlur;
  double get bgDim => _bgDim;

  Color get accentColor => Color(_accentColor);

  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  String? get authStorageError => _authStorageError;

  /// Web Crypto is unavailable on a regular HTTP origin. Keep the legacy
  /// SharedPreferences behaviour only for that explicitly unsupported case.
  static bool get _useInsecureWebStorage {
    if (!kIsWeb || Uri.base.scheme != 'http') return false;
    final host = Uri.base.host.toLowerCase();
    return host != 'localhost' && host != '127.0.0.1' && host != '::1';
  }

  // Unread-notification count for the bell badge. Polled from main.dart (kept
  // here so any widget can react via Provider without a separate service).
  int _notificationCount = 0;
  int get notificationCount => _notificationCount;
  void setNotificationCount(int n) {
    if (n == _notificationCount) return;
    _notificationCount = n;
    notifyListeners();
  }

  // Current user identity, fetched once from subsite/me (via main.dart). Used
  // to decide comment ownership and the edit window (Plus = 1h, else 1min).
  int? _myUserId;
  bool _myIsPlus = false;
  int? get myUserId => _myUserId;
  bool get myIsPlus => _myIsPlus;
  void setCurrentUser(int? id, bool isPlus) {
    if (id == _myUserId && isPlus == _myIsPlus) return;
    _myUserId = id;
    _myIsPlus = isPlus;
    notifyListeners();
  }

  static Future<SettingsService> load() async {
    final svc = SettingsService();
    await svc._init();
    return svc;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadToken(prefs);
    showDeletedComments = prefs.getBool(_kShowDeleted) ?? true;
    autoCollapseViewed = prefs.getBool(_kAutoCollapse) ?? false;
    autoExpandComments = prefs.getBool(_kAutoExpandComments) ?? true;
    batchSize = prefs.getInt(_kBatchSize) ?? 20;

    final kwJson = prefs.getString(_kFilterKeywords);
    if (kwJson != null) filterKeywords = List<String>.from(jsonDecode(kwJson));

    final notesJson = prefs.getString(_kUserNotes);
    if (notesJson != null) {
      final raw = jsonDecode(notesJson) as Map;
      userNotes = raw.map((k, v) => MapEntry(int.parse(k.toString()), v.toString()));
    }

    final viewedJson = prefs.getString(_kViewedPosts);
    if (viewedJson != null) {
      viewedPostIds = Set<int>.from((jsonDecode(viewedJson) as List).map((e) => int.parse(e.toString())));
    }

    final gifsJson = prefs.getString(_kRecentGifs);
    if (gifsJson != null) {
      recentGifs = (jsonDecode(gifsJson) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }

    final usageJson = prefs.getString(_kReactionUsage);
    if (usageJson != null) {
      final raw = jsonDecode(usageJson) as Map;
      reactionUsage = raw.map(
          (k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt()));
    }

    final favJson = prefs.getString(_kFavoriteSubsites);
    if (favJson != null) {
      favoriteSubsites = Set<int>.from(
          (jsonDecode(favJson) as List).map((e) => int.parse(e.toString())));
    }

    _accentColor = prefs.getInt(_kAccentColor) ?? _defaultAccent;
    _bgImagePath = prefs.getString(_kBgImagePath);
    _bgBlur = prefs.getDouble(_kBgBlur) ?? 10.0;
    _bgDim = prefs.getDouble(_kBgDim) ?? 0.45;
    blackTheme = prefs.getBool(_kBlackTheme) ?? false;
    hideCompanyPosts = prefs.getBool(_kHideCompanyPosts) ?? false;
  }

  Future<void> setBlackTheme(bool v) async {
    blackTheme = v;
    await _prefs((p) => p.setBool(_kBlackTheme, v));
  }

  Future<void> setHideCompanyPosts(bool v) async {
    hideCompanyPosts = v;
    await _prefs((p) => p.setBool(_kHideCompanyPosts, v));
  }

  /// Records that [reactionId] was used, so the picker can surface the user's
  /// favourites first. Fire-and-forget — no notifyListeners (nothing visible
  /// needs to rebuild immediately; the picker re-reads on next open).
  Future<void> recordReactionUse(int reactionId) async {
    reactionUsage[reactionId] = (reactionUsage[reactionId] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kReactionUsage,
        jsonEncode(
            reactionUsage.map((k, v) => MapEntry(k.toString(), v))));
  }

  Future<void> setAccentColor(Color c) async {
    _accentColor = c.toARGB32();
    await _prefs((p) => p.setInt(_kAccentColor, _accentColor));
  }

  Future<void> resetAccentColor() async {
    _accentColor = _defaultAccent;
    await _prefs((p) => p.setInt(_kAccentColor, _accentColor));
  }

  Future<void> setBgImagePath(String? path) async {
    _bgImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_kBgImagePath);
    } else {
      await prefs.setString(_kBgImagePath, path);
    }
    notifyListeners();
  }

  Future<void> setBgBlur(double v) async {
    _bgBlur = v;
    await _prefs((p) => p.setDouble(_kBgBlur, v));
  }

  Future<void> setBgDim(double v) async {
    _bgDim = v;
    await _prefs((p) => p.setDouble(_kBgDim, v));
  }

  Future<void> addRecentGif(Map<String, dynamic> gif) async {
    final id = gif['id'];
    // Move to front, dedupe, cap at 100.
    recentGifs = [gif, ...recentGifs.where((g) => g['id'] != id)];
    if (recentGifs.length > 100) recentGifs = recentGifs.sublist(0, 100);
    await _prefs((p) => p.setString(_kRecentGifs, jsonEncode(recentGifs)));
  }

  Future<void> _prefs(Future<void> Function(SharedPreferences) fn) async {
    final prefs = await SharedPreferences.getInstance();
    await fn(prefs);
    notifyListeners();
  }

  Future<void> _loadToken(SharedPreferences prefs) async {
    final legacyToken = prefs.getString(_kToken);

    if (_useInsecureWebStorage) {
      _token = legacyToken;
      return;
    }

    try {
      final secureToken = await _secureStorage.read(key: _kToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        _token = secureToken;
        if (legacyToken != null && !await prefs.remove(_kToken)) {
          _authStorageError =
              'Не удалось удалить старую небезопасную копию токена.';
        }
        return;
      }

      if (legacyToken == null || legacyToken.isEmpty) return;

      await _secureStorage.write(key: _kToken, value: legacyToken);
      if (!await prefs.remove(_kToken)) {
        // Do not silently accept a migration that left the plaintext copy.
        await _secureStorage.delete(key: _kToken);
        throw const AuthStorageException(
            'Не удалось завершить перенос токена в защищённое хранилище.');
      }
      _token = legacyToken;
    } catch (error) {
      _token = null;
      _authStorageError = error is AuthStorageException
          ? error.message
          : 'Защищённое хранилище авторизации недоступно.';
    }
  }

  Future<void> saveToken(String token) async {
    final currentToken = _token;
    try {
      if (_useInsecureWebStorage) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(_kToken, token)) {
          throw const AuthStorageException('Не удалось сохранить токен.');
        }
      } else {
        await _secureStorage.write(key: _kToken, value: token);
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(_kToken) && !await prefs.remove(_kToken)) {
          if (currentToken == null) {
            await _secureStorage.delete(key: _kToken);
          } else {
            await _secureStorage.write(key: _kToken, value: currentToken);
          }
          throw const AuthStorageException(
              'Не удалось удалить старую небезопасную копию токена.');
        }
      }
    } catch (error) {
      if (error is AuthStorageException) rethrow;
      throw const AuthStorageException(
          'Не удалось сохранить токен в защищённом хранилище.');
    }

    _token = token;
    _authStorageError = null;
    notifyListeners();
  }

  Future<void> clearToken() async {
    final currentToken = _token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_useInsecureWebStorage) {
        if (prefs.containsKey(_kToken) && !await prefs.remove(_kToken)) {
          throw const AuthStorageException('Не удалось удалить токен.');
        }
      } else {
        await _secureStorage.delete(key: _kToken);
        if (prefs.containsKey(_kToken) && !await prefs.remove(_kToken)) {
          // Avoid restoring a leftover legacy token on the next launch.
          if (currentToken != null) {
            await _secureStorage.write(key: _kToken, value: currentToken);
          }
          throw const AuthStorageException(
              'Не удалось удалить старую небезопасную копию токена.');
        }
      }
    } catch (error) {
      if (error is AuthStorageException) rethrow;
      throw const AuthStorageException(
          'Не удалось удалить токен из защищённого хранилища.');
    }

    _token = null;
    _authStorageError = null;
    notifyListeners();
  }

  Future<void> setShowDeletedComments(bool v) async {
    showDeletedComments = v;
    await _prefs((p) => p.setBool(_kShowDeleted, v));
  }

  Future<void> setAutoCollapseViewed(bool v) async {
    autoCollapseViewed = v;
    await _prefs((p) => p.setBool(_kAutoCollapse, v));
  }

  Future<void> setAutoExpandComments(bool v) async {
    autoExpandComments = v;
    await _prefs((p) => p.setBool(_kAutoExpandComments, v));
  }

  Future<void> setBatchSize(int v) async {
    batchSize = v;
    await _prefs((p) => p.setInt(_kBatchSize, v));
  }

  Future<void> addFilterKeyword(String kw) async {
    kw = kw.trim().toLowerCase();
    if (kw.isEmpty || filterKeywords.contains(kw)) return;
    filterKeywords = [...filterKeywords, kw];
    await _prefs((p) => p.setString(_kFilterKeywords, jsonEncode(filterKeywords)));
  }

  Future<void> removeFilterKeyword(String kw) async {
    filterKeywords = filterKeywords.where((k) => k != kw).toList();
    await _prefs((p) => p.setString(_kFilterKeywords, jsonEncode(filterKeywords)));
  }

  Future<void> setUserNote(int userId, String note) async {
    if (note.trim().isEmpty) {
      userNotes = Map.from(userNotes)..remove(userId);
    } else {
      userNotes = {...userNotes, userId: note.trim()};
    }
    final toSave = userNotes.map((k, v) => MapEntry(k.toString(), v));
    await _prefs((p) => p.setString(_kUserNotes, jsonEncode(toSave)));
  }

  bool isFavoriteSubsite(int id) => favoriteSubsites.contains(id);

  Future<void> toggleFavoriteSubsite(int id) async {
    if (favoriteSubsites.contains(id)) {
      favoriteSubsites = {...favoriteSubsites}..remove(id);
    } else {
      favoriteSubsites = {...favoriteSubsites, id};
    }
    await _prefs(
        (p) => p.setString(_kFavoriteSubsites, jsonEncode(favoriteSubsites.toList())));
  }

  Future<void> markViewed(int postId) async {
    if (viewedPostIds.contains(postId)) return;
    viewedPostIds = {...viewedPostIds, postId};
    if (viewedPostIds.length > 1000) {
      viewedPostIds = viewedPostIds.skip(500).toSet();
    }
    await _prefs((p) => p.setString(_kViewedPosts, jsonEncode(viewedPostIds.toList())));
  }

  bool isFiltered(dynamic post) {
    // Hide company-blog posts (black check-mark) when the user opted out.
    if (hideCompanyPosts && post['author']?['isCompany'] == true) return true;
    if (filterKeywords.isEmpty) return false;
    final title = (post['title'] ?? '').toString().toLowerCase();
    final blocks = post['blocks'] as List? ?? [];
    final text = blocks
        .where((b) => b['type'] == 'text')
        .map((b) => (b['data']?['text'] ?? '').toString())
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'<[^>]*>'), '');
    final content = '$title $text';
    return filterKeywords.any((kw) => content.contains(kw));
  }
}
