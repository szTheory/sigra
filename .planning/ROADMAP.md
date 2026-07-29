# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Active milestone — **v1.47 CI-EFFICIENCY** (Phases 230-235). Next: `/gsd-plan-phase 230`.

## Milestones

- 🚧 **v1.47 CI-EFFICIENCY** — Phases 230-235 (active, roadmap created 2026-07-28) · 24/24 requirements mapped
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (shipped 2026-07-27 · `override_closeout`, 15/15 requirements, 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (shipped 2026-07-11 · `override_closeout`, Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md
- ✅ **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (shipped 2026-07-10) · full detail in milestones/v1.44-ROADMAP.md
- ✅ **v1.43 STABILIZE** — Phases 213-215 (shipped 2026-07-03) · full detail in milestones/v1.43-ROADMAP.md
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

---

# v1.47 CI-EFFICIENCY (active)

**Goal:** Cut PR wall-clock from ~29.5m to under 12m and make every remaining gate honest — by *executing* the already-written SEED-005 audit rather than re-running it.

**Source of truth:** `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` (finished audit; prioritized Phase 198→203 sequence, orphaned when v1.41 reused numbers 199-204; re-verified accurate 2026-07-28). Its scope guardrails bind every phase below.

**Measured baseline (last 40 runs, 2026-07-28):** PR mean 29.5m / p50 27.3m (n=21, 17 pass / 4 fail) · push mean 30.5m (n=7) · **nightly 0 pass / 9 fail (n=9)**. A PR burns ~56 runner-minutes for a 25.6m wall.

**Sole PR critical path:** `example_playwright_smoke` (23m). Inside it: `design_gallery` 734s (**53% of the job**), admin behavior 224s, non-admin 187s, checkpoints 130s, browser install 62s (never cached).

## Verification Philosophy (binds every phase)

`.planning/v1.42-CI-GATE-REMEDIATION-FINDINGS.md` records a milestone that passed audits which were **"code-level reads that never executed the specs"** while the required Playwright check carried ~15 real failures. This milestone inherits the correction:

- **Success criteria are proven by running CI and reading measured numbers — never by reading YAML.**
- Every wall-clock claim needs a before/after pair from real runs (`gh run view <id> --json jobs`), captured with the same method as the baseline table.
- A job that concludes `skipped` proves nothing. `ci-gate` counts `skipped` as pass today, so "the gate is green" is not evidence that a lane ran.
- A demotion is only honest if the receiving lane is *observed executing* the demoted work.

## Two-Tier Shape (owner-approved)

- **Tier 1 — stop the bleeding (230-231).** Phase 230 bundles every low-risk critical-path win into one verifiable step; Phase 231 revives the dead nightly and repairs the gates that report green while asserting nothing.
- **Tier 2 — execute the orphaned audit phases (232-235).** Playwright `storageState` then parallelization, library shard economics, hygiene/DX, then measured ratification.

## Phases

- [ ] **Phase 230: Tier-1 Critical-Path Reclamation** - All low-risk PR-path wins in one revertible step: gallery snapshots off PR (a11y stays), eval probe demoted, `concurrency:`, path filters, browser cache, `timeout-minutes`
- [ ] **Phase 231: Gate Honesty + Nightly Revival** - Revive the 0-pass/9-fail nightly and repair the gates that report green while verifying nothing
- [ ] **Phase 232: Playwright Economics — Authenticate Once, Then Shard** - `storageState` for the design boards first (measured), then per-shard-DB parallelization and a single shared boot prelude
- [ ] **Phase 233: Library Suite Economics** - Restore parallelism, balance the shards, and stop the subprocess-heavy install tests from dominating shard wall-clock
- [ ] **Phase 234: Hygiene, Supply Chain, and Contributor DX** - `mix ci` reproduces the gate, actions SHA-pinned, Dependabot covers Hex+npm, no orphaned specs, SEED-006 closed
- [ ] **Phase 235: Terminal Ratification — Measured, Not Read** - Re-measure against the baseline table, publish the before/after coverage inventory, update CONTRIBUTING, close SEED-005 and the CI-PERF arc entry

## Phase Details

### Phase 230: Tier-1 Critical-Path Reclamation

**Goal**: A contributor's PR run stops paying for work that gates nothing — the PR path drops from ~29.5m toward ~12m in one step, with every assertion it previously enforced still enforced on an observed lane.
**Depends on**: Nothing (first phase)
**Requirements**: FAST-02, FAST-03, FAST-04, FAST-05, FAST-06, FAST-07
**Success Criteria** (what must be TRUE):

  1. On a real PR run, the design-gallery **snapshot** boards do not execute, while the per-board axe WCAG assertions still do — proven by that run's own Playwright output (executed-assertion count), and the snapshots are observed executing and hard-failing capable on a push-to-main / nightly run.
  2. `admin_eval_render` is absent from the job list of a PR run and present on a non-PR run, with the ~17m of PR runner time it consumed no longer charged to any PR.
  3. Pushing a second commit to an open PR branch leaves the superseded run in state `cancelled` in `gh run list`, while a push-to-`main` run and a scheduled run under the same conditions both run to completion (release integrity preserved).
  4. A documentation-only PR (touching only `*.md` / `.planning/`) reports its required checks in a merge-eligible state without running the full job matrix — read from that PR's checks view, not from the workflow file.
  5. A PR run logs a Playwright browser-binary **cache hit** instead of the ~62s download, every job in `ci.yml` reports an explicit `timeout-minutes`, and the run's wall-clock is recorded against the 29.5m/27.3m baseline using the baseline's measurement method.

**Proof discipline**: This phase is judged on one before/after pair of real PR runs (`gh run view --json jobs`), not on a diff review. Do not split this phase — the six changes are independently revertible and together they constitute the one measurable drop. *(Corrected per CONTEXT D-22: this is **not** a pure-YAML change set. FAST-02 also edits `test/example/priv/playwright/tests/admin-design.spec.ts`, and the phase adds two `scripts/ci/` guards plus two ExUnit contract tests. Revertibility survives — the gallery split reverts by deleting a tag argument and a CLI flag.)*
**Non-negotiable**: FAST-02 moves *pixels only*. The axe gate runs on **library** admin components and is covered by no other PR lane; gating all three design projects on `event_name` would silently drop a non-redundant signal (SEED-005 P0-2 mandatory mitigation). *(Owner-ratified reinterpretation 2026-07-28, CONTEXT D-01: the **letter** is superseded — the ~84 per-board axe scans collapse to one full-page scan per design project, because `admin-design.spec.ts:64-66` builds the scanner with no include filter and every board test reaches it in an identical page state, so the repeats carry the coverage of one. The **intent** — never silently drop the WCAG signal no other PR lane covers — is fully preserved and provable: all three viewport/theme projects keep a scan on every PR.)*
**Success criterion 2 restatement**: SC-2 as worded above ("absent from the job list") is literally unsatisfiable — a job whose `if:` evaluates false is still present in `gh run view --json jobs` with `conclusion: "skipped"` and ~0s duration (verified on PR run `30390832059`, six such jobs). Verify against the operative restatement in `230-VALIDATION.md`: present with `conclusion == "skipped"` and duration < 5s on a PR; non-skipped with a real duration on a non-PR run.
**Plans**: 9 plans in 8 waves

Plans:
**Wave 1**

- [x] 230-01-PLAN.md — TRACER: committed CI run-metrics measurement instrument + hermetic self-test + BEFORE evidence slots (D-21)
- [x] 230-02-PLAN.md — FAST-02 spec half: tag the 28 board tests, add one full-page WCAG test per design project, fix the wrong doc comments

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 230-03-PLAN.md — FAST-02 CI half: filter the PR gallery step, add the event-gated snapshot step, wire its id into the seam aggregator (D-05)

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 230-04-PLAN.md — FAST-03 + FAST-04: demote `admin_eval_render` to non-PR events; add workflow-level run supersession

**Wave 4** *(blocked on Wave 3 completion)*

- [ ] 230-05-PLAN.md — FAST-05: a `changes` job with fail-open polarity, step-level gating on four required lanes, `fast_checks`/`library_tests` exempt

**Wave 5** *(blocked on Wave 4 completion)*

- [ ] 230-06-PLAN.md — FAST-06: browser-set-scoped Playwright cache, branched install, and a lockfile version-drift guard

**Wave 6** *(blocked on Wave 5 completion)*

- [ ] 230-07-PLAN.md — FAST-07: explicit `timeout-minutes` on all 22 jobs + a per-job completeness contract

**Wave 7** *(blocked on Wave 6 completion)*

- [ ] 230-08-PLAN.md — D-23 honest-skip set and accepted residuals, durably recorded in `MAINTAINING.md`

**Wave 8** *(blocked on Wave 7 completion)*

- [ ] 230-09-PLAN.md — Observed-run evidence: AFTER-PR, AFTER-NONPR, AFTER-DOCSONLY, AFTER-CANCEL captured with verbatim run IDs

### Phase 231: Gate Honesty + Nightly Revival

**Goal**: Every gate that reports green is asserting something on a lane that actually ran, and a red lane produces a signal a human sees.
**Depends on**: Phase 230 (the demoted `admin_eval_render` lane and the reshaped nightly are what this phase must prove green)
**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04, DX-05
**Success Criteria** (what must be TRUE):

  1. A scheduled nightly run concludes green — or every remaining red lane in it is a filed defect with a diagnosis and an owner, linked from the run. The "0 pass / 9 fail over 9 runs" baseline has a measured successor.
  2. Generated-host parity is verified by a job that **executes on a real PR**, shown by that job's own logs and test counts. The stale `head_ref == 'ship/v1.42-ci-gate-remediation'` condition no longer decides whether parity is checked.
  3. `ci-gate` fails when a needed lane is skipped by a rotted condition and passes when a lane is skipped by a correct event gate — both demonstrated on real runs, with the honest-skip set enumerated explicitly rather than inferred from `skipped`.
  4. `admin_eval_render` concludes `success` on its new lane, and that run's log shows `stale-render-guard.sh` and the fix-queue/anchor integrity checks executing — guards that have never run in CI because the job has failed in its Playwright phase every sampled time.
  5. `gate-ci-green` completes inside its polling ceiling on a real push-to-`main` run (its 30-minute ceiling is shorter than the run it waits for), and a red-probe of the release lane creates a tracking issue — i.e. the `release-lane-rot` label exists and `notify-failure-issue.sh` survives.

**Proof discipline**: Every criterion here is a claim about what a run *did*. A YAML condition that "looks right" is exactly the failure mode this milestone exists to remove — GATE-02's defect is a condition that reads plausibly and has verified nothing for months.
**Plans**: TBD

### Phase 232: Playwright Economics — Authenticate Once, Then Shard

**Goal**: The Playwright critical path collapses — first by removing the per-test re-registration, then by letting the residual seams run at the same time instead of one after another.
**Depends on**: Phase 230 (with the gallery snapshot mass off the PR path, sharding actually pays; SEED-005 found sharding in isolation is bottlenecked by that same 700s+ leg)
**Requirements**: PW-01, PW-02, PW-03
**Success Criteria** (what must be TRUE):

  1. The design projects authenticate **once per project** via a `storageState` setup project; `beforeEach` no longer calls `registerUser()` (currently `admin-design.spec.ts:250-255`, ~120 tests × a full LiveView registration over dev-mode longpoll plus an Argon2id hash). Measured: the design-board step's before/after duration from `gh run view --json jobs`, with an identical passing assertion and snapshot count.
  2. A Playwright run with more than one worker (or matrix-sharded with per-shard database and app) passes at `--retries=0` with no cross-spec interference, so `workers: 1` is no longer required for correctness — proven by running it that way, not by reasoning about it.
  3. The required check name `Example Playwright smoke (full lifecycle)` remains byte-identical after any restructuring, and branch protection still resolves it on a real PR.
  4. The example-app boot prelude exists in exactly one definition referenced by the jobs that boot the app (it is duplicated verbatim across ~6 jobs today), and a full run afterwards shows every one of those jobs still booting successfully.

**Proof discipline**: PW-01 must land and be measured **before** PW-02 restructures anything — otherwise the sharding win and the registration win are indistinguishable in the numbers, and the audit's ordering rationale is lost. Retries and `continue-on-error` are forbidden as flake mitigation (D-15, recorded in `playwright.config.ts`).
**Plans**: TBD

### Phase 233: Library Suite Economics

**Goal**: The library shards do not become the new pole once Playwright stops being one.
**Depends on**: Phase 232 (the shards are off the critical path until the Playwright pole collapses; SEED-005 explicitly ranks this runner-minutes-then-latency)
**Requirements**: TEST-01, TEST-02, TEST-03
**Success Criteria** (what must be TRUE):

  1. Slow-test visibility no longer costs serial execution — a run shows both the slowest-test reporting (or an equivalent committed artifact) and restored parallelism in the same job.
  2. The two `library_tests` shards' durations are recorded before and after, and the after-gap is measurably smaller — one shard no longer idles while the other works.
  3. The subprocess-heavy install/scaffold tests no longer dominate a shard's wall-clock, shown by per-shard job durations before and after. If any were moved off the PR lane, the receiving lane is observed executing them green and the routing decision is recorded with its justification.
  4. `upgrade_test` and golden-contract coverage are demonstrably still exercised on a **pull_request** event after any extraction — the audit's sharpest hazard, because `upgrade_smoke` is nightly-only and `ci-gate` counts a skipped lane as a pass, so this coverage can vanish while everything reports green.

**Proof discipline**: "Faster" here is a per-job duration comparison, and "still covered" is a test-count or spec-name observation on a PR run. Deleting tests to make CI faster is out of scope; only demotion with evidence and a named receiving lane is permitted.
**Plans**: TBD

### Phase 234: Hygiene, Supply Chain, and Contributor DX

**Goal**: A contributor can reproduce the gate locally, and the repo's action/dependency surface stops drifting silently.
**Depends on**: Phase 230 (the local mirror must reflect the post-reshape gate, not the pre-milestone one)
**Requirements**: DX-01, DX-02, DX-03, DX-04, DX-06
**Success Criteria** (what must be TRUE):

  1. `mix ci` on a clean checkout runs the same checks the PR gate runs — including `format --check-formatted` and the dependency-lock checks the alias lacks today (`mix.exs:143`) — and a CI lane invokes the alias so the two cannot drift apart. The one-time tree format must exclude `test/fixtures/install_golden/tree/**` from `.formatter.exs` inputs or it breaks `golden_diff_test`.
  2. Every third-party action in release-critical workflows resolves to a 40-character commit SHA with a trailing version comment (`release-please.yml:88` is the last unpinned one, on the secrets-bearing path — pin the **dereferenced commit**, not the annotated-tag object), and the release workflow still runs green afterwards.
  3. Dependabot covers `mix` and `npm` in addition to `github-actions`, evidenced by opened update PRs or a validated configuration run.
  4. An inventory lists every Playwright spec file against the named CI lane that invokes it; any spec with no lane is either wired in or deleted, with nothing left ambiguous.
  5. SEED-006 is closed as delivered against a real run of the gallery lane, or its residual work is filed as a tracked defect with evidence.

**Proof discipline**: DX-01 is only true if a CI lane runs the alias — an alias that merely *resembles* the gate is the drift this criterion exists to prevent. DX-04's inventory is the same artifact class as GATE-05 and should be produced so Phase 235 can consume it.
**Plans**: TBD

### Phase 235: Terminal Ratification — Measured, Not Read

**Goal**: The milestone's headline claims are proven from run data, and a maintainer can see exactly what moved and where it landed.
**Depends on**: Phases 230, 231, 232, 233, 234
**Requirements**: FAST-01, GATE-05
**Success Criteria** (what must be TRUE):

  1. PR wall-clock is under 12 minutes at p50 across at least 10 post-change PR runs, tabulated directly against the REQUIREMENTS.md baseline (29.5m mean / 27.3m p50 / 41.7m max, n=21) using that table's measurement method.
  2. A single committed artifact lists every spec and lane with where it ran **before** vs **after** (PR / main / nightly), proving no test was silently dropped and naming the lane that now carries each moved one.
  3. Nightly and push-to-`main` outcomes over the same measurement window are recorded, giving the "0 pass / 9 fail" and "6 pass / 1 fail" baselines a measured counterpart.
  4. CONTRIBUTING.md describes the post-v1.47 topology and the local reproduction path (`mix ci` plus the Playwright seam), matching what CI actually runs rather than the pre-v1.40 topology it still describes.
  5. SEED-005 is closed as delivered — or its residuals are filed — and the `CI-PERF` entry in MILESTONE-ARC.md is reconciled to reflect that the audit's Phase 198→203 sequence was executed as 230-235.

**Proof discipline**: This phase re-measures; it does not re-audit. If the p50 lands above 12 minutes, the honest outcome is v1.40's precedent — record the measured number and the binding pole, and disclose the miss rather than restating the target.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 230. Tier-1 Critical-Path Reclamation | 2/9 | In Progress|  |
| 231. Gate Honesty + Nightly Revival | 0/? | Not started | - |
| 232. Playwright Economics | 0/? | Not started | - |
| 233. Library Suite Economics | 0/? | Not started | - |
| 234. Hygiene, Supply Chain, Contributor DX | 0/? | Not started | - |
| 235. Terminal Ratification | 0/? | Not started | - |

## Requirement Coverage

24 of 24 v1.47 requirements mapped; each to exactly one phase.

| Phase | Requirements | Count |
|-------|--------------|-------|
| 230 | FAST-02, FAST-03, FAST-04, FAST-05, FAST-06, FAST-07 | 6 |
| 231 | GATE-01, GATE-02, GATE-03, GATE-04, DX-05 | 5 |
| 232 | PW-01, PW-02, PW-03 | 3 |
| 233 | TEST-01, TEST-02, TEST-03 | 3 |
| 234 | DX-01, DX-02, DX-03, DX-04, DX-06 | 5 |
| 235 | FAST-01, GATE-05 | 2 |

**Placement notes:**

- **FAST-01** (`<12m` p50 over ≥10 runs) sits in Phase 235 rather than 230 because it is only satisfiable after a measurement window that spans the whole milestone. Phase 230 delivers most of the drop and records its own before/after pair.
- **GATE-05** (before/after coverage inventory) sits in Phase 235 because it must span every demotion made in 230-234. Phase 234's DX-04 spec inventory is its direct input.
- **DX-05** (the two filed release-lane defects) sits in Phase 231 rather than the hygiene phase: `gate-ci-green` timing out on a green release and `notify-failure-issue.sh` dying on a missing label are gate-honesty failures — a green thing reported red, and a red thing reported silently.

## Out of Scope (this milestone)

- Re-running the SEED-005 audit playbook. The output exists and was re-verified accurate 2026-07-28.
- Credo, Dialyzer, and `mix_audit` as new gates — each needs its own remediation plan first.
- Converting the `async: false` posture (contract-locked by `phase_153_infra_stability_contract_test.exs`).
- Larger or self-hosted runners — solve the waste first (~56 runner-minutes per PR, ~17 of them an unread red).
- Deleting tests for speed, or masking flake with retries / `continue-on-error` (D-15).
- Retiring the stray Hex `1.20.0` (ADR 003; operator-deferred).

---

## Shipped Milestone Detail

<details>
<summary>✅ v1.46 ADOPTER-EXPERIENCE (Phases 224-229) — SHIPPED 2026-07-27 (`override_closeout` · 15/15 requirements · 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md</summary>

- [x] **Phase 224: Experience Contract + Representative Slice** — JTBD/surface/state contract + UI-SPEC, extended generated-host review substrate, four representative states, ratified baseline comprehension + creative direction (EXPR-01/02) — completed 2026-07-19
- [x] **Phase 225: Secure First-Admin + Generated-Host Security Parity** — host-owned persisted-grant seam + `mix sigra.admin.{grant,revoke,list,check}`, customized policies never overwritten, all 10 impersonation-sensitive operations closed (BOOT-01/02/03, SEC-01) — completed 2026-07-19
- [x] **Phase 226: Auth Entry + Recovery** — semantic `sigra-auth-*` primitives across login, registration, confirmation, reset, reactivation, sudo, invitation acceptance (AUTHUI-01/02) — completed 2026-07-19
- [x] **Phase 227: Account Security Coherence** — settings, MFA, backup codes, passkeys, sessions, destructive flows; theme/a11y/latency ratified (AUTHUI-03/04) — completed 2026-07-19
- [x] **Phase 228: Admin Audit Precision + Boundary Pass** — duplicate filter state repaired, Failures/Impersonation as shareable GET presets, labeled Active-filters region (AUDIT-01/02) — completed 2026-07-19
- [x] **Phase 229: Adoption Handoff + Terminal Ratification** — fresh-host install→revocation smoke, golden drift/idempotency, docs reconciliation, human visual acceptance of the login composition (PROOF-01/02/03) — completed 2026-07-27

**Closed with 8 deferred audit findings.** W-3 is the substantive one: generated auth has browser coverage on exactly one surface (login, no-passkeys), so ~1,100 lines of template change are verified almost entirely by source-string assertion. W-1 (a half-fixed two-branch label collision) is the concrete evidence of what that costs. All eight carry full diagnosis in `todos/pending/2026-07-28-w{1..8}-*`.

</details>

<details>
<summary>⚠️ v1.45 RELEASE-CURRENCY (Phases 221-223) — SHIPPED 2026-07-11 (`override_closeout` · Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md</summary>

- [x] **Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt** — `<.button type>` upgrade-smoke fix + `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin (PUB-01), v1.2.0 + v1.3.0 published to Hex (PUB-02/03), generated-host debt paid (SHIP-01/02/03); PUB-04 retire deferred at phase close (5/5) — completed 2026-07-10
- [x] **Phase 222: Release-Lane Hardening (No Silent Rot)** — durable resolver stray-exclusion, shared loud-signal find-or-create issue notifier on red-`main`/publish-failure, `dry_run=true` publish-path proof + MAINTAINING runbook (HARD-01/02) (3/3) — completed 2026-07-11
- [~] **Phase 223: Get Current on Hex + Terminal Currency Proof** — ⏸️ **DEFERRED 2026-07-11.** Pre-retire snapshot captured (223-01 Task 1). The stray `1.20.0` retire (operator/interactive Hex write step, PUB-04) was deferred indefinitely by Jon (no adopters); PUB-05 (adopter resolution) + PROOF-01 (currency trust bundle) are carried/unproven because they're unsatisfiable while `latest_stable_version=1.20.0` outranks `1.3.0`. Non-blocking (CI gate green regardless). Root cause: ADR 003. Resume `/gsd-execute-phase 223` after the retire lands.

</details>

<details>
<summary>✅ v1.44 ADMIN-UX-RATCHET (Phases 216-220) — SHIPPED 2026-07-10 · full detail in milestones/v1.44-ROADMAP.md</summary>

- [x] **Phase 216: Harness Foundation + Award Gradient** — render substrate, evidence-integrity + stale-render guards, deterministic visual probes, award sub-score ledger extension + verify-then-climb, end-to-end on 2 pilot surfaces (9/9) — completed 2026-07-04
- [x] **Phase 217: Adversarial Panel + Auto-Fix Safety Rails** — 4-lens LLM panel (3 persona/JTBD + 1 graphic-design), k=3 consensus, settled-findings suppression, findings-count-monotonic guard, fix queue, safe-class auto-apply with per-fix auto-revert (8/8) — completed 2026-07-04
- [x] **Phase 218: Elevation Wave + Nit Cleanup** — full loop across all 8 admin surfaces + L1/L2 component fractal; verify-then-climb each; fold in UI-01 (demo-DX nits) + UI-02 (Tasklane rebrand residuals); batched reviewable PR (10/10) — completed 2026-07-09
- [x] **Phase 219: Baseline Recapture + Canary Reconciliation** — ~115 PNG baselines recaptured in-CI (ubuntu), allowlists reset to empty steady-state, snapshot-canary + generated-host parity green (5/5) — completed 2026-07-09
- [x] **Phase 220: Terminal Ratification** — award sub-score cells locked forward under monotonic guard, harness runbook committed, milestone shipped via terminal PR #73 (`c0595e09`) gated on 5 required CI checks; LLM panel advisory/off-CI throughout (4/4) — completed 2026-07-10

</details>

<details>
<summary>✅ v1.43 STABILIZE (Phases 213-215) — SHIPPED 2026-07-03 · full detail in milestones/v1.43-ROADMAP.md</summary>

- [x] **Phase 213: Latest-Phoenix Compatibility** — generated-host compile fix vs phx.new ≥1.8.8, golden fixture reblessed, all 11 archive pins → 1.8.8 + `--check` drift-detector (2/2) — completed 2026-07-02
- [x] **Phase 214: Debt & Robustness Clear** — Oban enqueue guard, `delete_session/3` IDOR guard, app.css corruption cleanup + CI guard, Chimeway.Repo + conditional `:upgrade` skip, retired panel-schema-check.sh + deleted stray v1.20.0 tag (5/5) — completed 2026-07-03
- [x] **Phase 215: Terminal Ratification** — library green (2404/0) + example green (323/0) recorded signals, ledger reconciled, 5 required CI checks green on merged PR #67 (4/4) — completed 2026-07-03

</details>

<details>
<summary>✅ v1.42 ADMIN-DS-ELEVATION (Phases 205-212) — SHIPPED 2026-07-02 · full detail in milestones/v1.42-ROADMAP.md</summary>

- [x] **Phase 205: Foundation** — Adversarial persona/JTBD rubric, real-configuration `board-cfg-*` gallery, IA diagnostic, stress fixtures (4/4) — completed 2026-06-28
- [x] **Phase 206: L1 Component Elevation Wave A** — 8 highest-reuse L1 components to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 207: L1 Component Elevation Wave B + L0 Token Layer** — remaining 5 L1 components + token layer to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 208: L2 Meta-Component Group Elevation** — all 11 MG groups (MG-1…MG-11) to Tier-2 (208-03/GROUP-02 folded into 210-02) (3/3) — completed 2026-07-01
- [x] **Phase 208.1: v1.42 CI-Gate Remediation (INSERTED)** — fix ~15 never-CI-validated admin Playwright failures blocking the backlog ship (4/4) — completed 2026-07-01
- [x] **Phase 209: Judgment-Level Page Pass** — adversarial persona panel over all 8 pages; remediations under the monotonic guard (6/6) — completed 2026-07-01
- [x] **Phase 210: Remaining Cell Elevation** — user-sessions page + 3 persona flows to Tier-2 (2/2) — completed 2026-07-01
- [x] **Phase 211: Terminal Ratification** — every ledger cell reads 2, baselines recaptured, generated-host parity proven (5/5) — completed 2026-07-01
- [x] **Phase 212: v1.42 Integration Merge (INSERTED)** — canary reconciliation + gate persona flows + un-skip generated-host smoke; PR #63 merged to origin/main (4/4) — completed 2026-07-02

</details>

<details>
<summary>✅ v1.41 ADMIN-UX-ELEVATION (Phases 199-204) — SHIPPED 2026-06-27 · full detail in milestones/v1.41-ROADMAP.md</summary>

- [x] **Phase 199: Foundation** — Tier-2 scorecard & stress fixtures — completed 2026-06-25
- [x] **Phase 200: User Detail Elevation** — completed 2026-06-26
- [x] **Phase 201: Users Index Elevation** — completed 2026-06-26
- [x] **Phase 202: Audit Surfaces Elevation** — completed 2026-06-26
- [x] **Phase 203: Consistency Propagation** — completed 2026-06-26
- [x] **Phase 204: Terminal Ratification** — completed 2026-06-27

</details>

Earlier milestones (v1.33–v1.40) are archived under `milestones/`.
