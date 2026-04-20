import { test, expect } from '@playwright/test';
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

function inlinePasskeyHookSource(
  browserHelperSource: string,
  hookSource: string,
): string {
  const browserHelperWithoutExports = browserHelperSource
    .replace(/export class WebAuthnError/g, 'class WebAuthnError')
    .replace(/export const WebAuthnAbortService =/g, 'const WebAuthnAbortService =')
    .replace(/export async function startRegistration/g, 'async function startRegistration')
    .replace(/export async function startAuthentication/g, 'async function startAuthentication');
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
    await page.addScriptTag({ content: inlinedHookSource });
    await page.waitForFunction(() => {
      const w = window as unknown as {
        PasskeyRegister?: { mounted?: unknown };
        PasskeyAuthenticate?: { mounted?: unknown };
      };
      return (
        typeof w.PasskeyRegister?.mounted === 'function' &&
        typeof w.PasskeyAuthenticate?.mounted === 'function'
      );
    });

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

    await page.evaluate(() => (window as any).__mountSigraHook('register'));
    await page.evaluate(() =>
      (window as any).__sigraTrigger({
        options: {
          rp: { id: 'localhost', name: 'Sigra Test' },
          user: {
            id: [115, 105, 103, 114, 97, 45, 117, 115, 101, 114],
            name: 'sigra@example.test',
            displayName: 'Sigra Test User',
          },
          challenge: [1, 2, 3, 4, 5, 6, 7, 8],
          pubKeyCredParams: [{ type: 'public-key', alg: -7 }],
          authenticatorSelection: {
            residentKey: 'required',
            userVerification: 'preferred',
          },
          timeout: 60_000,
          attestation: 'none',
        },
      }),
    );

    await page.waitForFunction(() => (window as any).__sigraEvents.length === 1);
    const registrationEvent = await page.evaluate(() => (window as any).__sigraEvents.shift());

    expect(registrationEvent.event).toBe('sigra:passkey-register:success');
    expect(registrationEvent.payload.response.id).toBeTruthy();
    expect(registrationEvent.payload.response.rawId).toBeTruthy();

    const credentialId = registrationEvent.payload.response.rawId;

    await page.evaluate(() => (window as any).__mountSigraHook('authenticate'));
    await page.evaluate((id) =>
      (window as any).__sigraTrigger({
        options: {
          rpId: 'localhost',
          challenge: [9, 10, 11, 12, 13, 14, 15, 16],
          timeout: 60_000,
          userVerification: 'preferred',
          allowCredentials: [{ type: 'public-key', id }],
        },
      }),
    credentialId);

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
