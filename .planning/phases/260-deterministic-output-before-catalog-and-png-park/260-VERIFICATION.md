---
phase: 260-deterministic-output-before-catalog-and-png-park
verified: 2026-11-15T21:55:00Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".gitattributes"
  - ".github/workflows/ci.yml"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-01-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-01-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-02-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-02-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-03-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-03-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-04-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-04-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-05-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-05-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-06-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-06-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-07-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-07-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-08-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-08-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-09-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-09-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-10-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-10-SUMMARY.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-11-PLAN.md"
  - ".planning/phases/260-deterministic-output-before-catalog-and-png-park/260-11-SUMMARY.md"
  - "MAINTAINING.md"
  - "mix.exs"
  - "priv/templates/sigra.install/admin/sigra_admin.css"
  - "priv/templates/sigra.install/core/sigra_auth.css"
  - "scripts/brand/catalog-diff.sh"
  - "scripts/ci/admin-acceptance-smoke.sh"
  - "scripts/ci/admin-css-conformance.sh"
  - "scripts/ci/admin-css-conformance.test.sh"
  - "test/example/lib/example_web/live/admin/design_gallery_live.ex"
  - "test/example/priv/playwright/tests/admin-checkpoints.spec.ts"
  - "test/example/priv/playwright/tests/admin-design.spec.ts"
  - "test/example/priv/playwright/tests/admin-generated.spec.ts"
  - "test/example/priv/playwright/tests/demo-showcase.spec.ts"
  - "test/example/priv/static/assets/css/app.css"
  - "test/example/priv/static/assets/sigra_admin.css"
  - "test/example/priv/static/assets/sigra_auth.css"
  - "test/example/test/example_web/catalog_test.exs"
  - "test/example/test/example_web/live/admin_design_gallery_catalog_test.exs"
  - "test/fixtures/brand/before/MANIFEST.json"
  - "test/fixtures/brand/css-undefined-classes.txt"
  - "test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css"
  - "test/sigra/brand/catalog_diff_test.exs"
  - "test/sigra/brand/catalog_test.exs"
  - "test/sigra/install/asset_parity_test.exs"
  - "test/sigra/install/css_undefined_classes_test.exs"
  - "test/sigra/install/double_install_test.exs"
  - "test/sigra/install/features/admin_test.exs"
  - "test/sigra/planning/phase_260_ci_alias_contract_test.exs"
  - "test/sigra/planning/phase_260_png_park_contract_test.exs"
  - "test/support/brand/catalog.ex"
  - "test/support/brand/css_gap.ex"
  - "test/support/brand/regen_guard.ex"
covered_digest: "v4:sha256:967914abd25c62cd70142126e282257bca7b373e9a8f649941b4f8f08c7ee5ad"
behavior_unverified: 0
overrides_applied: 0
deferred:
  - truth: "Shipped default dark palette draws accent text below WCAG AA (3.17:1 measured vs 4.5:1) in the template sigra_auth.css"
    addressed_in: "Phase 261"
    evidence: "Phase 261 success criterion 2: 'The 30 brand-book contrast pairs pass over the implemented CSS in light and dark plus hover/focus/disabled states using Sigra.Branding.Contrast' (BTOK-03)"
human_verification: []
---

# Phase 260: Deterministic Output, Before Catalog and PNG Park, Verification Report

**Phase Goal:** Generated output is byte-stable and verifiably in sync with its sources, the latent CSS defects are repaired, the "before" state of every in-scope screen is captured while output is still byte-identical to main, and the PNG-compare lanes are parked so later visual changes can merge.
**Verified:** 2026-11-15T21:55:00Z
**Status:** passed (with five non-blocking warnings, listed below; none violates a success criterion)
**Re-verification:** No, initial verification

