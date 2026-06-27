# Phase 204: Terminal Ratification - Context

**Gathered:** 2026-06-26 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Terminal ratification of milestone **v1.41 ADMIN-UX-ELEVATION** (phases 199-204). The
milestone closes honestly: all Playwright baselines recaptured through the gate with both
allowlists reset to empty, the monotonic quality-ledger guard green vs `origin/main`, the
full admin surface axe-clean (including overlays in their open state), generated-host
parity proven, and a final adversarial milestone review confirming no usability, contract,
or accessibility regression. Tier-2 ledger cells locked.

**Covers:** RATIFY-01, RATIFY-02.

**This is a closing/lock phase, not a feature phase.** It verifies and locks the bar set
by phases 199-203; it does NOT introduce new admin surfaces or new Tier-2 ratchets. Same
mechanics as the prior milestone's terminal phase (v1.39 Phase 192 "Ratification &
Baseline Lock"). Scope-creep into new elevation work belongs to a future milestone.
</domain>

<decisions>
## Implementation Decisions

### Baseline Recapture Scope & Sequencing
- **D-01:** The only baselines that genuinely need recapture are the audit-mobile
  checkpoint PNGs blocked by the `.vt-status-pill` axe failure: `user-audit`,
  `audit-explorer`, and incidentally the `impersonation-banner` canary (its pixels shift
  from the contrast fix), plus any other mobile checkpoint that renders the pill.
  Everything else — chromium/dark checkpoints, all design-gallery lanes, component
  byte-goldens — is already at steady state and is proven via **compare-mode zero-drift
  idempotency**, NOT force-recapture.
- **D-02:** Recapture sequence: (1) fix `.vt-status-pill` contrast → (2) recapture
  `admin-checkpoints-mobile` only (`--update-snapshots` scoped to that project) →
  (3) restore any incidentally-drifted non-pill, non-audit mobile baselines →
  (4) re-run all 6 projects (admin-checkpoints + admin-design × chromium/mobile/dark) in
  compare mode and confirm **0 diffs** → (5) `quality-ledger-monotonic.sh --base origin/main`
  exits 0. Drive recapture through `scripts/ci/snapshot-recapture-gate.sh` (all-green ==
  approval, no human review). Both allowlists (`snapshot-allowlist`,
  `snapshot-allowlist-design`) stay/return to **empty** (comments only).

### `.vt-status-pill` Contrast Fix + Canary Rebase
- **D-03:** Fix the WCAG AA contrast failure by raising the `--vt-color-ink` proportion in
  BOTH the base `.vt-status-pill` (currently `color-mix(... caution 62% + ink)`, ~3.33:1)
  AND the `.vt-status-pill--ok` variant in `test/example/priv/static/assets/css/app.css`
  (~lines 1089-1112), targeting ≥4.5:1 on **both light and dark** themes. Verify each with
  the **axe gate itself** (it reports pass/fail), not by eyeballing.
- **D-04:** Edit `app.css` **precisely** — the file has known stray-comment corruption that
  silently drops the next CSS rule. After editing, confirm the surrounding
  `.vt-status-pill--ok` / `.vt-table-panel` rules survive intact.
- **D-05:** The contrast fix changes the **non-allowlistable** `impersonation-banner`
  canary's pixels. The contrast fix, the recaptured canary PNG, and the recaptured audit
  PNGs MUST all land in the **same commit** — so that vs `origin/main` the new PNGs are the
  established baseline, and the in-phase recapture/canary guard (which diffs `--base HEAD`)
  sees zero post-commit drift. The canary must NEVER be added to an allowlist.

### Test Hardening Folded Into Ratification (WR-01 / WR-02)
- **D-06:** Add a **deterministic per-user audit pagination boundary** ExUnit test to
  `test/example/test/example_web/live/admin_audit_user_live_test.exs`: ≥26 events → nav
  present with correct user-scoped `page_path/4` hrefs (threading `user_id` + `return_to`);
  ≤25 events → nav absent. Closes WR-02. (The `audit-user-live` ledger cell already CITES
  this test as Tier-2 evidence, so it must exist for the claim to be honest.)
- **D-07:** Add a **structural assertion** locking the desktop Event-cell codes (event id +
  action code) inside a **default-collapsed `<details>`** with the `<summary>` as the
  visible affordance (the ratified Phase 202 "inline code disclosure" archetype). Closes
  WR-01. Neither D-06 nor D-07 changes product behavior — both lock existing intent.

