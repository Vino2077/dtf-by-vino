import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ── DTF by Vino — design system (Figma "DTF-PDF": Dark + Light) ────────────
/// Two palettes taken 1:1 from the Figma file. The active one is swapped at
/// runtime via [applyPalette] so the ~370 `AppColors.x` call sites keep working
/// without having to thread a theme through each of them.
class AppPalette {
  final bool isLight;
  final Color bgDeep;      // screen background
  final Color bgCard;      // cards, list items
  final Color bgElevated;  // chips, secondary buttons, inputs
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color divider;
  final Color online;      // green
  final Color danger;      // red
  final Color topBar;      // app bar / tab strip background
  /// Light theme cards have a 1px left→right gradient border; dark ones a
  /// hairline white border. Null = no gradient (dark).
  final Gradient? cardBorderGradient;
  final Color cardBorderSolid;
  final List<BoxShadow> cardShadow;

  const AppPalette({
    required this.isLight,
    required this.bgDeep,
    required this.bgCard,
    required this.bgElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.online,
    required this.danger,
    required this.topBar,
    required this.cardBorderGradient,
    required this.cardBorderSolid,
    required this.cardShadow,
  });

  static const dark = AppPalette(
    isLight: false,
    bgDeep: Color(0xFF0D0E12),
    bgCard: Color(0xFF151618),
    bgElevated: Color(0xFF323234),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB4B7BC),
    textMuted: Color(0xFF747474),
    divider: Color(0xFF26272B),
    online: Color(0xFF7AAA56),
    danger: Color(0xFFFD424B),
    topBar: Color(0xFF0D0E12),
    cardBorderGradient: null,
    cardBorderSolid: Color(0x0DFFFFFF),
    cardShadow: [],
  );

  static const light = AppPalette(
    isLight: true,
    bgDeep: Color(0xFFD2D2D2),
    bgCard: Color(0xFFEAEAEA),
    bgElevated: Color(0xFFB0C7F2),
    textPrimary: Color(0xFF0D0E12),
    textSecondary: Color(0xFF323234),
    textMuted: Color(0xFF747474),
    divider: Color(0xFFD9D9D9),
    online: Color(0xFF7AAA56),
    danger: Color(0xFFFD424B),
    topBar: Color(0xFFFFFFFF),
    cardBorderGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFB3DEFF), Color(0xFF6580EC)],
    ),
    cardBorderSolid: Color(0xFF8CA2F6),
    cardShadow: [
      BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 4)),
    ],
  );
}

AppPalette _palette = AppPalette.dark;

/// Switches the active palette. Call before building the [MaterialApp] theme.
void applyPalette({required bool light}) {
  _palette = light ? AppPalette.light : AppPalette.dark;
}

/// Default accent per palette (Figma: #5B82F2 dark, #6580EC light).
const kDefaultAccentDark = Color(0xFF5B82F2);
const kDefaultAccentLight = Color(0xFF6580EC);

abstract final class AppColors {
  static bool get isLight => _palette.isLight;
  static Color get bgDeep => _palette.bgDeep;
  static Color get bgCard => _palette.bgCard;
  static Color get bgElevated => _palette.bgElevated;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textMuted => _palette.textMuted;
  static Color get divider => _palette.divider;
  static Color get online => _palette.online;
  static Color get danger => _palette.danger;
  static Color get topBar => _palette.topBar;

  // Legacy AMOLED aliases — kept so old call sites keep compiling.
  static Color get blackBg => _palette.bgDeep;
  static Color get blackCard => _palette.bgCard;
  static Color get blackElevated => _palette.bgElevated;
}

/// Corner radii from the design (10 = cards/buttons, 28 = pills, 5 = small).
abstract final class AppRadius {
  static const double card = 10;
  static const double pill = 28;
  static const double small = 5;
}

/// A [BoxBorder] painted with a gradient — the light theme's card outline.
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;
  const GradientBoxBorder({required this.gradient, this.width = 1});

  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  bool get isUniform => true;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..strokeWidth = width
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke;
    final inner = rect.deflate(width / 2);
    if (borderRadius != null) {
      canvas.drawRRect(borderRadius.toRRect(inner), paint);
    } else if (shape == BoxShape.circle) {
      canvas.drawCircle(inner.center, inner.shortestSide / 2, paint);
    } else {
      canvas.drawRect(inner, paint);
    }
  }

  @override
  ShapeBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);
}

