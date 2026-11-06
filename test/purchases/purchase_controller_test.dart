import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/data/entitlement_repository.dart';
import 'package:sudoku/features/purchases/purchase_controller.dart';
import 'package:sudoku/features/purchases/store.dart';
import 'package:sudoku/features/purchases/verifier.dart';

import '../support.dart';

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A store whose purchase updates the test sends itself.
class ScriptedStore implements StoreGateway {
  final controller = StreamController<List<StorePurchase>>.broadcast();
  int buys = 0;
  int completed = 0;

  @override
  String get storeName => 'google_play';
  @override
  bool get isDemo => false;
  @override
  Stream<List<StorePurchase>> get purchaseUpdates => controller.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<StoreProduct>> loadProducts(Set<String> ids) async =>
      [const StoreProduct(id: removeAdsProductId, price: '2,49 €')];
  @override
  Future<bool> buy(String productId) async {
    buys++;
    return true;
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(StorePurchase purchase) async => completed++;

  void send(StorePurchaseStatus status, {String id = 'GPA.1'}) => controller.add([
        StorePurchase(
          productId: removeAdsProductId,
          status: status,
          purchaseId: status == StorePurchaseStatus.pending ? null : id,
          verificationData: 'token',
          source: 'google_play',
          needsCompletion: status != StorePurchaseStatus.pending,
        ),
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo store: buy → verified → owned, ad-free; price comes from the store', () async {
    final s = testServices();
    await _settle();
    final p = s.purchases;
    expect(p.state, RemoveAdsState.notOwned);
    expect(p.adFreeKnown, isTrue);
    expect(p.product!.price, '2,99 €');
    final messages = <PurchaseMessage>[];
    p.messages.listen(messages.add);
    await p.buy();
    await _settle();
    expect(p.state, RemoveAdsState.owned);
    expect(p.adFree, isTrue);
    expect(messages, contains(PurchaseMessage.unlocked));
  });

  test('pending payment grants nothing; the later PURCHASED update unlocks', () async {
    final store = ScriptedStore();
    final s = testServices(store: store, verifier: FakeVerifier(VerificationOutcome.valid));
    await _settle();
    final p = s.purchases;
    await p.buy();
    store.send(StorePurchaseStatus.pending);
    await _settle();
    expect(p.state, RemoveAdsState.pending);
    expect(p.adFree, isFalse);
    expect(store.completed, 0, reason: 'a pending purchase is never acknowledged early');
    store.send(StorePurchaseStatus.purchased);
    await _settle();
    expect(p.state, RemoveAdsState.owned);
    expect(store.completed, 1);
  });

  test('duplicate delivery is handled once', () async {
    final store = ScriptedStore();
    final verifier = FakeVerifier(VerificationOutcome.valid);
    final s = testServices(store: store, verifier: verifier);
    await _settle();
    store.send(StorePurchaseStatus.purchased);
    store.send(StorePurchaseStatus.purchased);
    await _settle();
    expect(verifier.calls, 1);
    expect(s.purchases.adFree, isTrue);
  });

  test('cancel is not an error', () async {
    final store = ScriptedStore();
    final s = testServices(store: store, verifier: FakeVerifier(VerificationOutcome.valid));
    await _settle();
    final messages = <PurchaseMessage>[];
    s.purchases.messages.listen(messages.add);
    await s.purchases.buy();
    store.send(StorePurchaseStatus.canceled);
    await _settle();
    expect(messages, [PurchaseMessage.canceled]);
    expect(s.purchases.state, RemoveAdsState.notOwned);
  });

  test('verification service not reachable: no store dialog is opened', () async {
    final store = ScriptedStore();
    final s = testServices(store: store, verifier: FakeVerifier(VerificationOutcome.valid, isReady: false));
    await _settle();
    final messages = <PurchaseMessage>[];
    s.purchases.messages.listen(messages.add);
    await s.purchases.buy();
    await _settle();
    expect(store.buys, 0);
    expect(messages, [PurchaseMessage.checkUnavailable]);
  });

  test('paid but check unavailable: "Prüfung ausstehend", no ads, no second purchase, kept across restart',
      () async {
    final db = memoryDb();
    final store = ScriptedStore();
    final verifier = FakeVerifier(VerificationOutcome.unavailable);
    final s = testServices(db: db, store: store, verifier: verifier);
    await _settle();
    store.send(StorePurchaseStatus.purchased);
    await _settle();
    final p = s.purchases;
    expect(p.state, RemoveAdsState.verifying);
    expect(p.paidUnverified, isTrue);
    expect(p.suppressAds, isTrue);
    expect(store.completed, 0, reason: 'not acknowledged before it is verified');
    await p.buy();
    expect(store.buys, 0, reason: 'already paid: checks again instead of selling twice');

    final again = testServices(db: db, store: ScriptedStore(), verifier: verifier);
    await _settle();
    expect(again.purchases.paidUnverified, isTrue);

    // the store delivers it again once the service is back
    verifier.outcome = VerificationOutcome.valid;
    store.send(StorePurchaseStatus.purchased);
    await _settle();
    expect(p.state, RemoveAdsState.owned);
    expect(p.paidUnverified, isFalse);
  });

  test('a network error never takes away a verified purchase; a confirmed refund does', () async {
    final db = memoryDb();
    await EntitlementRepository(db).grant(productId: removeAdsProductId, store: 'google_play');
    final store = ScriptedStore();
    final verifier = FakeVerifier(VerificationOutcome.unavailable);
    final s = testServices(db: db, store: store, verifier: verifier);
    await _settle();
    expect(s.purchases.adFree, isTrue, reason: 'offline from the local cache, no expiry');
    store.send(StorePurchaseStatus.restored, id: 'GPA.2');
    await _settle();
    expect(s.purchases.adFree, isTrue);

    verifier.outcome = VerificationOutcome.revoked;
    store.send(StorePurchaseStatus.restored, id: 'GPA.3');
    await _settle();
    expect(s.purchases.adFree, isFalse);
    expect(s.purchases.state, RemoveAdsState.revoked);
  });

  test('invalid purchase: nothing unlocked, not acknowledged', () async {
    final store = ScriptedStore();
    final s = testServices(store: store, verifier: FakeVerifier(VerificationOutcome.invalid));
    await _settle();
    store.send(StorePurchaseStatus.purchased);
    await _settle();
    expect(s.purchases.adFree, isFalse);
    expect(store.completed, 0);
  });

  test('restore in the demo store brings the purchase back on a "new device"', () async {
    final demo = DemoStoreGateway(delay: Duration.zero);
    final first = testServices(store: demo);
    await _settle();
    await first.purchases.buy();
    await _settle();
    final fresh = testServices(store: demo); // empty database, same store account
    await _settle();
    expect(fresh.purchases.adFree, isFalse);
    final messages = <PurchaseMessage>[];
    fresh.purchases.messages.listen(messages.add);
    await fresh.purchases.restore();
    await _settle();
    expect(fresh.purchases.adFree, isTrue);
  });
}
