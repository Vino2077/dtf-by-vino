import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import '../theme.dart';

/// Wraps the app and shows an easter-egg toast after a period of no interaction.
class InactivityDetector extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const InactivityDetector({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 2),
  });

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  Timer? _timer;
  bool _toastVisible = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset([_]) {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _fire);
  }

  void _fire() {
    _showToast('Пользователь, вы упали в фрустрацию?');
    _reset(); // keep nagging on continued inactivity
  }

  void _showToast(String message) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null || _toastVisible) return;
    _toastVisible = true;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 90,
        left: 24,
        right: 24,
        child: IgnorePointer(
          child: _ToastBubble(message: message),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2600), () {
      entry.remove();
      _toastVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _reset,
      onPointerMove: _reset,
      onPointerSignal: _reset,
      child: widget.child,
    );
  }
}

class _ToastBubble extends StatefulWidget {
  final String message;
  const _ToastBubble({required this.message});

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
