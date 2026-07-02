---
created: 2026-06-17T00:00:00.000Z
resolved: 2026-06-25T00:00:00.000Z
status: resolved
closed_by: FIXT-01 / Phase 199 plan 04
title: admin-design MG-5/6 content-equivalence test is data-dependent (pagination needs 25+ audit events)
area: test
files:
  - test/example/priv/playwright/tests/admin-design.spec.ts
source: phase 191 Wave 4 recapture (191-04) — surfaced in snapshot-recapture-gate.sh admin-design step
resolves_phase: 199
---

## Resolution (2026-06-25, Phase 199 plan 04)

Closed by FIXT-01. The MG-5/MG-6 content-equivalence test is un-skipped and passes against
the ≥25-event seeded fixture.

**How resolved:**
- Plan 199-03 seeded the admin persona with 29 self-tied audit events (≥25 FIXT-01 threshold)
  and a 36-user bulk loadtest cohort inserted BEFORE personas so admin stays first-listed on
  `/admin/users` (inserted_at DESC sort, newest wins).
- Plan 199-04 Task 1 removed the `test.skip(...)` call at line 328 of admin-design.spec.ts.
- The test's live-navigation assertions (lines 347-390) are guarded by conditional `if (count > 0)`
  blocks, so they correctly exercise pagination only when the data supports it.
- Empirical blast radius (Task 2): zero baseline PNGs moved — the content-equivalence test
  takes no screenshots; gallery boards use static assigns; checkpoint lane uses per-run users.
- Both allowlists remain in empty steady-state (no recapture needed).

**Commit:** 6e6d9936 (feat(199-04): un-skip MG-5/MG-6 content-equivalence test)

---

## Original Todo (archived below for history)

## What

The `admin-design` gallery `MG-5/6 content-equivalence` Playwright assertion
unconditionally expects pagination to render for the first user on `/admin/users`.
Pagination only renders when a user has ≥25 audit events. On a freshly-booted
example server, the test-created users each have ~3–5 audit events, so no user
crosses the pagination threshold and the assertion fails.

## Why this is NOT a phase-191 regression

Verified during phase 191 execution:
- Phase 191's true diff (`0a449435..HEAD`) touches only: `admin-glossary.md`,
  one line of `admin-quality-ledger.md`, ~49 lines of pure copy-string swaps across
  5 admin LiveViews, `components_test.exs` golden, the new `glossary_test.exs`, and
  15 recaptured checkpoint PNGs.
- `admin-design.spec.ts` was **not** touched by phase 191 (it was added in phase 185).
- No phase-191 edit touches audit-event seeding or pagination logic — copy swaps
  (org→organization, logins→sessions, etc.) cannot change event counts.
- It "passed in phase 188" only because demo-fixture users were newest/most-active
  then; it is environment/data-dependent, i.e. latent flakiness.

The phase-191 recapture deliverable itself is sound: 15 baselines for the 5 changed
slugs, 0 canary delta, canary-guard PASS, allowlist reset to empty.

## Fix direction

Make the assertion data-independent: either (a) seed one user with ≥25 audit events
in the gallery fixture before asserting pagination, or (b) gate the pagination
assertion on the rendered event count / make it conditional rather than
unconditional. Prefer (a) so the gallery deterministically exercises the paginated
state regardless of boot-time seeding order.

## Update 2026-06-19 (related: SEED-006)

This todo is the MG-5/6 **content-equivalence** test (pagination needs ≥25 audit events),
`test.fail`'d in 192-02 (`cdd7fe13`). When the gallery CI step finally ran un-masked on
PR #54, a **separate** test — the `Design gallery board snapshots` test (admin-design.spec.ts:222)
— failed for ~11 boards (incl. mg-5/6) on **image dimension mismatch** (CI renders boards
taller, likely a brand-font-load difference vs the local capture harness). That broader
in-CI baseline problem is tracked in **SEED-006**, which demoted the gallery step to
`continue-on-error` for the v1.39 ship. Resolve this content-equivalence todo as part of
the SEED-006 re-gating work (don't fix in isolation).

## Also note (separate, unrelated)

Full `mix test` shows 2 pre-existing install-golden failures that reproduce
identically on clean `origin/main` and are out of phase-191 scope:
- `test/sigra/install/vault_promotion_test.exs:9` — undefined attribute "type" for
  `CoreComponents.button/1` under `--warnings-as-errors`
- `test/sigra/install/golden_diff_test.exs:53` — generated-tree byte diff
These belong to the installer/template lane, not the microcopy sweep.
