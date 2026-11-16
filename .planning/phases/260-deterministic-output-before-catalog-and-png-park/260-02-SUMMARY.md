---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 02
subsystem: testing
tags: [brand, catalog, normalizer, manifest, privacy-scan, liveview, bgen-03]

requires:
  - phase: 259
    provides: RegenGuard, the brand test suite conventions, source_pin privacy rules, frozen-surface pretty-JSON recipe
provides:
  - "Sigra.Test.Brand.Catalog: normalize/2, 19 tier-1 literal-assign renders of the eight library admin LiveViews, build/1, write!/2 (:before, :after), manifest/2, verify_manifest/1, committed_status/1, privacy_violations/1, assert_main_identity!/1, clock_violations/2"
  - "SIGRA_BRAND_CATALOG=before|after opt-in writer, requested only through RegenGuard.requested?/3 (refused under CI=true)"
  - "Pinned MANIFEST.json field names for plans 05 and 08"
  - ".gitattributes line test/fixtures/brand/before/** -text"
affects: [260-03, 260-05, 260-08, 260-11, 262]

actuals:
  tokens: 19510
  tasks: 3
  commits: 8

plan_head_before: 6eee55fe8610ec21fcc0ca3ac5452ee26bcf0b04
plan_head_after: 188dbe19822cd061f56cebefd986ac7bb8007505

tech-stack:
  added: []
  patterns:
    - "Pure LiveView render of render/1 with literal assigns (Phoenix.LiveViewTest.rendered_to_string/1), normalized to line-per-tag text"
    - "Immutable baseline protected by hash and refuse-to-overwrite, never by equality with current sources"
    - "Privacy rules with a planted failure per rule, each observed red against a deliberately weakened rule"

key-files:
  created:
    - test/support/brand/catalog.ex
    - test/sigra/brand/catalog_test.exs
  modified:
    - test/support/brand/regen_guard.ex
    - .gitattributes

key-decisions:
  - "The shipped branding sign-in preview placeholder address (an example.com literal in Components.preview_pair/1) is masked to {{PREVIEW_EMAIL}} by the normalizer instead of weakening the privacy rule; the manifest coverage records it"
  - "Manifest field names fixed: schema, provenance, pinned, capture_command, lanes, personas, coverage, example_files_changed_vs_main, deferred_shipped_byte_fixes, files"
  - "write!(:before) refuses when MANIFEST.json exists, when the raw directory is absent, and unless lib/ and priv/ are byte-identical to origin/main; it writes the manifest last"
  - "example_files_changed_vs_main is computed from git over render-affecting example paths only (lib, config, assets, priv/static, priv/repo, priv/gettext) and yields exactly the three Phase 259 files today"

requirements-completed: [BGEN-03]

coverage:
  - id: D1
    description: "normalize/2 removes csrf values, phx ids and signed values, vsn queries, per-render ids, every UUID and relative wall-clock text, never an absolute timestamp, and canonicalizes whitespace to one tag per line"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#normalize/2 (7 tests incl. planted csrf, UUID, 304d ago controls)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tier 1 renders 19 states across all eight library admin LiveViews deterministically from literal assigns, with every data date pinned at or before 2026-05-15"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#tier 1 state matrix (matrix, eight-LiveView completeness derived from lib/, determinism, no raw UUID/csrf/relative text, clock control)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Manifest is sorted-key pretty JSON with the pinned fields; verify_manifest/1 reports exactly the mutated path; the committed-catalog guard is live only once MANIFEST.json exists and its non-vacuity is proven with a planted directory"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#manifest/2, verify_manifest/1"
        status: pass
    human_judgment: false
  - id: D4
    description: "privacy_violations/1 flags home paths, Windows profile, /private/var, file URL, non-.test email, secret_key_base, signing_salt and a long csrf value; each rule has a planted failure observed red against a weakened rule"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#privacy_violations/1 planted-failure controls (11 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "write!(:before) is refused when MANIFEST.json exists, raw inputs are missing, a raw lane is missing, lib/priv differ from origin/main, or CI=true; assert_main_identity!/1 names the differing area; the default git runner returns the live pin"
    requirement: BGEN-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/catalog_test.exs#write!/2 in before mode, assert_main_identity!/1"
        status: pass
      - kind: integration
        ref: "MIX_ENV=test mix run --no-start -e 'Sigra.Test.Brand.Catalog.assert_main_identity!()' against the live repo (read-only)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The before catalog itself (the committed text, its real MANIFEST.json, its size) does not exist yet"
    requirement: BGEN-03
    verification: []
    human_judgment: true
    rationale: "This plan builds the harness only. The single immutable capture, with tier-2 and generated-host raw inputs from plan 03, is plan 05."

