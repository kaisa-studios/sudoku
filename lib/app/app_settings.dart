import 'package:flutter/material.dart';

import '../data/game_repository.dart';

/// User preferences (Master-Prompt 5.1 / 8). Each change is saved at once;
/// an invalid stored value only resets that one setting (9.4).
class AppSettings extends ChangeNotifier {
  AppSettings(this._repo);

  final GameRepository? _repo;

  ThemeMode themeMode = ThemeMode.system;

  /// null = follow the device.
  String? languageCode;
  bool showTimer = true;
  bool haptics = false;
  bool largeViewDefault = false;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  static const _theme = 'theme', _lang = 'language', _timer = 'showTimer', _haptics = 'haptics';
  static const _large = 'largeView';

  Future<void> load() async {
    final r = _repo;
    if (r == null) return;
    themeMode = ThemeMode.values.asNameMap()[await r.setting(_theme)] ?? ThemeMode.system;
    final lang = await r.setting(_lang);
    languageCode = lang == 'de' || lang == 'en' ? lang : null;
    showTimer = await _bool(_timer, true);
    haptics = await _bool(_haptics, false);
    largeViewDefault = await _bool(_large, false);
    notifyListeners();
  }

  Future<bool> _bool(String key, bool fallback) async => switch (await _repo!.setting(key)) {
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  Future<void> _store(String key, String value) async {
    notifyListeners();
    await _repo?.setSetting(key, value);
  }

  Future<void> setThemeMode(ThemeMode m) {
    themeMode = m;
    return _store(_theme, m.name);
  }

  Future<void> setLanguage(String? code) {
    languageCode = code;
    return _store(_lang, code ?? 'device');
  }

  Future<void> setShowTimer(bool v) {
    showTimer = v;
    return _store(_timer, '$v');
  }

  Future<void> setHaptics(bool v) {
    haptics = v;
    return _store(_haptics, '$v');
  }

  Future<void> setLargeViewDefault(bool v) {
    largeViewDefault = v;
    return _store(_large, '$v');
  }
}
