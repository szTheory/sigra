import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const source = fs.readFileSync(
  new URL('../../test/example/priv/playwright/tests/organizations.spec.ts', import.meta.url),
  'utf8',
);

function testBlock(title) {
  const marker = `test('${title}'`;
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `missing original test title: ${title}`);
  const next = source.indexOf("\ntest('", start + marker.length);
  return source.slice(start, next === -1 ? source.length : next);
}

test('registered owner helper proves authenticated zero-organization state without browser navigation', async () => {
  const helper = source.match(/async function assertAuthenticatedZeroOrganizationState\([\s\S]*?\n\}/)?.[0];
  assert.ok(helper, 'missing helper-return authentication assertion');
  assert.match(helper, /page\.request\.get\('\/organizations',\s*\{\s*maxRedirects:\s*0\s*\}\)/);
  assert.match(helper, /response\.status\(\),\s*200/);
  assert.match(helper, /Create your first organization/);

  const ownerCalls = source.match(/await assertAuthenticatedZeroOrganizationState\(page\);/g) ?? [];
  assert.equal(ownerCalls.length, 2, 'both invitation owners must prove the helper return');
});

test('new-user owner starts organization creation directly after the authenticated helper', () => {
  const block = testBlock('organization invitations: new user accepts through the mailbox signup path');
  assert.match(block, /await registerAndConfirmUser\(page, ownerEmail, ownerPassword\);\s*await assertAuthenticatedZeroOrganizationState\(page\);\s*await createOrganizationFromZeroState/);
  assert.doesNotMatch(block, /await logInIfNeeded\(page, ownerEmail, ownerPassword\);/);
  assert.match(block, /await inviteePage\.getByRole\('button', \{ name: `Create account & join \$\{orgName\}` \}\)\.click\(\);/);
  assert.match(block, /await inviteePage\.fill\('#login_form input\[name="user\[email\]"\]'[\s\S]*?await inviteePage\.goto\(`\/organizations\/\$\{orgSlug\}\/members`\)/);
  assert.match(block, /pending-invitations-section/);
});

test('matching-user owner uses the same proven return while invitee authentication and acceptance remain', () => {
  const block = testBlock('organization invitations: signed-in matching user accepts through the mailbox link');
  assert.match(block, /await registerAndConfirmUser\(page, ownerEmail, ownerPassword\);\s*await assertAuthenticatedZeroOrganizationState\(page\);\s*await createOrganizationFromZeroState/);
  assert.doesNotMatch(block, /await logInIfNeeded\(page, ownerEmail, ownerPassword\);/);
  assert.match(block, /await registerAndConfirmUser\(inviteePage, inviteeEmail, inviteePassword\);\s*await logInIfNeeded\(inviteePage, inviteeEmail, inviteePassword\);/);
  assert.match(block, /invitation-accept-accept/);
  assert.match(block, /pending-invitations-section/);
});

test('organization registration, confirmation, zero-org creation, and first-org lifecycle remain unchanged', () => {
  const registration = testBlock('phase 16 organizations UX: register → branch A → create → settings → slug change → members → multi-org switch');
  assert.match(registration, /extractConfirmationLink\(page, email\)/);
  assert.match(registration, /\/organizations\/\$\{firstOrgSlug\}\/members/);
  assert.match(registration, /\/organizations\/\$\{secondOrgSlug\}\/members/);
  assert.match(registration, /OrganizationSlugAlias/);
});
