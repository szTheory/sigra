---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Generated confirmation route cannot confirm in EITHER session state
area: auth
severity: blocker
disposition: fast-follow
disposition_note: "Deliberately NOT pulled into v1.48 (CLEAN-BASELINE) — decided 2026-09-15. Must be scheduled as a fast-follow in the FIRST phase batch of the next milestone, not left to generic seed triggers."
resolves_phase: 246
source: downstream adopter field report, 2026-09-15 (relayed); verified locally at 160de093
files:
  - lib/sigra/install/features/core.ex:370-376
  - lib/sigra/install/features/core.ex:500-511
  - priv/templates/sigra.install/core/confirmation_live.ex:100
  - priv/templates/sigra.install/core/confirmation_live.ex:148
  - priv/templates/sigra.install/core/confirmation_live.ex:163
related:
  - .planning/todos/pending/2026-07-28-w3-generated-auth-runtime-coverage-is-login-only.md
  - .planning/seeds/SEED-011-generated-auth-email-and-confirmation-defects.md
audit_acknowledged:
  milestone: v1.50
  at: 2026-11-10
---

## Problem

Every host that runs `mix sigra.install --live` gets a confirmation flow that cannot
confirm an account in either session state. The confirmation link in every generated
confirmation email is affected. **Verified directly against HEAD `160de093`** — this is
not a report taken on trust.

### The two halves

`lib/sigra/install/features/core.ex:370-376` builds `confirmation_routes` as bare
LiveView routes:

```elixir
live "/confirm", ConfirmationLive
live "/confirm/:token", ConfirmationLive, :confirm
```

with **no `live_session` and no `on_mount`**. Those get injected at `:508` into the scope
opened at `:500-501`:

```elixir
scope "/users", #{web_module} do
  pipe_through [:browser, :redirect_if_user_is_authenticated]
```

Meanwhile `priv/templates/sigra.install/core/confirmation_live.ex` reads
`socket.assigns.current_scope.user` three times — at `:100`, `:148`, `:163`.

### Both paths fail, and the common one fails silently

**Anonymous visitor** — `fetch_current_scope` assigns to the *conn*; `on_mount` never
ran, so `socket.assigns.current_scope` is absent. `KeyError` → 500 on the link in every
confirmation email.

**Signed-in visitor** — `redirect_if_user_is_authenticated` redirects before mount. A 302
and a plausible-looking page, `confirmed_at` still `nil`, and no error anywhere.

The signed-in case is the **common** one, because the generated `RegistrationLive`
establishes a session immediately — and it is the dangerous one, because nothing in the
response distinguishes it from success. It also compounds with the missing flash region
(see SEED-011 / SG-REQ-D): a silent no-op and a crash look identical from outside.

### Why "just drop the reads" is the wrong fix

`:100` is a dead binding (`_user`, never read) that can only ever raise — that one can go.
But `:148` (resend) and `:163` (do_confirm) are **real** reads: `confirm_user_by_code/2`
scopes by `user_id`, and that scoping is a genuine security property. An unscoped 6-digit
code is brute-forceable across the whole user table. Removing the reads would trade a
broken flow for an enumerable one.

## Solution

Move the confirm routes into a `live_session` on `:mount_current_scope`, which assigns
`nil` rather than redirecting:

- the **token** path must work with no session at all
- the **code** path must *know* there is no session, so it can say so rather than raise

Then audit **every** generated LiveView that reads `current_scope` against the scope it is
actually injected into — this class is not necessarily limited to the confirm routes. The
generated router already carries a comment recording this same lesson on a different set of
generated routes; the confirmation routes were missed because nobody could reach them to
notice.

### Required test (not optional)

Assert the confirm route confirms **from both session states**, and assert on
`confirmed_at` — **not** on the response status. A status-only assertion passes while
confirming nothing, which is precisely the failure mode above. This test belongs with the
W-3 generated-auth coverage gap.

## Status update (Phase 259 gap closure) — 2026-11-15

Fresh read of the generated sources at HEAD `958a03834`, not of this file's own text. Labels: **read in source, not executed** means the claim comes from reading the file at the cited line and nothing was run against a generated host. The Problem, Solution and Required test sections above are written for the state at `160de093` and are historical for the LiveView flavor.

### The LiveView flavor was repaired in Phase 246

