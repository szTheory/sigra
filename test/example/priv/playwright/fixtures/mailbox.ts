import { Page } from '@playwright/test';

type MailboxEmail = {
  html_body: string | null;
  inserted_at?: string | null;
  text_body: string | null;
  to: string[];
};

function extractConfirmationHref(email: MailboxEmail): string | null {
  const body = [email.html_body || '', email.text_body || ''].join('\n');
  const hrefMatch = body.match(
    /https?:\/\/[^\s"'<>]+\/users\/confirm\/[A-Za-z0-9._~-]+(?:\?[^\s"'<>]+)?/,
  );

  if (hrefMatch?.[0]) {
    return hrefMatch[0];
  }

  const pathMatch = body.match(/\/users\/confirm\/[A-Za-z0-9._~-]+(?:\?[^\s"'<>]+)?/);
  return pathMatch?.[0] ?? null;
}

export async function extractConfirmationLink(page: Page, recipient: string): Promise<string> {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const mailbox = (await page.evaluate(async () => {
      const response = await fetch('/dev/mailbox/json');
      return response.json();
    })) as { data: MailboxEmail[] };

    const confirmationEmail = mailbox.data
      .filter((email) => email.to.join(' ').includes(recipient))
      .sort((left, right) => {
        const leftTime = left.inserted_at ? Date.parse(left.inserted_at) : 0;
        const rightTime = right.inserted_at ? Date.parse(right.inserted_at) : 0;
        return rightTime - leftTime;
      })
      .find((email) => extractConfirmationHref(email));

    if (confirmationEmail) {
      const href = extractConfirmationHref(confirmationEmail);

      if (!href) {
        throw new Error(`Confirmation email for ${recipient} did not include a link`);
      }

      return new URL(href, page.url()).toString();
    }

    await page.waitForTimeout(1_000);
  }

  throw new Error(`No confirmation email found in mailbox JSON for ${recipient}`);
}
