---
phase: 217-adversarial-panel-auto-fix-safety-rails
plan: "01"
subsystem: panel-seams
tags: [panel, anchor, finding-id, schema, tdd]
requires: []
provides: [anchor.mjs, panel-schema.mjs, devdeps]
affects: [scripts/ci/evidence-anchor-check.mjs, scripts/ci/lib/, scripts/panel/]
tech_stack:
  added:
    - "@anthropic-ai/sdk (devDep, Playwright subproject)"
    - "zod (devDep, Playwright subproject, SDK-native path)"
  patterns:
    - "TDD RED/GREEN for shared module extraction"
    - "NUL-delimited sha256 finding_id (byte-identical to 216 formula)"
    - "D-08 anchor canonicalization (quote-style + whitespace) before hashing"
key_files:
  created:
    - scripts/ci/lib/anchor.mjs
    - scripts/ci/lib/anchor.test.mjs
    - scripts/panel/panel-schema.mjs
    - scripts/panel/panel-schema.test.mjs
  modified:
    - scripts/ci/evidence-anchor-check.mjs
    - test/example/priv/playwright/package.json
    - test/example/priv/playwright/package-lock.json
decisions:
  - "Use zod (SDK-native @anthropic-ai/sdk/helpers/zod) over ajv — reduces friction in judge.mjs"
  - "findingId applies D-08 canonicalization (single→double quotes, whitespace trim) before hashing"
  - "PANEL_SCHEMA uses anyOf[finding-cell, keep-cell] to enforce forced-floor at schema level"
  - "Extraction is a pure move — zero logic changes to isStructuralAnchor (byte-behavior preserved)"
metrics:
  duration: "6m 14s"
  completed: "2026-07-04T17:56:01Z"
  tasks_completed: 4
  files_created: 4
  files_modified: 3
status: complete
---

# Phase 217 Plan 01: Shared Anchor Module + Panel Schema Seams Summary

Shared anchor module extracted into `scripts/ci/lib/anchor.mjs`; byte-identical `findingId` helper authored in `scripts/panel/panel-schema.mjs`; `@anthropic-ai/sdk` and `zod` installed as Playwright devDependencies after operator legitimacy gate approval.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| T1 (gate, approved) | Package legitimacy gate | — | (human verify, no commit) |
| T2 | Install @anthropic-ai/sdk + zod devDeps | cffaea95 | package.json, package-lock.json |
| T3 RED | anchor.test.mjs failing tests | cbbdc3ae | scripts/ci/lib/anchor.test.mjs |
| T3 GREEN | Extract isStructuralAnchor into lib/anchor.mjs | 5da96337 | scripts/ci/lib/anchor.mjs, evidence-anchor-check.mjs |
| T4 RED | panel-schema.test.mjs failing tests | ebe41883 | scripts/panel/panel-schema.test.mjs |
| T4 GREEN | Author panel-schema.mjs findingId + PANEL_SCHEMA | 1a7b029f | scripts/panel/panel-schema.mjs |

## Verification Results

All plan verification criteria pass:

- `node scripts/ci/lib/anchor.test.mjs` — 29/29 PASS
- `node scripts/ci/evidence-anchor-check.test.mjs` — 15/15 PASS (byte-behavior preserved)
- `node scripts/panel/panel-schema.test.mjs` — 12/12 PASS (finding_id byte-identity proven)
- Both devDeps resolve via `require()` from the Playwright subproject
- `git status` shows no change under `priv/templates/sigra.install/` (golden_diff_test unaffected)

## Key Design Decisions

**1. Zod over ajv**
The plan recommended zod for the SDK-native `@anthropic-ai/sdk/helpers/zod` path. Chosen as approved by operator. `client.messages.parse()` with `zodOutputFormat` auto-strips unsupported schema constraints client-side, aligning with D-03.

**2. Pure extraction — no logic changes**
`isStructuralAnchor` and `GEOMETRY_ONLY_CLASSES` moved byte-for-byte from `evidence-anchor-check.mjs` into `scripts/ci/lib/anchor.mjs`. The pre-existing edge case (all-lowercase prose like "the header looks off" passes the structural check) is preserved intentionally — this is the documented behavior, not a bug in scope here.

**3. findingId canonicalization (D-08)**
`canonicalizeAnchor()` normalizes single-quoted CSS attribute selectors to double-quoted form and trims whitespace before hashing. The canonical form is then hashed byte-identically to Phase 216's formula, so panel finding_ids, settled-findings.tsv waivers, and the fix queue share the same key space.

**4. PANEL_SCHEMA forced-floor via anyOf**
Each of the 12 cells uses `anyOf[finding-cell, keep-cell]` to structurally enforce the forced-floor at schema level (D-06): either a `verdict != keep` finding with `anchor` + `refutation`, or `verdict == keep` with `none_searched_for`. No `minimum`/`maximum`/`minLength`/`maxLength`/`multipleOf` present anywhere (D-03 schema-constraint limits verified by test).

## Deviations from Plan

None — plan executed exactly as written. The legitimacy gate was resolved by the operator before this agent started; Task 1 commit is omitted (gate is approval-only, no code change).

## Known Stubs

None. All exports are fully implemented and self-tested.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced by this plan. The `@anthropic-ai/sdk` devDep is installed in the Playwright subproject (never shipped to host apps). `ANTHROPIC_API_KEY` is not read or referenced by any code in this plan.

## Self-Check: PASSED

All created files confirmed on disk. All commits verified in git log.

| Check | Result |
|-------|--------|
| scripts/ci/lib/anchor.mjs | FOUND |
| scripts/ci/lib/anchor.test.mjs | FOUND |
| scripts/panel/panel-schema.mjs | FOUND |
| scripts/panel/panel-schema.test.mjs | FOUND |
| commit cffaea95 (devDeps) | FOUND |
| commit cbbdc3ae (anchor RED) | FOUND |
| commit 5da96337 (anchor GREEN) | FOUND |
| commit ebe41883 (panel-schema RED) | FOUND |
| commit 1a7b029f (panel-schema GREEN) | FOUND |
