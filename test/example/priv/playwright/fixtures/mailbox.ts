import { expect, type Page } from '@playwright/test';

type MailboxEmail = {
  html_body: string | null;
  inserted_at?: string | null;
  text_body: string | null;
  to: string[];
};

export type AuthLinkKind = 'confirmation' | 'magic_link' | 'password_reset';

const routePrefixes: Record<AuthLinkKind, string> = {
  confirmation: '/users/confirm/',
  magic_link: '/users/log_in/',
  password_reset: '/users/reset-password/',
};

const linkKinds: Record<AuthLinkKind, string> = {
  confirmation: 'confirmation',
  magic_link: 'magic link',
  password_reset: 'password reset',
};

function isMailboxEmail(value: unknown): value is MailboxEmail {
  if (!value || typeof value !== 'object') return false;

  const email = value as Partial<MailboxEmail>;
  return (
    Array.isArray(email.to) &&
    email.to.every((recipient) => typeof recipient === 'string') &&
    (email.html_body === null || typeof email.html_body === 'string') &&
    (email.text_body === null || typeof email.text_body === 'string') &&
    (email.inserted_at === undefined ||
      email.inserted_at === null ||
      typeof email.inserted_at === 'string')
  );
}

function isMailboxResponse(value: unknown): value is { data: MailboxEmail[] } {
  return (
    !!value &&
    typeof value === 'object' &&
    Array.isArray((value as { data?: unknown }).data) &&
    (value as { data: unknown[] }).data.every(isMailboxEmail)
  );
}

function extractAuthHref(email: MailboxEmail, kind: AuthLinkKind): string | null {
  const body = [email.html_body || '', email.text_body || ''].join('\n');
  const routePrefix = routePrefixes[kind].replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = body.match(
    new RegExp(`(?:https?:\\/\\/[^\\s"'<>]+)?${routePrefix}[^\\s"'<>]+`),
  );

  return match?.[0] ?? null;
}

function newestMatchingLink(
  emails: MailboxEmail[],
  recipient: string,
  kind: AuthLinkKind,
): string | null {
  return (
    emails
      .filter((email) => email.to.includes(recipient))
      .sort((left, right) => {
        const leftTime = Date.parse(left.inserted_at ?? '');
        const rightTime = Date.parse(right.inserted_at ?? '');
        return (Number.isNaN(rightTime) ? 0 : rightTime) - (Number.isNaN(leftTime) ? 0 : leftTime);
      })
      .map((email) => extractAuthHref(email, kind))
      .find((href): href is string => href !== null) ?? null
  );
}

async function readMailbox(page: Page): Promise<MailboxEmail[]> {
  const response = await page.evaluate(async () => {
    const mailboxResponse = await fetch('/dev/mailbox/json');
    const body = await mailboxResponse.json().catch(() => null);
    return { ok: mailboxResponse.ok, body };
  });

  if (!response.ok || !isMailboxResponse(response.body)) {
    throw new Error('Development mailbox did not return a valid JSON response');
  }

  return response.body.data;
}

function normalizeLink(href: string, pageUrl: string): string {
  const generatedHost = new URL(pageUrl);
  const link = new URL(href, generatedHost);
  link.protocol = generatedHost.protocol;
  link.host = generatedHost.host;
  return link.toString();
}

export async function extractAuthLink(
  page: Page,
  recipient: string,
  kind: AuthLinkKind,
): Promise<string> {
  let selectedHref: string | null = null;

  await expect
    .poll(
      async () => {
        try {
          selectedHref = newestMatchingLink(await readMailbox(page), recipient, kind);
          return selectedHref !== null;
        } catch {
          return false;
        }
      },
      {
        message: `No ${linkKinds[kind]} email found for ${recipient} in development mailbox JSON`,
        intervals: [250, 500, 1_000],
        timeout: 30_000,
      },
    )
    .toBe(true);

  if (!selectedHref) {
    throw new Error(`No ${linkKinds[kind]} email found for ${recipient}`);
  }

  return normalizeLink(selectedHref, page.url());
}

export const extractConfirmationLink = (page: Page, recipient: string) =>
  extractAuthLink(page, recipient, 'confirmation');

export const extractMagicLink = (page: Page, recipient: string) =>
  extractAuthLink(page, recipient, 'magic_link');

export const extractPasswordResetLink = (page: Page, recipient: string) =>
  extractAuthLink(page, recipient, 'password_reset');
