---
phase: 238-tag-guard-then-tag-deletion
plan: 05
subsystem: infra
tags: [git-tags, github-rulesets, release-hygiene, maintainers-tooling]

requires:
  - phase: 238-02
    provides: the live Tier-2 `tag-namespace` ruleset and its committed snapshot
  - phase: 238-03
    provides: the red-proven `p19` contract guard that makes ruleset drift loud
  - phase: 238-04
    provides: the committed 39-row allowlist and the dry-run-by-default delete script
provides:
  - 39 planning and phase-proof tags deleted locally, 21 of them also deleted from origin
  - local tag namespace reduced 52 -> 13, remote 33 -> 12, each set-equal to its regex-derived keep-set
  - AFTER-LOCAL-DELETE and AFTER-REMOTE-DELETE evidence slots captured from live output
  - a release surface proven byte-identical across the deletion window
affects: [238-06, 245]

actuals:
  tokens: 7800
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Four-separate-invocations protocol: mutate, verify, mutate, verify — never chained, so a verification cannot inherit the mutation's exit status"
    - "Set-equality against a regex-derived keep-set computed at compare time, with no cardinality written into the assertion"

key-files:
  created:
    - .planning/phases/238-tag-guard-then-tag-deletion/238-05-SUMMARY.md
  modified:
    - .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md

key-decisions:
  - "Deleted locally first and verified before touching the remote, so a defect in the instrument would have surfaced on the recoverable side"
  - "Read the release count from the REST releases route rather than `gh release list`, whose draft field does not exist and would have yielded a confident false zero"
  - "Recorded the classifier denial and the later success as a non-deterministic harness outcome rather than claiming the second attempt satisfied a rule"

patterns-established:
  - "Pre-deletion gate: the guard must be live, snapshotted, contract-tested green and the tree clean before the first destructive invocation"
  - "Reversibility stated as a live constraint (no gc/reflog/prune until Phase 245) rather than as a closing caveat"

requirements-completed: [REL-02]

coverage:
  - id: D1
    description: "39 allowlisted tags deleted locally; surviving local set is exactly the regex-derived keep-set"
    requirement: REL-02
    verification:
      - kind: integration
        ref: "bash scripts/maintainers/delete-planning-tags.sh verify-local"
        status: pass
    human_judgment: false
  - id: D2
    description: "21 remote-flagged tags deleted from origin; surviving remote set is exactly the regex-derived keep-set"
    requirement: REL-02
    verification:
      - kind: integration
        ref: "bash scripts/maintainers/delete-planning-tags.sh verify-remote"
        status: pass
    human_judgment: false
  - id: D3
    description: "Release surface unchanged across the deletion window: 12 published, 0 drafts, v1.4.0 source tree still 200"
    requirement: REL-02
    verification:
      - kind: integration
        ref: "gh api repos/szTheory/sigra/releases --paginate (before/after diff empty); curl https://github.com/szTheory/sigra/tree/v1.4.0 -> 200"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-17
status: complete
---

# Phase 238 Plan 05: Tag Deletion Summary

**The planning-tag namespace is gone from both sides — 52 local tags down to 13, 33 remote down to 12 — with every published release provably untouched and the guard that prevents recurrence already standing.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-09-17
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- **The deletion executed in four separate invocations**, in the mandated order: local apply (`deleted=39 absent=0`), `verify-local` (13 == 13, set-equal), remote apply (`deleted=21 absent=0`), `verify-remote` (12 == 12, set-equal). No pass was chained to another, so no verification could inherit a mutation's exit status.
- **The prefix-collision hazard was observed resolving correctly on the real repository**, not just in 238-04's scratch clone: `v1.0` deleted while `v1.0.0` survives, and likewise for the `v1.1`/`v1.3`/`v1.4`/`v1.5` pairs. It holds because every delete invocation took one literal name from an allowlist row; no glob was expanded at any call site.
- **The release surface is proven unchanged**, read from the REST releases route before and after: 12 published, 0 drafts, the two captures diffing empty. None of the 39 allowlist rows backed a release, asserted against the live route before the first delete rather than inferred from the allowlist's own self-description. `v1.4.0` still resolves on origin at `cfc5e6b8` and its GitHub tree serves 200, so the HexDocs source reference is intact.
- **A home-directory path that had leaked into 238-03's TAP capture was scrubbed** from the evidence ledger. This repository is public; the ledger now contains zero home-directory prefixes.

## Deviations

- **The plan is `autonomous: false` and its operator gate was satisfied outside the executor.** The orchestrator printed the complete 39-row local and 21-row remote delete sets, derived live from the committed allowlist, and the operator approved that exact list before any destructive invocation ran.
- **No `gsd-executor` ran this plan.** The Agent dispatch was refused by the Claude Code auto-mode Bash classifier with reason `[Git Destructive]`, as was a subsequent direct `local --apply` in the orchestrator session. The operator then ran the local apply pass themselves; the remaining three passes were permitted on retry. The evidence slots are written from output observed directly by the orchestrator, which is the only party that observed it.
- **Why the classifier permitted the retry is unknown.** The operator's authorization and the retry are confounded and the denial should be treated as non-deterministic, not as a rule now satisfied. Recorded rather than smoothed over, because the opposite reading would mislead the next run.
- **`AFTER-RELEASE-SURFACE` remains `pending (238-06)`.** Its data was captured here and lives inside `AFTER-REMOTE-DELETE`; the dedicated slot belongs to 238-06 and was left for it rather than filled early.

## Reversibility

The 39 refs are gone from both sides. The objects are reachable **by SHA only**, through the `pre_delete_sha` column of `.planning/decisions/003-tag-delete-list.tsv` — the forward-feed Phase 245 consumes before pruning the branch that holds the `phase-proof` tags. Until 245 runs, no garbage collection, reflog expiry or prune may run in this repository. That step, not this one, is what would make the deletion truly irreversible. No such command ran at any point in this phase.

## Handoff

238-06 writes the `MAINTAINING.md` runbook, the dated ADR 003 amendment correcting guardrail 3, and the REL-01 supersession — the last reading its rule type from the committed snapshot rather than from memory. One correction it must carry: the allowlist's `pre_delete_sha` column holds a single value (the dereferenced commit), with the tag-object names preserved in the file's comment header. The ADR amendment should describe the column as it is.
