import 'package:flutter/material.dart';

import '../../domain/sudoku/difficulty.dart';
import '../game/game_screen.dart';
import '../game/puzzle_source.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.source = generatePuzzle});

  final PuzzleSource source;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _level = Difficulty.easy;
  bool _loading = false;

  Future<void> _start() async {
    if (_loading) return; // no second game from a double tap
    setState(() => _loading = true);
    var next = true;
    while (next && mounted) {
      try {
        final puzzle = await widget.source(_level);
        if (!mounted) return;
        setState(() => _loading = false);
        final exit = await Navigator.of(context).push<GameExit>(
          MaterialPageRoute(builder: (_) => GameScreen(puzzle: puzzle)),
        );
        next = exit == GameExit.newGame;
        if (next && mounted) setState(() => _loading = true);
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Das Sudoku konnte nicht erstellt werden. Bitte versuche es erneut.'),
        ));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Tidy Sudoku',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Große Zahlen. Klare Felder.',
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 40),
                Text('Schwierigkeit', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final d in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LevelTile(
                      label: difficultyLabel(d),
                      selected: d == _level,
                      onTap: _loading ? null : () => setState(() => _level = d),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _start,
                  child: _loading
                      ? const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 3))
                      : const Text('Spiel starten'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 20))),
                if (selected) Icon(Icons.check_circle, color: scheme.primary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
