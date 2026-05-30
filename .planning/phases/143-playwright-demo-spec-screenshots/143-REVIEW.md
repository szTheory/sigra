---
phase: 143-playwright-demo-spec-screenshots
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .github/workflows/ci.yml
  - lib/sigra/admin/live/user_show_live.ex
  - test/example/lib/example/sigra_admin_policy.ex
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/test/example/demo/seeds_test.exs
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 143: Code Review Report

**Reviewed:** 2026-05-30
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase adds the demo-showcase Playwright spec (`demo-showcase.spec.ts`), its
snapshot baselines, a seeds smoke/invariant ExUnit suite (`seeds_test.exs`), the
`demo-showcase-chromium` Playwright project partition, and the CI job step that
invokes it. The `UserShowLive` and `SigraAdminPolicy` files are included for
admin-surface context.

Overall structure is sound — the Playwright partition, snapshot baseline location,
and ExUnit sandbox isolation are correctly set up. Several issues range from a
BLOCKER-grade security finding in `UserShowLive` to a silent invariant gap in the
seeds test and a dead import in the spec.

---

## Critical Issues

### CR-01: `open_revoke_session` event processes a Base64 token from the client without validating that it belongs to the currently-viewed user

**File:** `lib/sigra/admin/live/user_show_live.ex:38-45`

**Issue:** `handle_event("open_revoke_session", ...)` decodes a `Base.url_decode64!` token
that was embedded as a `phx-value-token` attribute in the rendered HTML. A
legitimate admin who has permission to view _their own_ user-detail page can craft
an `open_revoke_session` event carrying an arbitrary token from a *different* user
that they memorized from an earlier page load, because the event handler only checks
that `confirm_action` is set — it never validates that the supplied token actually
belongs to `detail.user.id`. The confirm handler in `confirm_action` (line 66) passes
that token straight to `Actions.revoke_session(config, admin_scope, detail.user.id,
token)`. If `Actions.revoke_session` performs a token→user lookup in the DB instead
of a `WHERE user_id = $1 AND hashed_token = $2` join, an admin scoped to org A
could revoke a session belonging to a user in org B by opening the org-B user detail,
copying the `phx-value-token` HTML attribute, then submitting the crafted event
against an org-A user detail.

The scope guard at mount time only ensures the admin is allowed to view `user_id`,
not that the supplied token lives in that user's token table.

**Fix:** In `open_revoke_session`, validate that the incoming token is present in
`socket.assigns.detail.sessions` before storing it in `confirm_action`:

```elixir
def handle_event("open_revoke_session", %{"token" => encoded_token}, socket) do
  raw_token = Base.url_decode64!(encoded_token, padding: false)
  sessions = socket.assigns.detail.sessions

  if Enum.any?(sessions, &(&1.hashed_token == raw_token)) do
    {:noreply,
     assign(socket, :confirm_action, %{
       type: :revoke_session,
       token: raw_token,
       copy: revoke_session_copy(socket.assigns.detail)
     })}
  else
    {:noreply, put_flash(socket, :error, "Session not found.")}
  end
end
```

This ensures the token can only ever reference a session already loaded and
authorized for the current `detail.user.id`.

---

## Warnings

### WR-01: `return_to` renders as bare `href` when nil — produces invalid `href=""`

**File:** `lib/sigra/admin/live/user_show_live.ex:91`

**Issue:** `mount/3` initializes `:return_to` to `nil` (line 18). During the brief
window between `mount` and the first `handle_params` (which sets the real value),
the template renders:

```heex
<a class="btn btn-ghost min-h-11" href={@return_to}>Back to users</a>
```

When `@return_to` is `nil`, Phoenix will render `href=""`, which is a relative
link to the current URL. On a live navigation reconnect or when a user clicks
before the patch resolves, they stay on the same page rather than returning to the
users list. The same nil issue applies to line 202 (`full_audit_path`).

**Fix:** Provide a safe default in `mount/3`, or guard the anchor with `:if`:

```elixir
# Option A: default in mount
|> assign(:return_to, "/admin/users")

# Option B: guard in template
<a :if={@return_to} class="btn btn-ghost min-h-11" href={@return_to}>Back to users</a>
```

---

### WR-02: `handle_event` callbacks `open_revoke_all_sessions` and `cancel_confirm` are missing `@impl true` annotations

**File:** `lib/sigra/admin/live/user_show_live.ex:47,55`

**Issue:** `handle_event("open_revoke_session", ...)` at line 37 carries `@impl true`.
The next two `handle_event` clauses at lines 47 and 55 do not. Without `@impl true`,
Dialyzer cannot verify these clauses implement the correct callback signature, and a
future rename of the first clause would orphan the remaining clauses silently.

**Fix:**

```elixir
@impl true
def handle_event("open_revoke_all_sessions", _params, socket) do
  ...
end

@impl true
def handle_event("cancel_confirm", _params, socket) do
  ...
end
```

---

### WR-03: Seeds test compares `credential.encrypted_secret` directly against `Personas.demo_totp_secret()` — the assertion is vacuous because the type is a passthrough

**File:** `test/example/test/example/demo/seeds_test.exs:167`

**Issue:** The test asserts:

```elixir
assert credential.encrypted_secret == Personas.demo_totp_secret(),
```

The `encrypted_secret` field uses `Example.Accounts.Encrypted.Binary`, which is
documented as a "test-only passthrough" that stores the raw binary unencrypted
(`encrypted.ex` line 1–11). The seed orchestrator inserts `Personas.demo_totp_secret()`
directly, and the passthrough type stores it verbatim, so the assertion trivially
passes. It does not test that the seeded secret survives a real encryption
round-trip (which is the intended invariant for production). When a real
`Cloak.Ecto.Binary` type is substituted, `credential.encrypted_secret` will be the
*encrypted* binary, not the raw secret, and this assertion will fail with a
confusing message — but worse, the test currently conveys false confidence.

**Fix:** Document the limitation explicitly and add a separate assertion for the
raw secret once decrypted, or at least note that this assertion only holds with the
passthrough type:

```elixir
# NOTE: `encrypted_secret` is the raw binary (passthrough Ecto type in test).
# When a real Cloak.Ecto.Binary vault is substituted, this must be changed
# to decrypt the ciphertext before comparing.
assert credential.encrypted_secret == Personas.demo_totp_secret()
```

Alternatively, route the check through `Accounts` context functions that would
perform decryption, so the test remains valid under both type implementations.

---

### WR-04: `seeds_test.exs` lacks the `@moduletag :example_app` tag, so the seeds smoke runs in `mix test` (library suite) when the example app's database is not present

**File:** `test/example/test/example/demo/seeds_test.exs:1`

**Issue:** The example app's `test_helper.exs` excludes `:example_app` by default
(`ExUnit.start(exclude: [:example_app])`). The `example_unit_smoke` CI job re-includes
them with `mix test --include example_app`. The seeds test has no `@moduletag :example_app`,
so it runs unconditionally whenever `mix test` is invoked in the example directory without
`--exclude example_app`. While this is fine in CI (the example job always passes the
correct flag), a developer running a focused `mix test test/example/` locally without a
seeded database will silently trigger the seeds orchestrator and potentially leave
unexpected data, or crash if the DB is absent.

More importantly: the `library_tests` CI job runs `mix test` at the **repository root**,
not inside `test/example/`, so this specific file is never accidentally picked up by the
library suite. But within the example app directory, the unconditional behavior is
inconsistent with every other example test that uses `@moduletag :example_app`.

**Fix:** Add the module tag for consistency:

```elixir
@moduletag :example_app
```

---

### WR-05: `assertDemoScreenshot` accepts `testInfo: TestInfo` but never uses it — unused parameter that will trigger TypeScript strict-mode warnings

**File:** `test/example/priv/playwright/tests/demo-showcase.spec.ts:49-59`

**Issue:** The function signature is:

```ts
async function assertDemoScreenshot(
  page: Page,
  testInfo: TestInfo,
  slug: string,
) {
  const ci = process.env.CI === 'true';
  await expect(page).toHaveScreenshot(`${slug}.png`, { ... });
}
```

