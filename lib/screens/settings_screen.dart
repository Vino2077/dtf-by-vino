import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor:
          settings.blackTheme ? AppColors.blackBg : AppColors.bgDeep,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Настройки'),
      ),
      body: ListView(
        children: [
          _section(context, 'Внешний вид'),
          _accentColorTile(context, settings),
          _BgImageTile(settings: settings),
          _toggle(
            context,
            'Чёрная тема (AMOLED)',
            'Полностью чёрный фон — глубже смотрится и экономит батарею на OLED',
            settings.blackTheme,
            (v) => settings.setBlackTheme(v),
          ),
          _section(context, 'Комментарии'),
          _toggle(
            context,
            'Показывать удалённые комментарии',
            'Удалённые комменты будут видны со специальной пометкой',
            settings.showDeletedComments,
            (v) => settings.setShowDeletedComments(v),
          ),
          _toggle(
            context,
            'Автоматически раскрывать комментарии',
            'Основные ветки раскрываются при открытии поста',
            settings.autoExpandComments,
            (v) => settings.setAutoExpandComments(v),
          ),
          _section(context, 'Лента'),
          _toggle(
            context,
            'Автосворачивать просмотренные посты',
            'Посты, которые ты уже открывал, будут свёрнуты в ленте',
            settings.autoCollapseViewed,
            (v) => settings.setAutoCollapseViewed(v),
          ),
          _batchSizeTile(context, settings),
          _section(context, 'Фильтры'),
          _filterKeywordsTile(context, settings),
          _section(context, 'Заметки о пользователях'),
          _userNotesTile(context, settings),
          _section(context, 'Кеш'),
          const _CacheTile(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1),
      ),
    );
  }

  Widget _toggle(BuildContext context, String title, String subtitle,
      bool value, void Function(bool) onChanged) {
    final black = context.select<SettingsService, bool>((s) => s.blackTheme);
    return Container(
      color: black ? AppColors.blackCard : AppColors.bgCard,
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _accentColorTile(BuildContext context, SettingsService settings) {
    final accent = settings.accentColor;
    const defaultAccent = Color(0xFF4FC3F7);
    final isDefault = accent.toARGB32() == defaultAccent.toARGB32();

    return Container(
      color: AppColors.bgCard,
      child: ListTile(
        title: const Text('Цвет акцента',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: const Text('Кнопки, ссылки, активные элементы',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDefault)
              GestureDetector(
                onTap: () => settings.resetAccentColor(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.refresh, color: AppColors.textMuted, size: 20),
                ),
              ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
            ),
          ],
        ),
        onTap: () => _showColorPicker(context, settings),
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsService settings) {
    Color current = settings.accentColor;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Цвет акцента'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: current,
              onColorChanged: (c) => setState(() => current = c),
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                settings.setAccentColor(current);
                Navigator.pop(ctx);
              },
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchSizeTile(BuildContext context, SettingsService settings) {
    return Container(
      color: AppColors.bgCard,
      child: ListTile(
        title: const Text('Постов за раз',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: const Text('Сколько постов загружается при прокрутке',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: DropdownButton<int>(
          value: settings.batchSize,
          dropdownColor: AppColors.bgElevated,
          style: const TextStyle(color: AppColors.textPrimary),
          underline: const SizedBox(),
          items: [15, 20, 30, 50]
              .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
              .toList(),
          onChanged: (v) {
            if (v != null) settings.setBatchSize(v);
          },
        ),
      ),
    );
  }

  Widget _filterKeywordsTile(BuildContext context, SettingsService settings) {
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Скрыть по ключевым словам',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Посты с этими словами не появятся в ленте',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _addKeywordDialog(context, settings),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить', style: TextStyle(fontSize: 13)),
            ),
          ]),
          if (settings.filterKeywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: settings.filterKeywords
                  .map((kw) => Chip(
                        label: Text(kw,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13)),
                        backgroundColor: AppColors.bgElevated,
                        deleteIcon:
                            const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                        onDeleted: () => settings.removeFilterKeyword(kw),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _userNotesTile(BuildContext context, SettingsService settings) {
    if (settings.userNotes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          'Пока пусто. Добавить заметку можно через меню в посте или комментарии.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }
    return Container(
      color: AppColors.bgCard,
      child: Column(
        children: settings.userNotes.entries
            .map((e) => ListTile(
                  title: Text('ID ${e.key}',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: Text(e.value,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => settings.setUserNote(e.key, ''),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _addKeywordDialog(BuildContext context, SettingsService settings) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить фильтр'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Ключевое слово...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              settings.addFilterKeyword(ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _BgImageTile extends StatefulWidget {
  final SettingsService settings;
  const _BgImageTile({required this.settings});

  @override
  State<_BgImageTile> createState() => _BgImageTileState();
}

class _BgImageTileState extends State<_BgImageTile> {
  bool _picking = false;

  SettingsService get s => widget.settings;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Фон работает только на Android-устройстве')),
          );
        }
        return;
      }
      // Copy to documents so path persists after app restarts
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/app_background.jpg');
      await File(picked.path).copy(dest.path);
      await s.setBgImagePath(dest.path);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _remove() async {
    await s.setBgImagePath(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasBg = s.bgImagePath != null && !kIsWeb && File(s.bgImagePath!).existsSync();
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      color: AppColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('Фон приложения',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            subtitle: Text(
              hasBg
                  ? 'Своя картинка установлена'
                  : 'Выбери фото из галереи как фон',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasBg)
                  GestureDetector(
                    onTap: _remove,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.delete_outline,
                          color: Colors.red, size: 22),
                    ),
                  ),
                _picking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        hasBg
                            ? Icons.image_outlined
                            : Icons.add_photo_alternate_outlined,
                        color: accent,
                        size: 26,
                      ),
              ],
            ),
            onTap: _picking ? null : _pick,
          ),
          // Preview strip + sliders — only when image is set
          if (hasBg) ...[
            // Thumbnail preview
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(s.bgImagePath!),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Blur slider
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(children: [
                const Icon(Icons.blur_on_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Размытие',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: s.bgBlur,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    label: s.bgBlur.toStringAsFixed(0),
                    onChanged: (v) => s.setBgBlur(v),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    s.bgBlur.toStringAsFixed(0),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            ),
            // Dim slider
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                const Icon(Icons.brightness_4_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Затемнение',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                Expanded(
                  child: Slider(
                    value: s.bgDim,
                    min: 0,
                    max: 0.85,
                    divisions: 17,
                    label: '${(s.bgDim * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => s.setBgDim(v),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(s.bgDim * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _CacheTile extends StatefulWidget {
  const _CacheTile();

  @override
  State<_CacheTile> createState() => _CacheTileState();
}

class _CacheTileState extends State<_CacheTile> {
  String _size = '…';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _calcSize();
  }

  Future<void> _calcSize() async {
    try {
      final tmp = await getTemporaryDirectory();
      int total = 0;
      if (tmp.existsSync()) {
        await for (final e in tmp.list(recursive: true, followLinks: false)) {
          if (e is File) {
            try {
              total += await e.length();
            } catch (_) {}
          }
        }
      }
      if (mounted) setState(() => _size = _fmt(total));
    } catch (_) {
      if (mounted) setState(() => _size = '—');
    }
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      final tmp = await getTemporaryDirectory();
      if (tmp.existsSync()) {
        await for (final e in tmp.list()) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _size = '…';
    });
    _calcSize();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Кеш очищен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgCard,
      child: ListTile(
        title: const Text('Очистить кеш',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: Text('Кешированные картинки, гифки и медиа · $_size',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: _clearing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.primary),
        onTap: _clearing ? null : _clear,
      ),
    );
  }
}