duration: 14min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 02: Before-Catalog Harness Summary

**A deterministic, privacy-scanned text catalog harness: a pure normalizer, 19 literal-assign renders of the eight library admin LiveViews, a guarded opt-in writer, and a hash-protected immutable `before` manifest, each guard seen failing once.**

## Performance

- **Duration:** about 14 min (start 2026-11-15T18:11:17Z, end 18:26Z)
- **Tasks:** 3 (Task 1 tracer, Tasks 2 and 3 TDD)
- **Files:** 4 (2 created, 2 modified), nothing under `lib/` or `priv/`

## Accomplishments

- `Sigra.Test.Brand.Catalog.normalize/2` is a pure function: csrf values (`{{CSRF}}`), `phx-` request ids, `data-phx-*` signed values, `?vsn=`, per-render `mg-<n>-...-<n>` ids, every UUID (persona-labelled when mapped, else `{{UUID}}`) and relative wall-clock text (`{{RELATIVE}}`) are replaced; absolute timestamps are never matched by pattern; whitespace collapses to one tag per line.
- Tier 1 renders 19 states over all eight library admin LiveViews through `rendered_to_string(Live.render(assigns))` with `__changed__: nil`, no database, no browser, no clock. The eight-LiveView completeness check is derived from `lib/sigra/admin/live/*_live.ex`, so a ninth LiveView fails it.
- Every data timestamp is pinned at or before 2026-05-15 (`clock_pin/0`); `clock_violations/2` flags any date past the pin or equal to the run day, so a `utc_now()` that sneaks in fails the day it is written.
- `write!/2` is opt-in through `RegenGuard.requested?/3` only (no direct environment read in either new file; `RegenGuardTest` stays green). `:after` writes `tmp/catalog-after/` (gitignored, owned lane directories cleared first). `:before` is the one immutable capture: refuses when `MANIFEST.json` exists, when no raw directory exists, and unless `assert_main_identity!/1` passes (`git diff --quiet origin/main -- lib priv`); the manifest is written last.
- `build/1` already ingests the plan-03 raw dumps (`tier2-example-admin`, `generated-host/pages`, `generated-host/emails`) into the committed layout; a raw directory that exists but lacks a lane is an error naming it.
- Manifest field names are fixed for plans 05 and 08 (listed in Decisions). `verify_manifest/1` re-hashes the directory; `committed_status/1` makes the committed-catalog guard a no-op until the catalog exists, with a planted-directory test proving the live branch is reachable.
- `privacy_violations/1` is the Phase 259 source-pin text rule set plus `secret_key_base`, `signing_salt` and a csrf-value rule. No allowlist.

## Final tier-1 state matrix (19 states, 8 LiveViews)

| LiveView | States |
| --- | --- |
| `audit_index_live` | populated, empty |
| `audit_user_live` | populated, empty |
| `branding_live` | default_profile, explicit_profile |
| `index_live` | overview, needs_review |
| `organization_live` | populated, empty |
| `user_sessions_live` | populated, empty |
| `user_show_live` | active, unconfirmed, locked, scheduled_deletion |
| `users_index_live` | populated, empty, filtered_empty |

Paths are `tier1-library-admin/<live>--<state>.html` (for example `user_show_live--locked.html`). Three states go beyond the plan's minimum list (`index_live--needs_review`, `organization_live--empty`, `users_index_live--filtered_empty`) because each carries distinct shipped copy Phase 262 may touch. An after-mode run writes 19 files, 180 KB; two consecutive runs are byte-identical (`test -z "$(diff -ru run1 run2)"`).

### Recorded as not covered (manifest `coverage.not_covered`)

No state the plan listed was dropped. Recorded as not reachable by a pure render:

- Event-driven states: the revoke-session, revoke-all-sessions and restore-defaults confirm dialogs, the branding unsaved-draft and validation-error states, and loading skeletons. Their copy is assigned in `handle_event` or on socket connect, so rendering them would mean duplicating the copy as a fake.
- The branding preview placeholder address is masked (see Deviations).
- Plus the plan's own items: authenticated generated screens (golden tree only), Light/Dark/System admin HTML (theme is client-side), explicit light/dark profile variants of generated auth pages (only the default-profile value), anything rendered from CSS, any PNG.

## Task Commits

1. **Task 1: tracer, normalizer plus UserShowLive locked render through the guarded writer**
   - RED `1df4bb708` (test), GREEN `5474b1d18` (feat)
