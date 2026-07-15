import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api/dtf_api.dart';
import 'services/settings_service.dart';
import 'services/reactions_registry.dart';
import 'theme.dart';
import 'widgets/inactivity_detector.dart';
import 'widgets/app_drawer.dart';
import 'screens/feed_screen.dart';
import 'screens/search_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  final settings = await SettingsService.load();
  ReactionsRegistry.refresh();
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const DtfApp(),
    ),
  );
}

class DtfApp extends StatelessWidget {
  const DtfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select<SettingsService, Color>((s) => s.accentColor);
    return MaterialApp(
      title: 'DTF by Vino',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accentColor),
      home: const MainScreen(),
      builder: (context, child) =>
          InactivityDetector(child: child ?? const SizedBox()),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  Timer? _pollTimer;

  // Bottom-nav tab index that holds the notifications screen.
  static const _notificationsTab = 3;

  static const _screens = [
    FeedScreen(),
    SearchScreen(),
    ChatsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pollNotifications();
    _loadCurrentUser();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _pollNotifications());
  }

  Future<void> _loadCurrentUser() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) return;
    final me = await DtfApi.getMe(settings);
    if (mounted && me is Map) {
      settings.setCurrentUser(me['id'] as int?, me['isPlus'] == true);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollNotifications() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) return;
    if (_index == _notificationsTab) return;
    final count = await DtfApi.getNotificationsCount(settings);
    if (mounted) settings.setNotificationCount(count);
  }

  void _onTapTab(int i) {
    if (i == _notificationsTab) {
      context.read<SettingsService>().setNotificationCount(0);
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: Colors.transparent,
      drawerEdgeDragWidth: 60,
      drawer: AppDrawer(onOpenSearch: () => _onTapTab(1)),
      body: AppBackground(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: _BottomNav(index: _index, onTap: _onTapTab),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Главная'),
    (Icons.search, Icons.search, 'Поиск'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Чаты'),
    (Icons.notifications_none, Icons.notifications, 'Уведомления'),
    (Icons.person_outline, Icons.person, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(
            top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: bottomPad + 8),
      child: Row(
        children: [
          for (int i = 0; i < _items.length; i++)
            Expanded(
              child: _NavItem(
                icon: _items[i].$1,
                activeIcon: _items[i].$2,
                label: _items[i].$3,
                selected: index == i,
                accent: accent,
                showBadge: i == _MainScreenState._notificationsTab,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color accent;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : AppColors.textMuted;
    Widget iconWidget = Icon(selected ? activeIcon : icon, color: color, size: 24);

    if (showBadge) {
      final count =
          context.select<SettingsService, int>((s) => s.notificationCount);
      if (count > 0) {
        iconWidget = Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            Positioned(top: -5, right: -9, child: _NotificationBadge(count: count)),
          ],
        );
      }
    }

    return PressableScale(
      onTap: onTap,
      scale: 0.88,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red unread-count pill. Grows horizontally for 2+ digit counts; caps at 99+.
class _NotificationBadge extends StatelessWidget {
  final int count;
  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4.5),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.bgDeep, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
