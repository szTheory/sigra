---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 05
subsystem: testing
tags: [brand, catalog, before-catalog, manifest, privacy-scan, immutable-baseline, generated-host, bgen-03]

requires:
  - phase: 260
    provides: "Plan 02 harness (Sigra.Test.Brand.Catalog) and plan 03 raw inputs (tier-2 pages, generated-host pages and emails)"
provides:
  - "test/fixtures/brand/before/: the committed, immutable before catalog (63 files) with MANIFEST.json pinning origin/main, the lib/priv/golden tree hashes and the shipped CSS and logo hashes"
  - "Catalog.privacy_violations_in/1: the privacy scan over a whole directory with its manifest, run over the writer's output and over the committed catalog"
  - "Cursor normalization rule ({{CURSOR}}) and seeded-persona listing in the manifest"
  - "260-deferred-items.md plan-05 section: owed pre-262 shipped-byte fixes with the re-capture rule, 56-class CSS gap, Pages-workflow note, SC-1 wording reconciliation"
affects: [260-08, 260-09, 260-11, 262]

actuals:
  tokens: 150830
  tasks: 3
  commits: 5

plan_head_before: 1f5d3e917ce85e66b3618628d74fdca5689141f2
plan_head_after: df035eed410cdd6b006b2f05621072e0c048e65e

tech-stack:
  added: []
  patterns:
    - "Write-once baseline guarded by refuse-to-overwrite (observed once) and a re-hash test that goes live the moment the manifest exists"
    - "Determinism proven by two independent captures at least 65 seconds apart plus two fresh generated hosts, compared with diff -ru"
    - "A normalizer rule is allowed only with a planted-input control seen red first"

key-files:
  created:
    - test/fixtures/brand/before/MANIFEST.json
    - test/fixtures/brand/before/tier1-library-admin
    - test/fixtures/brand/before/tier2-example-admin
    - test/fixtures/brand/before/generated-host-pages
    - test/fixtures/brand/before/generated-host-emails
  modified:
    - test/support/brand/catalog.ex
    - test/sigra/brand/catalog_test.exs
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md

key-decisions:
  - "The before catalog keeps the reset-password request page as a one-line marker (the truthful before state of a page that answers HTTP 500); the fix is listed as owed in the manifest and the deferral log, not made here (orchestrator decision on plan 03 deliverable D5)"
  - "The generated-host smoke target was run with the PG* and SIGRA_TEST_PG_* variables unset so every command reaches localhost:5432; the script's DB behavior is untouched (orchestrator decision)"
  - "The audit pagination cursor (base64 of a timestamp and a random row UUID) is normalized to {{CURSOR}}; the rest of the query string stays"
  - "Manifest personas = the tier-1 literal personas plus the seeded Tasklane cohort found in tier 2; bulk loadtest-* rows and the capture sender are not personas"
  - "The two generated email builders that plan 03 left out stay out: adding them needs a script change plus a re-capture, and the before is immutable; recorded as a gap for Phase 262"

patterns-established:
  - "After-directory scan: the privacy test scans whichever directory the writer just wrote, and the committed directory once MANIFEST.json exists, with a planted-leak control proving the scan itself can fail"

requirements-completed: [BGEN-03]

