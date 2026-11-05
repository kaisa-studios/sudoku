/// Game rules of one Sudoku session (Master-Prompt 6.2 / 6.3), independent of UI.
library;

import '../sudoku/difficulty.dart';
import '../sudoku/grid.dart';

enum GamePhase { active, awaitingContinue, completed, abandoned }

enum GameOutcome { undecided, won, failed, abandoned }

enum EntryResult { ignored, note, correct, mistake }

const int mistakeLimit = 3;

class _CellBefore {
  _CellBefore(this.cell, this.value, this.notes);
  final int cell;
  final int value;
  final int notes;
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

  GamePhase phase = GamePhase.active;
  GameOutcome outcome = GameOutcome.undecided;
  int mistakes = 0;
  bool continueUsed = false;
  bool failed = false;
  int? selected;
  bool notesMode = false;

  final List<List<_CellBefore>> _undo = [];
  static const int undoLimit = 200;

  bool get canPlay => phase == GamePhase.active;
  bool get canUndo => canPlay && _undo.isNotEmpty;
  bool isGiven(int c) => givens[c] != 0;
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
    if (!canPlay || c == null || isGiven(c) || digit < 1 || digit > 9) {
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
      outcome = GameOutcome.failed;
      phase = GamePhase.awaitingContinue;
    }
    return EntryResult.mistake;
  }

  bool erase() {
    final c = selected;
    if (!canPlay || c == null || isGiven(c)) return false;
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
    }
    _checkComplete();
    return true;
  }

  /// The one second chance after the third mistake; the loss stays recorded.
  bool grantContinue() {
    if (phase != GamePhase.awaitingContinue || continueUsed) return false;
    continueUsed = true;
    phase = GamePhase.active;
    return true;
  }

  void abandon() {
    if (phase == GamePhase.completed) return;
    phase = GamePhase.abandoned;
    if (!failed) outcome = GameOutcome.abandoned;
  }

  void _push(List<int> cells) {
    _undo.add([for (final c in cells) _CellBefore(c, values[c], notes[c])]);
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
