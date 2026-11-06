import { beforeEach, describe, expect, it } from 'vitest';

import { handle, type Deps } from '../src/index';
import { resetTokenCache } from '../src/google';
import type { Env } from '../src/config';
import { makeChain, serviceAccount, signJws } from './helpers';

const APP = 'at.kaisasolutions.sudoku';
const PRODUCT = 'remove_ads_lifetime';
const APPS = JSON.stringify({ [APP]: [PRODUCT], 'at.kaisasolutions.orbella': ['pack_love', PRODUCT] });

const post = (body: unknown) =>
  new Request('https://verify.test/verify-purchase', { method: 'POST', body: JSON.stringify(body) });

async function call(env: Env, body: unknown, deps: Deps = {}) {
  const r = await handle(post(body), env, deps);
  return { status: r.status, body: (await r.json()) as Record<string, unknown> };
}

// ------------------------------------------------------------------- Google Play --

type Purchase = Record<string, unknown>;

function googleFetcher(purchase: Purchase | number, seen: string[] = []): typeof fetch {
  return (async (input: RequestInfo | URL) => {
    const url = String(input);
    seen.push(url);
    if (url.startsWith('https://oauth2.googleapis.com/token')) {
      return new Response(JSON.stringify({ access_token: 'at', expires_in: 3600 }));
    }
    if (typeof purchase === 'number') return new Response('{}', { status: purchase });
    return new Response(JSON.stringify(purchase));
  }) as typeof fetch;
}

const purchased = (extra: Purchase = {}): Purchase => ({
  productLineItem: [{ productId: PRODUCT }],
  purchaseStateContext: { purchaseState: 'PURCHASED' },
  orderId: 'GPA.1',
  ...extra,
});

