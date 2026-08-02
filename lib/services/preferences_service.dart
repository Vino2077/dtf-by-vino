import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/block.dart';
import '../models/post.dart';

class PreferencesService extends ChangeNotifier {
  PreferencesService(this._preferences);

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
  static const _kHideCompanyPosts = 'hide_company_posts';
  static const _kReactionUsage = 'reaction_usage';
  static const _kFavoriteSubsites = 'favorite_subsites';
  static const _kLightTheme = 'light_theme';
  static const _defaultAccent = 0xFF5B82F2;
  static const _defaultAccentLight = 0xFF6580EC;

  final SharedPreferences _preferences;

  bool showDeletedComments = true;
  bool autoCollapseViewed = false;
  bool autoExpandComments = true;
  bool blackTheme = false;
  bool lightTheme = false;
  bool hideCompanyPosts = false;
  List<String> filterKeywords = [];
  Map<int, String> userNotes = {};
  Set<int> viewedPostIds = {};
  Set<int> favoriteSubsites = {};
  Map<int, int> reactionUsage = {};
  int batchSize = 20;
  List<Map<String, dynamic>> recentGifs = [];

  int _accentColor = _defaultAccent;
  String? _bgImagePath;
  double _bgBlur = 10.0;
  double _bgDim = 0.45;

  String? get bgImagePath => _bgImagePath;
  double get bgBlur => _bgBlur;
  double get bgDim => _bgDim;
  Color get accentColor => Color(
        _accentColor == _defaultAccent && lightTheme
            ? _defaultAccentLight
            : _accentColor,
      );

  void initialize() {
    showDeletedComments = _preferences.getBool(_kShowDeleted) ?? true;
    autoCollapseViewed = _preferences.getBool(_kAutoCollapse) ?? false;
    autoExpandComments = _preferences.getBool(_kAutoExpandComments) ?? true;
    batchSize = _preferences.getInt(_kBatchSize) ?? 20;

    final keywords = _decodeList(_preferences.getString(_kFilterKeywords));
    filterKeywords = keywords.map((value) => value.toString()).toList();

    final notes = _decodeMap(_preferences.getString(_kUserNotes));
    userNotes = notes.map(
      (key, value) => MapEntry(int.parse(key.toString()), value.toString()),
    );

    viewedPostIds = _decodeList(
      _preferences.getString(_kViewedPosts),
    ).map((value) => int.parse(value.toString())).toSet();
    recentGifs = _decodeList(_preferences.getString(_kRecentGifs))
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();

    final usage = _decodeMap(_preferences.getString(_kReactionUsage));
    reactionUsage = usage.map(
      (key, value) =>
          MapEntry(int.parse(key.toString()), (value as num).toInt()),
    );
    favoriteSubsites = _decodeList(
      _preferences.getString(_kFavoriteSubsites),
    ).map((value) => int.parse(value.toString())).toSet();

    _accentColor = _preferences.getInt(_kAccentColor) ?? _defaultAccent;
    _bgImagePath = _preferences.getString(_kBgImagePath);
    _bgBlur = _preferences.getDouble(_kBgBlur) ?? 10.0;
    _bgDim = _preferences.getDouble(_kBgDim) ?? 0.45;
    blackTheme = _preferences.getBool(_kBlackTheme) ?? false;
    lightTheme = _preferences.getBool(_kLightTheme) ?? false;
    hideCompanyPosts = _preferences.getBool(_kHideCompanyPosts) ?? false;
  }

  List<dynamic> _decodeList(String? source) {
    if (source == null) return const [];
    try {
      final value = jsonDecode(source);
      return value is List ? value : const [];
    } catch (_) {
      return const [];
    }
  }

