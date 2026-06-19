# Phase 190: Flows & Fixture Data (L4) - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 9 new/modified files
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/priv/playwright/helpers/adminFlows.ts` | utility/helper | request-response | `test/example/priv/playwright/helpers/adminUsersIndex.ts` + `demo-showcase.spec.ts:183-194` | role-match (extracted from duplicated spec-local helpers) |
| `test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts` | test/behavior-spec | request-response | `test/example/priv/playwright/tests/admin-user-operations.spec.ts` | exact (same lane, same CRUD + scope-ribbon + breadcrumb assertions) |
| `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` | test/behavior-spec | request-response | `test/example/priv/playwright/tests/impersonation.spec.ts` | exact (journey-level impersonation + return-context) |
| `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` | test/behavior-spec | request-response | `test/example/priv/playwright/tests/admin-generated.spec.ts:159-201` | exact (403 permission-denied + org-scoped access pattern) |
| `test/example/priv/playwright/playwright.config.ts` (edit) | config | — | self (lines 24-25) | self-edit (regex extension) |
| `guides/reference/admin-quality-ledger.md` (append 3 rows) | documentation | — | existing L3 rows (lines 61-66) | exact (same row shape) |
| `priv/templates/sigra.install/admin/admin_hooks.js` (WR-01/02/03) | client/hook | event-driven | self (lines 375-475 ConfirmDialog) | self-edit (harden existing patterns) |
| `test/example/assets/js/admin_hooks.js` (WR-01/02/03 mirror) | client/hook | event-driven | `priv/templates/sigra.install/admin/admin_hooks.js` | byte-identical mirror obligation |
| `lib/sigra/admin/live/branding_live.ex` (WR-04) | LiveView/component | request-response | self (lines 710-719) | self-edit (add `%Ecto.Changeset{}` clause) |

---

## Pattern Assignments

### `helpers/adminFlows.ts` (utility, request-response)

**Analog:** `test/example/priv/playwright/helpers/adminUsersIndex.ts` (helper module shape) + `test/example/priv/playwright/tests/demo-showcase.spec.ts:183-194` (`loginDemoUser` function)

**Module shape** from `adminUsersIndex.ts:1-21`:
```typescript
import type { Page } from '@playwright/test';

export function adminUsersEmailLocator(page: Page, email: string) {
  return page
    .locator('#admin-users-desktop-results tbody tr, #admin-users-mobile-results article')
    .filter({ hasText: email })
    .filter({ visible: true })
    .first();
}
```

**waitForLiveViewReady** (currently copy-pasted in every spec file — extract once here).
Canonical form from `impersonation.spec.ts:20-24`:
```typescript
export async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}
```

**loginDemoUser** from `demo-showcase.spec.ts:183-194`:
```typescript
// /users/log_in is a plain controller page (not a LiveView) — do NOT call
// waitForLiveViewReady here.
export async function loginDemoUser(page: Page, email: string, password: string) {
  await page.goto("/users/log_in");
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  // No MFA challenge — example app has no mfa.check_fn; creates :standard session.
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}
```

**loginDemoAdmin** (convenience wrapper) from `demo-showcase.spec.ts:196-198`:
```typescript
// admin@demo.vaultr.test — DemoAdmin1!SecurePass (from Personas.all())
export async function loginDemoAdmin(page: Page) {
  await loginDemoUser(page, 'admin@demo.vaultr.test', 'DemoAdmin1!SecurePass');
}
```

**assertScopeRibbon / scope chrome** from `admin-user-operations.spec.ts:62-69`:
```typescript
export async function expectScopeChrome(page: Page, scopeLabel: string) {
  const header = page.locator('header').first();
  await expect(header.getByText('Admin', { exact: true })).toBeVisible();
  await expect(header.getByText(scopeLabel, { exact: false }).first()).toBeVisible();
}
// Usage: await expectScopeChrome(page, 'Global'); or 'Acme Corp' for org-scoped
```

**No-flash addInitScript + theme attribute assertion** from `admin-theme.spec.ts:364-394`:
```typescript
export async function seedThemeAndAssertNoFlash(page: Page, theme: 'dark' | 'light') {
  await page.addInitScript((t) => {
    window.localStorage.setItem("sigra.admin.theme", t);
  }, theme);
  await page.goto("/admin");
  await expect(page.locator("html")).toHaveAttribute("data-sg-admin-theme", theme);
  // The no-flash script is a synchronous inline <script> in admin_shell.ex, NOT async/defer.
  // Source: admin_shell.ex:24-42 (also priv/templates/sigra.install/admin/components/admin_shell.ex)
}
```

**assertThemeAttributes** from `admin-theme.spec.ts:415-479`:
```typescript
export async function assertThemeAttributes(page: Page, theme: 'dark' | 'light') {
  await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', theme);
  await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', theme);
  expect(
    await page.evaluate(() => localStorage.getItem("sigra.admin.theme"))
  ).toBe(theme);
}
// System mode: shell has no data-theme, html has no data-sg-admin-theme, localStorage null
```

**Import block for new flow specs** (copy from `impersonation.spec.ts:1-3`):
```typescript
import { test, expect, type Page } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';
// Add: import { waitForLiveViewReady, loginDemoUser, loginDemoAdmin, ... } from '../helpers/adminFlows';
```

---

### `admin-flow-platform-admin.spec.ts` (behavior-spec, request-response)

**Analog:** `test/example/priv/playwright/tests/admin-user-operations.spec.ts`

**File header / describe structure** from `admin-user-operations.spec.ts:1-17`:
```typescript
import { test, expect, type Page } from '@playwright/test';
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
import { TEST_PASSWORD } from '../helpers/fixtures';

