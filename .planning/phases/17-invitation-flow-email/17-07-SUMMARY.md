---
phase: 17-invitation-flow-email
plan: 07
subsystem: organizations, invitations, liveview, accept-flow
tags: [sigra, liveview, invitation-accept, jetstream-907, cve-2026-1529, phase-17, inv-05, inv-06, inv-07, d-06]
requires: ["17-05", "17-06"]
provides:
  - "InvitationAcceptLive — single unscoped LiveView handling invitation acceptance across 7 render branches (D-06)"
  - "Structural Jetstream #907 / CVE-2026-1529 defense — mismatch branch contains ZERO accept DOM controls by construction"
  - "Fallback raise clauses on handle_event for accept_invitation/accept_with_signup — any non-matching branch raises ArgumentError"
  - "Sigra.Organizations.Invitations.load_for_view/3 — HMAC verify + DB lookup + branch classify for LV mount"
  - "Unscoped /invitations/:token/accept route in router_injection.ex template + example-app router"
  - "Example.Organizations wired with user_registration_changeset_fn for the accept_with_signup anonymous path"
  - "lazy_html enabled in example-app mix.exs — unblocks Phoenix.LiveViewTest.live/3 for all future Phase 17+ LV tests"
affects:
  - lib/sigra/organizations/invitations.ex
  - lib/sigra/install/features/organizations.ex
  - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
  - priv/templates/sigra.install/organizations/router_injection.ex
  - test/example/lib/example/organizations.ex
  - test/example/lib/example_web/router.ex
  - test/example/lib/example_web/live/invitation_accept_live.ex
  - test/example/mix.exs
  - test/example/test/example_web/live/invitation_accept_live_test.exs
tech-stack:
  added:
    - "lazy_html ~> 0.1 (only: :test) — required by Phoenix.LiveViewTest.live/3, ships precompiled NIFs via cc_precompiler"
  patterns:
    - "Branch-dispatched render — `case @branch do ... end` routes to one of 7 function components"
    - "Structural invariant by construction — :mismatch branch has no accept DOM; fallback handle_event clauses raise explicitly"
    - "HMAC verify + DB lookup first, assign branch second — keeps mount/3 thin; all classification in Sigra.Organizations.Invitations.load_for_view/3"
    - "Lockstep template + example-app edits (matches Plan 17-04 / 17-06 convention)"
    - "Test-time EXIT trap helper (assert_accept_rejected/1) for asserting raises inside a linked LiveView channel process"
key-files:
  created:
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - test/example/lib/example_web/live/invitation_accept_live.ex
    - test/example/test/example_web/live/invitation_accept_live_test.exs
    - .planning/phases/17-invitation-flow-email/17-07-SUMMARY.md
  modified:
    - lib/sigra/organizations/invitations.ex
    - lib/sigra/install/features/organizations.ex
    - priv/templates/sigra.install/organizations/router_injection.ex
    - test/example/lib/example/organizations.ex
    - test/example/lib/example_web/router.ex
    - test/example/mix.exs
    - test/example/mix.lock
decisions:
  - "Added fallback handle_event clauses that explicitly raise ArgumentError on non-matching branches. The plan described `assert_raise ArgumentError` in the regression test, which is only expressible if the raise is explicit — FunctionClauseError would reach the test as a linked EXIT, not a synchronous raise. The explicit ArgumentError fallback makes the defense both testable AND clearly intentional. (Rule 2 — critical security defense.)"
  - "accept_with_signup handler back-fills user_params[\"email\"] from invitation.email when the submitted form omits it. The signup form locks email via disabled+readonly, which browsers AND Phoenix.LiveViewTest.form/3 honor by not submitting the field. Back-filling on nil/empty preserves the happy-path submission while leaving attacker-supplied non-matching emails to hit the library's :email_mismatch guard."
  - "Test-time assertions use a custom `assert_accept_rejected/1` helper that traps the Phoenix.LiveViewTest channel EXIT signal. Phoenix.LiveViewTest runs the LV in a separate linked process, so a raise in handle_event reaches the test as `{:EXIT, pid, {exception, stack}}` rather than a synchronous raise. The helper unwraps the exit, asserts the message mentions `Jetstream #907`, and drains the linked EXIT message so it does not bleed into the next test."
  - "Enabled lazy_html in test/example/mix.exs. Prior note (\"omitted: requires cmake for source build\") turned out to be stale — lazy_html 0.1.11 ships precompiled NIFs via fine + cc_precompiler, so no cmake toolchain is required. This unblocks Phoenix.LiveViewTest.live/3 for all Phase 17+ LV tests in the example app."
  - "load_for_view/3 does its own HMAC verify + DB lookup path rather than delegating to the existing `verify_and_load/2` private helper. The existing helper enforces a pending-state guard (rejects expired/revoked/already_accepted), but the LV needs those branches to RENDER distinct copy — so load_for_view classifies them instead of rejecting. The org + inviter fetches are deferred to the :signup/:accept branches (mismatch branch does not display them)."
  - "Redirect target on successful accept is `/organizations/#{slug}/members` (not `/organizations/#{slug}`) because the example-app router scope `/organizations/:org` does not have a bare index route — only `/settings` and `/members`. The members page is the natural landing for a newly-joined user. When host apps add a bare org index route the generated template can be re-pointed."
  - "Route is placed in a `live_session :invitations_public` block with `on_mount: :mount_current_scope` (not :ensure_authenticated). This is the whole point of D-06: both anonymous (signup) and signed-in (accept/mismatch) visitors must reach the same LV. The router_injection.ex template puts it inside a scope piped through `:browser` only — outside `:require_authenticated`."
