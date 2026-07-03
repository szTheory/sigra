# Requirements: Sigra — v1.44 ADMIN-UX-RATCHET

**Defined:** 2026-07-03
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Milestone goal:** Automate the evaluation and forward-only ratcheting of admin/operator UI/UX quality (adversarial LLM persona/JTBD + graphic-design panels, deterministic-first with LLM-residual) so award-grade iteration is fast and only-moves-forward — needing a human only for a minimal final sign-off — then apply the harness in one broad wave to elevate every admin surface.

**Invariant across all requirements:** the merge-blocking forward-only signal stays 100% deterministic (monotonic ledger guard, snapshot-canary, axe, token/contrast gates, named spec assertions). The LLM panel is an issue-finder + judge-of-taste ONLY — never a CI gate, never flips a ledger cell. Designed around **cite-and-flip** (evaluate RENDERED output, never code) and **LLM-nondeterminism** (judge off the merge path).

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase.

### Evaluation Harness (HARNESS) — Phase 216

- [x] **HARNESS-01**: A single command renders every admin surface (the 8 L3/L4 pages + flows and the L1/L2 component boards) across the light/dark/mobile × populated/zero/loading/error matrix into per-surface evidence bundles (screenshot + post-hydration DOM + axe JSON + computed-style facts + `app_git_sha` + `render_sha256`), reusing the existing `/admin/_design` gallery and font-ready capture discipline.
- [x] **HARNESS-02**: The harness refuses to evaluate untrustworthy renders — a stale-render guard hard-fails when a bundle's `app_git_sha` ≠ working HEAD (or admin source is newer than the bundle), and an evidence-integrity check rejects any finding whose DOM anchor is absent from the captured DOM, so "cite-and-flip" is impossible by construction.
- [ ] **HARNESS-03**: Deterministic visual probes run over the rendered DOM/computed-style and flag off-token spacing, 1–6px misalignment, size/weight-budget overflow, ember-reserved-for violations, off-scale radius/shadow/control-height, sub-minimum target size, missing focus ring, card-in-card nesting, and a non-obvious or below-fold primary action — promoting the three documented-as-manual scorecard proxies (motion, whitespace rhythm, target-size) to automated, merge-blocking checks.

### Forward Ratchet & Award Gradient (RATCHET) — Phase 216

- [ ] **RATCHET-01**: The quality ledger gains a finer-grained award sub-score above the current Tier-2 ceiling, and the harness re-verifies each existing Tier-2 claim against rendered output (verify-then-climb), flagging any cell that was optimistically flipped in the manual era.
- [x] **RATCHET-02**: A deterministic findings-count-monotonic guard fails CI if any cell's open-finding count increases versus merge-base, and a committed settled-findings set suppresses re-litigation of already-resolved/waived findings — a forward-only signal that counts, never judges.

### Adversarial LLM Panel (PANEL) — Phase 217

- [ ] **PANEL-01**: An adversarial 4-lens LLM panel (3 persona/JTBD lenses verbatim from `admin-persona-jtbd-rubric.md` + 1 new graphic-design/visual-quality lens) evaluates only deterministically-clean surfaces from rendered evidence, under a forced-finding floor (every lens×question holds a cited DOM anchor OR the literal `NONE — searched for: <what>`), emitting machine-parseable findings that round-trip the existing rubric schema.
- [ ] **PANEL-02**: Panel nondeterminism is controlled so verdicts are stable and low-churn — k=3 consensus admits a finding only at ≥2/3 quorum, unchanged surfaces are skipped via content-hash (prior verdict carried forward), and changed surfaces receive a diff-scoped critique (new regressions + unresolved gaps only); the panel is never in the merge-blocking path.

### Auto-Fix with Safety Rails (AUTOFIX) — Phase 217

