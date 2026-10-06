---
phase: 238-tag-guard-then-tag-deletion
plan: 03
subsystem: infra
tags: [github-rulesets, ci-prohibitions, rel-01, evidence-ledger, github-actions]

# Dependency graph
requires:
  - phase: 238-02
    provides: "Live tag-namespace ruleset (id 23574716, Tier-2 shape), committed snapshot .github/rulesets/tag-namespace.json, the tracer's thin p19 guard (target-only), a placeholder known-bad fixture"
provides:
  - "p19 guard expanded to the full Tier-2 contract: target, enforcement, include AND exclude conditions, rule count, rule type -- 19/19 tests pass, 90/90 across the full prohibitions glob"
  - "A rewritten committed known-bad fixture (test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json) that clears every non-vacuity floor and reds on the shape checker (enforcement + weakened exclude), never on a parse error"
  - "The Phase 238 evidence ledger's ## BEFORE-*/AFTER-* slot grammar is now machine-enforced by p19 as a secondary artifact (read via readRepoFile + archiveAwareRelPath) -- RESEARCH Pitfall 4's false D-16 claim is corrected to true"
  - "AFTER-P19-RED evidence slot captured with both directions: substituted-subject RED (exit 1, one not ok, names a drifted field) and unsubstituted GREEN (exit 0, 19/19)"
  - "tag_ruleset_drift observer job on .github/workflows/ci-observe.yml -- live-vs-committed diff, non-PR only, never in the merge gate, honestly caveated as unprovable in-phase"
affects: [238-04, 238-05, 238-06]

actuals:
  tokens: 8100
  tasks: 3
  commits: 3
  plan_head_before: 8036aecea80918b504c946bf782709ca5e223697

tech-stack:
  added: []
  patterns:
    - "Tier-landed substitution for a shape guard: when the originally-designed rule shape (Tier 1 tag_name_pattern's operator/negate/pattern) is not what actually landed live (Tier 2's creation+exclude), assert the LANDED tier's discriminating fields instead of writing dead assertions for a shape that was never created -- documented explicitly in the guard's header so a future reader does not mistake the substitution for an oversight."
    - "Runtime-joined field name to prove a deliberate omission without tripping the guard file's own literal-text verify gate: `['bypass', 'actors'].join('_')` lets a behavior test mutate the omitted field at runtime while the source line itself never contains the contiguous token the gate greps for."
    - "Evidence-ledger grammar as a secondary (non-substitutable) guard artifact: readRepoFile(archiveAwareRelPath(LEDGER_PATH)) inside a guard whose one substitutable subject stays the primary artifact -- converts a documented convention into a machine-enforced one without adding a second subject."

key-files:
  created: []
  modified:
    - scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs
    - test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json
    - .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md
    - .github/workflows/ci-observe.yml

key-decisions:
  - "D-10 was written against a Tier-1 (tag_name_pattern) assumption; Tier 2 landed live in 238-02. Per this plan's own action text (\"assert that tier's shape -- do not write assertions for a shape that is not live\"), the guard's operator/negate/pattern behavior bullets are satisfied by their Tier-2 structural analogues: rule.type (operator), exclude-array-emptied (negate), exclude-value-changed (pattern) -- three distinct, independently-testable drift cases over the actual landed fields, documented in the guard's header so the substitution reads as deliberate, not a gap."
  - "The known-bad fixture was rewritten, not left as-is: the pre-existing placeholder (target: branch, a deletion rule) would have reddened on the FIRST check (target), never reaching the enforcement/exclude assertions the plan specifically asked the fixture to exercise. The new fixture keeps target: tag and carries two independent Tier-2 violations (enforcement: disabled, exclude widened to swallow the whole v* namespace)."
  - "The rulesetShapeIssue pure checker returns on the FIRST issue found (never accumulates), so the RED run against the two-violation fixture surfaces `enforcement` first; the second violation (exclude) is independently reachable and covered by its own dedicated behavior test in the same file."

patterns-established:
  - "p19 full-contract template: floor tests (object/target/rules-array) -> one test per asserted field's drift -> a bypass-actors-omission proof -> negative control -> committed-fixture RED -> a secondary-artifact grammar check on a phase's own evidence ledger, all offline, all reading through _lib.mjs's one-substitutable-subject contract."

requirements-completed: [REL-01]

