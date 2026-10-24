---
phase: 238-tag-guard-then-tag-deletion
plan: 01
subsystem: infra
tags: [github-rulesets, rest-api, tag-guard, rel-01]

# Dependency graph
requires: []
provides:
  - "Operator authorization for repo-settings writes on szTheory/sigra (task 1, `(a) Authorize`)"
  - "Committed pre-change ruleset record (`238-TAG-RULESET-RECORD.md`) naming the revert value: exactly one ruleset, `main` / `14941512`, `target: branch`"
  - "Committed evidence ledger (`238-EVIDENCE.md`) with BEFORE-RULESET-STATE, BEFORE-TAG-INVENTORY, and BEFORE-RULESET-FEASIBILITY-PROBE captured"
  - "The Tier-1/Tier-2/Tier-3 ladder settled by observation: Tier 1 rejected (HTTP 422), Tier 2 accepted and selected"
affects: [238-02, 238-03, 238-06]

actuals:
  tokens: 8500
  tasks: 1
  commits: 1

tech-stack:
  added: []
  patterns:
    - "GitHub repository ruleset feasibility probing: issue with enforcement=disabled, capture the round-tripped by-id payload, delete in the same cycle, never inferring acceptance from documentation alone"

key-files:
  created: []
  modified:
    - .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md

key-decisions:
  - "Selected Tier 2 (fnmatch-excluded `creation` rule) over Tier 1 (`tag_name_pattern`), because Tier 1 was observed to be rejected by the live API (HTTP 422, enterprise-gated) and Tier 2 was observed to be accepted."
  - "Recorded the Tier-2 departures from CONTEXT D-04 and ROADMAP SC-1 in the same evidence slot as the tier selection, per the plan's obligation that the departure travel with the tier."

patterns-established:
  - "Pattern: feasibility probes for privileged repo-settings writes run with enforcement=disabled and are deleted in the same task/cycle as they are created, with the request/response pair recorded verbatim in the evidence ledger before any tier decision is made."

requirements-completed: []

coverage:
  - id: D1
    description: "Tier-1 and Tier-2 GitHub ruleset feasibility probes issued and recorded; Tier 2 selected as the server-side tag-guard mechanism for the rest of Phase 238"
    requirement: "REL-01"
    verification:
      - kind: other
        ref: "live gh api probe, response embedded verbatim in .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md#before-ruleset-feasibility-probe"
        status: pass
    human_judgment: false

duration: N/A (continuation of pre-authorized task 3 only)
completed: 2026-09-16
status: complete
---

# Phase 238 Plan 01: Ruleset Authorization, Pre-Change Record, and Tier Feasibility Probe Summary

**Tier 2 selected for the tag-name guard — a `creation` rule scoped via `ref_name.exclude` to `refs/tags/v*.*.*` — after Tier 1's `tag_name_pattern` was observed rejected (HTTP 422, enterprise-gated) on this Free-tier repo.**

## Performance

- **Tasks:** 3/3 complete (tasks 1-2 completed and committed in a prior session at `2e1485ef`; this session completed task 3 and wrote this SUMMARY)
- **Files modified:** 1 (`238-EVIDENCE.md`); 1 created (this SUMMARY)

## Accomplishments

- Task 1 (checkpoint:decision, prior session): operator authorized repo-settings writes on `szTheory/sigra` — option `(a) Authorize`.
- Task 2 (prior session, commit `2e1485ef`): committed `238-TAG-RULESET-RECORD.md` (pre-change revert value: one ruleset, `main`/`14941512`) and opened `238-EVIDENCE.md` with `BEFORE-RULESET-STATE` and `BEFORE-TAG-INVENTORY` captured.
- Task 3 (this session): issued both feasibility probes against `POST /repos/szTheory/sigra/rulesets`, `enforcement: "disabled"`, each deleted immediately after capture; recorded both request/response pairs verbatim in `BEFORE-RULESET-FEASIBILITY-PROBE`; selected and recorded the tier with its `Departs from:` line; confirmed the live ruleset list is restored to exactly one entry (`14941512`).

## Tier selection (the load-bearing fact for 238-02, 238-03, 238-06)

**Selected tier: Tier 2 — fnmatch-excluded `creation` rule.**

Shape: `target: "tag"`, `conditions.ref_name.include: ["refs/tags/v*"]`,
`conditions.ref_name.exclude: ["refs/tags/v*.*.*"]`, `rules: [{"type":"creation"}]`,
`bypass_actors: []`.

**Observed evidence, not inferred from documentation:**
- Probe A (Tier 1, `tag_name_pattern`) → **REJECTED**. `HTTP 422 Validation Failed`,
  `{"message":"Validation Failed","errors":["Invalid rule 'tag_name_pattern': "]}`. No ruleset was
  created.
- Probe B (Tier 2, `creation` + `ref_name.exclude`) → **ACCEPTED**. Round-tripped by-id payload
  confirmed `id: 23564973`, `enforcement: "disabled"`, `bypass_actors: []`,
  `current_user_can_bypass: "never"`. Deleted in the same cycle (`gh api -X DELETE
  repos/szTheory/sigra/rulesets/23564973` → success).
- Post-probe live state verified: `gh api repos/szTheory/sigra/rulesets` returns exactly one
  entry — `14941512`, `main`, `target: branch`, `enforcement: active`. No probe ruleset survives.

