---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 11
subsystem: ci
tags: [phase-close, park-merge, adr-005, local-gate, fresh-host-smoke, catalog-neutrality, privacy-gate, process-budget, bgen-01, bgen-02, bgen-03, bgen-04, bgen-05, bgen-06, bgen-07, bgen-08]

requires:
  - phase: 260
    provides: "Plans 01 to 10: park PR #381 merged on main, deterministic installs and asset parity, the immutable before catalog, the catalog diff and gallery section, the L1 move into sigra_admin.css, the two CSS guards wired into mix ci"
provides:
  - "The merged park change (4154a913e6c31f54f357587553c0dc7846ebc915) is on the milestone branch via a local merge; nothing pushed"
  - "ADR 005 dated note under decision 7: authoring order, comparison-level mechanism, PR number, merge SHA and date"
  - "Full local gate green: mix ci with both CSS guards, the example suite, rebless_golden --check, prohibitions, observer, CSS self-tests"
  - "Fresh-host proof green and looked at; final-CSS browser truth green on the example (admin-theme and the non-snapshot gallery set)"
  - "Full after-mode catalog shows no differences against the committed before catalog (four lanes, 62 files), with a planted-difference control"
  - "Privacy gate and process-budget measurements over Phase 260's own commits, each with an observed control"
affects: [261]

actuals:
  tokens: 452
  tasks: 3
  commits: 3

# `commits: 3` is the MEASURED count of the persisted-ledger range. Plan 11 authored 2 of the 3 before this SUMMARY
# (the local merge commit bf7e11d07 and the ADR note 7c2c93bbe); the third is the park squash commit 4154a913e that the merge
# brought in from main, which plan 01 authored and plan 04 merged. Not rounded or reattributed.
plan_authored_commits: 2
plan_head_before: b1007f4d2d420e7801b4fbf9fb0807c3a255c1f5
plan_head_after: 7c2c93bbea91bc2c0ab2a9456671084995b38ae1

tech-stack:
  added: []
  patterns:
    - "Phase-close verification on Phase 260's own commits only: git log --first-parent --no-merges since the phase base, so a merged park change and unrelated main commits are excluded from the budgets"
    - "Run-time-derived privacy legs: the local user name, the maintainer address and the vendored book's authoring origin are derived from the environment at run time, matched against a planted self-test line, and never written into a file"

key-files:
  created: []
  modified:
    - .planning/decisions/005-brand-adoption-compatibility-policy.md

key-decisions:
  - "Merged origin/main into the milestone branch with a plain local merge (no rebase, no push); the six park files auto-merged with no conflict, and the park contract test (47 tests across four files) passed on the merged tree"
  - "The ADR note states the switch values exactly as ci.yml sets them: 1 (skip) on pull_request, push and schedule, 0 (compare) on workflow_dispatch, and unset (compare) in both recapture jobs; an earlier draft said unset on dispatch and was corrected against the live diff before commit"
  - "Smoke runs used the PG* and SIGRA_TEST_PG_* variables unset (the established plan 03, 05 and 09 behavior); the example dev boot used a throwaway database on the dockerized test Postgres because the shared local Postgres on 5432 reported too_many_connections during the smoke runs"
  - "Nothing outside the one ADR file was edited: CONTRIBUTING.md (nine legs vs the text's seven), the stale golden-alias sentence in MAINTAINING.md and the byte-pinned fixture were left alone, as the hand-offs from plans 06 and 10 direct"

patterns-established:
  - "Re-read a switch's values from the live diff before writing them into a policy record"

requirements-completed: [BGEN-01, BGEN-02, BGEN-03, BGEN-04, BGEN-05, BGEN-06, BGEN-07, BGEN-08]

