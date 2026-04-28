import { expect, test } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';
import { probeIdentities, resetIssuer, setupIssuer } from '../fixtures/oauthIssuer';

type MailboxEmail = {
  html_body: string | null;
  inserted_at?: string | null;
  subject: string;
  text_body: string | null;
  to: string[];
};

async function waitForLiveViewReady(page: import('@playwright/test').Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function registerAndConfirm(page: import('@playwright/test').Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.locator('#registration_form_email').fill(email);
  await page.locator('#registration_form_password').fill(password);
  await expect(page.locator('#registration_form_email')).toHaveValue(email);
  await page.getByRole('button', { name: 'Create an account' }).click();
  await expect(page).toHaveURL('/');

  const confirmHref = await extractConfirmationLink(page, email);
  await page.goto(confirmHref);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);
  await page.context().clearCookies();
}

async function waitForProviderLinkedEmail(
  page: import('@playwright/test').Page,
  recipient: string,
): Promise<MailboxEmail> {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const mailbox = (await page.evaluate(async () => {
      const response = await fetch('/dev/mailbox/json');
      return response.json();
    })) as { data: MailboxEmail[] };

    const linkedEmail = mailbox.data
      .filter((email) => email.to.join(' ').includes(recipient))
      .sort((left, right) => {
        const leftTime = left.inserted_at ? Date.parse(left.inserted_at) : 0;
        const rightTime = right.inserted_at ? Date.parse(right.inserted_at) : 0;
        return rightTime - leftTime;
      })
      .find((email) => email.subject.includes('linked to your account'));

    if (linkedEmail) {
      return linkedEmail;
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error(`No provider_linked_email found for ${recipient}`);
}

test('GAUAT-06: email-match prompts for password login, links identity, and sends provider-linked email', async ({
  page,
}) => {
  const stamp = Date.now();
  const email = `oauth-email-match-${stamp}@example.test`;
  const password = 'CorrectHorseBatteryStaple123!';
  const sub = `oauth-email-match-${stamp}`;

  await page.goto('/');
  await registerAndConfirm(page, email, password);
  await setupIssuer(page, { sub, email, email_verified: true, name: 'Email Match User' });

  try {
    await page.goto('/users/log_in');
    await page.getByRole('link', { name: 'Continue with Google' }).click();
    await expect(page).toHaveURL(/\/users\/log_in/);
    await expect(page.getByText('An account with this email exists. Log in to link your google account.')).toBeVisible();

    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).toHaveURL('/');
    await expect(page.getByText('Your Google sign-in has been linked to this account.')).toBeVisible();

    const identities = await probeIdentities(page, email);
    expect(identities.count).toBe(1);
    expect(identities.rows[0]).toEqual({
      provider: 'google',
      provider_uid: sub,
    });

    const linkedEmail = await waitForProviderLinkedEmail(page, email);
    expect(linkedEmail.subject).toContain('Google linked to your account');
    expect([linkedEmail.html_body || '', linkedEmail.text_body || ''].join('\n')).toContain(
      'Google was linked to your account.',
    );
  } finally {
    await resetIssuer(page);
  }
});
