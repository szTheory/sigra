# Phase 242: Close gap: XW-01/XW-02 — add rendered Crosswake start control - Pattern Map

**Mapped:** 2026-08-11  
**Files analyzed:** 4 (three required modifications; one conditional source-contract update)  
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/example/lib/example_web/live/app_live.ex` | LiveView component | request-response | same file's authenticated Tasklane quick-actions grid; `test/example/lib/example_web/controllers/confirmation_html.ex` | exact surface / role-match form |
| `test/example/test/example_web/live/app_live_test.exs` | test | request-response | same file's authenticated `/app` rendering tests | exact |
| `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` | browser integration test | request-response | same file's real-cookie-jar redirect proof | exact |
| `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` (only if a narrow source contract is added) | source-contract test | transform | same file's browser/config contract guard | exact |

## Pattern Assignments

### `test/example/lib/example_web/live/app_live.ex` (LiveView component, request-response)

**Analogs:** this file's authenticated account-home and quick-actions surface (lines 44-124); `test/example/lib/example_web/controllers/confirmation_html.ex` regular controller form (lines 27-43).

**Tasklane surface and stable readiness pattern** — `app_live.ex` lines 44-58:

```elixir
<Layouts.app
  flash={@flash}
  current_scope={@current_scope}
  user_organizations={@user_organizations}
>
  <section class="vt-page-intro" data-testid="app-account-home">
    <header class="vt-panel__header">
      <div>
        <p class="vt-kicker">Your Tasklane account</p>
        <h1 class="vt-panel__title">Welcome back, {@greeting_name}</h1>
```

Keep the rendered entry inside this authenticated `vt-*` account hub. Do not introduce `sg-*` styles, an admin surface, or a new LiveView event handler.

**Quick-action panel pattern** — `app_live.ex` lines 108-124:

```elixir
<div class="vt-card-grid vt-card-grid--three" data-testid="app-quick-actions">
  <a href={~p"/users/settings"} class="vt-panel">
    <p class="vt-kicker">Account</p>
    <h2 class="vt-panel__title">Settings</h2>
    <p class="vt-copy">Update your email, password, and account preferences.</p>
  </a>
```

Add the Crosswake affordance as a fourth Tasklane panel (or equivalent adjacent action panel), using `vt-panel`, `vt-kicker`, `vt-panel__title`, `vt-copy`, and `vt-btn vt-btn--primary`. Preserve `app-quick-actions` and `app-account-home` readiness hooks.

**Native controller POST form pattern** — `confirmation_html.ex` lines 27-43:

```elixir
<.form for={%{}} id="confirmation_form" action={~p"/users/confirm"} method="post">
  <.input
    name="code"
    type="text"
    label={dgettext("sigra", "Confirmation code")}
    required
  />

  <.button class="btn btn-primary w-full">
    {dgettext("sigra", "Confirm email")} <span aria-hidden="true">&rarr;</span>
  </.button>
</.form>
```

Copy only the `for={%{}}`, `action`, and `method="post"` mechanics for the new zero-input form, changing the action to `~p"/crosswake/start"` and using a native `<button type="submit">` with a unique accessible name such as `Continue to Crosswake`. The form must have no `phx-submit` and no input fields for continuation, state, PKCE, binding, session, route, destination, or evaluator values; Phoenix owns the standard CSRF field.

**Existing authenticated controller boundary (do not modify)** — `test/example/lib/example_web/router.ex` lines 126-138:

```elixir
scope "/", ExampleWeb do
  pipe_through [:browser, :require_authenticated]

  delete "/impersonation", Admin.ImpersonationController, :delete
  post "/crosswake/start", CrosswakeController, :start

  live_session :app_authenticated,
    on_mount: [{ExampleWeb.UserAuth, :ensure_authenticated}] do
    live "/app", AppLive, :home
  end