Commits `6be7eff6b` (Phase 246: scoped generated confirmation source, #287) and `590eb4ed3` (harden generated confirmation retries, #288). What the current sources show (read in source, not executed):

- `lib/sigra/install/features/core.ex:387-402` (`optional_scope_confirmation_routes`) emits a `scope "/users"` with `pipe_through [:browser]` and `live_session :sigra_confirmation, on_mount: [{Web.UserAuth, :mount_current_scope}]` (`:394-395`) around the confirm routes. For a live install `redirect_scope_confirmation_routes` is empty (`:404`), so the confirm routes are no longer injected into the `redirect_if_user_is_authenticated` scope (`:522`). The bare `live` route text quoted under "The two halves" is still the definition at `:370-376`, but it is now interpolated into that `live_session` (`:396`) instead of the redirect scope.
- The committed golden router shows it: `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex:98-102`. `test/sigra/install/generator_wiring_test.exs:185` asserts `live_session :sigra_confirmation` is emitted.
- The template no longer does the three `socket.assigns.current_scope.user` reads listed in `files`. `priv/templates/sigra.install/core/confirmation_live.ex:270-277` (`with_confirmation_user/2`) reads `socket.assigns[:current_scope]` without raising and, for an anonymous visitor, sets `live_action: :sign_in_required`, rendered in place at `:103-110`. The resend and code-entry handlers go through it (`:181`, `:216`).
- The "Required test" above now exists for the LiveView flavor: `scripts/ci/generated-confirmation-probe.exs` asserts on `confirmed_at` for an anonymous link confirmation (`:11-60`), for a signed-in visitor confirming another owner's link while staying signed in (`:64-107`), and for anonymous code and resend events that show sign-in guidance and change no account (`:110`). It is rendered and run by `scripts/ci/install-smoke.sh:240-247`. Not executed in this plan.

### What remains: the non-live controller flavor (`--no-live`), read in source, not executed

- `core.ex:404` sets `redirect_scope_confirmation_routes = confirmation_routes` for a non-live install, so the four controller routes (`core.ex:380-383`: `get /confirm`, `post /confirm`, `get /confirm/:token`, `post /confirm/resend`) are still emitted inside `scope "/users"` with `pipe_through [:browser, :redirect_if_user_is_authenticated]` (`core.ex:522`, `:529`).
- Signed-in visitor: `redirect_if_user_is_authenticated` (`priv/templates/sigra.install/core/user_auth.ex:385-392`) redirects and halts before any confirmation action runs, so a signed-in visitor's token link, code entry and resend never reach the controller and `confirmed_at` stays `nil` with no error. This is the same silent no-op described under "Both paths fail".
- Anonymous visitor: `create/2` (`priv/templates/sigra.install/core/confirmation_controller.ex:25-26`) and `resend/2` (`:94-95`) read `conn.assigns.current_scope.user`, and `fetch_current_scope` assigns `nil` for an anonymous visitor (`user_auth.ex:164-170`, `:191`), so these two actions appear to raise. The token link action `confirm/2` (`:52`, `:74`) reads no `current_scope` and so appears to work for an anonymous visitor only. The code path needs a session user (`confirm_user_by_code/2` scopes by `user_id`, as the Problem section explains), so for this flavor it appears unreachable in both session states.
- No generated-host probe covers this flavor: the install-smoke probe and the Playwright spec drive the LiveView pages (`live(conn, "/users/confirm")`).

A fix for the residual is the same shape as the Solution above, applied to the controller flavor, plus a generated-host check for it. It is not done here: Phase 259 ships zero bytes under `lib/` and `priv/`. This file stays pending, and the fast-follow disposition is unchanged.

### The example host was repaired separately, and its row is example-host evidence only

Plan 259-15 repaired `test/example` only: `live "/confirm"` now sits in `live_session :confirmation` on `:mount_current_scope` outside `redirect_if_user_is_authenticated`, `ConfirmationLive` reads the session user through a nil-safe lookup, an anonymous resend or code entry flashes and redirects to log in, and regression tests assert on `confirmed_at`. That anonymous behaviour (flash and redirect) differs from the generated page's in-place `:sign_in_required` render. The registry row `confirmation-resend` in `test/fixtures/brand/public-surfaces.json` is therefore example-host evidence only: it claims nothing about a generated host, neither the LiveView flavor (covered by the Phase 246 probe above) nor the non-live controller flavor (covered by nothing). The row keeps this path in its `todo` field because the residual above is still open.
