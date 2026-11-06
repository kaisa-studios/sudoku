import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sudoku/features/purchases/store.dart';
import 'package:sudoku/features/purchases/verifier.dart';

/// The app side of the contract with services/verify (same JSON, same status codes).
void main() {
  final purchase = StorePurchase(
    productId: removeAdsProductId,
    status: StorePurchaseStatus.purchased,
    purchaseId: 'GPA.1',
    verificationData: 'token',
  );

  test('health check names store and app', () async {
    Uri? asked;
    final v = RemoteVerifier('https://verify.test/', client: MockClient((r) async {
      asked = r.url;
      return http.Response('{"status":"ok"}', 200);
    }));
    expect(await v.ready(store: 'google_play'), isTrue);
    expect(asked.toString(), 'https://verify.test/health?store=google_play&appId=at.kaisasolutions.sudoku');
    final down = RemoteVerifier('https://verify.test', client: MockClient((_) async => http.Response('', 503)));
    expect(await down.ready(store: 'google_play'), isFalse);
  });

  test('answers of the service map to the outcomes', () async {
    Future<VerificationOutcome> answer(int code, Map<String, Object?> body) async {
      final v = RemoteVerifier('https://verify.test', client: MockClient((r) async {
        final sent = jsonDecode(r.body) as Map<String, Object?>;
        expect(sent['appId'], 'at.kaisasolutions.sudoku');
        expect(sent['verificationData'], 'token');
        return http.Response(jsonEncode(body), code);
      }));
      return (await v.verify(store: 'google_play', purchase: purchase)).outcome;
    }

    expect(await answer(200, {'status': 'valid', 'productId': removeAdsProductId}), VerificationOutcome.valid);
    expect(await answer(200, {'status': 'revoked', 'productId': removeAdsProductId}), VerificationOutcome.revoked);
    expect(await answer(400, {'status': 'invalid', 'productId': removeAdsProductId, 'code': 'pending'}),
        VerificationOutcome.invalid);
    expect(await answer(200, {'status': 'valid', 'productId': 'other'}), VerificationOutcome.invalid);
    expect(await answer(503, {'error': 'unavailable'}), VerificationOutcome.unavailable);
    expect(await answer(429, {'error': 'rate_limited'}), VerificationOutcome.unavailable);
  });
}
