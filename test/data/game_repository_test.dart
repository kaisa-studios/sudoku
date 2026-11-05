import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/game_repository.dart';
import 'package:sudoku/domain/daily/streak.dart';
import 'package:sudoku/domain/game/game.dart';
import 'package:sudoku/domain/stats/statistics.dart';
import 'package:sudoku/domain/sudoku/difficulty.dart';

import '../support.dart';

void main() {
  test('a started game is saved and restored exactly', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    final s = await repo.startRegular(examplePuzzleOf(Difficulty.medium));
    s.game
      ..select(2)
      ..enter(1) // mistake
      ..toggleNotesMode()
      ..select(3)
      ..enter(6)
      ..toggleNotesMode()
      ..activeMs = 4200;
    await repo.save(s);

    final back = (await GameRepository(db).openRegularGame())!;
    expect(back.id, s.id);
    expect(back.game.values, s.game.values);
    expect(back.game.notes, s.game.notes);
    expect(back.game.mistakes, 1);
    expect(back.game.activeMs, 4200);
    expect(back.game.canUndo, isTrue);
    expect(back.game.difficulty, Difficulty.medium);
    await db.close();
  });

  test('the third-mistake lock survives a restart', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    final s = await repo.startRegular(examplePuzzleOf(Difficulty.easy));
    s.game
      ..select(2)
      ..enter(1)
      ..enter(2)
      ..enter(3);
    await repo.save(s);
    final back = (await repo.openRegularGame())!;
    expect(back.game.phase, GamePhase.awaitingContinue);
    expect(back.game.canPlay, isFalse);
    expect(back.game.continueUsed, isFalse);
    await db.close();
  });

  test('starting a new game ends the open one; at most one open regular game', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    final first = await repo.startRegular(examplePuzzleOf(Difficulty.easy));
    final second = await repo.startRegular(examplePuzzleOf(Difficulty.hard));
    final open = await repo.openRegularGame();
    expect(open!.id, second.id);
    expect(open.id, isNot(first.id));
    final stats = Stats.of(await repo.summaries());
    expect(stats.started, 2);
    expect(stats.abandonedWithoutFail, 1);
    expect(stats.undecided, 1);
    await db.close();
  });

  test('stale saves never overwrite newer ones', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    final s = await repo.startRegular(examplePuzzleOf(Difficulty.easy));
    final copy = (await repo.openRegularGame())!; // same revision as s
    s.game
      ..select(2)
      ..enter(4);
    await repo.save(s); // revision 2
    await repo.save(copy); // also revision 2, older content: ignored
    final back = (await repo.openRegularGame())!;
    expect(back.game.values[2], 4);
    await db.close();
  });

  test('daily games: one per day and slot, streak from finished days', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    final p = examplePuzzleOf(Difficulty.easy);
    final a = await repo.startDaily(p, '2026-11-09', 0);
    final again = await repo.startDaily(p, '2026-11-09', 0);
    expect(again.id, a.id);
    expect(await repo.openRegularGame(), isNull); // daily games are not "regular"

    final sol = examplePuzzleOf(Difficulty.easy).solution;
    for (var c = 0; c < 81; c++) {
      if (a.game.values[c] == 0) {
        a.game
          ..select(c)
          ..enter(sol[c]);
      }
    }
    expect(a.game.phase, GamePhase.completed);
    await repo.save(a);
    expect(await repo.dailyStatus('2026-11-09'), {0: GamePhase.completed});
    final days = await repo.completedDailyDays();
    expect(days, {'2026-11-09'});
    expect(computeStreak(days, DateTime(2026, 11, 10)).current, 1);
    final report = StatsReport(await repo.summaries());
    expect(report.daily.won, 1);
    expect(report.overall.started, 0);
    await db.close();
  });

  test('settings and deleting all game data', () async {
    final db = memoryDb();
    final repo = GameRepository(db);
    await repo.setSetting('lastLevel', 'hard');
    expect(await repo.setting('lastLevel'), 'hard');
    await repo.startRegular(examplePuzzleOf(Difficulty.easy));
    await db.deleteAllGameData();
    expect(await repo.openRegularGame(), isNull);
    expect(await repo.setting('lastLevel'), 'hard');
    await db.close();
  });

  test('content: pool and daily lookup by local day', () {
    final c = testContent();
    expect(c.pool(Difficulty.expert), hasLength(1));
    expect(c.dailyFor(DateTime(2026, 11, 1, 0, 5)), hasLength(3));
    expect(c.dailyFor(DateTime(2026, 10, 31, 23, 59)), isNull);
    expect(c.dailyFor(DateTime(2026, 11, 1).add(const Duration(days: 60))), isNull);
    expect(c.dailyFor(DateTime(2026, 11, 2))![1].difficulty, Difficulty.medium);
  });
}
