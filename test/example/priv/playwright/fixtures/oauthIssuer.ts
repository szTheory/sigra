import { Page } from '@playwright/test';

export type GoogleClaims = {
  sub: string;
  email: string;
  email_verified: boolean;
  name?: string;
  picture?: string;
};

// NOTE: Playwright workers are pinned to 1 in playwright.config.ts, so the
// Application.put_env-mediated provider overrides set by /test/oauth_issuer/setup
// are safe across these specs. Do NOT enable parallel workers without
// rewiring this.

export async function setupIssuer(page: Page, claims: Partial<GoogleClaims>): Promise<void> {
  const result = (await page.evaluate(async (payload) => {
    const response = await fetch('/test/oauth_issuer/setup', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        provider: 'google',
        user: payload,
      }),
    });

    return {
      status: response.status,
      body: await response.json(),
    };
  }, claims)) as { status: number; body: { ok?: boolean; error?: string } };

  if (result.status !== 200 || result.body.ok !== true) {
    throw new Error(`oauth issuer setup failed: ${JSON.stringify(result)}`);
  }
}

export async function resetIssuer(page: Page): Promise<void> {
  const result = (await page.evaluate(async () => {
    const response = await fetch('/test/oauth_issuer/reset', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
      },
      body: JSON.stringify({}),
    });

    return {
      status: response.status,
      body: await response.json(),
    };
  })) as { status: number; body: { ok?: boolean; error?: string } };

  if (result.status !== 200 || result.body.ok !== true) {
    throw new Error(`oauth issuer reset failed: ${JSON.stringify(result)}`);
  }
}

export async function probeIdentities(
  page: Page,
  userEmail: string,
): Promise<{ count: number; rows: Array<{ provider: string; provider_uid: string }> }> {
  return (await page.evaluate(async (email) => {
    const url = `/test/db_probe?table=user_identities&user_email=${encodeURIComponent(email)}`;
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`db probe failed with ${response.status}`);
    }

    return response.json();
  }, userEmail)) as { count: number; rows: Array<{ provider: string; provider_uid: string }> };
}
