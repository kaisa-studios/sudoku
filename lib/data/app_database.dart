import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// One Sudoku game (regular or daily). The full play state lives in [state]
/// (JSON); the columns statistics and lookups need are mirrored next to it and
/// written in the same statement, so they can never disagree.
@DataClassName('GameRow')
class Games extends Table {
  TextColumn get id => text()();
  TextColumn get difficulty => text()();

  /// Local calendar day (yyyy-mm-dd) for daily puzzles, null for regular games.
  TextColumn get dailyDate => text().nullable()();

  /// 0 = easy, 1 = medium, 2 = hard daily puzzle.
  IntColumn get dailySlot => integer().nullable()();
  TextColumn get puzzle => text()();
  TextColumn get solution => text()();
  TextColumn get state => text()();
  TextColumn get phase => text()();
  TextColumn get outcome => text()();
  IntColumn get mistakes => integer()();
  IntColumn get hintCount => integer()();
  IntColumn get activeMs => integer()();
  BoolColumn get continueUsed => boolean()();
  TextColumn get continueSource => text()();
  DateTimeColumn get failedAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Monotonic per game; stale writes from an older revision are ignored.
  IntColumn get revision => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {dailyDate, dailySlot},
      ];
}

/// Small key/value store for settings (last difficulty, theme, …).
@DataClassName('SettingRow')
class SettingsEntries extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

@DriftDatabase(tables: [Games, SettingsEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'tidy_sudoku'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // future schema steps go here, one `if (from < n)` block per version
        },
      );

  /// Deletes games, history and statistics (Master-Prompt 9.4). Store purchases
  /// are not stored here and stay untouched.
  Future<void> deleteAllGameData() => transaction(() async {
        await delete(games).go();
      });
}
