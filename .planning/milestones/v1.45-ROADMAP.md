# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Active milestone — **v1.45 RELEASE-CURRENCY** (Phases 221–223). Get Sigra current and trustworthy on Hex: unblock the publish gate, publish v1.2.0 + v1.3.0, retire the stray 1.20.0, harden the release lane against silent rot.

## Milestones

- ⏳ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (active) · unblock gate → harden lane → publish + prove
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

## Phases

### v1.45 RELEASE-CURRENCY (Phases 221-223) — ACTIVE

- [x] **Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt** — resolve the `<.button type>` upgrade-smoke warning-as-error (lib + installer template + example parity, golden re-blessed) so `ci-gate` goes green on push-to-`main`, and pay down the generated-host debt that ships to every adopter (passkey `scope:` defense-in-depth, copy/DX nits, app.css corruption-guard blind spot)
- [x] **Phase 222: Release-Lane Hardening (No Silent Rot)** — make the `Upgrade smoke` gate un-rot-able (PR-visible or loud red-`main` signal) and verify release-please auto-publish fires end-to-end on a green gate — or fails loudly — with a documented recovery/manual-dispatch runbook (completed 2026-07-11)
- [~] **Phase 223: Get Current on Hex + Terminal Currency Proof** — ⏸️ **DEFERRED 2026-07-11.** Pre-retire snapshot captured (223-01 Task 1); the stray `1.20.0` retire (operator/interactive Hex write step) was deferred indefinitely by Jon (no adopters, low stakes). PUB-05 (adopter resolution) + PROOF-01 (currency trust bundle) remain **carried/unproven** because they're unsatisfiable while `latest_stable_version=1.20.0` outranks the real `1.3.0` GA. Non-blocking: CI gate is green regardless (`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0`). Root cause of the phantom release captured in ADR 003. Resume `/gsd-execute-phase 223` after the retire lands.

## Phase Details

### Phase 221: Unblock the Gate + Ship-Honest Generated-Host Debt

**Goal**: The code bound for Hex is honest and the release gate is green — resolve the upgrade-smoke `<.button type>` blocker so `ci-gate` goes green on push-to-`main`, and pay down the generated-host debt that ships to every adopter, before anything is published.
**Depends on**: Nothing (first phase of milestone)
**Requirements**: PUB-01, PUB-02, PUB-03, PUB-04, SHIP-01, SHIP-02, SHIP-03
> **Reordered 2026-07-10 (planning):** PUB-02/03/04 pulled forward from Phase 223 as gate dependencies of PUB-01 — research proved publishing/retiring alone can't green the smoke (the stray `1.20.0` out-sorts `v1.2.0`/`v1.3.0` and retire doesn't drop it from the list); greening requires publishing v1.2.0+v1.3.0 AND pinning `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0`. See 221-CONTEXT.md D-12..D-16.
**Success Criteria** (what must be TRUE):

  1. The `Upgrade smoke (published source → local candidate)` job compiles the upgrade harness clean under `--warnings-as-errors` and `ci-gate` is green on push-to-`main` — the `<.button type>` warning-as-error is resolved in lib + installer template + example in parity, with the install golden fixture re-blessed. (PUB-01)
  2. A freshly generated host's `mfa_settings_live.ex` passes `scope:` into `save_passkey_name` and handles the `{:error, :impersonation_forbidden}` clause — restoring the library-level impersonation defense-in-depth, mirrored from the example twin, with the golden fixture re-blessed. (SHIP-01)
  3. The generated delete-passkey confirmation copy matches the example twin (golden re-blessed) and `up.sh --help` prints the full `--print-env` usage line with no truncation. (SHIP-02)
  4. `scripts/ci/app-css-corruption-check.sh` catches an orphaned bare value placed immediately after a `;`-terminated declaration (the `last_was_prop` reset), proven by a committed regression case. (SHIP-03)

**Plans**: 5 plans

- [x] 221-01-PLAN.md — SHIP-01 passkey-rename `scope:` + impersonation clause and SHIP-02a delete-copy dedupe in the installer template, golden re-blessed (SHIP-01, SHIP-02)
- [x] 221-02-PLAN.md — SHIP-02b `up.sh --help` window + SHIP-03 corruption-guard `last_was_prop` reset with net-new fixture/driver wired into CI (SHIP-02, SHIP-03)
- [x] 221-03-PLAN.md — PUB-01 smoke-floor pin: `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` on the `upgrade_smoke` job (PUB-01)
- [x] 221-04-PLAN.md — PUB-02/03 operator publishes of v1.2.0 (dry-run then real) and v1.3.0 via `hex-publish.yml` (autonomous: false)
- [x] 221-05-PLAN.md — PUB-04 retire stray 1.20.0 + PUB-01 terminal gate-green observation on push-to-`main` (autonomous: false)

### Phase 222: Release-Lane Hardening (No Silent Rot)

