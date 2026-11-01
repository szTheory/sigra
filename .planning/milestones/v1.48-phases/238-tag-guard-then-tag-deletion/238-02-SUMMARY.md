---
phase: 238-tag-guard-then-tag-deletion
plan: 02
subsystem: infra
tags: [github-rulesets, rest-api, tag-guard, rel-01, ci-prohibitions]

# Dependency graph
requires:
  - phase: 238-01
    provides: "Tier-2 selection (fnmatch-excluded `creation` rule), operator authorization for repo-settings writes, pre-change ruleset record, BEFORE-* evidence slots"
provides:
  - "Live `tag-namespace` ruleset (id 23574716) validated: target=tag, enforcement=active, bypass_actors=[], one `creation` rule, no `deletion` rule"
  - "Committed verbatim-by-id snapshot `.github/rulesets/tag-namespace.json`"
  - "Live proof: v9.9 rejected (GH013, creation restricted), v9.9.9-rulesettest accepted -- PROVES Assumptions Log A3 (exclude wins over include)"
  - "Citable rule-suite evidence (rule_suite_id 4106927843) embedded in 238-EVIDENCE.md"
  - "scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs -- offline, green, with inline negative control and a committed known-bad fixture"
  - "D-06 delete-deadlock answered by observation: deletion is unaffected by this ruleset; no enforcement flip needed"
  - "AFTER-RULESET-ACTIVE, AFTER-SC1-REJECT-ACCEPT, AFTER-DELETE-PROBE evidence slots captured"
affects: [238-03, 238-04, 238-05, 238-06]

actuals:
  tokens: 4950
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "GitHub tag ruleset SC-1 live proof: push a two-component scratch tag (in scope) to observe rejection, push a three-component scratch tag (excluded by conditions.ref_name.exclude) to observe acceptance -- proves exclude precedence live rather than assuming it from docs"
    - "Delete-deadlock probe as a side effect of the accept probe: deleting the already-accepted scratch tag both cleans up and answers whether the ruleset governs deletion, at zero extra cost"

key-files:
  created:
    - .github/rulesets/tag-namespace.json
    - scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
    - test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json
  modified:
    - .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md

key-decisions:
  - "p19 asserts only `target === \"tag\"` in this slice (the thinnest true body per the tracer's 'do not build any layer beyond what this one path needs' instruction) -- not enforcement, conditions, rules, or bypass_actors."
  - "Recorded the Departs-from line (D-04, ROADMAP SC-1) in AFTER-RULESET-ACTIVE, restated verbatim below, because a `creation` rule landed live."

patterns-established:
  - "p19 template: offline node:test guard reading a committed verbatim-by-id GitHub API snapshot through the single substitutable subject, paired with both an inline negative-control test and a committed known-bad fixture (test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json) read via readRepoFile as a secondary artifact."

requirements-completed: [REL-01]

