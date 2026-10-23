---
phase: 245-branch-prune-local-and-remote
plan: 01
subsystem: repository-maintenance
tags: [git, bash, pull-requests, branch-safety, tdd]
requires:
  - phase: 244
    provides: completed ref-dependent work and an explicit PR disposition
provides:
  - Report-first local and origin ref-pruning commands bound to committed snapshots and exact allowlist rows
  - Complete PR head/base capture, access preflight, absent-only safety publication, exact remote deletion, and tracking-ref verification
  - Independent complete-ref and direct/peeled object readbacks
affects: [REPO-04]
actuals:
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - One-shot Bash command surface with literal full refs and a repository-wide apply lock
    - Node TAP wrapper around deterministic local and bare-origin Git fixtures
key-files:
  created:
    - scripts/maintainers/prune-stale-branches.remote.test.sh
    - scripts/maintainers/prune-stale-branches.test.mjs
    - .planning/phases/245-branch-prune-local-and-remote/245-01-RED-EVIDENCE.json
    - .planning/phases/245-branch-prune-local-and-remote/245-01-REMOTE-RED-EVIDENCE.json
  modified:
    - scripts/maintainers/prune-stale-branches.sh
    - scripts/maintainers/prune-stale-branches.test.sh
key-decisions:
  - Keep every capture report-only; each apply pass requires a committed exact ref identity, Phase 244 readiness, and fresh PR/origin checks.
  - Treat origin HEAD as a recorded symbolic relationship and preserve direct plus peeled annotated-tag identities.
  - Use a lock shared across linked worktrees and expected-old-OID deletion for tracking refs.
coverage:
  - id: D1
    description: Exact local branch apply is separated from reporting and verifies committed snapshot objects.
    requirement: REPO-04
    verification:
      - kind: unit
        ref: scripts/maintainers/prune-stale-branches.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Origin inventory, PR completeness, access denial, drift, safety publication, remote deletion, and tracking cleanup fail closed.
    requirement: REPO-04
    verification:
      - kind: integration
        ref: scripts/maintainers/prune-stale-branches.remote.test.sh
        status: pass
    human_judgment: false
metrics:
  completed: 2026-09-27
  status: complete
  plan_head_before: 69d814ae82f23e3c84cbb8021b537b5040c44ab1
  commits: 4
---

# Phase 245 Plan 01: Guarded Branch Operator Summary

Plan 01 implements the local and origin branch-prune operator with reporting as the default. Every mutation reads committed evidence, checks full ref/OID/type identity, and has a separate independent readback.

## Task Commits

1. **Local fixture RED** — `c772741d` (`test`)
2. **Local exact-name GREEN** — `ecf8a2de` (`feat`)
3. **Remote and PR fixture RED** — `8440fb6c` (`test`)
4. **Origin and PR safety GREEN** — `fe118612` (`feat`)

## Accomplishments

- Added capture and verification commands for local refs, origin refs, complete live open-PR state, exact allowlists, access preflight, safety refs, local/remote deletion, tracking refs, and object readback.
- The PR reader requires fewer than 1,000 complete rows with unique numbers, valid head/base names and OIDs, authenticated GitHub identity, and explicit repository identity. Failure and rate-limit output is not copied into evidence.
- The origin reader captures full ref namespaces, direct object types, annotated-tag peeled identities, and the advertised `HEAD` target. Missing remote objects are fetched by exact ref with automatic maintenance disabled; a second live listing must remain unchanged.
- Apply passes require D-01 readiness, a committed snapshot and operation row, fresh complete PR exclusions, expected live identities, and a non-mutating exact-ref push preflight for origin writes. The helper never uses a force refspec or broad prune.
- Added a shared apply lock, per-ref expected-old-OID tracking deletion, and complete local/origin ref-set readbacks.
- Fixture coverage includes malformed, duplicate, truncated, failed, rate-limited, changing, and denied PR/access responses; divergent CI safety tips; an annotated safety tag; absent-only publication; remote deletion; tracking cleanup; and a competing-apply lock.

## Deviations

The plan names the Bash self-test, while the GSD RED evidence checker requires Node TAP output. Added a Node `node:test` wrapper and a separate remote fixture script; the plan's Bash command runs both fixture suites. No application or CI wiring changed.

## TDD and Verification

- Both committed RED records returned `RED_EVIDENCE_OK` from `gsd check tdd-red-evidence` before GREEN implementation.
- The scripted Bash self-test passed, including the isolated local and bare-origin lifecycle fixtures.
- The Node TAP wrapper passed with two tests before the final duplicate-PR fixture was added; the final shell suite passed with that fixture included.
- `bash -n` on all three shell files — passed.
- `shellcheck` on the helper and fixture scripts — passed with no findings.
- `git diff --check` — passed.

No project local or origin refs were changed by these tests. All destructive fixture operations stayed inside temporary repositories. The production origin has not yet been mutated by Phase 245.

## Next

Wave 2 Plan 02 captures and commits the live local/origin inventories, PR baseline, and safety-publication list before any production ref mutation. Continue with `$gsd-execute-phase 245`; do not repeat Phase 245 discussion or planning.

## Self-Check: PASSED

- The helper and both fixture scripts exist; all four Plan 01 task commits are in the current history.
- The plan's self-test and the committed TDD evidence checks passed.
- No production origin or local project ref has been changed by Plan 01.