coverage:
  - id: D1
    description: "The park PR is merged on main, its merge SHA is an ancestor of the milestone branch (local merge, nothing pushed), the park gating survived the merge, and ADR 005 carries the dated authoring-order and mechanism note"
    requirement: BGEN-06
    verification:
      - kind: other
        ref: "gh pr view 381 reports MERGED; git merge-base --is-ancestor 4154a913e6c31f54f357587553c0dc7846ebc915 HEAD exits 0; mix test phase_260_png_park_contract_test, phase_230_design_gallery_split_test, phase_234_playwright_inventory_contract_test, policy_docs_test: 47 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "The full local gate is green: mix ci runs both CSS guards and passes, the example suite passes with --include example_app, rebless_golden --check is up to date, and the prohibition, observer and CSS self-test suites pass"
    requirement: BGEN-02
    verification:
      - kind: other
        ref: "MIX_ENV=test mix ci exit 0 (3157 tests, 0 failures; admin-css-conformance PASS; admin-token-completeness PASS 100 tokens; install golden leg 65 tests, 0 failures); example suite 433 tests, 0 failures; rebless_golden --check 'OK: fixture is up-to-date'; node --test prohibitions 93 pass; observer 19 passed; both CSS self-test twins pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "A fresh generated host (phx_new 1.8.8, mix sigra.install, boot, real login) passes the whole smoke target, including the L1 assertions for brand mark and explicit Light, Dark and System rules from the shipped sigra_admin.css alone"
    requirement: BGEN-03
    verification:
      - kind: other
        ref: "scripts/ci/admin-acceptance-smoke.sh --test all exit 0: 8 passed and 1 deliberately skipped in the admin run, the confirmation journey 1 passed, the revoked-admin test passed after the revoke"
        status: pass
    human_judgment: true
    rationale: "The three Light, Dark and System screenshots are written unasserted by design and were viewed and described here; whether they look acceptable is a judgment. The computed-style assertions that back the rules are automated and passed."
  - id: D4
    description: "On the final combined CSS (plans 06, 08 and 09) the example's own browser truth is green against a booted dev server: admin-theme on chromium and the whole non-@snapshot design-gallery spec on the three admin-design projects, including the page-wide axe test"
    requirement: BGEN-03
    verification:
      - kind: other
        ref: "playwright tests/admin-theme.spec.ts --project=chromium --retries=0: 19 passed; tests/admin-design.spec.ts three admin-design projects --grep-invert '@snapshot' --retries=0: 42 passed (14 per project)"
        status: pass
    human_judgment: false
  - id: D5
    description: "A full after-mode catalog, including a freshly captured generated-host lane and a regenerated tier 2, shows no differences against the committed before catalog: no visible HTML changed in this phase"
    requirement: BGEN-07
    verification:
      - kind: other
        ref: "bash scripts/brand/catalog-diff.sh printed 'no differences' over 62 files (19, 20, 5 and 18 per lane); planted-difference control reported 1 changed file and --fail-on-diff exited 1"
        status: pass
    human_judgment: false
  - id: D6
    description: "The privacy gate over the Phase 260 diff (home paths, non-.test addresses, local user name, maintainer address, vendored book's authoring origin, no binary or SVG/PDF added) is clean with a planted self-match control per leg, and the process budget and shipped-byte diff hold on Phase 260's own commits"
    requirement: BGEN-08
    verification:
      - kind: other
        ref: "four privacy legs PASS with controls, re-run after this SUMMARY was written; lib and priv touched only at the template sigra_admin.css; .github untouched and no workflow added; scripts touched are exactly the four named; one golden rebless commit touching only the golden CSS path; lib untouched"
        status: pass
    human_judgment: false

duration: 14min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 11: Phase Close, Park Merge Reconciliation and Full Gate Summary

**The merged park PR is on the milestone branch with ADR 005 recording how it was authored, the full local gate, the fresh-host smoke, the example's final-CSS browser run and the before/after catalog (no differences) are all green, and Phase 260's own commits touch lib and priv only at the one shipped admin stylesheet.**

## Performance

