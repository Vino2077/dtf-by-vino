import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../api/dtf_api.dart';
import '../services/settings_service.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Block model
// ---------------------------------------------------------------------------

enum _BType { text, header, quote, list, delimiter, audio, media }

class _Block {
  final String id;
  _BType type;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  // header
  String headerStyle = 'h2';
  // list: each item is a separate controller + focusnode
  final List<TextEditingController> listCtrls;
  final List<FocusNode> listFoci;
  // audio
  dynamic audioData;
  final TextEditingController audioTitleCtrl;
  // media
  final List<dynamic> mediaItems;

  _Block(this.type)
      : id = '${type.index}_${DateTime.now().microsecondsSinceEpoch}',
        ctrl = TextEditingController(),
        focusNode = FocusNode(),
        listCtrls = [TextEditingController()],
        listFoci = [FocusNode()],
        audioTitleCtrl = TextEditingController(),
        mediaItems = [];

  void dispose() {
    ctrl.dispose();
    focusNode.dispose();
    for (final c in listCtrls) { c.dispose(); }
    for (final f in listFoci) { f.dispose(); }
    audioTitleCtrl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Editor screen
// ---------------------------------------------------------------------------

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final List<_Block> _blocks = [];
  int _focused = -1;
  bool _reorderMode = false;
  bool _nsfw = false;
  bool _publishing = false;
  List<dynamic> _subsites = [];
  dynamic _subsite;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _addBlock(_BType.text, 0);
    _loadSubsites();
    _titleFocus.addListener(() {
      if (_titleFocus.hasFocus) setState(() => _focused = -1);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    for (final b in _blocks) { b.dispose(); }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Block management
  // ---------------------------------------------------------------------------

  _Block _addBlock(_BType type, int index) {
    final b = _Block(type);
    _blocks.insert(index, b);
    b.focusNode.addListener(() {
      if (b.focusNode.hasFocus) {
        final i = _blocks.indexOf(b);
        if (i >= 0) setState(() => _focused = i);
      }
    });
    for (final f in b.listFoci) {
      f.addListener(() {
        if (f.hasFocus) {
          final i = _blocks.indexOf(b);
          if (i >= 0) setState(() => _focused = i);
        }
      });
    }
    return b;
  }

  void _insertBlock(_BType type, {int? afterIndex}) {
    final idx = afterIndex != null
        ? (afterIndex + 1).clamp(0, _blocks.length)
        : _blocks.length;
    _addBlock(type, idx);
    setState(() => _focused = idx);
  }

  void _deleteBlock(int index) {
    if (_blocks.length <= 1) {
      _blocks[0].ctrl.clear();
      return;
    }
    final b = _blocks[index];
    b.dispose();
    _blocks.removeAt(index);
    final newFocus = (index - 1).clamp(0, _blocks.length - 1);
    setState(() => _focused = newFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newFocus >= 0 && newFocus < _blocks.length) {
        _blocks[newFocus].focusNode.requestFocus();
      }
    });
  }

  void _convertBlock(_BType type, {String? headerStyle}) {
    if (_focused < 0 || _focused >= _blocks.length) return;
    final old = _blocks[_focused];
    if (old.type == type && (headerStyle == null || old.headerStyle == headerStyle)) {
      return;
    }
    final text = old.ctrl.text;
    final b = _Block(type);
    b.ctrl.text = text;
    b.focusNode.addListener(() {
      if (b.focusNode.hasFocus) setState(() => _focused = _blocks.indexOf(b));
    });
    if (type == _BType.header && headerStyle != null) b.headerStyle = headerStyle;
    if (type == _BType.list && text.isNotEmpty) {
      b.listCtrls[0].text = text;
      b.ctrl.clear();
    }
    old.dispose();
    _blocks[_focused] = b;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => b.focusNode.requestFocus());
  }

