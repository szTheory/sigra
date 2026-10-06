# Phase 246: Generated Confirmation Recovery - Research

**Researched:** 2026-10-06
**Domain:** Generated Phoenix LiveView authentication, confirmation tokens, and fresh-host verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Confirmation routes and token behavior
- **D-01:** Preserve the locked CONF-01 behavior: an anonymous visitor and a signed-in visitor can complete email-link confirmation in the same generated confirmation experience. The link token identifies the account being confirmed. Opening the link only loads a confirmation page; an explicit, keyboard-operable submit performs the state change. This reduces scanner and prefetch side effects while keeping the anonymous path.
- **D-02:** Confirmation must not create a session, sign a visitor in as the token's account, or switch an existing session. If the visitor is signed in, their existing session remains unchanged. Keep the email-link token single-use and bound to its account.
- **D-03:** Code entry and resend operate only for the signed-in account represented by the current request scope. Anonymous visitors must receive clear sign-in guidance and a working link; missing scope must never crash the LiveView. Never accept a target account ID from submitted form data.

### Code paste and account binding
- **D-04:** Accept the confirmation code exactly as displayed in the generated email, including intervening spaces. Browser constraints must not truncate the pasted value or replace Sigra's translated validation with a locale-dependent native error. Normalize permitted whitespace on the server, then require exactly six ASCII digits before attempting verification.
- **D-05:** Confirmation-code verification must match the token to the current account before changing account state. Preserve per-account rate limiting and prove that a valid code for account A cannot confirm account B. The current library verifier accepts a user ID for rate limiting but its token lookup omits that ID; generated code must not be considered secure or complete until the lookup and a cross-account regression case enforce account binding.
- **D-06:** Residual security boundary: anonymous email-link confirmation is an explicit Phase 246 contract. An explicit submit avoids automatic confirmation on scanner GETs and no session change avoids turning the link into a login credential, but this flow alone does not prevent account pre-hijacking when an attacker registers using someone else's email. Do not claim that it does. Preventing that threat would require revisiting the locked anonymous-confirmation contract and is not an unreviewed implementation choice.

### Feedback and accessibility
- **D-07:** Render LiveView confirmation feedback in the shared generated auth page so success and invalid-code messages are visible on the generated screens. Use the existing neutral sigra-auth component and CSS vocabulary; do not introduce a new visual system or expose backend details. Success updates should be announced as a status; validation errors should be announced as an alert/live-region message without forcing focus away from the form. Keep copy localized and allow retry after an invalid code.

### Automated evidence
- **D-08:** Prove the behavior at distinct seams: focused LiveView/integration tests for both link-confirmation session states, persisted confirmed_at changes, anonymous code/resend handling, and cross-account code rejection; template contract assertions for feedback semantics; and one real-browser path in a freshly generated host for actual spaced-code paste and visible success/error feedback.
- **D-09:** Put the generated-host proof on the recurring required CI path for changes to generated auth. Reuse the existing install-smoke and Playwright infrastructure where practical, keep the browser path narrow to avoid duplicating the whole LiveView matrix, and preserve failure output that identifies the failed path. All acceptance evidence is automated; no human UAT is needed. Browser automation should use stable accessible selectors and deterministic readiness, without sleeps.

### the agent's Discretion
The planner may choose the smallest route grouping and helper structure consistent with these decisions, the exact whitespace normalization implementation, focused test names/fixtures, and the existing CI job that should own the generated-host browser check. Prefer existing Phoenix, ExUnit, and Playwright patterns; do not add a new framework or broad generated-auth coverage.

### Deferred Ideas (OUT OF SCOPE)
- SEED-011 C (wide transactional-email rendering), E (error modifier vocabulary), F (spent-link messaging), and G (Apple Mail styling) remain separate findings.
- Broad generated-auth runtime and axe coverage remains in AUTHUI-01 and the W-3 follow-up; Phase 246 adds only confirmation-journey evidence.
- Preventing account pre-hijacking would require changing the locked anonymous-confirmation contract and needs a separate product/security decision if the project chooses to take that on.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONF-01 | In a freshly generated host app, an anonymous visitor and an already signed-in visitor can complete email confirmation, and the test proves the persisted account state changed rather than relying on response status alone. `[VERIFIED: .planning/REQUIREMENTS.md:16]` | Optional-scope route and explicit submit; focused LiveView/integration cases for both session states; generated-host probe queries persisted `confirmed_at`; narrow browser host proof. |
| CONF-02 | A confirmation code copied from the generated email can be pasted into the generated confirmation form and accepted without browser-side truncation or locale-dependent validation failure. `[VERIFIED: .planning/REQUIREMENTS.md:17]` | Remove incompatible six-character/digit-only HTML constraints; normalize only permitted displayed spacing server-side; validate six ASCII digits; actual clipboard-to-input browser path in a fresh host. |
| CONF-03 | Generated authentication screens display confirmation success and error feedback produced by their LiveViews, including invalid-code feedback. `[VERIFIED: .planning/REQUIREMENTS.md:18]` | Shared auth-page feedback rendering with visible localized notices and status/alert semantics; fast template assertions and browser assertions against visible messages. |
</phase_requirements>

