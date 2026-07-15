import 'package:flutter/material.dart';
import '../theme.dart';

/// Placeholder for the future direct-messages feature. The bottom-nav tab is
/// part of the redesign, but chat functionality isn't built yet.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Чаты'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 56, color: accent),
            const SizedBox(height: 16),
            Text('Скоро',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Личные сообщения появятся в одном из следующих обновлений.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
