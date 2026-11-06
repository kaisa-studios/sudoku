import * as x509 from '@peculiar/x509';

x509.cryptoProvider.set(crypto);

const enc = (s: string) => new TextEncoder().encode(s);
export const b64url = (data: ArrayBuffer | Uint8Array | string) => {
  const bytes = typeof data === 'string' ? enc(data) : new Uint8Array(data);
  return Buffer.from(bytes).toString('base64url');
};

const EC = { name: 'ECDSA', namedCurve: 'P-256', hash: 'SHA-256' } as const;
const NULL_VALUE = new Uint8Array([5, 0]);

/** A test certificate chain shaped like Apple's (leaf and intermediate marker extensions). */
export async function makeChain(opts: { appleOids?: boolean; expired?: boolean } = {}) {
  const rootKeys = (await crypto.subtle.generateKey(EC, true, ['sign', 'verify'])) as CryptoKeyPair;
  const interKeys = (await crypto.subtle.generateKey(EC, true, ['sign', 'verify'])) as CryptoKeyPair;
  const leafKeys = (await crypto.subtle.generateKey(EC, true, ['sign', 'verify'])) as CryptoKeyPair;
  const notBefore = new Date('2025-01-01');
  const notAfter = opts.expired ? new Date('2025-06-01') : new Date('2035-01-01');
  const root = await x509.X509CertificateGenerator.createSelfSigned({
    serialNumber: '01', name: 'CN=Test Root', notBefore, notAfter, keys: rootKeys, signingAlgorithm: EC,
    extensions: [new x509.BasicConstraintsExtension(true, undefined, true)],
  });
  const oids = opts.appleOids !== false;
  const inter = await x509.X509CertificateGenerator.create({
    serialNumber: '02', subject: 'CN=Test Intermediate', issuer: root.subject, notBefore, notAfter,
    signingKey: rootKeys.privateKey, publicKey: interKeys.publicKey, signingAlgorithm: EC,
    extensions: [
      new x509.BasicConstraintsExtension(true, 0, true),
      ...(oids ? [new x509.Extension('1.2.840.113635.100.6.2.1', false, NULL_VALUE)] : []),
    ],
  });
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: '03', subject: 'CN=Test Leaf', issuer: inter.subject, notBefore, notAfter,
    signingKey: interKeys.privateKey, publicKey: leafKeys.publicKey, signingAlgorithm: EC,
    extensions: oids ? [new x509.Extension('1.2.840.113635.100.6.11.1', false, NULL_VALUE)] : [],
  });
  const rootSha256 = Buffer.from(await crypto.subtle.digest('SHA-256', root.rawData)).toString('hex');
  const x5c = [leaf, inter, root].map((c) => Buffer.from(c.rawData).toString('base64'));
  return { x5c, rootSha256, leafKey: leafKeys.privateKey, otherKey: interKeys.privateKey };
}

export async function signJws(payload: unknown, x5c: string[], key: CryptoKey) {
  const head = b64url(JSON.stringify({ alg: 'ES256', x5c }));
  const body = b64url(JSON.stringify(payload));
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc(`${head}.${body}`));
  return `${head}.${body}.${b64url(sig)}`;
}

export async function serviceAccount() {
  const keys = (await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  )) as CryptoKeyPair;
  const der = Buffer.from(await crypto.subtle.exportKey('pkcs8', keys.privateKey)).toString('base64');
  const pem = `-----BEGIN PRIVATE KEY-----\n${der.match(/.{1,64}/g)!.join('\n')}\n-----END PRIVATE KEY-----\n`;
  return { client_email: 'verify@test.iam.gserviceaccount.com', private_key: pem, publicKey: keys.publicKey };
}