coverage:
  - id: D1
    description: "Committed text catalog at test/fixtures/brand/before/ (tier 1: 19, tier 2: 20, generated pages: 5, generated emails: 18, plus MANIFEST.json), pinned to origin/main 4cf5829ea with the lib, priv and golden tree hashes and the shipped CSS and logo hashes, captured while git diff --quiet origin/main -- lib priv succeeded; no PNG, CSS or SVG"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#the committed before catalog, when it exists, matches its manifest byte for byte (live: verify_manifest/1 returns [])"
        status: pass
      - kind: other
        ref: "python3 -I check of MANIFEST.json: pinned.origin_main_sha == git rev-parse origin/main, lib_tree == HEAD:lib, priv_tree == HEAD:priv, golden_tree == HEAD:test/fixtures/install_golden/tree, provenance == 'brand book v2.0 (2026-11-13)', files map lists exactly the 62 committed lane files"
        status: pass
      - kind: other
        ref: "test -z \"$(find test/fixtures/brand/before -type f \\( -name '*.png' -o -name '*.css' -o -name '*.svg' \\))\"; git diff --quiet origin/main -- lib priv"
        status: pass
    human_judgment: false
  - id: D2
    description: "The normalized catalog is deterministic: tier 1 and tier 2 are byte-identical across two captures 70 seconds apart, and the generated lane is byte-identical across two independent fresh generated hosts; no volatile pattern and no absolute date past the seeds' reference date survives"
    requirement: BGEN-03
    verification:
      - kind: other
        ref: "diff -ru tmp/catalog-after-run1 tmp/catalog-after (empty, 62 files); diff -ru tmp/catalog-gen-run1 tmp/catalog-gen-run2 (empty, 62 files, two fresh hosts)"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#normalize/2 a pagination cursor value is replaced, the rest of the query stays (red before the rule, green after)"
        status: pass
      - kind: other
        ref: "volatile-pattern grep and run-day clock scan over the written catalog, each with its planted positive control; address scan over the generated lane with planted control"
        status: pass
    human_judgment: false
  - id: D3
    description: "The privacy scan passes over every committed catalog file and the manifest, and over whichever directory the writer just wrote; the scan is shown able to fail by a planted leak in a lane file and in the manifest"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#privacy_violations_in/1 over written catalog directories (3 tests)"
        status: pass
      - kind: other
        ref: "run-time-derived local user name, authoring-origin host and maintainer address absent from the tracked before tree, each with a planted self-match control (re-run after the commit against git ls-files)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The before catalog is write-once: a second SIGRA_BRAND_CATALOG=before run raised the immutability error at setup_all and changed nothing; the manifest re-hash test is live and green"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#write!/2 in before mode refuses to overwrite once MANIFEST.json exists, and changes nothing"
        status: pass
      - kind: other
        ref: "second SIGRA_BRAND_CATALOG=before mix test run: setup_all RuntimeError 'the committed before catalog is immutable', 62 invalid, directory bytes unchanged (mix test test/sigra/brand afterwards: 405 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The owed pre-262 shipped-byte fixes (registration and passkey-options oracles, confirm, reset-request) and the re-capture rule are recorded in the manifest and in 260-deferred-items.md; none is fixed; the manifest coverage states the not-covered items, the capture-host sender overrides, the reset-page marker and the one exact-value replacement"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#manifest/2 (coverage text carries the tier-2 sender override, the reset-page marker and the one exact-value replacement; names the reset-request page fix as owed; records the owed fixes and the re-capture rule)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Accepting a one-line marker as the before baseline for the reset-password request page (instead of holding the capture for the shipped fix)"
    requirement: BGEN-03
    verification: []
    human_judgment: true
    rationale: "A product call recorded by the orchestrator (resolving plan 03 deliverable D5), not asserted by a test. If the owner prefers a rendered before for that page, the fix must land and the generated lane must be re-captured under a documented new decision before Phase 262."

duration: 11min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 05: The Immutable Before Catalog Summary

**A 63-file normalized text catalog (19 pure renders, 20 example admin pages on seeded .test personas, 5 generated auth pages, 18 generated emails, plus a hash-pinned MANIFEST.json) captured once while lib/ and priv/ were byte-identical to origin/main, proven deterministic across two timed captures and two fresh generated hosts, and write-protected by a refuse-to-overwrite writer and a live re-hash test.**

## Performance

- **Duration:** 11 min (start 2026-11-15T19:05:46Z, end about 19:17Z), including a 70-second determinism gap and two fresh generated hosts
- **Tasks:** 3 (Task 1 tracer, Tasks 2 and 3 auto)
- **Files:** catalog directory (63 files) plus 3 modified (2 test-support files, 1 phase log); nothing under `lib/` or `priv/`

## Accomplishments