## Summary

Phase 246 is a bounded repair across three connected layers: generated router policy, generated LiveView/token handling, and generated-host proof. The route generator currently places the LiveView routes in the same scope as `redirect_if_user_is_authenticated`; the token LiveView confirms inside `handle_params`; the code input constrains entry to six digits even though the generated HTML email separates digits with spaces; and the shared auth page currently renders its inner slot without a flash/feedback region. The library's confirmation-code verifier rate-limits by user but looks up a code without that user filter. These are direct code observations. `[VERIFIED: lib/sigra/install/features/core.ex:370-376,500-509; priv/templates/sigra.install/core/confirmation_live.ex:38-49,99-120; priv/templates/sigra.install/core/emails.ex:19-32; priv/templates/sigra.install/core/sigra_auth_components.ex:27-62; lib/sigra/auth.ex:963-989]`

Plan the work around a single optional-scope confirmation route that serves both anonymous and authenticated visitors. Render a confirmation prompt on link GET, and perform the token mutation only from an explicit submit event. Keep token resolution and cleanup in the existing library transaction, with no session creation or switch. For code verification, bind token lookup to the `current_scope` user before state mutation, preserve rate limiting, remove only the ASCII spaces intentionally inserted for display, and validate exactly six ASCII digits. Reuse the generated auth page, existing `sigra-auth-*` classes, ExUnit/LiveViewTest, install-smoke fresh host, and Playwright. **Primary recommendation:** keep fast contract tests in the library suite, add generated-host behavior tests that assert persisted state, then add one required Chromium browser scenario against the host produced by install-smoke.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Route availability and optional visitor scope | Frontend Server (SSR) | API / Backend | Generated router pipeline and LiveView mount policy determine whether anonymous and signed-in visitors can open the same confirmation page. `[VERIFIED: lib/sigra/install/features/core.ex:500-509; priv/templates/sigra.install/core/user_auth.ex:317-344]` |
| Explicit link confirmation and session invariance | API / Backend | Frontend Server (SSR) | The generated LiveView event invokes the library verifier; the verifier owns atomic account state/token updates. The route must not invoke login/session APIs. `[VERIFIED: lib/sigra/auth.ex:856-942; 246-CONTEXT.md D-01-D-02]` |
| Code normalization and account-bound verification | API / Backend | Browser / Client | Browser input must carry the complete displayed value; server normalization, validation, user-scoped query, rate limit and persistence enforce correctness. `[VERIFIED: priv/templates/sigra.install/core/emails.ex:19-32; priv/templates/sigra.install/core/user_token.ex:156-168; lib/sigra/auth.ex:963-989]` |
| Visible localized feedback | Frontend Server (SSR) | Browser / Client | LiveView assigns/flash are server state; shared generated auth components render them with accessible semantics and existing styles. `[VERIFIED: priv/templates/sigra.install/core/confirmation_live.ex:162-179; priv/templates/sigra.install/core/sigra_auth_components.ex:27-62; priv/templates/sigra.install/core/sigra_auth.css:252-284,360-362]` |
| Durable regression evidence | API / Backend | Browser / Client | ExUnit/LiveViewTest prove callbacks and persisted DB state; a real browser verifies pasted display text and visible feedback in fresh generated output. `[VERIFIED: scripts/ci/install-smoke.sh:1-12,167-229; .github/workflows/ci.yml:756-824,1585-1590]` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | `~> 1.18` | Generator, library auth, LiveView, ExUnit | Existing project requirement. `[VERIFIED: mix.exs:7-12]` Quote: `elixir: "~> 1.18"`. |
| Phoenix | `~> 1.8` (lockfile: `1.8.13`) | Router/pipeline and generated host | Existing required framework and locked dependency. `[VERIFIED: mix.exs:99-103; mix.lock:47]` Quote: `{:phoenix, "~> 1.8"}`; `"phoenix": {:hex, :phoenix, "1.8.13"`. |
| Phoenix LiveView | `~> 1.1` (lockfile: `1.1.33`) | Generated interactive confirmation page and LiveViewTest | Existing required framework. `[VERIFIED: mix.exs:99-103; mix.lock:49]` Quote: `{:phoenix_live_view, "~> 1.1"}`; `"phoenix_live_view": {:hex, :phoenix_live_view, "1.1.33"`. |
| ExUnit + Phoenix.LiveViewTest | Existing project test stack | Route, connected LiveView, event, and persisted-state tests | LiveViewTest supplies the repo-consistent event-level seam; official docs cover `live/2`, `render_submit/2`, and `render_change/2`. `[CITED: https://phoenix-live-view.hexdocs.pm/1.2.11/Phoenix.LiveViewTest.html]` |
| Playwright Test | `1.62.1` | Single Chromium fresh-host proof | Existing pinned browser test runner. `[VERIFIED: test/example/priv/playwright/package.json:13]` Quote: `"@playwright/test": "1.62.1"`. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ecto / Repo | `~> 3.12` | Token lookup, account update and persistence assertions | Existing generated auth data layer; preserve the library transaction boundary. `[VERIFIED: mix.exs:99-106]` Quote: `{:ecto, "~> 3.12"}`; `{:ecto_sql, "~> 3.12"}`. |
| Gettext | Existing generated host backend | Localized success, invalid-code and anonymous-scope guidance | Keep user-facing feedback in the existing generated locale catalog. `[VERIFIED: priv/templates/sigra.install/core/confirmation_live.ex:14,25-27,177-183]` Quote: `use Gettext, backend: <%= web_module %>.Gettext`; `dgettext("sigra", "Invalid confirmation code. Please try again.")`. |

