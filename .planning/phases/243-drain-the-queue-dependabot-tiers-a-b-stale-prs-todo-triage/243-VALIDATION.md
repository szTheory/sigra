---
phase: "243"
slug: "drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-09-24"
---

# Phase 243 — Validation Strategy

> Validation is evidence-driven: external queue operations must be read back from GitHub, and local triage must be proven against a frozen inventory.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `gh` structured JSON, `jq`, Git, and lockfile parsing |
| **Config file** | `.github/workflows/ci.yml` |
| **Quick run command** | `git diff --check` |
| **Full suite command** | Required GitHub Actions jobs on each exact post-merge `main` SHA; no product code suite is added for this operations phase |
| **Estimated runtime** | External CI duration varies; inventory and schema checks should complete locally in under 30 seconds |

## Sampling Rate

- After every dependency merge: compare the PR title to the resulting lockfile entry and observe required CI before the next Tier B merge.
- After every stale PR close: read back closed state, public comment, and head/base refs.
- After todo triage: validate all frozen inventory rows and verify the triage commit path set.
- Before `$gsd-verify-work`: all receipts must be complete and machine-readable; no unresolved required gate may be presented as passed.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 243-01-01 | 01 | 1 | QUEUE-01 | — | Tier A batch identity and CI evidence is read back | external | `gh pr view` for #215, #227, #228, #220 | Yes | pending |
| 243-01-02 | 01 | 1 | QUEUE-01 | — | Lock values match titles and required gate is exact-SHA green | external | lockfile comparison plus `gh run view` | Yes | pending |
| 243-02-01 | 02 | 2 | QUEUE-01 | — | Each Tier B merge waits for green `ci-gate` | external | ordered PR/run evidence validation | Yes | pending |
| 243-02-02 | 02 | 2 | QUEUE-01 | — | Threadline special job/override and #213 hold are proven | external | PR, lockfile and named-job evidence validation | Yes | pending |
| 243-03-01 | 03 | 1 | QUEUE-03 | — | Exactly eight identities are frozen before closes | external | `gh pr list` plus manifest validation | Yes | pending |
| 243-03-02 | 03 | 1 | QUEUE-03 | — | Each public reason and closed state is read back; refs remain | external | `gh pr list --state closed` plus comment/ref validation | Yes | pending |
| 243-04-01 | 04 | 1 | QUEUE-04 | — | Frozen sorted inventory has unique rows and hashes | local | inventory `jq` validation | To create in plan | pending |
| 243-04-02 | 04 | 1 | QUEUE-04 | — | Required FUT records exist without implementing their contents | local | focused `rg` plus todo review | Yes | pending |
| 243-04-03 | 04 | 1 | QUEUE-04 | — | Exactly-one coverage and todo-only commit scope are proven | local/git | inventory validator and `git show --name-only` | To create in plan | pending |

## Wave 0 Requirements

- None. The plan creates the inventory and evidence validators alongside the operational evidence; no new package or CI workflow is required.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Whether a stale PR's work is superseded, obsolete, or deferred | QUEUE-03 | The disposition is a semantic maintainer judgment based on history; public closure text and state remain automatically verifiable. | Inspect the source phase evidence and successor before posting each individual reason. |
| Whether a todo can honestly close | QUEUE-04 | A stale `resolves_phase` label alone is not completion evidence. | Read the specific owner evidence and retain the todo when proof is absent. |

## Validation Sign-Off

- [x] All plan tasks define automated verification and explicit failure signals.
- [x] Sampling continuity: every task has an automated verification contract.
- [x] Wave 0 covers all missing references: no external package/test harness is needed.
- [x] No watch-mode flags; GitHub runs use one 60-second watcher per run under project limits.
- [x] Local feedback commands are under 30 seconds; external CI is gated by exact run evidence.
- [ ] `nyquist_compliant: true` set in frontmatter after execution validation.

**Approval:** pending
