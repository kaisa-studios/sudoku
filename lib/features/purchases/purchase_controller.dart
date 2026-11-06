// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/config.dart';
import '../../data/entitlement_repository.dart';
import '../../data/game_repository.dart';
import '../ads/ad_coordinator.dart';
import 'store.dart';
import 'verifier.dart';

/// Purchase states of "Werbung entfernen" (Master-Prompt 10.5).
enum RemoveAdsState { unknown, notOwned, pending, verifying, owned, revoked, error }

/// One-off feedback for the UI (snackbar).
enum PurchaseMessage {
  unlocked,
  canceled,
  failed,
  verificationFailed,

  /// Paid, but the check could not run yet (offline / service down).
  paidUnverified,

  /// The verification service is not reachable: no purchase was started.
  checkUnavailable,
  restoredOwned,
  restoredNothing,
}

EntitlementVerifier defaultVerifier() {
  if (AppConfig.isDemoStore) return const DemoVerifier();
  if (AppConfig.verifierUrl.isEmpty) return const UnconfiguredVerifier();
  return RemoteVerifier(AppConfig.verifierUrl);
}

StoreGateway defaultStore() => AppConfig.isDemoStore ? DemoStoreGateway() : InAppPurchaseGateway();

/// Store, verification and the local entitlement in one place. The purchase
/// listener starts with the app (purchases can arrive at any time: pending
/// payment finished, new device, redelivery).
class PurchaseController extends ChangeNotifier implements AdFreeSource {
  PurchaseController({
    required StoreGateway store,
    required EntitlementVerifier verifier,
    required EntitlementRepository entitlements,
    required GameRepository settings,
    this.restoreSettle = const Duration(seconds: 2),
  })  : _store = store,
        _verifier = verifier,
        _entitlements = entitlements,
        _settings = settings;

  final StoreGateway _store;
  final EntitlementVerifier _verifier;
  final EntitlementRepository _entitlements;
  final GameRepository _settings;
  final Duration restoreSettle;

  StreamSubscription<List<StorePurchase>>? _subscription;
  final _messages = StreamController<PurchaseMessage>.broadcast();

  /// Purchase updates already handled (stores may deliver the same update twice).
  final _handled = <String>{};

  static const _kUnverified = 'iap.paidUnverified';

  EntitlementState _entitlement = EntitlementState.none;
  bool _loaded = false;
  bool _pendingPayment = false;
  bool _verifying = false;
  bool _starting = false;
  bool _restoring = false;
  bool _paidUnverified = false;
  bool _lastFailed = false;

  bool productsLoading = true;
  StoreProduct? product;

  bool get isDemo => _store.isDemo;
  Stream<PurchaseMessage> get messages => _messages.stream;
  bool get restoring => _restoring;

  /// Paid at the store, the check is still outstanding – no second purchase needed.
  bool get paidUnverified => _paidUnverified;

  /// A purchase is starting or running: the buy button is disabled (double tap).
  bool get busy => _starting || _pendingPayment || _verifying;

  RemoveAdsState get state {
    if (!_loaded) return RemoveAdsState.unknown;
    if (_entitlement == EntitlementState.verified) return RemoveAdsState.owned;
    if (_verifying || _paidUnverified) return RemoveAdsState.verifying;
    if (_pendingPayment) return RemoveAdsState.pending;
    if (_lastFailed) return RemoveAdsState.error;
    if (_entitlement == EntitlementState.revoked) return RemoveAdsState.revoked;
    return RemoveAdsState.notOwned;
  }

  @override
  bool get adFreeKnown => _loaded;
  @override
  bool get adFree => _entitlement == EntitlementState.verified;
  @override
  bool get suppressAds => _verifying || _restoring || _paidUnverified;

  /// Loads the local entitlement first (ads wait for it), then talks to the store.
  Future<void> start() async {
    _subscription ??= _store.purchaseUpdates.listen((list) async {
      for (final p in list) {
        await _handle(p);
      }
    });
    try {
      _entitlement = await _entitlements.state(removeAdsProductId, _store.storeName);
      _paidUnverified = await _settings.setting(_kUnverified) == 'true' && _entitlement != EntitlementState.verified;
    } on Object {
      // unreadable: treated as not bought; a restore brings it back
    }
    _loaded = true;
    notifyListeners();
    unawaited(loadProducts());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messages.close();
    super.dispose();
  }

  void _emit(PurchaseMessage m) {
    if (!_messages.isClosed) _messages.add(m);
  }

