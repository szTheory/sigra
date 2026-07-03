# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Milestone **v1.44 ADMIN-UX-RATCHET** active — Phases 216–220.

## Milestones

- 🚧 **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (active)
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

## Phases

### v1.44 ADMIN-UX-RATCHET (Phases 216–220) — ACTIVE

- [ ] **Phase 216: Harness Foundation + Award Gradient** — render substrate, evidence-integrity + stale-render guards, deterministic visual probes, award sub-score ledger extension + verify-then-climb, end-to-end on 2 pilot surfaces
- [ ] **Phase 217: Adversarial Panel + Auto-Fix Safety Rails** — 4-lens LLM panel (3 persona/JTBD + 1 graphic-design), k=3 consensus, settled-findings suppression, findings-count-monotonic guard, fix queue, safe-class auto-apply with per-fix auto-revert
- [ ] **Phase 218: Elevation Wave + Nit Cleanup** — full loop across all 8 admin surfaces + L1/L2 component fractal; verify-then-climb each; fold in UI-01 (demo-DX nits) + UI-02 (Tasklane rebrand residuals); batched reviewable PR
- [ ] **Phase 219: Baseline Recapture + Canary Reconciliation** — ~115 PNG baselines recaptured in-CI (ubuntu), allowlists reset to empty steady-state, snapshot-canary + generated-host parity green
- [ ] **Phase 220: Terminal Ratification** — award sub-score cells locked forward under monotonic guard, harness runbook committed, milestone ships via PR gated on 5 required CI checks

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

## Phase Details

### Phase 216: Harness Foundation + Award Gradient
**Goal**: A single near-command renders every admin surface into tamper-proof evidence bundles, deterministic visual probes run and flag defects automatically, and the quality ledger gains a finer-grained award sub-score — all proven end-to-end on two pilot surfaces.
**Depends on**: Nothing (first phase of milestone; builds on v1.43 clean foundation)
**Requirements**: HARNESS-01, HARNESS-02, HARNESS-03, RATCHET-01, RATCHET-02
**Success Criteria** (what must be TRUE):
  1. A single command (`scripts/uat/up.sh` + one harness invocation) emits render bundles — screenshot + post-hydration DOM + axe JSON + computed-style facts + `app_git_sha` + `render_sha256` — for every admin surface across the light/dark/mobile × populated/zero/loading/error matrix.
  2. The stale-render guard hard-fails (non-zero exit) when a bundle's `app_git_sha` does not match working HEAD or admin source is newer than the bundle; an evidence-integrity check rejects findings whose DOM anchor is absent from the captured DOM, making cite-and-flip impossible by construction.
  3. Deterministic visual probes run over the rendered DOM/computed-style and produce machine-readable findings for off-token spacing, misalignment, size/weight-budget overflow, ember-reserved violations, off-scale radius/shadow/control-height, sub-minimum target size, missing focus ring, card-in-card nesting, and non-obvious/below-fold primary actions.
  4. The award sub-score ledger extension is committed and the harness runs a verify-then-climb pass over existing Tier-2 claims against rendered output, flagging any cell that fails re-verification.
  5. The findings-count-monotonic guard exits non-zero when any cell's open-finding count increases versus merge-base, and two pilot surfaces complete the full render-probe-ratchet loop end-to-end with zero guard regressions.
**Plans**: TBD
**UI hint**: yes

### Phase 217: Adversarial Panel + Auto-Fix Safety Rails
**Goal**: The 4-lens LLM panel (3 persona/JTBD + 1 graphic-design) evaluates deterministically-clean surfaces under a forced-finding floor with k=3 consensus, deduplicates findings into a stable fix queue, and auto-applies only provably-safe fix classes with per-fix auto-revert on regression — all proven by an injected-regression test.
**Depends on**: Phase 216
**Requirements**: PANEL-01, PANEL-02, AUTOFIX-01, AUTOFIX-02
**Success Criteria** (what must be TRUE):
  1. The 4-lens LLM panel emits machine-parseable findings that round-trip the existing rubric schema, with every lens-question holding a cited DOM anchor or the literal `NONE — searched for: <what>` — the forced-finding floor holds on deterministically-clean surfaces.
  2. k=3 consensus admits a finding only at ≥2/3 quorum; unchanged surfaces are skipped via content-hash (prior verdict carried forward) so re-runs on unmodified code produce zero new LLM calls and zero finding churn.
  3. All findings dedup into a single fix queue keyed by stable `finding_id` (hash of surface+lens+question+anchor); cross-surface recurring anchors collapse into high-priority systemic findings visible at the top of the queue.
  4. An injected-regression test proves that a deliberately-clunky change (off-token spacing, ember misuse, misalignment) causes the auto-revert to fire and the findings-count-monotonic guard to exit non-zero — the safety rails actually catch a regression.
  5. The panel is not in the `fast_checks` job and does not appear in any merge-blocking CI gate; only its deterministic derivatives (monotonic guard, probe findings) gate merges, preserving the JUDGE-CI-01 invariant throughout.
