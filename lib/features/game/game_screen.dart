import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_settings.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../data/game_repository.dart';
import '../../domain/game/game.dart';
import '../../domain/sudoku/grid.dart';
import '../../l10n/strings.dart';
import 'board.dart';

/// Result returned to the previous screen when the player leaves.
enum GameExit { home, newGame }

/// Smallest cell edge in the large view (Master-Prompt 8.2: at least 48).
const double largeCellSize = 56;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.saved});

  final SavedGame saved;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameRepository _repo;
  late final AppSettings _settings;
  late bool _large;
  final _clock = Stopwatch();
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  double _cell = 0;
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
    final services = ServicesScope.read(context);
    _repo = services.games;
    _settings = services.settings;
    _large = _settings.largeViewDefault;
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _updateClock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible();
      if (mounted && game.phase == GamePhase.awaitingContinue) _showThirdMistake();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _hScroll.dispose();
    _vScroll.dispose();
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
    if (_settings.showTimer) setState(() {});
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
    _ensureVisible();
    if (game.phase == GamePhase.awaitingContinue) {
      _showThirdMistake();
    } else if (game.phase == GamePhase.completed) {
      _showFinished();
    }
  }

  void _enter(int digit) => _act(() {
        final r = game.enter(digit);
        if (r == EntryResult.mistake && _settings.haptics) HapticFeedback.mediumImpact();
      });

  void _hint() {
    int? filled;
    _act(() => filled = game.hint());
    if (filled != null && game.phase != GamePhase.completed && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.s.hintDone), duration: const Duration(seconds: 2)));
    }
  }

  void _select(int cell) {
    setState(() => game.select(cell));
    _ensureVisible();
  }

  void _move(int dr, int dc) {
    final c = game.selected ?? 0;
    final r = (rowOf(c) + dr).clamp(0, 8), k = (colOf(c) + dc).clamp(0, 8);
    _select(r * 9 + k);
  }

  /// Large view: scrolls so the selected cell is fully visible.
  void _ensureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = game.selected;
      if (!mounted || !_large || c == null || _cell == 0) return;
      void fit(ScrollController sc, double start) {
        if (!sc.hasClients) return;
        final p = sc.position;
        var target = p.pixels;
        if (start < target) target = start;
        if (start + _cell > target + p.viewportDimension) target = start + _cell - p.viewportDimension;
        target = target.clamp(0.0, p.maxScrollExtent);
        if (target != p.pixels) sc.jumpTo(target);
      }

      fit(_hScroll, colOf(c) * _cell);
      fit(_vScroll, rowOf(c) * _cell);
    });
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
    final s = context.s;
    final choice = await _dialog<String>((context) => AlertDialog(
          title: Text(s.threeMistakesTitle),
          content: Text(s.threeMistakesBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'end'), child: Text(s.endGame)),
            TextButton(onPressed: () => Navigator.pop(context, 'later'), child: Text(s.later)),
            FilledButton(onPressed: () => Navigator.pop(context, 'continue'), child: Text(s.keepPlaying)),
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
    final s = context.s;
    final won = game.outcome == GameOutcome.won;
    final daily = saved.isDaily;
    final choice = await _dialog<GameExit>((context) => AlertDialog(
          title: Text(won ? s.solvedTitle : s.finishedTitle),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!won) ...[Text(s.failedNote), const SizedBox(height: 12)],
            Text(s.timeLine(formatDuration(game.activeMs))),
            Text(s.mistakesLine(game.mistakes)),
          ]),
          actions: [
            if (daily)
              FilledButton(onPressed: () => Navigator.pop(context, GameExit.home), child: Text(s.done))
            else ...[
              TextButton(onPressed: () => Navigator.pop(context, GameExit.home), child: Text(s.toHome)),
              FilledButton(onPressed: () => Navigator.pop(context, GameExit.newGame), child: Text(s.newSudoku)),
            ],
          ],
        ));
    if (!mounted) return;
    await _leave(choice ?? GameExit.home);
  }

  // --------------------------------------------------------------- UI --

  Widget _status(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      // wraps to two lines with large system text instead of overflowing
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Semantics(
              label: s.mistakesLabel(game.mistakes, mistakeLimit),
              excludeSemantics: true,
              child: Text(s.mistakes(game.mistakes, mistakeLimit),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: game.mistakes > 0 ? context.colors.wrong : null)),
            ),
            if (_settings.showTimer)
              Semantics(
                label: s.timeLabel(formatDuration(_shownMs)),
                excludeSemantics: true,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, size: 22),
                  const SizedBox(width: 6),
                  Text(formatDuration(_shownMs), style: theme.textTheme.titleLarge),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _boardArea() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(builder: (context, box) {
        final fitCell = box.biggest.shortestSide / 9;
        final largeCell = max(largeCellSize, fitCell);
        if (!_large || largeCell <= fitCell + 0.5) {
          _cell = fitCell;
          return Center(child: Board(game: game, onTap: _select));
        }
        _cell = largeCell;
        return Scrollbar(
          controller: _vScroll,
          child: SingleChildScrollView(
            controller: _vScroll,
            child: Scrollbar(
              controller: _hScroll,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: Board(game: game, onTap: _select, cellSize: largeCell),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _arrows(BuildContext context) {
    final s = context.s;
    final c = game.selected ?? 0;
    Widget arrow(IconData icon, String label, int dr, int dc) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IconButton.filledTonal(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            tooltip: label,
            onPressed: () => _move(dr, dc),
            icon: Icon(icon, size: 28),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(s.position(rowOf(c) + 1, colOf(c) + 1), style: Theme.of(context).textTheme.titleMedium),
          ),
          arrow(Icons.arrow_back, s.moveLeft, 0, -1),
          arrow(Icons.arrow_upward, s.moveUp, -1, 0),
          arrow(Icons.arrow_downward, s.moveDown, 1, 0),
          arrow(Icons.arrow_forward, s.moveRight, 0, 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final level = s.difficulty(game.difficulty);
    final title = saved.isDaily ? s.dailyGameTitle(level) : level;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(GameExit.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: _large ? s.normalView : s.largeView,
              icon: Icon(_large ? Icons.zoom_out_map : Icons.zoom_in, size: 28),
              onPressed: () {
                setState(() => _large = !_large);
                _ensureVisible();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: OrientationBuilder(builder: (context, orientation) {
            final pad = _Controls(game: game, onAction: _act, onDigit: _enter, onHint: _hint);
            final controls = Column(mainAxisSize: MainAxisSize.min, children: [if (_large) _arrows(context), pad]);
            if (orientation == Orientation.landscape) {
              return Row(children: [
                Expanded(child: Column(children: [_status(context), Expanded(child: _boardArea())])),
                Expanded(child: Center(child: SingleChildScrollView(child: controls))),
              ]);
            }
            return LayoutBuilder(builder: (context, box) {
              final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
              final controlsEstimate = 300 * scale + (_large ? 80 : 0);
              if (box.maxHeight - controlsEstimate >= min(box.maxWidth, 280)) {
                return Column(children: [_status(context), Expanded(child: _boardArea()), controls]);
              }
              // small phone or very large text: everything scrolls, nothing is cut off (8.2)
              return SingleChildScrollView(
                child: Column(children: [
                  _status(context),
                  SizedBox(height: box.maxWidth, child: _boardArea()),
                  controls,
                ]),
              );
            });
          }),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game, required this.onAction, required this.onDigit, required this.onHint});

  final Game game;
  final void Function(VoidCallback) onAction;
  final ValueChanged<int> onDigit;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final play = game.canPlay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: _ToolButton(
              icon: game.notesMode ? Icons.edit : Icons.edit_outlined,
              label: game.notesMode ? s.notesOn : s.notes,
              selected: game.notesMode,
              onPressed: play ? () => onAction(game.toggleNotesMode) : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              icon: Icons.backspace_outlined,
              label: s.erase,
              onPressed: play ? () => onAction(() => game.erase()) : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              icon: Icons.undo,
              label: s.undo,
              onPressed: game.canUndo ? () => onAction(() => game.undo()) : null,
            ),
          ),
          Expanded(
            child: _ToolButton(
              icon: Icons.lightbulb_outline,
              label: s.hint,
              onPressed: play ? onHint : null,
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
                Expanded(child: _DigitButton(game: game, digit: r * 3 + c + 1, onDigit: onDigit)),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({required this.game, required this.digit, required this.onDigit});

  final Game game;
  final int digit;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final done = game.placedCount(digit) >= 9;
    return Semantics(
      label: done ? s.digitDone(digit) : s.digit(digit),
      button: true,
      excludeSemantics: true,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: game.canPlay ? () => onDigit(digit) : null,
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          backgroundColor: selected ? scheme.secondaryContainer : null,
        ),
        onPressed: onPressed,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 26),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
