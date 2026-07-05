import 'package:flutter/material.dart';
import '../theme.dart';

/// A looping shimmer that sweeps a light highlight across its [child].
/// Wrap skeleton shapes (see [SkeletonBox]) with this for a loading effect.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Dark base with a slightly lighter sweep — reads well on the deep theme.
  static const _base = Color(0xFF141B2E);
  static const _highlight = Color(0xFF262F4A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [_base, _highlight, _base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(_controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Translates the gradient horizontally from off-screen left to off-screen right.
class _SlideGradient extends GradientTransform {
  final double value; // 0..1
  const _SlideGradient(this.value);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (value * 2 - 1) * bounds.width * 1.5;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A single rounded placeholder block. Colour is filled by the parent [Shimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // recoloured by the shimmer ShaderMask
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Loading skeleton for the feed: post cards with text lines + a media square.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.only(top: 12),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(5, (i) => const _PostCardSkeleton()),
      ),
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // author row
          Row(children: const [
            SkeletonBox(width: 32, height: 32, radius: 16),
            SizedBox(width: 10),
            SkeletonBox(width: 120, height: 12),
          ]),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 14),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 14),
                    SizedBox(height: 14),
                    SkeletonBox(height: 11),
                    SizedBox(height: 7),
                    SkeletonBox(width: 160, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const SkeletonBox(width: 84, height: 84, radius: 10),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

/// Loading skeleton for the notifications list: avatar circle + two lines.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.only(top: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(11, (i) => const _NotifRowSkeleton()),
      ),
    );
  }
}

class _NotifRowSkeleton extends StatelessWidget {
  const _NotifRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 42, height: 42, radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 4),
                SkeletonBox(height: 12),
                SizedBox(height: 9),
                SkeletonBox(width: 140, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
