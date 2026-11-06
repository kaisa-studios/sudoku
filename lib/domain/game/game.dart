/// Game rules of one Sudoku session (Master-Prompt 6.2 / 6.3), independent of UI.
library;

import '../sudoku/difficulty.dart';
import '../sudoku/grid.dart';

enum GamePhase { active, awaitingContinue, completed, abandoned }

enum GameOutcome { undecided, won, failed, abandoned }

enum EntryResult { ignored, note, correct, mistake }

/// Where the one second chance came from (statistics show ads separately).
/// `free` is the placeholder until rewarded ads exist (Phase 5).
enum ContinueSource { none, free, rewarded, adFree }

const int mistakeLimit = 3;

class _CellBefore {
  _CellBefore(this.cell, this.value, this.notes, this.hinted);
  final int cell;
  final int value;
  final int notes;
  final bool hinted;
}

class Game {
  Game({
    required List<int> puzzle,
    required List<int> solution,
    required this.difficulty,
  })  : givens = List.unmodifiable(puzzle),
        solution = List.unmodifiable(solution),
        values = List.of(puzzle),
        notes = List.filled(cellCount, 0);

  final List<int> givens;
  final List<int> solution;
  final Difficulty difficulty;
  final List<int> values;
  final List<int> notes;

  /// Cells filled by a hint: protected like givens, but undoable (6.2).
  final Set<int> hinted = {};

  GamePhase phase = GamePhase.active;
  GameOutcome outcome = GameOutcome.undecided;
  int mistakes = 0;
  bool continueUsed = false;
  ContinueSource continueSource = ContinueSource.none;
  bool failed = false;
  DateTime? failedAt;

  /// When the second chance was granted (10.3).
  DateTime? continueAt;

  /// A rewarded video was actually opened for this game: the following
  /// transition shows no interstitial (10.2).
  bool rewardedAdOpened = false;

  /// Active play time in milliseconds (only while visible and playable, 6.4).
  int activeMs = 0;
  int hintCount = 0;
  int? selected;
  bool notesMode = false;

  final List<List<_CellBefore>> _undo = [];
  static const int undoLimit = 200;

  bool get canPlay => phase == GamePhase.active;
  bool get canUndo => canPlay && _undo.isNotEmpty;
  bool isGiven(int c) => givens[c] != 0;
  bool isHinted(int c) => hinted.contains(c);

  /// Givens and hinted cells cannot be changed by entries or erasing.
  bool isProtected(int c) => isGiven(c) || isHinted(c);
  bool isWrong(int c) => values[c] != 0 && values[c] != solution[c];

  /// How many of [digit] are correctly placed (used to grey out finished digits).
  int placedCount(int digit) {
    var n = 0;
    for (var c = 0; c < cellCount; c++) {
      if (values[c] == digit && solution[c] == digit) n++;
    }
    return n;
  }

  void select(int cell) {
    if (cell >= 0 && cell < cellCount) selected = cell;
  }

  void toggleNotesMode() => notesMode = !notesMode;

  EntryResult enter(int digit) {
    final c = selected;
    if (!canPlay || c == null || isProtected(c) || digit < 1 || digit > 9) {
      return EntryResult.ignored;
    }
    if (notesMode) {
      if (values[c] != 0) return EntryResult.ignored;
      _push([c]);
      notes[c] ^= 1 << digit;
      return EntryResult.note;
    }
    if (values[c] == digit) return EntryResult.ignored; // same digit again: no-op
    final correct = digit == solution[c];
    final touched = [c];
    if (correct) {
      for (final p in peers[c]) {
        if (values[p] == 0 && notes[p] & (1 << digit) != 0) touched.add(p);
      }
    }
    _push(touched);
    values[c] = digit;
    notes[c] = 0;
    if (correct) {
      for (final p in touched.skip(1)) {
        notes[p] &= ~(1 << digit);
      }
      _checkComplete();
      return EntryResult.correct;
    }
    mistakes++;
    if (mistakes >= mistakeLimit && !failed) {
      failed = true;
      failedAt = DateTime.now().toUtc();
      outcome = GameOutcome.failed;
      phase = GamePhase.awaitingContinue;
    }
    return EntryResult.mistake;
  }

  bool erase() {
    final c = selected;
    if (!canPlay || c == null || isProtected(c)) return false;
    if (values[c] == 0 && notes[c] == 0) return false;
    _push([c]);
    values[c] = 0;
    notes[c] = 0;
    return true;
  }

  /// Undoes the last board change. Mistakes and a used second chance stay.
  bool undo() {
    if (!canUndo) return false;
    for (final b in _undo.removeLast()) {
      values[b.cell] = b.value;
      notes[b.cell] = b.notes;
      if (b.hinted) {
        hinted.add(b.cell);
      } else {
        hinted.remove(b.cell);
      }
    }
    _checkComplete();
    return true;
  }

