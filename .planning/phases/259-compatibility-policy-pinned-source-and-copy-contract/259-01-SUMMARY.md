---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 01
subsystem: docs
tags: [compatibility-policy, adr, semver, brand-adoption, doc-contract-test]

requires:
  - phase: none
    provides: first phase of v1.51 (brand identity adoption)
provides:
  - ADR 005 with the frozen list, add-only list, ownership lanes, surface map, seven recorded decisions and the owner-decision table
  - guides/reference/brand-compatibility.md (public reference guide, not an ExDoc extra) with the consumed-subset table and the upgrade-note skeleton
  - A "Brand and visual compatibility" section in guides/introduction/contract.md
  - test/sigra/brand/policy_docs_test.exs doc-contract test (headings and key terms only, with planted-content controls)
affects: [259-02, 259-04, 259-05, 259-06, 259-08, 259-09, 259-11, 260, 261, 262, 263]

actuals:
  tokens: 8960
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Doc-contract ExUnit: pure missing_terms/2 and section_slice/2 helpers with a planted-removal control against the real file"
    - "Policy prose states names and lanes; the machine-readable baseline lives in a fixture owned by the ratchet plan"

key-files:
  created:
    - .planning/decisions/005-brand-adoption-compatibility-policy.md
    - guides/reference/brand-compatibility.md
    - test/sigra/brand/policy_docs_test.exs
  modified:
    - guides/introduction/contract.md

key-decisions:
  - "Every decision except #12 is recorded as 'Recommended default - owner confirmation pending'; #12 is confirmed 2026-11-13"
  - "v1.51 ships as a minor release: feat/fix/docs only, no bang marker, no BREAKING footer, nothing hand-added under CHANGELOG Unreleased"
  - "Pin the whole tracked brand/ tree (72 files); the consumed subset is a documented table, not a prune"
  - "Install-pin shape is enforced now; the three-segment value bump belongs to Phase 263 (a two-segment requirement still resolves to the retired stray 1.20.0)"
  - "Frozen counts re-measured 2026-11-13: 100 --sg-*, 35 --sigra-auth-*, 112 sg-* selectors, 66 sigra-auth selectors, 25 Profile keys, 33 config keys / 170 paths, 73 route-DSL lines (54 route + 19 scope), 54 ~p helpers, 344 dgettext calls / 180 msgids, 25 data-testids"

patterns-established:
  - "Surface map carries an explicit Brand owner column with exactly Sigra or host per row, asserted by test in both the ADR and the guide"
  - "Upgrade-note skeleton lives inside brand-compatibility.md; no upgrading-to-* file is created and no permanent assertion forbids Phase 263 from adding one"

requirements-completed: [BPOL-01, BPOL-05, BPOL-07]

coverage:
  - id: D1
    description: "ADR 005 records the frozen list, add-only list, ownership lanes, surface map and the seven decisions, with decisions other than #12 marked as awaiting owner confirmation"
    requirement: "BPOL-01, BPOL-05"
    verification:
      - kind: unit
        ref: "test/sigra/brand/policy_docs_test.exs#ADR 005"
        status: pass
    human_judgment: false
  - id: D2
    description: "Public guide brand-compatibility.md with lists, lanes, surface map, consumed-subset table, SemVer treatment and the upgrade-note skeleton"
    requirement: "BPOL-01, BPOL-07"
    verification:
      - kind: unit
        ref: "test/sigra/brand/policy_docs_test.exs#brand-compatibility guide"
        status: pass
    human_judgment: false
  - id: D3
    description: "contract.md carries the compact brand section after SemVer And Deprecation Policy, original H1 unchanged, reference guide pointed at by backticked path"
    requirement: "BPOL-01"
    verification:
      - kind: unit
        ref: "test/sigra/brand/policy_docs_test.exs#contract.md brand section"
        status: pass
    human_judgment: false
  - id: D4
    description: "The recommended-default decisions themselves (SemVer level, msgid policy, PNG-lane park, pin whole tree) are the owner's call"
    verification: []
    human_judgment: true
    rationale: "Policy choices awaiting owner confirmation; a test can only prove they are recorded and labelled, not that they are the right decisions"

duration: 6min
completed: 2026-11-14
plan_head_before: 73c16d5a447c9615973e79feb97696caaa6d789d
plan_head_after: aa8c64c5bec976a889d4057ade4763f24f38799f
commits: 3
status: complete
---

# Phase 259 Plan 01: Compatibility policy Summary

**ADR 005, a public brand-compatibility guide and a contract.md section that state the frozen and add-only surfaces, the three ownership lanes and who owns each surface's identity, with one doc-contract test that fails when a decision or heading goes missing.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-11-14T15:32:33Z
- **Completed:** 2026-11-14T15:38:09Z
- **Tasks:** 3
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments

