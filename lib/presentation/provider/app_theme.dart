import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_theme.g.dart';

@Riverpod(keepAlive: true)
AppThemeDataNotifier appThemeData(Ref ref) {
  return AppThemeDataNotifier();
}

class AppThemeData {
  const AppThemeData({
    required this.day,
    required this.night,
    required this.midnight,
  });

  final ThemeData day;
  final ThemeData night;
  final ThemeData midnight;
}

class AppThemeDataNotifier {
  AppThemeData? _data;
  ColorScheme? _light;
  ColorScheme? _dark;

  AppThemeData get data => _data ??= _create();

  /// Rebuilding ThemeData is not free, so only do it when the dynamic
  /// palette actually changed.
  AppThemeData fillWith({ColorScheme? light, ColorScheme? dark}) {
    if (_data != null && light == _light && dark == _dark) return _data!;
    _light = light;
    _dark = dark;
    return _data = _create(light: light, dark: dark);
  }

  AppThemeData _create({ColorScheme? light, ColorScheme? dark}) {
    final lightScheme = light?.harmonized() ?? defLightScheme;
    final darkScheme = dark?.harmonized() ?? defDarkScheme;
    return AppThemeData(
      day: _build(lightScheme),
      night: _build(darkScheme),
      midnight: _build(
        darkScheme.copyWith(
          surface: Colors.black,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0B0B0D),
          surfaceContainer: const Color(0xFF121214),
          surfaceContainerHigh: const Color(0xFF19191C),
          surfaceContainerHighest: const Color(0xFF212125),
        ),
      ),
    );
  }

  ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final cs = scheme.copyWith(
      outlineVariant: scheme.outlineVariant.withValues(alpha: 0.35),
    );
    const radius = BorderRadius.all(Radius.circular(16));
    const smallRadius = BorderRadius.all(Radius.circular(12));

    final base = ThemeData(
      colorScheme: cs,
      brightness: cs.brightness,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      canvasColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: cs.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: smallRadius),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        iconColor: cs.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: smallRadius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        border: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check_rounded, size: 16)
              : null,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: smallRadius),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
        thumbColor: WidgetStateProperty.all(
          cs.onSurfaceVariant.withValues(alpha: isDark ? 0.35 : 0.3),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cs.inverseSurface,
          borderRadius: smallRadius,
        ),
        textStyle: TextStyle(color: cs.onInverseSurface),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
    );
  }

  static const defaultAccent = Color.fromARGB(255, 149, 30, 229);

  static final defLightScheme = ColorScheme.fromSeed(
    seedColor: defaultAccent,
    brightness: Brightness.light,
  );

  static final defDarkScheme = ColorScheme.fromSeed(
    seedColor: defaultAccent,
    brightness: Brightness.dark,
  );
}