end
```

The new form delegates to this existing CSRF-protected authenticated route. It must not add a route, controller action, or client-side protocol orchestration.

---

### `test/example/test/example_web/live/app_live_test.exs` (test, request-response)

**Analog:** same file's authenticated LiveView rendering test (lines 13-29).

```elixir
test "greets a standard user and hides operator surfaces", %{conn: conn} do
  user = user_fixture()
  conn = log_in_user(conn, user)

  {:ok, _lv, html} = live(conn, ~p"/app")

  assert html =~ "Welcome back"
  assert html =~ user.email
  assert html =~ "app-account-home"
  assert html =~ "app-security"
  refute html =~ "app-platform-admin"
  refute html =~ "Open Sigra Admin"
end
```

Extend this existing authenticated-user test style: log in through `log_in_user/2`, render `/app` with `live/2`, and make narrow HTML/source assertions for the visible control. Lock the rendered form's `/crosswake/start` action, `method="post"`, unique accessible button text, and absence of `phx-submit` / Crosswake protocol-value names. Do not call a LiveView event, because a normal browser POST is the contract.

---

### `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` (browser integration test, request-response)

**Analog:** same file's current real-cookie-jar proof (lines 9-35 and 58-93).

**Authentication and stable precondition** — lines 9-22:

```typescript
await page.goto('/users/log_in');

const passwordForm = page.locator('#login_form');
await passwordForm.getByLabel('Email').fill(DEMO_ALICE_EMAIL);
await passwordForm.getByLabel('Password').fill(DEMO_ALICE_PASSWORD);
await passwordForm.getByRole('button', { name: 'Log in' }).click();
await expect(page).not.toHaveURL(/\/users\/log_in/);

const sessionCookie = (await page.context().cookies()).find((cookie) => cookie.name === '_example_key');
expect(sessionCookie).toBeDefined();
expect(sessionCookie?.httpOnly).toBe(true);
expect(sessionCookie?.sameSite).toBe('Lax');
```

Keep this real browser cookie-jar setup unchanged.

**Pre-register transition observers** — lines 24-35:

```typescript
const returnRequest = page.waitForRequest((request) => {
  const url = new URL(request.url());
  return request.method() === 'GET' && url.pathname === '/crosswake/return';
});
const appRequest = page.waitForRequest((request) => {
  const url = new URL(request.url());
  return (
    request.method() === 'GET' &&
    request.resourceType() === 'document' &&
    url.pathname === '/app'
  );
});
```

Keep both promises before the user action. Replace only the `page.evaluate()`-created CSRF form at lines 37-56 with the role-based visible control interaction:

```typescript
await page.getByRole('button', { name: 'Continue to Crosswake' }).click();
```

Use the final chosen unique accessible name exactly. Do not add sleeps, request fabrication, direct HTTP calls, or DOM injection.

**Security and safe-return assertions to retain verbatim** — lines 58-93:

```typescript
const returnUrl = new URL((await returnRequest).url());
const appNavigation = await appRequest;
expect(appNavigation.headers()['referer']).toBeUndefined();

expect([...returnUrl.searchParams.keys()].sort()).toEqual(['continuation', 'state']);

await expect(page).toHaveURL(/\/app$/);
await expect(page.locator('[data-testid="app-account-home"]')).toBeVisible();
await expect(page.getByRole('heading', { name: /welcome back/i })).toBeVisible();

