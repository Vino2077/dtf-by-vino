import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/editor/data/editor_repository.dart';
import '../features/editor/presentation/editor_controller.dart';
import '../models/post.dart';
import '../theme.dart';
import '../widgets/post_card.dart';
import 'post_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  late final EditorController _controller;
  List<Post> get _items => _controller.drafts;
  bool get _loading => _controller.isBusy;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(context.read<EditorRepository>())
      ..addListener(_onChanged);
    _load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.loadDrafts();

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
                  Center(
                    child: Text(
                      'Нет черновиков',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
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
