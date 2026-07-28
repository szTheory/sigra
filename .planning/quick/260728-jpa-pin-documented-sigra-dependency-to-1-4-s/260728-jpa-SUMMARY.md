---
phase: quick-260728-jpa
plan: 01
subsystem: docs
tags: [docs, hex, dependency-pin, adopter-experience]
status: complete

requires:
  - "Hex stray release 1.20.0 remains unretired (ADR 003, pending retire todo)"
provides:
  - "Documented Sigra dependency requirement that provably excludes Hex 1.20.0"
affects:
  - README.md
  - guides/introduction/
  - guides/recipes/companion-libs/

tech-stack:
  added: []
  patterns:
    - "Three-segment `~> X.Y.Z` requirement used deliberately to terminate the admitted range below the next minor"

key-files:
  created: []
  modified:
    - README.md
    - guides/introduction/installation.md
    - guides/introduction/getting-started.md
    - guides/introduction/first-hour.md
    - guides/recipes/companion-libs/lockspire.md
    - guides/recipes/companion-libs/threadline.md
    - guides/recipes/companion-libs/rulestead.md
    - guides/recipes/companion-libs/mailglass.md
    - guides/recipes/companion-libs/relyra.md
    - guides/recipes/companion-libs/accrue.md

decisions:
  - "Documented requirement is the three-segment `~> 1.4.0`, not `~> 1.4` — the two-segment form still admits the stray 1.20.0 and would look fixed while changing nothing."
  - "The explanatory note lives in exactly one file (guides/introduction/installation.md); README and the companion-lib recipes carry the corrected requirement with no commentary."
  - "The README sentence directing readers to treat Hex as the current package truth was deleted, not softened — left in place it re-authorizes resolution to the stray."

metrics:
  duration: "~10 min"
  completed: 2026-07-28
  tasks: 3
  files_modified: 10
  commits: 2
---

# Quick Task 260728-jpa: Pin Documented Sigra Dependency to `~> 1.4.0` Summary

Narrowed the documented `{:sigra, ...}` requirement across README.md and guides/ from the two-segment `~> 1.0` to the three-segment `~> 1.4.0`, so a copy-pasting adopter can no longer resolve the erroneous stray Hex release `1.20.0`.

## What Was Done

### Task 1 — Pin every documented install line (commit `2cff11fd`)

The live discovery grep returned **exactly the 11 hits across 10 files** the planner predicted — no discrepancy to record. All 11 were changed from `~> 1.0` to `~> 1.4.0`, version string only, with surrounding syntax (trailing commas, fence style, indentation, inline-prose backticks) preserved untouched. `rulestead.md` carried two occurrences in separate deps blocks; both were pinned.

No `~> 1.0` requirement belonging to another package (`telemetry_metrics`, `gettext`, `phoenix_live_view`, etc.) was touched — every edit was scoped to the literal `{:sigra, "~> 1.0"}` tuple.

Why three segments, restated for the record:

| requirement | 1.4.0 | 1.5.0 | 1.20.0 |
|-------------|-------|-------|--------|
| `~> 1.0`    | admits | admits | **admits** |
| `~> 1.4`    | admits | admits | **admits** |
| `~> 1.4.0`  | admits | no     | **no** |

Because Hex resolves to the highest satisfying version, `~> 1.4` would have resolved to `1.20.0` — the exact current broken behavior wearing a different string.

### Task 2 — Correct stale caveats, add the single explanatory note (commit `24759cc0`)

- **getting-started.md** and **first-hour.md**: deleted the obsolete "if you are reading `main` before Hex shows `1.0.0` … until the release PR lands" caveat. 1.0.0 shipped 2026-06-03 and 1.4.0 is current, so the sentence was simply false. Both bullets now read as the dependency requirement plus `mix deps.get`.
- **installation.md**: kept the Sigra 1.0 contract sentence verbatim, deleted the same caveat, and added the explanatory note as a new paragraph immediately after — factual, no retire date, no promise of a fix, no characterization of the situation as broken.
- **README.md**: deleted both leading sentences, including the one telling readers to treat Hex as the current package truth and pick a constraint appropriate for their target. That sentence pointed a reader straight back at `1.20.0` and would have made the pin self-defeating. The final Sigra 1.0 contract sentence was kept verbatim with its existing link text and target. No explanation was added to README.

The note now appears in **exactly one file** under README.md + guides/ (verified by `grep -rln`).

### Task 3 — Scope proof, tests, commit

**Scope proof:** `git diff --name-only cfc5e6b8..HEAD` filtered against `^(README\.md|guides/)` returns empty. Ten files changed, +18/−13, zero deletions. Nothing under `mix.exs`, `priv/`, `lib/`, `test/`, `CHANGELOG.md`, `.release-please-manifest.json`, or `test/example/mix.exs` was touched.

