---
phase: "245"
slug: "branch-prune-local-and-remote"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-02"
---

# Phase 245 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + Git CLI + GitHub CLI (`gh`); no application test framework |
| **Config file** | None — use the repository's existing maintainers scripts and committed phase evidence |
| **Quick run command** | `bash scripts/maintainers/prune-stale-branches.test.sh` |
| **Full suite command** | `bash scripts/maintainers/prune-stale-branches.test.sh && bash scripts/maintainers/prune-stale-branches.sh verify-snapshot && bash scripts/maintainers/prune-stale-branches.sh verify-allowlist && bash scripts/maintainers/prune-stale-branches.sh verify-local && bash scripts/maintainers/prune-stale-branches.sh verify-remote && bash scripts/maintainers/prune-stale-branches.sh verify-safety && bash scripts/maintainers/prune-stale-branches.sh verify-prs && bash scripts/maintainers/prune-stale-branches.sh verify-objects` |
| **Estimated runtime** | ~60 seconds for local checks; live GitHub checks depend on API response time |

---

## Sampling Rate

- **After every task commit:** Run the offline pruning-script self-test when its files exist; before those files exist, use `MISSING — Wave 0 must create scripts/maintainers/prune-stale-branches.test.sh`.
- **After every plan wave:** Run the offline self-test and the plan's applicable snapshot, safety-ref, or PR-evidence verifier.
- **Before `$gsd-verify-work`:** Re-run object-resolvability, safety-ref identity/type, and live PR head/base checks against the committed evidence.
- **Max feedback latency:** 60 seconds for offline checks; live API operations have their own bounded timeout.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 245-01-01 | 01 | 1 | REPO-04 | T-245-01 | Exact local fixture prune and object proof; malformed evidence blocks mutation | shell self-test | `bash scripts/maintainers/prune-stale-branches.test.sh` | ❌ W0 | ⬜ pending |
| 245-01-02 | 01 | 1 | REPO-04 | T-245-03 | Complete PR head/base guard and safety conflict rejection | shell self-test | `bash scripts/maintainers/prune-stale-branches.test.sh` | ❌ W0 | ⬜ pending |
| 245-02-01 | 02 | 2 | REPO-04 | T-245-05 | Committed local/origin snapshots are non-empty and every direct/peeled OID resolves | evidence verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-snapshot` | ❌ W0 | ⬜ pending |
| 245-02-02 | 02 | 2 | REPO-04 | T-245-06 | Required origin safety refs retain exact namespace/type/OID | evidence verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-safety` | ❌ W0 | ⬜ pending |
| 245-03-01 | 03 | 3 | REPO-04 | T-245-08 | Committed exact-name candidate list excludes protected heads/bases and anchors | evidence verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-allowlist` | ❌ W0 | ⬜ pending |
| 245-03-02 | 03 | 3 | REPO-04 | T-245-09 | Only selected local refs disappear and recorded objects remain readable | integration verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-local && bash scripts/maintainers/prune-stale-branches.sh verify-objects` | ❌ W0 | ⬜ pending |
| 245-04-01 | 04 | 4 | REPO-04 | T-245-12 | Only selected origin/tracking refs disappear and live PR heads/bases remain intact | integration verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-remote && bash scripts/maintainers/prune-stale-branches.sh verify-local && bash scripts/maintainers/prune-stale-branches.sh verify-prs` | ❌ W0 | ⬜ pending |
| 245-04-02 | 04 | 4 | REPO-04 | T-245-13 | Full final object, safety, PR, local and remote evidence passes | integration verifier | `bash scripts/maintainers/prune-stale-branches.sh verify-objects && bash scripts/maintainers/prune-stale-branches.sh verify-safety && bash scripts/maintainers/prune-stale-branches.sh verify-prs && bash scripts/maintainers/prune-stale-branches.sh verify-local && bash scripts/maintainers/prune-stale-branches.sh verify-remote` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/maintainers/prune-stale-branches.test.sh` — deterministic offline tests for parsing, allowlist membership, empty/malformed evidence, identity conflicts, and fail-closed mutation gates.
- [ ] `scripts/maintainers/prune-stale-branches.sh` — command interface for capture, dry-run, exact-name apply, and post-operation evidence verification; all live mutations remain gated by the committed snapshot and refreshed PR exclusions.
- [ ] Existing Git, GitHub CLI, and `jq` — no dependency installation.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|-----------|-------------------|
| None | REPO-04 | Required outcomes must be demonstrated with committed snapshots and automated Git/GitHub readback; no manual-only pass is accepted. | All destructive steps remain behind the Phase 244 completion gate and exact-name evidence checks. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s for offline checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

## Current Context Reconciliation — 2026-10-02

This addendum reconciles the original phase validation strategy with the later locked
decisions in `245-CONTEXT.md` and the current D-06 blocker. The earlier PR base identity
and cleanup-history audits remain historical records with unresolved status; this phase
must not reconstruct them or change their acceptance criteria.

| Current gate | Required evidence | Stop condition |
|--------------|------------------|----------------|
| D-06 source readiness | `.planning/phases/245-branch-prune-local-and-remote/245-33-PLANNING-PREFLIGHT.json` records the pinned Plan 29 blocker, exact live `origin/gh-pages` OID, local object readability, and GitHub's exact commit response before a plan is created. | Any mismatch in the exact OID, authority source, or immutable prior receipt blocks planning. |
| Exact object recovery | A separate blocking-human decision checkpoint must precede any write to the shared Git object database. Use only the exact commit already named by the live `origin/gh-pages` ref and confirmed by GitHub. | No approval, unavailable object, or any proposed ref/worktree/PR mutation leaves Plan 30 blocked and records a durable blocked result. |
| Post-recovery readiness | Re-run the complete D-06 census against the unchanged captured local/origin/PR identities and record a new machine-readable receipt. | Any unreadable required object or changed identity blocks Plan 30; preserve historical unknowns. |
| Historical evidence | Keep the 11 PR rows and 30 cleanup-history rows explicitly `unresolved`; no new history reconstruction is in scope. | A plan that promotes either historical audit or changes its evidence window is rejected. |

The user authorized planning this gated exact-object recovery. That direction does not
authorize execution of the object-database write; the explicit checkpoint remains an
execution-time prerequisite. No production ref operations or pull-request mutations are
authorized by this plan.