  Map<dynamic, dynamic> _decodeMap(String? source) {
    if (source == null) return const {};
    try {
      final value = jsonDecode(source);
      return value is Map ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> setBlackTheme(bool value) async {
    blackTheme = value;
    await _write(() => _preferences.setBool(_kBlackTheme, value));
  }

  Future<void> setLightTheme(bool value) async {
    lightTheme = value;
    await _write(() => _preferences.setBool(_kLightTheme, value));
  }

  Future<void> setHideCompanyPosts(bool value) async {
    hideCompanyPosts = value;
    await _write(() => _preferences.setBool(_kHideCompanyPosts, value));
  }

  Future<void> recordReactionUse(int reactionId) async {
    reactionUsage[reactionId] = (reactionUsage[reactionId] ?? 0) + 1;
    await _preferences.setString(
      _kReactionUsage,
      jsonEncode(
        reactionUsage.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color.toARGB32();
    await _write(() => _preferences.setInt(_kAccentColor, _accentColor));
  }

  Future<void> resetAccentColor() async {
    _accentColor = _defaultAccent;
    await _write(() => _preferences.setInt(_kAccentColor, _accentColor));
  }

  Future<void> setBgImagePath(String? path) async {
    _bgImagePath = path;
    if (path == null) {
      await _preferences.remove(_kBgImagePath);
    } else {
      await _preferences.setString(_kBgImagePath, path);
    }
    notifyListeners();
  }

  Future<void> setBgBlur(double value) async {
    _bgBlur = value;
    await _write(() => _preferences.setDouble(_kBgBlur, value));
  }

  Future<void> setBgDim(double value) async {
    _bgDim = value;
    await _write(() => _preferences.setDouble(_kBgDim, value));
  }

  Future<void> addRecentGif(Map<String, dynamic> gif) async {
    final id = gif['id'];
    recentGifs = [gif, ...recentGifs.where((item) => item['id'] != id)];
    if (recentGifs.length > 100) recentGifs = recentGifs.sublist(0, 100);
    await _write(
      () => _preferences.setString(_kRecentGifs, jsonEncode(recentGifs)),
    );
  }

  Future<void> setShowDeletedComments(bool value) async {
    showDeletedComments = value;
    await _write(() => _preferences.setBool(_kShowDeleted, value));
  }

  Future<void> setAutoCollapseViewed(bool value) async {
    autoCollapseViewed = value;
    await _write(() => _preferences.setBool(_kAutoCollapse, value));
  }

  Future<void> setAutoExpandComments(bool value) async {
    autoExpandComments = value;
    await _write(() => _preferences.setBool(_kAutoExpandComments, value));
  }

  Future<void> setBatchSize(int value) async {
    batchSize = value;
    await _write(() => _preferences.setInt(_kBatchSize, value));
  }

  Future<void> addFilterKeyword(String keyword) async {
    final value = keyword.trim().toLowerCase();
    if (value.isEmpty || filterKeywords.contains(value)) return;
    filterKeywords = [...filterKeywords, value];
    await _write(
      () =>
          _preferences.setString(_kFilterKeywords, jsonEncode(filterKeywords)),
    );
  }

  Future<void> removeFilterKeyword(String keyword) async {
    filterKeywords = filterKeywords.where((value) => value != keyword).toList();
    await _write(
      () =>
          _preferences.setString(_kFilterKeywords, jsonEncode(filterKeywords)),
    );
  }

  Future<void> setUserNote(int userId, String note) async {
    if (note.trim().isEmpty) {
      userNotes = Map.from(userNotes)..remove(userId);
    } else {
      userNotes = {...userNotes, userId: note.trim()};
    }
    final value = userNotes.map((key, note) => MapEntry(key.toString(), note));
    await _write(() => _preferences.setString(_kUserNotes, jsonEncode(value)));
  }

  bool isFavoriteSubsite(int id) => favoriteSubsites.contains(id);

  Future<void> toggleFavoriteSubsite(int id) async {
    if (favoriteSubsites.contains(id)) {
      favoriteSubsites = {...favoriteSubsites}..remove(id);
    } else {
      favoriteSubsites = {...favoriteSubsites, id};
    }
    await _write(
      () => _preferences.setString(
        _kFavoriteSubsites,
        jsonEncode(favoriteSubsites.toList()),
      ),
    );
  }

  Future<void> markViewed(int postId) async {
    if (viewedPostIds.contains(postId)) return;
    viewedPostIds = {...viewedPostIds, postId};
    if (viewedPostIds.length > 1000) {
      viewedPostIds = viewedPostIds.skip(500).toSet();
    }
    await _write(
      () => _preferences.setString(
        _kViewedPosts,
        jsonEncode(viewedPostIds.toList()),
      ),
    );
  }

  bool isFiltered(Post post) {
    if (hideCompanyPosts && post.author?.rawJson['isCompany'] == true) {
      return true;
    }
    if (filterKeywords.isEmpty) return false;
    final title = post.title.toLowerCase();
    final text = post.blocks
        .whereType<TextBlock>()
        .map((block) => block.html)
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'<[^>]*>'), '');
    final content = '$title $text';
    return filterKeywords.any(content.contains);
  }

  Future<void> _write(Future<bool> Function() operation) async {
    await operation();
    notifyListeners();
  }
}
