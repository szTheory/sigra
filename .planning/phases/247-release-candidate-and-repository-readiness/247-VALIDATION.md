---
phase: "247"
slug: "release-candidate-and-repository-readiness"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-06"
---

# Phase 247 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for library tests; deterministic shell/Node assertions for repository inventories; GitHub CLI/API for live PR state |
| **Config file** | `mix.exs`; `.github/workflows/ci.yml`; scoped Phase 247 inventory contract, if the plan adds one |
| **Quick run command** | `mix docs --warnings-as-errors` and `mix hex.publish --dry-run` from the reviewed candidate worktree |
| **Full suite command** | No Phase 247 full-suite run. Do not use it to substitute for Phase 246 required CI or Phase 248 exact-source gate evidence. |
| **Estimated runtime** | Not measured; derive from execution logs and keep the local documentation/package checks bounded. |

---

## Sampling Rate

- **After every task commit:** Run the task's narrow source, inventory, or documentation check and `git diff --check` for changed text files.
- **After every plan wave:** Reconcile the candidate/source and inventory evidence against READY-01/READY-02 using the exact reviewed source SHA.
- **Before `$gsd-verify-work`:** Run `mix docs --warnings-as-errors`, `mix hex.publish --dry-run`, `mix hex.build --unpack`, metadata/link assertions, the complete PR/path disposition checks, and a clean-worktree assertion in the candidate checkout.
- **Max feedback latency:** No measured limit; avoid repository-wide CI in this phase.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 247-01-01 | 01 | 1 | READY-02 | T-247-01 | Fresh Git/GitHub observations are captured into stable, complete disposition rows. | inventory contract | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | ❌ W0 | ⬜ pending |
| 247-01-02 | 01 | 1 | READY-02 | T-247-02 | A clean worktree is pinned to reviewed source only after Phase 246 evidence and complete dispositions. | Git/inventory assertion | `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage checkout .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` | ❌ W0 | ⬜ pending |
| 247-02-01 | 02 | 2 | READY-01 | T-247-03 | A live post-refresh PR/Git ref query proves recorded pre-refresh head, new head, base, reviewed main, and Phase 246 tested SHA ancestry or exact-head renewed review before further writes; version metadata also agrees. | live source and metadata contract | `node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage candidate --assert-live-refresh .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` | ❌ W0 | ⬜ pending |
| 247-02-02 | 02 | 2 | READY-01 | T-247-04 | Curated 1.6.0 notes contain only source-backed adopter claims under the versioned heading, with none stranded under Unreleased. | changelog contract + ExDoc | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs && cd tmp/phase-247-candidate && mix docs --warnings-as-errors` | ❌ W0 | ⬜ pending |
| 247-03-01 | 03 | 3 | READY-01 | T-247-05 | README routes adopters through the v1.6 guide to the versioned changelog; compatibility and host actions are evidence-backed at the rechecked post-write PR head. | docs contract + live source | `cd tmp/phase-247-candidate && mix docs --warnings-as-errors && git show --check --oneline HEAD && cd ../.. && node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage candidate --assert-live-refresh .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` | ❌ W0 | ⬜ pending |
| 247-04-01 | 04 | 4 | READY-01, READY-02 | T-247-06 | Final ledger and local package checks cover the same clean candidate head; missing Phase 246 proof remains blocked. | package + final ledger contract | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs && node .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs --stage final .planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Define the inventory artifact schema and its deterministic completeness check before collecting release dispositions; include trusted base SHA, checkout HEAD, every modified/untracked path, each open PR, reason, and disposition.
- [ ] Confirm whether an existing test/helper can assert candidate version/changelog/README/ExDoc consistency; add a focused check only if no existing seam covers the required behavior.
- [ ] Make the candidate-stage validator re-query live PR and Git refs after refresh and reject recorded head/base/main/tested-source mismatch or non-fast-forward movement without review evidence bound to the new head.
- [ ] Confirm Phase 246 required evidence and the reviewed source identity before any candidate-refresh or adopter-claim task becomes executable.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Decide whether an individual inherited PR or checkout change blocks or belongs in the 1.6.0 source. | READY-02 | This is a maintainer scope/ownership decision; automated checks can require a disposition and reason but cannot infer release intent from a title or path. | Record one of the three locked categories, the reason, and the owner/source evidence in the committed disposition ledger; do not merge, close, or discard work as part of this decision without its separately authorized workflow. |

---

## Validation Sign-Off

- [ ] All plan tasks have `<automated>` verification or a documented checkpoint where only maintainer intent can decide the outcome.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers every missing validator or source-identity prerequisite.
- [ ] No watch-mode flags.
- [ ] Feedback latency recorded from execution evidence; do not claim a bound before measurement.
- [ ] `nyquist_compliant: true` set in frontmatter after verification evidence is complete.

**Approval:** pending
