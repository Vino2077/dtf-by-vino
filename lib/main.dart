import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api/dtf_api.dart';
import 'services/settings_service.dart';
import 'services/reactions_registry.dart';
import 'theme.dart';
import 'widgets/inactivity_detector.dart';
import 'screens/feed_screen.dart';
import 'screens/search_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/editor_screen.dart';

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
    final black = context.select<SettingsService, bool>((s) => s.blackTheme);
    return MaterialApp(
      title: 'DTF by Vino',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(accentColor, black: black),
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
  int _index = 0;
  Timer? _pollTimer;

  static const _screens = [
    FeedScreen(),
    SearchScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pollNotifications();
    // Refresh the bell badge periodically while the app is open.
    _pollTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _pollNotifications());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollNotifications() async {
    final settings = context.read<SettingsService>();
    if (!settings.isLoggedIn) return;
    // Don't badge while the user is looking at the notifications tab.
    if (_index == 2) return;
    final count = await DtfApi.getNotificationsCount(settings);
    if (mounted) settings.setNotificationCount(count);
  }

  void _onTapTab(int i) {
    // Opening the notifications tab clears the badge (they're now seen).
    if (i == 2) context.read<SettingsService>().setNotificationCount(0);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: _GlassNavBar(
        index: _index,
        onTap: _onTapTab,
      ),
      floatingActionButton: _index == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditorScreen()),
                ),
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.edit_outlined, size: 22),
              ),
            )
          : null,
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _GlassNavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final black = context.select<SettingsService, bool>((s) => s.blackTheme);

    return SizedBox(
      height: bottomPad + 84,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 14),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            color: (black ? AppColors.blackCard : AppColors.bgCard)
                .withValues(alpha: 0.90),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Row(
                children: [
                  _item(context, 0, Icons.home_outlined, Icons.home, accent),
                  _item(context, 1, Icons.search, Icons.search, accent),
                  _item(context, 2, Icons.notifications_none,
                      Icons.notifications, accent),
                  _item(context, 3, Icons.account_circle_outlined,
                      Icons.account_circle, accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, IconData icon, IconData activeIcon,
      Color accent) {
    final selected = index == i;
    Widget iconWidget = Icon(
      selected ? activeIcon : icon,
      color: selected ? accent : AppColors.textMuted,
      size: 24,
    );

    // Bell (index 2) gets an unread-count badge.
    if (i == 2) {
      final count =
          context.select<SettingsService, int>((s) => s.notificationCount);
      if (count > 0) {
        iconWidget = Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            Positioned(
              top: -6,
              right: -9,
              child: _NotificationBadge(count: count),
            ),
          ],
        );
      }
    }

    return Expanded(
      child: PressableScale(
        onTap: () => onTap(i),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: iconWidget,
          ),
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
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.bgCard, width: 1.5),
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
