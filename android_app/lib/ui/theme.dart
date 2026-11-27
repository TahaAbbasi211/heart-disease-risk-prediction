// theme.dart
//
// BioVanta Obsidian Dark & Clinical Paper Light theme system matching ECG V4.0.0.

import 'package:flutter/material.dart';

import '../heart_model.dart';

/// Global theme mode notifier (defaults to BioVanta Obsidian Dark).
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

@immutable
class BioVantaPalette extends ThemeExtension<BioVantaPalette> {
  const BioVantaPalette({
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.borderAccent,
    required this.textPrimary,
    required this.textMuted,
    required this.lowRisk,
    required this.moderateRisk,
    required this.highRisk,
    required this.cyan,
    required this.neutral,
    required this.dockBg,
  });

  final bool isDark;
  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color borderAccent;
  final Color textPrimary;
  final Color textMuted;
  final Color lowRisk;
  final Color moderateRisk;
  final Color highRisk;
  final Color cyan;
  final Color neutral;
  final Color dockBg;

  static const BioVantaPalette dark = BioVantaPalette(
    isDark: true,
    canvas: Color(0xFF07090C),
    surface: Color(0xFF0F131B),
    elevated: Color(0xFF151B26),
    border: Color(0xFF1F2937),
    borderAccent: Color(0xFF2D3A4F),
    textPrimary: Color(0xFFE6EDF3),
    textMuted: Color(0xFF8B949E),
    lowRisk: Color(0xFF3FB950),
    moderateRisk: Color(0xFFF5A623),
    highRisk: Color(0xFFFF4D5E),
    cyan: Color(0xFF39C5CF),
    neutral: Color(0xFF6E7781),
    dockBg: Color(0xEB0F131B),
  );

  static const BioVantaPalette light = BioVantaPalette(
    isDark: false,
    canvas: Color(0xFFF6F3EC),
    surface: Color(0xFFFDFBF7),
    elevated: Color(0xFFECE7DC),
    border: Color(0xFFD8D1C2),
    borderAccent: Color(0xFFBFB6A3),
    textPrimary: Color(0xFF1A1E24),
    textMuted: Color(0xFF5C6470),
    lowRisk: Color(0xFF0F7A3D),
    moderateRisk: Color(0xFFB45309),
    highRisk: Color(0xFFC81E32),
    cyan: Color(0xFF0E7490),
    neutral: Color(0xFF6E7781),
    dockBg: Color(0xF0FDFBF7),
  );

  static BioVantaPalette of(BuildContext context) {
    final ext = Theme.of(context).extension<BioVantaPalette>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  Color colorForBand(RiskBand band) {
    switch (band) {
      case RiskBand.low:
        return lowRisk;
      case RiskBand.moderate:
        return moderateRisk;
      case RiskBand.high:
        return highRisk;
    }
  }

  @override
  BioVantaPalette copyWith({
    bool? isDark,
    Color? canvas,
    Color? surface,
    Color? elevated,
    Color? border,
    Color? borderAccent,
    Color? textPrimary,
    Color? textMuted,
    Color? lowRisk,
    Color? moderateRisk,
    Color? highRisk,
    Color? cyan,
    Color? neutral,
    Color? dockBg,
  }) {
    return BioVantaPalette(
      isDark: isDark ?? this.isDark,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      border: border ?? this.border,
      borderAccent: borderAccent ?? this.borderAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      lowRisk: lowRisk ?? this.lowRisk,
      moderateRisk: moderateRisk ?? this.moderateRisk,
      highRisk: highRisk ?? this.highRisk,
      cyan: cyan ?? this.cyan,
      neutral: neutral ?? this.neutral,
      dockBg: dockBg ?? this.dockBg,
    );
  }

  @override
  BioVantaPalette lerp(ThemeExtension<BioVantaPalette>? other, double t) {
    if (other is! BioVantaPalette) return this;
    return BioVantaPalette(
      isDark: t < 0.5 ? isDark : other.isDark,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderAccent: Color.lerp(borderAccent, other.borderAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      lowRisk: Color.lerp(lowRisk, other.lowRisk, t)!,
      moderateRisk: Color.lerp(moderateRisk, other.moderateRisk, t)!,
      highRisk: Color.lerp(highRisk, other.highRisk, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      dockBg: Color.lerp(dockBg, other.dockBg, t)!,
    );
  }
}

/// Shared tabular-figure text style for clinical numbers & equations.
TextStyle tabularStyle(
  TextStyle? base, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  bool monospace = false,
}) {
  return (base ?? const TextStyle()).copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    fontFamily: monospace ? 'monospace' : null,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

ThemeData buildAppTheme(
  Brightness brightness, {
  bool isPersian = false,
}) {
  final isDark = brightness == Brightness.dark;
  final pal = isDark ? BioVantaPalette.dark : BioVantaPalette.light;
  final fontFamily = isPersian ? 'Vazirmatn' : null;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: pal.cyan,
    onPrimary: isDark ? const Color(0xFF041418) : Colors.white,
    primaryContainer: pal.cyan.withValues(alpha: isDark ? 0.16 : 0.12),
    onPrimaryContainer: pal.cyan,
    secondary: pal.lowRisk,
    onSecondary: isDark ? const Color(0xFF031509) : Colors.white,
    secondaryContainer: pal.lowRisk.withValues(alpha: isDark ? 0.16 : 0.12),
    onSecondaryContainer: pal.lowRisk,
    tertiary: pal.moderateRisk,
    onTertiary: isDark ? const Color(0xFF1E1300) : Colors.white,
    error: pal.highRisk,
    onError: isDark ? const Color(0xFF2B0509) : Colors.white,
    errorContainer: pal.highRisk.withValues(alpha: isDark ? 0.16 : 0.11),
    onErrorContainer:
        isDark ? const Color(0xFFFFB4BC) : const Color(0xFF8C0E1E),
    surface: pal.surface,
    onSurface: pal.textPrimary,
    onSurfaceVariant: pal.textMuted,
    surfaceContainerHighest: pal.elevated,
    outline: pal.borderAccent,
    outlineVariant: pal.border,
  );

  final baseTheme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: fontFamily,
  );

  return baseTheme.copyWith(
    scaffoldBackgroundColor: pal.canvas,
    canvasColor: pal.canvas,
    extensions: <ThemeExtension<dynamic>>[pal],
    appBarTheme: AppBarTheme(
      backgroundColor: pal.canvas,
      foregroundColor: pal.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseTheme.textTheme.titleMedium?.copyWith(
        color: pal.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: isPersian ? 0.0 : -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: pal.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: pal.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: pal.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pal.elevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: pal.highRisk),
      ),
      labelStyle: TextStyle(color: pal.textMuted),
      helperStyle: TextStyle(color: pal.textMuted, fontSize: 12),
    ),
    chipTheme: baseTheme.chipTheme.copyWith(
      backgroundColor: pal.elevated,
      selectedColor: pal.cyan.withValues(alpha: 0.18),
      side: BorderSide(color: pal.border),
      labelStyle: TextStyle(color: pal.textPrimary, fontSize: 12.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: pal.cyan,
      inactiveTrackColor: pal.borderAccent,
      thumbColor: pal.cyan,
      overlayColor: pal.cyan.withValues(alpha: 0.16),
      trackHeight: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return pal.canvas;
        return pal.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return pal.cyan;
        return pal.elevated;
      }),
      trackOutlineColor: WidgetStateProperty.all(pal.borderAccent),
    ),
  );
}
