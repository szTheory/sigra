---
created: 2026-09-15T00:00:00.000Z
status: pending
title: Generated confirmation route cannot confirm in EITHER session state
area: auth
severity: blocker
disposition: fast-follow
disposition_note: "Deliberately NOT pulled into v1.48 (CLEAN-BASELINE) — decided 2026-09-15. Must be scheduled as a fast-follow in the FIRST phase batch of the next milestone, not left to generic seed triggers."
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