### Clean `mix test` for the Terminal Gate
- **D-08:** Fix the two stale known-failure contract tests so `mix test` is green for the
  terminal gate:
  - Delete/relax `Sigra.Planning.Phase192KnownFailureContractTest`
    (`test/sigra/planning/phase_192_known_failure_contract_test.exs:32`) — it asserts an
    `admin-design.spec.ts` MG-5/6 `test.skip(` quarantine marker that is already gone — AND
    resolve its companion todo
    `.planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md`.
  - Update `Sigra.Planning.Phase148EvaluatorFunnelAndFirstRunDxTest`
    (`test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs:40`) expected
    doc strings from `Vaultr` → `Tasklane` (demo app was renamed); fix any companion
    `demo-showcase`/`llms.txt` copy that drifted.
- **D-09:** The 3 `Sigra.UpgradeIntegrationTest` failures (`test/upgrade_test.exs:212`,
  `seed_users!/2`) are **accepted known env-DB failures**, excluded from the gate's pass
  criterion — NOT fixed in this phase. Do not spend effort "fixing" environmental DB
  failures.

### Adversarial Review, Tier-2 Lock & Milestone Close Housekeeping
- **D-10:** Conduct RATIFY-02's adversarial milestone review via the `gsd-audit-milestone`
  skill, producing `.planning/milestones/v1.41-MILESTONE-AUDIT.md` (same artifact shape as
  `v1.40-MILESTONE-AUDIT.md`), with explicit adversarial checks against the four RATIFY-02
  criteria: (a) no usability-for-aesthetics regression (operator JTBD improved, not just
  prettier), (b) no generated-host-contract friction (host extension seams intact, contract
  doc current), (c) no broken dark/mobile/keyboard/reduced-motion paths, (d) no
  screenshot-only quality (interactions work, not just static captures).
- **D-11:** "Tier-2 cells locked" = the ledger cells already flipped to Tier `2` by phases
  199-203 are forward-only protected by the monotonic guard. **204 VERIFIES the lock; it
  introduces NO new Tier-2 ratchets.** (See `guides/reference/admin-quality-ledger.md` —
  ~8 Tier-2 cells; Phase 192's terminal block frames the closing phase's role as locking,
  not ratcheting.)
- **D-12:** Generated-host parity is proven by BOTH: install-golden byte-diff green with the
  **phx_new 1.8.7** pin (a newer archive injects a `root_tag_attribute` config block → a
  spurious diff; do NOT regenerate the fixture to "fix" it — SEED-004) AND
  `scripts/ci/admin-acceptance-smoke.sh` rendering the elevated, styled admin UI on a
  freshly generated host (run the parity lane via `RUN_PARITY=1` on the recapture gate).
- **D-13:** Milestone-close housekeeping is part of this phase: tick Phase 201
  `[ ] → [x]` in `ROADMAP.md` (it is functionally complete — `201-VERIFICATION.md` status
  passed — but still unticked), and flip RATIFY-01 / RATIFY-02 to satisfied in
  `REQUIREMENTS.md` (lines 47-48 and the coverage table at 87-88) as they are proven.

### Claude's Discretion
- Exact `color-mix` ratio for the pill fix (e.g. caution 45-50% + ink) — pick whatever the
  axe gate confirms ≥4.5:1 on both themes; the axe gate is the oracle.
- Internal test naming, describe-block placement, and assertion helper shape for D-06/D-07.
- Whether the stale-contract-test fixes (D-08) and pill fix (D-03) ride in the same or
  separate commits, subject to the D-05 same-commit constraint for the canary rebase.

### Folded Todos
- `2026-06-26-audit-mobile-baseline-recapture-phase204.md` → D-01..D-05 (contrast fix +
  mobile recapture + zero-drift idempotency). Closes 202-UAT G1, 202-VERIFICATION SC-3
  mobile leg.