No external package installation is needed for this phase. Use the already pinned Playwright package and existing Phoenix/ExUnit dependencies; the phase context explicitly says not to add a framework.

## Architecture Patterns

### System Architecture Diagram

```text
Email link or displayed code
            |
            v
Generated browser pipeline (fetches current scope; allows nil)
            |
            v
ConfirmationLive GET / mount + render prompt only
       |                           |
       | link token                | code / resend event
       v                           v
explicit link submit           require current-scope user
       |                           |
       v                           v
Sigra.Auth.confirm_user     normalize permitted spaces -> validate
       |                    six ASCII digits -> per-user rate limit
       |                           |
       v                           v
atomic confirmed_at +      user-scoped confirmation token query
delete confirm tokens              |
       |                           v
       |                     atomic confirmed_at + token cleanup
       +-------------+-------------+
                     v
Shared SigraAuthComponents renders localized visible feedback
                     |
                     v
LiveViewTest + fresh-host DB probe + narrow Chromium browser proof
```

### Recommended Project Structure

Keep implementation in the existing generator-owned seams; update tests alongside each seam.

```text
lib/sigra/install/features/core.ex                 # route grouping/pipeline injection
lib/sigra/auth.ex                                  # code verifier lookup scoping
priv/templates/sigra.install/core/
├── confirmation_live.ex                          # optional scope, explicit link submit, code validation
├── auth.ex                                        # generated verifier call; current user only
├── user_token.ex                                  # scoped code query already exists
├── sigra_auth_components.ex                       # shared feedback rendering
└── sigra_auth.css                                 # existing neutral status/notice classes
test/sigra/install/                                # fast generator/template assertions
scripts/ci/install-smoke.sh                        # fresh-host setup and integration probe
test/example/priv/playwright/tests/                # one generated-host confirmation scenario
.github/workflows/ci.yml                           # recurring required lane
```

### Pattern 1: Optional-scope generated confirmation route

**What:** Put confirmation routes on the normal browser pipeline with the current-scope mount hook, but outside the `redirect_if_user_is_authenticated` group. The generated `:mount_current_scope` callback supports a nil scope; the redirect callback halts when the scope exists. Keep any signed-in-only code/resend behavior guarded at event handling time, and always derive the target account from the server-assigned current scope.

**When to use:** The user-facing link must work anonymously while other generated auth entry pages continue redirecting signed-in users.

**Example:** Current source routes `live "/confirm"` and `live "/confirm/:token"` are emitted in the scope that pipes through `:redirect_if_user_is_authenticated` (`lib/sigra/install/features/core.ex:370-376,500-509`). Generated scope hooks distinguish optional current scope from required auth (`priv/templates/sigra.install/core/user_auth.ex:317-344`). Preserve the route values exactly as quoted: `live "/confirm", ConfirmationLive`; `live "/confirm/:token", ConfirmationLive, :confirm` `[VERIFIED: lib/sigra/install/features/core.ex:370-376]`.

