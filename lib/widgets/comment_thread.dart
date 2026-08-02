import 'package:flutter/material.dart';

import '../models/comment.dart';
import 'comment_widget.dart';

class VisibleComment {
  final Comment comment;
  final int depth;
  final int loadedDescendantCount;
  final bool hasChildren;

  const VisibleComment({
    required this.comment,
    required this.depth,
    required this.loadedDescendantCount,
    required this.hasChildren,
  });
}

class CommentTreeIndex {
  final List<Comment> roots;
  final Map<int, Comment> byId;
  final Map<int, List<Comment>> childrenByParent;
  final Map<int, int> descendantCounts;

  const CommentTreeIndex._({
    required this.roots,
    required this.byId,
    required this.childrenByParent,
    required this.descendantCounts,
  });

  factory CommentTreeIndex.fromComments(List<Comment> comments) {
    final byId = <int, Comment>{
      for (final comment in comments) comment.id: comment,
    };
    final roots = <Comment>[];
    final childrenByParent = <int, List<Comment>>{};
    for (final comment in comments) {
      if (comment.replyTo == 0 || !byId.containsKey(comment.replyTo)) {
        roots.add(comment);
      } else {
        (childrenByParent[comment.replyTo] ??= []).add(comment);
      }
    }

    final descendantCounts = <int, int>{};
    final visiting = <int>{};
    int countDescendants(int id) {
      final cached = descendantCounts[id];
      if (cached != null) return cached;
      if (!visiting.add(id)) return 0;
      var count = 0;
      for (final child in childrenByParent[id] ?? const []) {
        count += 1 + countDescendants(child.id);
      }
      visiting.remove(id);
      descendantCounts[id] = count;
      return count;
    }

    for (final id in byId.keys) {
      countDescendants(id);
    }
    return CommentTreeIndex._(
      roots: roots,
      byId: byId,
      childrenByParent: childrenByParent,
      descendantCounts: descendantCounts,
    );
  }

  List<VisibleComment> flatten({
    Set<int> collapsedIds = const {},
    int? promoteCommentId,
  }) {
    final orderedRoots = List<Comment>.from(roots);
    if (promoteCommentId != null) {
      final rootId = _rootIdFor(promoteCommentId);
      final index = orderedRoots.indexWhere((root) => root.id == rootId);
      if (index > 0) orderedRoots.insert(0, orderedRoots.removeAt(index));
    }

    final visible = <VisibleComment>[];
    final visited = <int>{};
    void append(Comment comment, int depth) {
      if (!visited.add(comment.id)) return;
      final children = childrenByParent[comment.id] ?? const [];
      visible.add(
        VisibleComment(
          comment: comment,
          depth: depth,
          loadedDescendantCount: descendantCounts[comment.id] ?? 0,
          hasChildren: children.isNotEmpty,
        ),
      );
      if (collapsedIds.contains(comment.id)) return;
      for (final child in children) {
        append(child, depth + 1);
      }
    }

    for (final root in orderedRoots) {
      append(root, 0);
    }
    return visible;
  }

  int? _rootIdFor(int commentId) {
    var current = byId[commentId];
    if (current == null) return null;
    var guard = 0;
    while (current!.replyTo != 0 && guard++ < 100) {
      final parent = byId[current.replyTo];
      if (parent == null) break;
      current = parent;
    }
    return current.id;
  }
}

class CommentRow extends StatefulWidget {
  final VisibleComment row;
  final void Function(int commentId, String authorName)? onReply;
  final VoidCallback? onReactionChanged;
  final VoidCallback? onToggleCollapse;
  final bool branchCollapsed;
  final Future<void> Function(String threadId)? onLoadThread;
  final Set<String> loadingThreadIds;
  final int? highlightCommentId;
  final GlobalKey? highlightKey;

  const CommentRow({
    super.key,
    required this.row,
    this.onReply,
    this.onReactionChanged,
    this.onToggleCollapse,
    this.branchCollapsed = false,
    this.onLoadThread,
    required this.loadingThreadIds,
    this.highlightCommentId,
    this.highlightKey,
  });

  @override
  State<CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<CommentRow> {
  bool _highlight = false;
  int get _id => widget.row.comment.id;

  @override
  void initState() {
    super.initState();
    if (_id == widget.highlightCommentId) {
      _highlight = true;
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _highlight = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.row.comment;
    final threadId = comment.threadId;
    final missing = comment.replyCount - widget.row.loadedDescendantCount;
    final isLoading =
        threadId != null && widget.loadingThreadIds.contains(threadId);
    final isTarget = _id == widget.highlightCommentId;
    final accent = Theme.of(context).colorScheme.primary;

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
            key: ValueKey(_id),
            comment: comment,
            depth: widget.row.depth,
            onReactionChanged: widget.onReactionChanged,
            onReply: widget.onReply == null
                ? null
                : () => widget.onReply!(_id, comment.author?.name ?? ''),
            onToggleCollapse: widget.row.hasChildren
                ? widget.onToggleCollapse
                : null,
            branchCollapsed: widget.row.hasChildren
                ? widget.branchCollapsed
                : null,
          ),
        ),
        if (!widget.branchCollapsed &&
            missing > 0 &&
            threadId != null &&
            widget.onLoadThread != null)
          Padding(
            padding: EdgeInsets.only(
              left: (widget.row.depth + 1) * 12.0 + 4,
              top: 2,
              bottom: 8,
            ),
            child: GestureDetector(
              onTap: isLoading ? null : () => widget.onLoadThread!(threadId),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  else
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 15,
                      color: accent,
                    ),
                  const SizedBox(width: 5),
                  Text(
                    isLoading ? 'Загрузка...' : _repliesLabel(missing),
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _repliesLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'ответ'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)
      ? 'ответа'
      : 'ответов';
  return '$count $word';
}
