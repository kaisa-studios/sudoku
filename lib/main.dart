import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const TidySudokuApp());
}

class TidySudokuApp extends StatelessWidget {
  const TidySudokuApp({super.key, this.home});

  /// Replaceable start screen (tests inject fixed puzzles).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidy Sudoku',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: home ?? const HomeScreen(),
    );
  }
}