- **Tracer passed end to end.** Tier 1 and tier 2 were produced and written twice, 70 seconds apart, and `diff -ru` was empty. The first attempt found one real volatility (below); after the rule the whole chain was re-run from scratch.
- **Generated lane is deterministic across two fresh hosts.** `admin-acceptance-smoke.sh --test catalog` was run twice (two independent phx_new 1.8.8 + `mix sigra.install` hosts). The raw dumps differ (csrf tokens, `phx-` ids, signed session values); the normalized trees are identical.
- **One immutable write.** `SIGRA_BRAND_CATALOG=before mix test test/sigra/brand/catalog_test.exs` with `CI` unset ran `assert_main_identity!/1`, wrote the four lane directories and the manifest last. A second run raised the immutability error at `setup_all` and changed nothing.
- **Guards are live.** With the manifest present the byte-for-byte re-hash test and the new committed-directory privacy test run for real (405 brand tests green; full root suite 3054 tests, 0 failures).

## The catalog

| Lane | Files | Size on disk |
| --- | --- | --- |
| `tier1-library-admin` (library-admin, pure renders) | 19 | 180 KB |
| `tier2-example-admin` (library-admin, example-mirror shell, seeded personas) | 20 | 332 KB |
| `generated-host-pages` (generated-host, anonymous auth pages) | 5 | 44 KB |
| `generated-host-emails` (generated-host, 18 email builders) | 18 | 104 KB |
| `MANIFEST.json` | 1 | 13,802 bytes |
| **Total** | **63** | **676 KB** (`du -sk`; 590,150 bytes of added lines), under the 3 MB stop limit |

Pins recorded in the manifest (all re-checked against git after the write):

| Field | Value |
| --- | --- |
| `pinned.origin_main_sha` and `merge_base_sha` | `4cf5829eaa96973c064b9b32a215439ae200cf42` |
| `pinned.lib_tree` | `cee46757e8e20ed59eca0e2af4ac214c931e4247` |
| `pinned.priv_tree` | `290c9ece96677bef9093f43d9608b839e36556e9` |
| `pinned.golden_tree` | `0211f2ea0489d3dd152f53588657ba76220d23ae` |
| `provenance` | `brand book v2.0 (2026-11-13)` |
| `capture_command` | `SIGRA_BRAND_CATALOG=before mix test test/sigra/brand/catalog_test.exs` |
| `example_files_changed_vs_main` | `confirmation_live.ex`, `reset_password_live.ex`, `router.ex` under `test/example/lib/example_web` (the three Phase 259 example files) |
| `personas` | 14 fictional `.test` addresses (5 tier-1 personas plus the 9 seeded cohort addresses in tier 2) |

`generated-host-pages/reset-password.html` is a one-line marker comment, not a rendered page (the shipped page answers HTTP 500). The same fact is in the manifest `coverage.not_covered` text and `deferred_shipped_byte_fixes`.

The 590,150 added bytes of catalog equal about 147,537 tokens of generated artifact; the hand-written diff (harness code, tests, the deferral log) is 13,171 bytes, about 3,292 tokens. `actuals.tokens` is the whole realized diff (150,830), not the authored part alone, against a plan estimate of 50,000; it is not rounded toward the estimate.

## Task Commits

1. **Task 1: tracer, after-mode capture of tier 1 and tier 2 twice** - `d0628c2ad` (test: `{{CURSOR}}` rule, red first)
2. **Task 2: generated lane from two fresh hosts, after-directory privacy scan** - `4e15d22e7` (test)
3. **Task 3: manifest content, then the immutable write, then the log**
   - `173adbf25` (test): manifest coverage text, owed reset-request fix, seeded personas
   - `c7c91ab42` (test): the before catalog (63 files)
   - `df035eed4` (docs): deferral log

**Plan metadata:** docs commit (this SUMMARY, STATE, ROADMAP, REQUIREMENTS).

## Test-first notes

The three tasks are `tracer`/`auto`, not `tdd="true"`, but every harness change was written test-first and each new test was seen red on its intended assertion before the code existed: the cursor rule (`Refute with =~ failed`, the planted cursor value survived), the directory privacy scan (undefined function), and the coverage, deferred-fix and persona tests (3 failures; the persona test failed on `"alice@demo.tasklane.test" in personas` with only the five tier-1 personas present). ExUnit console output is not a report format `gsd_run check tdd-red-evidence` classifies, so the assessment is semantic.

## Positive controls (planted, each shown to match)

