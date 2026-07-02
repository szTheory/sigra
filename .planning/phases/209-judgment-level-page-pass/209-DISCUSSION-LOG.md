# Phase 209: Judgment-Level Page Pass - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-30
**Phase:** 209-judgment-level-page-pass
**Mode:** assumptions
**Areas analyzed:** Panel execution & relationship to advisory diagnostic; Live remediation scope; Snapshot-canary drift gate; Baseline recapture & canary mechanics; Waiver-vs-remediate boundary & no-net-new guardrail

## Assumptions Presented

### Panel Execution & Relationship to the Advisory Diagnostic
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-run the rubric fresh against current source for all 8 pages; `v1.42-IA-DIAGNOSTIC.md` advisory only; 8 scored docs + roll-up index | Confident | Diagnostic authored Phase 205; pages last edited 200-203; rubric forced-finding floor requires fresh adversarial pass |

### Live Remediation Scope — Which IA Findings Still Hold
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Worklist dominated by STILL-LIVE findings; 206/207/208 touched zero page LiveViews | Confident | `git log -1` per page file → Phases 200-203; 206/207/208 commits all docs/gallery/CI-gate |
| Live: index "All clear"/total-users dup; org bare-`<p>` empty-states + dead-end invite; user_show sessions-count dup + buried Manage-sessions + 4 zoe copies + terse kicker; user_sessions `<h1>Sessions` + revoke copy; chips inside/outside form; scope_ribbon above/below header; branding hardcoded scope copy | Confident | Line-anchored in current `lib/sigra/admin/live/*.ex` (read this session) |
| Resolved/waiver-track: audit `<details>` already semantic; per-user "Effective user" absence defensible (subject-scoped) → waiver | Confident | `audit_index_live.ex:82`, `audit_user_live.ex:105`, `:91` |

### Snapshot-Canary Drift Gate — In-Scope vs Deferred
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| (Analyzer) drift is a SEPARATE milestone-integration concern, not 209 SC-4 | Likely | Drift todo self-scopes "MILESTONE-INTEGRATION — NOT Phase 208.1"; rooted in 200-204 commits; 204-03 WCAG canary re-designation policy call |

### Baseline Recapture & Canary Discipline Mechanics
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Checkpoint baselines CI-native ubuntu (platform-pinned); two allowlists; sole canary `impersonation-banner` (not allowlistable); branding has NO checkpoint slug | Confident | `playwright.config.ts:64-66` no OS token; `ci.yml:999-1016` ubuntu; `snapshot-canary-guard.sh:21,99,104`; 9 checkpoint slugs (branding absent) |

### Waiver-vs-Remediate Boundary & No-Net-New Guardrail
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Every actionable → diff OR written waiver; in-place only, no net-new surfaces; monotonic green; do NOT ratchet user-sessions (Phase 210) | Confident | Ledger lines 85-92 (7 Tier-2, user-sessions Tier-1); ledger line 29 monotonic; `organization_live.ex:60` documented omission |

## Corrections Made

### Snapshot-Canary Drift Gate
- **Original assumption (analyzer):** The cross-phase 200–204 snapshot-canary drift + impersonation-banner canary re-designation is a SEPARATE milestone-integration concern, NOT folded into Phase 209.
- **User correction:** **Fold into Phase 209.** Phase 209 IS the binding gate (per STATE's stated intent): as part of SC-4, allowlist the legitimate drifted slugs (`audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin`) AND make the `impersonation-banner` canary-policy decision (re-designate/re-baseline with documented rationale, preserving the shipped 204-03 WCAG contrast fix — not a revert, not a guess-fix). Net effect: the v1.42 integration PR #63 `fast_checks` snapshot-canary lane goes green via Phase 209.
- **Reason:** Matches STATE.md and the drift todo's own "strong candidate binding gate" framing; consolidates the backlog-merge gate into the page pass rather than leaving #63 blocked.

### Assumptions 1–4
- **Confirmed as written** — no corrections (fresh panel re-run; still-live remediation worklist with cited anchors; CI-native ubuntu baseline recapture + canary mechanics; waiver-vs-fix + no-net-new + don't-ratchet-user-sessions).

## External Research

None — every assumption grounded in current source, CI workflow, the guard scripts, the ledger, and the drift todo (all read this session).