### Pattern 2: GET display; explicit event performs mutation

**What:** `handle_params` reads the untrusted route token into server-side LiveView state and renders the confirmation action. A keyboard-operable `phx-submit` invokes a distinct `handle_event`; only that event calls the library's token verifier. Keep the existing atomic library operation responsible for setting `confirmed_at` and deleting confirmation credentials. Never call session creation, login, or scope switching from the link verifier.

**When to use:** The link may be opened by scanners or prefetchers and confirmation is an intentional user action. RFC 9110 defines safe methods as methods whose semantics are essentially read-only; the LiveView pattern also separates parameter handling from client events. This is a risk-reduction pattern under the locked contract, not a resolution of account pre-hijacking. `[CITED: https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.1; https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html]`

### Pattern 3: Normalize only the email's visual separators

**What:** The generated email constructs the HTML code by joining digit graphemes with U+0020 spaces (`priv/templates/sigra.install/core/emails.ex:19-22`). Remove only those expected literal spaces, then match the whole normalized string against six ASCII digits before rate-limited verification. Reject tabs, line breaks, non-breaking spaces, Unicode digits, letters and all extra characters. The text input must not impose a maximum of six before the server receives the spaced value; remove its digit-only native `pattern` so localized server feedback remains available. Server checks still apply regardless of browser constraints.

**When to use:** A copied value includes exactly the spaces inserted by the generated email. The HTML standard defines `maxlength` and `pattern` as text-control constraints, and Elixir Regex uses explicit character ranges when a narrow character set is required. `[CITED: https://html.spec.whatwg.org/multipage/input.html; https://hexdocs.pm/elixir/Regex.html]`

**Implementation sketch (recommendation):**

```elixir
# Remove only the separator emitted by the generated HTML email.
normalized = String.replace(code, " ", "")
valid? = Regex.match?(~r/\A[0-9]{6}\z/, normalized)
```

`[ASSUMED]` This exact whitespace policy is the recommended default from the generated email's current formatter and D-04; lock it in the focused unit cases. The quote-backed in-repo display behavior is `code_display = code |> String.graphemes() |> Enum.join(" ")` `[VERIFIED: priv/templates/sigra.install/core/emails.ex:19-22]`.

### Pattern 4: Bind the code query before mutation

**What:** Preserve per-account rate-limit keying and include the same current-scope user ID in the confirmation token query. The generated `UserToken.verify_confirmation_code_query/2` already returns a query filtered by token hash, `confirm_code` context, `user_id`, and TTL, but `Sigra.Auth.verify_confirmation_code/3` currently bypasses it with `repo.get_by/3` on token hash/context alone. Change the verifier to use the scoped query and verify the returned record belongs to the current user before mutating state; return invalid-code for a mismatch. Keep user ID server-derived, never form-provided.

**When to use:** Every code-based account transition. Assert account A's valid code cannot change account B, including while B is the signed-in request scope.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Signed, hashed, single-use confirmation token lifecycle | New token format, ad hoc DB update, or route-specific token deletion | Existing `Sigra.Auth.confirm_user/3` library transaction | It verifies the signed credential, persists `confirmed_at`, and deletes link/code tokens atomically for the token's owner (`lib/sigra/auth.ex:856-942`). |
| Rate limiting | A confirmation-specific counter or browser throttle | Existing verifier per-user rate limiter | The library already keys attempts by user ID (`lib/sigra/auth.ex:971-977`); account binding must augment its lookup, not replace the limiter. |
| Auth page design | New alert framework or new design system | `sigra_auth_page`, existing notice/status classes, Gettext | Generator components and CSS already define the host auth surface. `[VERIFIED: priv/templates/sigra.install/core/sigra_auth_components.ex:17-62; priv/templates/sigra.install/core/sigra_auth.css:250-284,360-362]` |
| Browser synchronization | Sleeps and DOM-position selectors | Playwright accessible locators, live readiness and retrying assertions | Playwright locators auto-wait; role/label locators and web-first assertions give stable, observable checks. `[CITED: https://playwright.dev/docs/locators; https://playwright.dev/docs/test-assertions]` |

**Key insight:** Token security depends on the verifier's query shape and transaction, not on a route or UI check. The UI must preserve the identity source and invoke that verifier only after the intended submit.

## Common Pitfalls

