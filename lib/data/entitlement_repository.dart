import 'package:drift/drift.dart';

import 'app_database.dart';

enum EntitlementState { none, verified, revoked }

/// Local cache of verified purchases (works offline, no expiry, 10.7).
class EntitlementRepository {
  EntitlementRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _verified = 'verified';
  static const _revoked = 'revoked';

  Future<EntitlementState> state(String productId, String store) async {
    final row = await (_db.select(_db.entitlements)
          ..where((e) => e.productId.equals(productId) & e.store.equals(store)))
        .getSingleOrNull();
    return switch (row?.state) {
      _verified => EntitlementState.verified,
      _revoked => EntitlementState.revoked,
      _ => EntitlementState.none,
    };
  }

  /// Idempotent: granting an already verified product only refreshes the date.
  Future<void> grant({required String productId, required String store, String? reference}) =>
      _db.into(_db.entitlements).insertOnConflictUpdate(EntitlementsCompanion.insert(
            productId: productId,
            store: store,
            state: _verified,
            verifiedAt: _clock(),
            reference: Value(reference),
          ));

  /// Only after a verified refund/revocation – never because of network errors.
  Future<void> revoke({required String productId, required String store}) =>
      (_db.update(_db.entitlements)..where((e) => e.productId.equals(productId) & e.store.equals(store)))
          .write(EntitlementsCompanion(state: const Value(_revoked), verifiedAt: Value(_clock())));
}