- **Duration:** about 14 min (start 2026-11-15T21:12:24Z, end about 21:26Z)
- **Tasks:** 3 (Task 1 tracer, Tasks 2 and 3 auto)
- **Files modified:** 1 (the ADR) plus this SUMMARY. No source, script, workflow, fixture or golden file was touched.

## Accomplishments

- **Park merge reconciled (Task 1, tracer).** `gh pr view 381` reports MERGED; the squash `4154a913e6c31f54f357587553c0dc7846ebc915` is an ancestor of `origin/main` and, after `git merge origin/main`, of the milestone branch (local merge `bf7e11d07`, nothing pushed). The merge was clean: the six park files (`ci.yml`, `MAINTAINING.md`, three Playwright specs, the park contract test) came in with +472/-1, nothing under `lib/` or `priv/`. The four-file contract and policy test set passed on the merged tree (47 tests, 0 failures), so the park gating survived. Tracer verified end to end, expanding.
- **ADR 005 note (Task 1).** A dated note directly under decision 7 records that the park was authored first, in wave 1, as an independent branch with owner approval; that the mechanism is comparison-level (`SIGRA_PNG_COMPARE_SKIP`, `1` on `pull_request`/`push`/`schedule`, `0` on dispatch, unset in both recapture jobs) so axe, the three demo behavior tests and the generated-host smoke stay on the PR path; the PR number and merge date; and that reversibility is unchanged. Commit `7c2c93bbe`. No personal data and no local path.
- **Full local gate green (Task 2).** See the table below.
- **Fresh host proven and looked at (Task 3a).** `--test all` passed end to end; the three unasserted screenshots were opened and are described below.
- **Final-CSS browser truth (Task 3a2).** The example booted in dev mode on port 4021 with a throwaway database; `admin-theme.spec.ts` (19) and the non-snapshot gallery set across the three admin-design projects (42, including the first run of the page-wide axe test against the combined CSS) all passed. Server stopped and the database dropped afterwards.
- **Catalog neutrality (Task 3b).** Fresh generated-host raw (5 pages, 18 emails), regenerated tier 2 (23 tests), the after-mode writer (62 tests, 62 files), then `catalog-diff.sh`: `no differences`.
- **Privacy and budgets (Task 3c, 3d).** Recorded below with every control.

## Task Commits

On `milestone/v1.51-brand-identity-adoption`:

1. **Task 1: merge the park PR into the milestone branch** - `bf7e11d07` (merge, local only)
2. **Task 1: ADR 005 dated note under decision 7** - `7c2c93bbe` (docs)
3. **Tasks 2 and 3** produced no repository change by design (read-only verification; the only artifacts are gitignored outputs and this SUMMARY).

**Plan metadata:** the docs commit that carries this SUMMARY, STATE, ROADMAP and REQUIREMENTS follows this file.

## Task 2: Full local gate (recorded results)

