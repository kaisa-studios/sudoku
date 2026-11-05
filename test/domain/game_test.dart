import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';
import 'package:sudoku/domain/sudoku/grid.dart';

const _puzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
const _solution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

Game _newGame() => Game(
      puzzle: gridFromString(_puzzle),
      solution: gridFromString(_solution),
      difficulty: Difficulty.easy,
    );

/// Cell 2 (row 0, column 2) is empty; its solution is 4.
const _empty = 2;
const _right = 4;
const _wrong = 1;

void main() {
  test('givens cannot be changed', () {
    final g = _newGame()..select(0);
    expect(g.enter(9), EntryResult.ignored);
    expect(g.erase(), isFalse);
    expect(g.values[0], 5);
  });

  test('correct entry clears that digit from peer notes, not from others', () {
    final g = _newGame()
      ..select(3)
      ..toggleNotesMode()
      ..enter(_right)
      ..enter(6)
      ..toggleNotesMode()
      ..select(_empty);
    expect(g.enter(_right), EntryResult.correct);
    expect(g.notes[3] & (1 << _right), 0);
    expect(g.notes[3] & (1 << 6), isNot(0));
    expect(g.mistakes, 0);
  });

  test('wrong entries count each time, same digit again is a no-op, notes never count', () {
    final g = _newGame()..select(_empty);
    expect(g.enter(_wrong), EntryResult.mistake);
    expect(g.enter(_wrong), EntryResult.ignored);
    expect(g.mistakes, 1);
    expect(g.enter(7), EntryResult.mistake); // switching between wrong digits counts
    expect(g.mistakes, 2);
    g
      ..erase()
      ..toggleNotesMode();
    expect(g.enter(_wrong), EntryResult.note);
    expect(g.mistakes, 2);
  });

  test('undo restores the board but not the mistake count', () {
    final g = _newGame()..select(_empty);
    g.enter(_wrong);
    expect(g.undo(), isTrue);
    expect(g.values[_empty], 0);
    expect(g.mistakes, 1);
  });

  test('third mistake locks the game, one second chance keeps the loss', () {
    final g = _newGame()..select(_empty);
    g
      ..enter(1)
      ..enter(2)
      ..enter(3);
    expect(g.phase, GamePhase.awaitingContinue);
    expect(g.outcome, GameOutcome.failed);
    expect(g.enter(_right), EntryResult.ignored);
    expect(g.undo(), isFalse);
    expect(g.grantContinue(), isTrue);
    expect(g.grantContinue(), isFalse);
    expect(g.enter(6), EntryResult.mistake);
    expect(g.mistakes, 4);
    expect(g.phase, GamePhase.active); // no second lock after the chance
  });

  test('solving completes the game as won, or as failed after a second chance', () {
    for (final withChance in [false, true]) {
      final g = _newGame();
      if (withChance) {
        g.select(_empty);
        g
          ..enter(1)
          ..enter(2)
          ..enter(3)
          ..grantContinue();
      }
      final sol = gridFromString(_solution);
      for (var c = 0; c < cellCount; c++) {
        if (g.values[c] != sol[c]) {
          g.select(c);
          g.enter(sol[c]);
        }
      }
      expect(g.phase, GamePhase.completed);
      expect(g.outcome, withChance ? GameOutcome.failed : GameOutcome.won);
    }
  });

  test('abandoning before the third mistake is not a loss', () {
    final g = _newGame()..abandon();
    expect(g.outcome, GameOutcome.abandoned);
  });

  test('hint fills the selected wrong cell, protects it, undo takes it back but the count stays', () {
    final g = _newGame()..select(_empty);
    g.enter(_wrong);
    expect(g.hint(), _empty);
    expect(g.values[_empty], _right);
    expect(g.isHinted(_empty), isTrue);
    expect(g.hintCount, 1);
    expect(g.enter(9), EntryResult.ignored);
    expect(g.erase(), isFalse);
    expect(g.undo(), isTrue);
    expect(g.values[_empty], _wrong);
    expect(g.isHinted(_empty), isFalse);
    expect(g.hintCount, 1);
    expect(g.mistakes, 1);
  });

  test('hint without a usable selection takes the first open cell', () {
    final g = _newGame()..select(0); // a given
    expect(g.hint(), _empty); // cell 2 is the first empty cell
  });

  test('hint is locked after the third mistake', () {
    final g = _newGame()..select(_empty);
    g
      ..enter(1)
      ..enter(2)
      ..enter(3);
    expect(g.hint(), isNull);
  });

  test('hints survive saving and loading', () {
    final g = _newGame()..select(_empty);
    g.hint();
    final back = Game.fromJson(
      puzzle: gridFromString(_puzzle),
      solution: gridFromString(_solution),
      difficulty: Difficulty.easy,
      json: g.toJson(),
    );
    expect(back.isHinted(_empty), isTrue);
    expect(back.hintCount, 1);
    expect(back.undo(), isTrue);
    expect(back.isHinted(_empty), isFalse);
  });
}