### Pitfall 1: Keeping confirmation inside the signed-in redirect pipeline

**What goes wrong:** Anonymous entry works while a signed-in link visitor is redirected away before the token flow.
**Why it happens:** The route injection currently emits confirmation routes in a scope piped through `redirect_if_user_is_authenticated`.
**How to avoid:** Split confirmation route placement from login/registration redirects; mount optional current scope.
**Warning signs:** Tests only exercise an anonymous conn, or authenticate then open the link and get sent to the signed-in path. `[VERIFIED: lib/sigra/install/features/core.ex:500-509; priv/templates/sigra.install/core/user_auth.ex:336-344]`

### Pitfall 2: Mutating on token GET or changing the visitor's session

**What goes wrong:** A link fetch changes account state before an explicit action, or a visitor is signed in as the account named by the link.
**Why it happens:** The generated LiveView calls `Auth.confirm_user(token)` in `handle_params`, which runs for initial route parameters; this currently sets `confirmed_at` and consumes tokens.
**How to avoid:** Render a confirmation page from params; call the existing verifier only on explicit submit. Assert persisted state remains unchanged after link GET and the original signed-in user/session remains unchanged after submit.
**Warning signs:** `Auth.confirm_user/1` appears in `handle_params`; tests assert only a response or redirect. `[VERIFIED: priv/templates/sigra.install/core/confirmation_live.ex:99-120; lib/sigra/auth.ex:868-905]`

### Pitfall 3: Treating the displayed code as six input characters

**What goes wrong:** `123 456` is clipped at six characters or blocked by the HTML pattern before LiveView sees it.
**Why it happens:** Email HTML inserts five spaces, while the input sets `maxlength="6"` and `pattern="[0-9]{6}"`.
**How to avoid:** Let the text input carry the displayed value; normalize only permitted spaces on the server, validate the complete six-digit ASCII representation, and return localized LiveView feedback for invalid input.
**Warning signs:** Browser test uses only a six-digit unspaced value, or input markup still imposes six characters. `[VERIFIED: priv/templates/sigra.install/core/emails.ex:19-32; priv/templates/sigra.install/core/confirmation_live.ex:38-49]`

### Pitfall 4: Treating the rate-limit user ID as token account binding

**What goes wrong:** A code token can resolve to the token owner's user even when the currently signed-in account differs.
**Why it happens:** The verifier uses `user_id` for rate-limit keying but does not add it to `repo.get_by` lookup; the generated scoped query is presently unused on this path.
**How to avoid:** Use the scoped query and add a cross-account integration regression with persisted state assertions for both users. Preserve token cleanup/account semantics and the per-account rate limiter.
**Warning signs:** Tests verify a code while signed in as the code's owner only; source lookup contains no `user_id` predicate. `[VERIFIED: lib/sigra/auth.ex:963-989; priv/templates/sigra.install/core/user_token.ex:156-168]`

### Pitfall 5: Rendering flashes only in LiveView state

**What goes wrong:** Success or invalid-code events set flashes but generated auth screens show no text announcement.
**Why it happens:** The shared auth page currently renders its slot and branding, with no flash rendering; LiveView flash state alone is not visible output.
**How to avoid:** Add shared visible feedback markup inside the existing auth page. Use localized strings, current neutral success/danger class vocabulary, `role="status"`/polite announcement for success and alert semantics for validation failure; keep the message in the form flow without stealing focus.
**Warning signs:** Tests inspect `Phoenix.Flash` or source strings but do not assert rendered visible text and live-region semantics. W3C explains status messages should be programmatically exposed without focus change. `[VERIFIED: priv/templates/sigra.install/core/sigra_auth_components.ex:27-62; priv/templates/sigra.install/core/confirmation_live.ex:162-179; CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html]`

## Code Examples

Verified patterns from official sources:

### Separate parameter display from explicit submit

```elixir
def handle_params(%{"token" => token}, _uri, socket) do
  {:noreply, assign(socket, :confirmation_token, token)}
end

def handle_event("confirm_link", _params, socket) do
  # Verify the server-held route token here; do not create or switch a session.
end
```

`[CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html; https://phoenix-live-view.hexdocs.pm/bindings.html]` `handle_params` runs after mount for route params, `handle_event` handles client bindings, and client payloads are untrusted. The event name shown is an implementation example, not a locked project value.

### Test LiveView submit and persisted state

```elixir
{:ok, view, _html} = live(conn, confirmation_url)
assert view |> element("form") |> render_submit(%{confirmation: %{code: pasted_code}}) =~ success_copy
assert repo.reload!(target_user).confirmed_at
```

