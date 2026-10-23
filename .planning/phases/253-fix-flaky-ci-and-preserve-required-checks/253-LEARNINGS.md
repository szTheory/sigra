---
phase: 253
phase_name: "Fix Flaky CI and Preserve Required Checks"
project: Sigra
generated: "2026-10-21"
status: incomplete_phase_process_review
scope: "Recent repair loop:175,178,181,182,183; original requirements and current maintenance"
counts:
  decisions: 3
  lessons: 5
  patterns: 3
  surprises: 2
missing_artifacts:
  - "253-VERIFICATION.md"
  - "253-UAT.md"
---

# Phase 253 lessons: stop restarting the same repair

This is a review of an incomplete phase, not a completion report. The intended result remains a reproduced CI failure with a tested fix, and proof that required checks cannot go green when expected work fails or disappears. Recent attempts instead concentrated on the scripts that check old plans and results.

At the maintenance capture boundary there were183 plans,103 summaries,28 halted attempts and no runnable plan. Plan and summary text alone totaled about6million characters. These are measurements of accumulated process, not delivered CI reliability. The review below concentrates on the recent five stopped repairs; it is not an exhaustive audit of all historical work.

## Decisions

### Preserve the failed attempts; stop numbering ordinary fixes

Keep the old plans, failures, raw outputs and spent acceptance limits unchanged. The user's request to leave the loop authorizes ordinary local maintenance, with its own clearly labeled development outputs. It does not turn Plan183 green, launch Plan179, or replenish a hosted collection budget. No Plan184 is needed to fix a fixture assertion.

**Rationale:** Restarting planning after every development error adds new counts and owners that the next repair must migrate again.
**Source:** 253-181-SUMMARY.md;253-182-SUMMARY.md;253-183-SUMMARY.md; user's request after183.

### Measure progress against the two original requirements

Report separately: a reproduced/fixed selected CI failure; retained required-check coverage and failure behavior; local checker maintenance. Plans, preservation refs, schema checks and simulated routes are supporting work and cannot satisfy the first two outcomes by themselves.

**Rationale:** CIREL-01 remains partial_not_reproduced and CIREL-02 remains unaccepted despite many completed implementation summaries.
**Source:** .planning/REQUIREMENTS.md;253-CONTEXT.md D-04/D-18/D-24;253-183-EXECUTION-RECORD.json.

### Remove automatic backward routing

The immediate route is a status/recovery review, not another `plan-phase --gaps` cycle. Read253-RECOVERY-RESET.md before resuming. No plan is unblocked by this maintenance. Any future acceptance needs a concrete, valid path that respects the existing stops and budgets.

**Rationale:** Both181 and182 ended by directing the next session back to planning, which added another migration instead of finishing the local debugging.
**Source:** 253-181-SUMMARY.md;253-182-SUMMARY.md;253-183-EXECUTION-ROUTING.json; user's recovery instruction.

## Lessons

### Plan counts became part of the bug

The operative contract moved through174/22,177/23,180/24,181/25 and183/27 plan/halt counts. Renderers, consumers, ownership tables and fixtures repeated these values. Adding a repair plan therefore changed the thing being repaired.

**Context:**175 accepted stale executable counts and failed owners;181's negative control replaced a24 anchor in a25 fixture and changed no bytes;183 retained an181 error expectation after implementing183.
**Source:** 253-175-SUMMARY.md;253-181-SUMMARY.md;253-183-EXECUTION-RECORD.json.

### Fixture construction needs the same care as validation

A valid synthetic fixture must reach the intended check. It must also state which facts are hypothetical. A receipt fixture that deliberately creates a simulated receipt cannot assert that the same file is absent. A routing fixture copied after183 halted cannot assume that183 has no summary.

**Context:** Maintenance exposed both errors after the original label mismatch was corrected. Fixing these fixture errors is development work, not evidence that actual183 or179 succeeded.
**Source:** 253-RECOVERY-SUCCESSOR.test.py;253-MAINTENANCE-RESULT.json and its preserved targeted-01 output.

### Required failure signals must be captured when they occur

Preserve stdout/stderr and source identity directly. A later replay or reconstructed transcript cannot recover the original invocation. The183 captures fixed this omission for183 only;182 remains incomplete evidence.

**Context:**182 edited before its required baseline and retained reconstructed output.183 captured the real baseline and the subsequent failures.
**Source:** 253-182-SUMMARY.md;253-183-EXECUTION-RECORD.json.

### Do not make the checker reject its own permitted workflow

A test-only edit may legitimately precede a source commit. Validate its captured bytes against a durable retained path/blob; do not invent an earlier producing commit. Root identity and individual tool invocation identity are different values and should be checked separately.

**Context:**183's review required every snapshot to equalHEAD and every owner string to be identical, although its capture process permitted test-only edits and recorded invocation suffixes.
**Source:** 253-183-EXECUTION-RECORD.json findings183-SOURCE-01/02;maintenance regression test.

### A stop rule should stop acceptance, not force new paperwork for a typo

Keep a stopped acceptance attempt stopped. Within separately authorized development, diagnose a local failure, make a scoped correction, and rerun meaningful tests. Another repair plan is not a technical remedy for wrong error text or an invalid fixture.

**Context:**181,182 and183 all stopped around local test/checker defects; their requirements stayed open while the next plan expanded the machinery.
**Source:** 253-181-SUMMARY.md;253-182-SUMMARY.md;253-183-SUMMARY.md;user's recovery instruction.

## Patterns

### Changed bytes, intended refusal, restored positive

For a negative control: prove a unique mutation anchor, changed bytes/hash, the intended refusal, restoration in finally, and a valid case before and after. An unchanged fixture or unrelated early rejection proves nothing about the intended rule.

**When to use:** Mutation tests and required-gate failure injection.
**Source:** 253-181-SUMMARY.md;253-183-PLAN.md Task1 and direct passing runs.

### One retained maintenance result

Use ordinary test commands with directly saved output. Keep a compact current result pointing to the raw outputs in Git. Avoid copying the same entire captured ledger into every state file. A focused failed run is diagnostic; successful focused tests do not replace the relevant full suite.

**When to use:** Local repairs after a historical attempt has stopped.
**Source:** 253-183-EXECUTION-RECORD.json;current253-MAINTENANCE-RESULT.json.

### Separate historical truth from current authority

Old failures stay immutable. Synthetic copies are labeled and cannot modify actual receipts or summaries. A current development pass can repair source, but it cannot grant an acceptance permission that the old attempt did not earn.

**When to use:** Recovery tools, test fixtures, and handoffs after partial execution.
**Source:** 253-178-SUMMARY.md;253-183-SUMMARY.md;253-CONTEXT.md D-01/D-18/D-24.

## Surprises

### More tests did not guarantee a valid contract

175's14 passing tests still accepted stale executable instructions.183's new positive tests could not initially reach the validator because a historical-log check failed first.

**Impact:** Use an independent valid fixture and a negative case that proves the intended condition, then inspect what the checks actually cover.
**Source:** 253-175-SUMMARY.md;253-183-EXECUTION-RECORD.json.

### The first183 diagnosis was itself imprecise

The defect was not just uppercase versus lowercase: the code lowercased the log, then searched for the different phrase `transcript reconstruction`. The actual header begins `RECONSTRUCTED FROM TOOL TRANSCRIPT`. Maintenance checks the real retained header and leaves the old diagnosis unchanged as history.

**Impact:** Diagnose from the actual code and raw output, not from the previous summary's shorthand.
**Source:** 253-RECOVERY-SUCCESSOR.py historical transcript check;253-182-TASK1-FAILED-01.log;253-183-SUMMARY.md.
