import 'package:flutter/material.dart';

/// Calm, warm look (Master-Prompt 8.1): warm light background, dark text,
/// one restrained accent; a dark counterpart with the same hierarchy.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.boardBackground,
    required this.lineThin,
    required this.lineThick,
    required this.given,
    required this.entry,
    required this.wrong,
    required this.selected,
    required this.related,
    required this.sameDigit,
    required this.note,
  });

  final Color boardBackground;
  final Color lineThin;
  final Color lineThick;
  final Color given;
  final Color entry;
  final Color wrong;
  final Color selected;
  final Color related;
  final Color sameDigit;
  final Color note;

  static const light = AppColors(
    boardBackground: Color(0xFFFFFDF8),
    lineThin: Color(0xFFC9C2B5),
    lineThick: Color(0xFF3E4A52),
    given: Color(0xFF1F2A30),
    entry: Color(0xFF2B5F8A),
    wrong: Color(0xFFB3261E),
    selected: Color(0xFFBFD6EA),
    related: Color(0xFFEDE7DC),
    sameDigit: Color(0xFFD6E4F0),
    note: Color(0xFF5A646B),
  );

  static const dark = AppColors(
    boardBackground: Color(0xFF1E2327),
    lineThin: Color(0xFF4A535A),
    lineThick: Color(0xFFC9D1D6),
    given: Color(0xFFF1EEE8),
    entry: Color(0xFF8EC1EA),
    wrong: Color(0xFFFF8A80),
    selected: Color(0xFF34506A),
    related: Color(0xFF2A3036),
    sameDigit: Color(0xFF2E4252),
    note: Color(0xFFB4BCC2),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2B5F8A),
    brightness: brightness,
    surface: dark ? const Color(0xFF15191C) : const Color(0xFFF7F3EC),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    extensions: [dark ? AppColors.dark : AppColors.light],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
