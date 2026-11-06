import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'store.dart';

enum VerificationOutcome {
  /// The store confirmed the purchase for this app and product.
  valid,

  /// Not a valid purchase (wrong app/product, forged, never paid).
  invalid,

  /// Was valid, but refunded or revoked.
  revoked,

  /// Could not be checked right now (offline, service down): try again later, change nothing.
  unavailable,
}

class VerificationResult {
  const VerificationResult(this.outcome, {this.message});

  final VerificationOutcome outcome;
  final String? message;
}

/// Checks a purchase before anything is unlocked (see VERIFICATION_SERVICE.md).
abstract class EntitlementVerifier {
  Future<VerificationResult> verify({required String store, required StorePurchase purchase});

  /// Checked before a new purchase starts (10.5): if the service is not set up
  /// or not reachable, no store purchase dialog is opened.
  Future<bool> ready();
}

/// Accepts only purchases from the simulated demo store. Used in demo builds only.
class DemoVerifier implements EntitlementVerifier {
  const DemoVerifier();

  @override
  Future<VerificationResult> verify({required String store, required StorePurchase purchase}) async {
    final ok = store == 'demo' && purchase.source == 'demo' && allProductIds.contains(purchase.productId);
    return VerificationResult(ok ? VerificationOutcome.valid : VerificationOutcome.invalid);
  }

  @override
  Future<bool> ready() async => true;
}

/// Real store without a configured verification service: nothing can be unlocked;
/// purchases stay open in the store and are checked again once a service exists.
class UnconfiguredVerifier implements EntitlementVerifier {
  const UnconfiguredVerifier();

  @override
  Future<VerificationResult> verify({required String store, required StorePurchase purchase}) async =>
      const VerificationResult(VerificationOutcome.unavailable, message: 'no verification service configured');

  @override
  Future<bool> ready() async => false;
}

/// Talks to the small verification service over HTTPS. The service checks the
/// purchase with Apple/Google using secrets that never leave the server.
class RemoteVerifier implements EntitlementVerifier {
  RemoteVerifier(this.baseUrl, {http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  String get _base => baseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  Future<bool> ready() async {
    try {
      final r = await _client.get(Uri.parse('$_base/health')).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } on Object {
      return false;
    }
  }

  @override
  Future<VerificationResult> verify({required String store, required StorePurchase purchase}) async {
    final uri = Uri.parse('$_base/verify-purchase');
    try {
      final response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'store': store,
              'appId': appId,
              'productId': purchase.productId,
              'purchaseId': purchase.purchaseId,
              'verificationData': purchase.verificationData,
            }),
          )
          .timeout(timeout);
      if (response.statusCode >= 500 || response.statusCode == 429) {
        return VerificationResult(VerificationOutcome.unavailable, message: 'service ${response.statusCode}');
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return const VerificationResult(VerificationOutcome.unavailable, message: 'bad response');
      // the service must confirm exactly the product that was bought
      if (body['productId'] != purchase.productId) {
        return const VerificationResult(VerificationOutcome.invalid, message: 'product mismatch');
      }
      return switch (body['status']) {
        'valid' => const VerificationResult(VerificationOutcome.valid),
        'revoked' => const VerificationResult(VerificationOutcome.revoked),
        'invalid' => VerificationResult(VerificationOutcome.invalid, message: body['code'] as String?),
        _ => const VerificationResult(VerificationOutcome.unavailable, message: 'unknown status'),
      };
    } on TimeoutException {
      return const VerificationResult(VerificationOutcome.unavailable, message: 'timeout');
    } on Object catch (e) {
      // offline, DNS, TLS, malformed JSON: never a reason to unlock or to revoke
      return VerificationResult(VerificationOutcome.unavailable, message: e.runtimeType.toString());
    }
  }
}
