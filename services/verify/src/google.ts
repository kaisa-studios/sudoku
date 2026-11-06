import type { ServiceAccount } from './config';
import { invalid, revoked, Unavailable, valid, type Verdict } from './result';

const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const TOKEN_URI = 'https://oauth2.googleapis.com/token';

let cachedToken: { value: string; expires: number; email: string } | undefined;

const b64url = (data: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

/** OAuth access token for the service account (signed JWT grant, RS256). Cached until shortly before expiry. */
export async function accessToken(sa: ServiceAccount, fetcher: typeof fetch = fetch, now = Date.now()): Promise<string> {
  if (cachedToken && cachedToken.email === sa.client_email && cachedToken.expires - 60_000 > now) return cachedToken.value;
  const iat = Math.floor(now / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(
    JSON.stringify({ iss: sa.client_email, scope: SCOPE, aud: sa.token_uri ?? TOKEN_URI, iat, exp: iat + 3600 }),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`));
  const response = await fetcher(sa.token_uri ?? TOKEN_URI, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!response.ok) throw new Unavailable(`google token ${response.status}`);
  const body = (await response.json()) as { access_token?: string; expires_in?: number };
  if (!body.access_token) throw new Unavailable('google token missing');
  cachedToken = { value: body.access_token, expires: now + (body.expires_in ?? 3600) * 1000, email: sa.client_email };
  return body.access_token;
}

export function resetTokenCache() {
  cachedToken = undefined;
}

interface ProductPurchaseV2 {
  productLineItem?: { productId?: string }[];
  purchaseStateContext?: { purchaseState?: string };
  testPurchaseContext?: unknown;
  orderId?: string;
}

/**
 * Checks a one-time purchase with the Google Play Developer API
 * (purchases.productsv2.getproductpurchasev2). The app acknowledges the purchase itself
 * after a "valid" answer; this service never acknowledges or consumes.
 */
export async function verifyGoogle(
  request: { appId: string; productId: string; purchaseId?: string; token: string },
  options: { sa: ServiceAccount; production: boolean; fetcher?: typeof fetch },
): Promise<Verdict> {
  const fetcher = options.fetcher ?? fetch;
  const auth = await accessToken(options.sa, fetcher);
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(request.appId)}/purchases/productsv2/tokens/${encodeURIComponent(request.token)}`;
  const response = await fetcher(url, { headers: { authorization: `Bearer ${auth}` } });
  if (response.status === 404 || response.status === 410) return invalid(request.productId, 'unknown_token');
  if (response.status === 400) return invalid(request.productId, 'unknown_token');
  // 401/403 (our access), 429 and 5xx: not the buyer's fault – the app asks again later
  if (!response.ok) throw new Unavailable(`google purchase ${response.status}`);
  const p = (await response.json()) as ProductPurchaseV2;

  if (!(p.productLineItem ?? []).some((item) => item.productId === request.productId)) {
    return invalid(request.productId, 'wrong_product');
  }
  if (p.testPurchaseContext && options.production) return invalid(request.productId, 'wrong_environment');
  if (request.purchaseId && p.orderId && request.purchaseId !== p.orderId) {
    return invalid(request.productId, 'unknown_token');
  }
  switch (p.purchaseStateContext?.purchaseState) {
    case 'PURCHASED':
      return valid(request.productId);
    case 'PENDING':
      return invalid(request.productId, 'pending');
    case 'CANCELLED':
      return revoked(request.productId);
    default:
      return invalid(request.productId, 'not_paid');
  }
}