  void _onTextEnter(int blockIndex) {
    final idx = blockIndex + 1;
    final b = _addBlock(_BType.text, idx);
    setState(() => _focused = idx);
    WidgetsBinding.instance.addPostFrameCallback((_) => b.focusNode.requestFocus());
  }

  // ---------------------------------------------------------------------------
  // List block helpers
  // ---------------------------------------------------------------------------

  void _addListItem(_Block block, int afterItemIndex) {
    final ctrl = TextEditingController();
    final focus = FocusNode();
    focus.addListener(() {
      if (focus.hasFocus) {
        final i = _blocks.indexOf(block);
        if (i >= 0) setState(() => _focused = i);
      }
    });
    setState(() {
      block.listCtrls.insert(afterItemIndex + 1, ctrl);
      block.listFoci.insert(afterItemIndex + 1, focus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  void _removeListItem(_Block block, int itemIndex) {
    if (block.listCtrls.length <= 1) return;
    block.listCtrls[itemIndex].dispose();
    block.listFoci[itemIndex].dispose();
    setState(() {
      block.listCtrls.removeAt(itemIndex);
      block.listFoci.removeAt(itemIndex);
    });
    if (itemIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.listFoci[itemIndex - 1].requestFocus();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Media & Audio
  // ---------------------------------------------------------------------------

  Future<void> _pickMedia(int blockIndex) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.textPrimary),
            title: const Text('Фото', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: AppColors.textPrimary),
            title: const Text('Видео', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null || !mounted) return;

    final file = choice == 'photo'
        ? await _picker.pickImage(source: ImageSource.gallery)
        : await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final settings = context.read<SettingsService>();
    final uploaded = await DtfApi.uploadMediaFile(file.path, settings);
    if (!mounted || uploaded == null) return;

    setState(() {
      _blocks[blockIndex].mediaItems.add({
        'title': '',
        'author': '',
        'image': uploaded,
      });
    });
  }

  Future<void> _onToolbarMedia() async {
    if (_focused >= 0 && _focused < _blocks.length && _blocks[_focused].type == _BType.media) {
      await _pickMedia(_focused);
    } else {
      final idx = _focused >= 0 ? _focused + 1 : _blocks.length;
      _addBlock(_BType.media, idx);
      setState(() => _focused = idx);
      await _pickMedia(idx);
    }
  }

  Future<void> _onToolbarAudio() async {
    // Audio via URL (file_picker has AGP 9 build issues; URL upload works universally)
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Аудио по ссылке', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: urlCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlCtrl.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    urlCtrl.dispose();
    if (url == null || url.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Загружаю аудио...')));
    final settings = context.read<SettingsService>();
    final uploaded = await DtfApi.extractMediaByUrl(url, settings);
    if (!mounted) return;
    if (uploaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить аудио по ссылке')));
      return;
    }

    final idx = _focused >= 0 ? _focused + 1 : _blocks.length;
    final b = _addBlock(_BType.audio, idx);
    b.audioData = uploaded;
    b.audioTitleCtrl.text = '';
    setState(() => _focused = idx);
  }

  // ---------------------------------------------------------------------------
  // Subsites
  // ---------------------------------------------------------------------------

  Future<void> _loadSubsites() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) return;
    final list = await DtfApi.getMySubsites(settings);
    if (mounted) setState(() => _subsites = list);
  }

  // ---------------------------------------------------------------------------
  // Publish
  // ---------------------------------------------------------------------------

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Добавь заголовок поста')));
      return;
    }
    final settings = context.read<SettingsService>();
    final subsite = _subsite ?? (_subsites.isNotEmpty ? _subsites.first : null);
    if (subsite == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нет доступных подсайтов')));
      return;
    }
    setState(() => _publishing = true);
    final result = await DtfApi.createEntry(
      title: title,
      blocks: _buildBlocksJson(),
      subsiteId: subsite['id'] as int,
      isPublished: true,
      isNsfw: _nsfw,
      settings: settings,
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (result['ok'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Пост опубликован!')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result['error'] ?? 'Ошибка')));
    }
  }

  List<Map<String, dynamic>> _buildBlocksJson() {
    final out = <Map<String, dynamic>>[];
    for (final b in _blocks) {
      switch (b.type) {
        case _BType.text:
          final t = b.ctrl.text.trim();
          if (t.isNotEmpty) {
            out.add({'type': 'text', 'data': {'text': '<p>$t</p>'}});
          }
        case _BType.header:
          final t = b.ctrl.text.trim();
          if (t.isNotEmpty) {
            out.add({'type': 'header', 'data': {'text': t, 'style': b.headerStyle}});
          }
        case _BType.quote:
          // QuoteBlockDto = {text, subline1} (NOT "author" — the server drops
          // the block otherwise, which is why quotes never saved).
          final t = b.ctrl.text.trim();
          if (t.isNotEmpty) {
            out.add({'type': 'quote', 'data': {'text': t, 'subline1': ''}});
          }
        case _BType.list:
          final items = b.listCtrls
              .map((c) => c.text.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (items.isNotEmpty) {
            out.add({'type': 'list', 'data': {'type': 'UL', 'items': items}});
          }
        case _BType.delimiter:
          // DividerBlockDto = {type}; empty {} made the server reject it.
          out.add({'type': 'delimiter', 'data': {'type': 'default'}});
        case _BType.audio:
          // AudioBlockDto = {title, hash, audio}.
          if (b.audioData != null) {
            out.add({'type': 'audio', 'data': {
              'title': b.audioTitleCtrl.text.trim(),
              'hash': '',
              'audio': b.audioData,
            }});
          }
        case _BType.media:
          // MediaItemBlockDto = {title, image}; strip the extra 'author' key.
          if (b.mediaItems.isNotEmpty) {
            out.add({'type': 'media', 'data': {
              'items': b.mediaItems
                  .map((m) => {'title': m['title'] ?? '', 'image': m['image']})
                  .toList(),
            }});
          }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: _buildAppBar(accent),
      body: Column(children: [
        Expanded(child: _reorderMode ? _buildReorderList(accent) : _buildScrollList(accent)),
        _buildToolbar(accent),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0
            ? 0
            : MediaQuery.of(context).padding.bottom),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar(Color accent) {
    final name = _subsite?['name'] ??
        (_subsites.isNotEmpty ? _subsites.first['name'] : 'Мой профиль');
    return AppBar(
      backgroundColor: AppColors.bgCard,
      elevation: 0,
      leading: const BackButton(color: AppColors.textPrimary),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: _showSubsiteSelector,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
        ]),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onPressed: _showMoreMenu,
        ),
        _publishing
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                icon: Icon(Icons.arrow_upward, color: accent),
                onPressed: _publish,
              ),
      ],
    );
  }

  Widget _buildScrollList(Color accent) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _buildTitleField()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _buildBlockRow(_blocks[i], i, accent),
            childCount: _blocks.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildReorderList(Color accent) {
    return ReorderableListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 100),
      header: _buildTitleField(),
      itemCount: _blocks.length,
      itemBuilder: (_, i) => _buildBlockRow(_blocks[i], i, accent, key: ValueKey(_blocks[i].id)),
      onReorderItem: (oldIdx, newIdx) {
        setState(() {
          final b = _blocks.removeAt(oldIdx);
          _blocks.insert(newIdx, b);
          _focused = newIdx;
        });
      },
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: TextField(
        controller: _titleCtrl,
        focusNode: _titleFocus,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Заголовок',
          hintStyle: TextStyle(
              color: AppColors.textMuted, fontSize: 24, fontWeight: FontWeight.bold),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  Widget _buildBlockRow(_Block block, int index, Color accent, {Key? key}) {
    final isFocused = index == _focused;
    Widget content;
    switch (block.type) {
      case _BType.text:
        content = _buildTextBlock(block, index);
      case _BType.header:
        content = _buildHeaderBlock(block, index, accent);
      case _BType.quote:
        content = _buildQuoteBlock(block, index, accent);
      case _BType.list:
        content = _buildListBlock(block, index, accent);
      case _BType.delimiter:
        content = _buildDelimiterBlock(index);
      case _BType.audio:
        content = _buildAudioBlock(block, index);
      case _BType.media:
        content = _buildMediaBlock(block, index, accent);
    }

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: content),
          if (_reorderMode)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 10),
              child: Icon(Icons.drag_handle, size: 20, color: AppColors.textMuted),
            )
          else if (isFocused)
            GestureDetector(
              onTap: () => _deleteBlock(index),
              child: const Padding(
                padding: EdgeInsets.only(left: 8, top: 10),
                child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Block widgets
  // ---------------------------------------------------------------------------

  Widget _buildTextBlock(_Block block, int index) {
    return TextField(
      controller: block.ctrl,
      focusNode: block.focusNode,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.55),
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Текст...',
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 6),
      ),
      onChanged: (v) {
        if (v.endsWith('\n')) {
          block.ctrl.value = TextEditingValue(
            text: v.substring(0, v.length - 1),
            selection: TextSelection.collapsed(offset: v.length - 1),
          );
          _onTextEnter(index);
        }
      },
    );
  }

  Widget _buildHeaderBlock(_Block block, int index, Color accent) {
    final isH2 = block.headerStyle == 'h2';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Row(children: [
        _styleChip('H2', selected: isH2, accent: accent, onTap: () => setState(() => block.headerStyle = 'h2')),
        const SizedBox(width: 4),
        _styleChip('H3', selected: !isH2, accent: accent, onTap: () => setState(() => block.headerStyle = 'h3')),
      ]),
      const SizedBox(height: 4),
      TextField(
        controller: block.ctrl,
        focusNode: block.focusNode,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: isH2 ? 21 : 18,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: isH2 ? 'Заголовок H2' : 'Заголовок H3',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        onChanged: (v) {
          if (v.endsWith('\n')) {
            block.ctrl.value = TextEditingValue(
              text: v.substring(0, v.length - 1),
              selection: TextSelection.collapsed(offset: v.length - 1),
            );
            _onTextEnter(index);
          }
        },
      ),
    ]);
  }

  Widget _buildQuoteBlock(_Block block, int index, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: accent.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: TextField(
        controller: block.ctrl,
        focusNode: block.focusNode,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontStyle: FontStyle.italic,
          height: 1.5,
        ),
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Цитата...',
          hintStyle: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: (v) {
          if (v.endsWith('\n')) {
            block.ctrl.value = TextEditingValue(
              text: v.substring(0, v.length - 1),
              selection: TextSelection.collapsed(offset: v.length - 1),
            );
            _onTextEnter(index);
          }
        },
      ),
    );
  }

  Widget _buildListBlock(_Block block, int index, Color accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 4),
      for (int i = 0; i < block.listCtrls.length; i++)
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: TextField(
              controller: block.listCtrls[i],
              focusNode: block.listFoci[i],
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, height: 1.4),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Пункт ${i + 1}...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onSubmitted: (_) => _addListItem(block, i),
            ),
          ),
          if (block.listCtrls.length > 1)
            GestureDetector(
              onTap: () => _removeListItem(block, i),
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.remove_circle_outline, size: 16, color: AppColors.textMuted),
              ),
            ),
        ]),
      TextButton.icon(
        onPressed: () => _addListItem(block, block.listCtrls.length - 1),
        icon: const Icon(Icons.add, size: 15, color: AppColors.textMuted),
        label: const Text('Добавить пункт',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.only(left: 16),
          minimumSize: const Size(0, 32),
        ),
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildDelimiterBlock(int index) {
    return GestureDetector(
      onTap: () => setState(() => _focused = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(child: Divider(color: AppColors.bgElevated, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('* * *',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 14, letterSpacing: 5)),
          ),
          Expanded(child: Divider(color: AppColors.bgElevated, thickness: 1)),
        ]),
      ),
    );
  }

  Widget _buildAudioBlock(_Block block, int index) {
    return GestureDetector(
      onTap: () => setState(() => _focused = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.bgElevated),
        ),
        child: Row(children: [
          const Icon(Icons.audiotrack_outlined, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: block.audioData != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TextField(
                      controller: block.audioTitleCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Название аудио...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Text('Аудио прикреплено ✓',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ])
                : const Text('Загрузка аудио...',
                    style: TextStyle(color: AppColors.textMuted)),
          ),
        ]),
      ),
    );
  }

  Widget _buildMediaBlock(_Block block, int index, Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _focused = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: block.mediaItems.isEmpty
            ? GestureDetector(
                onTap: () => _pickMedia(index),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bgElevated),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.textMuted, size: 30),
                      const SizedBox(height: 6),
                      const Text('Добавить фото или видео',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                  ),
                ),
              )
            : SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: block.mediaItems.length + 1,
                  itemBuilder: (_, i) {
                    if (i == block.mediaItems.length) {
                      return GestureDetector(
                        onTap: () => _pickMedia(index),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bgElevated),
                          ),
                          child: const Center(
                            child: Icon(Icons.add, color: AppColors.textMuted, size: 28),
                          ),
                        ),
                      );
                    }
                    final item = block.mediaItems[i];
                    final uuid = item['image']?['data']?['uuid'] as String?;
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            image: uuid != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                        'https://leonardo.osnova.io/$uuid/-/scale_crop/200x200/center/'),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: uuid == null
                              ? const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => setState(() => block.mediaItems.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  Widget _buildToolbar(Color accent) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: const Border(top: BorderSide(color: AppColors.bgElevated)),
      ),
      child: Row(children: [
        _toolTxt('H2', onTap: () => _convertBlock(_BType.header, headerStyle: 'h2')),
        _toolTxt('H3', onTap: () => _convertBlock(_BType.header, headerStyle: 'h3')),
        _toolTxt('T', onTap: () => _convertBlock(_BType.text)),
        _toolIco(Icons.format_quote, onTap: () => _convertBlock(_BType.quote)),
        _toolIco(Icons.format_list_bulleted, onTap: () => _convertBlock(_BType.list)),
        _toolTxt('* * *', small: true, onTap: () {
          _insertBlock(_BType.delimiter, afterIndex: _focused >= 0 ? _focused : null);
        }),
        _toolIco(Icons.mic_none, onTap: _onToolbarAudio),
        _toolIco(Icons.image_outlined, onTap: _onToolbarMedia),
      ]),
    );
  }

  Widget _toolTxt(String label, {required VoidCallback onTap, bool small = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: small ? 11 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: small ? 2 : 0,
              )),
        ),
      ),
    );
  }

  Widget _toolIco(IconData icon, {required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(child: Icon(icon, size: 20, color: AppColors.textSecondary)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper widgets
  // ---------------------------------------------------------------------------

  Widget _styleChip(String label,
      {required bool selected, required Color accent, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? accent : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom sheets
  // ---------------------------------------------------------------------------

  void _showSubsiteSelector() {
    if (_subsites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Загрузка подсайтов...')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Опубликовать в',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          for (final s in _subsites)
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.textPrimary),
              title: Text(s['name'] ?? '',
                  style: const TextStyle(color: AppColors.textPrimary)),
              trailing: _subsite?['id'] == s['id']
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                setState(() => _subsite = s);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.eighteen_up_rating_outlined,
                  color: AppColors.textPrimary),
              title: const Text('18+', style: TextStyle(color: AppColors.textPrimary)),
              trailing: Switch(
                value: _nsfw,
                onChanged: (v) {
                  setState(() => _nsfw = v);
                  setS(() {});
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reorder, color: AppColors.textPrimary),
              title: Text(
                _reorderMode ? 'Выйти из режима перестановки' : 'Переставить блоки',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                setState(() => _reorderMode = !_reorderMode);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