**Departs from:** Tier 2's landed ruleset contains exactly one `creation` rule. This departs from
two locked source artifacts, and both departures are recorded here so the obligation travels
downstream:
1. **CONTEXT D-04** — D-04 states absolutely that the ruleset contains no `creation` rule and no
   `deletion` rule, ever. This IS a `creation` rule, which D-04 forbade. The justification: D-04's
   stated objection was that a `creation` rule would block release-please's own tag creation (e.g.
   `v1.5.1`). The `ref_name.exclude` list of `refs/tags/v*.*.*` takes any three-component release
   tag out of the ruleset's scope entirely, so the objection D-04 existed to prevent does not apply
   to this shape. See 238-06 task 3 for the dated supersession record.
2. **ROADMAP SC-1's named mechanism** — SC-1 names a name-pattern rule (Tier 1's
   `tag_name_pattern`) as the mechanism, not a `creation`+`exclude` shape. This departs from the
   named mechanism, but SC-1's *observable outcome* still holds under Tier 2: a two-component
   scratch tag name (`vX.Y`) carries exactly one dot and is therefore not excluded by `v*.*.*`, so
   it remains in the ruleset's scope and is rejected by the `creation` rule; a three-component
   release tag carries two dots and is excluded, so it is accepted. See 238-06 task 3 for the dated
   supersession record.

**Honest weakness (238-RESEARCH.md Pattern 2, "three further consequences", consequence 3):**
`v*.*.*` admits `v1.2.3.4`, `v1.a.b`, `v1..`, `v...` — it is a *shape* guard, not a SemVer
validator. It blocks the recurrence class only: two-component `vX.Y` names, which is the pattern
behind 28 of the 39 tags being deleted in this phase and both of the post-ADR-003 regressions the
phase exists to prevent from recurring. It does not validate full SemVer correctness.

**Tier-3 disposition:** Not applicable — Tier 2 was accepted, so Tier 3 was never triggered. Tier 3
(D-02's committed pre-push hook and tag-push detection workflow) remains a named, accepted
replanning trigger of this plan set that did not fire. No Tier-3 infrastructure (no hooks, no
detection workflow) was built, and none is needed given Tier 2's acceptance.

**REL-01 supersession implication for 238-06:** REL-01's "server-side" wording survives under
Tier 2 — the guard is genuinely a server-side GitHub ruleset restriction, not client-side
detection. The supersession 238-06 must record narrows from "detection only, not server-side
prevention" (the Tier-3 fallback framing) to "server-side prevention at coarser granularity than a
SemVer regex" (the Tier-2 reality) — a much smaller amendment than a full Tier-3 fallback would
have required.

## Task Commits

1. **Task 1: Authorize repo-settings writes and the live ruleset mutation** (checkpoint:decision,
   prior session) — operator answered `(a) Authorize`. No commit (decision-only task).
2. **Task 2: Commit the pre-change ruleset record and open the evidence ledger** (prior session) —
   `2e1485ef` (docs)
3. **Task 3: Probe Tier 1 and Tier 2 in one write cycle and record the tier** (this session) —
   committed together with this SUMMARY in the same atomic commit (see plan metadata commit below;
   the orchestrator directed a single combined commit for this continuation session rather than a
   separate task-3 commit followed by a plan-metadata commit).

**Plan metadata + task 3:** single combined commit (see repo `git log` for this plan's final
commit hash) — `docs(238-01)` — updates `238-EVIDENCE.md`'s `BEFORE-RULESET-FEASIBILITY-PROBE`
slot and adds this SUMMARY.

_Note: task 1 was a decision checkpoint with no code/file changes to commit; task 2 was committed
in a prior session per the continuation brief._

## Files Created/Modified

- `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` - flipped
  `BEFORE-RULESET-FEASIBILITY-PROBE` from pending to captured; recorded both probe
  request/response pairs verbatim, the tier selection, the `Departs from:` line, and the
  `Tier-3 disposition:` line; flipped its index-table row from `pending` to `captured`.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-01-SUMMARY.md` - this file.

## Decisions Made

- Tier 2 was selected because it was the only tier the live API accepted; Tier 1 was rejected with
  an explicit `422` naming `tag_name_pattern` as invalid, confirming the Plan-Gating Verdict's
  near-certain NO from documentary evidence with an actual observed API response.
- The Tier-2 departures from D-04 and ROADMAP SC-1 are recorded inline in the evidence slot per
  the plan's obligation that the departure travel with the tier rather than being discovered
  later downstream.

## Deviations from Plan

None - plan executed exactly as written for task 3. The continuation session recorded task 3's
probe evidence (both probes had already been run by the orchestrator/operator per this session's
brief; no additional `gh api -X POST`/`-X DELETE` calls against rulesets were issued by this
executor) and wrote this SUMMARY, matching the plan's task 3 action and acceptance criteria.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required beyond the task 1 authorization already granted.

## Next Phase Readiness

- 238-02 (the tracer) can now be written against the confirmed Tier-2 shape: `target: "tag"`,
  `creation` rule, `ref_name.exclude: ["refs/tags/v*.*.*"]`, `bypass_actors: []`.
- 238-03 (the `p19` offline guard) and 238-06 (the dated D-04/SC-1 supersession record and REL-01
  wording amendment) both have the tier and its departures available from this SUMMARY and from
  `238-EVIDENCE.md`'s `BEFORE-RULESET-FEASIBILITY-PROBE` slot.
- No blockers. Ruleset `14941512` (`main`) is untouched and remains the only live ruleset until
  238-02 creates the `tag-namespace` ruleset.

---
*Phase: 238-tag-guard-then-tag-deletion*
*Completed: 2026-09-16*