- Anchored `phx-` volatile pattern: `<link phx-track-static phx-click-away>` prints nothing, `<div id="phx-F1a2b3c4d5e6">` prints a match.
- Clock scan: a planted run-day date is printed by the same awk filter that must print nothing over the catalog.
- Non-`.test` address scan: a planted `a@b.com` is printed by the same pipeline that is empty over the generated lane.
- Local user name, authoring-origin host and maintainer address: each derived at run time (never written to a file) and each proven to match a planted probe file; the scan over the tracked before tree was run before and after the commit.
- Directory privacy scan: a planted non-`.test` address in a lane file and in `MANIFEST.json` is found; a clean planted directory reports `[]`.
- Immutability: the second before run raised at `setup_all` (observed).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Audit pagination cursor made two captures disagree**
- **Found during:** Task 1, first `diff -ru` of the two tier-2 captures (the only difference in 62 files)
- **Issue:** `admin-audit-index` carries a next-page link `?cursor=<base64>` whose value encodes the last row's timestamp and its UUID. The seeded audit event UUIDs are random on every run, so the cursor differs per capture, and the root normalizer did not cover it.
- **Fix:** normalizer rule `([?&;]cursor=)[A-Za-z0-9_%=-]+` to `\1{{CURSOR}}`, the rest of the query string kept; planted-input test written first and seen red; moduledoc updated.
- **Files modified:** `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`
- **Verification:** brand suite 399 then 402 tests green; the whole two-capture chain re-run from scratch (70-second gap): `diff -ru` empty.
- **Commit:** `d0628c2ad`

**2. [Rule 2 - Missing critical] Manifest lacked the statements the plan requires it to carry**
- **Found during:** Task 3 preparation
- **Issue:** the plan and the orchestrator require the manifest to state the tier-2 branding sender override, the reset-page marker, the one exact-value replacement and the reset-request fix as owed, and to list the tier-2 personas; the plan-02 harness carried only the generated-email sender override and the tier-1 persona list.
- **Fix:** `coverage` and `deferred_shipped_byte_fixes` extended; `personas` derived from the catalog (tier-1 personas plus the seeded cohort in tier 2). Three tests written first, seen red.
- **Files modified:** `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`
- **Commit:** `173adbf25`

### Implementation choices that differ from the plan's literal wording

- **Task 1's "tier 1 and tier 2 only" run included the generated-host raw already on disk.** `build/1` (plan 02) raises when a raw lane is missing, so a run with a raw directory cannot omit the generated lane. Both Task 1 captures therefore wrote 62 files (19 + 20 + 23). The 19 + 20 = 39 subtotal was verified numerically by directory; the generated lane's own two-host comparison is Task 2.
- **The after-directory privacy test is a new public function plus three tests** (`Catalog.privacy_violations_in/1`): it scans every file under a directory with its manifest, and runs over the writer's own output and over the committed directory once the manifest exists. It does nothing when no writer ran and no manifest exists, which is why the planted-leak control is part of it.
- **Task 3's PII verify blocks first ran against `git ls-files -o --exclude-standard`** (the files were untracked until the commit) and were re-run against `git ls-files` after the commit; both passed.
- **Raw inputs were reused** from Tasks 1 and 2 (no tracked file that feeds the producers changed in between, only harness code), as the plan allows. `git diff --quiet origin/main -- lib priv` was re-confirmed immediately before the write; no fetch was made.
- **Task 2's smoke runs used the orchestrator's DB decision** (PG* and SIGRA_TEST_PG_* unset, a Postgres reachable on localhost:5432); the tier-2 example catalog test used `source tmp/db.env`. Neither failed, so the two-failed-attempts rule was not triggered.

**Total deviations:** 2 auto-fixed (1 bug, 1 missing-critical) plus the choices above. **Impact on plan:** none on scope; every acceptance criterion met.

## Issues Encountered

- The first generated-host comparison could have been vacuous, so the raw dumps were diffed too: they differ in csrf tokens, `phx-` ids and signed session values (as expected), and the normalized trees did not. The normalizer is doing real work, not comparing identical inputs.
- The immutability error message embeds the absolute repo path in test output only; nothing in the committed catalog or manifest contains a home path (scan: 0 files).
- Not captured, stated in the manifest and the deferral log: authenticated generated screens (golden tree only), explicit light and dark branding variants of the generated auth pages, event-driven admin states, two generated email builders (see Deviations and the log), any CSS or PNG.

