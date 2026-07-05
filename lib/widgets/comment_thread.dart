import 'package:flutter/material.dart';
import 'comment_widget.dart';

/// Builds a threaded comment tree from a flat list. DTF's main /comments call
/// only returns levels 0-1; deeper replies are fetched on demand by threadId.
class CommentThread extends StatelessWidget {
  final List<dynamic> comments;
  final void Function(int commentId, String authorName)? onReply;
  final VoidCallback? onReactionChanged;
  // Called with a comment's threadId to load the rest of its branch.
  final Future<void> Function(String threadId)? onLoadThread;
  final Set<String> loadingThreadIds;

  const CommentThread({
    super.key,
    required this.comments,
    this.onReply,
    this.onReactionChanged,
    this.onLoadThread,
    this.loadingThreadIds = const {},
  });

  /// Splits a flat comment list into root nodes and a children-by-parent map.
  static ({List<dynamic> roots, Map<int, List<dynamic>> childrenByParent})
      buildTree(List<dynamic> comments) {
    final childrenByParent = <int, List<dynamic>>{};
    final byId = <int, dynamic>{};
    for (final c in comments) {
      final id = c['id'] as int?;
      if (id != null) byId[id] = c;
    }
    final roots = <dynamic>[];
    for (final c in comments) {
      final replyTo = (c['replyTo'] ?? 0) as int;
      if (replyTo == 0 || !byId.containsKey(replyTo)) {
        roots.add(c);
      } else {
        (childrenByParent[replyTo] ??= []).add(c);
      }
    }
    return (roots: roots, childrenByParent: childrenByParent);
  }

  @override
  Widget build(BuildContext context) {
    final tree = buildTree(comments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tree.roots
          .map((c) => CommentNode(
                comment: c,
                childrenByParent: tree.childrenByParent,
                depth: 0,
                onReply: onReply,
                onReactionChanged: onReactionChanged,
                onLoadThread: onLoadThread,
                loadingThreadIds: loadingThreadIds,
              ))
          .toList(),
    );
  }
}

class CommentNode extends StatefulWidget {
  final dynamic comment;
  final Map<int, List<dynamic>> childrenByParent;
  final int depth;
  final void Function(int commentId, String authorName)? onReply;
  final VoidCallback? onReactionChanged;
  final Future<void> Function(String threadId)? onLoadThread;
  final Set<String> loadingThreadIds;
  // When set, the comment with this id gets [highlightKey] (for scroll-to) and
  // a brief highlight flash — used to jump straight to a comment from a
  // notification or the search screen.
  final int? highlightCommentId;
  final GlobalKey? highlightKey;

  const CommentNode({
    super.key,
    required this.comment,
    required this.childrenByParent,
    required this.depth,
    this.onReply,
    this.onReactionChanged,
    this.onLoadThread,
    required this.loadingThreadIds,
    this.highlightCommentId,
    this.highlightKey,
  });

  @override
  State<CommentNode> createState() => CommentNodeState();
}

class CommentNodeState extends State<CommentNode> {
  bool _branchCollapsed = false;
  bool _highlight = false;

  @override
  void initState() {
    super.initState();
    final id = widget.comment['id'] as int? ?? -1;
    if (id == widget.highlightCommentId) {
      _highlight = true;
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _highlight = false);
      });
    }
  }

  int _loadedDescendants(int id) {
    final kids = widget.childrenByParent[id] ?? const [];
    var n = kids.length;
    for (final k in kids) {
      n += _loadedDescendants(k['id'] as int? ?? -1);
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.comment['id'] as int? ?? -1;
    final children = widget.childrenByParent[id] ?? const [];
    final hasChildren = children.isNotEmpty;
    final replyCount = (widget.comment['replyCount'] ?? 0) as int;
    final threadId = widget.comment['threadId']?.toString();

    final loaded = _loadedDescendants(id);
    final accent = Theme.of(context).colorScheme.primary;
    final missing = replyCount - loaded; // unloaded replies in this branch
    final isLoading = threadId != null && widget.loadingThreadIds.contains(threadId);

    final isTarget = id == widget.highlightCommentId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          key: isTarget ? widget.highlightKey : null,
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            color: _highlight
                ? accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CommentWidget(
            comment: widget.comment,
            onReactionChanged: widget.onReactionChanged,
            onReply: widget.onReply == null
                ? null
                : () => widget.onReply!(id, widget.comment['author']?['name'] ?? ''),
            onToggleCollapse: hasChildren ? () => setState(() => _branchCollapsed = !_branchCollapsed) : null,
            branchCollapsed: hasChildren ? _branchCollapsed : null,
          ),
        ),

        // Loaded children (unless this branch is collapsed)
        if (hasChildren && !_branchCollapsed)
          ...children.map((c) => CommentNode(
                comment: c,
                childrenByParent: widget.childrenByParent,
                depth: widget.depth + 1,
                onReply: widget.onReply,
                onReactionChanged: widget.onReactionChanged,
                onLoadThread: widget.onLoadThread,
                loadingThreadIds: widget.loadingThreadIds,
                highlightCommentId: widget.highlightCommentId,
                highlightKey: widget.highlightKey,
              )),

        // "Show N replies" button to fetch the rest of the branch
        if (!_branchCollapsed && missing > 0 && threadId != null && widget.onLoadThread != null)
          Padding(
            padding: EdgeInsets.only(left: (widget.depth + 1) * 12.0 + 4, top: 2, bottom: 8),
            child: GestureDetector(
              onTap: isLoading ? null : () => widget.onLoadThread!(threadId),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isLoading)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                else
                  Icon(Icons.subdirectory_arrow_right, size: 15, color: accent),
                const SizedBox(width: 5),
                Text(
                  isLoading ? 'Загрузка...' : _repliesLabel(missing),
                  style: TextStyle(
                      color: accent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  String _repliesLabel(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    String word;
    if (mod10 == 1 && mod100 != 11) {
      word = 'ответ';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      word = 'ответа';
    } else {
      word = 'ответов';
    }
    return '$n $word';
  }
}