**Goal**: The release lane can no longer silently strand a release — the `Upgrade smoke` gate is made un-rot-able and release-please auto-publish is proven to fire on a green gate (or fail loudly), with the recovery path documented. Lands before the publish so the publish itself exercises the hardened path.
**Depends on**: Phase 221 (the gate must be green first so hardening validates against a real green baseline)
**Requirements**: HARD-01, HARD-02
**Success Criteria** (what must be TRUE):

  1. The `Upgrade smoke` gate can no longer rot unnoticed — it runs/reports on `pull_request` (PR-visible) **or** a red result on `main` raises a loud, discoverable signal (alert / annotation / failing required aggregate) instead of failing silently. (HARD-01)
  2. release-please auto-publish is verified to fire end-to-end when a release is cut on a green `ci-gate` — **or** to fail loudly (not silently) when blocked. (HARD-02)
  3. The recovery / manual-dispatch runbook (`hex-publish.yml` `workflow_dispatch` with `tag` + `release_version` + `dry_run`) is documented so an operator can publish or diagnose a stranded release. (HARD-02)

**Plans**: 3 plans
**Wave 1**

- [x] 222-01-PLAN.md — HARD-01 durable resolver stray-exclusion (drop stray `1.20.0`) + retire the D-13 ci.yml start-version pin (D-03/D-04)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 222-02-PLAN.md — shared loud-signal notify-failure-issue.sh + two consumer jobs: `notify_release_lane_rot` (ci.yml red-main) and `notify-release-failure` (release-please publish/gate failure) (D-02/D-06.3/D-07)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 222-03-PLAN.md — HARD-02 `dry_run=true` publish-path proof against v1.3.0 + MAINTAINING.md recovery/manual-dispatch runbook (D-06.1/D-08)

### Phase 223: Get Current on Hex + Terminal Currency Proof

**Goal**: Sigra is current and trustworthy on Hex — v1.2.0 then v1.3.0 published contiguously after v1.1.0, the stray 1.20.0 retired, a clean adopter resolution proven, and the end state recorded as the milestone's trust artifact. Runs last, once the gate is green and the lane is hardened.
**Depends on**: Phase 221 (green gate + v1.2.0/v1.3.0 published, 1.20.0 retired), Phase 222 (hardened auto-publish lane)
**Requirements**: PUB-05, PROOF-01
> **Reordered 2026-07-10 (planning):** PUB-02/03/04 (publish v1.2.0, publish v1.3.0, retire 1.20.0) moved to Phase 221 as gate dependencies — the smoke can't green without them. This phase now verifies the terminal end-state only: clean adopter `~> 1.0` resolution (PUB-05) + the release-currency trust bundle (PROOF-01). SC 1–3 below were executed in Phase 221; retained here for record.
**Success Criteria** (what must be TRUE):

  1. Sigra `v1.2.0` is published to Hex.pm — the agent verifies a clean dry-run and `ci-gate` green first; the operator dispatches the publish (interactive Hex write-auth) — keeping the series contiguous after `v1.1.0`. (PUB-02)
  2. Sigra `v1.3.0` is published to Hex.pm after `v1.2.0` (same dry-run-then-operator-dispatch pattern), making the current shipped code (through v1.44) available to adopters. (PUB-03)
  3. The stray Hex `1.20.0` is retired so `latest_stable_version` resolves to the real GA (`1.3.0`) — the operator dispatches `mix hex.retire sigra 1.20.0` per runbook (interactive write-auth); the agent verifies via the `hex.pm/api/packages/sigra` `latest_stable_version` API. (PUB-04)
  4. A clean adopter resolution is proven — `{:sigra, "~> 1.0"}` / `mix deps.update` resolves to `1.3.0`, not the stray `1.20.0` nor the stale `1.1.0` (agent-verified resolution check). (PUB-05)
  5. A release-currency proof bundle records the end state — `ci-gate` green on `main`, Hex `latest_stable_version` = `1.3.0`, adopter `~> 1.0` resolution verified, and full library + example suites green — as the milestone's trust artifact. (PROOF-01)

**Plans**: 3 plans
- [ ] 223-01-PLAN.md — Retire stray Hex 1.20.0 (operator checkpoint) + verify currency (latest_stable = 1.3.0) [PROOF-01 prerequisite]
- [ ] 223-02-PLAN.md — PUB-05 raw adopter resolution proof: scratch `{:sigra, "~> 1.0"}` `mix deps.get` locks 1.3.0 (no stray-exclusion filter)
- [ ] 223-03-PLAN.md — PROOF-01 trust bundle: suites green + ci-gate/Hex evidence → emit 223-PROOF.md

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 221. Unblock the Gate + Ship-Honest Generated-Host Debt | 5/5 | Complete    | 2026-07-10 |
| 222. Release-Lane Hardening (No Silent Rot) | 3/3 | Complete    | 2026-07-11 |
| 223. Get Current on Hex + Terminal Currency Proof | 1/3 (Task-level) | ⏸️ Deferred — blocked on operator retire | 2026-07-11 (partial) |

---

## Shipped Milestone Detail

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
