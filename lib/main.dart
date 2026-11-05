import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/services.dart';
import 'app/theme.dart';
import 'data/app_database.dart';
import 'data/game_repository.dart';
import 'data/puzzle_content.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = Services(
    games: GameRepository(AppDatabase()),
    content: await PuzzleContent.load(rootBundle),
  );
  runApp(TidySudokuApp(services: services));
}

class TidySudokuApp extends StatelessWidget {
  const TidySudokuApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: services,
      child: MaterialApp(
        title: 'Tidy Sudoku',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
