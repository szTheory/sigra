# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Active milestone — **v1.46 ADOPTER-EXPERIENCE** (Phases 224–229). Close the secure first-hour adopter journey and finish the neutral generated-auth contract without reopening the mature admin design system.

## Milestones

- ◆ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (active)
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

## v1.46 ADOPTER-EXPERIENCE (Active)

### Phase 224: Experience Contract + Representative Slice

- [x] Commit the JTBD/surface/state contract and UI-SPEC, extend the existing generated-host review substrate, implement the four representative states, and ratify baseline comprehension + creative direction. Covers EXPR-01/02. — completed 2026-07-19

### Phase 225: Secure First-Admin + Generated-Host Security Parity

- [x] Generate the host-owned persisted-grant seam and CLI workflow, preserve customized policy upgrades, and close all impersonation-sensitive operation drift. Covers BOOT-01/02/03 and SEC-01. — completed 2026-07-19

### Phase 226: Auth Entry + Recovery

- [x] Establish semantic `sigra-auth-*` primitives and propagate them through login, registration, confirmation, reset, reactivation, sudo, and invitation acceptance with configuration-led hierarchy and state-complete microcopy. Covers AUTHUI-01/02. — completed 2026-07-19

### Phase 227: Account Security Coherence

- [x] Propagate the approved contract through settings, MFA, backup codes, passkeys, sessions, and destructive flows; ratify responsive/theme/accessibility/latency behavior. Covers AUTHUI-03/04. — completed 2026-07-19

### Phase 228: Admin Audit Precision + Boundary Pass

- [x] Repair duplicate filter state, flatten and clarify the operator form, expose applied state, and review invitation→scope→admin entry without reskinning host product UI. Covers AUDIT-01/02. — completed 2026-07-19

### Phase 229: Adoption Handoff + Terminal Ratification

- [x] Reconcile templates/golden/docs/upgrades, prove the fresh-host journey and relevant feature variants, obtain final human acceptance, recapture CI-native baselines, and close on deterministic gates. Covers PROOF-01/02/03. — completed 2026-07-27

---

## Shipped Milestone Detail

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
</content>
</invoke>