- `2026-06-26-per-user-audit-pagination-test-coverage.md` → D-06, D-07 (WR-02, WR-01).
- `2026-06-26-stale-known-failure-contract-tests.md` → D-08, D-09.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 204 detail (line ~172) + v1.41 milestone overview (line ~20)
- `.planning/REQUIREMENTS.md` — RATIFY-01/02 (lines 47-48, coverage 87-88)
- `guides/reference/admin-quality-ledger.md` — Tier-2 cells + Phase 192 terminal-lock semantics
- `scripts/ci/snapshot-recapture-gate.sh` — drives recapture; routes slugs to lanes; `RUN_PARITY=1` parity lane
- `scripts/ci/snapshot-canary-guard.sh` — non-allowlistable canary guard (impersonation-banner / board-notice)
- `scripts/ci/quality-ledger-monotonic.sh` — `--base origin/main` forward-only guard
- `scripts/ci/admin-acceptance-smoke.sh` — generated-host runtime parity proof
- `test/example/priv/playwright/snapshot-allowlist`, `snapshot-allowlist-design` — must stay empty
- `test/example/priv/static/assets/css/app.css` — `.vt-status-pill` / `--ok` (~1089-1112; corruption hazard)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — impersonation-banner canary (~289-296)
- `test/example/test/example_web/live/admin_audit_user_live_test.exs` — per-user audit test (no pagination coverage yet)
- `.planning/milestones/v1.40-MILESTONE-AUDIT.md` — adversarial-review artifact precedent
- CLAUDE.md — phx_new 1.8.7 pin (SEED-004), `app.css` comment-corruption + Vaultr→Tasklane notes
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Full gate toolchain already exists and is the approval mechanism (no human review):
  `snapshot-recapture-gate.sh`, `snapshot-canary-guard.sh`, `quality-ledger-monotonic.sh`,
  `admin-acceptance-smoke.sh`.
- `gsd-audit-milestone` skill + `v1.40-MILESTONE-AUDIT.md` template for the RATIFY-02 review.
- Phase 192 (v1.39 terminal phase) is the direct precedent for the entire ratification flow,
  including the "compare-mode zero-drift, not force-recapture" proof method.

### Established Patterns
- Allowlists are empty at steady state; a deliberate recapture adds slug(s) in the same diff
  for reviewability, then resets to empty when merged. The `impersonation-banner` /
  `board-notice` canaries are NEVER allowlistable.
- `admin-checkpoints.spec.ts` runs all 6 checkpoints as ONE linear test per project — an axe
  failure on an early checkpoint (the `.vt-status-pill` pill on the impersonation-banner page)
  aborts before the downstream audit captures. This is exactly why the mobile audit baselines
  are stale and why the pill fix unblocks them.
- Ledger cells ratchet forward only; the closing phase locks, it does not flip new cells.

### Integration Points
- The pill fix is in the **example/demo** `vt-*` Tasklane styling (`app.css`), not the
  library-owned `sg-*` admin CSS — the audit pages themselves are clean; the blocker is
  pre-existing demo styling upstream in the linear test.
- Generated-host parity connects the example proof to a freshly generated phx_new 1.8.7 host
  via the install-golden fixture + `admin-acceptance-smoke.sh`.
- Boot note for local recapture: example dev server on an alt PORT (4000 collides with
  Rulestead Docker); pre-compile before launch to avoid the code-reload crash; set
  `SIGRA_EXAMPLE_URL`.
</code_context>

<specifics>
## Specific Ideas

- The axe gate is the oracle for the contrast fix — verify pass/fail with it, never by eye.
- Same-commit constraint for the canary rebase (D-05) is the one non-obvious sequencing trap;
  it mirrors how Phase 192 proved compare-mode zero-drift.
</specifics>

<deferred>
## Deferred Ideas

None net-new — analysis stayed within the ratification boundary. No new admin surfaces or
Tier-2 ratchets are introduced (that belongs to a future milestone).

### Reviewed Todos (not folded)
- `2026-06-25-phase199-code-review-info-hardening.md` — fixture/self-test hardening (INFO
  severity); not required for an honest milestone close. Defer.
- `2026-06-25-phase200-code-review-deferred.md` — harden token-scoped session revocation +
  de-dupe admin session helpers; product hardening, not ratification scope. Defer.
- `2026-06-18-token-reference-completeness-ci-guard.md` — optional CI guard (186 IN-03); not
  ratification scope. Defer.
- `2026-06-19-uat-demo-dx-polish-nits.md`, `2026-06-20-mix-sigra-migrate_schema-helper`,
  `2026-06-20-playwright-parallelization-per-shard-db.md`,
  `2026-06-20-runtime-auth-prefix-override.md`,
  `2026-06-21-app-css-comment-corruption-cleanup.md` (broader cleanup beyond the precise pill
  edit), `2026-06-22-white-label-auth-email-theming.md`,
  `2026-06-24-oban-enqueue-unguarded...`, `2026-06-22-vaultr-authed-rebrand-residuals.md` —
  all out of the terminal-ratification boundary. Defer to backlog / future milestones.
</deferred>