requirements: [INV-05, INV-06, INV-07]
metrics:
  duration: "~60 minutes"
  completed: "2026-04-14"
  tasks: 2
  commits: 2
  tests_added: 20
---

# Phase 17 Plan 07: InvitationAcceptLive Summary

**One-liner:** Shipped the final load-bearing plan of Phase 17 — `InvitationAcceptLive`, a single unscoped LiveView at `/invitations/:token/accept` with 7 render branches (signup, accept, mismatch, invalid, expired, revoked, already_accepted) that enforces the Jetstream #907 / CVE-2026-1529 structural defense: the `:mismatch` branch contains ZERO accept DOM controls by construction, and fallback `handle_event` clauses explicitly raise `ArgumentError` on any non-matching branch, so a synthesized accept event cannot mutate state regardless of how the URL was obtained.

## Module path + route path

| Artifact | Path |
|---|---|
| LV module (template) | `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` → `<%= web_module %>.InvitationAcceptLive` |
| LV module (example app) | `test/example/lib/example_web/live/invitation_accept_live.ex` → `ExampleWeb.InvitationAcceptLive` |
| Route | `live "/invitations/:token/accept", InvitationAcceptLive` |
| Live session | `live_session :invitations_public, on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}]` |
| Scope pipeline | `pipe_through [:browser]` — **outside** any `:require_authenticated` pipeline (verified by T20 regex grep) |

## Branch atoms → function components

| `@branch` atom | Function component | Accept DOM? |
|---|---|---|
| `:signup` | `render_signup/1` | yes — `<.form phx-submit="accept_with_signup" id="invitation-signup-form">` |
| `:accept` | `render_accept/1` | yes — `<.button id="accept-invitation-button" phx-click="accept_invitation">` |
| `:mismatch` | `render_mismatch/1` | **NO** — zero phx-click / phx-submit / form-action targeting accept. Structural invariant enforced by grep + T19. |
| `:invalid` | `render_invalid/1` | no |
| `:expired` | `render_expired/1` | no |
| `:revoked` | `render_revoked/1` | no |
| `:already_accepted` | `render_already_accepted/1` | no |

## Structural Jetstream #907 check — awk grep returns 0

```
$ awk '/defp render_mismatch/,/^  end$/' \
    priv/templates/sigra.install/organizations/live/invitation_accept_live.ex \
  | grep -cE 'phx-click="accept|phx-submit="accept'
0
```

Verified at plan close — the `:mismatch` render branch contains zero accept DOM controls.

## Test file + counts

- **File:** `test/example/test/example_web/live/invitation_accept_live_test.exs` (625+ lines)
- **Total tests:** 20 (all passing)
- **Describe blocks:** 7
  - `"mount/3 branch selection"` — 8 tests (T1-T8)
  - `"handle_event(\"accept_invitation\", ...)"` — 5 tests (T9-T13)
  - `"handle_event(\"accept_with_signup\", ...)"` — 2 tests (T14-T15)
  - `"Jetstream #907 regression"` — 1 test (T16) ← **THE load-bearing security test**
  - `"Replay regression"` — 1 test (T17)
  - `"Citext regression"` — 1 test (T18)
  - `"structural invariant (Jetstream #907 static check)"` — 2 tests (T19-T20)

