import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/chat/presentation/chat_controller.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';

/// Direct-message channel list (the "Чаты" tab).
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final ChatController _controller;
  List<Map<String, dynamic>> get _channels =>
      _controller.channels.map((channel) => channel.rawJson).toList();
  bool _loading = true;
  bool get _loadingMore => _controller.isLoadingMore;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = ChatController(context.read<ChatRepository>())
      ..addListener(_onChanged);
    _scroll.addListener(() {
      final pos = _scroll.position;
      if (pos.pixels > pos.maxScrollExtent - 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _controller.loadChannels(refresh: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() => _controller.loadChannels();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<SettingsService, bool>((s) => s.isLoggedIn);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Чаты'),
        backgroundColor: Colors.transparent,
      ),
      body: !loggedIn
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Войди в аккаунт, чтобы читать сообщения',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ),
            )
          : _loading
          ? Center(child: CircularProgressIndicator())
          : _channels.isEmpty
          ? Center(
              child: Text(
                'Пока нет диалогов',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 90,
                ),
                itemCount: _channels.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _channels.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _ChannelTile(
                    channel: _channels[i],
                    onTap: () => _openChat(_channels[i]),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _openChat(dynamic channel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(channel: channel)),
    );
    if (mounted) _load(); // refresh unread / last message on return
  }
}

class _ChannelTile extends StatelessWidget {
  final dynamic channel;
  final VoidCallback onTap;
  const _ChannelTile({required this.channel, required this.onTap});

  String _preview(BuildContext context) {
    final last = channel['lastMessage'];
    if (last is! Map) return '';
    final myId = context.read<SettingsService>().myUserId?.toString();
    final authorId = last['author']?['id']?.toString();
    final mine = myId != null && authorId == myId;
    var text = (last['text'] ?? '').toString().trim();
    if (text.isEmpty && last['media'] != null) text = '📷 Вложение';
    return mine ? 'Вы: $text' : text;
  }

  String _time() {
    final last = channel['lastMessage'];
    final ts = last is Map ? last['dtCreated'] : null;
    if (ts is! num) return '';
    final d = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0 && now.day == d.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
      return wd[d.weekday - 1];
    }
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final unread = (channel['unreadCount'] ?? 0) as int;
    final pending = channel['pendingAcceptance'] == true;
    final pic = channel['pictureData'];
    final animated = pic?['data']?['type'] == 'gif';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Avatar(uuid: pic?['data']?['uuid'], size: 54, animated: animated),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          channel['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _time(),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pending ? 'Запрос на переписку' : _preview(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: pending ? accent : AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