**Plans**: TBD
**UI hint**: yes

### Phase 218: Elevation Wave + Nit Cleanup
**Goal**: Every admin surface and the L1/L2 component fractal runs through the full harness loop, existing Tier-2 claims are re-verified and award sub-scores raised where earned, UI-01 and UI-02 nits are folded in, and the result lands as a single reviewable PR where the operator signs off only on residual judgment calls and gradient raises — not an open-ended issue hunt.
**Depends on**: Phase 217
**Requirements**: ELEVATE-01, ELEVATE-02, ELEVATE-03
**Success Criteria** (what must be TRUE):
  1. All 8 admin/operator surfaces and the L1/L2 component fractal have been run through the full harness loop (render → deterministic probes → panel → dedup queue → safe auto-fix) and verify-then-climbed, with each earned award sub-score raise protected by the monotonic guard.
  2. UI-01 (demo-DX polish nits) and UI-02 (Tasklane rebrand residuals) are resolved as part of the elevation wave — no outstanding items in either carry-forward todo.
  3. The batched elevation result exists as a reviewable PR with a before/after render strip and narrowed options for each judgment call, so the operator's review is bounded to approval decisions rather than a fresh issue hunt.
**Plans**: TBD
**UI hint**: yes

### Phase 219: Baseline Recapture + Canary Reconciliation
**Goal**: After the elevation wave, all ~115 committed PNG baselines are recaptured in-CI (ubuntu), allowlists are reset to empty steady-state, and the snapshot-canary drift guard plus generated-host parity are green.
**Depends on**: Phase 218
**Requirements**: RECAP-01
**Success Criteria** (what must be TRUE):
  1. All ~115 committed PNG baselines are recaptured via the in-CI ubuntu recapture job (not darwin-local), producing a reviewable PR that lands with zero spurious drift.
  2. Both snapshot allowlists are reset to empty steady-state — no slugs are suppressed by allowlist entries — and the snapshot-canary drift guard exits zero on a clean re-run.
  3. Generated-host parity is green: install-golden byte-diff and the acceptance-smoke runtime render both pass against the post-wave codebase.
**Plans**: TBD
**UI hint**: yes

### Phase 220: Terminal Ratification
**Goal**: The award sub-score cells are locked forward under the monotonic guard, a harness runbook is committed, and the milestone ships via a PR gated on the five required CI checks — with the LLM panel advisory and off-CI throughout.
**Depends on**: Phase 219
**Requirements**: RATIFY-01
**Success Criteria** (what must be TRUE):
  1. Every award sub-score cell in the quality ledger is locked forward under `quality-ledger-monotonic.sh` — the guard exits zero against merge-base and would exit non-zero if any sub-score were lowered.
  2. A committed harness runbook documents the one-iteration loop (how to run, where the human sign-off sits, how to read the dossier) so a future agent can re-run without prior context.
  3. The milestone ships via a PR gated on all five required CI checks under ruleset 14941512 (`Library tests`, `Example unit smoke`, `Install smoke`, `Example HTTP smoke`, `Example Playwright smoke`) — all green before the ROADMAP status flips to shipped.
  4. The LLM panel is advisory and off-CI in the final shipped state — no panel invocation appears in any required-check job, preserving the forward-only deterministic signal invariant.
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 216. Harness Foundation + Award Gradient | 0/? | Not started | - |
| 217. Adversarial Panel + Auto-Fix Safety Rails | 0/? | Not started | - |
| 218. Elevation Wave + Nit Cleanup | 0/? | Not started | - |
| 219. Baseline Recapture + Canary Reconciliation | 0/? | Not started | - |
| 220. Terminal Ratification | 0/? | Not started | - |