coverage:
  - id: D1
    description: "Live tag-namespace ruleset created (by operator, per plan's already_done_by_operator note) and read-back-validated: target=tag, enforcement=active, bypass_actors=[], one creation rule, no deletion rule"
    requirement: "REL-01"
    verification:
      - kind: other
        ref: "gh api repos/szTheory/sigra/rulesets/23574716, embedded verbatim in 238-EVIDENCE.md#after-ruleset-active"
        status: pass
    human_judgment: false
  - id: D2
    description: "SC-1 live reject/accept proof: v9.9 rejected (GH013), v9.9.9-rulesettest accepted -- proves Assumptions Log A3 (exclude wins over include)"
    requirement: "REL-01"
    verification:
      - kind: other
        ref: "live git push probes, embedded verbatim in 238-EVIDENCE.md#after-sc1-reject-accept, plus rule-suite JSON (rule_suite_id 4106927843)"
        status: pass
    human_judgment: false
  - id: D3
    description: "p19 offline contract guard: asserts committed snapshot target==tag, non-vacuity floor, inline negative control, and committed known-bad fixture -- all green, ci.yml untouched"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs -- 4/4 pass; full glob scripts/ci/prohibitions/*.test.mjs -- 75/75 pass"
        status: pass
    human_judgment: false
  - id: D4
    description: "Delete-deadlock question (D-06) answered by observation: deleting the accepted scratch tag from origin succeeded -- deletion is unaffected by this ruleset; no enforcement flip needed; enforcement confirmed still active"
    requirement: "REL-01"
    verification:
      - kind: other
        ref: "git push origin --delete v9.9.9-rulesettest (exit 0), gh api .../enforcement == active, embedded in 238-EVIDENCE.md#after-delete-probe"
        status: pass
    human_judgment: false
  - id: D5
    description: "Scratch tag cleanup: both v9.9 and v9.9.9-rulesettest removed locally and remotely; tag counts return to exactly 52 local / 33 remote, matching BEFORE-TAG-INVENTORY"
    requirement: "REL-01"
    verification:
      - kind: other
        ref: "git tag | wc -l == 52; git ls-remote --tags origin | grep -cv '^{}' == 33"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-16
status: complete
---

# Phase 238 Plan 02: Tag-Namespace Ruleset Guard — Tracer Summary

**REL-01's server-side half landed and proven live: the `tag-namespace` ruleset rejects `v9.9`, accepts `v9.9.9-rulesettest`, an offline `p19` guard mirrors the committed snapshot, and A3 (exclude beats include) is now observed, not assumed.**

## Performance

- **Duration:** ~45 min
- **Tasks:** 2/2 complete
- **Files modified:** 4 (`.github/rulesets/tag-namespace.json` created, `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` created, `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` created, `238-EVIDENCE.md` modified across both task commits)

## Accomplishments

- **Live ruleset validated, not created by this executor.** The `tag-namespace` ruleset (id `23574716`) was already live per the operator, created via `POST /repos/szTheory/sigra/rulesets` outside this session (the harness permission classifier blocks `gh api -X POST` against rulesets for this executor). Task 1's step 1 read it back with `gh api repos/szTheory/sigra/rulesets/23574716` and validated `target: "tag"`, `enforcement: "active"`, `bypass_actors: []`, exactly one rule of type `creation`, and no rule of type `deletion` — matching the Tier-2 shape 238-01 selected. Committed the verbatim by-id payload to `.github/rulesets/tag-namespace.json`.
- **SC-1 live proof, both directions observed.** `git tag v9.9 HEAD && git push origin v9.9` was rejected server-side: `GH013 … Cannot create ref due to creations being restricted`. `git tag v9.9.9-rulesettest HEAD && git push origin v9.9.9-rulesettest` was accepted. **This is the live proof of Assumptions Log A3**: `conditions.ref_name.exclude` does take precedence over `include` on this repo's live ruleset. Had it not, the accept probe would have been rejected too — which the plan flags as phase-stopping, because it would mean release-please's `v1.5.1` is also blocked under Tier 2. It was not. A3 verdict: **exclude wins**.
- **Rejection made citable (D-18).** Fetched `rule_suite_id 4106927843` from `GET /rulesets/rule-suites?time_period=day&ref=refs/tags/v9.9`, then the full by-id record with `rule_evaluations[]` naming `ruleset id 23574716`, `rule_type: "creation"`, `result: "fail"`. Embedded the full JSON in `238-EVIDENCE.md` — the id alone is not enough because the query window expires.
- **`p19` guard shipped, offline, green, falsifiable.** `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` follows the `p17` template: header restating the prohibition, offline-by-design paragraph mirroring `p12`, exactly one `readSubject` call against `.github/rulesets/tag-namespace.json`, a pure `rulesetShapeIssue(obj)` checker asserting only `target === "tag"` (thinnest true body for this slice), a non-vacuity floor, an inline negative-control test (branch-target object), and a fourth test reading the committed known-bad fixture `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` via `readRepoFile` as a secondary artifact. 4/4 tests pass; the full `scripts/ci/prohibitions/*.test.mjs` glob is 75/75. `.github/workflows/ci.yml` untouched — the existing prohibition glob picks `p19` up with zero workflow edits (verified byte-identical via `git diff --stat` across both task commits).
- **D-06 delete-deadlock answered by observation.** Deleted the accepted scratch tag `v9.9.9-rulesettest` from origin: `git push origin --delete v9.9.9-rulesettest` succeeded (exit 0). **Verdict, recorded as an observation, not an inference: deletion is unaffected by this ruleset.** No enforcement flip was needed or performed; `gh api .../enforcement` confirmed `active` immediately after the delete. 238-05 can run its remote deletion pass with enforcement left active throughout.
- **Scratch tags fully cleaned up.** Both `v9.9` and `v9.9.9-rulesettest` removed locally (`git tag -d`) after remote cleanup. Post-cleanup counts read directly from source: `git tag | wc -l` = 52, `git ls-remote --tags origin | grep -cv '\^{}'` = 33 — exact match to `BEFORE-TAG-INVENTORY`. Neither scratch name survives anywhere. No other ref was touched: all 18 local-only `v1.NN` tags, `archive/local-main-pre-235-recovery`, and all 11 `phase-238-*` tags remain intact for 238-04/238-05.

## Landed tier and Departs-from restatement (for 238-06 task 3)

**Landed tier: Tier 2 — fnmatch-excluded `creation` rule.** Shape confirmed live: `target: "tag"`, `conditions.ref_name.include: ["refs/tags/v*"]`, `conditions.ref_name.exclude: ["refs/tags/v*.*.*"]`, `rules: [{"type":"creation"}]`, `bypass_actors: []`.

The `Departs from:` line, restated verbatim from `238-EVIDENCE.md#after-ruleset-active` (238-06 task 3 reads this SUMMARY to decide what the dated supersession must cover):

> Departs from: the landed ruleset carries exactly one `creation` rule. This departs from two locked source artifacts, both recorded here because this is the plan where the rule actually lands:
>
> 1. **CONTEXT D-04** — D-04 states absolutely that the ruleset contains no `creation` rule and no `deletion` rule, ever. This IS a `creation` rule, which D-04 forbade. Reason this is safe: D-04's stated objection was that a `creation` rule would block release-please's own tag creation (e.g. `v1.5.1`); the `ref_name.exclude` list of `refs/tags/v*.*.*` takes any three-component release tag out of the ruleset's scope entirely, so the objection D-04 existed to prevent does not apply to this shape. See 238-06 task 3 for the dated supersession record.
> 2. **ROADMAP SC-1's named mechanism** — SC-1 names a name-pattern rule (Tier 1's `tag_name_pattern`) as the mechanism, not a `creation`+`exclude` shape. This departs from the named mechanism. Reason this is safe: SC-1's observable outcome still holds under Tier 2 — a two-component scratch tag name (`vX.Y`) carries exactly one dot and is therefore not excluded by `v*.*.*`, so it remains in the ruleset's scope and is rejected by the `creation` rule; a three-component release tag carries two dots and is excluded, so it is accepted. See 238-06 task 3 for the dated supersession record.

## A3 verdict (Assumptions Log, 238-RESEARCH.md)

**PROVEN, not assumed: `conditions.ref_name.exclude` takes precedence over `include`.** Observed live via the accept probe (`v9.9.9-rulesettest`, in both `include` and `exclude`, ACCEPTED). This was the phase-stopping risk named in the dispatch brief; it did not materialize.

## Delete-probe verdict (for 238-05)

**Deletion is unaffected by the `tag-namespace` ruleset — an observation, not an inference.** The accepted scratch tag's delete from origin succeeded with no rejection and no enforcement flip. 238-05 therefore does not need to open an enforcement-flip window; it can delete the 39-tag allowlist with enforcement left `active` throughout, true guard-first in the literal sense the phase title reads.

## Task Commits

1. **Task 1: End-to-end — a non-SemVer `v*` tag is rejected server-side and the repo knows it** (type=tracer) — `a0623ab3` (feat): read-back-validated the live ruleset, ran the SC-1 reject/accept proof, embedded the citable rule-suite JSON, committed the verbatim snapshot, and shipped the `p19` guard with its fixture.
2. **Task 2: Answer the delete-deadlock question empirically and clear the scratch tags** (type=auto) — `7a81e9f7` (docs): deleted the accepted scratch tag from origin (the delete probe), confirmed enforcement stayed active, removed both scratch tags locally, verified tag-count set-equality against `BEFORE-TAG-INVENTORY`, and flipped the three evidence-slot index rows to `captured`.

Both task commits landed directly on `main` per this run's explicit isolation directive (`isolation=none`, sequential mode — the worktree base-check degraded because `origin/HEAD` is unresolved and local `main` is ahead of `origin/main`).

## Tracer Feedback Gate

Task 1 is `type="tracer"` with no `gate="blocking-human"` attribute. `workflow.auto_advance` and `workflow._auto_chain_active` are both `false` in `.planning/config.json`, so auto-mode re-run-and-continue did not apply. `HUMAN_VERIFY_MODE` is the default `end-of-phase`, and task 1's `<verify>` block carries only `<automated>` entries (no `<human-check>`) — per the tracer feedback gate's third branch, this executor re-ran all four automated verify blocks post-commit (all passed) and continued directly to task 2 without synthesizing a checkpoint.

## Files Created/Modified

- `.github/rulesets/tag-namespace.json` - new file, new directory; verbatim by-id payload of the live `tag-namespace` ruleset (id 23574716).
- `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` - new offline node:test guard; single substitutable subject, `rulesetShapeIssue` pure checker, non-vacuity floor, inline negative control, fixture-based secondary check.
- `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` - new committed known-bad fixture (branch target + deletion rule) per D-09.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` - `AFTER-RULESET-ACTIVE`, `AFTER-SC1-REJECT-ACCEPT`, and `AFTER-DELETE-PROBE` slots filled with fenced commands and full output; index-table rows flipped to `captured`.

## Decisions Made

- `p19`'s checker asserts only `target === "tag"` in this slice — the plan's own "thinnest true body" instruction for a tracer plan. Enforcement, conditions, rules composition, and bypass_actors assertions are explicitly out of scope here (bypass_actors is permanently out of scope per D-10: invisible at CI token level).
- Created the committed known-bad fixture (`test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json`) in addition to the task's literal inline-negative-control instruction, because it is listed as an artifact this phase produces (D-09) and gives the guard a second, independently falsifiable RED proof via `readRepoFile` as a secondary (non-substitutable) artifact.

## Deviations from Plan

None - plan executed exactly as written, with the one adjustment the dispatch brief itself specified: task 1's ruleset-creation step was replaced by a read-back-and-validate step against the operator-created live ruleset, per the plan's own `<already_done_by_operator>` context.

## Issues Encountered

None. The harness permission classifier blocked `gh api -X POST` against rulesets as expected (by design — the orchestrator's prompt explicitly prohibited it for this executor); no other blockers were hit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **238-03** (the `p19` offline guard's own dedicated plan, if separate from this tracer's `p19` v1) has a green starting point: `p19` exists, is offline, and passes 4/4. `AFTER-P19-RED` remains `pending (238-03)` in the ledger — this plan shipped `p19`'s thinnest true body; if 238-03 expands its assertions (enforcement, conditions, rules composition), that expansion is 238-03's job, not a gap in this plan.
- **238-04/238-05** (allowlist-driven deletion) can proceed knowing: (a) enforcement never needs to flip — deletion is structurally unaffected by this ruleset, confirmed by live observation; (b) the tag namespace carries zero scratch residue, exactly 52 local / 33 remote, matching the pre-phase baseline exactly.
- **238-06** (ADR amendment + REL-01 supersession) has the `Departs from:` line available verbatim in both `238-EVIDENCE.md#after-ruleset-active` and this SUMMARY, naming both D-04 and ROADMAP SC-1 with their one-sentence safety reasons.
- No blockers.

---
*Phase: 238-tag-guard-then-tag-deletion*
*Completed: 2026-09-16*

## Self-Check: PASSED

- `.github/rulesets/tag-namespace.json` — FOUND
- `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — FOUND
- `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` — FOUND
- `.planning/phases/238-tag-guard-then-tag-deletion/238-02-SUMMARY.md` — FOUND
- Commit `a0623ab3` (task 1) — FOUND in `git log --oneline --all`
- Commit `7a81e9f7` (task 2) — FOUND in `git log --oneline --all`
- `node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — 4/4 pass
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 75/75 pass
- Live-vs-committed snapshot field diff (`{target,enforcement,conditions,rules}`) — clean
- `git tag | wc -l` = 52, `git ls-remote --tags origin` non-`^{}` count = 33 — both match `BEFORE-TAG-INVENTORY`
- `git diff --stat` on `.github/workflows/ci.yml` across both task commits — empty (unchanged)
