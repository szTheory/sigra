# Phase 214: Debt & Robustness Clear - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-02
**Phase:** 214-debt-robustness-clear
**Mode:** assumptions
**Areas analyzed:** DEBT-01 (Oban guard), DEBT-02 (phase-209 review items), DEBT-03 (phase-200 review items), DEBT-04 (Hex 1.20.0 wart), DEBT-05 (app.css corruption), HEALTH-03 (spurious mix test failures)

## Assumptions Presented

### DEBT-01 — Oban enqueue guard
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add live-supervision check to account-deletion enqueue, mirroring the two sibling Oban sites; centralize into `OptionalDeps.oban_running?/0`; use raw `Process.whereis(Oban)` | Confident | `deletion.ex:308` bare `oban_available?()`; `delivery.ex:113` + `forwarders.ex:99` already gate on `... and Process.whereis(Oban) != nil`; enqueue at `deletion.ex:207` already post-commit + rescue-wrapped |

### DEBT-02 — phase-209 review items
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Retire `panel-schema-check.sh` with rationale (not wire into CI); IN-02/03/04 become won't-fix; WR-01 residual already resolved | Likely | Script validates frozen v1.42 persona-JTBD planning artifacts (archived milestone); zero refs in `ci.yml` |

### DEBT-03 — phase-200 review items
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| WR-01 fix is backward-compatible (signature preserved); fork = library-layer vs admin-Actions-only guard | Unclear (fork) | Admin path already carries scope-checked `user_id` (`actions.ex:10-21`); store `delete/2` (`ecto.ex:64-72`) unconstrained by `user_id`; both options keep `delete_session/3` signature |
| IN-01 drop unused `@return_to`; IN-02 promote duplicated session helpers to `Admin.Components` | Confident | dup helpers verbatim across `UserSessionsLive` + `UserShowLive` |

### DEBT-04 — Hex 1.20.0 wart
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `1.20.0` is a real leaked Hex release from v1.20 GA milestone; current `@version` correctly `1.1.0`; full retire is interactive-only; repo slice (git tag + contract.md) automatable | Confident (root cause); scope fork | `git tag -l` shows lone three-segment `v1.20.0`; `mix.exs:4`=1.1.0; `contract.md:9` cites 1.20.0 as "published truth"; memory `reference_milestone_tagging` |

### DEBT-05 — app.css corruption
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Delete orphaned sg-* value fragments + stray `*/` tails (don't reconstruct — would dup `sigra_admin.css`); vt-* tokens stay; add CI regex guard; no installer-template copy | Confident | `app.css:6-84` sg-* comment-headers with deleted bodies; dark-block `88-91` orphans; vt-* set fully paired; `find priv/templates -name app.css` → none |

### HEALTH-03 — spurious mix test failures
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| (a) Chimeway.Repo auto-starts with no test-DB config → noise; config-DB or suppress-start. (b) UpgradeIntegrationTest needs phx_new archive + env DB; graceful preflight-skip (not blanket `:postgres` exclusion) | Likely | `deps/chimeway/.../application.ex` unconditional Repo child; `test/upgrade_test.exs` `@moduletag :upgrade` + InstallFixture shells `mix phx.new`; CI lane installs archive + Postgres; CLAUDE.md forbids blanket `:postgres` exclusion |

## Corrections Made

Two genuine contract-level forks were escalated (per repo methodology — touching shipped
API / published-package contract). Both resolved by user:

### DEBT-03 — WR-01 session-revocation guard placement
- **Original assumption:** Fork flagged Unclear between library-layer hardening and
  admin-Actions-only guard.
- **User decision:** **Library-layer (harden Auth).** Guard inside `Sigra.Auth.delete_session/3`
  when `opts[:user_id]` is present — protects ALL callers of the shipped API, zero
  behaviour change when `user_id` omitted.
- **Reason:** Strongest defense-in-depth; the admin path already passes `user_id`, so the
  guard fires there automatically, and other callers gain the protection too.

### DEBT-04 — Hex 1.20.0 retire scope
- **Original assumption:** Root cause confirmed; scope fork between full retire (interactive)
  and repo-hygiene-only.
- **User decision:** **Repo slice + runbook.** Delete stray `v1.20.0` git tag + fix
  `contract.md` in-phase; document `mix hex.retire` as a manual runbook for Jon; do not
  block the phase on the interactive Hex retire.
- **Reason:** The retire needs interactive Hex write-key auth only Jon can run; the
  automatable repo slice + a tracked runbook closes DEBT-04 without blocking.

All other assumptions confirmed as presented.

## External Research

None performed — codebase evidence was sufficient for all six items. Two items involve
external *actions* rather than research gaps: DEBT-04's `mix hex.retire` (interactive Hex
auth) and DEBT-01's optional `Oban.whereis/1` (deliberately not adopted; raw
`Process.whereis` matches existing code).
