---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Generated auth has browser coverage on exactly one surface — login, no-passkeys
area: auth-ui
severity: medium
audit_finding: W-3
audit_source: .planning/v1.46-MILESTONE-AUDIT.md
requirements: [AUTHUI-02, AUTHUI-03, AUTHUI-04, PROOF-01]
files:
  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - test/sigra/install/auth_ui_contract_test.exs
  - scripts/ci/admin-acceptance-smoke.sh
source: 2026-07-28 v1.46 milestone audit (cross-phase integration check)
---

## What

This is the milestone's single largest proof gap, and the one the other findings keep
pointing back to.

`admin-generated.spec.ts:79` is the **only** browser test that renders a `sigra-auth-*`
surface, and it visits `/users/log_in` only — in the `--no-passkeys` configuration.

Everything else Phases 226 and 227 shipped is proven by source-string assertions in
`test/sigra/install/auth_ui_contract_test.exs` (135 lines) plus a
`--warnings-as-errors` compile:

- **AUTHUI-02:** registration, confirmation, reset, reactivation, sudo, invitation
  acceptance — 6 of 7 surfaces never rendered.
- **AUTHUI-03:** account settings, MFA, backup codes, passkeys, sessions, destructive
  account actions — none rendered.

Roughly 1,100 lines of template change verified almost entirely by string matching.

The example app does not compensate: it re-brands those same flows in the `vt-*` lane, so
exercising the example proves nothing about the generated `sigra-auth-*` output.

**PROOF-01's "register/confirm" clause is satisfied programmatically, not through the UI.**
The acceptance smoke seeds and confirms via `User.confirm_changeset()`
(`scripts/ci/admin-acceptance-smoke.sh:180+`), so the
registration-template → generated-host-runtime link is unproven end to end.

## Why this matters concretely

Finding W-1 is the receipt. The duplicate-`Email`-label defect the project owner caught by
eye during PROOF-03 review still exists one config flag away, and PR #113 shipped a fix
that missed it — because no lane renders the passkey-primary composition and no assertion
covers the label. String assertions cannot catch a collision between two strings that are
each individually correct.

## Recommended fix

Extend the generated-host Playwright lane to render each auth surface at least once. The
substrate already exists — `scripts/ci/admin-acceptance-smoke.sh` scaffolds
`phx.new` + `mix sigra.install`, boots it, and runs Playwright against it, so this is
adding specs rather than building infrastructure.

Sequencing suggestion:

1. The surfaces reachable without extra state: registration, login (both passkey configs),
   reset request, reactivation.
2. The token-gated ones: confirmation, reset completion, invitation acceptance — these need
   the smoke to surface tokens, which is the bulk of the work.
3. Authenticated: settings, MFA, backup codes, passkeys, sessions, destructive actions.

Pair this with W-4 (no axe run touches any `sigra-auth-*` surface) — the two together are
the coherent core of a follow-on auth-UI proof milestone, and doing them in one pass is
much cheaper than twice.

While here, consider adding a page-level "no duplicate DOM ids" assertion; it would have
caught W-1(b) directly.

## Related

- W-1, W-4 in the same audit.
- [[reference_generated_host_acceptance_smoke]] — the existing harness to extend.