// Phase 190: Platform Admin JTBD flow spec.
// Exercises the overview → users search → user detail → audit → return-context journey
// for the platform admin operator (admin@demo.vaultr.test in global posture).
// Happy: alice. Main-error: dave (locked). Boundary: frank (scheduled-deletion), empty filter.
// Runs on the `chromium` behavior-truth lane only (ADMIN_BEHAVIOR_SPECS regex).

test.describe('Phase 190 platform admin flow (FLOW-01..03, DATA-01)', () => { ... });
```

**Demo persona constants** from `demo-showcase.spec.ts:23-28`:
```typescript
const DEMO_ADMIN_EMAIL = 'admin@demo.vaultr.test';
const DEMO_ADMIN_PASSWORD = 'DemoAdmin1!SecurePass';
const DEMO_ALICE_EMAIL = 'alice@demo.vaultr.test';
const DEMO_ALICE_PASSWORD = 'AliceDemoPass1!';
const DEMO_DAVE_EMAIL = 'dave@demo.vaultr.test';
const DEMO_MORGAN_EMAIL = 'morgan@demo.vaultr.test';
```

**Search + scope-ribbon pattern** from `admin-user-operations.spec.ts:85-100`:
```typescript
await page.goto('/admin/users');
await waitForLiveViewReady(page);
await expectScopeChrome(page, 'Global');

await page.fill('input[name="q"]', targetEmail);
await page.click('button:has-text("Search")');
await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
```

**Breadcrumb return-context pattern** from `admin-user-operations.spec.ts:106-112`:
```typescript
// After navigating to user detail, breadcrumb must carry the return scope.
const breadcrumb = page.getByRole('navigation', { name: 'Breadcrumb' });
await expect(breadcrumb.getByRole('link', { name: 'Users' })).toHaveAttribute(
  'href',
  /return_to|\/admin\/users\?/,
);
```

**Theme reload persistence** (new — gap confirmed in RESEARCH.md). Pattern basis from `admin-theme.spec.ts:415-435`:
```typescript
// Set theme via switcher, then reload, then re-assert — covers the reload gap.
await page.getByRole('radio', { name: 'Dark' }).click();
await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'dark');
await page.reload();
await waitForLiveViewReady(page);
// After reload the inline script in admin_shell.ex fires synchronously — theme already set.
await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'dark');
await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', 'dark');
```

**Reduced-motion at context level** (D-10 — must be `test.use()` before `goto`, NOT per-page `emulateMedia`):
```typescript
// At the top of the describe block (or in playwright.config.ts project definition):
test.use({ reducedMotion: 'reduce' });

