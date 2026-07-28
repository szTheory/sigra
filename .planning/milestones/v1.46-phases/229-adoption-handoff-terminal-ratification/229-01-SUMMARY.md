---
phase: 229-adoption-handoff-terminal-ratification
plan: 01
subsystem: adoption-proof
tags: [golden, generated-host, playwright, docs, ratification]
requirements-completed: [PROOF-01, PROOF-02, PROOF-03]
completed: 2026-07-27
status: complete
---

# Phase 229 Plan 01 Summary

Proved the v1.46 adopter handoff end to end from a fresh generated host, then closed the
one clause the milestone deliberately reserved for a human: visual acceptance of the
generated login composition.

## Delivered

- The fresh-host smoke covers generation, warnings-as-errors compilation, migration, seed,
  grant/check/list, browser auth/admin/audit behavior, revoke, and deny-on-next-request
  with deterministic selectors and no sleeps.
- Golden generation is independently drift-checked and idempotent; default/no-passkey and
  admin/no-admin ownership paths are contract-tested.
- Installation, getting-started, v1.46 upgrade/rollback, changelog, and ExDoc discovery
  guidance are reconciled with the generated contract.
- Playwright outputs are separated by generated-host and revocation runs so later proof
  cannot delete earlier artifacts.

## Human Acceptance (PROOF-03)

Accepted 2026-07-27 after direct owner review of the light, system-dark, and 320px/200%
reflow captures from the post-CSS-specificity-correction run. Four findings surfaced: one
real defect, two cleared against source evidence, one accepted with rationale.

- **Fixed:** duplicate "Email" label across the magic-link and password forms, which
  collided once the "Other ways to sign in" disclosure was expanded. Quick task
  `260727-v15`, merged as PR #113 (`743864c0`).
- **Cleared:** the apparent flat submit buttons were an artifact of a superseded capture
  set; the action hierarchy renders correctly post-correction. The ember box on the
  disclosure is the `:focus-visible` ring (`sigra_auth.css:765`), not a resting border.
- **Accepted:** the product name breaks mid-token at 320px/200%. The string is the
  acceptance harness's generated app name rather than a product name, and reflow
  containment already passes. Rationale and the open design question are recorded in
  `.planning/todos/pending/2026-07-27-login-wordmark-midword-break-at-320.md`.

Full disposition table and capture provenance live in `229-VERIFICATION.md`.

## Verification

- `mix test`: 33 doctests, 3 properties, 2,438 tests, 0 failures, 12 skipped (3 excluded).
- Focused adopter-experience suite: 153 tests, 0 failures.
- Golden/idempotency suite: 4 tests, 0 failures; independent `--check` reports up to date.
- Fresh generated-host acceptance: 9 browser tests passed.
- `mix compile --warnings-as-errors`, scoped formatter, shell syntax, `git diff --check`,
  axe, theme, focus, reduced-motion, reflow, and CSS-budget gates pass.
- PR #113 carried all required CI lanes green, including `ci-gate`.
