import 'package:flutter/foundation.dart';
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
    lineThin: Color(0xFF8C8478),
    lineThick: Color(0xFF3E4A52),
    given: Color(0xFF1F2A30),
    entry: Color(0xFF245580),
    wrong: Color(0xFFA1201A),
    selected: Color(0xFFD3E3F1),
    related: Color(0xFFEFEAE0),
    sameDigit: Color(0xFFDCE8F3),
    note: Color(0xFF4E585F),
  );

  static const dark = AppColors(
    boardBackground: Color(0xFF1E2327),
    lineThin: Color(0xFF6E7880),
    lineThick: Color(0xFFC9D1D6),
    given: Color(0xFFF1EEE8),
    entry: Color(0xFF9ECBEE),
    wrong: Color(0xFFFFA49C),
    selected: Color(0xFF2C4255),
    related: Color(0xFF2A3036),
    sameDigit: Color(0xFF2A3B49),
    note: Color(0xFFC2C9CE),
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
  // the platform's text theme (Roboto / San Francisco); buttons take their font from it too
  final typography = Typography.material2021(platform: defaultTargetPlatform);
  final text = dark ? typography.white : typography.black;
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    extensions: [dark ? AppColors.dark : AppColors.light],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: text.labelLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