// Assert collapsed CSS effect on loading bar (sigra_admin.css:1467-1484):
// The guard sets `animation: none !important` on .sg-admin-loading-bar::before
const animName = await page.locator('.sg-admin-loading-bar').evaluate(el =>
  window.getComputedStyle(el, '::before').animationName
);
expect(animName).toBe('none');
```

---

### `admin-flow-support-investigator.spec.ts` (behavior-spec, request-response)

**Analog:** `test/example/priv/playwright/tests/impersonation.spec.ts` (lines 89-145)

**Journey structure** from `impersonation.spec.ts:89-144` (fresh-sudo → banner → stop → return):
```typescript
// D-02: find account → per-user audit evidence (read) → impersonate → resolve → return.
// D-09: assert journey-level properties only; does NOT re-test impersonation internals.

// 1. Navigate to target user detail via search (same as openUserDetail helper)
await page.goto(`/admin/users?q=${encodeURIComponent(DEMO_ALICE_EMAIL)}`);
await waitForLiveViewReady(page);
await page.getByRole('link', { name: 'Open user' }).first().click();
await waitForLiveViewReady(page);

// 2. Sudo confirm (impersonation.spec.ts:109-111)
const detailUrl = new URL(page.url());
const detailPath = `${detailUrl.pathname}${detailUrl.search}`;
await page.goto(`/users/sudo?return_to=${encodeURIComponent(detailPath)}`);
await page.fill('input[name="sudo[password]"]', DEMO_ADMIN_PASSWORD);
await page.getByRole('button', { name: 'Confirm password' }).click();
await waitForLiveViewReady(page);

// 3. Start impersonation
await page.getByRole('button', { name: 'Start impersonation' }).click();
await expect(page).toHaveURL('/');

// 4. Banner persistence across navigation (impersonation.spec.ts:120-130)
const appBanner = page.locator('section').filter({ hasText: 'Impersonating' }).first();
await expect(appBanner).toContainText(`Impersonating ${DEMO_ALICE_EMAIL}`);
await expect(appBanner).toContainText(`Signed in as ${DEMO_ADMIN_EMAIL}`);

// 5. Stop → return to admin context (impersonation.spec.ts:138-143)
await page.getByRole('button', { name: 'End impersonation' }).click();
await expect(page).toHaveURL(/\/admin\/users\?.*q=/);
await waitForLiveViewReady(page);
await expect(page.locator('header').first()).toContainText('Global');
```

**ConfirmDialog keyboard (FLOW-02 gates)** from `admin-modal-interaction.spec.ts:93-182`:
```typescript
// Gate 2: focus on Cancel (WR-01 target: [data-sg-confirm-cancel], not positional)
// Gate 3: Tab containment (containment invariant, not Tab-count)
const isFocusInsideDialog = await page.evaluate(() => {
  const active = document.activeElement;
  const dialogEl = document.querySelector('.sg-confirm-dialog');
  return dialogEl !== null && (dialogEl === active || dialogEl.contains(active));
});
expect(isFocusInsideDialog, 'focus must stay inside dialog').toBe(true);

// Gate 4: Escape closes dialog
await page.keyboard.press('Escape');
await expect(overlay).toBeHidden();

// Gate 5: focus returns to trigger
// Note: must Tab-focus the trigger FIRST (not click — click suppresses :focus-visible)
await triggerLocator.focus();  // keyboard-focus, not click
await page.keyboard.press('Enter');
// ... open dialog ...
await page.keyboard.press('Escape');
await expect(triggerLocator).toBeFocused();
```

---

### `admin-flow-org-admin.spec.ts` (behavior-spec, request-response)

**Analog:** `test/example/priv/playwright/tests/admin-generated.spec.ts:159-201`

**403 permission-denied pattern** from `admin-generated.spec.ts:170-186`:
```typescript
// Log in as morgan (seeded org admin, not platform admin):
await loginDemoUser(page, 'morgan@demo.vaultr.test', 'MorganDemo1!OrgAdmin');

