import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';

abstract final class AppColors {
  static const bgDeep     = Color(0xFF080B14);
  static const bgCard     = Color(0xFF0F1420);
  static const bgElevated = Color(0xFF1A2240);
  static const textPrimary   = Color(0xFFEEF0FF);
  static const textSecondary = Color(0xFF8A93B0);
  static const textMuted     = Color(0xFF4A5470);
  static const divider       = Color(0xFF1A2240);
  static const online        = Color(0xFF3DD68C);

  // AMOLED black-theme background palette (opt-in via settings).
  static const blackBg       = Color(0xFF000000);
  static const blackCard     = Color(0xFF0C0C0E);
  static const blackElevated = Color(0xFF1B1B1F);
}

class AppTheme {
  static ThemeData build(Color accent, {bool black = false}) {
    final base = ThemeData.dark();
    final deep = black ? AppColors.blackBg : AppColors.bgDeep;
    final card = black ? AppColors.blackCard : AppColors.bgCard;
    final elevated = black ? AppColors.blackElevated : const Color(0xFF1A2240);
    return base.copyWith(
      scaffoldBackgroundColor: deep,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: card,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:   GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        displayMedium:  GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        headlineLarge:  GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        bodyLarge:    GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium:   GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall:    GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textMuted),
        labelLarge:   GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        labelMedium:  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall:   GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 0.5),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.35)
              : const Color(0xFF1A2240),
        ),
      ),
      dividerTheme: const DividerThemeData(
          color: AppColors.divider, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: AppColors.textMuted),
        enabledBorder: UnderlineInputBorder(
            borderSide:
                BorderSide(color: AppColors.textMuted.withValues(alpha: 0.4))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accent)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(card)),
      ),
    );
  }
}

/// Glassmorphism container: BackdropFilter blur + translucent gradient + border.
/// [active] tints the glass with the current theme accent (for selected tabs, etc.).
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool active;
  final Color? accentOverride;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.active = false,
    this.accentOverride,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentOverride ?? Theme.of(context).colorScheme.primary;
    final br = borderRadius ?? BorderRadius.circular(16);
    final tint   = active ? accent : Colors.white;
    final fillA  = active ? 0.16 : 0.07;
    final fill2A = active ? 0.05 : 0.02;
    final bordA  = active ? 0.48 : 0.12;

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: fillA),
                tint.withValues(alpha: fill2A),
              ],
            ),
            border: Border.all(
                color: tint.withValues(alpha: bordA), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gradient background with colored ambient blobs that make glass cards visible.
/// When user has set a custom background image, shows it instead of the gradient.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bgPath = context.select<SettingsService, String?>((s) => s.bgImagePath);
    final dim = context.select<SettingsService, double>((s) => s.bgDim);
    final black = context.select<SettingsService, bool>((s) => s.blackTheme);
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        if (bgPath != null && !kIsWeb && File(bgPath).existsSync()) ...[
          // Custom photo background
          Positioned.fill(
            child: Image.file(File(bgPath), fit: BoxFit.cover),
          ),
          // Dimming overlay so UI stays readable
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: dim)),
          ),
        ] else if (black) ...[
          // AMOLED: pure black, no gradient or ambient glows.
          const Positioned.fill(
            child: ColoredBox(color: AppColors.blackBg),
          ),
        ] else ...[
          // Default gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E1535), Color(0xFF060810)],
                ),
              ),
            ),
          ),
          // Accent glow — top right
          Positioned(
            right: -80,
            top: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: 0.13), Colors.transparent],
                ),
              ),
            ),
          ),
          // Purple glow — bottom left
          Positioned(
            left: -90,
            bottom: 150,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6B48FF).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

/// Smart glass card.
/// • With custom bg photo → BackdropFilter blur (real liquid glass effect).
/// • Without photo → gradient fill (looks good on the default gradient bg).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final bool isViewed;

  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.isViewed = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = context.select<SettingsService, bool>((s) {
      if (s.bgImagePath == null || kIsWeb) return false;
      return File(s.bgImagePath!).existsSync();
    });
    final blur = context.select<SettingsService, double>((s) => s.bgBlur);
    final black = context.select<SettingsService, bool>((s) => s.blackTheme);

    final borderColor =
        Colors.white.withValues(alpha: isViewed ? 0.05 : 0.13);
    final shadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: isViewed ? 0.22 : 0.42),
        blurRadius: isViewed ? 10 : 24,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      ),
    ];

    if (hasBg) {
      // Real glass: blur the photo behind the card
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.7),
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              color: isViewed
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.08),
              child: child,
            ),
          ),
        ),
      );
    }

    // No photo: gradient glass look on the default bg
    return Container(
      margin: margin,
      decoration: glassCardDecoration(isViewed: isViewed, black: black),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

/// Shared glass-card decoration. Use on floating card containers.
/// [black] switches to the flat AMOLED look (dark card, no blue tint).
BoxDecoration glassCardDecoration({bool isViewed = false, bool black = false}) {
  if (black) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: isViewed
          ? const Color(0xFF060606)
          : AppColors.blackCard,
      border: Border.all(
        color: Colors.white.withValues(alpha: isViewed ? 0.04 : 0.08),
        width: 0.7,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: isViewed ? 8 : 16,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
  return BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      // No white top highlight — plain dark gradient (users disliked the glossy edge).
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isViewed
            ? [
                const Color(0xFF0C0F1E).withValues(alpha: 0.85),
                const Color(0xFF060810).withValues(alpha: 0.80),
              ]
            : [
                const Color(0xFF1C2545).withValues(alpha: 0.88),
                const Color(0xFF0F1628).withValues(alpha: 0.82),
              ],
        stops: const [0.0, 1.0],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: isViewed ? 0.04 : 0.11),
        width: 0.7,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isViewed ? 0.22 : 0.38),
          blurRadius: isViewed ? 10 : 22,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ],
    );
}

/// Scales down slightly on press then snaps back — satisfying tap feedback.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.93,
    this.duration = const Duration(milliseconds: 90),
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      onLongPress: () {
        _ctrl.reverse();
        widget.onLongPress?.call();
      },
      child: ScaleTransition(scale: _anim, child: widget.child),
    );
  }
}