## Jetstream #907 regression — specific assertion line

**File + line (for verifier reference):**

- `test/example/test/example_web/live/invitation_accept_live_test.exs:483` — `assert_accept_rejected(fn -> render_click(view, "accept_invitation") end)` inside the `describe "Jetstream #907 regression"` block at line 451.

The test asserts four invariants in order:

1. **Mismatch branch rendered with locked copy** — "This invitation is not for you", target email, attacker email all visible.
2. **ZERO accept DOM** via `refute html =~ "phx-click=\"accept_invitation\""`, `refute html =~ "phx-submit=\"accept_with_signup\""`, `refute html =~ "Accept &amp; join"`, `refute html =~ "Create account"`.
3. **Synthesized accept event raises** via `assert_accept_rejected(fn -> render_click(view, "accept_invitation") end)` — the fallback `handle_event` clause raises `ArgumentError` whose message mentions "Jetstream #907".
4. **Zero DB mutation** — `Repo.aggregate(OrganizationMembership, :count, :id)` unchanged, `invitation.accepted_at == nil`, `invitation.accepted_by_id == nil`.

## Acceptance criteria — all met

| Check | Result |
|---|---|
| `grep -n "def mount" invitation_accept_live.ex` (template) | 1 match |
| `grep -n 'def handle_event("accept_invitation"' invitation_accept_live.ex` | 2 matches (main + fallback raise) |
| `grep -n 'def handle_event("accept_with_signup"' invitation_accept_live.ex` | 2 matches (main + fallback raise) |
| `grep -n "defp render_mismatch" invitation_accept_live.ex` | 1 match |
| `grep -n "load_for_view" lib/sigra/organizations/invitations.ex` | 4 matches (spec + def + docstring + private classify helpers) |
| Structural awk grep on `render_mismatch` body | 0 matches for `phx-click="accept` / `phx-submit="accept` |
| `grep -n "live \"/invitations/:token/accept\"" router_injection.ex` | 1 match |
| `grep -n "live \"/invitations/:token/accept\"" test/example/lib/example_web/router.ex` | 1 match |
| `live_session :invitations_public` block does NOT contain `require_authenticated` | verified via T20 router-regex test |
| `mix compile --warnings-as-errors` | exits 0 (library) |
| `cd test/example && mix compile` | exits 0 |
| `cd test/example && mix test test/example_web/live/invitation_accept_live_test.exs` | 20 tests, 0 failures |
| `cd test/example && mix test --exclude example_app` | 66 tests, 0 failures (includes Phase 16 + 17-04 email + 17-06 LV + 17-07 LV) |
| `mix test` (library suite) | 1703 tests, 5 failures (all pre-existing from Plan 17-04 fragment debt — see `deferred-items.md`) |

## Deviations from Plan

### Plan divergences (Rule 2 — critical security defense)

**1. Added fallback `handle_event` clauses that raise `ArgumentError` explicitly**