- ADR 005 (`.planning/decisions/005-brand-adoption-compatibility-policy.md`) records the owner-decision table (#1-#9, #11, #12, #14), the frozen list with counts re-measured on 2026-11-13, the add-only list, the lane table, a nine-row surface map with a Brand owner column, the seven recorded decisions each with a reversibility line, and the Hex install-pin facts verified on 2026-11-13.
- `guides/reference/brand-compatibility.md` repeats the lists and lanes for adopters, adds the consumed-brand-subset table (manifest pins the whole tracked tree), the SemVer and changelog treatment, and a five-step upgrade-note skeleton with an empty "Visual and copy changes" table. It is not an ExDoc extra.
- `guides/introduction/contract.md` gained a compact "Brand and visual compatibility" section between "SemVer And Deprecation Policy" and "Security Invariants"; the H1 and every other heading are unchanged, so `doc/llms.txt` and `mix.exs` stay byte-identical.
- `test/sigra/brand/policy_docs_test.exs` (16 tests) asserts headings and key terms only, the decision-12 confirmed label versus eleven pending rows, the Sigra-or-host owner value on every surface row in both documents, the contract section's position, and three planted-content controls proving the helpers can go red.

## Task Commits

1. **Task 1: ADR 005 and its doc-contract test (tracer)** - `cbd51ea7f` (docs)
2. **Task 2: brand-compatibility reference guide** - `0d52ee77d` (docs)
3. **Task 3: contract.md section** - `aa8c64c5b` (docs)

The tracer gate ran after Task 1: workflow auto mode was off and `human_verify_mode` was end-of-phase with an automated-only verify, so the tracer verify was re-run (7 tests, 0 failures) and expansion continued with no checkpoint.

**Plan metadata:** recorded in the follow-up `docs(259-01)` commit (SUMMARY, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `.planning/decisions/005-brand-adoption-compatibility-policy.md` - ADR: decisions, lists, lanes, surface map, install-pin note
- `guides/reference/brand-compatibility.md` - public reference guide with consumed-subset table and upgrade-note skeleton
- `guides/introduction/contract.md` - new compact H2 section
- `test/sigra/brand/policy_docs_test.exs` - doc-contract test (headings and key terms, planted controls)

## Decisions Made

- Recorded exactly as the plan specifies; the only judgment calls were wording. The Frozen list states route counts as 73 route-DSL lines (54 route lines plus 19 scope lines) because that is what a direct count of the golden router gives; the research document's "about 50" was an estimate.
- The guide's surface-map third column names public decision sources (the brand book, `Sigra.Branding`) rather than phase numbers, since the guide is adopter-facing; the ADR keeps the phase references.
- The empty "Visual and copy changes" table is a deliberate skeleton (BPOL-07), filled by the phases that change visible output; no entry was added to the cross-phase defect ledger because an open entry would block shipping for an intentionally empty table.

## Deviations from Plan

None - plan executed exactly as written.

Three small wording fixes made inside the tasks before commit, none a deviation from the plan's requirements: the ADR said "real-login" (changed to "real sign-in") and the guide said "self-hosted" (changed to "served from local files") so neither file contains a word that the later lexicon scan treats as banned.

**Total deviations:** 0.

## Issues Encountered

None. `tmp/db.env` was absent at start; the task precondition's documented remedy `scripts/db/up.sh` booted an ephemeral Postgres on a dynamic port, after which every verify command ran.

## Known Stubs

- `guides/reference/brand-compatibility.md`, "### 5. Visual and copy changes": the table has a header and no rows. Intentional (BPOL-07 skeleton); Phases 261-263 add one row per shipped change.
- ADR 005 Decision 4 and the guide's msgid rename table are described as "header and no rows"; Phase 262 appends rows. The table itself is created by the phase that renames a string.

## Verification Results

- `mix test test/sigra/brand test/sigra/architecture_guides_contract_test.exs`: 26 tests, 0 failures.
- Zero shipped bytes: `git diff --stat aeda7273d -- lib priv brandbook brand .github scripts` empty, untracked status empty, with the planning diff and tracked-tree sample as positive controls.
- Privacy gate (phase directory excluded): no home-path shape, no personal-name word match; planted control matched.
- `mix format --check-formatted`: clean.
- Guide gate: no `upgrading-to-*` file added or changed under `guides/`; `mix.exs` and `doc/llms.txt` diff-stat empty.
- Task acceptance greps: 11 "owner confirmation pending" lines, decision-12 row confirmed 2026-11-13, 9 owner cells, no `cleared`/trademark wording, no lexicon words, no literal dependency tuple, contract H1 unchanged, new H2 exactly once.

## Threat Flags

None. Docs and a doc-contract test only; no new network, auth, file-access or schema surface.

## Next Phase Readiness

Plans 259-02 through 259-13 can cite ADR 005 for the lists and decisions. Plan 259-05 owns `test/fixtures/brand/frozen-surface.json`, the machine-readable counterpart to the ADR's frozen list. Plan 259-04 can scan README and guides for dependency tuples: this plan wrote none.

## Self-Check: PASSED

- FOUND: `.planning/decisions/005-brand-adoption-compatibility-policy.md`, `guides/reference/brand-compatibility.md`, `guides/introduction/contract.md`, `test/sigra/brand/policy_docs_test.exs`
- FOUND commits: `cbd51ea7f`, `0d52ee77d`, `aa8c64c5b`
