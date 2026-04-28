import { Page } from '@playwright/test';

const appBaseUrl = process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000';

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
  const response = await page.request.post(`${appBaseUrl}/test/oauth_issuer/setup`, {
    data: {
      provider: 'google',
      user: claims,
    },
  });

  const text = await response.text();
  const result = {
    status: response.status(),
    text,
    body: text ? JSON.parse(text) : {},
  } as {
    status: number;
    text: string;
    body: { ok?: boolean; error?: string };
  };

  if (result.status !== 200 || result.body.ok !== true) {
    throw new Error(`oauth issuer setup failed: ${JSON.stringify(result)}`);
  }
}

export async function resetIssuer(page: Page): Promise<void> {
  const response = await page.request.post(`${appBaseUrl}/test/oauth_issuer/reset`, {
    data: {},
  });

  const text = await response.text();
  const result = {
    status: response.status(),
    text,
    body: text ? JSON.parse(text) : {},
  } as { status: number; text: string; body: { ok?: boolean; error?: string } };

  if (result.status !== 200 || result.body.ok !== true) {
    throw new Error(`oauth issuer reset failed: ${JSON.stringify(result)}`);
  }
}

export async function probeIdentities(
  page: Page,
  userEmail: string,
): Promise<{ count: number; rows: Array<{ provider: string; provider_uid: string }> }> {
  const response = await page.request.get(`${appBaseUrl}/test/db_probe`, {
    params: {
      table: 'user_identities',
      user_email: userEmail,
    },
  });

  if (!response.ok()) {
    throw new Error(`db probe failed with ${response.status()}`);
  }

  return (await response.json()) as {
    count: number;
    rows: Array<{ provider: string; provider_uid: string }>;
  };
}

export async function probeBackupCodeValidity(
  page: Page,
  userEmail: string,
  submittedCode: string,
): Promise<{ current_match: boolean; remaining: number; hash_prefix: string }> {
  const response = await page.request.get(`${appBaseUrl}/test/db_probe`, {
    params: {
      table: 'user_backup_codes',
      user_email: userEmail,
      submitted_code: submittedCode,
    },
  });

  if (!response.ok()) {
    throw new Error(`backup code probe failed with ${response.status()}`);
  }

  return (await response.json()) as {
    current_match: boolean;
    remaining: number;
    hash_prefix: string;
  };
}

export async function probeAuditEvent(
  page: Page,
  userEmail: string,
  action: string,
): Promise<{
  count: number;
  rows: Array<{
    action: string;
    outcome: string;
    actor_id: string | null;
    target_id: string | null;
    effective_user_id: string | null;
    inserted_at: string;
  }>;
}> {
  const response = await page.request.get(`${appBaseUrl}/test/db_probe`, {
    params: {
      table: 'audit_events',
      user_email: userEmail,
      action,
    },
  });

  if (!response.ok()) {
    throw new Error(`audit event probe failed with ${response.status()}`);
  }

  return (await response.json()) as {
    count: number;
    rows: Array<{
      action: string;
      outcome: string;
      actor_id: string | null;
      target_id: string | null;
      effective_user_id: string | null;
      inserted_at: string;
    }>;
  };
}
