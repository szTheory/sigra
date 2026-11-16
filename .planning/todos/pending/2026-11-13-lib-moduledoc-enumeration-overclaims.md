---
created: 2026-11-13T00:00:00.000Z
status: pending
title: Library moduledocs and docs state account-discovery protection more broadly than the parity harness proves
area: security
severity: minor
source: Phase 259 enumeration parity harness
files:
  - lib/sigra/lockout.ex
  - lib/sigra/error.ex
  - lib/sigra/auth.ex
  - test/fixtures/brand/public-surfaces.json
---

Registry row: `lib-moduledoc-claims` in `test/fixtures/brand/public-surfaces.json` (state `not_proven`, kind `library`, no compared dimensions: this is prose, not a request surface, so no probe exists).

## Deferred: needs lib bytes

Every location below is documentation inside `lib/`. Phase 259 ships zero bytes under `lib/`, so none of these was edited; they are filed here and bounded by the claims register. The edit belongs to a later phase that is allowed to change `lib/` (docs-only, so no behaviour or typespec change).

## Over-claim locations

| Location | What it says today (quoted) | What the harness proves instead |
|----------|-----------------------------|---------------------------------|
| `lib/sigra/lockout.ex:13` | "Messages are enumeration-safe (generic text via `Sigra.Error.safe_message/1`)." | After the lockout threshold an existing account returns a different error than an unknown email (`password-signin-repeat-attempts`, `lib/sigra/auth.ex:515-533`, `lib/sigra/lockout.ex:57`); the lockout message differs from the invalid-credentials one (`lib/sigra/error.ex:155`, `:160-161`) |
| `lib/sigra/lockout.ex:42-43` | "Returns `:ok` for `nil` users ... to support enumeration-safe flows where a dummy hash is performed regardless." | `check(nil)` is the reason an unknown address is never locked; the dummy-hash claim is about timing, which is not compared |
| `lib/sigra/error.ex:7` | "enumeration-safe user-facing strings" | The strings are generic per error; which error a caller receives still depends on account state (lockout row above) |
| `lib/sigra/error.ex:138-141` | "enumeration-safe user-facing message ... intentionally generic to prevent user enumeration attacks" | Same as above; the passkey options endpoint (`passkey-signin-options`) is outside `safe_message/1` and differs on JSON keys |
| `lib/sigra/auth.ex:16` | "User enumeration prevention: generic error messages, constant-time operations" | Timing is not compared by the harness; the duplicate-registration timing oracle is tracked separately (`2026-11-13-duplicate-registration-timing-oracle.md`) |
| `lib/sigra/auth.ex:132` | "(enumeration-safe -- callers should show a generic message)" for `{:error, :email_taken}` | A duplicate registration differs from a new one on body and flash (`registration` row, known divergence) |
| `lib/sigra/auth.ex:613` | "to prevent email enumeration" for `request_magic_link/3` | Holds at the single-request level for the generated controller (`magic-link-request` parity, bounded to status, redirect, flash and body); the throttle is applied to existing accounts only (`magic-link-rate-limit`, `lib/sigra/auth.ex:643-645`) |
| `lib/sigra/auth.ex:1097` | "Enumeration-safe: always returns `{:ok, :sent}` for non-existent emails with a dummy hash operation to match timing" | The return value claim is source-level; timing is not compared; the throttle is existing-only (`password-reset-rate-limit`, `lib/sigra/auth.ex:1131-1133`) |

## Why it matters

Adopters read these moduledocs on HexDocs and in editor tooltips and may rely on the wording. The claims register (Plan 259-11) and the parity registry bound what the project asserts today; the lib prose is wider than that bound.

## Proposed fix direction

Rewrite each sentence to the bounded form the parity registry supports: say what the function returns for an unknown email, name the dimensions that were compared ("generic message text", "one request, fresh state"), and point at the divergences that remain (lockout after the threshold, registration, passkey options) instead of the unqualified label. Keep the typespec and return values untouched, so this is a docs-only change.

## Shrink discipline

Rewriting the prose does not change a registry state by itself. When the lib docs are corrected, update the `blocker` of `lib-moduledoc-claims` (it cites `lib/sigra/lockout.ex:13`, which the harness resolves to a real line) or remove the row if no over-claim remains, then close this todo. Until then the row stays `not_proven` and no prose in this repository may extend the claim past the dimensions the parity rows list.
