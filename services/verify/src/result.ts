/** What the apps understand (see VERIFICATION_SERVICE.md and the apps' RemoteVerifier). */
export type Status = 'valid' | 'invalid' | 'revoked';

export type Code =
  | 'wrong_app'
  | 'wrong_product'
  | 'not_paid'
  | 'pending'
  | 'bad_signature'
  | 'wrong_environment'
  | 'unknown_token'
  | 'bad_request';

export type Verdict = { status: Status; productId: string; code?: Code };

/** The store or our own configuration could not answer: the app tries again later. */
export class Unavailable extends Error {}

export const valid = (productId: string): Verdict => ({ status: 'valid', productId });
export const revoked = (productId: string): Verdict => ({ status: 'revoked', productId });
export const invalid = (productId: string, code: Code): Verdict => ({ status: 'invalid', productId, code });