  Future<void> loadProducts() async {
    productsLoading = true;
    notifyListeners();
    try {
      final available = await _store.isAvailable();
      final products = available ? await _store.loadProducts(allProductIds) : const <StoreProduct>[];
      product = products.where((p) => p.id == removeAdsProductId).firstOrNull;
    } on Object {
      product = null;
    }
    productsLoading = false;
    notifyListeners();
  }

  Future<void> buy() async {
    if (busy || adFree) return; // double tap, or already owned
    if (_paidUnverified) {
      await restore(); // already paid: check again instead of buying twice
      return;
    }
    final p = product;
    if (p == null) {
      _fail();
      return;
    }
    _starting = true;
    _lastFailed = false;
    notifyListeners();
    try {
      // no store dialog while the purchase cannot be checked (10.5)
      if (!await _verifier.ready(store: _store.storeName)) {
        _emit(PurchaseMessage.checkUnavailable);
        return;
      }
      if (!await _store.buy(p.id)) _fail();
    } on Object {
      _fail();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// Explicit, user-initiated restore (10.7).
  Future<void> restore() async {
    if (_restoring) return;
    _restoring = true;
    notifyListeners();
    try {
      await _store.restore();
      // results arrive on the purchase stream; give the store a moment
      await Future<void>.delayed(restoreSettle);
      _emit(adFree ? PurchaseMessage.restoredOwned : PurchaseMessage.restoredNothing);
    } on Object {
      _emit(PurchaseMessage.failed);
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  void _fail() {
    _lastFailed = true;
    notifyListeners();
    _emit(PurchaseMessage.failed);
  }

  Future<void> _handle(StorePurchase p) async {
    if (p.productId != removeAdsProductId) {
      if (p.needsCompletion) await _safeComplete(p);
      return;
    }
    final key = '${p.purchaseId ?? p.productId}:${p.status.name}';
    if (p.status != StorePurchaseStatus.pending && !_handled.add(key)) return; // duplicate delivery
    switch (p.status) {
      case StorePurchaseStatus.pending:
        // no entitlement for a pending payment (10.5)
        // shown as a lasting note in the settings, no extra message
        _pendingPayment = true;
        notifyListeners();
      case StorePurchaseStatus.canceled:
        _pendingPayment = false;
        notifyListeners();
        _emit(PurchaseMessage.canceled); // not a technical error
        if (p.needsCompletion) await _safeComplete(p);
      case StorePurchaseStatus.error:
        _pendingPayment = false;
        _fail();
        if (p.needsCompletion) await _safeComplete(p);
      case StorePurchaseStatus.purchased:
      case StorePurchaseStatus.restored:
        await _verifyAndGrant(p, key);
    }
  }

  Future<void> _verifyAndGrant(StorePurchase p, String key) async {
    _pendingPayment = false;
    _verifying = true;
    notifyListeners();
    final result = await _verifier.verify(store: _store.storeName, purchase: p);
    switch (result.outcome) {
      case VerificationOutcome.valid:
        // store the entitlement first, then acknowledge: a crash in between only
        // leads to a repeated (idempotent) delivery, never to a lost purchase
        await _entitlements.grant(productId: p.productId, store: _store.storeName, reference: p.purchaseId);
        _entitlement = EntitlementState.verified;
        await _setPaidUnverified(false);
        await _safeComplete(p);
        if (p.status == StorePurchaseStatus.purchased) _emit(PurchaseMessage.unlocked);
      case VerificationOutcome.revoked:
        await _entitlements.revoke(productId: p.productId, store: _store.storeName);
        if (_entitlement == EntitlementState.verified) _entitlement = EntitlementState.revoked;
        await _setPaidUnverified(false);
        await _safeComplete(p);
      case VerificationOutcome.invalid:
        // not acknowledged: Google refunds unacknowledged purchases automatically
        await _setPaidUnverified(false);
        _emit(PurchaseMessage.verificationFailed);
      case VerificationOutcome.unavailable:
        // keep the purchase open; the store delivers it again (next start / restore).
        // An already verified entitlement stays (a network error is no revocation).
        _handled.remove(key);
        if (_entitlement != EntitlementState.verified) {
          await _setPaidUnverified(true);
          _emit(PurchaseMessage.paidUnverified);
        }
    }
    _verifying = false;
    notifyListeners();
  }

  Future<void> _setPaidUnverified(bool value) async {
    _paidUnverified = value;
    try {
      await _settings.setSetting(_kUnverified, '$value');
    } on Object {
      // only affects the hint after a restart
    }
  }

  Future<void> _safeComplete(StorePurchase p) async {
    try {
      await _store.complete(p);
    } on Object {
      // the store will deliver the purchase again; the entitlement is already stored
    }
  }
}