class AppTheme {
  static ThemeData build(Color accent, {bool black = false}) {
    final p = _palette;
    final base = p.isLight ? ThemeData.light() : ThemeData.dark();

    TextStyle m(double size, FontWeight w, Color c, {double? height}) =>
        GoogleFonts.montserrat(
            fontSize: size, fontWeight: w, color: c, height: height);

    return base.copyWith(
      scaffoldBackgroundColor: p.bgDeep,
      colorScheme: (p.isLight ? const ColorScheme.light() : const ColorScheme.dark())
          .copyWith(
        primary: accent,
        secondary: accent,
        surface: p.bgCard,
        onSurface: p.textPrimary,
      ),
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme).copyWith(
        displayLarge:   m(28, FontWeight.w700, p.textPrimary, height: 1.2),
        displayMedium:  m(22, FontWeight.w700, p.textPrimary, height: 1.2),
        headlineLarge:  m(18, FontWeight.w700, p.textPrimary, height: 1.25),
        headlineMedium: m(16, FontWeight.w700, p.textPrimary, height: 1.25),
        titleMedium:    m(14, FontWeight.w600, p.textPrimary, height: 1.3),
        bodyLarge:    m(14, FontWeight.w400, p.textPrimary,   height: 1.4),
        bodyMedium:   m(13, FontWeight.w400, p.textSecondary, height: 1.4),
        bodySmall:    m(12, FontWeight.w400, p.textMuted,     height: 1.3),
        labelLarge:   m(14, FontWeight.w600, p.textPrimary),
        labelMedium:  m(12, FontWeight.w500, p.textSecondary),
        labelSmall:   m(11, FontWeight.w500, p.textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.topBar,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
            color: p.isLight ? accent : p.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          color: p.isLight
              ? const Color(0xFFA2B6EE)
              : accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: p.isLight ? const Color(0xFF3C53BA) : accent.withValues(alpha: 0.55),
              width: 1),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: p.isLight ? const Color(0xFF3C53BA) : accent,
        unselectedLabelColor: p.isLight ? p.textPrimary : p.textMuted,
        labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (p.isLight ? accent : const Color(0xFF6EBAF3))
              : (p.isLight ? const Color(0xFF6580EC) : const Color(0xFFB4B7BC)),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (p.isLight ? const Color(0xFFB0C7F2) : accent)
              : (p.isLight ? const Color(0xFFEAEAEA) : p.bgElevated),
        ),
        trackOutlineColor: WidgetStatePropertyAll(
            p.isLight ? const Color(0xFF6580EC) : Colors.transparent),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isLight ? p.bgCard : p.bgElevated,
        contentTextStyle:
            GoogleFonts.montserrat(color: p.textPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bgCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.isLight ? p.bgCard : p.bgElevated,
        hintStyle: GoogleFonts.montserrat(color: p.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: accent, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle:
              GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle:
            GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
      )),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(p.bgElevated)),
      ),
    );
  }
}

/// Flat card surface used across the app. In the light theme it carries the
/// Figma gradient outline + soft drop shadow.
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
    return Container(
      margin: margin,
      decoration: glassCardDecoration(isViewed: isViewed),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );
  }
}

/// Shared card decoration. [black] is ignored (kept for call-site compat).
BoxDecoration glassCardDecoration({bool isViewed = false, bool black = false}) {
  final p = _palette;
  if (p.isLight) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      color: isViewed ? const Color(0xFFDEDEDE) : p.bgCard,
      border: GradientBoxBorder(
        gradient: p.cardBorderGradient!,
        width: 1,
      ),
      boxShadow: p.cardShadow,
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(AppRadius.card),
    color: isViewed ? const Color(0xFF101113) : p.bgCard,
    border: Border.all(
      color: Colors.white.withValues(alpha: isViewed ? 0.03 : 0.05),
      width: 1,
    ),
  );
}

/// Flat elevated pill/container. [active] tints it with the accent.
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
    final br = borderRadius ?? BorderRadius.circular(AppRadius.card);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        color: active
            ? accent.withValues(alpha: AppColors.isLight ? 0.30 : 0.18)
            : AppColors.bgElevated,
        border: active
            ? Border.all(color: accent.withValues(alpha: 0.55), width: 1)
            : null,
      ),
      child: child,
    );
  }
}

/// Full-screen background: flat fill + tiled DTF watermark.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: AppColors.bgDeep)),
        const Positioned.fill(child: _Watermark()),
        child,
      ],
    );
  }
}

/// Faint tiled monogram behind everything, matching the Figma background.
class _Watermark extends StatelessWidget {
  const _Watermark();

  @override
  Widget build(BuildContext context) {
    final light = AppColors.isLight;
    return IgnorePointer(
      child: Opacity(
        opacity: light ? 0.10 : 0.16,
        child: ColorFiltered(
          // The tile art is white; darken it so it stays visible on light bg.
          colorFilter: light
              ? const ColorFilter.mode(Color(0xFF6B6B6B), BlendMode.srcIn)
              : const ColorFilter.mode(Colors.white, BlendMode.dst),
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/watermark.png'),
                repeat: ImageRepeat.repeat,
                scale: 2.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