- **Found during:** Task 2 test runtime
- **Issue:** The plan's regression test asserts `assert_raise ArgumentError, fn -> render_click(view, "accept_invitation") end`. With only the narrow branch-matching clause, Elixir raises `FunctionClauseError` (not `ArgumentError`) when the event reaches the LV on a non-matching branch. Because Phoenix.LiveViewTest runs the LV in a separate linked channel process, the raise reaches the test as a linked `EXIT` signal, not a synchronous raise — `assert_raise` does NOT catch it, and the test caller crashes.
- **Fix:** Added two fallback `handle_event` clauses at the end of the handler block that explicitly raise `ArgumentError` with a message mentioning "Jetstream #907 structural defense". This makes the defense both testable AND clearly intentional (the error message self-documents the purpose). The mismatch branch still renders zero accept DOM, so the fallback clause is unreachable from legitimate clients — it exists purely as a server-side crash barrier for synthesized/tampered requests.
- **Files modified:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex`, `test/example/lib/example_web/live/invitation_accept_live.ex`
- **Rule:** Rule 2 (critical security defense — correctness requirement for the Jetstream #907 regression test)

**2. Added `assert_accept_rejected/1` test helper that traps EXIT signals**

- **Found during:** Task 2 test runtime
- **Issue:** Even after adding the explicit `raise ArgumentError`, Phoenix.LiveViewTest still delivers the raise as a linked `{:EXIT, pid, {exception, stack}}` message (the LV channel is a GenServer that crashes on raise; the test process is linked). `assert_raise` does not catch this.
- **Fix:** Added a private `assert_accept_rejected/1` helper that calls `Process.flag(:trap_exit, true)`, runs the fun inside a `try/catch :exit` block, asserts the exit reason is `{{%ArgumentError{message: msg}, _stack}, _gs}` with `msg =~ "Jetstream #907"`, then drains the linked `{:EXIT, _, _}` mailbox message with a 50ms timeout so it doesn't bleed into the next test.
- **Files modified:** `test/example/test/example_web/live/invitation_accept_live_test.exs` only (test infrastructure, no production code)

**3. `accept_with_signup` handler back-fills `user_params["email"]` from the locked invitation email**

- **Found during:** Task 2 T14 (happy-path signup) test runtime
- **Issue:** The signup form locks the email via `disabled + readonly`. Browsers honor `disabled` by NOT submitting the field (per HTML spec). Phoenix.LiveViewTest.form/3 mirrors this. So `handle_event("accept_with_signup", %{"user" => user_params}, ...)` receives `user_params` with **no email key at all** on the happy path. The library's `assert_signup_email_matches/2` guard then compares `"" == invitation.email` → `{:error, :email_mismatch}` → test fails despite being the happy path.
- **Fix:** The handler back-fills `user_params["email"]` from `socket.assigns.invitation.email` when the submitted value is `nil` or `""`. Attacker bypasses that DOM-craft a different email still populate the key with a non-empty value, which preserves the `:email_mismatch` rejection on the server. The library's additional force-overwrite inside `run_accept_with_signup_multi/4` still applies for defense in depth.
- **Files modified:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex`, `test/example/lib/example_web/live/invitation_accept_live.ex`
- **Rule:** Rule 2 (critical functionality — without this fix the happy path does not work at all)

**4. Enabled `lazy_html` as a test dependency**

- **Found during:** First test run
- **Issue:** `test/example/mix.exs` had `lazy_html` commented out with the note "omitted: requires cmake for source build". `Phoenix.LiveViewTest.live/3` raises a clear RuntimeError demanding lazy_html as a test dep. Plan 17-06's test pattern comment says "the example-app test suite does not import Phoenix.LiveViewTest anywhere" — that was why lazy_html was omitted. But Plan 17-07 explicitly requires `Phoenix.LiveViewTest` to express the Jetstream #907 regression test (DOM refute + render_click synthesized event + render_submit bypass).
- **Fix:** Probed lazy_html in a scratch project and confirmed it ships precompiled NIFs via `cc_precompiler` + `fine` — no cmake required. Enabled it in `test/example/mix.exs` as `{:lazy_html, ">= 0.1.0", only: :test}`. This unblocks Phoenix.LiveViewTest.live/3 for all Phase 17+ LV tests in the example app.
- **Files modified:** `test/example/mix.exs` + `test/example/mix.lock`

**5. Redirect target on accept success is `/organizations/#{slug}/members`, not `/organizations/#{slug}`**

- **Found during:** Task 1 first compile
- **Issue:** The plan's draft redirects to `~p"/organizations/#{org.slug}"`. The example-app router scope `/organizations/:org` does NOT have a bare index route — only `/settings` and `/members`. `~p` verified routes flagged the warning.
- **Fix:** Redirect to `~p"/organizations/#{org.slug}/members"` in both template and example-app copies. The members page is the natural landing for a newly-joined user. When host apps add a bare org index route, the generated template can be re-pointed manually (this is generator code — host-owned per D-28).

**6. Test 18 (citext regression) uses raw Repo.insert instead of User.registration_changeset**

- **Found during:** Task 2 T18 runtime
- **Issue:** `User.registration_changeset/2` runs `Sigra.Email.normalize/1` on the email, which downcases `User@Ex.com` → `user@ex.com`. This means registering a mixed-case user via the changeset path always produces a lowercase row, defeating the test's intent of proving a mixed-case LIVE user row matches a lower-case invitation.
- **Fix:** The test inserts the user directly via `Repo.insert!(%Example.Accounts.User{email: "User-T18-N@Ex.com", ...})` with manually-hashed password. This preserves the mixed-case email on the row so the `:accept` branch's downcase-compare has something meaningful to exercise.

## Auth Gates

None — fully autonomous execution.

## Commits

