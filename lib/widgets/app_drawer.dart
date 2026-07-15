import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/dtf_api.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../screens/editor_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/settings_screen.dart';
import 'avatar.dart';
import 'profile_navigation.dart';

/// Left navigation drawer (Figma "Main-Side"): search, quick actions,
/// the user's subscriptions with favorite stars, and a settings shortcut.
class AppDrawer extends StatefulWidget {
  /// Switches the main scaffold to the Search tab (search lives there).
  final VoidCallback onOpenSearch;
  const AppDrawer({super.key, required this.onOpenSearch});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<dynamic> _subs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSubs();
  }

  Future<void> _loadSubs() async {
    final settings = context.read<SettingsService>();
    final subs = await DtfApi.getMySubsites(settings);
    if (!mounted) return;
    setState(() {
      _subs = subs;
      _loading = false;
    });
  }

  /// Favorites first, then the rest — preserving API order within each group.
  List<dynamic> get _sortedSubs {
    final settings = context.read<SettingsService>();
    final fav = <dynamic>[];
    final rest = <dynamic>[];
    for (final s in _subs) {
      final id = s['id'] as int?;
      (id != null && settings.isFavoriteSubsite(id) ? fav : rest).add(s);
    }
    return [...fav, ...rest];
  }

  void _push(Widget screen) {
    Navigator.pop(context); // close drawer first
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Drawer(
      backgroundColor: AppColors.bgDeep,
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          // Search field → jumps to the Search tab.
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 4),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onOpenSearch();
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    SizedBox(width: 10),
                    Text('Поиск по DTF',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _DrawerAction(
            icon: Icons.edit_outlined,
            label: 'Написать пост',
            onTap: () => _push(const EditorScreen()),
          ),
          _DrawerAction(
            icon: Icons.bookmark_border,
            label: 'Закладки',
            onTap: () => _push(const BookmarksScreen()),
          ),
          _DrawerAction(
            icon: Icons.filter_alt_outlined,
            label: 'Фильтры',
            onTap: () => _push(const SettingsScreen()),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Подписки',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(child: _buildSubs(accent)),
          // Settings gear pinned bottom-left.
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 12),
              child: IconButton(
                icon: Icon(Icons.settings_outlined, color: accent, size: 26),
                onPressed: () => _push(const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubs(Color accent) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_subs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Войди в аккаунт, чтобы видеть свои подписки',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }
    // Rebuild when favorites change so the ordering / stars update.
    context.watch<SettingsService>();
    final subs = _sortedSubs;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: subs.length,
      itemBuilder: (_, i) => _SubTile(subsite: subs[i]),
    );
  }
}

class _DrawerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final dynamic subsite;
  const _SubTile({required this.subsite});

  @override
  Widget build(BuildContext context) {
    final id = subsite['id'] as int?;
    final settings = context.watch<SettingsService>();
    final fav = id != null && settings.isFavoriteSubsite(id);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        openUserProfile(context, subsite);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Avatar.fromData(subsite['avatar'], size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                subsite['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: Icon(
                fav ? Icons.star : Icons.star_border,
                color: fav ? const Color(0xFF6EBAF3) : AppColors.textMuted,
                size: 24,
              ),
              onPressed: id == null
                  ? null
                  : () => context.read<SettingsService>().toggleFavoriteSubsite(id),
            ),
          ],
        ),
      ),
    );
  }
}
