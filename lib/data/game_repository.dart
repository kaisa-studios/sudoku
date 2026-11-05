import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/game/game.dart';
import '../domain/stats/statistics.dart';
import '../domain/sudoku/difficulty.dart';
import '../domain/sudoku/generator.dart';
import '../domain/sudoku/grid.dart';
import 'app_database.dart';

/// A stored game together with its identity.
class SavedGame {
  SavedGame({
    required this.id,
    required this.game,
    required this.startedAt,
    this.dailyDate,
    this.dailySlot,
    this.revision = 0,
  });

  final String id;
  final Game game;
  final DateTime startedAt;
  final String? dailyDate;
  final int? dailySlot;
  int revision;

  bool get isDaily => dailyDate != null;
}

class GameRepository {
  GameRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final _random = Random.secure();

  String _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  SavedGame _fromRow(GameRow r) => SavedGame(
        id: r.id,
        startedAt: r.startedAt,
        dailyDate: r.dailyDate,
        dailySlot: r.dailySlot,
        revision: r.revision,
        game: Game.fromJson(
          puzzle: gridFromString(r.puzzle),
          solution: gridFromString(r.solution),
          difficulty: Difficulty.values.byName(r.difficulty),
          json: jsonDecode(r.state) as Map<String, Object?>,
        ),
      );

  /// The one unfinished regular game, if any (Master-Prompt 9.2).
  Future<SavedGame?> openRegularGame() async {
    final q = _db.select(_db.games)
      ..where((g) => g.dailyDate.isNull() & g.endedAt.isNull())
      ..orderBy([(g) => OrderingTerm.desc(g.updatedAt)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<bool> hasOpenRegularGame() async => (await openRegularGame()) != null;

  Future<SavedGame?> dailyGame(String date, int slot) async {
    final row = await (_db.select(_db.games)
          ..where((g) => g.dailyDate.equals(date) & g.dailySlot.equals(slot)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// Phases of the daily games of one day, by slot.
  Future<Map<int, GamePhase>> dailyStatus(String date) async {
    final rows = await (_db.select(_db.games)..where((g) => g.dailyDate.equals(date))).get();
    return {
      for (final r in rows)
        if (r.dailySlot != null) r.dailySlot!: GamePhase.values.byName(r.phase),
    };
  }

  /// Days (yyyy-mm-dd) on which at least one daily puzzle was finished.
  Future<Set<String>> completedDailyDays() async {
    final rows = await (_db.select(_db.games)
          ..where((g) => g.dailyDate.isNotNull() & g.phase.equals(GamePhase.completed.name)))
        .get();
    return {for (final r in rows) r.dailyDate!};
  }

  /// Fingerprints of the most recent regular games, to avoid repeats (6.1).
  Future<Set<String>> recentFingerprints({int limit = 100}) async {
    final q = _db.selectOnly(_db.games)
      ..addColumns([_db.games.puzzle])
      ..orderBy([OrderingTerm.desc(_db.games.startedAt)])
      ..limit(limit);
    return {for (final r in await q.get()) r.read(_db.games.puzzle)!};
  }

  /// Starts a new regular game. An open regular game is ended as abandoned in
  /// the same transaction, so a failure never leaves two open games or none.
  Future<SavedGame> startRegular(GeneratedPuzzle p) => _db.transaction(() async {
        final open = await openRegularGame();
        if (open != null) {
          open.game.abandon();
          await _write(open);
        }
        return _insert(p);
      });

  /// Starts (or returns the existing) daily game for [date]/[slot].
  Future<SavedGame> startDaily(GeneratedPuzzle p, String date, int slot) =>
      _db.transaction(() async {
        final existing = await dailyGame(date, slot);
        if (existing != null) return existing;
        return _insert(p, dailyDate: date, dailySlot: slot);
      });

  Future<SavedGame> _insert(GeneratedPuzzle p, {String? dailyDate, int? dailySlot}) async {
    final saved = SavedGame(
      id: _newId(),
      game: Game(puzzle: p.puzzle, solution: p.solution, difficulty: p.difficulty)
        ..select(p.puzzle.indexOf(0)),
      startedAt: _clock().toUtc(),
      dailyDate: dailyDate,
      dailySlot: dailySlot,
    );
    await _write(saved, insert: true);
    return saved;
  }

  /// Saves the current state atomically (one statement, all mirrored columns).
  Future<void> save(SavedGame s) => _write(s);

  Future<void> _write(SavedGame s, {bool insert = false}) async {
    final g = s.game;
    final now = _clock().toUtc();
    s.revision++;
    final companion = GamesCompanion(
      id: Value(s.id),
      difficulty: Value(g.difficulty.name),
      dailyDate: Value(s.dailyDate),
      dailySlot: Value(s.dailySlot),
      puzzle: Value(gridToString(g.givens)),
      solution: Value(gridToString(g.solution)),
      state: Value(jsonEncode(g.toJson())),
      phase: Value(g.phase.name),
      outcome: Value(g.outcome.name),
      mistakes: Value(g.mistakes),
      hintCount: Value(g.hintCount),
      activeMs: Value(g.activeMs),
      continueUsed: Value(g.continueUsed),
      continueSource: Value(g.continueSource.name),
      failedAt: Value(g.failedAt),
      startedAt: Value(s.startedAt),
      endedAt: Value(g.isFinal ? now : null),
      updatedAt: Value(now),
      revision: Value(s.revision),
    );
    if (insert) {
      await _db.into(_db.games).insert(companion);
      return;
    }
    // only newer revisions win; keeps the first end time of a finished game
    await _db.transaction(() async {
      final current = await (_db.select(_db.games)..where((t) => t.id.equals(s.id))).getSingleOrNull();
      if (current == null || current.revision >= s.revision) return;
      await (_db.update(_db.games)..where((t) => t.id.equals(s.id))).write(
        companion.copyWith(endedAt: Value(current.endedAt ?? (g.isFinal ? now : null))),
      );
    });
  }

  /// Rows reduced to what the statistics need.
  Future<List<GameSummary>> summaries() async {
    final rows = await _db.select(_db.games).get();
    return [
      for (final r in rows)
        GameSummary(
          difficulty: Difficulty.values.byName(r.difficulty),
          daily: r.dailyDate != null,
          phase: GamePhase.values.byName(r.phase),
          outcome: GameOutcome.values.byName(r.outcome),
          mistakes: r.mistakes,
          hintCount: r.hintCount,
          activeMs: r.activeMs,
          continueUsed: r.continueUsed,
          continueSource: ContinueSource.values.byName(r.continueSource),
          failed: r.failedAt != null || r.mistakes >= mistakeLimit,
        ),
    ];
  }

  // ----------------------------------------------------------- settings --

  Future<String?> setting(String key) async => (await (_db.select(_db.settingsEntries)
            ..where((s) => s.settingKey.equals(key)))
          .getSingleOrNull())
      ?.settingValue;

  Future<void> setSetting(String key, String value) => _db
      .into(_db.settingsEntries)
      .insertOnConflictUpdate(SettingsEntriesCompanion.insert(settingKey: key, settingValue: value));
}