| Commit    | Type | Summary |
|-----------|------|---------|
| `f33205f` | feat | InvitationAcceptLive 7-branch LV + load_for_view helper + router + install-features + example wiring |
| `68c77a1` | test | 20 tests covering all branches + Jetstream #907 structural regression + replay + citext |

## Verification Results

```
mix compile --warnings-as-errors (library)                 → clean
cd test/example && mix compile                             → clean
cd test/example && mix test test/example_web/live/invitation_accept_live_test.exs
  → 20 tests, 0 failures
cd test/example && mix test --exclude example_app
  → 66 tests, 0 failures (Phase 16 + 17-04 + 17-06 + 17-07 all green)
mix test (library)
  → 1703 tests, 5 failures (all pre-existing from Plan 17-04
    fragment debt — see deferred-items.md; out of scope per
    SCOPE BOUNDARY)
```

**Structural awk grep (zero-DOM invariant):**

```
$ awk '/defp render_mismatch/,/^  end$/' \
    priv/templates/sigra.install/organizations/live/invitation_accept_live.ex \
  | grep -cE 'phx-click="accept|phx-submit="accept'
0
```

Returns `0` ✓.

## Known Stubs

None. All 7 branches render their intended copy and the two accept handlers delegate to real library functions that have been exercised by Plan 17-05's library tests and Plan 17-07's 20 LV tests.

## Threat Flags

None — all new trust-boundary surface is covered by the plan's `<threat_model>` block (T-17-02, T-17-07, T-17-08, T-17-10, T-17-11). Mitigations honored:

- **T-17-07 (Jetstream #907 structural):** Mismatch branch contains zero accept DOM (T19 static check + T16 runtime assertion). Fallback `handle_event` clauses raise explicitly. Zero DB writes on synthesized accept event (T16).
- **T-17-02 (HMAC verify):** `Sigra.Organizations.Invitations.load_for_view/3` calls `Sigra.Token.verify_invite_envelope/3` first; tampered token → `:invalid` branch (T4).
- **T-17-08 (Replay):** `load_for_view` classifies `accepted_at IS NOT NULL` as `:already_accepted` branch; T17 replay test asserts second visit renders `:already_accepted` and does NOT re-stamp accepted_at.
- **T-17-11 (Citext bypass):** `load_for_view` uses `String.downcase/1` on both sides of the user↔invitation email compare; T18 citext regression test verifies `User@Ex.com` accepts `user@ex.com` successfully.
- **T-17-10 (Info disclosure):** `:invalid` branch copy is uniformly "This invitation link is not valid." — T4 asserts the rendered HTML does NOT contain "signature", "base64", or "tamper".
- **T-17-02 (signup server-side re-check):** `accept_with_signup` handler back-fills locked email on nil/empty and defers to the library `:email_mismatch` guard for attacker bypass; T15 verifies the guard fires on a direct `render_submit` that bypasses the disabled input.

## Self-Check: PASSED

**Created files:**

- FOUND: `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex`
- FOUND: `test/example/lib/example_web/live/invitation_accept_live.ex`
- FOUND: `test/example/test/example_web/live/invitation_accept_live_test.exs`

**Modified files verified via grep:**

- FOUND: `def load_for_view(config, signed_token, current_user)` in `lib/sigra/organizations/invitations.ex`
- FOUND: `def mount(%{"token" => signed_token}` in `invitation_accept_live.ex` (template + example copy)
- FOUND: `defp render_mismatch` in `invitation_accept_live.ex`
- FOUND: `raise ArgumentError` fallback clauses for `accept_invitation` + `accept_with_signup`
- FOUND: `live "/invitations/:token/accept"` in `router_injection.ex` + `test/example/lib/example_web/router.ex`
- FOUND: `live_session :invitations_public` block outside any `:require_authenticated` pipeline
- FOUND: `user_registration_changeset_fn:` wired in `test/example/lib/example/organizations.ex`
- FOUND: `{:lazy_html, ">= 0.1.0", only: :test}` in `test/example/mix.exs`
- FOUND: 20 tests in `invitation_accept_live_test.exs`, 0 failures, 7 describe blocks
- FOUND: `"Jetstream #907"` named describe block (line 451) + test (T16 at line ~457)

**Commits (both reachable from HEAD):**

- FOUND: `f33205f` (feat — InvitationAcceptLive + load_for_view helper + router/install/example wiring)
- FOUND: `68c77a1` (test — 20 LV tests + Jetstream #907 regression + replay + citext)
