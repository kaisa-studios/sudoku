import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The one product (Master-Prompt 10.5): "Werbung entfernen", non-consumable on
/// Apple, a one-time product on Google that is never consumed. Same id in both stores.
const removeAdsProductId = 'remove_ads_lifetime';
const allProductIds = {removeAdsProductId};

/// Application id sent to the verification service (Play package name / iOS bundle id).
const appId = 'at.kaisasolutions.sudoku';

class StoreProduct {
  const StoreProduct({required this.id, required this.price, this.title = ''});

  final String id;

  /// Localised price as delivered by the store (never hard-coded in real mode).
  final String price;
  final String title;
}

enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

/// Platform-neutral view of a purchase update.
class StorePurchase {
  StorePurchase({
    required this.productId,
    required this.status,
    this.purchaseId,
    this.verificationData = '',
    this.source = '',
    this.errorMessage,
    this.needsCompletion = false,
    this.platformData,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// Order id (Google) / transaction id (Apple); null for pending purchases.
  final String? purchaseId;

  /// Purchase token (Google) or signed transaction (Apple), only sent to the verification service.
  final String verificationData;
  final String source;
  final String? errorMessage;
  final bool needsCompletion;

  /// The original platform object, needed to complete the purchase.
  final Object? platformData;
}

/// The store as seen by the app. Real: [InAppPurchaseGateway]; development: [DemoStoreGateway].
abstract class StoreGateway {
  /// google_play, app_store or demo
  String get storeName;
  bool get isDemo => false;
  Stream<List<StorePurchase>> get purchaseUpdates;
  Future<bool> isAvailable();
  Future<List<StoreProduct>> loadProducts(Set<String> ids);

  /// Starts a purchase; the result arrives on [purchaseUpdates]. False if it could not start.
  Future<bool> buy(String productId);
  Future<void> restore();

  /// Acknowledges/finishes a purchase – only after verification and storage.
  Future<void> complete(StorePurchase purchase);
}

class InAppPurchaseGateway implements StoreGateway {
  InAppPurchaseGateway([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final _details = <String, ProductDetails>{};

  @override
  String get storeName => defaultTargetPlatform == TargetPlatform.iOS ? 'app_store' : 'google_play';

  @override
  bool get isDemo => false;

  @override
  Stream<List<StorePurchase>> get purchaseUpdates => _iap.purchaseStream.map((list) => [for (final p in list) _map(p)]);

  StorePurchase _map(PurchaseDetails p) => StorePurchase(
        productId: p.productID,
        status: switch (p.status) {
          PurchaseStatus.pending => StorePurchaseStatus.pending,
          PurchaseStatus.purchased => StorePurchaseStatus.purchased,
          PurchaseStatus.restored => StorePurchaseStatus.restored,
          PurchaseStatus.canceled => StorePurchaseStatus.canceled,
          PurchaseStatus.error => StorePurchaseStatus.error,
        },
        purchaseId: p.purchaseID,
        verificationData: p.verificationData.serverVerificationData,
        source: p.verificationData.source,
        errorMessage: p.error?.message,
        needsCompletion: p.pendingCompletePurchase,
        platformData: p,
      );

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> loadProducts(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    for (final d in response.productDetails) {
      _details[d.id] = d;
    }
    return [for (final d in response.productDetails) StoreProduct(id: d.id, price: d.price, title: d.title)];
  }

  @override
  Future<bool> buy(String productId) async {
    final details = _details[productId];
    if (details == null) return false;
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(StorePurchase purchase) async {
    final p = purchase.platformData;
    if (p is PurchaseDetails && p.pendingCompletePurchase) await _iap.completePurchase(p);
  }
}

/// Simulated store for development and test devices (STORE_MODE=demo). Shown in
/// the app as "Demo-Store"; prices are labelled as demo, nothing is charged.
class DemoStoreGateway implements StoreGateway {
  DemoStoreGateway({this.delay = const Duration(milliseconds: 600)});

  final Duration delay;
  final _controller = StreamController<List<StorePurchase>>.broadcast();
  final _owned = <String>{};
  var _counter = 0;

  /// Demo price, clearly labelled as demo in the app; the real price always comes from the store.
  static const prices = {removeAdsProductId: '1,99 €'};

  @override
  String get storeName => 'demo';

  @override
  bool get isDemo => true;

  @override
  Stream<List<StorePurchase>> get purchaseUpdates => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> loadProducts(Set<String> ids) async => [
        for (final id in ids)
          if (prices.containsKey(id)) StoreProduct(id: id, price: prices[id]!, title: id),
      ];

  @override
  Future<bool> buy(String productId) async {
    if (!prices.containsKey(productId)) return false;
    _controller.add([StorePurchase(productId: productId, status: StorePurchaseStatus.pending)]);
    Timer(delay, () {
      _owned.add(productId);
      _controller.add([
        StorePurchase(
          productId: productId,
          status: StorePurchaseStatus.purchased,
          purchaseId: 'DEMO-${++_counter}-$productId',
          verificationData: 'demo',
          source: 'demo',
          needsCompletion: true,
        ),
      ]);
    });
    return true;
  }

  @override
  Future<void> restore() async {
    Timer(delay, () {
      _controller.add([
        for (final id in _owned)
          StorePurchase(
            productId: id,
            status: StorePurchaseStatus.restored,
            purchaseId: 'DEMO-restore-$id',
            verificationData: 'demo',
            source: 'demo',
          ),
      ]);
    });
  }

  @override
  Future<void> complete(StorePurchase purchase) async {}
}
