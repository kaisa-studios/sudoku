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

/// Verified store purchases ("Werbung entfernen"). An entry exists only after the
/// verification confirmed the purchase; never a free-form "isPremium" flag.
/// Network problems never remove an entry, only a verified refund/revocation does
/// (Master-Prompt 10.7).
@DataClassName('EntitlementRow')
class Entitlements extends Table {
  TextColumn get productId => text()();

  /// google_play, app_store or demo (demo entries count only in demo builds)
  TextColumn get store => text()();

  /// verified or revoked
  TextColumn get state => text()();
  DateTimeColumn get verifiedAt => dateTime()();

  /// Store order / transaction id (no token, no personal data)
  TextColumn get reference => text().nullable()();

  @override
  Set<Column> get primaryKey => {productId, store};
}

@DriftDatabase(tables: [Games, SettingsEntries, Entitlements])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'tidy_sudoku'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // one `if (from < n)` block per version
          if (from < 2) await m.createTable(entitlements);
        },
      );

  /// Deletes games, history and statistics (Master-Prompt 9.4). Store purchases
  /// are not stored here and stay untouched.
  Future<void> deleteAllGameData() => transaction(() async {
        await delete(games).go();
      });
}
