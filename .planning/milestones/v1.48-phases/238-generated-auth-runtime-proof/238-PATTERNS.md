# Phase 238: Generated Auth Runtime Proof - Pattern Map

**Mapped:** 2026-08-05  
**Files analyzed:** 4 repository files, plus one ephemeral generated-host seam  
**Analogs found:** 4 / 4 repository files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/ci/generated-auth-runtime-proof.sh` | config / acceptance harness | batch | `scripts/ci/passkeys-opt-out-smoke.sh` | exact lifecycle match |
| `test/example/priv/playwright/tests/generated-auth.spec.ts` | test | request-response | `test/example/priv/playwright/tests/golden-path.spec.ts` | role + generated-auth journey match |
| `test/example/priv/playwright/fixtures/mailbox.ts` | utility / fixture | request-response | `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` | exact observable-mailbox polling match |
| `test/example/priv/playwright/playwright.config.ts` | config | batch | existing generated-host project in the same file | exact config match |

The harness owns any provider-double controller/configuration only inside its freshly generated temporary host. It is not a permanent repository source file and therefore is not separately classified as a planned repository edit.

## Pattern Assignments

### `scripts/ci/generated-auth-runtime-proof.sh` (config / acceptance harness, batch)

**Primary analog:** `scripts/ci/passkeys-opt-out-smoke.sh`  
**Supporting analog:** `scripts/ci/admin-acceptance-smoke.sh`

Copy the Phase 237 B2C order: create a temporary Phoenix app, add the local dependency, install the B2C profile, then generate Google OAuth. The new harness should have one B2C leg rather than the three coverage legs in the opt-out smoke, and must retain guarded cleanup.

**Temporary-root and lifecycle pattern** — `scripts/ci/passkeys-opt-out-smoke.sh:18-33,35-76`:

```bash
set -euo pipefail

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_PARENT="${TMPDIR:-/tmp}"
TMP_ROOT="$(mktemp -d "${TMP_PARENT%/}/sigra-passkeys-opt-out.XXXXXX")"
readonly TMP_ROOT
SERVER_PID=""

cleanup() {
  cleanup_server
  cleanup_tmp_root
}

trap cleanup EXIT
```

Keep the existing safe-delete allowlist principle; do not use an unvalidated `rm -rf` target.

**Canonical B2C installer and OAuth-generator order** — `scripts/ci/passkeys-opt-out-smoke.sh:199-253`:

```bash
MIX_ENV=dev mix sigra.install Accounts User users ${flags} --yes

if [[ "${label}" == "sigra_b2c_alpha" ]]; then
  add_cloak_ecto
  mix deps.get
  MIX_ENV=dev mix sigra.gen.oauth --providers google

  assert_file_present "lib/${label}_web/controllers/oauth_controller.ex"
  assert_match 'get "/:provider", OAuthController, :request' "${router}"
  assert_match 'get "/:provider/callback", OAuthController, :callback' "${router}"
fi
```

**Focused Playwright invocation against the booted temporary host** — `scripts/ci/admin-acceptance-smoke.sh:398-404`:

```bash
(
  cd "${PLAYWRIGHT_DIR}"
  CI=true \
  SIGRA_EXAMPLE_URL="http://localhost:${PORT}" \
  npx playwright test --output test-results/generated-host "${PLAYWRIGHT_ARGS[@]}"
)
```

For this phase, set the spec to `tests/generated-auth.spec.ts` and output to a distinct generated-auth result directory. The harness should install its local OIDC double and dummy Google configuration before starting Phoenix; it must not mock Sigra modules or use external provider credentials.

### `test/example/priv/playwright/tests/generated-auth.spec.ts` (test, request-response)

**Primary analog:** `test/example/priv/playwright/tests/golden-path.spec.ts`  
**Supporting analogs:** `test/example/priv/playwright/tests/admin-generated.spec.ts`, `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts`

**Imports and one serial browser-visible journey** — `golden-path.spec.ts:13-21`:

```typescript
import { test, expect } from '@playwright/test';
import { extractConfirmationLink } from '../fixtures/mailbox';

