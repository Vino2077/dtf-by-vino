import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/dtf_api.dart';
import '../models/post.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/post_card.dart';
import 'post_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Post> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = context.read<SettingsService>();
    final items = await DtfApi.getDrafts(settings);
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Черновики', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: const [
                      SizedBox(height: 180),
                      Center(child: Text('Нет черновиков', style: TextStyle(color: Colors.grey))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final post = _items[i];
                      return PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => PostScreen(
                              postId: post.id,
                              title: post.title,
                              postData: post,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