// Denied global admin access: org admin is blocked at /admin (403).
// Existing assertion shape from admin-generated.spec.ts:181-186:
const forbiddenResponse = await page.goto('/admin');
expect(forbiddenResponse?.status()).toBe(403);
await expect(page.locator('body')).toContainText(
  'Access denied. You do not have access to this admin scope.',
);
await expect(page.locator('body')).not.toHaveText(/^\s*$/);
```

**Org-scoped allowed access** from `admin-generated.spec.ts:172-177`:
```typescript
// Allowed org-scoped access — morgan can reach /admin/organizations/acme-corp/...
const allowedResponse = await page.goto('/admin/organizations/acme-corp');
expect(allowedResponse?.status()).toBe(200);
await expect(adminShellHeader(page)).toContainText('Acme Corp');
```

**Empty state boundary** (morgan has 0 audit events — RESEARCH gap).
Pattern from `empty_state` component assertion used in `admin-checkpoints.spec.ts` (not inline-readable, but pattern is):
```typescript
// Navigate to morgan's per-user audit page (boundary case: zero audit events).
// URL: /admin/organizations/acme-corp/users/:morgan_id/audit
// The AuditUserLive will render <.empty_state title="No audit events for this user">
await expect(page.getByRole('heading', { name: /no audit events/i })).toBeVisible();
// OR: assert the empty_state component text directly
await expect(page.locator('.sg-empty-state')).toBeVisible();
```

**adminShellHeader helper** from `admin-generated.spec.ts:54-57`:
```typescript
function adminShellHeader(page: Page) {
  return page.locator('header').filter({ hasText: 'Admin' }).first();
}
```

---

### `playwright.config.ts` — `ADMIN_BEHAVIOR_SPECS` regex edit

**Location:** `test/example/priv/playwright/playwright.config.ts:24-25`

**Current (lines 24-25):**
```typescript
const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation)\.spec\.ts/;
```

**Required change** (RESEARCH confirmed gap — flow specs will run on mobile without this fix):
```typescript
const ADMIN_BEHAVIOR_SPECS =
  /(admin-user-operations|admin-audit|admin-theme|impersonation|admin-flow)\.spec\.ts/;
