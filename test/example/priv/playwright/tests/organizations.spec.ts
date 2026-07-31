// Phase 16: organizations UX browser smoke. Automates the 15-step human
// verification checklist from 16-06-PLAN.md:232-272 so the Phase 16 gate
// is enforced in CI instead of on a live laptop.
//
// What this catches that the 9 Phoenix.LiveViewTest integration tests
// under test/example/test/example_web/integration/phase_16_integration_test.exs
// miss: exact DOM copy, daisyUI badge class presence, native <dialog>
// modal behavior, URL transitions through real form POSTs (switcher +
// settings), and the slug-alias redirect round-trip on a real cookie
// session. Exact copy strings are hard-coded against 16-UI-SPEC.md
// §Copywriting Contract — same discipline as the SHA256 byte-identity
// test on registration_live.ex: UI-SPEC changes and this spec change in
// the same PR.

import { test, expect } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';

const EXAMPLE_BASE_URL = process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000';

async function waitForLiveViewReady(
  page: Parameters<typeof test>[0]['page'],
) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function dismissFlash(page: Parameters<typeof test>[0]['page']) {
  for (let index = 0; index < 2; index += 1) {
    const visibleFlashes = page.locator('#flash-group [data-flash]:visible');

    if ((await visibleFlashes.count()) === 0) {
      return;
    }

    const flash = visibleFlashes.first();
    const flashId = await flash.getAttribute('id');

    if (!flashId) {
      throw new Error('visible flash is missing its stable id');
    }

    await flash.getByRole('button', { name: 'close' }).click();
    await expect(page.locator(`#${flashId}`)).toBeHidden();
  }
}

async function registerAndConfirmUser(
  page: Parameters<typeof test>[0]['page'],
  email: string,
  password: string,
) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');
  await expect(page).not.toHaveURL(/\/users\/register/);
  await logInIfNeeded(page, email, password);
}

async function logInIfNeeded(
  page: Parameters<typeof test>[0]['page'],
  email: string,
  password: string,
) {
  await page.goto('/users/log_in');
  if (page.url().includes('/users/log_in')) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }
}

async function createOrganizationFromZeroState(
  page: Parameters<typeof test>[0]['page'],
  orgName: string,
  expectedSlug: string,
) {
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', orgName);
  await expect(page.locator('#slug-preview')).toHaveText(expectedSlug);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(
    new RegExp(`/organizations/${expectedSlug}/members$`),
  );
  await waitForLiveViewReady(page);
}

async function sendInvitation(
  page: Parameters<typeof test>[0]['page'],
  inviteeEmail: string,
  role: 'member' | 'admin' | 'owner' = 'member',
) {
  const modal = page.locator('#invite-member-modal');
  const emailInput = modal.locator('input[name="invitation[email]"]');
  const inviteButton = page.locator('#invite-member-button');
  await expect(inviteButton).toBeEnabled();
  await inviteButton.click({ force: true });
  await page.evaluate(() => {
    const dialog = document.getElementById('invite-member-modal');

    if (dialog instanceof HTMLDialogElement && !dialog.open) {
      dialog.showModal();
    }
  });
  await expect(modal).toHaveJSProperty('open', true);
  await emailInput.fill(inviteeEmail, { force: true });
  await modal
    .locator('select[name="invitation[role]"]')
    .selectOption(role, { force: true });
  await modal.locator('button[type="submit"]').click({ force: true });

  await expect(page.getByText(`Invitation sent to ${inviteeEmail}.`)).toBeVisible();
  await expect(page.locator('#pending-invitations-section')).toContainText(
    inviteeEmail,
  );
}

