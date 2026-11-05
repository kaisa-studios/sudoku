import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../data/game_repository.dart';
import '../../domain/game/game.dart';
import '../../domain/sudoku/difficulty.dart';
import 'board.dart';

String difficultyLabel(Difficulty d) => switch (d) {
      Difficulty.easy => 'Leicht',
      Difficulty.medium => 'Mittel',
      Difficulty.hard => 'Schwer',
      Difficulty.expert => 'Experte',
    };

/// Result returned to the previous screen when the player leaves.
enum GameExit { home, newGame }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.saved});

  final SavedGame saved;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameRepository _repo;
  final _clock = Stopwatch();
  Timer? _ticker;
  int _ticks = 0;
  bool _dialogOpen = false;
  bool _foreground = true;
  Future<void> _saving = Future.value();

  SavedGame get saved => widget.saved;
  Game get game => saved.game;

  @override
  void initState() {
    super.initState();
    _repo = ServicesScope.read(context).games;
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _updateClock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && game.phase == GamePhase.awaitingContinue) _showThirdMistake();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _commitTime();
    _save();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateClock();
    if (!_foreground) _save();
  }

  // ------------------------------------------------------------- timer --

  /// Time only counts while the game is visible and playable (6.4).
  void _updateClock() {
    final run = _foreground && !_dialogOpen && game.canPlay;
    if (run && !_clock.isRunning) {
      _clock.start();
    } else if (!run && _clock.isRunning) {
      _commitTime();
      _clock.stop();
    }
  }

  void _commitTime() {
    game.activeMs += _clock.elapsedMilliseconds;
    _clock.reset();
  }

  void _tick() {
    if (!mounted || !_clock.isRunning) return;
    setState(() {});
    if (++_ticks % 5 == 0) {
      _commitTime();
      _save();
    }
  }

  int get _shownMs => game.activeMs + _clock.elapsedMilliseconds;

  /// Saves are serialised so an older state can never overwrite a newer one.
  Future<void> _save() => _saving = _saving.then((_) => _repo.save(saved)).catchError((_) {});

  // ----------------------------------------------------------- actions --

  void _act(VoidCallback change) {
    setState(change);
    _commitTime();
    _save();
    _updateClock();
    if (game.phase == GamePhase.awaitingContinue) {
      _showThirdMistake();
    } else if (game.phase == GamePhase.completed) {
      _showFinished();
    }
  }

  Future<T?> _dialog<T>(WidgetBuilder builder) async {
    _dialogOpen = true;
    _updateClock();
    final r = await showDialog<T>(context: context, barrierDismissible: false, builder: builder);
    _dialogOpen = false;
    _updateClock();
    return r;
  }

  Future<void> _leave(GameExit exit) async {
    _commitTime();
    await _save();
    if (mounted) Navigator.pop(context, exit);
  }

  Future<void> _showThirdMistake() async {
    final choice = await _dialog<String>((context) => AlertDialog(
          title: const Text('Drei Fehler'),
          content: const Text(
              'Dieses Sudoku zählt jetzt als nicht geschafft. Du kannst es trotzdem zu Ende spielen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'end'), child: const Text('Spiel beenden')),
            TextButton(onPressed: () => Navigator.pop(context, 'later'), child: const Text('Später')),
            FilledButton(onPressed: () => Navigator.pop(context, 'continue'), child: const Text('Weiterspielen')),
          ],
        ));
    if (!mounted) return;
    switch (choice) {
      case 'continue':
        _act(() => game.grantContinue());
      case 'end':
        game.abandon();
        await _leave(GameExit.home);
      default:
        await _leave(GameExit.home); // stays locked; the decision is offered again later
    }
  }

  Future<void> _showFinished() async {
    final won = game.outcome == GameOutcome.won;
    final daily = saved.isDaily;
    final choice = await _dialog<GameExit>((context) => AlertDialog(
          title: Text(won ? 'Geschafft!' : 'Sudoku beendet'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!won) const Text('Zählt als nicht geschafft, weil die zweite Chance genutzt wurde.\n'),
            Text('Zeit: ${formatDuration(game.activeMs)}'),
            Text('Fehler: ${game.mistakes}'),
          ]),
          actions: [
            if (daily)
              FilledButton(onPressed: () => Navigator.pop(context, GameExit.home), child: const Text('Fertig'))
            else ...[
              TextButton(onPressed: () => Navigator.pop(context, GameExit.home), child: const Text('Zur Startseite')),
              FilledButton(onPressed: () => Navigator.pop(context, GameExit.newGame), child: const Text('Neues Sudoku')),
            ],
          ],
        ));
    if (!mounted) return;
    await _leave(choice ?? GameExit.home);
  }

  // --------------------------------------------------------------- UI --

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = saved.isDaily ? 'Tagesrätsel · ${difficultyLabel(game.difficulty)}' : difficultyLabel(game.difficulty);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(GameExit.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            Semantics(
              label: 'Spielzeit ${formatDuration(_shownMs)}',
              excludeSemantics: true,
              child: Text(formatDuration(_shownMs), style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 16),
            Semantics(
              label: 'Fehler ${game.mistakes} von $mistakeLimit',
              excludeSemantics: true,
              child: Text('Fehler ${game.mistakes}/$mistakeLimit', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: OrientationBuilder(builder: (context, orientation) {
            final board = Padding(
              padding: const EdgeInsets.all(8),
              child: Center(child: Board(game: game, onTap: (c) => setState(() => game.select(c)))),
            );
            final pad = _Controls(game: game, onAction: _act);
            if (orientation == Orientation.landscape) {
              return Row(children: [Expanded(child: board), Expanded(child: SingleChildScrollView(child: pad))]);
            }
            return Column(children: [Expanded(child: board), pad]);
          }),
        ),
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
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w600, color: done ? Theme.of(context).disabledColor : null)),
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