| # | Command | Result |
| --- | --- | --- |
| 1 | `source tmp/db.env && MIX_ENV=test mix ci` | exit 0. Main leg: 33 doctests, 3 properties, 3157 tests, 0 failures, 12 skipped (26 excluded). Install golden leg: 65 tests, 0 failures. Guard lines present: `admin-css-conformance: PASS` (checks 1 to 3) and `admin-token-completeness: PASS - 100 tokens, :root == doc` |
| 2 | `cd test/example && MIX_ENV=test mix test --include example_app` | 433 tests, 0 failures (plan 06 recorded 419; plans 08 and 09 added tests). The logged `accept_invitation is not bound on branch=:invalid` error is the deliberate defensive-path test output, not a failure |
| 3 | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date (check mode).` The writer was never run |
| 4 | `node --test scripts/ci/prohibitions/*.test.mjs` | 93 tests, 93 pass, 0 fail |
| 4 | `bash scripts/ci/ci-demotion-observer.test.sh` | 19 passed, 0 failed |
| 5 | `bash scripts/ci/admin-css-conformance.test.sh` | 24 passed, 0 failed (Test G, no real-repo side effects, passed) |
| 5 | `bash scripts/ci/admin-token-completeness.test.sh` | 8 passed, 0 failed |

No failure occurred, so nothing needed diagnosing against `origin/main`. `git status --porcelain -- test/fixtures` is empty. The whole tree shows exactly one modified file, `.planning/config.json`, which is the owner's own uncommitted model-profile edit; it was left unstaged and untouched, so the plan's "git status --porcelain is empty" is met except for that one pre-existing owner edit.

## Task 3: Fresh-host proof and the three screenshots

`scripts/ci/admin-acceptance-smoke.sh --test all` (phx_new 1.8.8 and `mix sigra.install --yes Accounts User users --no-passkeys`, port 4017) exited 0: the admin run reported 8 passed and 1 skipped (the revoked-admin test is skipped there on purpose and run after the real revoke, where it passed), the generated confirmation journey passed (1), and the generated `check` task denied the revoked grant. The `too_many_connections` errors in the log come from the shared local Postgres on 5432 and did not affect any result.

The Playwright chrome test writes three screenshots with no assertion on them. All three were opened with the Read tool; none was compared or committed (they sit in the gitignored Playwright output directory).

- **Light (explicit light attribute, light colour scheme).** Warm off-white page. One lockup is visible at top left, drawn in dark ink; the light-on-dark variant is not visible. The nav groups and the three task cards are white panels with soft borders and dark text; the three call-to-action buttons are filled orange with white text; "No flagged accounts" is a pale green callout. The theme switch shows LIGHT, DARK and SYSTEM, with SYSTEM filled orange (see note below). Everything is legible.
- **Dark (explicit dark attribute, light colour scheme).** The panel colour differs from the light screenshot (near-black instead of white), the lockup has swapped (the pale variant is now the visible one and nearly vanishes on the still-light page, with one orange dot visible), and the switch pill and "Global" chip are dark-themed with the orange active segment. **The page itself did not go dark**: the background stays off-white and the headings and body text stay dark, so the text inside the dark panels is dark on dark and unreadable (the nav groups, the three task cards), while text outside panels is readable. This is the gap plan 09 recorded; it is worse than "does not look dark" (see Issues Encountered).
- **System (no attribute, emulated dark scheme).** The whole page is dark with light text, the pale lockup is the single visible lockup, panels are dark with a hairline border, the switch pill is dark with the orange active segment, and the "Global" chip uses light-orange text. System follows the emulated scheme and reads as a coherent dark page. One low-contrast item: the "No flagged accounts" callout text is dim on a dark green background (Phase 261 contrast work).

Note on the orange segment: it reads SYSTEM in all three, by design. The test sets and removes the theme attribute on the document element and leaves the stored preference alone, so the active segment stays the one the page loaded with. The assertions (passed) check that segment's colours (`rgb(253, 186, 116)` on `rgb(21, 21, 21)` text) in each state. Also in all three, content runs past the right edge of the 1280 px viewport capture (the "Jump to" control and card text are cut off); the screenshots are viewport crops and the generated shell still lacks about 49 layout classes (the shrink-only baseline from plans 05 and 09), which is the likely cause, not investigated here.

## Task 3: Final-CSS browser truth on the example

Booted the way `.github/actions/example-playwright-boot/action.yml` does: `MIX_ENV=dev`, `PORT=4021` compiled in, a throwaway database on the dockerized test Postgres, `deps.get`, `compile --warnings-as-errors`, `ecto.create`, `ecto.migrate`, `mix run priv/repo/seeds.exs`, server in the background, readiness and warm-up routes all responded.

- `tests/admin-theme.spec.ts --project=chromium --retries=0`: **19 passed** (1.2 m).
- `tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --grep-invert '@snapshot' --retries=0` (run with `CI=true` as the CI step sets it; it only changes snapshot tolerance, and no snapshot test runs): **42 passed** (57.6 s), 14 per project, including the page-wide axe test on each project and the L1 state-evidence tests. Never `--update-snapshots`.

The server was stopped and the throwaway database dropped; no process is listening on 4021 and no `sigra_p260*` database remains.

## Task 3: Catalog neutrality

| Lane | before | after |
| --- | --- | --- |
| tier1-library-admin | 19 | 19 |
| tier2-example-admin | 20 | 20 |
| generated-host-pages | 5 | 5 |
| generated-host-emails | 18 | 18 |

`tmp/catalog-raw` and `tmp/catalog-after` were removed first so nothing stale could mask a difference. Sequence: `--test catalog` on a fresh generated host, the example catalog test with `SIGRA_CATALOG_RAW_DIR` set (23 tests), `SIGRA_BRAND_CATALOG=after mix test test/sigra/brand/catalog_test.exs` with `CI` unset (62 tests, 62 files written), then `bash scripts/brand/catalog-diff.sh` printed `no differences` (rc 0). **Control:** a scratch copy of the after tree with one planted line in one generated-host page reported `Changed files (1): generated-host-pages/log-in.html`, and `--fail-on-diff` returned 1. The before catalog was not touched.

The SC-1 reconciliation recorded in `260-deferred-items.md` stands: ROADMAP SC-1's parenthetical "full HTML as a CI artifact" is produced by no plan, on purpose (RESEARCH Open Question 7). The committed, normalized text (62 files, about 660 KB) is the durable review artifact, because a CI artifact expires in 7 to 14 days and cannot be the baseline Phase 262 diffs against, and producing one would need a workflow edit the process budget forbids. The ROADMAP text itself is not edited here.

## Task 3: Privacy gate (each leg ran with its planted control)

Run before this SUMMARY existed and again after it was written, so the origin leg (which scans the phase planning directory too) covered it. The legs are the plan's verify block, held in a scratchpad script outside the repository; the home-directory prefixes are assembled from fragments inside the commands.

| Leg | Scope | Control | Result |
| --- | --- | --- | --- |
| Home-directory shapes | whole phase diff, phase planning directory excluded | planted `x <prefix>someone/y` line matched | PASS, no hit |
| Address-shaped tokens outside `.test`, `example.*`, `.invalid` and `Nx.png` image names | lines this phase added, phase planning directory excluded | planted `someone@corp.io` matched | PASS, no hit |
| Local user name (`id -un`, case-insensitive, whole word, fixed string) | whole phase diff, phase planning directory excluded | planted line containing the derived name matched | PASS, no hit |
| Maintainer address (`git config user.email`) | whole phase diff, phase planning directory excluded | planted probe file containing the derived address matched | PASS, no hit. An address **was** configured, so the leg ran; the "no address configured" skip line was not printed |
| Vendored book's authoring origin (derived from the `og:image` URL in `brand/index.html`) | whole diff and the phase planning directory (no exclusion) | planted line containing the derived origin matched | PASS, no hit |
| Binary and SVG/PDF metadata | files added by Phase 260's own commits | planted `a.png` matched; the added-file capture was non-empty | PASS, no png, woff2, svg or pdf added |

The name, address and origin values are derived at run time and are not written in this file or anywhere else. No hit was triaged because none occurred; hits from commits merged from main would have been recorded, and the merged park change produced none.

## Task 3: Budgets and shipped-byte diff (Phase 260's own commits)

Measured with `git log --first-parent --no-merges` over `7751d3b51..HEAD` (56 own commits touching 122 unique paths), captured into variables before comparing, so the merged park change and any unrelated main commits are excluded.

| Check | Result |
| --- | --- |
| `lib` and `priv` | exactly `priv/templates/sigra.install/admin/sigra_admin.css` |
| `lib` alone | empty |
| `.github` | no commit touches it; no commit adds a file under `.github/workflows` |
| `scripts` | exactly `scripts/brand/catalog-diff.sh`, `scripts/ci/admin-acceptance-smoke.sh`, `scripts/ci/admin-css-conformance.sh`, `scripts/ci/admin-css-conformance.test.sh` |
| `test/fixtures/install_golden` | exactly `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`, from one commit (`6e8a00dff`): exactly one golden rebless |

The merged park change (the squash commit's six files, `.github/workflows/ci.yml` among them) is on the branch only through the merge commit, which `--no-merges` on the first-parent walk does not traverse. No token value, logo, copy, `Components` markup or `Profile` key changed (plan 05's manifest pins the shipped CSS and logo hashes; the catalog shows no visible HTML change).

## ROADMAP SC-1 to SC-5 together

| SC | Statement (short) | Evidence |
| --- | --- | --- |
| 1 | Committed before catalog, neutral, no new PNG baselines | Catalog: 62 files, four lanes, `no differences` against a fresh after capture; no PNG added. The "full HTML as a CI artifact" parenthetical is the recorded departure above |
| 2 | Install twice is byte-identical; rebless check clean; asset parity | `mix ci` (double-install, asset-parity and install golden legs) green; `rebless_golden --check` up to date |
| 3 | Brand mark and explicit Light/Dark from the shipped stylesheet alone; guards in `mix ci` | Smoke L1 assertions passed in a real host; both guard PASS lines are in the `mix ci` output |
| 4 | Park PR merged with explicit owner approval before Phase 261 | PR #381 MERGED, merge SHA on `origin/main` and in this branch; two recorded owner approvals; canary not allowlisted; no darwin recapture; ADR note records the comparison-level mechanism |
| 5 | No token/logo/copy/Components/Profile change; ratchet, privacy and process budget hold; at most one rebless; fresh-host green | Budgets above; four privacy legs with controls; one rebless commit; `--test all` green |

## Deviations from Plan

### Auto-fixed Issues

None. No bug, missing-critical or blocking fix was needed.

### Verification approach that differs from the plan's literal wording

**1. [Task 3] Smoke runs used the `PG*` and `SIGRA_TEST_PG_*` variables unset.** The plan's verify block sources `tmp/db.env` before the smoke command. With it exported, the generated host's `Repo` still connects to `localhost:5432` while the Ecto tasks follow `PGPORT` (pre-existing script behavior, `260-deferred-items.md` plan 03 item 2, and the way plans 03, 05 and 09 ran it). Same three commands, reaching 5432.

**2. [Task 3a2] The example dev boot used the dockerized test Postgres with a throwaway database** (the `PG*` variables from `tmp/db.env` plus a new `PGDATABASE`), not the default 5432, because the shared Postgres on 5432 reported `too_many_connections` during the smoke runs. Same boot sequence otherwise.

**3. [Task 3a2] The gallery run set `CI=true`**, which the plan's command line omits but the ci.yml step sets. It only changes snapshot tolerances; no snapshot test runs under `--grep-invert '@snapshot'`.

**4. [Task 2 and 3] "`git status --porcelain` is empty" holds except for the owner's uncommitted `.planning/config.json` edit**, left untouched as instructed. Nothing else is dirty.

**Total deviations:** 0 auto-fixed, 4 documented. **Impact on plan:** none on scope; every success criterion is met.

## Issues Encountered

- **Explicit Dark in a generated host is worse than "does not look dark" (carried from plan 09, now seen).** The shipped `sigra_admin.css` has no `.sg-admin-shell` background, colour and min-height rule (that rule lives only in the example `app.css`, one of the 49 gap classes). With an explicit Dark attribute the panels turn near-black but the page background and the body and heading text keep their light-theme values, so text inside panels is dark on dark and unreadable (screenshot above). Before the plan 09 move, an explicit Dark attribute in a generated host did nothing at all (the readable light page); now it half-applies. System dark is coherent. Not fixed here: adding the shell surface rule is a shipped-byte change that would need a second golden rebless, which this plan prohibits and plan 09's scope (OQ2) excluded. **Recommendation:** make the `.sg-admin-shell` surface rule the first Phase 261 task, or an explicit Phase 261 acceptance criterion, so v1.51 does not ship a generated host whose Dark switch produces unreadable panels.
- The shared local Postgres on 5432 is saturated (`too_many_connections` noise in the smoke logs); it did not change any result.
- The example `_build/dev` was left compiled with `PORT=4021`; the next `scripts/uat/up.sh --dev` self-heals a frozen-port mismatch, and a plain `mix phx.server` in `test/example` needs `mix compile --force` with the intended port first.

## Authentication Gates

None.

## Known Stubs

None. This plan created no source files.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema surface.

**Threat model disposition:** T-260-23 (personal data, home paths, non-.test addresses or secrets in the Phase 260 diff) mitigated: the privacy legs above passed over the full phase diff with a planted control per leg, and no PNG, font, SVG or PDF was added. T-260-24 (process-budget creep, or park gating lost in the merge) mitigated: exact path-list assertions for `.github`, `scripts`, `lib` and `priv` held, and the park contract test passed on the merged branch.

## Handoff for Phase 261 and later

- **Phase 261 is unblocked:** the park is merged (SC-4 condition met), the before catalog is committed and neutral, and the CSS guards run in `mix ci`.
- **Phase 261 owns:** the dark-palette accent contrast (3.17:1 measured, plan 08, BTOK-03) and the explicit-Dark shell surface rule above. The four `catalog-*` previews are pinned to `data-theme="light"` until the dark palette passes AA.
- **Owed shipped-byte fixes before Phase 262 changes generated output** (none fixed in Phase 260, per `260-deferred-items.md`): the registration timing oracle, the passkey-options oracle, the generated confirm fix and the generated reset-request fix (`GET /users/reset-password` is a real HTTP 500 on a fresh host; its before is a one-line marker). If any lands first, re-capture the generated-lane before as a documented new capture decision with a fresh manifest.
- **Two generated email builders are not in the before** (`email_change_confirmation_email/3`, `email_change_notification_email/3`); a Phase 262 change to either has no before to diff against.
- **Left alone on purpose:** `CONTRIBUTING.md` still says `mix ci` chains seven legs (the alias has nine) and is hash-pinned by Phase 235 tests; the "golden alias runs two files" sentence in `MAINTAINING.md` and its byte-pinned fixture copy are stale; the `.test.sh` self-test twins are on no automated gate. All logged in `260-deferred-items.md` for a ratification decision, not edited here.
- **`mix sigra.fixture.rebless_golden --help` runs the writer** (an unknown switch is dropped); a small follow-up in `lib/`.
- **Park branch and worktree remain** (`ci/park-png-compare`, remote and local); cleanup is a separate decision. `playwright-github-pages.yml` still compares PNGs and will report drift after Phase 261 until baselines are recaptured in CI.
- **Nothing was pushed, tagged or released by this plan;** the milestone branch holds the local merge and is ahead of origin.

## Next Phase Readiness

Phase 260 is complete: 11 of 11 plans have summaries. Ready for Phase 261 (tokens, type, logo, favicon and contrast).

## Self-Check: PASSED

- Files exist (checked with `[ -f ]`): `260-11-SUMMARY.md` and the edited `005-brand-adoption-compatibility-policy.md`.
- Commits `bf7e11d07` (merge), `7c2c93bbe` (ADR note), `6e8a00dff` (the one golden rebless) and the park squash `4154a913e6c31f54f357587553c0dc7846ebc915` are ancestors of the milestone branch HEAD (`git merge-base --is-ancestor`).
- The four privacy legs were re-run after this SUMMARY was written: all PASS with their planted controls. A direct scan of this SUMMARY and the ADR for the derived name, address, authoring origin and home-directory shapes found nothing.
- Counts cited above (3157 tests, 433 example tests, 93 prohibition tests, 19 and 42 Playwright tests, 62 catalog files, 56 own commits) were re-read from the run logs and git output captured in the session scratchpad, not copied from earlier SUMMARYs.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
