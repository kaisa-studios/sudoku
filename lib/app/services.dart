import 'package:flutter/widgets.dart';

import '../data/game_repository.dart';
import 'app_settings.dart';
import '../data/puzzle_content.dart';
import '../features/game/puzzle_source.dart';

/// Explicit dependencies of the app (Master-Prompt 4.2: simple DI).
class Services {
  Services({
    required this.games,
    required this.content,
    AppSettings? settings,
    PuzzleSource? source,
    DateTime Function()? clock,
  })  : source = source ?? puzzleSourceWith(content),
        settings = settings ?? AppSettings(games),
        clock = clock ?? DateTime.now;

  final GameRepository games;
  final AppSettings settings;
  final PuzzleContent content;
  final PuzzleSource source;
  final DateTime Function() clock;
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});

  final Services services;

  static Services of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;

  /// Without registering a dependency; usable in initState.
  static Services read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ServicesScope>()!.services;

  @override
  bool updateShouldNotify(ServicesScope oldWidget) => oldWidget.services != services;
}

extension ServicesX on BuildContext {
  Services get services => ServicesScope.of(this);
}

String formatDuration(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}