**Requirement sweep:** `grep -rn ':sigra, "~> 1\.0"' README.md guides/` returns nothing; the three-segment count is 11, matching the live occurrence count.

## Tests Run

A live test Postgres was reachable (`127.0.0.1:57326`, via `source tmp/db.env`), so the full listed set ran. **These six files ran, all passed — 39 tests, 0 failures:**

- `test/sigra/guides_dx02_test.exs`
- `test/sigra/architecture_guides_contract_test.exs`
- `test/sigra/recipes/companion_lib_contract_test.exs`
- `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs`
- `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs`
- `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs`

**No full-suite run was performed and none is claimed.** Only the six files above were executed.

As an extra guard I grepped the whole test tree for assertions on the documented requirement string (`grep -rn 'sigra, "~>' test/ scripts/`). Nothing in `test/` asserts on it, confirming the planner's expectation that these tests pass unchanged. The single hit outside `test/example/` is `scripts/ci/upgrade-smoke.test.sh:58`, a stub of `mix hex.info sigra` output that *deliberately* reproduces the live stray (`1.20.0` in its canned release list) to exercise the stray-exclusion resolver. It is out of scope and was correctly left alone — changing it would break the very test that guards against the stray.

## Deviations from Plan

**1. [Rule 1 - Bug] Task 2's automated gate expression was malformed; the underlying facts all passed**

- **Found during:** Task 2 verification
- **Issue:** The gate contained `[ "$(grep -rc 'erroneous \`1.20.0\`' guides/introduction/installation.md)" = "1" ]`. With `-r` supplied alongside an explicit path, GNU/BSD grep prefixes the filename, so the substitution yielded `guides/introduction/installation.md:1` rather than `1`, and the comparison failed. This was a defect in the check, not in the content.
- **Fix:** Ran each clause individually to confirm the facts, then re-ran the gate with `-c` instead of `-rc` on the single-file check. All four clauses pass: no `release PR lands` in the three intro guides, no `current package truth` in README, exactly 1 matching line in installation.md, exactly 1 matching file across README + guides.
- **Files modified:** none (verification-expression only)
- **Commit:** n/a

No other deviations. Tasks 1 and 3 executed exactly as written.

## Out-of-Scope Follow-Ups Observed (not fixed here)

Both were explicitly kept out of scope and are reported for separate filing:

1. **`guides/introduction/contract.md:9`** — states "The current published package truth before the release PR is `1.1.0`; the selected release path moves to real Hex `1.0.0`." Stale relative to 1.4.0. The whole "Version Axes" section is written from a pre-1.0.0 vantage point and needs a rewrite, not a one-line version bump.

2. **`guides/introduction/upgrading-to-v1.0.md:8`** — carries the same "treat Hex package metadata as the current package truth" framing that was removed from README in Task 2(d). Less acute here because the surrounding sentence scopes the guide to historical pre-1.0 cutover review, but it is the same steering pattern and would benefit from the same treatment.

Neither file contains a `{:sigra, "~> ..."}` install line, so neither weakens the pin directly — an adopter copy-pasting from any documented install block still gets `~> 1.4.0`.

## Known Stubs

None. No stubs, placeholders, skipped tests, or unrun verifications were introduced.

## Accepted Consequence

`~> 1.4.0` pins the documented line to 1.4.x patch releases, so the docs must be bumped when 1.5.0 ships. This is intentional and is the cost of routing around the stray without a retire. The installation.md note tells readers to raise the requirement when they move to a newer minor. The durable fix remains `mix hex.retire` of 1.20.0, still blocked by the Hex 2.5.1 OAuth-scope limitation (ADR 003, pending retire todo).

## Commits

| Commit | Message |
|--------|---------|
| `2cff11fd` | docs: pin documented sigra dependency to `~> 1.4.0` |
| `24759cc0` | docs: drop obsolete pre-1.0.0 caveats and explain the narrower requirement |

Both on branch `docs-pin-sigra-1-4`, based on `cfc5e6b8`. Nothing pushed, no PR opened, no tag created — the orchestrator owns the PR.

## Self-Check: PASSED

- All 10 modified files verified present on disk and in the committed diff.
- Both commit hashes verified present in `git log`.
- `grep -rn ':sigra, "~> 1\.0"' README.md guides/` → no results.
- `grep -rn ':sigra, "~> 1\.4\.0"' README.md guides/` → 11 results.
- `git diff --name-only cfc5e6b8..HEAD | grep -vE '^(README\.md|guides/)'` → empty.
- No file deletions in either commit.