expect(returnUrl.toString()).not.toContain('pkce_verifier');
expect(finalUrl).not.toContain('pkce_verifier');
```

Keep the remaining sentinel loop in lines 80-93 unchanged: it is the correlation/secret non-disclosure evidence.

**Focused serial project pattern** — `test/example/priv/playwright/playwright.config.ts` lines 196-203:

```typescript
// The continuation proof is intentionally one Chromium spec. It inherits
// the serial, one-worker, zero-retry settings above and does not retain
// success artifacts that could contain transient correlation values.
{
  name: 'crosswake-hosted-runtime',
  testMatch: CROSSWAKE_HOSTED_RUNTIME_SPEC,
  use: { ...devices['Desktop Chrome'] },
},
```

The global config at lines 62-68 supplies `fullyParallel: false`, `workers: 1`, and `retries: 0`; retain that focused project and runner invocation.

---

### `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` (source-contract test, transform; conditional)

**Analog:** same file's browser/config guard (lines 182-210).

```elixir
test "continuation, controller, browser, and serial project guards name the real security matrix" do
  continuation_test = read!(@continuation_test)
  controller_test = read!(@controller_test)
  browser_test = read!(@browser_test)
  playwright_config = read!(@playwright_config)

  assert browser_test =~ "hosted Crosswake local return preserves the real cookie jar"
  assert browser_test =~ "page.waitForRequest"
  assert playwright_config =~ "name: 'crosswake-hosted-runtime'"
  assert playwright_config =~ "workers: 1"
  assert playwright_config =~ "retries: 0"
end
```

Only update this file if needed to make the rendered-entry contract durable. Follow its module attributes + `read!/1` source-inspection pattern: add an `@app_live` path, read it in this focused guard, and assert small stable markers for the action route, POST method, named native button, and no `phx-submit`. Also change the browser guard from accepting the old synthetic implementation to requiring the role-based click and rejecting `page.evaluate`. Do not replicate controller denial/evaluator assertions already owned by the preceding suites.

## Shared Patterns

### Authenticated, CSRF-protected HTTP boundary

**Source:** `test/example/lib/example_web/router.ex` lines 126-138  
**Apply to:** the `AppLive` form and all rendered-entry tests.

The form is a native POST to the already protected route, not a new LiveView transition. The router's `:browser` pipeline includes `protect_from_forgery` (lines 7-15) and the scope adds `:require_authenticated` (lines 126-130).

### Tasklane host styling and readiness

**Source:** `test/example/lib/example_web/live/app_live.ex` lines 51-58 and 108-124  
**Apply to:** `AppLive` UI and Playwright readiness assertions.

Use `vt-*` classes and leave `data-testid="app-account-home"` in place. This is example-host Tasklane UI; no `sg-*`, Rail Accent, or admin theme work belongs here.

### Redirect-observer timing and secret boundaries

**Source:** `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` lines 24-35 and 58-93  
**Apply to:** the browser proof.

Register request observers before clicking. Preserve exact callback keys, missing Referer, fixed `/app` final navigation, and all verifier/correlation non-disclosure checks; do not log or reconstruct observed continuation/state values.

### Deterministic proof execution

**Sources:** `test/example/priv/playwright/playwright.config.ts` lines 62-68 and 196-203; `scripts/ci/hosted-session-interop-proof.sh` lines 95-104.

The focused browser proof remains one Chromium project, serial, one worker, zero retries, and has no sleeps. Run it through:

```bash
scripts/ci/hosted-session-interop-proof.sh --browser-only
```

The wrapper invokes only `crosswake-hosted-runtime.spec.ts` with `--retries=0`.

### Existing security authority (preserve, do not duplicate)

**Source:** `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs` lines 62-98 and 108-125.

P14 mechanically checks personal `org_id: nil`, encrypted HttpOnly transport, verifier-free callback URL, exact callback keys, fixed route/destination, and denial before evaluator invocation. Keep it green; the new UI tests prove the missing rendered entry rather than reimplementing this matrix.

## No Analog Found

| File | Role | Data Flow | Reason / Planner guidance |
|---|---|---|---|
| None | — | — | The modification targets existing, directly analogous host and proof files. There is no existing `AppLive` regular controller POST form, so use Phoenix.Component's established `for={%{}}`, `action`, `method="post"` form convention from `confirmation_html.ex`, constrained by the phase research. |

## Metadata

**Analog search scope:** `test/example/lib/example_web/live`, `test/example/lib/example_web/controllers`, `test/example/test/example_web/live`, `test/example/priv/playwright`, `test/sigra/planning`, `scripts/ci`  
**Files scanned:** 11 focused implementation, router, test, proof-runner, and guard files  
**Pattern extraction date:** 2026-08-11
