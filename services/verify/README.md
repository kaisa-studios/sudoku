# Kaisa-Kaufprüfdienst

Gemeinsamer Dienst für Tidy Sudoku und Orbella (DECISIONS D3/D14). Er bestätigt einen Kauf nur, wenn der
Store (Google Play bzw. Apple) ihn bestätigt. Keine Konten, keine gespeicherten Anfragen, keine Tokens in
Protokollen. Die App bestätigt den Kauf danach selbst beim Store (Acknowledgement).

| Weg | Antwort |
| --- | --- |
| `GET /health?store=google_play&appId=…` | 200, wenn dieser Store für diese App gerade geprüft werden kann; sonst 503 (die App öffnet dann keinen Kaufdialog) |
| `POST /verify-purchase` `{store, appId, productId, purchaseId, verificationData}` | 200 `valid`/`revoked`, 400 `invalid` + `code`, 503/429 = später erneut |

- **Google Play:** Purchase-Token → `purchases.productsv2.getproductpurchasev2`. Gekauft = gültig, ausstehend =
  ungültig (`pending`), storniert = widerrufen. Testkäufe nur in der Testumgebung.
- **Apple:** signierte StoreKit-2-Transaktion (JWS). Kette Blatt → Zwischenzertifikat → Apple Root CA G3
  (Fingerabdruck), Apple-Kennzeichen in den Zertifikaten, Gültigkeit, Signatur; dann App, Produkt,
  Transaktion, Umgebung (Sandbox nur im Test), Widerruf.
- **Missbrauchsschutz:** nur eingetragene Apps/Produkte, Größenlimits, Rate Limit 30/min je Absender.

## Tests

```
npm ci && npm test        # 12 Tests, auch in GitHub Actions (Workflow „Prüfdienst“)
```

## Einrichtung (nach Freigabe)

1. Cloudflare-Konto anlegen (Workers Free reicht: 100.000 Anfragen pro Tag).
2. `npx wrangler login`, dann `npx wrangler deploy --env test` und `--env production`.
3. Google: Dienstkonto in der Google Cloud anlegen, in der Play Console unter „Nutzer und Berechtigungen“
   mit Leserechten für Finanzdaten/Bestellungen verknüpfen, JSON-Schlüssel als Geheimnis hinterlegen:
   `npx wrangler secret put GOOGLE_SERVICE_ACCOUNT --env production` (und `--env test`).
4. Apple braucht keinen Schlüssel für die Prüfung (Signaturprüfung). Die iOS-App muss StoreKit 2 verwenden,
   damit sie die signierte Transaktion sendet.
5. Adresse in den Release-Build eintragen: `VERIFIER_URL=https://kaisa-verify.<konto>.workers.dev`.

Später (zweiter Schritt): Abgleich von Rückerstattungen (Voided Purchases API / App Store Server API).
