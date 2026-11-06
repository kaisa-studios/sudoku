/**
 * Kaisa purchase verification service (Cloudflare Worker), shared by Tidy Sudoku and Orbella.
 *
 *   GET  /health?store=google_play&appId=…   200 when this store and app can be checked right now
 *   POST /verify-purchase                    {store, appId, productId, purchaseId?, verificationData}
 *        → 200 {status:"valid"|"revoked", productId} · 400 {status:"invalid", productId, code}
 *        → 503 / 429 when the app should try again later (never "invalid" for our own problems)
 *
 * Stateless: no accounts, no stored requests, no tokens in logs. The app acknowledges the
 * purchase at the store itself after a "valid" answer (VERIFICATION_SERVICE.md).
 */
import { judgeAppleTransaction, verifyAppleJws, BadSignature } from './apple';
import { readConfig, type Config, type Env } from './config';
import { verifyGoogle } from './google';
import { invalid, Unavailable, type Verdict } from './result';

const MAX_BODY = 16 * 1024;
const STORES = new Set(['google_play', 'app_store']);

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });

function log(event: Record<string, unknown>) {
  console.log(JSON.stringify(event)); // never tokens or receipts
}

export interface Deps {
  fetcher?: typeof fetch;
  appleRootSha256?: string;
  appleRequireOids?: boolean;
  now?: () => Date;
}

export async function handle(request: Request, env: Env, deps: Deps = {}): Promise<Response> {
  const url = new URL(request.url);
  let config: Config;
  try {
    config = readConfig(env);
  } catch {
    log({ event: 'config_error' });
    return json(503, { error: 'unavailable' });
  }

  if (request.method === 'GET' && url.pathname === '/health') {
    const store = url.searchParams.get('store');
    const appId = url.searchParams.get('appId');
    if (appId && !config.apps.has(appId)) return json(503, { status: 'unconfigured' });
    if (store === 'google_play' && !config.googleServiceAccount) return json(503, { status: 'unconfigured' });
    if (store && !STORES.has(store)) return json(503, { status: 'unconfigured' });
    return json(200, { status: 'ok', environment: config.production ? 'production' : 'test' });
  }

  if (request.method !== 'POST' || url.pathname !== '/verify-purchase') return json(404, { error: 'not_found' });

  if (env.RATE_LIMITER) {
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const { success } = await env.RATE_LIMITER.limit({ key: ip });
    if (!success) return json(429, { error: 'rate_limited' });
  }

  const started = Date.now();
  const rid = crypto.randomUUID().slice(0, 8);
  const length = Number(request.headers.get('content-length') ?? '0');
  if (length > MAX_BODY) return json(413, { error: 'too_large' });
  const text = await request.text();
  if (text.length > MAX_BODY) return json(413, { error: 'too_large' });

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(text);
  } catch {
    return json(400, { status: 'invalid', productId: '', code: 'bad_request' });
  }
  const str = (k: string, max: number) => (typeof body[k] === 'string' && (body[k] as string).length <= max ? (body[k] as string) : undefined);
  const store = str('store', 32);
  const appId = str('appId', 200);
  const productId = str('productId', 200) ?? '';
  const purchaseId = str('purchaseId', 200) || undefined;
  const token = str('verificationData', 12 * 1024);
  if (!store || !STORES.has(store) || !appId || !productId || !token) {
    return json(400, { status: 'invalid', productId, code: 'bad_request' });
  }

  let verdict: Verdict;
  try {
    const products = config.apps.get(appId);
    if (!products) {
      verdict = invalid(productId, 'wrong_app');
    } else if (!products.has(productId)) {
      verdict = invalid(productId, 'wrong_product');
    } else if (store === 'google_play') {
      if (!config.googleServiceAccount) throw new Unavailable('google not configured');
      verdict = await verifyGoogle(
        { appId, productId, purchaseId, token },
        { sa: config.googleServiceAccount, production: config.production, fetcher: deps.fetcher },
      );
    } else {
      try {
        const transaction = await verifyAppleJws(token, {
          rootSha256: deps.appleRootSha256,
          requireAppleOids: deps.appleRequireOids,
          now: deps.now?.(),
        });
        verdict = judgeAppleTransaction(transaction, { appId, productId, purchaseId }, config.production);
      } catch (e) {
        if (e instanceof BadSignature) verdict = invalid(productId, 'bad_signature');
        else throw e;
      }
    }
  } catch (e) {
    log({ event: 'unavailable', rid, store, appId, reason: e instanceof Error ? e.message : 'error' });
    return json(503, { error: 'unavailable' });
  }

  log({ event: 'verify', rid, store, appId, productId, status: verdict.status, code: verdict.code, ms: Date.now() - started });
  return json(verdict.status === 'invalid' ? 400 : 200, verdict);
}

export default {
  fetch: (request: Request, env: Env) => handle(request, env),
};
