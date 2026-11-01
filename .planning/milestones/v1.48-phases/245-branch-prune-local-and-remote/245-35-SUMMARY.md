---
phase: 245-branch-prune-local-and-remote
plan: 35
subsystem: repository-maintenance
tags: [git, object-recovery, branch-pruning, d06]
requires:
  - phase: 245
    provides: committed Plan 18 typed object snapshot, Plan 23 public readiness, and historical Plan 29/30/34 records
provides:
  - Digest-bound recovery decision and truthful blocked D-06 readiness evidence
affects: [245-36, REPO-04]
status: blocked
plan_head_before: e1e37ea2c25a100711c757fa347ee054cfe900bd
tech-stack:
  added: []
  patterns: [digest-bound exact-object fetch, complete no-ref-mutation census]
key-files:
  created:
    - .planning/phases/245-branch-prune-local-and-remote/245-35-OBJECT-RECOVERY.json
    - .planning/phases/245-branch-prune-local-and-remote/245-35-D06-READINESS.json
    - .planning/phases/245-branch-prune-local-and-remote/245-35-SUMMARY.md
key-decisions:
  - "The user approved exactly four OIDs bound to preflight SHA-256 5fc848c5a21c0dfe160079e237d587f9f383f8c5a5c8ffd31001f99372efe829; live source drift voided that approval before the fetch."
  - "No fetch was attempted. The four approved OIDs remain pinned, but origin/heads/gh-pages advanced and its replacement commit is unreadable locally."
  - "Plan 36 remains gated on a fresh ready D-06 receipt; historical PR and cleanup audits remain unresolved."
completed: 2026-10-03
status_detail: blocked-before-fetch
---

# Phase 245 Plan 35: Exact Object Recovery Summary

The user approved one exact source-only fetch for four commit OIDs bound to preflight SHA-256 `5fc848c5a21c0dfe160079e237d587f9f383f8c5a5c8ffd31001f99372efe829`. Immediate revalidation blocked the operation before sandbox escalation or fetch because the complete origin ref inventory had changed from 361 rows (SHA-256 `c4c39e26b2a80fd9c8ea58382b3eabb46024693594e91ccfd36ad5f42d89e453`) to 363 rows (SHA-256 `58a06c4d91f8be15b9e6256a6f8ba7667784983d7cffe3e3514e7d2ce31ec65e`). No object import or production ref/PR operation occurred.

## Evidence

- `refs/heads/gh-pages` advanced from `c39e423cb023b60aefbda3e848b0a89395ff22d3` to `d2358eebe1cb4411d73552ec2359e54d8a4c98b4`; the replacement commit is not readable locally.
- The annotated tag inventory now includes peeled commit `e7eb414fefbd1587daf3c943868914916a565836`, readable locally as a commit.
- The four approved OIDs remain advertised by the same refs, and their GitHub commit/tree identities still match the receipt.
- The current preflight typed-object snapshot has 360/364 readable; the four approved commits remain the only missing objects in that pinned snapshot. The newly advertised `gh-pages` commit adds another unreadable object to the current source census.
- Public Plan 23 readiness passed; 14 open PR identities agree across CLI and REST. The existing 11-row PR mismatch and 30-row cleanup-history audits remain unresolved.
- Preflight and current index/worktree fingerprints differ. Since the source inventory drifted, the exact approval was voided and the approved command was not invoked.

## Task results

- Task 1: committed fresh execution preflight `e1e37ea2` (SHA-256 `5fc848c5a21c0dfe160079e237d587f9f383f8c5a5c8ffd31001f99372efe829`).
- Task 2: user approved the exact four-OID command bound to that SHA.
- Task 3: blocked before fetch after immediate source revalidation; attempt count 0.

Plan 36 must not proceed until a separate, fresh D-06 recovery covers the new `gh-pages` source and Plan 35 has a current ready receipt. The approval recorded here cannot be reused.