Method: every ROADMAP success criterion was re-derived from the repository and from commands run during this
verification, not from SUMMARY text. Where a SUMMARY claim could be re-run cheaply it was re-run (results in the
spot-check table). The working tree was left unmodified (the only dirty file, `.planning/config.json`, is the
owner's unrelated edit; verification wrote only to gitignored `tmp/`).

## Goal Achievement

### Observable Truths (ROADMAP SC-1 to SC-5, the contract)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A maintainer can read a committed "before" catalog (3 tiers, normalized HTML, seeded `.test` personas, pinned SHA, byte-identical to main, auth pages from template CSS, no new PNG, manifest + copy inventory) | VERIFIED (one parenthetical departure, see W3) | `test/fixtures/brand/before/` holds 62 catalog files + `MANIFEST.json` (44 html, 18 txt, 0 png, 0 css). I re-hashed all 62 files against the manifest: 0 mismatches, 0 files on disk but not in the manifest, 0 the other way. The manifest pins `origin_main_sha` 4cf5829ea and `lib_tree`/`priv_tree`/`golden_tree` hashes; I recomputed them with `git rev-parse 4cf5829ea:lib` etc. and they match, and the phase-base trees are identical, so the capture really was byte-identical to main. The capture commit (c7c91ab42) precedes the only shipped-byte change (6fc5e2ccc). Tier 0 is by reference to `test/fixtures/brand/copy-inventory` (exists). Personas are `@demo.tasklane.test` / `.test`. I re-ran tier 1 and tier 2 on the final tree (23 tests in the example app, `SIGRA_BRAND_CATALOG=after`, 62 tests), then `scripts/brand/catalog-diff.sh`: `no differences`. Planted-change control on a copy: reported 1 changed + 1 removed file. Immutability and refuse-to-overwrite are asserted in `catalog_test.exs` (62 tests pass). |
| 2 | Installing twice is byte-identical; `rebless_golden --check` clean under pinned phx_new 1.8.8; every copied asset has a template/example/golden parity test | VERIFIED | `mix archive` shows `phx_new-1.8.8`; `MIX_ENV=test mix sigra.fixture.rebless_golden --check` printed `OK: fixture is up-to-date (check mode)`. `double_install_test.exs`, `golden_diff_test.exs`, `idempotency_test.exs` run with `--include scaffold`: 18 tests, 0 failures (two fresh installs compared after normalization, raw delta confined to migration filenames and config salts). `asset_parity_test.exs` classifies exactly the 8 `.css/.svg/.js` files under `priv/templates/sigra.install/` (completeness check, planted-byte control, shrink-only guards on the two documented divergences). `cmp` confirms template == example == golden for `sigra_admin.css`, `sigra_auth.css`; the example `sigra_auth.css` is refreshed to byte equality. `double_install_test.exs` is in the `ci.install_golden` alias (`mix.exs`). |
| 3 | In a real generated host the brand mark and explicit Light/Dark rules render from shipped `sigra_admin.css` alone (app.css duplicates gone), version stamp present, both CSS guards in `mix ci`/`fast_checks` | VERIFIED (two warnings, W1 and W2) | Shipped file gained 239 lines, 0 deleted: stamp `/* sigra-admin-css: 1 */` as line 1, explicit light/dark token blocks, `.sg-brand-mark*` and `.sg-theme-switch*` rules. All token values used already existed in the file, and the 55 moved `--sg-*` declarations equal the 55 removed from the example `app.css` (compared as text, modulo indentation). Example `app.css` now has 0 occurrences of `sg-brand-mark`, `data-sg-admin-theme`, `sg-theme-switch`, `sg-admin-shell[data-theme`. Stamp is on template, example and golden copies. Real generated host: `scripts/ci/admin-acceptance-smoke.sh --test all` (the invocation CI uses) exited 0 here: 8 passed, 1 skipped by design, the L1 computed-style test passed, confirmation journey passed, revoked-admin test passed after the revoke. Guards: `mix.exs` `ci` alias runs `admin-css-conformance.sh` and `admin-token-completeness.sh` right after `compile --warnings-as-errors`; CI's required `library_tests_shard` runs `MIX_ENV=test mix ci`, which the required `Library tests` aggregator depends on. Both guards PASS on the real file; self-test twin 24/24; a planted hex/`transition: all` file exits 1 on darwin, and in the `ubuntu:24.04` image (GNU grep 3.11) the real file exits 0 while a planted hex and a planted line-start raw px both exit 1, so the `\d` to `[0-9]` CHECK 3 fix is proven on the CI userland. |
| 4 | Park PR (separate, small) demotes PNG-compare lanes to dispatch while real-login/generated-host smoke, axe, golden install and behavior specs stay on the PR path; canary not allowlisted; nothing recaptured on darwin; merged with explicit owner approval before Phase 261 | VERIFIED (mechanism departs from the literal wording by owner decision; approval-provenance caveat, W4) | `gh pr view 381`: MERGED, base `main`, title `ci: park PNG compare on pull_request and push`, 6 files, +472/-1; squash commit 4154a913e is an ancestor of the milestone HEAD. The ci.yml diff is exactly three `SIGRA_PNG_COMPARE_SKIP: ${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}` env lines on the admin_checkpoints, design_gallery and demo_showcase shard steps (6 inserted lines, 0 deleted, no `if:` or `name:` touched). Specs skip only `toHaveScreenshot` (axe call stays before the guard; the 28 `@snapshot` board tests `test.skip`; the three demo behavior tests untouched). The PR run's own logs show `SIGRA_PNG_COMPARE_SKIP: 1` on the admin_checkpoints and demo_showcase shards and the shards passing; all 27 PR checks passed or were legitimately skipped, including the five ruleset-required contexts. Recapture jobs, drift scripts, `ci-skip-manifest.tsv`, `spec-ownership.json`, `snapshot-allowlist*` and `playwright-github-pages.yml` are byte-unchanged over the whole phase; `snapshot-canary-guard.sh` is still run from `fast_checks`; no PNG or snapshot path appears anywhere in the phase diff. The five required job names each still appear once as `name:`. `phase_260_png_park_contract_test.exs` (17 tests, planted-source controls) plus phase_230, phase_234, prohibitions (93/93) and observer (19/19) all pass. ADR 005 carries the dated note under decision 7 recording authoring order and mechanism, and its switch values match the live diff. Judgement on the deviation: see "Park deviation" below. |
| 5 | No token value, logo, copy, `Components` markup or `Profile` key changed; frozen-surface ratchet, privacy grep and process budget hold (no new workflow/receipt/ledger beyond the park PR); at most one golden rebless; fresh-host run green | VERIFIED | Phase-own commits (`git log --first-parent --no-merges` from the phase base): under `lib/` nothing; under `priv/` only `priv/templates/sigra.install/admin/sigra_admin.css` (the logos and `sigra_auth.css` template are untouched); whole-phase diff of `lib` + `priv` = that one file, additive. Token declarations moved verbatim (see SC-3). `.github` touched only by the merged park squash (ci.yml +6); no new workflow file. Scripts touched are exactly `catalog-diff.sh`, `admin-acceptance-smoke.sh`, `admin-css-conformance.sh`, `admin-css-conformance.test.sh`. Golden rebless: exactly one commit (6e8a00dff), exactly one path (`.../assets/sigra_admin.css`), and `--check` is clean afterwards. `test/sigra/brand/frozen_surface_test.exs` passes (inside the 528-test brand/install batch). Privacy scan over the phase diff excluding planning docs: 0 home-path shapes, 0 local-user-name hits, 0 configured-email hits, 0 non-`.test` addresses; 0 home paths inside the phase planning directory; `.gitattributes` `-text` line present. Fresh host green: `--test all` exit 0 (see SC-3). |

**Score:** 5/5 roadmap truths verified, 0 present-but-behavior-unverified.

### Park deviation, judged against the owner-approved decision

ROADMAP SC-4 and BGEN-06 say "demote the PNG-compare lanes to dispatch"; the shipped park is a comparison-level
skip (the lanes still run, only the pixel comparison is skipped on PR/push/schedule). The departure is deliberate,
documented in four places (260-01 plan Task 0, 260-01-SUMMARY, 260-04-GATE-LEDGER, ADR 005 dated note), was put to
the owner as a blocking decision checkpoint (`author-first-option-a`) and is judged acceptable because it
satisfies the criterion's substance better than literal demotion would: the PNG compare is off the PR path and on in
dispatch and recapture, and the half of the criterion that says axe, real-login smoke and behavior specs must stay
on the PR path is met more completely (whole-lane demotion would have dropped the checkpoint axe scan and the three
demo behavior tests). It also leaves `if:` predicates, the honest-skip manifest and every required job name
untouched. Verified by reading the live diff, the PR-run logs and the contract tests, not by SUMMARY.

### Plan-level must-haves (supplementary; all folded into the table above)

| Plan | Must-have | Status | Evidence |
|------|-----------|--------|----------|
| 01 | Switch on exactly three steps; recapture jobs, Pages workflow, manifest untouched | VERIFIED | ci.yml diff above; contract test green |
| 02 | Opt-in writer refused under `CI=true`; normalizer determinism; manifest by hash + refuse-to-overwrite; privacy scan with planted leak | VERIFIED | `catalog_test.exs` 62 tests, 0 failures; after-mode run twice reproduced identical normalized output |
| 03 | Example tier-2 producer + `--test catalog`; other smoke targets unchanged | VERIFIED | example `catalog_test.exs` 23 tests green when re-run with the raw dir set; `--test all` and `--test chrome` still run |
| 04 | Two owner approvals recorded; squash, no admin/force; merge SHA recorded | VERIFIED with caveat W4 | gate ledger; PR merged, 27 checks pass/skipped |
| 05 | Catalog committed, labelled lanes, coverage and not-covered stated, owed pre-262 fixes recorded | VERIFIED | `MANIFEST.json` `coverage`, `deferred_shipped_byte_fixes`; `260-deferred-items.md` |
| 06 | Asset table complete; example `sigra_auth.css` refreshed; double install proven; alias lists the new test | VERIFIED | see SC-2 |
| 07 | Guard admits explicit-theme blocks only for `--sg-*`/`color-scheme`; GNU-portable CHECK 3; shrink-only gap baseline | VERIFIED | self-test 24/24 on darwin; GNU container run; `css_undefined_classes_test.exs` passes |
| 08 | Diff script with planted controls; `catalog-*` gallery section outside the board registries; `Suspended` only in the example gallery | VERIFIED | `catalog_diff_test.exs` passes; `catalog-*` ids are not in `COMPONENT/GROUP/CONFIG_BOARDS`; `Suspended` appears 0 times under `lib/` or `priv/`, once in the example gallery |
| 09 | Additive CSS move + stamp; exactly one rebless; red-then-green generated-host assertions | VERIFIED (W2 caveat on the assertion's robustness) | `admin-generated.spec.ts` computed-style assertions present and substantive; green under `--test all` |
| 10 | Owner decision #13 recorded (wire); guards in `mix ci` with contract test and planted control | VERIFIED | `mix.exs`; `phase_260_ci_alias_contract_test.exs` (8 tests) |
| 11 | Park merged into milestone branch; ADR note; full gate; fresh host; catalog neutrality; privacy and budgets | VERIFIED | re-run independently above |

## Deferred Items

Addressed by a later phase's roadmap entry (do not affect status):

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Shipped dark palette accent text is 3.17:1 on the dark surface (below AA 4.5:1); the catalog auth/email previews are pinned to `data-theme="light"` until fixed | Phase 261 | SC-2: "The 30 brand-book contrast pairs pass over the implemented CSS in light and dark..." (BTOK-03) |

Known non-blocking items recorded by the phase and not matched to a scheduled phase (informational, from
`260-deferred-items.md`): the four owed pre-262 shipped-byte fixes (registration timing oracle, passkey-options
oracle, generated confirm fix, generated reset-request fix, where `GET /users/reset-password` is a real HTTP 500
and its before baseline is a marker file), with the re-capture rule recorded in the manifest; two generated email
builders not in the before; the 49-class shipped-CSS gap (shrink-only baseline); `CONTRIBUTING.md` still saying
"seven legs" (the alias now has nine; the file is hash-pinned by sealed Phase 235 tests); the stale "golden alias
runs two files" sentence in `MAINTAINING.md` and its byte-pinned fixture copy; `rebless_golden --help` runs the
writer; the `.test.sh` twins are on no automated gate.

## Warnings (non-blocking; none violates a success criterion)

**W1. Explicit Dark in a generated host is half-applied (carried from plans 09 and 11; recommend a Phase 261 task).**
I confirmed the root cause in the repository: the example `app.css` defines `.sg-admin-shell { ... }` (line 1570)
and the shipped `sigra_admin.css` has no base `.sg-admin-shell` surface rule (only the token blocks and the lockup
and theme-switch rules). So in a real generated host an explicit Dark attribute re-resolves the panel colours but
leaves the page background and body text at light values, giving dark text on near-black panels. System dark is
coherent. Before Phase 260 the switch had no CSS at all and did nothing visible, so this is newly reachable by
clicking Dark. It does not violate SC-3 as worded (the rules do render from the shipped file, asserted by computed
style) and the plan scope deliberately stopped at the roadmap minimum, but v1.51 should not ship it. Fixing it is a
shipped-byte change that needs a second golden rebless, which Phase 260 prohibits. The hand-off exists only as a
STATE.md note; recommend adding it to Phase 261's success criteria (its SC-5 already requires the Light/Dark/System
fresh-host run to be "looked at").

**W2. The new generated-host L1 assertion is timing-dependent; the documented `--test chrome` slice failed 2 of 2
here.** Running the BGEN-04 validation command from `260-VALIDATION.md`
(`PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test chrome`) failed twice on this machine (once while other work
ran, once isolated), on the three explicit-dark assertions only (`explicit dark: light lockup opacity`,
`... dark lockup opacity`, `explicit dark and explicit light resolve different --sg-color-panel`). The failure log
shows the light lockup fading to opacity 0.05 and then returning to 1, i.e. the dark attribute was applied (so the
shipped CSS rule works) and then removed. The only post-load writer of `data-sg-admin-theme` is
`ThemeSwitch.mounted()` in `admin_hooks.js`, which re-applies the stored preference when the LiveView connects, and the
test overrides the attribute right after `page.goto("/admin")` without first calling `waitForLiveViewReady`.
This is my inference; I did not instrument the page. The CI invocation, `--test all` (the test runs second, after a
warm-up test), passed here (8 passed, 1 skipped, L1 test 1.2 s), as it did in plan 11, and plan 09 saw `--test chrome`
pass, so the proof is load-sensitive rather than wrong. It matters because `generated_admin_playwright_smoke` is in
`ci-gate`'s `needs`: a late LiveView connect on a CI runner would redden the milestone PR. Suggested one-line fix:
`await waitForLiveViewReady(page)` before `assertShippedThemeRules(page, testInfo)` in
`test/example/priv/playwright/tests/admin-generated.spec.ts` (the helper already exists in the spec), plus using
`--test all` rather than `--test chrome` in the validation map. Do this before pushing the milestone branch.

**W3. SC-1 parenthetical "full HTML as a CI artifact" is produced by no plan.** Deliberate and reasoned (RESEARCH
Open Question 7; `260-deferred-items.md` plan 05 item 4): the committed normalized text is the durable artifact (a CI
artifact expires in 7 to 14 days and cannot be the baseline Phase 262 diffs against), and producing one needs a
workflow edit that SC-5's process budget forbids. The ROADMAP wording was not amended, so a literal reading of SC-1
finds the clause unmet. I did not self-accept an override. Either amend the SC-1 parenthetical in ROADMAP.md, or accept
this override so the milestone audit does not trip on it:

```yaml
overrides:
  - must_have: "A maintainer can read a committed before catalog ... with a committed manifest plus copy inventory (full HTML as a CI artifact)"
    reason: "Committed normalized text (62 files, about 660 KB) is the durable baseline; a CI artifact expires and would need a workflow edit that SC-5's process budget forbids (RESEARCH OQ7)"
    accepted_by: "{owner}"
    accepted_at: "{ISO timestamp}"
```

**W4. Approval provenance for the park merge (and owner decision #13) is a delegation relayed by an agent.** The
gate ledger records, verbatim, the owner reply that authorised the merge: `and then after that for all the things to
open decisions, follow ur recs plz...`, read as delegation to the presented recommendation (`merge`, after stripping a
stray title line from the PR body). The same sentence also resolved decision #13 (wire). The ledger is candid that the
executing agent did not see the chat and the orchestrator relayed it. I cannot verify chat provenance from the
repository, and a relayed message is not itself evidence of consent. Plan 04's own prohibition asked for an approval
"for that specific action"; a blanket "follow your recs" is weaker than that, and the ADR 005 note's phrase "in a
separate reply, merging it" slightly overstates what the ledger records. The merge itself was clean (no `--admin`, no
force, no `--delete-branch`, ruleset not bypassed, 27 checks green) and is already done. I treated the ledger as the
record, as instructed, and did not make this a gate; the owner should simply confirm the delegation was intended to
cover merging PR #381. The plan 01 Task 0 choice (`author-first-option-a`) is recorded in the SUMMARY as an owner chat
reply without verbatim text.

**W5. The four open code-review warnings are advisory and unchanged (`260-REVIEW-DISPOSITION.md`).** I reproduced
the substance of WR-02 directly: a planted mid-line `padding: 13px` in a one-line rule is not caught by CHECK 3 (it
reports PASS), and `transition: all` with unusual spacing or a multi-line list is outside CHECK 1, so the now-required
guard is easier to bypass than its name suggests. WR-01 (focus ring lost on the active theme-switch segment, WCAG
2.4.7) now ships to adopters in the shipped stylesheet, inherited verbatim from the example. WR-03 (committed-catalog
checks pass vacuously if `MANIFEST.json` is deleted) and WR-04 (the guards' self-test twins have no CI caller) stand
as routed. None breaks an SC; routing to Phase 261 / quick tasks is reasonable. Note `260-VALIDATION.md` is still
`status: draft` / `nyquist_compliant: false` (sign-off never recorded), and REQUIREMENTS.md BGEN-06 still carries the
stale "demote ... to dispatch" and "before Phase 3 starts" wording.

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/fixtures/brand/before/` + `MANIFEST.json` | Immutable text catalog, 62 files | VERIFIED | hashes re-verified; no png/css |
| `test/support/brand/catalog.ex` (1303 lines), `catalog_test.exs` (62 tests) | Writer, normalizer, manifest, privacy | VERIFIED | substantive; wired through `RegenGuard` opt-in |
| `test/example/test/example_web/catalog_test.exs` (16 tests) | Tier-2 producer | VERIFIED | 23 tests ran green with raw dir set |
| `scripts/ci/admin-acceptance-smoke.sh --test catalog` | Generated-lane producer | VERIFIED | plan 11 captured; earlier raw reused by my after-run, result `no differences` |
| `scripts/brand/catalog-diff.sh` + `catalog_diff_test.exs` (20 tests) | BGEN-07 report | VERIFIED | planted-change control observed by me |
| `test/sigra/install/asset_parity_test.exs` (26 tests), `double_install_test.exs` | BGEN-01/02 | VERIFIED | green |
| `priv/templates/sigra.install/admin/sigra_admin.css` | Stamp, explicit blocks, brand mark, theme switch | VERIFIED | +239/-0; copies byte-identical |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | Generated-host L1 assertions | VERIFIED (see W2) | computed-style assertions, `expect.soft`, bounded timeouts |
| `scripts/ci/admin-css-conformance.sh` (+ `.test.sh`) | Explicit-theme scope; GNU-portable CHECK 3 | VERIFIED (see W5) | 24/24 self-test |
| `test/fixtures/brand/css-undefined-classes.txt` | Shrink-only gap baseline | VERIFIED | test green |
| `mix.exs` `ci` alias + `phase_260_ci_alias_contract_test.exs` | Guards wired | VERIFIED | |
| `.github/workflows/ci.yml` + `phase_260_png_park_contract_test.exs` | Park switch | VERIFIED | |
| `.planning/decisions/005-...md` | Dated note under decision 7 | VERIFIED | |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ci.yml` shard steps | the three specs | `process.env.SIGRA_PNG_COMPARE_SKIP === '1'` | WIRED | PR-run logs show the env value reaching the steps |
| `mix.exs` `ci` | the two guard scripts | `cmd bash` alias entries | WIRED | `library_tests_shard` runs `mix ci` |
| `mix.exs` `ci.install_golden` | `double_install_test.exs` | explicit file list | WIRED | |
| `catalog_test.exs` | `MANIFEST.json` | re-hash guard (active because file exists) | WIRED | see WR-03 for the absence loophole |
| `catalog_test.exs` (example) | `Catalog.build/1` | raw-dir contract `tmp/catalog-raw` | WIRED | re-run end to end |
| `catalog_diff_test.exs` | `catalog-diff.sh` | `System.cmd("bash", ...)` | WIRED | |
| `admin_shell.ex` markup | shipped `sigra_admin.css` | `.sg-brand-mark__image--*`, `data-sg-admin-theme`, `.sg-theme-switch*` | WIRED | classes present in shipped CSS; computed-style test green under `--test all` |
| `admin_test.exs` D-11 | shipped explicit blocks | `extract_css_block/2` | WIRED | |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| Tier-1 catalog files | rendered HTML | real `render/1` of the eight admin LiveViews with literal assigns | Yes (regenerated byte-identical) | FLOWING |
| Tier-2 catalog files | rendered HTML | real router + seeded database, wall-clock columns pinned at the source | Yes (re-captured; raw differs run to run, normalized output identical) | FLOWING |
| Generated-lane files | pages/emails | one freshly generated host (phx_new 1.8.8 + `mix sigra.install`) | Yes (plan 11 capture, reused raw) | FLOWING |

## Behavioral Spot-Checks (re-run during this verification)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Library suite | `MIX_ENV=test mix test --exclude scaffold` (+ `format --check-formatted`, `compile --warnings-as-errors`) | 33 doctests, 3 properties, 3157 tests, 0 failures, 12 skipped | PASS |
| Phase 260 test batch | brand dir, asset parity, install `admin_test`, css gap, png-park + ci-alias contracts | 528 tests, 0 failures | PASS |
| Install determinism + golden | `mix test double_install golden_diff idempotency --include scaffold` | 18 tests, 0 failures | PASS |
| Golden fixture sync | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date` | PASS |
| Example suite | `cd test/example && mix test --include example_app` | 433 tests, 0 failures | PASS |
| Demotion guards | `node --test scripts/ci/prohibitions/*.test.mjs`; `ci-demotion-observer.test.sh`; phase_230/234/260 contracts | 93/93; 19/19; 79 tests, 0 failures | PASS |
| CSS guards | conformance + token-completeness on the real file; `admin-css-conformance.test.sh` | PASS; PASS (100 tokens); 24/24 | PASS |
| Guard fails on planted defect (darwin) | planted hex + `transition: all` appended to a copy | exit 1 | PASS |
| Guard fails on planted defect (GNU) | `ubuntu:24.04` container, GNU grep 3.11: real file; planted hex; planted line-start raw px | exit 0; 1; 1 | PASS |
| Before/after catalog neutrality | after-mode capture on the final tree, `catalog-diff.sh` | `no differences` (62 files) | PASS |
| Diff script positive control | copy with one planted line and one removed file | 1 changed, 1 removed reported | PASS |
| Manifest integrity | re-hash 62 files; recompute pinned git tree hashes | 0 mismatches; trees match | PASS |
| Fresh generated host, CI invocation | `PORT=4017 admin-acceptance-smoke.sh --test all` (PG vars unset) | exit 0; 8 passed, 1 skipped by design; confirmation 1 passed; revoked-admin 1 passed | PASS |
| Fresh generated host, BGEN-04 slice | `PORT=4017 admin-acceptance-smoke.sh --test chrome` (run twice) | 1 failed both times, three explicit-dark soft assertions | FAIL (see W2; not the CI invocation) |

Not re-run (accepted on the strength of the artifacts above): the destructive `sigra.dep_off` leg of `mix ci`; the
generated-host `--test catalog` capture (its raw output from plan 11 was reused for the generated lane of my
after-run); the three Light/Dark/System screenshots (written unasserted by design; plan 11 describes them); the live
PNG positive control of plan 04 (corroborated instead by the PR-run logs showing the switch value reaching the shards).

## Probe Execution

SKIPPED: no `scripts/*/tests/probe-*.sh` exists and no plan declares one.

## Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| BGEN-01 | 06, 11 | Template/example/golden parity, refreshed example `sigra_auth.css`, parity test for every copied asset | SATISFIED | `asset_parity_test.exs`; `cmp` byte equality |
| BGEN-02 | 06, 11 | Double install byte-identical; `rebless_golden --check` clean under phx_new 1.8.8 | SATISFIED | `double_install_test.exs`; `--check` OK |
| BGEN-03 | 02, 03, 05, 11 | Before catalog, three tiers, pinned SHA, byte-identical to main, template CSS, no PNG | SATISFIED | SC-1 (W3 for the CI-artifact parenthetical) |
| BGEN-04 | 07, 09, 11 | L1: brand mark + explicit Light/Dark into shipped CSS, drop duplicates, verify in generated host, version stamp | SATISFIED | SC-3 (W1, W2) |
| BGEN-05 | 07, 10, 11 | L2: guards wired into `mix ci`/`fast_checks` or retired | SATISFIED | `mix.exs`; wired (owner decision #13) (W5) |
| BGEN-06 | 01, 04, 11 | Park PR, canary never allowlisted, no darwin recapture, merges before Phase 261 | SATISFIED | SC-4 (comparison-level mechanism; W4) |
| BGEN-07 | 08, 11 | Before/after text-diff report script | SATISFIED | `catalog-diff.sh` + test + my control |
| BGEN-08 | 08, 11 | `DesignGalleryLive` auth/email/status states, dev-only | SATISFIED | `catalog-*` section; example tests green |

All 8 IDs declared across the 11 PLAN frontmatters appear in REQUIREMENTS.md, marked `[x]` and mapped to Phase 260.
REQUIREMENTS.md maps no other ID to Phase 260, so there are no orphaned requirements.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (phase diff, excluding planning docs) | n/a | `TBD`/`FIXME`/`XXX` markers | none found | Debt-marker gate clean (0 hits, including inside the committed catalog) |
| (phase diff) | n/a | `TODO`/`HACK`/`PLACEHOLDER` | none found | |
| `scripts/ci/admin-css-conformance.sh` | CHECK 1 / CHECK 3 | line-anchored, whitespace-sensitive matchers | Warning | review WR-02, reproduced; advisory |
| `priv/templates/sigra.install/admin/sigra_admin.css` | active theme-switch segment | focus ring overridden by active-segment `box-shadow` | Warning | review WR-01; advisory, Phase 261 |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | before `assertShippedThemeRules` | no wait for LiveView connect | Warning | W2 |

Test-quality audit: no disabled tests among the requirement-linked test files (the `test.skip` matches are the park
contract test asserting the spec's own skip call). The catalog is a recorded baseline protected by manifest re-hash and
refuse-to-overwrite, deliberately not asserted equal to current sources, so it is not a circular test; the neutrality
claim is proven by an independent after-capture compared through the diff script.

## Human Verification Required

None. Nothing in this phase's success criteria requires a human beyond the owner confirmations already noted in W3
(accept or amend the SC-1 wording) and W4 (confirm the delegated merge approval), which are record-keeping, not UAT,
and do not gate the status.

## Gaps Summary

No gaps. All five roadmap success criteria hold in the repository, all eight BGEN requirements are satisfied, the
shipped-byte diff is exactly one additive stylesheet plus one golden copy, and the independent re-runs match the
SUMMARY claims (3157 and 433 test counts, `no differences` catalog, clean golden check). The warnings above are the
things I would act on before the milestone branch is pushed: fix the W2 race (one line), put the W1 shell-surface rule
into Phase 261's criteria, and settle the SC-1 parenthetical (W3).

---

_Verified: 2026-11-15T21:55:00Z_
_Verifier: Claude (gsd-verifier)_
