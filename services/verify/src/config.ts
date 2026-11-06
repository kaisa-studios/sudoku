/** Configuration from the Worker's variables and secrets (wrangler.toml / `wrangler secret put`). */
export interface Env {
  /** "production" accepts only real purchases; "test" also accepts test/sandbox purchases. */
  ENVIRONMENT: string;
  /** JSON: { "<app id>": ["<product id>", …] } – the only apps and products this service vouches for. */
  APPS: string;
  /** Secret: the Google Cloud service account key (JSON) linked in the Play Console. */
  GOOGLE_SERVICE_ACCOUNT?: string;
  /** Optional Cloudflare rate limiting binding. */
  RATE_LIMITER?: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export interface Config {
  production: boolean;
  apps: Map<string, Set<string>>;
  googleServiceAccount?: ServiceAccount;
}

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

export function readConfig(env: Env): Config {
  const apps = new Map<string, Set<string>>();
  const raw = JSON.parse(env.APPS || '{}') as Record<string, unknown>;
  for (const [app, products] of Object.entries(raw)) {
    if (Array.isArray(products)) apps.set(app, new Set(products.filter((p): p is string => typeof p === 'string')));
  }
  let googleServiceAccount: ServiceAccount | undefined;
  if (env.GOOGLE_SERVICE_ACCOUNT) {
    const sa = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT) as ServiceAccount;
    if (sa.client_email && sa.private_key) googleServiceAccount = sa;
  }
  // anything but an explicit "test" is production: the safe default
  return { production: env.ENVIRONMENT !== 'test', apps, googleServiceAccount };
}
