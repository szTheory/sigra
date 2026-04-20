import { test, expect } from '@playwright/test';
import { Buffer } from 'node:buffer';
import fs from 'node:fs/promises';
import path from 'node:path';

const hookSourcePath = path.resolve(
  __dirname,
  '../../../../../priv/templates/sigra.install/passkeys/passkey_hooks.js',
);
const browserHelperPath = path.resolve(
  __dirname,
  '../../../../../priv/templates/sigra.install/passkeys/passkey_browser.js',
);

/** UMD build loaded before inlined hooks (classic script cannot parse npm imports). */
const simpleWebAuthnUmdPath = path.resolve(
  __dirname,
  '../node_modules/@simplewebauthn/browser/dist/bundle/index.es5.umd.min.js',
);

function bytesToBase64Url(bytes: readonly number[]): string {
  return Buffer.from(Uint8Array.from(bytes)).toString('base64url');
}

function inlinePasskeyHookSource(
  browserHelperSource: string,
  hookSource: string,
): string {
  const browserHelperWithoutImports = browserHelperSource.replace(
    /^import\s+\{[\s\S]*?\}\s+from\s+["']@simplewebauthn\/browser["']\s*\n?/m,
    '',
  );
  const browserHelperWithoutExports = browserHelperWithoutImports
    .replace(/export class WebAuthnError/g, 'class WebAuthnError')
    .replace(/export const WebAuthnAbortService =/g, 'const WebAuthnAbortService =')
    .replace(/export async function conditionalMediationAvailable/g, 'async function conditionalMediationAvailable')
    .replace(/export async function startRegistration/g, 'async function startRegistration')
    .replace(/export async function startAuthentication/g, 'async function startAuthentication')
    .replace(/export function attachPasskeyLogin/g, 'function attachPasskeyLogin');
  const withoutImport = hookSource.replace(
    /^import\s+\{[\s\S]*?\}\s+from\s+"\.\/passkey_browser"\s*\n\n/m,
    '',
  );
  const withoutExports = withoutImport
    .replace(/export const PasskeyRegister =/g, 'const PasskeyRegister =')
    .replace(/export const PasskeyAuthenticate =/g, 'const PasskeyAuthenticate =')
    .replace(/export const PasskeyHooks =/g, 'const PasskeyHooks =');

  return (
    '(() => {\n' +
    'if (typeof globalThis.SimpleWebAuthnBrowser === "undefined") {\n' +
    '  throw new Error("SimpleWebAuthnBrowser UMD must be loaded before inlined passkey bundle");\n' +
    '}\n' +
    'const {\n' +
    '  browserSupportsWebAuthnAutofill,\n' +
    '  startAuthentication: browserStartAuthentication,\n' +
    '  startRegistration: browserStartRegistration,\n' +
    '} = globalThis.SimpleWebAuthnBrowser;\n' +
    browserHelperWithoutExports +
    '\n' +
    'window.WebAuthnError = WebAuthnError;\n' +
    'window.WebAuthnAbortService = WebAuthnAbortService;\n' +
    'window.startRegistration = startRegistration;\n' +
    'window.startAuthentication = startAuthentication;\n' +
    '})();\n' +
    withoutExports +
    '\n' +
    'window.PasskeyRegister = PasskeyRegister;\n' +
    'window.PasskeyAuthenticate = PasskeyAuthenticate;\n' +
    'window.PasskeyHooks = PasskeyHooks;\n'
  );
}

test('generated passkey hooks complete real browser registration and authentication with a virtual authenticator', async ({
  page,
}) => {
  const client = await page.context().newCDPSession(page);
  await client.send('WebAuthn.enable');

  const { authenticatorId } = await client.send('WebAuthn.addVirtualAuthenticator', {
    options: {
      protocol: 'ctap2',
      transport: 'internal',
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  });

  try {
    const [browserHelperSource, hookSource] = await Promise.all([
      fs.readFile(browserHelperPath, 'utf8'),
      fs.readFile(hookSourcePath, 'utf8'),
    ]);
    const inlinedHookSource = inlinePasskeyHookSource(browserHelperSource, hookSource);

    await page.goto('/');
    await page.addScriptTag({ path: simpleWebAuthnUmdPath });
    await page.addScriptTag({ content: inlinedHookSource });
    await expect
      .poll(async () =>
        page.evaluate(() => {
          const w = window as unknown as {
            PasskeyRegister?: { mounted?: unknown };
            PasskeyAuthenticate?: { mounted?: unknown };
          };
          return {
            reg: typeof w.PasskeyRegister?.mounted,
            auth: typeof w.PasskeyAuthenticate?.mounted,
          };
        }),
      )
      .toEqual({ reg: 'function', auth: 'function' });

    await page.evaluate(() => {
      const win = window as any;
      win.__sigraEvents = [];

      win.__mountSigraHook = (kind: 'register' | 'authenticate') => {
        const hookDef =
          kind === 'register' ? win.PasskeyRegister : win.PasskeyAuthenticate;
        const startEvent =
          kind === 'register'
            ? 'sigra:passkey-register:start'
            : 'sigra:passkey-authenticate:start';
        const listeners: Record<string, (payload: unknown) => unknown> = {};

        const hook = {
          ...hookDef,
          handleEvent(event: string, callback: (payload: unknown) => unknown) {
            listeners[event] = callback;
          },
          pushEvent(event: string, payload: unknown) {
            win.__sigraEvents.push({ event, payload });
          },
        };

        const mount = hookDef?.mounted;
        if (typeof mount !== 'function') {
          throw new Error(
            `Passkey hook missing mounted (kind=${kind}); keys=${Object.keys(hookDef ?? {}).join(',')}`,
          );
        }
        mount.call(hook);
        win.__sigraCurrentHook = hook;
        win.__sigraTrigger = (payload: unknown) => listeners[startEvent](payload);
      };
    });

    const regChallengeB64 = bytesToBase64Url([1, 2, 3, 4, 5, 6, 7, 8]);
    const regUserIdB64 = bytesToBase64Url([
      115, 105, 103, 114, 97, 45, 117, 115, 101, 114,
    ]);
    const authChallengeB64 = bytesToBase64Url([9, 10, 11, 12, 13, 14, 15, 16]);

    await page.evaluate(() => (window as any).__mountSigraHook('register'));
    await page.evaluate(
      ({ regChallengeB64: ch, regUserIdB64: uid }) =>
        (window as any).__sigraTrigger({
          options: {
            rp: { id: 'localhost', name: 'Sigra Test' },
            user: {
              id: uid,
              name: 'sigra@example.test',
              displayName: 'Sigra Test User',
            },
            challenge: ch,
            pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
            authenticatorSelection: {
              residentKey: 'required',
              userVerification: 'preferred',
            },
            timeout: 60_000,
            attestation: 'none',
          },
        }),
      { regChallengeB64, regUserIdB64 },
    );

    await page.waitForFunction(() => (window as any).__sigraEvents.length === 1);
    const registrationEvent = await page.evaluate(() => (window as any).__sigraEvents.shift());

    expect(registrationEvent.event).toBe('sigra:passkey-register:success');
    expect(registrationEvent.payload.response.id).toBeTruthy();
    expect(registrationEvent.payload.response.rawId).toBeTruthy();

    const credentialId = registrationEvent.payload.response.rawId;

    await page.evaluate(() => (window as any).__mountSigraHook('authenticate'));
    await page.evaluate(
      ({ credentialId: id, authChallengeB64: ch }) =>
        (window as any).__sigraTrigger({
          options: {
            rpId: 'localhost',
            challenge: ch,
            timeout: 60_000,
            userVerification: 'preferred',
            allowCredentials: [{ type: 'public-key', id }],
          },
        }),
      { credentialId, authChallengeB64 },
    );

    await page.waitForFunction(() => (window as any).__sigraEvents.length === 1);
    const authenticationEvent = await page.evaluate(() => (window as any).__sigraEvents.shift());

    expect(authenticationEvent.event).toBe('sigra:passkey-authenticate:success');
    expect(authenticationEvent.payload.response.id).toBeTruthy();
    expect(authenticationEvent.payload.response.rawId).toBe(credentialId);
  } finally {
    await client.send('WebAuthn.removeVirtualAuthenticator', { authenticatorId });
    await client.send('WebAuthn.disable');
  }
});
