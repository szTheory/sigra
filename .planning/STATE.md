---
gsd_state_version: "1.0"
milestone: v1.50
milestone_name: CI-SPEED-AND-RELIABILITY
current_phase: null
current_phase_name: null
current_plan: null
status: closed_with_deferred_scope
last_updated: "2026-11-10"
state_head: b11bcca1db7c0186b4610ab4f10aeb7f84567540
progress:
  total_phases: 8
  completed_phases: 2
  total_plan_records: 164
  plans_with_terminal_summaries: 157
last_activity: 2026-11-10
last_activity_desc: v1.50 archived as a partial internal closeout; four requirements remain deferred and the next route is new-milestone planning.
---

# Project State

## Project Reference

See: .planning/PROJECT.md

**Core value:** Authentication that works out of the box with a clear path for Phoenix adopters.
**Current focus:** Define the next milestone. No phase or plan is active.

## Current Position

v1.50 is closed as an internal planning milestone with deferred scope. Phase252 and Phase255 have passed current verification (2/8). Phase253 remains `gaps_found`; Phase254 lacks a verification report; Phases255.1–258 remain incomplete. The audit remains `gaps_found`.

Main CI run `42756400672` passed on `970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d`. That does not prove the current dirty diagnostics edits. The Git worktree remains dirty; `.git` is read-only in this session, so no broad staging or commit was attempted.

**Next command:** `$gsd-new-milestone`
**Next actor:** User
**External authority:** None for new GitHub requests, merges, releases, tags, or retries/renewals of consumed source-bound attempts.

## Deferred Requirements

| Requirement | Status | Closeout decision |
|---|---|---|
| CISPEED-01 | Deferred/open | No successful comparable pairs; median is null. |
| CISPEED-02 | Deferred/open | No valid population; p95 and runner cost are unproved. |
| CIREL-01 | Deferred/open | Selected registration failure was not reproduced. |
| CIDX-02 | Deferred/open | Current diagnostics source lacks matching main/hosted proof. |
| CIMEAS-01 | Adjusted | Accept the dated 2026-10-12 baseline; defer a fresh snapshot. |

## Deferred Items

Items acknowledged by the production audit writer at the v1.50 closeout. Acknowledgment suppresses the audit until an item changes; it does not resolve the underlying work. Forty-two records were newly acknowledged; 54 were already acknowledged by prior closes.

| Category | Item | Status | Deferred At | Milestone |
|---|---|---|---|---|
| debug_sessions | `253-r2-native-controls-all-fail` | diagnosed | 2026-11-10 | v1.50 |
| debug_sessions | `phase253-registration-timeout` | verifying | 2026-11-10 | v1.50 |
| debug_sessions | `phase256-prep-readiness` | investigating | 2026-11-10 | v1.50 |
| debug_sessions | `phase256-source-lineage` | resolved_offline | 2026-11-10 | v1.50 |
| quick_tasks | `260923-uqh-add-deterministic-offline-regression-cov` | missing | 2026-11-10 | v1.50 |
| todos | `2026-09-15-admin-eval-render-isolated-red-has-no-consumer.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-composite-action-outside-supply-chain-guards.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-gate-05-ledger-scope-and-manifest-contradiction.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-get-form-in-liveview-race-on-users-index-and-user-audit.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-honest-skip-parity-guard-does-not-exist.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-p12-evidence-guard-is-pinned-to-phase-230.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-15-test-01-02-timing-machinery-orphaned.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-dep-off-restore-leaves-threadline-forwarder-a-noop-until-forced-recompile.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-docs-index-goes-stale-on-every-version-bump.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-installer-template-ships-a-dead-planning-link-to-every-adopter.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-phase-241-ratchet-baseline-scans-lib-only-but-guides-render-on-hexdocs-too.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-repo-03-requirement-text-still-asserts-the-stash-push-that-d-09-abandoned.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-upgrade-guide-link-removal-was-lossy-where-a-lossless-fix-existed.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-upgrade-test-never-runs-anywhere-wrong-mix-task-name.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-16-walkthrough-excerpt-diverges-from-the-template-it-quotes.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-home-directory-paths-are-already-public-in-ten-committed-planning-files.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-p19-bypass-actors-literal-is-constructed-at-runtime-to-route-around-its-own-grep-gate.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-p19-known-bad-fixture-short-circuits-before-its-second-declared-violation.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-17-tag-ruleset-drift-observer-has-never-run-and-has-two-latent-defects.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-19-example-playwright-smoke-manifest-step-gate-inaccuracy.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-25-fut-02-dependabot-groups-policy.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-09-25-fut-04-launch-pack-contract-caller.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-10-01-investigate-node-git-stdin-stall.md` | acknowledged | 2026-11-10 | v1.50 |
| todos | `2026-10-28-fix-org-config-test-async-capture-log-race.md` | acknowledged | 2026-11-10 | v1.50 |
| seeds | `SEED-261023-9t1` | dormant | 2026-11-10 | v1.50 |
| seeds | `SEED-261023-opm` | dormant | 2026-11-10 | v1.50 |
| uat_gaps | `253/253-UAT.md` | acknowledged | 2026-11-10 | v1.50 |
| verification_gaps | `253/253-VERIFICATION.md` | gaps_found | 2026-11-10 | v1.50 |
| verification_gaps | `245/245-VERIFICATION.md` | gaps_found | 2026-11-10 | v1.50 |
| deferred_items | `252/d4e1f1c5e5f3` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `252/3b881400f79b` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `252/2a488b4a872d` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `255.1/fd966a49e076` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `240/8b4e48b719b8` | acknowledged | 2026-11-10 | v1.50 |
| deferred_items | `244/534052033cf9` | acknowledged | 2026-11-10 | v1.50 |

## Durable Evidence

- Approved partial-closeout proposal: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/RESCOPE-PROPOSAL.md` (SHA-256 `f2b29ccbae3b8c89f0e5b55942f076e154944986bf8e81aff3fb0c1ecbfc3700`).
- User decision receipt: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/RESCOPE-DECISION-01.json` (SHA-256 `b9d5e34fa7af98323051a7fa9964ccaf4fe0c9419ac9ee09293bbee27d2e43b8`).
- Final audit: `.planning/milestones/v1.50-MILESTONE-AUDIT.md`; requirements: `.planning/milestones/v1.50-REQUIREMENTS.md`; full roadmap: `.planning/milestones/v1.50-ROADMAP.md`.
- Phase trees: `.planning/milestones/v1.50-phases/`; exact recovery archive and status manifest: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/write-ahead/phase-archive-01/`.
- Newly acknowledged item ledger: `.planning/recovery/opengsd-health-20261106/phase253-milestone-closeout-20261110-01/write-ahead/reconcile-06/ACKNOWLEDGMENT-LEDGER.json`.
- Cross-phase integration audit: `.planning/execution/v1.50-audit/INTEGRATION.md` (17/17 connections wired; performance flow has no passing sample).
- Final route write-ahead copy: `.planning/recovery/opengsd-health-20261106/phase253-milestone-rescope-20261110-01/write-ahead/reconcile-08/PRESERVATION.json`.

## Session Continuity

Last session: 2026-11-13 — resumed via /gsd-resume-work; stopped at: session resumed, proceeding to `$gsd-new-milestone` scoping (no phase/plan active).

No phase command is active. Define the next scope with `$gsd-new-milestone`. Preserve all halted one-use attempts; do not retry or renew them. The current worktree is not clean, and no files were discarded or committed.