```

The `mobile` project at lines 98-106 uses `testIgnore: [ADMIN_BEHAVIOR_SPECS, ...]` — adding `admin-flow` to the alternation is the entire edit.

---

### `guides/reference/admin-quality-ledger.md` — append 3 L4 rows

**Analog:** existing L3 rows, lines 61-66 of the ledger.

**Existing row shape** (lines 61-66):
```markdown
| index-live | L3 | 1 | [admin-checkpoints global-overview — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
| organization-live | L3 | 1 | [admin-checkpoints org-overview — 3 projects × toHaveScreenshot + axe](../../test/example/priv/playwright/tests/admin-checkpoints.spec.ts) |
```

**Parsing rules enforced** (`scripts/ci/quality-ledger-monotonic.sh`):
- Item must match `^\| [a-z]` (lowercase-item)
- Tier column (column 4) must be a bare integer: `0`, `1`, or `2` — no decorators
- New rows appended BELOW the 6 existing L3 rows (monotonic guard is append-only)

**3 new rows to append** (exact shape — tier set after evidence; use `1` as floor):
```markdown
| flow-platform-admin | L4 | 1 | [admin-flow-platform-admin.spec.ts — platform admin JTBD: happy/error/boundary, scope/return, keyboard, reduced-motion, theme-persistence + reload](../../test/example/priv/playwright/tests/admin-flow-platform-admin.spec.ts) |
| flow-support-investigator | L4 | 1 | [admin-flow-support-investigator.spec.ts — investigator posture: find→audit→impersonate→return, banner continuity, ConfirmDialog APG gates, theme](../../test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts) |
| flow-org-admin | L4 | 1 | [admin-flow-org-admin.spec.ts — org admin JTBD: tenant-bounded access, 403 permission-denied, empty audit boundary, theme](../../test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts) |
```

---

### `admin_hooks.js` WR-01/02/03 (both mirrors)

**Files (byte-identical mirror obligation — D-14):**
- `priv/templates/sigra.install/admin/admin_hooks.js` (canonical template, lines 375-475)
- `test/example/assets/js/admin_hooks.js` (example mirror — identical content verified by MD5)

**WR-01: explicit `[data-sg-confirm-cancel]` selector** replacing positional `focusables[0]`.
Current `_cancel` at template lines 433-442:
```javascript
_cancel: function () {
  var dialog = this.el.querySelector(".sg-confirm-dialog");
  if (!dialog) return;
  var focusables = dialog.querySelectorAll(FOCUSABLE);
  if (focusables.length) {
    focusables[0].click();   // <-- WR-01: replace with [data-sg-confirm-cancel]
  }
},
```
Also: `mounted` at lines 391-394 focuses `focusables[0]` — replace with `dialog.querySelector('[data-sg-confirm-cancel]')`.

**Companion template change required:** Add `data-sg-confirm-cancel` attribute to the Cancel button in:
- `lib/sigra/admin/live/user_show_live.ex` (ConfirmDialog cancel button)
- `lib/sigra/admin/live/branding_live.ex` (cancel_restore_defaults button)

**WR-02: `<body>` focus-return sentinel** in `destroyed` at lines 462-474:
```javascript
destroyed: function () {
  // ...
  if (this._trigger && this._trigger.focus) {
    this._trigger.focus();  // <-- WR-02: add fallback when trigger is detached
  }
  // After WR-02:
  if (this._trigger && document.contains(this._trigger) && this._trigger.focus) {
    this._trigger.focus();
  } else {
    document.body.focus();  // sentinel fallback
  }
},
```

**WR-03: Escape `stopImmediatePropagation`** in `_onKeydown` at lines 398-412:
```javascript
this._onKeydown = function (event) {
  var key = event.key;
  try {
    if (key === "Escape") {
      event.preventDefault();
      // WR-03: add stopImmediatePropagation so co-resident document listeners don't also fire
      event.stopImmediatePropagation();
      self._cancel();
      return;
    }
    if (key === "Tab") {
      self._trapFocus(event);
    }
  } catch (err) {
    // never throw from a keydown handler
  }
};
```

---

### `lib/sigra/admin/live/branding_live.ex` WR-04

**Location:** `lib/sigra/admin/live/branding_live.ex:710-719`

**Current pattern** (lines 710-719):
```elixir
defp error_message(%{message: message}) when is_binary(message), do: message
defp error_message(%ArgumentError{} = error), do: Exception.message(error)

defp error_message(%{__struct__: _module} = exception) do
  Exception.message(exception)
rescue
  _ -> inspect(exception)
end

defp error_message(reason), do: "Could not save auth branding: #{inspect(reason)}"
```

**WR-04 target:** Add an explicit `%Ecto.Changeset{}` clause before the catch-all struct clause. The `Ecto.Changeset` implements `Exception`, but `Exception.message/1` returns `"changeset is invalid"` — not useful. The correct pattern is to traverse `Ecto.Changeset.traverse_errors/2`:

```elixir
# Add this clause before the `%{__struct__: _module}` catch-all:
defp error_message(%Ecto.Changeset{} = changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end)
  |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
end
```

Existing analog for changeset error traversal exists in `test/example/lib/example_web/` LiveViews — the exact pattern used by Phoenix `phx.gen.auth`-style forms. The function signature above matches the Phoenix-idiomatic `translate_error` convention.

---

### `test/example/lib/example/demo/seeds.ex` (conditional enrichment)

**Analog:** existing `persona_audit_events/0` pattern at lines 500-632 of the same file.

**Enrichment scope** (D-05/D-06 — example-only, no parity duty):
- RESEARCH confirmed morgan has **zero audit events** — the empty state is already naturally reproducible. No enrichment required to create this state.
- Optional enrichment: add 1 morgan audit event to seeds so the org-admin flow can demonstrate both "has data" (org user list) and "empty sub-feed" (morgan's own per-user audit). Planner decides.

**Pattern for any new persona audit event** from `seeds.ex:500-510`:
```elixir
# Inside persona_audit_events/0 list, new entries follow this shape:
%{
  email: demo_email("morgan"),        # subject
  actor: demo_email("morgan"),        # who performed the action
  action: "auth.login.success",       # audit action string
  outcome: "success",
  offset: 34,                         # next monotonic offset after existing 33
  org: :acme                          # org context or nil
},
```

**Idempotency guard** from `seeds.ex:648`:
```elixir
# Count-threshold guard ensures the batch is only inserted if fewer rows exist.
# Incrementing length(@audit_actions) + length(persona_audit_events()) by 1
# causes re-seeding to insert the new event on next run/0 call.
if demo_tied_count < length(@audit_actions) + length(persona_audit_events()) do
  insert_audit_batch(admin, users, organizations)
end
```

**The `@seed_reference_ts` constraint** (D-05):
```elixir
# All timestamps in seeds.ex use offset from the pinned reference:
@seed_reference_ts ~U[2026-05-15 12:00:00Z]
# occurred_at = DateTime.add(@seed_reference_ts, -offset * 3600, :second)
# Never use DateTime.utc_now() in seed data.
```

---

## Shared Patterns

### Login (all 3 flow specs)
**Source:** `test/example/priv/playwright/tests/demo-showcase.spec.ts:183-198`
**Apply to:** All three flow spec files (via `helpers/adminFlows.ts`)
```typescript
// Use loginDemoUser(page, email, password) from helpers/adminFlows.ts — NOT registerUser.
// Demo personas are pre-seeded; registration would create duplicates or fail.
// /users/log_in is a controller page (not LiveView) — no waitForLiveViewReady needed before submit.
```

### waitForLiveViewReady (all 3 flow specs)
**Source:** `test/example/priv/playwright/tests/impersonation.spec.ts:20-24` (5 identical copies exist)
**Apply to:** All three flow spec files (via `helpers/adminFlows.ts`). One canonical export; do not copy-paste.

### Scope chrome assertion
**Source:** `test/example/priv/playwright/tests/admin-user-operations.spec.ts:62-69`
**Apply to:** All three flow specs for scope-ribbon continuity assertion.

### Web-first / no-sleep assertions
**Source:** All existing spec files — universal project convention.
**Apply to:** All new flow specs.
```typescript
// CORRECT: web-first auto-retrying
await expect(page.locator('.sg-admin-shell')).toHaveAttribute('data-theme', 'dark');
await expect(triggerLocator).toBeFocused();

// WRONG: never use sleep, fixed timeouts, or polling loops
// await page.waitForTimeout(500); // FORBIDDEN
```

### Axe accessibility gate
**Source:** `test/example/priv/playwright/tests/admin-modal-interaction.spec.ts:56-63`
**Apply to:** Each flow spec at a natural stable point (after page load, before navigation).
```typescript
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(violations, `${label}: axe violations`).toHaveLength(0);
}
```

### Reduced-motion at context level (not per-page)
**Source:** D-10; `admin-theme.spec.ts:851` shows the WRONG per-page pattern to avoid.
**Apply to:** All three flow specs.
```typescript
// CORRECT: test.use() inside describe block before any goto
test.use({ reducedMotion: 'reduce' });

// WRONG (Firefox drops it):
// await page.emulateMedia({ reducedMotion: 'reduce' }); // after goto
```

---

## No Analog Found

All files in this phase have either exact or role-match analogs in the codebase. No files are without precedent.

---

## Metadata

**Analog search scope:** `test/example/priv/playwright/` (all spec files + helpers), `priv/templates/sigra.install/admin/admin_hooks.js`, `test/example/assets/js/admin_hooks.js`, `lib/sigra/admin/live/branding_live.ex`, `test/example/lib/example/demo/seeds.ex` + `personas.ex`, `guides/reference/admin-quality-ledger.md`, `test/example/priv/playwright/playwright.config.ts`
**Files scanned:** 17
**Pattern extraction date:** 2026-06-17