## Authentication Gates

None.

## Known Stubs

None. `generated-host-pages/reset-password.html` is a deliberate marker for a shipped defect (HTTP 500), documented in the manifest, the deferral log and the smoke script, not a placeholder for missing work. The plan's goal is met with it; whether a marker is an acceptable baseline is deliverable D6 (human judgment, resolved by the orchestrator).

## Threat Flags

None. No endpoint, auth path, file access pattern or schema was added. T-260-12: privacy scan (planted controls) plus the address, run-day, home-path and derived-identity scans are clean over the 63 committed files. T-260-13: the writer refused unless `lib/` and `priv/` matched origin/main (re-confirmed before the write, `git status --porcelain -- lib priv` empty), and the manifest pins the SHAs and tree hashes. T-260-14: refuse-to-overwrite observed; the re-hash test is live.

## Verification Run

| Check | Result |
| --- | --- |
| `diff -ru tmp/catalog-after-run1 tmp/catalog-after` (tier 1 + tier 2, 70 s apart) | empty |
| `diff -ru tmp/catalog-gen-run1 tmp/catalog-gen-run2` (two fresh generated hosts) | empty |
| volatile-pattern grep, run-day clock scan, generated-lane address scan (each with planted control) | clean |
| `source tmp/db.env && mix test test/sigra/brand` (CI unset, writer unset), manifest guard live | 405 tests, 0 failures |
| `SIGRA_BRAND_CATALOG=before mix test test/sigra/brand/catalog_test.exs` second run | immutability error at `setup_all`, bytes unchanged |
| `mix test --exclude scaffold` (full root suite) | 33 doctests, 3 properties, 3054 tests, 0 failures, 12 skipped, 22 excluded |
| `mix format --check-formatted` | exit 0 |
| `git diff origin/main -- lib priv`; `git status --porcelain -- lib priv` | both empty |
| no `.png`, `.css`, `.svg` under the before directory; provenance is exactly `brand book v2.0 (2026-11-13)` | confirmed |
| `git log -2 --format=%s` | catalog commit, then deferral-log commit (separate) |

Commit ledger (measured from the persisted base): `plan_head_before` `1f5d3e917ce85e66b3618628d74fdca5689141f2`, `plan_head_after` `df035eed410cdd6b006b2f05621072e0c048e65e`, `git rev-list --count` = 5.

## Handoff for Plans 08, 09 and 11

- **Plan 08** (before/after report script) diffs `tmp/catalog-after` against `test/fixtures/brand/before/`; manifest field names are the plan-02 contract; `Catalog.read_dir!/1` skips `MANIFEST.json`.
- **Plan 09 (L1) may now change shipped bytes.** The before catalog is complete and committed, so the wave constraint is met. After plan 09 lands, the before still reads as captured (hash-protected, never compared to current sources).
- **Generated-lane re-capture rule:** if the registration or passkey-options oracle, the confirm fix or the reset-request fix lands before Phase 262, re-capture the generated lane first as a documented new decision (see `260-deferred-items.md`, plan 05 section 1).
- **The reset-password marker** in `generated-host-pages/` becomes a diff of a marker against a rendered page once that page is fixed; the smoke script pins that page's status to 500 and fails when it turns 200, so the change cannot go unnoticed.
- The two email builders still outside the before (plan 03 item 3) have no baseline; Phase 262 should state that or open a new capture decision for just those two files.

## Next Phase Readiness

Ready for plan 08 and for plan 09 (the first plan allowed to change shipped bytes). Nothing in this plan blocks them.

## Self-Check: PASSED

- Created and modified files exist (`[ -f ]`): `test/fixtures/brand/before/MANIFEST.json`, `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`, `260-deferred-items.md`; all four lane directories exist with 19, 20, 5 and 18 files.
- All five production commits (`d0628c2ad`, `4e15d22e7`, `173adbf25`, `c7c91ab42`, `df035eed4`) are ancestors of HEAD (`git merge-base --is-ancestor`).
- Task 1, 2 and 3 acceptance criteria re-run and passing; plan-level verification re-run after the last commit.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
