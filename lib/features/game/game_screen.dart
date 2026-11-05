import 'package:flutter/material.dart';

import '../../domain/game/game.dart';
import '../../domain/sudoku/difficulty.dart';
import '../../domain/sudoku/generator.dart';
import 'board.dart';

String difficultyLabel(Difficulty d) => switch (d) {
      Difficulty.easy => 'Leicht',
      Difficulty.medium => 'Mittel',
      Difficulty.hard => 'Schwer',
      Difficulty.expert => 'Experte',
    };

/// Result returned to the home screen when the player leaves.
enum GameExit { home, newGame }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.puzzle});

  final GeneratedPuzzle puzzle;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Game game = Game(
    puzzle: widget.puzzle.puzzle,
    solution: widget.puzzle.solution,
    difficulty: widget.puzzle.difficulty,
  )..select(widget.puzzle.puzzle.indexOf(0));

  void _update(VoidCallback change) {
    setState(change);
    _afterChange();
  }

  Future<void> _afterChange() async {
    if (game.phase == GamePhase.awaitingContinue) {
      await _showThirdMistake();
    } else if (game.phase == GamePhase.completed) {
      await _showFinished();
    }
  }

  Future<void> _showThirdMistake() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Drei Fehler'),
        content: const Text(
            'Dieses Sudoku zählt jetzt als nicht geschafft. Du kannst es trotzdem zu Ende spielen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'end'), child: const Text('Spiel beenden')),
          FilledButton(onPressed: () => Navigator.pop(context, 'continue'), child: const Text('Weiterspielen')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'continue') {
      setState(game.grantContinue);
    } else {
      game.abandon();
      Navigator.pop(context, GameExit.home);
    }
  }

  Future<void> _showFinished() async {
    final won = game.outcome == GameOutcome.won;
    final choice = await showDialog<GameExit>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(won ? 'Geschafft!' : 'Sudoku beendet'),
        content: Text(won
            ? 'Fehler: ${game.mistakes}'
            : 'Zählt als nicht geschafft (zweite Chance genutzt). Fehler: ${game.mistakes}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, GameExit.home), child: const Text('Zur Startseite')),
          FilledButton(onPressed: () => Navigator.pop(context, GameExit.newGame), child: const Text('Neues Sudoku')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, choice ?? GameExit.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(difficultyLabel(game.difficulty)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Semantics(
                label: 'Fehler ${game.mistakes} von $mistakeLimit',
                excludeSemantics: true,
                child: Text('Fehler ${game.mistakes}/$mistakeLimit', style: theme.textTheme.titleMedium),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: OrientationBuilder(builder: (context, orientation) {
          final board = Padding(
            padding: const EdgeInsets.all(8),
            child: Center(child: Board(game: game, onTap: (c) => setState(() => game.select(c)))),
          );
          final pad = _Controls(game: game, onAction: _update);
          if (orientation == Orientation.landscape) {
            return Row(children: [Expanded(child: board), Expanded(child: pad)]);
          }
          return Column(children: [Expanded(child: board), pad]);
        }),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game, required this.onAction});

  final Game game;
  final void Function(VoidCallback) onAction;

  @override
  Widget build(BuildContext context) {
    final play = game.canPlay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: _ToolButton(
              icon: game.notesMode ? Icons.edit : Icons.edit_outlined,
              label: game.notesMode ? 'Notizen an' : 'Notizen',
              selected: game.notesMode,
              onPressed: play ? () => onAction(game.toggleNotesMode) : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              icon: Icons.backspace_outlined,
              label: 'Löschen',
              onPressed: play ? () => onAction(() => game.erase()) : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              icon: Icons.undo,
              label: 'Rückgängig',
              onPressed: game.canUndo ? () => onAction(() => game.undo()) : null,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        for (var r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              for (var c = 0; c < 3; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(child: _DigitButton(game: game, digit: r * 3 + c + 1, onAction: onAction)),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({required this.game, required this.digit, required this.onAction});

  final Game game;
  final int digit;
  final void Function(VoidCallback) onAction;

  @override
  Widget build(BuildContext context) {
    final done = game.placedCount(digit) >= 9;
    return Semantics(
      label: done ? 'Zahl $digit, vollständig gesetzt' : 'Zahl $digit',
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: game.canPlay ? () => onAction(() => game.enter(digit)) : null,
        child: Text('$digit',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: done ? Theme.of(context).disabledColor : null)),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, this.onPressed, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      toggled: selected ? true : null,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 56),
          backgroundColor: selected ? scheme.secondaryContainer : null,
        ),
        onPressed: onPressed,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 26),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