2. **Task 2: manifest, privacy scan, immutability, main-identity, gitattributes**
   - RED `b84959784` (test), GREEN `55c2df1af` (feat)
3. **Task 3: tier-1 matrix for all eight LiveViews, determinism, clock control**
   - RED `d439daa9b` (test), GREEN `b1fb71188` (feat)
4. **Follow-ups inside this plan**
   - `729bef2aa` test: planted example.com addresses built from fragments (no literal non-.test address in committed source)
   - `188dbe198` fix: `example_files_changed_vs_main` scoped to render-affecting example paths

**Plan metadata:** docs commit (SUMMARY, STATE, ROADMAP, REQUIREMENTS).

## TDD Gate Compliance

RED then GREEN is present for all three tasks (`test(260-02)` precedes `feat(260-02)` each time). `workflow.tdd_mode` is not enabled, and ExUnit console output is not a report format `gsd_run check tdd-red-evidence` classifies, so no classifier record exists; the assessments below are semantic, not a classifier verdict.

- **Task 1 RED** (`mix test test/sigra/brand/catalog_test.exs`): 13 tests, 13 failures. Each target test executed and failed with `UndefinedFunctionError` on `Sigra.Test.Brand.Catalog.*`, the planned missing behavior (the module did not exist). Compile emitted only undefined-function warnings, not errors.
- **Task 2 RED:** 42 tests, 29 failures: 28 `UndefinedFunctionError`, plus the `.gitattributes` test failing on its real assertion (the line was absent).
- **Task 3 RED:** 54 tests, 7 failures: the planned-matrix, eight-LiveView completeness, state-marker, clock control, clock planted-control, preview-mask and coverage-text tests. The other 47 passed in RED because the tracer state already satisfied them (determinism, entry shape, one-state privacy scan); they become meaningful as states are added.

### Positive controls observed (each red against a deliberately broken source, then restored byte-identical)

Privacy rules, one weakened at a time (renamed so the rule can no longer fire; the email rule had its `.test` suffix check replaced by an always-true one): mac home path, linux home path, Windows profile, `/private/var`, `file:` URL, `secret_key_base`, `signing_salt`, csrf value (name-first, value-first and key-form each separately), non-`.test` email. Each failed exactly the matching planted test (the mixed-leak test also failed for the rules it combines).

Tier-1 guards: removing the preview mask failed the tier-1 privacy scan and the mask test; a data timestamp built from `DateTime.utc_now()` failed the clock control and the non-vacuity test; a per-call random suffix on audit ids failed the two-render determinism test; removing the UUID rule failed the no-raw-UUID, UUID and planted-control tests; dropping one state failed the planned-matrix test. The mutation scripts lived in the session scratchpad, not the repo.

## Deviations from Plan

### Auto-fixed Issues

None needed (no bug, missing-critical or blocking fix).

### Implementation choices that differ from the plan's literal wording

**1. Branding preview placeholder address masked in the normalizer (Rule 2 adjacent).** `Sigra.Admin.Components.preview_pair/1` ships `value="..."` with an `example.com` address. The plan forbids weakening the privacy rule and forbids changing `lib/`, so the tier-1 branding states would have failed the privacy scan. The normalizer maps that one exact literal to `{{PREVIEW_EMAIL}}`; any other `example.com` address is left alone and still flagged (tested). The cost is that a change to that literal shows as a privacy failure rather than a diff line, which `coverage.not_covered` says in words that carry no address.

**2. `build/1` ingests the raw dumps now.** The plan lists `build/1` as reading the raw directory (shared contract with plan 03) but only Task 3's wording wires tier 1. Plan 05 Task 2 describes the same ingestion. It is implemented here with a missing-lane error and tested with planted raw directories, so plan 05 can extend rather than build it. `write!(:before)` additionally refuses when the raw directory is absent (a tier-1-only baseline is never captured).

**3. Three extra states** beyond the plan's minimum (see matrix).

**4. `write!(:before)` derives `example_files_changed_vs_main` from git by default** (overridable with the `:example_files_changed_vs_main` option). The first pathspec (`test/example` minus `test/example/test`) also listed Playwright specs, helpers and the README; it was narrowed to render-affecting example paths and now returns exactly the three Phase 259 example files, as plan 05 expects.

**5. Manifest `personas` default is the tier-1 persona list** (fictional `.test` addresses); plan 05 passes the full persona list as `meta[:personas]` once tier 2 exists.

**6. `:before` mode does not clear lane directories** (only `:after` does). A stale file in a `before` directory therefore shows up as `{:added, path}` from `verify_manifest/1` instead of being silently deleted.

**Total deviations:** 0 auto-fixed, 6 documented choices. **Impact on plan:** none on scope; all acceptance criteria met.