  /// Free hint (6.2): fills the selected cell if it is editable and not yet
  /// correct, otherwise the first such cell. Returns the filled cell or null.
  /// The hint count stays even if the hint is undone.
  int? hint() {
    if (!canPlay) return null;
    bool open(int c) => !isProtected(c) && values[c] != solution[c];
    final sel = selected;
    int? target = sel != null && open(sel) ? sel : null;
    if (target == null) {
      for (var c = 0; c < cellCount; c++) {
        if (open(c)) {
          target = c;
          break;
        }
      }
    }
    if (target == null) return null;
    final c = target;
    final digit = solution[c];
    final touched = [
      c,
      for (final p in peers[c])
        if (values[p] == 0 && notes[p] & (1 << digit) != 0) p,
    ];
    _push(touched);
    values[c] = digit;
    notes[c] = 0;
    for (final p in touched.skip(1)) {
      notes[p] &= ~(1 << digit);
    }
    hinted.add(c);
    hintCount++;
    selected = c;
    _checkComplete();
    return c;
  }

  /// The one second chance after the third mistake; the loss stays recorded.
  /// Idempotent: a second call (e.g. a duplicate reward callback) changes nothing.
  bool grantContinue({ContinueSource source = ContinueSource.free, DateTime? at}) {
    if (phase != GamePhase.awaitingContinue || continueUsed) return false;
    continueUsed = true;
    continueSource = source;
    continueAt = at ?? DateTime.now();
    phase = GamePhase.active;
    return true;
  }

  void abandon() {
    if (phase == GamePhase.completed) return;
    phase = GamePhase.abandoned;
    if (!failed) outcome = GameOutcome.abandoned;
  }

  bool get isFinal => phase == GamePhase.completed || phase == GamePhase.abandoned;

  // ---------------------------------------------------------- persistence --

  Map<String, Object?> toJson() => {
        'v': 1,
        'values': gridToString(values),
        'notes': notes,
        'phase': phase.name,
        'outcome': outcome.name,
        'mistakes': mistakes,
        'continueUsed': continueUsed,
        'continueSource': continueSource.name,
        'failed': failed,
        'failedAt': failedAt?.toIso8601String(),
        'continueAt': continueAt?.toIso8601String(),
        'rewardedAdOpened': rewardedAdOpened,
        'activeMs': activeMs,
        'hintCount': hintCount,
        'selected': selected,
        'notesMode': notesMode,
        'hinted': hinted.toList()..sort(),
        'undo': [
          for (final step in _undo) [for (final b in step) [b.cell, b.value, b.notes, if (b.hinted) 1]],
        ],
      };

  /// Restores a saved game. Unknown or broken fields fall back to safe values;
  /// the rule lock (third mistake without used chance) is never loosened.
  static Game fromJson({
    required List<int> puzzle,
    required List<int> solution,
    required Difficulty difficulty,
    required Map<String, Object?> json,
  }) {
    final g = Game(puzzle: puzzle, solution: solution, difficulty: difficulty);
    final values = gridFromString(json['values'] as String? ?? gridToString(puzzle));
    for (var c = 0; c < cellCount; c++) {
      g.values[c] = g.isGiven(c) ? puzzle[c] : values[c];
    }
    final notes = (json['notes'] as List?)?.cast<int>() ?? const [];
    for (var c = 0; c < cellCount && c < notes.length; c++) {
      g.notes[c] = g.values[c] == 0 ? notes[c] & allDigits : 0;
    }
    g.phase = GamePhase.values.asNameMap()[json['phase']] ?? GamePhase.active;
    g.outcome = GameOutcome.values.asNameMap()[json['outcome']] ?? GameOutcome.undecided;
    g.mistakes = json['mistakes'] as int? ?? 0;
    g.continueUsed = json['continueUsed'] as bool? ?? false;
    g.continueSource =
        ContinueSource.values.asNameMap()[json['continueSource']] ?? ContinueSource.none;
    g.failed = (json['failed'] as bool? ?? false) || g.mistakes >= mistakeLimit;
    final failedAt = json['failedAt'] as String?;
    g.failedAt = failedAt == null ? null : DateTime.tryParse(failedAt);
    final continueAt = json['continueAt'] as String?;
    g.continueAt = continueAt == null ? null : DateTime.tryParse(continueAt);
    g.rewardedAdOpened = json['rewardedAdOpened'] as bool? ?? false;
    g.activeMs = json['activeMs'] as int? ?? 0;
    g.hintCount = json['hintCount'] as int? ?? 0;
    g.selected = json['selected'] as int?;
    g.notesMode = json['notesMode'] as bool? ?? false;
    for (final c in (json['hinted'] as List?)?.cast<int>() ?? const <int>[]) {
      if (c >= 0 && c < cellCount && !g.isGiven(c) && g.values[c] == solution[c]) g.hinted.add(c);
    }
    for (final step in (json['undo'] as List?) ?? const []) {
      g._undo.add([
        for (final b in step as List)
          _CellBefore((b as List)[0] as int, b[1] as int, b[2] as int, b.length > 3 && b[3] == 1),
      ]);
    }
    // invariant (6.3): a failed game without used chance stays locked
    if (g.failed && !g.continueUsed && !g.isFinal) g.phase = GamePhase.awaitingContinue;
    if (g.failed && g.outcome == GameOutcome.undecided) g.outcome = GameOutcome.failed;
    return g;
  }

  void _push(List<int> cells) {
    _undo.add([for (final c in cells) _CellBefore(c, values[c], notes[c], hinted.contains(c))]);
    if (_undo.length > undoLimit) _undo.removeAt(0);
  }

  void _checkComplete() {
    for (var c = 0; c < cellCount; c++) {
      if (values[c] != solution[c]) return;
    }
    phase = GamePhase.completed;
    outcome = failed ? GameOutcome.failed : GameOutcome.won;
  }
}
