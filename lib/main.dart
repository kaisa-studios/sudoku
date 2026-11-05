import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/services.dart';
import 'app/theme.dart';
import 'data/app_database.dart';
import 'data/game_repository.dart';
import 'data/puzzle_content.dart';
import 'features/home/home_screen.dart';
import 'l10n/strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = Services(
    games: GameRepository(AppDatabase()),
    content: await PuzzleContent.load(rootBundle),
  );
  await services.settings.load();
  runApp(TidySudokuApp(services: services));
}

class TidySudokuApp extends StatelessWidget {
  const TidySudokuApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => context.s.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: services.settings.themeMode,
          // null follows the device; other languages than German/English fall back to English (D8)
          locale: services.settings.locale,
          supportedLocales: S.supportedLocales,
          localizationsDelegates: const [AppStringsDelegate(), ...GlobalMaterialLocalizations.delegates],
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