`[CITED: https://phoenix-live-view.hexdocs.pm/1.2.11/Phoenix.LiveViewTest.html]` The official test API documents LiveView mounting and form submit/change event helpers. Use the host's test case/repo fixtures and assert the stored record, not only response HTML. This test sketch is a pattern, not a claim that these exact test helpers/values already exist in the repository.

### Deterministic browser proof

```typescript
const codeInput = page.getByRole('textbox', { name: 'Confirmation code' });
await codeInput.waitFor({ state: 'visible' });
// Put the exact email display value on the clipboard, then paste through Chromium.
await page.getByRole('button', { name: 'Confirm email' }).click();
await expect(page.getByRole('status')).toContainText(successCopy);
```

`[CITED: https://playwright.dev/docs/locators; https://playwright.dev/docs/test-assertions; https://playwright.dev/docs/api/class-browsercontext]` Configure only the generated-host origin for clipboard permissions and trigger the browser paste key after setting the clipboard to the spaced email value; the example omits that setup for brevity. Wait for the app's LiveView-ready signal/visible form and use Playwright's actionability and retrying assertions; do not use fixed sleeps. Include the negative invalid-code attempt and retry on the same accessible form.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Mutate when a token route's params are handled | Render an explicit confirmation step and mutate on form submit | Phase 246 contract, 2026-10-06 | Link GET remains display-only; submit is the user-intended mutation. `[VERIFIED: 246-CONTEXT.md D-01; CITED: Phoenix LiveView lifecycle docs]` |
| Treat copied code as six unspaced digits | Accept the email's displayed spacing and normalize server-side before strict validation | Phase 246 contract, 2026-10-06 | Browser no longer needs to silently trim/truncate; server retains exact validation authority. `[VERIFIED: 246-CONTEXT.md D-04; priv/templates/sigra.install/core/emails.ex:19-32]` |
| Rely on event flash assignment alone | Render visible localized status/error messages in the shared generated auth page | Phase 246 contract, 2026-10-06 | LiveView result reaches visual users and assistive technology without forced focus. `[VERIFIED: 246-CONTEXT.md D-07; CITED: W3C WCAG 2.2 SC 4.1.3]` |

**Deprecated/outdated:** The current `handle_params` mutation and six-character input rules are defects for this contract, not patterns to preserve. The current raw confirmation code lookup also does not satisfy D-05 account binding.

## Project Constraints (from AGENTS.md)

- For generated/auth UI, preserve the `sg-*` cascade-layer/BEM design system; use existing generated `sigra-auth-*` vocabulary and Rail Accent brand assets from `brandbook/` where a brand asset is needed.
- Support Light, Dark, and System modes; keep the shared page theme/branding integration intact.
- Keep Playwright/browser coverage deterministic: accessible role selectors, stable hooks when a named role is insufficient, LiveView readiness, no sleeps.
- Within this authorized phase, use deterministic tests, browser automation, CI and machine-readable evidence in place of human UAT. Do not start unrelated phases or increase product scope. Retry a transient CI failure once; diagnose deterministic failures; never waive absent evidence.
- Leave unrelated dirty worktree files untouched.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Only literal ASCII spaces inserted by the generated HTML email should be removed; tabs/newlines and other Unicode whitespace are rejected. | Architecture Pattern 3 | A mail client that transforms separators could create a false rejection; broaden only if a supported generated email rendering demonstrably emits different whitespace. |
| A2 | The narrow fresh-host browser test can run from the existing Playwright package while targeting the disposable host created by install-smoke, with browser installation added to that CI job if needed. | Validation Architecture | CI wiring may need a small dedicated job if the generated host lifecycle cannot be kept in the install-smoke job; either way the recurring required gate must observe it. |
| A3 | A success feedback result may follow existing redirect behavior after link/code confirmation, provided shared flash rendering makes it visible on the generated destination. | Feedback pattern | If the home route does not render the shared auth page, success copy must be displayed on a confirmation result page instead. |

## Open Questions

1. **Which generated screen owns success feedback after a successful confirmation?**
   - What we know: Current handlers set localized success flash then redirect to `/`; the shared auth page has no flash slot today.
   - What's unclear: Whether every freshly generated host renders shared auth feedback on `/`.
   - Recommendation: Keep success in the shared flash if rendered on the redirected page; otherwise retain the visitor on an explicit confirmation-complete screen that renders the same component. Test the visible success end to end.