describe('google_play', () => {
  let env: Env;
  const request = { store: 'google_play', appId: APP, productId: PRODUCT, purchaseId: 'GPA.1', verificationData: 'tok/en' };

  beforeEach(async () => {
    resetTokenCache();
    const { publicKey: _, ...sa } = await serviceAccount();
    env = { ENVIRONMENT: 'production', APPS, GOOGLE_SERVICE_ACCOUNT: JSON.stringify(sa) };
  });

  it('a paid purchase is valid; the token goes into the documented URL', async () => {
    const seen: string[] = [];
    const r = await call(env, request, { fetcher: googleFetcher(purchased(), seen) });
    expect(r).toEqual({ status: 200, body: { status: 'valid', productId: PRODUCT } });
    expect(seen[1]).toBe(
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${APP}/purchases/productsv2/tokens/tok%2Fen`,
    );
  });

  it('pending, cancelled, wrong product, other order, test purchase in production', async () => {
    const cases: [Purchase, number, Record<string, unknown>][] = [
      [purchased({ purchaseStateContext: { purchaseState: 'PENDING' } }), 400, { status: 'invalid', code: 'pending' }],
      [purchased({ purchaseStateContext: { purchaseState: 'CANCELLED' } }), 200, { status: 'revoked' }],
      [purchased({ productLineItem: [{ productId: 'pack_love' }] }), 400, { status: 'invalid', code: 'wrong_product' }],
      [purchased({ orderId: 'GPA.2' }), 400, { status: 'invalid', code: 'unknown_token' }],
      [purchased({ testPurchaseContext: { fopType: 'TEST' } }), 400, { status: 'invalid', code: 'wrong_environment' }],
    ];
    for (const [purchase, status, expected] of cases) {
      const r = await call(env, request, { fetcher: googleFetcher(purchase) });
      expect(r.status).toBe(status);
      expect(r.body).toMatchObject({ productId: PRODUCT, ...expected });
    }
  });

  it('test purchases are accepted only by the test environment', async () => {
    const r = await call({ ...env, ENVIRONMENT: 'test' }, request, {
      fetcher: googleFetcher(purchased({ testPurchaseContext: { fopType: 'TEST' } })),
    });
    expect(r.body.status).toBe('valid');
  });

  it('unknown token is invalid; our own access problems and Google outages mean "try again later"', async () => {
    expect((await call(env, request, { fetcher: googleFetcher(404) })).body).toMatchObject({ code: 'unknown_token' });
    for (const code of [401, 403, 429, 500, 503]) {
      const r = await call(env, request, { fetcher: googleFetcher(code) });
      expect(r.status).toBe(503);
    }
  });

  it('without service account: unavailable, and /health says so', async () => {
    const bare = { ENVIRONMENT: 'production', APPS };
    expect((await call(bare, request)).status).toBe(503);
    const h = await handle(new Request(`https://verify.test/health?store=google_play&appId=${APP}`), bare);
    expect(h.status).toBe(503);
    const ok = await handle(new Request(`https://verify.test/health?store=google_play&appId=${APP}`), env);
    expect(ok.status).toBe(200);
  });
});

// ------------------------------------------------------------------- App Store --

describe('app_store', () => {
  const env: Env = { ENVIRONMENT: 'production', APPS };
  const now = () => new Date('2026-11-06T12:00:00Z');
  const tx = (extra: Record<string, unknown> = {}) => ({
    bundleId: APP,
    productId: PRODUCT,
    transactionId: '2000001',
    originalTransactionId: '2000001',
    environment: 'Production',
    type: 'Non-Consumable',
    ...extra,
  });
  const req = (jws: string) => ({ store: 'app_store', appId: APP, productId: PRODUCT, purchaseId: '2000001', verificationData: jws });

  it('a correctly signed transaction from the Apple-shaped chain is valid', async () => {
    const chain = await makeChain();
    const r = await call(env, req(await signJws(tx(), chain.x5c, chain.leafKey)), { appleRootSha256: chain.rootSha256, now });
    expect(r).toEqual({ status: 200, body: { status: 'valid', productId: PRODUCT } });
  });

  it('signature, root, missing Apple markers and expiry are checked', async () => {
    const chain = await makeChain();
    const deps = { appleRootSha256: chain.rootSha256, now };
    const forged = await signJws(tx(), chain.x5c, chain.otherKey);
    expect((await call(env, req(forged), deps)).body).toMatchObject({ code: 'bad_signature' });
    // the real Apple root is required by default
    const real = await signJws(tx(), chain.x5c, chain.leafKey);
    expect((await call(env, req(real), { now })).body).toMatchObject({ code: 'bad_signature' });
    const noOids = await makeChain({ appleOids: false });
    expect(
      (await call(env, req(await signJws(tx(), noOids.x5c, noOids.leafKey)), { appleRootSha256: noOids.rootSha256, now })).body,
    ).toMatchObject({ code: 'bad_signature' });
    const old = await makeChain({ expired: true });
    expect(
      (await call(env, req(await signJws(tx(), old.x5c, old.leafKey)), { appleRootSha256: old.rootSha256, now })).body,
    ).toMatchObject({ code: 'bad_signature' });
    expect((await call(env, req('not.a.jws'), deps)).body).toMatchObject({ code: 'bad_signature' });
  });

  it('app, product, transaction, environment and refunds', async () => {
    const chain = await makeChain();
    const deps = { appleRootSha256: chain.rootSha256, now };
    const check = async (extra: Record<string, unknown>, e: Env = env) =>
      (await call(e, req(await signJws(tx(extra), chain.x5c, chain.leafKey)), deps)).body;
    expect(await check({ bundleId: 'com.other' })).toMatchObject({ code: 'wrong_app' });
    expect(await check({ productId: 'pack_love' })).toMatchObject({ code: 'wrong_product' });
    expect(await check({ transactionId: '9', originalTransactionId: '9' })).toMatchObject({ code: 'unknown_token' });
    expect(await check({ environment: 'Sandbox' })).toMatchObject({ code: 'wrong_environment' });
    expect(await check({ environment: 'Sandbox' }, { ...env, ENVIRONMENT: 'test' })).toMatchObject({ status: 'valid' });
    expect(await check({ revocationDate: 1762000000000 })).toMatchObject({ status: 'revoked' });
  });
});

// ------------------------------------------------------------------- requests --

describe('requests', () => {
  const env: Env = { ENVIRONMENT: 'production', APPS };

  it('only configured apps and products', async () => {
    const base = { store: 'app_store', verificationData: 'x' };
    expect((await call(env, { ...base, appId: 'com.evil', productId: PRODUCT })).body).toMatchObject({ code: 'wrong_app' });
    expect((await call(env, { ...base, appId: APP, productId: 'pack_love' })).body).toMatchObject({ code: 'wrong_product' });
  });

  it('malformed, oversized and unknown requests', async () => {
    expect((await handle(new Request('https://verify.test/verify-purchase', { method: 'POST', body: '{' }), env)).status).toBe(400);
    expect((await call(env, { store: 'amazon', appId: APP, productId: PRODUCT, verificationData: 'x' })).status).toBe(400);
    const big = 'x'.repeat(20_000);
    expect((await call(env, { store: 'app_store', appId: APP, productId: PRODUCT, verificationData: big })).status).toBe(413);
    expect((await handle(new Request('https://verify.test/'), env)).status).toBe(404);
  });

  it('rate limit answers 429', async () => {
    const limited: Env = { ...env, RATE_LIMITER: { limit: async () => ({ success: false }) } };
    expect((await call(limited, { store: 'app_store', appId: APP, productId: PRODUCT, verificationData: 'x' })).status).toBe(429);
  });

  it('logs never contain the token', async () => {
    const lines: string[] = [];
    const original = console.log;
    console.log = (s: string) => lines.push(s);
    try {
      await call(env, { store: 'app_store', appId: APP, productId: PRODUCT, verificationData: 'SECRET-TOKEN' });
    } finally {
      console.log = original;
    }
    expect(lines.join('\n')).not.toContain('SECRET-TOKEN');
    expect(lines.length).toBeGreaterThan(0);
  });
});