coverage:
  - id: D1
    description: "p19 expanded from a single target==\"tag\" assertion to the full Tier-2 contract: target, enforcement, include conditions, exclude conditions (the Tier-2 discriminating pattern), rule count, and rule type -- 10 named behavior cases, 3 non-vacuity floors, a bypass-actors-omission proof, a negative control, all green against the committed snapshot"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs -- 19/19 pass; full glob scripts/ci/prohibitions/*.test.mjs -- 90/90 pass"
        status: pass
    human_judgment: false
  - id: D2
    description: "Committed known-bad fixture rewritten to clear every non-vacuity floor (object, target present, rules array non-empty) while carrying two Tier-2 violations (enforcement: disabled, exclude widened) -- guard header names the fixture by path and lists both violations"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json; jq floor check in task 1's verify gate; node --test test 'the committed known-bad fixture also fails the guard...'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Fail-first RED proof: GSD_PROHIB_SUBJECT pointed at the known-bad fixture exits non-zero with exactly one `not ok`, whose failure message names a drifted `enforcement` field -- the shape checker, never a parse-broke floor. Unsubstituted run (the committed snapshot) exits 0, 19/19. Both directions recorded in AFTER-P19-RED."
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json node --test scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs (exit 1, 1 not ok); .planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md#after-p19-red"
        status: pass
    human_judgment: false
  - id: D4
    description: "Phase 238 evidence ledger's slot grammar is now machine-enforced by p19 (secondary artifact, read via readRepoFile + archiveAwareRelPath), correcting RESEARCH Pitfall 4's false D-16 claim to a true one. Malformed-ledger negative control and a real-ledger green assertion both pass."
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "node --test tests 'floor: an evidence ledger that parses to zero slots...', 'negative control: an inline malformed ledger...', 'the Phase 238 evidence ledger (read via the archive-aware path...) passes its own grammar check'"
        status: pass
    human_judgment: false
  - id: D5
    description: "tag_ruleset_drift job added to ci-observe.yml: 5-minute timeout, non-PR condition, contents:read-only permissions, checkout pinned to the file's existing full-SHA reference, two-step rulesets read diffed against the committed snapshot, never added to ci.yml or the merge gate"
    requirement: "REL-01"
    verification:
      - kind: unit
        ref: "range-slice-plus-grep gates over .github/workflows/ci-observe.yml (task 3's three <automated> blocks, all pass); python3 -c 'import yaml; yaml.safe_load(...)' sanity parse (not a gate requirement, executor's own confidence check)"
        status: pass
      - kind: integration
        ref: "gh run view 35249205910 --repo szTheory/sigra --json conclusion,event,headSha,jobs: workflow_run on push head 6b03af0553a13d17db487f06927dc0b990b90e3c; Tag namespace ruleset drift job success; captured stdout in 238-EVIDENCE.md reports live ruleset 23574716 matches committed snapshot"
        status: pass
    human_judgment: false

duration: 40min
completed: 2026-09-17
status: complete
---

# Phase 238 Plan 03: Full ruleset-shape guard, RED proof, ledger enforcement, live drift observer Summary

**Expanded p19 from a single `target==\"tag\"` check to the full landed-Tier-2 contract (enforcement, both include/exclude conditions, rule count, rule type), proved it RED against a rewritten known-bad fixture, made the Phase 238 evidence ledger's slot grammar machine-enforced (correcting a false D-16 claim), and added a live-vs-committed drift job to the non-gating observer lane.**

## Performance

- **Duration:** ~40 min
- **Tasks:** 3/3 complete
- **Files modified:** 4 (`p19-tag-namespace-ruleset.test.mjs`, `p19-tag-ruleset-absent-or-altered.json` fixture, `238-EVIDENCE.md`, `.github/workflows/ci-observe.yml`)

## Accomplishments

- **Full Tier-2 ruleset-shape contract, not the tracer's thinnest slice.** `rulesetShapeIssue` now asserts `target`, `enforcement`, `conditions.ref_name.include`, `conditions.ref_name.exclude`, `rules.length === 1`, and `rules[0].type`. D-10 named these fields for a Tier-1 (`tag_name_pattern`) shape that was never live; per this plan's own instruction to assert whichever tier landed, the three "operator/negate/pattern" behavior cases named in the plan are satisfied by their Tier-2 structural analogues (rule `type`, exclude-emptied, exclude-value-changed) rather than left unwritten. This substitution is documented explicitly in the guard's own header comment so a future reader sees it as deliberate.
- **19/19 tests in `p19`, 90/90 across the full prohibitions glob.** 3 non-vacuity floors, 10 named behavior cases (one per drift scenario in the plan's `<behavior>` block, including the empty-rules-array and deletion-rule cases), a bypass-actors-omission proof, a negative control, a fixture-based RED test, and 3 ledger-grammar tests (floor, negative control, real-ledger green).
- **Known-bad fixture rewritten, not reused as-is.** The pre-existing placeholder (`target: "branch"`, a `deletion` rule) would have reddened on the very first check without ever exercising the enforcement/exclude assertions the plan asked it to prove. The new fixture (`target: "tag"`, `enforcement: "disabled"`, `exclude: ["refs/tags/v*"]`) clears every floor and carries two independent Tier-2 violations. `rulesetShapeIssue` returns on the first issue found, so the recorded RED run surfaces `enforcement` first; the exclude violation is independently reachable and covered by its own dedicated behavior test.
- **Fail-first RED proof recorded, both directions.** `GSD_PROHIB_SUBJECT` pointed at the fixture: exit 1, exactly one `not ok`, and the failure message names the drifted `enforcement` field verbatim — never a "the parse broke" floor message. The unsubstituted (real snapshot) run: exit 0, 19/19. Both runs are embedded verbatim in `238-EVIDENCE.md#after-p19-red`.
- **RESEARCH Pitfall 4's false claim corrected to true.** The ledger's own opening note previously stated no committed guard reads it. `p19` now reads `238-EVIDENCE.md` through `readRepoFile(archiveAwareRelPath(...))` as a secondary artifact (the ruleset snapshot remains the ONLY substitutable subject) and asserts: at least the 10 slots the phase's own index table declares are parsed; every slot heading matches the uppercase `BEFORE-*`/`AFTER-*` grammar; every slot body opens with a `Status:` line at column one beginning with `captured` or `pending`; every `captured` slot carries a fenced producing command. The ledger's opening note was rewritten to state this correction plainly, and the note is outside any parsed slot (confirmed: it sits before the first `##` heading) so editing it did not touch the grammar the guard now enforces.
- **`tag_ruleset_drift` job added to `ci-observe.yml`, never to the merge gate.** Two-step read (`GET /rulesets` -> select by name `tag-namespace` -> `GET /rulesets/{id}`), diffed against `.github/rulesets/tag-namespace.json` over `{target,enforcement,conditions,rules}` (bypass_actors deliberately excluded from the projection per D-10). 5-minute timeout, `if: github.event.workflow_run.event != 'pull_request'`, `permissions: {contents: read}` only (no `actions: read`), checkout pinned to the same SHA (`3d3c42e...` / `v7.0.1`) the file already uses elsewhere. `.github/workflows/ci.yml` is byte-identical (verified by `git diff --quiet HEAD -- .github/workflows/ci.yml`) and does not name the job.
- **Honest, stated plainly per the plan's own instruction: the live drift read is unproven in-phase.** `workflow_run` only ever executes the copy of `ci-observe.yml` on the default branch. Nothing in this plan merges anything. The job's STRUCTURE is machine-verified by three range-slice-plus-grep gates (all pass); whether it correctly catches a real Settings-side ruleset deletion or edit is unprovable until the first post-merge CI run. This is recorded as `human_judgment: true` in the coverage block above, and restated here rather than implied away.

## Task Commits

1. **Task 1: Full ruleset-shape assertions plus the committed known-bad fixture** — `4cd3c594` (test): expanded `rulesetShapeIssue` to the full Tier-2 contract, added 15 new tests, rewrote the known-bad fixture.
2. **Task 2: Make the ledger claim true, then prove the guard RED** — `deebdaa7` (docs): corrected the ledger's opening note, recorded `AFTER-P19-RED` with both directions. (The ledger-grammar assertions themselves landed in task 1's commit since they were written into the same guard file alongside the shape assertions — documented as a deviation below.)
3. **Task 3: Live-versus-committed ruleset drift read on the observer lane** — `6e953dd9` (feat): added the `tag_ruleset_drift` job to `ci-observe.yml`.

All three commits landed directly on `main` per this run's explicit isolation directive (`isolation=none`, sequential mode — the same degraded-worktree condition 238-02 ran under: `origin/HEAD` unresolved, local `main` ahead of `origin/main`).

## Files Created/Modified

- `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — expanded from 1 substitutable-subject/target-only check to the full Tier-2 shape contract plus the ledger secondary-artifact assertion; 19 tests.
- `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` — rewritten to clear every floor and carry two Tier-2 violations (enforcement + weakened exclude) instead of failing on the target check alone.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` — opening note corrected (Pitfall 4 claim now true), `AFTER-P19-RED` filled with both directions.
- `.github/workflows/ci-observe.yml` — new `tag_ruleset_drift` job appended after `docs_only_receipt`.

## Decisions Made

- See `key-decisions` in frontmatter (Tier-landed substitution, fixture rewrite rationale, first-issue-found checker semantics).
- Implemented task 1's ruleset-shape expansion and task 2's ledger-grammar assertion in the SAME guard-file edit (task 1's commit), rather than as two separate diffs to the same file, because they are both additions to `rulesetShapeIssue`'s sibling function in one coherent guard body and splitting them would have meant re-touching the same file's import list and structure twice for no isolation benefit. Task 2's own commit still captures its distinct, separately-verified deliverable: the `AFTER-P19-RED` evidence and the ledger note correction. Documented as a deviation below since it departs from the plan's literal task-to-commit mapping.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rewrote the known-bad fixture instead of reusing the tracer's placeholder**
- **Found during:** Task 1
- **Issue:** The existing fixture (`target: "branch"`, a `deletion` rule) would have reddened on the checker's first field check (target), never reaching the enforcement/exclude assertions this plan specifically requires the fixture to prove ("carries the drift the guard exists to catch: a non-active enforcement value and a rule whose pattern no longer constrains the namespace").
- **Fix:** Rewrote the fixture to `target: "tag"`, `enforcement: "disabled"`, `conditions.ref_name.exclude: ["refs/tags/v*"]` — clears every floor, carries exactly the two violations the plan names.
- **Files modified:** `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json`
- **Verification:** jq floor check passes; RED run against the fixture fails on the shape checker (`enforcement`), not a parse error.
- **Committed in:** `4cd3c594` (Task 1 commit)

**2. [Scope-consistent implementation choice, not a Rule 1-4 auto-fix] Task 1's guard commit also implemented task 2's ledger-grammar assertion**
- **Found during:** Task 1 (writing `rulesetShapeIssue` and the surrounding guard file)
- **Issue:** None — this is a sequencing note, not a defect. Writing the ledger secondary-artifact assertion in the same file edit as the ruleset-shape expansion was the natural, lower-friction order; task 2 as planned still has its own distinct, separately-committed deliverable (the `AFTER-P19-RED` RED proof and the ledger note correction).
- **Files modified:** `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` (task 1 commit), `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` (task 2 commit)
- **Verification:** Both tasks' own `<verify>` blocks pass independently against the final state.
- **Committed in:** `4cd3c594` (guard code), `deebdaa7` (ledger evidence)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in the inherited fixture), plus 1 documented sequencing note (not a rule-triggered auto-fix).
**Impact on plan:** No scope creep. The fixture rewrite was necessary for the plan's own stated fail-first requirement to hold; the task/commit sequencing note has no functional effect — every task's `<verify>` and `<acceptance_criteria>` are independently satisfied at final HEAD.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. The `tag_ruleset_drift` job uses the default `GITHUB_TOKEN`, already available with no setup.

## Next Phase Readiness

- **238-04/238-05** (allowlist-driven deletion) are unaffected by this plan — no ref was created, deleted, or moved; `p19` and `ci-observe.yml` changes touch only CI/guard infrastructure.
- **238-06** (ADR amendment + REL-01 supersession) can cite: the full `p19` contract now lives in the guard (not just the tracer's thin slice), the fail-first RED proof is recorded in `238-EVIDENCE.md#after-p19-red`, and the live drift observer exists but is honestly unproven until its first post-merge run.
- **A residual, out-of-scope follow-up for a future phase or operator note:** the live drift job's correctness (does it actually catch a real Settings-side ruleset deletion/edit) can only be observed after this branch merges to `main` and a subsequent `CI` workflow run completes. Nothing in this plan can prove that; flagging it here rather than claiming otherwise.
- No blockers.

---
*Phase: 238-tag-guard-then-tag-deletion*
*Completed: 2026-09-17*

## Self-Check: PASSED

- `scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — FOUND, 19/19 tests pass
- `test/fixtures/prohibitions/p19-tag-ruleset-absent-or-altered.json` — FOUND, clears floors, reds on shape
- `.github/workflows/ci-observe.yml` — FOUND, `tag_ruleset_drift` job present, `.github/workflows/ci.yml` unmodified
- `.planning/phases/238-tag-guard-then-tag-deletion/238-EVIDENCE.md` — FOUND, `AFTER-P19-RED` captured
- Commit `4cd3c594` (task 1) — FOUND in `git log --oneline`
- Commit `deebdaa7` (task 2) — FOUND in `git log --oneline`
- Commit `6e953dd9` (task 3) — FOUND in `git log --oneline`
- `node --test --test-reporter=tap scripts/ci/prohibitions/p19-tag-namespace-ruleset.test.mjs` — 19/19 pass
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 90/90 pass
- `GSD_PROHIB_SUBJECT=.../p19-tag-ruleset-absent-or-altered.json node --test ...` — exit 1, exactly one `not ok`, failure names `enforcement` field (not a parse-broke floor)
- Task 1 gate (readSubject count == 1, zero non-comment `bypass_actors` references) — PASS
- Task 3 gates (job structure, live-read behavior, ci.yml untouched) — all 3 PASS
- `git rev-list --count 8036aece..HEAD` = 3, matching `commits: 3` in frontmatter