2. **How should route groups be split with the generated `--live` and controller modes?**
   - What we know: LiveView confirmation is the phase issue; controller mode emits GET and POST routes from the same authenticated redirect scope.
   - What's unclear: Whether Phase 246 intentionally changes only LiveView generation or expects parity for `--no-live` hosts.
   - Recommendation: Use the scope smallest consistent with D-01 and requirements; discuss-phase says reachable generated Phoenix confirmation flow, while specific D-08 browser proof covers the generated default LiveView. Avoid broad controller redesign unless a confirmed requirement demands it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Library tests and generated host | ✓ | Elixir reports 1.19.5; OTP 28 | CI's pinned toolchain |
| Node / npm | Playwright runner | ✓ | Node v22.14.0; npm 11.1.0 | Existing CI Node setup |
| Chromium executable | Browser proof | ✓ | `chromium` on PATH; version not probed | CI Playwright browser install |
| PostgreSQL client/server | Fresh host migration and persisted-state tests | Client ✓; server not probed | psql 14.17; server availability unknown | CI PostgreSQL service |
| Phoenix installer archive (`phx_new`) | Fresh `phx.new` host in install-smoke | Not probed | — | Existing CI install/setup steps |

No tests were run for this research task, as requested.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest; Playwright Test 1.62.1 |
| Config file | Root `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `mix test test/sigra/install/generator_email_test.exs test/sigra/install/generator_wiring_test.exs test/sigra/install/features/core_test.exs` |
| Full suite command | `mix ci` (repo's normal CI alias); the required CI job includes `install_smoke` and its final gate. `[VERIFIED: .github/workflows/ci.yml:756-824,1585-1590,1620-1644]` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|-------------|----------|-----------|-------------------|--------------|
| CONF-01 | GET does not mutate; explicit link submit confirms from anonymous and existing-session state; existing session stays bound to its original user; target `confirmed_at` persists; token is single-use. | LiveView/integration + fresh-host DB probe | `mix test test/sigra/install/generated_confirmation_live_test.exs` (new focused test) and generated host `MIX_ENV=test mix test test/generated_confirmation_probe_test.exs` | ❌ New behavior coverage required. Existing `test/sigra/install/features/core_test.exs` is mostly generator/template coverage. |
| CONF-02 | Paste the exact spaced email code in a real Chromium input and accept it; normalizer rejects non-ASCII digits/unapproved whitespace; account A's code cannot confirm B; rate limiting remains per account. | Unit/integration + real browser | `mix test test/sigra/auth_test.exs test/sigra/install/generated_confirmation_live_test.exs`; fresh-host browser `npx playwright test tests/generated-confirmation.spec.ts --project=generated-host-chromium` | ❌ No fresh-host confirmation browser scenario. Existing input tests encode six-character behavior and need updating. |
| CONF-03 | Success and invalid-code text is visible, localized, and exposed with status/alert semantics without focus theft; invalid input remains retryable. | Template/component contract + LiveView + browser | `mix test test/sigra/install/auth_ui_contract_test.exs test/sigra/install/generator_email_test.exs`; browser scenario above | ❌ Existing template tests do not assert feedback DOM semantics. |

### Sampling Rate

- **Per task commit:** focused ExUnit files for the touched source seam.
- **Per wave merge:** all relevant generator/auth tests plus the generated-host integration/browser command.
- **Phase gate:** recurring required CI green with an explicit successful fresh-host browser result and persisted-state assertions; no human UAT.

### Wave 0 Gaps

- [ ] Add focused LiveView tests for optional scope, token GET no-op, explicit submit, no login/session switch, signed-in owner preservation, anonymous code/resend guidance, and no missing-scope crash.
- [ ] Add library-level cross-account verification regression; call the scoped generated query and prove `confirmed_at` remains nil for the wrong account.
- [ ] Update generator contract tests for the spaced text input, strict server normalization, and visible status/alert markup. Existing `generator_email_test.exs:212-241` currently expects `phx-change`, auto-submit at length six, and old states.
- [ ] Extend fresh-host integration probe to submit link and code flows and read persisted `confirmed_at` plus session/token state.
- [ ] Add one Playwright spec under the current test/example Playwright harness that targets the disposable generated host, pastes clipboard contents (not only an unspaced value), verifies visible success/error and allows retry. Configure a deterministic LiveView-ready signal / readiness assertion and collect test output on failure.
- [ ] Add browser dependency installation and app boot/teardown/readiness to install-smoke or a dedicated job that is included in the existing required `ci` aggregation; keep the CI lane bounded to this scenario.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Single-use, account-bound confirmation token; code verification tied to current signed-in account. |
| V3 Session Management | Yes | Link confirmation must not create, switch, or replace a session; assert existing session identity remains unchanged. |
| V4 Access Control | Yes | Scope code lookup and mutation to the current request account; ignore any submitted target account identifier. |
| V5 Input Validation | Yes | Strict server-side normalization/validation; accept the documented ASCII-space separators only and exactly six ASCII digits. |
| V6 Cryptography | Yes | Preserve existing hashed code and signed link token utilities; do not invent token/hash formats. |

### Known Threat Patterns for Phoenix LiveView + generated auth

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Confirmation GET triggered by scanner/prefetch | Tampering | Render a display-only confirmation page on GET; mutate only on explicit submit. This reduces scanner side effects but does not eliminate pre-hijacking. |
| Token A used in signed-in account B scope | Spoofing / Elevation | Link remains bound to token owner's account; don't switch session; code query must include scope user ID. |
| Crafted LiveView payload or Unicode digit | Tampering | Treat event payload as untrusted; authorize from socket scope and validate on server before lookup. `[CITED: https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html]` |
| Replaying confirmation credential | Tampering | Existing transaction deletes all link/code tokens for the account after successful confirmation; assert reuse fails. `[VERIFIED: lib/sigra/auth.ex:894-905,1010-1020]` |
| Silent or inaccessible feedback | Repudiation / Information disclosure | Show neutral localized status/alert content, avoid exposing backend details, and keep the message available without moving focus. `[CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html]` |

**Residual risk:** The anonymous link contract still permits an email owner to confirm a pre-stuffed account. Record it as a residual risk; do not claim explicit submit or session invariance prevents it.

## Sources

### Primary (HIGH confidence)

- Repository source read this session: `.planning/phases/246-generated-confirmation-recovery/246-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/METHODOLOGY.md`, `AGENTS.md`.
- `lib/sigra/install/features/core.ex` — generated confirmation route shape and route pipeline grouping.
- `priv/templates/sigra.install/core/confirmation_live.ex` — current link/code event behavior, input constraints and feedback assignments.
- `lib/sigra/auth.ex` — signed-link transaction and confirmation-code query/rate-limit behavior.
- `priv/templates/sigra.install/core/auth.ex`, `user_auth.ex`, and `user_token.ex` — generated context methods, optional scope mount behavior, and existing account-scoped query.
- `emails.ex`, `sigra_auth_components.ex`, and `sigra_auth.css` — generated displayed code, shared page composition, and neutral status classes.
- `scripts/ci/install-smoke.sh`, `.github/workflows/ci.yml`, generator tests, and `test/example/priv/playwright` — fresh-host/CI/test seams.

### Secondary (MEDIUM confidence)

- [Phoenix LiveView lifecycle and event security](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.html) — `handle_params`, `handle_event`, untrusted event payload guidance.
- [Phoenix LiveView bindings](https://phoenix-live-view.hexdocs.pm/bindings.html) — explicit `phx-submit` browser event binding.
- [Phoenix.LiveViewTest](https://phoenix-live-view.hexdocs.pm/1.2.11/Phoenix.LiveViewTest.html) — LiveView mount, submit and change test helpers.
- [HTML Living Standard: input](https://html.spec.whatwg.org/multipage/input.html) — text inputs, `maxlength` and `pattern` validation.
- [Elixir Regex](https://hexdocs.pm/elixir/Regex.html) — explicit character classes and whitespace class behavior.
- [Playwright locators](https://playwright.dev/docs/locators), [assertions](https://playwright.dev/docs/test-assertions), [best practices](https://playwright.dev/docs/best-practices), and [BrowserContext permissions](https://playwright.dev/docs/api/class-browsercontext) — role selectors, auto-waiting, retrying assertions and clipboard permissions.
- [W3C WCAG 2.2 status messages](https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html) — announce status updates without moving focus.
- [RFC 9110 §9.2.1](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.2.1) — safe method semantics.

### Tertiary (LOW confidence)

- None used to support implementation claims.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing project dependencies/lockfiles and browser package were read directly.
- Architecture: HIGH — route, template, verifier and generator-source seams were opened directly; implementation recommendation follows the locked D-01..D-09.
- Pitfalls: HIGH — each identified defect is visible in current source; external behavior is supported by official docs.

**Research date:** 2026-10-06
**Valid until:** 2026-11-05 (project seams are stable; refresh framework/browser references if versions change).