- [ ] **AUTOFIX-01**: Findings dedup into a single prioritized fix queue keyed by a stable `finding_id` (a hash of surface+lens+question+anchor, not prose), with cross-surface recurring anchors collapsed into high-priority systemic findings so the operator always works highest-value-first.
- [ ] **AUTOFIX-02**: The harness auto-applies only provably-safe fix classes (copy / token-swap / component-swap) as atomic commits, re-renders after each, and auto-reverts any fix that regresses a deterministic gate or an already-elevated surface; judgment fixes route to the human queue. An injected-regression test proves the auto-revert + monotonic guards actually catch a deliberately-clunky change.

### Broad Elevation Wave (ELEVATE) — Phase 218

- [ ] **ELEVATE-01**: Every one of the 8 admin/operator surfaces plus the L1/L2 component fractal is run through the full loop and verify-then-climbed — existing Tier-2 re-verified against rendered output and the award sub-score raised where earned, with each raise protected by the monotonic guard.
- [ ] **ELEVATE-02**: The elevation wave folds in and resolves UI-01 (demo-DX polish nits) and UI-02 (Tasklane rebrand residuals) as part of the admin-adjacent cleanup.
- [ ] **ELEVATE-03**: The batched elevation lands as a reviewable PR where the operator signs off only on the residual judgment calls and the proposed gradient raises (a before/after render strip + narrowed options) — not an open-ended issue hunt.

### Baseline Recapture & Reconciliation (RECAP) — Phase 219

- [ ] **RECAP-01**: After the wave, the ~115 committed PNG baselines are recaptured in-CI (ubuntu), the snapshot allowlists are reset to empty steady-state, and the snapshot-canary drift guard plus generated-host parity are green.

### Terminal Ratification (RATIFY) — Phase 220

- [ ] **RATIFY-01**: The award sub-score cells are locked forward under the monotonic guard, a harness runbook is committed (how to run one iteration + where the human sign-off sits), and the milestone ships via a PR gated on the five required CI checks — with the LLM panel advisory/off-CI throughout.

## v2 Requirements

Acknowledged but deferred — not in this roadmap.

### Config / Installer Features (feature milestone)

- **FEAT-01**: Runtime auth-prefix override (`2026-06-20-runtime-auth-prefix-override`).
- **FEAT-02**: `mix sigra.migrate` schema helper (`2026-06-20-mix-sigra-migrate-schema-helper`).
- **FEAT-03**: White-label auth/email theming (`2026-06-22-white-label-auth-email-theming`).

### Infra / CI (later)

- **SEED-005**: CI/CD pipeline performance audit — Playwright parallelization per-shard DB.
- **SEED-006**: Admin-design gallery CI baseline recapture — deterministic CI fonts (largely resolved; residual tracked).

## Out of Scope

Explicit exclusions for this milestone, with reasoning.

- **New config/installer features (FEAT-01/02/03)** — these are *features*, not UI/UX cleanup; they belong in a later thesis-driven feature milestone, not this quality-automation lane.
- **Non-admin / auth surfaces** — this milestone is scoped to the admin/operator UI (plus the demo-DX/Tasklane nits the harness already renders); auth-form/email theming is a deferred feature.
- **Making the LLM panel a merge-blocking CI gate** — deliberately excluded (the JUDGE-CI-01 deferral): LLM nondeterminism must not gate merges; only its deterministic derivatives do.
- **Hex `1.20.0` retire** — tracked Jon-manual item (`2026-07-03-hex-retire-stray-1-20-0`), not roadmap work.

## Traceability

Filled by the roadmap — every REQ-ID maps to exactly one phase.

| REQ-ID | Phase | Status |
|--------|-------|--------|
| HARNESS-01 | 216 | Complete |
| HARNESS-02 | 216 | Complete |
| HARNESS-03 | 216 | Pending |
| RATCHET-01 | 216 | Pending |
| RATCHET-02 | 216 | Complete |
| PANEL-01 | 217 | Pending |
| PANEL-02 | 217 | Pending |
| AUTOFIX-01 | 217 | Pending |
| AUTOFIX-02 | 217 | Pending |
| ELEVATE-01 | 218 | Pending |
| ELEVATE-02 | 218 | Pending |
| ELEVATE-03 | 218 | Pending |
| RECAP-01 | 219 | Pending |
| RATIFY-01 | 220 | Pending |