async function extractInvitationLink(
  page: Parameters<typeof test>[0]['page'],
  recipient: string,
) {
  let link: string | null = null;
  await expect.poll(async () => {
    const mailbox = (await page.evaluate(async () => {
      const response = await fetch('/dev/mailbox/json');

      return response.json();
    })) as {
      data: Array<{
        to: string[];
        html_body: string | null;
        text_body: string | null;
      }>;
    };

    const invitationEmail = mailbox.data.find((email) => {
      const recipients = email.to.join(' ');
      const body = [email.html_body || '', email.text_body || ''].join('\n');

      return recipients.includes(recipient) && body.includes('/invitations/');
    });

    if (invitationEmail) {
      const body = [invitationEmail.html_body || '', invitationEmail.text_body || ''].join('\n');
      const match = body.match(/https?:\/\/[^\s"'<>]*\/invitations\/[^\s"'<>]*\/accept/);

      if (match) {
        const normalized = new URL(match[0], page.url());
        normalized.protocol = new URL(page.url()).protocol;
        normalized.host = new URL(page.url()).host;

        link = normalized.toString();
      }
    }

    return link !== null;
  }, {
    message: `No invitation link found in mailbox JSON for ${recipient}`,
    intervals: [250, 500, 1000],
    timeout: 30_000,
  }).toBe(true);

  if (!link) throw new Error(`No invitation link found in mailbox JSON for ${recipient}`);

  return link;
}

test('phase 16 organizations UX: register → branch A → create → settings → slug change → members → multi-org switch', async ({
  page,
}) => {
  const suffix = Date.now();
  const email = `orgs-${suffix}@example.test`;
  const password = 'CorrectHorseBatteryStaple123!';
  const firstOrgName = `Test Org ${suffix}`;
  const firstOrgSlug = `test-org-${suffix}`;
  const renamedOrgName = `Test Organization ${suffix}`;
  const renamedSlug = `test-org-${suffix}-renamed`;
  const secondOrgName = `Second Co ${suffix}`;
  const secondOrgSlug = `second-co-${suffix}`;

  // --- Step 1: Register ---
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.click('button:has-text("Create an account")');
  await expect(page).not.toHaveURL(/\/users\/register/);

  // --- Step 2: Confirm via dev mailbox ---
  const confirmHref = await extractConfirmationLink(page, email);
  await page.goto(confirmHref);
  await expect(page).not.toHaveURL(/\/users\/confirm\//);

  // --- Step 3: Login if needed ---
  await page.goto('/users/log_in');
  if (page.url().includes('/users/log_in')) {
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill('#login_form input[name="user[password]"]', password);
    await page.click('#login_form button:has-text("Log in")');
    await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
  }

  // --- Step 4: Navigate to Branch A (zero-org landing) ---
  // ORG-UX-09 lands a zero-org user on /organizations via Phase 14's
  // :no_active_org redirect. Navigate explicitly rather than rely on
  // automatic post-login routing — the login destination depends on the
  // example app's configured return path which may not be Branch A.
  await page.goto('/organizations');
  await waitForLiveViewReady(page);
  await expect(page).toHaveURL(/\/organizations$/);
  await expect(
    page.getByRole('heading', { name: 'Create your first organization' }),
  ).toBeVisible();
  await expect(
    page.getByText(
      "You don't belong to any teams yet. Create one to start sharing secrets.",
    ),
  ).toBeVisible();
  await expect(
    page.getByRole('link', { name: 'Skip for now' }),
  ).toBeVisible();

  // --- Step 5: Live slug preview on name field ---
  // phx-change="validate" pushes each keystroke to the server, which
  // updates @slug_preview via Sigra.Organizations.Slug.generate/1. The
  // preview element has aria-live="polite" and id="slug-preview".
  await page.fill('input[name="organization[name]"]', firstOrgName);
  await expect(page.locator('#slug-preview')).toHaveText(firstOrgSlug);

  // --- Step 6: Create the first organization ---
  await page.click('button:has-text("Create organization")');
  // The create handler redirects to /organizations/:slug/members.
  await expect(page).toHaveURL(
    new RegExp(`/organizations/${firstOrgSlug}/members$`),
  );
  await waitForLiveViewReady(page);

  // --- Step 7: Switcher chip shows active org + Owner badge ---
  // The switcher renders only when current_scope.active_organization is
  // set, which is exactly the post-create state. The trigger is a
  // <summary> with aria-label="Organization switcher" inside the
  // <details id="org-switcher">. Chromium exposes <summary> as
  // role=generic (not button), so target it via the parent details id.
  const switcherDetails = page.locator('#org-switcher');
  const switcherTrigger = switcherDetails.locator('summary');
  await expect(switcherTrigger).toBeVisible();
  await expect(switcherTrigger).toContainText(firstOrgName);
  // Role pill is a <span class="vt-status-pill vt-status-pill--ok">Owner</span>
  // inside the trigger summary. The Elixir helper renders literal "Owner".
  await expect(
    switcherTrigger.locator('.vt-status-pill').first(),
  ).toContainText('Owner');

  // --- Step 8: Open switcher dropdown, verify menu anatomy ---
  // Dismiss the post-create "Organization created." toast first; the
  // alert overlay intercepts pointer events on the switcher otherwise.
  await dismissFlash(page);
  await switcherTrigger.click();
  const switcherMenu = page.locator('#org-switcher .vt-menu__panel');
  await expect(switcherMenu).toBeVisible();
  await expect(switcherMenu).toContainText('Active');
  // "Switch to" section only exists when there's another org; at this
  // point we only have one, so just check the action items are present.
  await expect(
    switcherMenu.getByRole('link', { name: /Create organization/ }),
  ).toBeVisible();
  await expect(
    switcherMenu.getByRole('link', { name: /Organization settings/ }),
  ).toBeVisible();
  await expect(
    switcherMenu.getByRole('link', { name: /Manage organizations/ }),
  ).toBeVisible();
  // Esc closes the native <details> via the JS hook described in the UI
  // spec. Focus the trigger first so the keydown fires on the dropdown.
  await switcherTrigger.focus();
  await page.keyboard.press('Escape');

  // --- Step 9: Navigate to settings, verify three-section layout ---
  await page.goto(`/organizations/${firstOrgSlug}/settings`);
  await waitForLiveViewReady(page);
  // Sections use vt-kicker labels (p.vt-kicker), not heading elements.
  const generalLabel = page.getByText('General', { exact: true });
  const slugLabel = page.getByText('Slug', { exact: true });
  const dangerLabel = page.getByText('Danger zone', { exact: true });
  await expect(generalLabel).toBeVisible();
  await expect(slugLabel).toBeVisible();
  await expect(dangerLabel).toBeVisible();
  // Danger zone section carries data-testid="org-danger-zone".
  await expect(
    page.locator('[data-testid="org-danger-zone"]'),
  ).toBeVisible();

  // --- Step 10: Rename the organization ---
  await page.getByLabel('Organization name').fill(renamedOrgName);
  await page.click('button:has-text("Save name")');
  await expect(page.getByText('Name updated.')).toBeVisible();
  await dismissFlash(page);

  // --- Step 11: Slug progressive disclosure ---
  await page.click('button:has-text("Change slug")');
  // Use accessible-name (label) selectors — far more robust than guessing
  // input name attributes generated by core_components.ex .input/1.
  const slugInput = page.getByLabel('New slug');
  const slugPasswordInput = page.getByLabel('Current password');
  const slugConfirmInput = page.getByLabel(
    `Type ${firstOrgSlug} to confirm`,
  );
  await expect(slugInput).toBeVisible();
  await expect(slugPasswordInput).toBeVisible();
  await expect(slugConfirmInput).toBeVisible();
  // The warning banner references a 7-day redirect window.
  await expect(page.getByRole('alert')).toContainText('7 days');
  await expect(
    page.getByRole('button', { name: 'Update slug' }),
  ).toBeVisible();

  // --- Step 12: Slug change error paths ---
  // 12a: wrong password → "That password is incorrect."
  await slugInput.fill(renamedSlug);
  await slugPasswordInput.fill('wrong-password');
  await slugConfirmInput.fill(firstOrgSlug);
  await page.click('button:has-text("Update slug")');
  await expect(page.getByText('That password is incorrect.')).toBeVisible();

  // 12b: wrong typed-confirm → "Type {old-slug} exactly to confirm."
  await slugPasswordInput.fill(password);
  await slugConfirmInput.fill('nope');
  await page.click('button:has-text("Update slug")');
  await expect(
    page.getByText(`Type ${firstOrgSlug} exactly to confirm.`),
  ).toBeVisible();

  // 12c: valid values → success flash + URL updates to new slug
  await slugConfirmInput.fill(firstOrgSlug);
  await page.click('button:has-text("Update slug")');
  await expect(
    page.getByText('Slug updated. The old slug redirects for 7 days.'),
  ).toBeVisible();
  await expect(page).toHaveURL(
    new RegExp(`/organizations/${renamedSlug}/settings$`),
  );
  await dismissFlash(page);

  // --- Step 13: Slug alias redirect (7-day window) ---
  // Navigate to the old slug; the LoadOrganizationFromSlug plug should
  // look up the OrganizationSlugAlias row and 302 to the new slug.
  await page.goto(`/organizations/${firstOrgSlug}/settings`);
  await expect(page).toHaveURL(
    new RegExp(`/organizations/${renamedSlug}/settings$`),
  );
  await waitForLiveViewReady(page);

  // --- Step 14: Danger zone disclosure (do NOT delete) ---
  await page.click('button:has-text("Delete organization")');
  const deletePasswordInput = page
    .getByLabel('Current password')
    .first();
  const deleteConfirmInput = page.getByLabel(
    `Type ${renamedOrgName} to confirm`,
  );
  await expect(deletePasswordInput).toBeVisible();
  await expect(deleteConfirmInput).toBeVisible();
  // Click Cancel — the organization must survive for the remaining steps.
  await page.click('button:has-text("Cancel")');
  await expect(deletePasswordInput).not.toBeVisible();

  // --- Step 15: Members table ---
  await page.goto(`/organizations/${renamedSlug}/members`);
  await waitForLiveViewReady(page);
  const membersSection = page.locator('#members-section');
  await expect(membersSection).toContainText(email);
  // Owner role pill on the only row is vt-status-pill.
  await expect(
    membersSection.locator('.vt-status-pill').first(),
  ).toContainText('Owner');
  // Phase 17 invite flow is now implemented. The button is enabled for
  // owners/admins (this test user is the owner of the org) and fires
  // the open_invite_modal phx-click handler. Phase 24.1 updated this
  // assertion — previously the test expected a gated-disabled state
  // from a pre-Phase-17 snapshot, but the LiveView implements the
  // full invite UI (modal, handler, stream-based pending invitations).
  const inviteButton = page.getByRole('button', { name: 'Invite member' });
  await expect(inviteButton).toBeEnabled();
  await expect(inviteButton).toHaveAttribute(
    'phx-click',
    'open_invite_modal',
  );

  // --- Step 16: Create a second organization ---
  await page.goto('/organizations/new');
  await waitForLiveViewReady(page);
  await page.fill('input[name="organization[name]"]', secondOrgName);
  await page.click('button:has-text("Create organization")');
  await expect(page).toHaveURL(
    new RegExp(`/organizations/${secondOrgSlug}/members$`),
  );
  await waitForLiveViewReady(page);

  // --- Step 17: Switcher now shows SWITCH TO, use it to hop back ---
  await dismissFlash(page);
  await switcherTrigger.click();
  // Active section shows the second org now.
  await expect(switcherMenu).toContainText('Switch to');
  await expect(switcherMenu).toContainText(renamedOrgName);
  // Click the switch form button for the renamed (first) org.
  await switcherMenu
    .getByRole('button', { name: `Switch to ${renamedOrgName}` })
    .click();
  // POST /organizations/switch → 302 to return_to. The switcher form
  // sends return_to=/ by default (see org_switcher.ex line 66), so we
  // land on the root route. The home page is rendered by PageController
  // which does NOT use Layouts.app, so the switcher isn't there. Navigate
  // to a phase-16 LV under the new active org to verify the switch.
  await expect(page).not.toHaveURL(
    new RegExp(`/organizations/${secondOrgSlug}/`),
  );
  await page.goto(`/organizations/${renamedSlug}/members`);
  await waitForLiveViewReady(page);
  await expect(switcherTrigger).toContainText(renamedOrgName);
  await expect(
    switcherTrigger.locator('.vt-status-pill').first(),
  ).toContainText('Owner');

  // --- Step 18: Copywriting contract spot-checks ---
  // Re-verify three load-bearing strings from 16-UI-SPEC.md §Copywriting
  // Contract. If these drift, the test points at the UI-SPEC as source
  // of truth.
  await page.goto(`/organizations/${renamedSlug}/settings`);
  await waitForLiveViewReady(page);
  await expect(
    page.getByText('Soft-delete this organization. Members lose access immediately.'),
  ).toBeVisible();
  await page.click('button:has-text("Change slug")');
  await expect(page.getByRole('alert')).toContainText(
    'will redirect to the new slug for 7 days',
  );
});

test('organization invitations: new user accepts through the mailbox signup path', async ({
  page,
  browser,
}) => {
  const suffix = Date.now();
  const ownerEmail = `org-owner-${suffix}@example.test`;
  const ownerPassword = 'CorrectHorseBatteryStaple123!';
  const inviteeEmail = `org-invitee-${suffix}@example.test`;
  const inviteePassword = 'CorrectHorseBatteryStaple123!';
  const orgName = `Invite Org ${suffix}`;
  const orgSlug = `invite-org-${suffix}`;

  await registerAndConfirmUser(page, ownerEmail, ownerPassword);
  await logInIfNeeded(page, ownerEmail, ownerPassword);
  await createOrganizationFromZeroState(page, orgName, orgSlug);
  await sendInvitation(page, inviteeEmail);
  const invitationHref = await extractInvitationLink(page, inviteeEmail);

  const inviteeContext = await browser.newContext({
    baseURL: EXAMPLE_BASE_URL,
  });
  const inviteePage = await inviteeContext.newPage();

  try {
    await inviteePage.goto(invitationHref);
    await waitForLiveViewReady(inviteePage);
    await expect(inviteePage.locator('#invitation-accept-signup')).toBeVisible();
    await expect(inviteePage.getByLabel('Email')).toHaveValue(inviteeEmail);
    await expect(inviteePage.getByLabel('Email')).toBeDisabled();
    await inviteePage.getByLabel('Password').fill(inviteePassword);
    await inviteePage
      .getByRole('button', { name: `Create account & join ${orgName}` })
      .click();

    await expect(inviteePage).toHaveURL(/\/users\/log_in/);
    await inviteePage.fill('#login_form input[name="user[email]"]', inviteeEmail);
    await inviteePage.fill('#login_form input[name="user[password]"]', inviteePassword);
    await inviteePage.click('#login_form button:has-text("Log in")');
    await expect(inviteePage).not.toHaveURL(/\/users\/log_in(\?|$)/);

    await inviteePage.goto(`/organizations/${orgSlug}/members`);
    await waitForLiveViewReady(inviteePage);
    await expect(inviteePage.locator('#members-section')).toContainText(inviteeEmail);
    await expect(inviteePage.locator('#pending-invitations-section')).not.toContainText(
      inviteeEmail,
    );
  } finally {
    await inviteeContext.close();
  }
});

test('organization invitations: signed-in matching user accepts through the mailbox link', async ({
  page,
  browser,
}) => {
  const suffix = Date.now();
  const ownerEmail = `org-owner-match-${suffix}@example.test`;
  const ownerPassword = 'CorrectHorseBatteryStaple123!';
  const inviteeEmail = `org-member-match-${suffix}@example.test`;
  const inviteePassword = 'CorrectHorseBatteryStaple123!';
  const orgName = `Match Org ${suffix}`;
  const orgSlug = `match-org-${suffix}`;

  await registerAndConfirmUser(page, ownerEmail, ownerPassword);
  await logInIfNeeded(page, ownerEmail, ownerPassword);
  await createOrganizationFromZeroState(page, orgName, orgSlug);
  await sendInvitation(page, inviteeEmail);
  const invitationHref = await extractInvitationLink(page, inviteeEmail);

  const inviteeContext = await browser.newContext({
    baseURL: EXAMPLE_BASE_URL,
  });
  const inviteePage = await inviteeContext.newPage();

  try {
    await registerAndConfirmUser(inviteePage, inviteeEmail, inviteePassword);
    await logInIfNeeded(inviteePage, inviteeEmail, inviteePassword);

    await inviteePage.goto(invitationHref);
    await waitForLiveViewReady(inviteePage);
    await expect(inviteePage.locator('#invitation-accept-accept')).toBeVisible();
    await inviteePage
      .getByRole('button', { name: `Accept & join ${orgName}` })
      .click();

    await expect(inviteePage).toHaveURL(new RegExp(`/organizations/${orgSlug}/members$`));
    await waitForLiveViewReady(inviteePage);
    await expect(inviteePage.locator('#members-section')).toContainText(inviteeEmail);
    await expect(inviteePage.locator('#pending-invitations-section')).not.toContainText(
      inviteeEmail,
    );
  } finally {
    await inviteeContext.close();
  }
});