`testInfo` is never referenced inside the function body. In `admin-checkpoints.spec.ts`,
the analogous `assertCheckpointScreenshot` function uses `testInfo.project.name` to
branch on `dark` and `mobile`. The unused parameter here creates a misleading
signature and will produce a `@typescript-eslint/no-unused-vars` warning if strict
linting is ever enforced. It also suggests the intent was to branch on project name
(to set different tolerances per project) but that logic was inadvertently omitted.

**Fix:** Either remove the parameter if it is genuinely not needed:

```ts
async function assertDemoScreenshot(page: Page, slug: string) { ... }
// and update all call sites to drop testInfo
```

Or use it for project-aware tolerance (matching the admin-checkpoints pattern):

```ts
async function assertDemoScreenshot(page: Page, testInfo: TestInfo, slug: string) {
  const ci = process.env.CI === 'true';
  const mobile = testInfo.project.name.includes('mobile');
  await expect(page).toHaveScreenshot(`${slug}.png`, {
    fullPage: false,
    maxDiffPixels: ci ? 200_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : 0.06,
  });
}
```

---

## Info

### IN-01: `otplib` import is retained as dead code with an eslint-disable comment

**File:** `test/example/priv/playwright/tests/demo-showcase.spec.ts:7`

**Issue:**

```ts
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { authenticator } from 'otplib';
```

The comment suppresses a lint warning for an import that is explicitly described as
unused ("imported for future TOTP challenge integration"). This adds `otplib` as a
bundle dependency and the suppression comment papers over what is essentially planned-but-not-implemented code. If the future TOTP integration never materializes, the import
and suppression will remain indefinitely.

**Fix:** Remove the import and the associated comment now. If TOTP challenge
integration is needed in the future, the import can be restored at that time. The
`DEMO_TOTP_B32` constant and the long comment block explaining the rationale can be
retained without the runtime import.

---

### IN-02: `snapshot_counts/0` computes `enterprise_connections` but no test asserts the value

**File:** `test/example/test/example/demo/seeds_test.exs:71-75`

**Issue:** `snapshot_counts/0` queries `EnterpriseConnection` by `display_name ==
"Acme Corp SSO"` and includes the count in the returned map. The idempotency test
asserts `first == second` (covering all map keys), but no test asserts a specific
value like `first.enterprise_connections == 1`. If the seeds orchestrator stops
inserting the `EnterpriseConnection` row, the idempotency test will still pass
(both runs produce `0`), and no targeted test will surface the regression.

**Fix:** Add a targeted assertion:

```elixir
assert first.enterprise_connections == 1
```

---

### IN-03: Demo-showcase PNG baselines that match `admin-*.png` will be swept into the admin checkpoint artifact bundle on failure

**File:** `.github/workflows/ci.yml:792-808`

**Issue:** The "Collect curated admin checkpoint screenshots" step collects
`test-results/**/admin-*.png` into `artifacts/admin-checkpoints/`. The
`demo-showcase.spec.ts` uses slugs `admin-user-list` and `admin-user-detail` for
two of its four `toHaveScreenshot` baseline comparisons. When a baseline comparison
fails, Playwright writes the diff into `test-results/`, and these files match the
`admin-*.png` glob — they will be collected into the admin checkpoint bundle even
though they are demo-showcase artifacts, not admin checkpoint artifacts. This
conflates two conceptually distinct artifact families and could confuse reviewers
examining the artifact bundle after a CI failure.

**Fix:** Use slug names that do not begin with `admin-` for the demo-showcase
screenshots, or prefix them distinctively:

```ts
await assertDemoScreenshot(page, testInfo, 'demo-admin-user-list');
await assertDemoScreenshot(page, testInfo, 'demo-admin-user-detail');
```

This keeps the snapshot baselines in `tests/demo-showcase.spec.ts-snapshots/`
aligned with the new slugs (the baselines would need to be regenerated), but
prevents demo-showcase failure artifacts from polluting the admin checkpoint bundle.

---

_Reviewed: 2026-05-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