## Issues Encountered

- The first scripted tier-1 mutation run reported the wall-clock mutation as failing only the non-vacuity test. Cause: the `perl` replacement string interpolated `@last_active_at` as an empty array, so the mutation was not the one intended. Re-run by hand with the mutation applied correctly, the clock control failed as designed. Recorded as a false-negative caught by reading which test failed, not by trusting the summary line.
- `Catalog.assert_main_identity!/0` was smoked once against the live repo (read-only): `origin/main` and merge-base are both `4cf5829ea`, `lib/` and `priv/` match. The real `:before` write was not run here; that is plan 05.
- Full root suite after the last commit: `mix test --exclude scaffold` 3046 tests, 0 failures (12 skipped, 22 excluded). `MIX_ENV=test mix compile --force --warnings-as-errors` is clean. `MIX_ENV=test mix ci` and the example suite were not run in this plan (no example or installer file changed).

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No network endpoint, auth path, file access pattern or schema was added; the writer only writes under `tmp/` or, once, the `before` directory, behind the CI refusal.

## Verification Run

| Check | Result |
| --- | --- |
| `mix test test/sigra/brand` | 398 tests, 0 failures |
| `SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs` run twice, `diff -ru` of copies | empty (19 files, 180 KB) |
| `git status --porcelain` after the writer | none of `tmp/catalog-after` visible (gitignored) |
| `mix format --check-formatted` on catalog.ex, catalog_test.exs, regen_guard.ex | exit 0 |
| `git status --porcelain -- lib priv` | empty |
| `System.get_env`/`System.fetch_env` occurrences in the two new files | 0 (RegenGuardTest enforces) |
| Added-line grep for home paths and non-.test addresses | clean (planted examples are fragment-built) |

Commit ledger (measured from the persisted base): `plan_head_before` `6eee55fe8610ec21fcc0ca3ac5452ee26bcf0b04`, `plan_head_after` `188dbe19822cd061f56cebefd986ac7bb8007505`, `git rev-list --count` = 8. `actuals.tokens` is chars/4 over the added diff lines (78,041 bytes / 4 = 19,510), against a plan estimate of 70,000; not rounded toward the estimate.

## Handoff for Plans 03, 05 and 08

- **Plan 03** writes raw dumps under `tmp/catalog-raw/` (`tier2-example-admin/<slug>.html`, `generated-host/pages/<slug>.html`, `generated-host/emails/<slug>.txt`); `Catalog.build/1` normalizes them (`.html` with `format: :html`, `.txt` with `format: :text`). Persona labels (`{{PERSONA:<key>}}`) and `{{CAPTURE_SESSION_ACTIVITY}}` placeholders pass through untouched. The branding page also carries the masked preview address.
- **Plan 05** runs `SIGRA_BRAND_CATALOG=before mix test test/sigra/brand/catalog_test.exs` once, with `CI` unset and a raw directory present. Pass the full persona list as `meta[:personas]` if tier 2 adds personas (extend `write_before!` or the `:personas` meta), and re-read the emails text normalizer (`:text` only trims trailing whitespace; the email files hold an HTML body that is not tag-split). The coverage text already carries the capture-host sender-override and auth-page theme statements plan 05 asserts. No literal `example.com` address may be added to `coverage`, `deferred_shipped_byte_fixes` or any lane text: the manifest itself is privacy-scanned.
- **Plan 08** can rely on the manifest field names, `read_dir!/1` and `tier1_files/0`.
- The committed-catalog tests (`committed_status/1` re-hash) are no-ops until `test/fixtures/brand/before/MANIFEST.json` exists, then go live without any test edit.

## Next Phase Readiness

Ready for plan 03 (raw inputs) and then plan 05 (the immutable capture). Nothing in this plan blocks them.

## Self-Check: PASSED

- Created and modified files exist (checked with `[ -f ]`): `test/support/brand/catalog.ex`, `test/sigra/brand/catalog_test.exs`, `test/support/brand/regen_guard.ex`, `.gitattributes`.
- All eight production commits (`1df4bb708`, `5474b1d18`, `b84959784`, `55c2df1af`, `d439daa9b`, `b1fb71188`, `729bef2aa`, `188dbe198`) are ancestors of HEAD (`git merge-base --is-ancestor`).
- Task 1, 2 and 3 acceptance criteria re-run and passing (regen guard test, planted controls, determinism, moduledoc entry, gitattributes lines, format, `lib`/`priv` clean, two identical after-mode runs, all eight LiveViews present).
- Plan-level verification re-run after the last commit: green.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
