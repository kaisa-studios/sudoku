import * as x509 from '@peculiar/x509';

import { invalid, revoked, valid, type Verdict } from './result';

/** SHA-256 fingerprint of "Apple Root CA - G3" (https://www.apple.com/certificateauthority/). */
export const APPLE_ROOT_CA_G3_SHA256 = '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179';

/** Apple marks the certificates of the App Store signing chain with these extensions. */
const LEAF_OID = '1.2.840.113635.100.6.11.1';
const INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

x509.cryptoProvider.set(crypto);

const ES256 = { name: 'ECDSA', namedCurve: 'P-256', hash: 'SHA-256' } as const;

function b64urlDecode(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

export class BadSignature extends Error {}

/**
 * Verifies a StoreKit 2 signed transaction (JWS, ES256, x5c chain) and returns its payload.
 * Chain: leaf → intermediate → root; the root must be Apple Root CA G3 (by fingerprint),
 * each certificate signed by the next, all valid at [now], Apple's marker extensions present.
 */
export async function verifyAppleJws(
  jws: string,
  options: { rootSha256?: string; now?: Date; requireAppleOids?: boolean } = {},
): Promise<Record<string, unknown>> {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new BadSignature('not a JWS');
  let header: { alg?: string; x5c?: string[] };
  try {
    header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
  } catch {
    throw new BadSignature('bad header');
  }
  if (header.alg !== 'ES256' || !Array.isArray(header.x5c) || header.x5c.length !== 3) {
    throw new BadSignature('unexpected header');
  }
  const [leaf, intermediate, root] = header.x5c.map((c) => new x509.X509Certificate(c));
  const now = options.now ?? new Date();

  const rootPrint = hex(await crypto.subtle.digest('SHA-256', root.rawData));
  if (rootPrint !== (options.rootSha256 ?? APPLE_ROOT_CA_G3_SHA256)) throw new BadSignature('unknown root');
  for (const cert of [leaf, intermediate, root]) {
    if (cert.notBefore > now || cert.notAfter < now) throw new BadSignature('certificate expired');
  }
  if (!(await intermediate.verify({ publicKey: root, signatureOnly: true }))) throw new BadSignature('chain');
  if (!(await leaf.verify({ publicKey: intermediate, signatureOnly: true }))) throw new BadSignature('chain');
  if (options.requireAppleOids !== false) {
    if (!leaf.getExtension(LEAF_OID) || !intermediate.getExtension(INTERMEDIATE_OID)) {
      throw new BadSignature('not an App Store certificate');
    }
  }

  const key = await leaf.publicKey.export(ES256, ['verify']);
  const ok = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    b64urlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!ok) throw new BadSignature('signature');
  return JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
}

/** Checks a verified transaction against the request. */
export function judgeAppleTransaction(
  t: Record<string, unknown>,
  request: { appId: string; productId: string; purchaseId?: string },
  production: boolean,
): Verdict {
  if (t.bundleId !== request.appId) return invalid(request.productId, 'wrong_app');
  if (t.productId !== request.productId) return invalid(request.productId, 'wrong_product');
  if (request.purchaseId && t.transactionId !== request.purchaseId && t.originalTransactionId !== request.purchaseId) {
    return invalid(request.productId, 'unknown_token');
  }
  const environment = t.environment;
  if (production ? environment !== 'Production' : !['Production', 'Sandbox', 'Xcode'].includes(String(environment))) {
    return invalid(request.productId, 'wrong_environment');
  }
  if (t.type !== undefined && t.type !== 'Non-Consumable') return invalid(request.productId, 'wrong_product');
  if (t.revocationDate) return revoked(request.productId);
  return valid(request.productId);
}