test('full user lifecycle: register → confirm → login → sessions → sudo → MFA enroll → logout → MFA challenge', async ({
  page,
  request,
}) => {
  const email = `lifecycle-${Date.now()}@example.test`;
  const password = 'CorrectHorseBatteryStaple123!';
```

Use a single test with a unique email and fixed test password, but limit the journey to Phase 238’s email and Google states. Prefer `getByRole`/`getByLabel` locators in the new spec (as below) over this older spec’s CSS selectors.

**LiveView readiness gate** — `golden-path.spec.ts:24-34` (also `admin-generated.spec.ts:40-44`):

```typescript
const waitForLiveViewReady = async () => {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
};
```

Call this only on rendered LiveView states before interaction. Do not wait after controller routes that redirect during initial render.

**Registration and mailbox confirmation transition** — `golden-path.spec.ts:36-55`:

```typescript
await page.goto('/users/register');
await waitForLiveViewReady();
await page.fill('input[name="user[email]"]', email);
await page.fill('input[name="user[password]"]', password);
await page.click('button:has-text("Create an account")');
await expect(page).not.toHaveURL(/\/users\/register/);

const confirmHref = await extractConfirmationLink(page, email);
await page.goto(confirmHref);
await expect(page).not.toHaveURL(/\/users\/confirm\//);
```

**Accessible login controls and visible redirect assertion** — `admin-generated.spec.ts:62-77`:

```typescript
await page.goto("/users/log_in");
await expect(page.getByRole("heading", { name: "Sign in" })).toBeVisible();
await page.locator("details.sigra-auth-disclosure > summary").click();
const passwordForm = page.locator("#login_form");
await passwordForm.getByLabel("Email", { exact: true }).fill(email);
await passwordForm.getByLabel("Password", { exact: true }).fill(password);
await passwordForm
  .getByRole("button", { name: "Sign in with password" })
  .click();
await expect(page).not.toHaveURL(/\/users\/log_in(\?|$)/);
```

Use the real logout button/form rather than clearing cookies. The generated controller confirms the expected outcome: `session_controller.ex:308-318` sends the `Logged out successfully.` flash and calls `UserAuth.log_out_user()`.

**Scoped Axe gate** — `admin-generated.spec.ts:160-167`:

```typescript
const { violations } = await new AxeBuilder({ page })
  .include("main.sigra-auth")
  .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
  .analyze();
expect(
  violations,
  `generated auth post-disclosure axe violations: ${JSON.stringify(violations).slice(0, 2000)}`,
).toHaveLength(0);
```

Put this in a shared `assertAuthState` helper and invoke it after every material rendered state. Add the requirement-specific label-to-control and duplicate-ID assertions against the same `main.sigra-auth` root; no existing spec contains both checks together.

**Google controller boundary and collision result to assert** — `priv/templates/sigra.gen.oauth/oauth_controller.ex:22-45,54-98`:

```elixir
case Sigra.OAuth.authorize_url(config, provider_atom) do
  {:ok, url, session_params} ->
    conn
    |> put_session(:sigra_oauth_state, session_params[:sigra_state])
    |> put_session(:sigra_oauth_code_verifier, session_params[:code_verifier])
    |> redirect(external: url)
end

case Sigra.OAuth.handle_callback(config, provider_atom, params, session_params) do
  {:link_confirmation_required, info} ->
    conn
    |> put_session(:sigra_oauth_link_intent, %{provider: info.provider, email: info.email})
    |> put_flash(:info, "An account with this email exists. Log in to link your #{provider} account.")
    |> redirect(to: ~p"<%= login_path %>")
end
```

Start with `/auth/google`, have the local double relay its received `state` to `/auth/google/callback`, then assert the visible login collision flash. Do not call the callback directly or stub `handle_callback/4`.

### `test/example/priv/playwright/fixtures/mailbox.ts` (utility / fixture, request-response)

**Primary analog:** `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts`

The current fixture has useful recipient sorting and confirmation-link parsing (`mailbox.ts:10-48`), but its fixed delay at `mailbox.ts:50` is prohibited for this phase. Retain the extractor shape while replacing its retry loop with observable Playwright polling, and extend it for confirmation, magic-login, and reset-password routes.

**Observable mailbox polling pattern** — `ga-uat-shift-left.spec.ts:74-117`:

```typescript
let link: string | null = null;
await expect.poll(async () => {
  const mailbox = (await page.evaluate(async () => {
    const response = await fetch('/dev/mailbox/json');
    return response.json();
  })) as { data: Array<{ to: string[]; html_body: string | null; text_body: string | null }> };

  const row = mailbox.data.find((email) => {
    const recipients = email.to.join(' ');
    const body = [email.html_body || '', email.text_body || ''].join('\n');
    return recipients.includes(recipient) && body.includes('/invitations/');
  });

  // Extract and normalize the matching URL, then return link !== null.
  return link !== null;
}, {
  message: `No invitation link for ${recipient}`,
  intervals: [250, 500, 1000],
  timeout: 30_000,
}).toBe(true);
```

Normalize a full or relative link with `new URL(href, page.url()).toString()` as `mailbox.ts:47` already does. Keep recipient matching and select the newest relevant message so registration, magic link, and reset paths do not consume stale mail.

### `test/example/priv/playwright/playwright.config.ts` (config, batch)

**Analog:** existing generated-host project in `test/example/priv/playwright/playwright.config.ts`

The global configuration is already the required serial, zero-retry policy. Add a dedicated generated-auth spec matcher/project only if the default `chromium`/`mobile` projects would otherwise execute it; do not weaken the global policy.

**Serial defaults and host injection** — `playwright.config.ts:54-90`:

```typescript
export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  expect: { timeout: 15_000 },
  timeout: 60_000,
  use: {
    baseURL: process.env.SIGRA_EXAMPLE_URL ?? 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    headless: true,
    actionTimeout: 15_000,
    navigationTimeout: 15_000,
  },
```

**Generated-host project partition** — `playwright.config.ts:156-167`:

```typescript
{
  name: 'admin-generated',
  testMatch: ADMIN_GENERATED_SPEC,
  use: {
    ...devices['Desktop Chrome'],
    video: checkpointVideo,
  },
},
```

Mirror this as a `generated-auth` project matched solely to `generated-auth.spec.ts`, and add that matcher to the general projects’ `testIgnore` arrays so the fresh-host test is not accidentally run against the example application.

## Shared Patterns

### Deterministic browser state

**Sources:** `golden-path.spec.ts:24-34`; `admin-generated.spec.ts:62-77`  
**Apply to:** `generated-auth.spec.ts`

Use LiveView’s `.phx-connected` signal for hydrated views, then role/label locators plus URL/visible-flash assertions for controller redirects. Do not use `waitForTimeout`, CSS text click selectors, or direct context/module calls as substitution for rendered proof.

### Mailbox delivery and token routes

**Sources:** `fixtures/mailbox.ts:10-48`; `ga-uat-shift-left.spec.ts:79-117`; generated templates `registration_live.ex:108-146`, `session_controller.ex:37-49,102-114`, `reset_password_live.ex:155-198`  
**Apply to:** mailbox fixture and generated browser journey

Registration sends `/users/confirm/:token`; magic-link delivery resolves to `/users/log_in/:token`; reset delivery resolves to `/users/reset-password/:token`. Retrieve all through `/dev/mailbox/json` with bounded `expect.poll`, then navigate the actual emitted URL.

### OAuth state and collision semantics

**Sources:** `oauth_controller.ex:22-45,54-123`; `google.ex:18-38,81-90`; `callback_test.exs:63-77`  
**Apply to:** fresh-host harness and browser spec

The double must preserve the controller-created state/PKCE transaction and return a deterministic Google profile whose normalized email equals the existing password user. The unit contract establishes the target semantic:

```elixir
assert {:link_confirmation_required, info} =
         Callback.process_callback(config, :google, mock_user_info(), mock_token())

assert info.provider == :google
assert info.email == "oauth@example.com"
```

### Error handling and evidence

**Sources:** `passkeys-opt-out-smoke.sh:78-140`; `admin-acceptance-smoke.sh:398-404`

Fail fast under `set -euo pipefail`, emit actionable diagnostics on missing generated artifacts or boot failure, always stop the child server through `trap`, and allow Playwright failure artifacts to remain in its dedicated output directory.

## No Analog Found

| File / seam | Role | Data Flow | Reason |
|---|---|---|---|
| Ephemeral test-only generated-host OIDC discovery/authorize/token/userinfo double | controller / provider double | request-response | No existing host-local OIDC provider double exists. Implement it narrowly in the temporary app generated by the harness; preserve the real generated OAuth controller and Assent Google strategy boundary. |
| `assertAuthState` label-control and duplicate-ID helper | test utility | transform | Existing `admin-generated.spec.ts` supplies scoped Axe, but no repository helper combines Axe with both required DOM invariants. |

## Metadata

**Analog search scope:** `scripts/ci`, `test/example/priv/playwright`, generated auth/OAuth templates, `lib/sigra/oauth`, `test/sigra/oauth`  
**Files scanned:** 12  
**Pattern extraction date:** 2026-08-05
