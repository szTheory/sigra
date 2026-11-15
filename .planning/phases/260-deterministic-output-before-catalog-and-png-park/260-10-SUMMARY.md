---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 10
subsystem: infra
tags: [mix-ci, shipped-css, conformance-guard, token-completeness, contract-test, gnu-userland, bgen-05]

requires:
  - phase: 260
    provides: "Plan 07 guard extension (raw px and explicit-theme cases, the darwin-only \\d fix); plan 09 L1 move that made the real shipped sigra_admin.css pass both guards"
provides:
  - "mix ci runs scripts/ci/admin-css-conformance.sh and scripts/ci/admin-token-completeness.sh right after compile --warnings-as-errors and before test --exclude scaffold, so the PR-required Library tests shard (MIX_ENV=test mix ci) enforces them with zero .github diff"
  - "Sigra.Planning.Phase260CiAliasContractTest: a pure alias_entries/2 extractor and one shared check_alias/1 helper pin both entries, their position and the absence of the .test.sh twins, with four planted-source controls plus a well-formed control"
  - "Observed failure of the real alias: a planted raw hex in the shipped template CSS stopped MIX_ENV=test mix ci at admin-css-conformance: FAIL before any test step"
  - "Both guard self-tests (24 and 8 cases, including planted transition: all, raw hex, raw px case K and the explicit-theme cases) and both guards on the real post-L1 file pass inside ubuntu:24.04 (GNU grep 3.11, sed 4.9)"
affects: [260-11, 261, 262]

actuals:
  tokens: 2664
  tasks: 2
  commits: 2

plan_head_before: 8e98a6a2acce8a107ff7d26c0a7ccd3140063c0a
plan_head_after: f68aecef65facedf60cd8ffa92f68e414752927c

tech-stack:
  added: []
  patterns:
    - "An alias contract test reads the raw mix.exs text and extracts the alias list with a pure function, so the planted control runs the same extractor and the same assertion helper as the real check"
    - "A guard that was fixed for one userland is proven on the CI userland before it joins the PR gate, in addition to a darwin failure observed through the real alias"

key-files:
  created:
    - test/sigra/planning/phase_260_ci_alias_contract_test.exs
  modified:
    - mix.exs
    - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
    - test/sigra/planning/phase_233_library_economics_contract_test.exs
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md

key-decisions:
  - "Owner decision #13 is wire (see the verbatim text below); the two .test.sh twins stay out of the alias because Test G in admin-css-conformance.test.sh fails on a dirty tracked tree"
  - "CONTRIBUTING.md is not edited: its seven-leg wording is pinned by a live sha256 in the sealed Phase 235 ratification tests, so the stale leg count is logged, not fixed"

patterns-established:
  - "Wiring a guard into the PR gate is shown by three independent observations: a contract test over position and entries, one failure through the real alias before any test step, and the guard and its self-tests on the CI userland"

requirements-completed: [BGEN-05]

coverage:
  - id: D1
    description: "The ci alias runs both CSS guards after compile and before the test steps, and a planted raw hex in the shipped template CSS fails MIX_ENV=test mix ci at the conformance step before any test output"
    requirement: BGEN-05
    verification:
      - kind: other
        ref: "planted '.sg-planted-260-10 { color: #ff00aa; }' at the end of priv/templates/sigra.install/admin/sigra_admin.css; MIX_ENV=test mix ci exit 1; output 'admin-css-conformance: FAIL: raw hex color outside :root found: 1725:.sg-planted-260-10 { color: #ff00aa; }'; zero 'Running ExUnit' lines; restored with git checkout, git diff -- priv empty"
        status: pass
    human_judgment: false
  - id: D2
    description: "The alias contract is pinned by a test that can fail: entries, order (after compile, before test), twin absence, comment-only mention rejected"
    requirement: BGEN-05
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_260_ci_alias_contract_test.exs: red first (8 tests, 1 failure: ci alias lacks the conformance entry), green after the mix.exs edit (8 tests, 0 failures); four planted-source controls plus one well-formed control"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every check of both guards fails when it should on the CI platform, not only on darwin, against the real post-L1 shipped file"
    requirement: BGEN-05
    verification:
      - kind: other
        ref: "docker run --platform linux/amd64 ubuntu:24.04 (Linux x86_64, GNU grep 3.11, sed 4.9), repo mounted read-only: admin-css-conformance.test.sh 24 passed 0 failed (Tests A to K incl. K raw px, I2 look-alike selectors, J non-token declarations), admin-css-conformance.sh PASS (CHECK 1 to 3), admin-token-completeness.sh PASS (100 tokens), admin-token-completeness.test.sh 8 passed 0 failed; container exit 0, zero lines starting '  FAIL:'"
        status: pass
    human_judgment: false
  - id: D4
    description: "Nothing else in the ordinary library suite pins the old alias shape, and no .github, scripts or priv byte changed"
    requirement: BGEN-05
    verification:
      - kind: unit
        ref: "MIX_ENV=test mix test --exclude scaffold: 33 doctests, 3 properties, 3140 tests, 0 failures, 12 skipped; git diff --stat -- .github scripts priv empty; mix format --check-formatted over the four changed Elixir files exits 0"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 10: wire the two orphaned CSS guards into `mix ci` Summary

**`admin-css-conformance.sh` and `admin-token-completeness.sh` now run on every `mix ci` (right after compile, before any test), so the PR-required Library tests shard enforces raw-hex, raw-px, `transition: all` and token-drift rules on the shipped admin CSS with no `.github` diff; proven by a contract test, one observed failure through the real alias, and the guards plus their self-tests on `ubuntu:24.04`.**

## Owner decision #13 (Task 0), recorded verbatim

The decision checkpoint (wire or retire the orphaned CSS guards, recommendation `wire`) was presented to the user in chat. The user's own reply, verbatim:

> and then after that for all the things to open decisions, follow ur recs plz...

That is a delegation to the orchestrator's recommendation, which was `wire` (zero `.github` diff; enforced on every PR via `mix ci`). The resume signal was therefore treated as `wire`, and the plan proceeded. No `retire` path was taken.

## Performance

- **Duration:** about 20 min of continuation work (the Task 0 checkpoint was resolved before this agent started; the clock was not started at the first agent's launch, so this is an estimate, not a measurement). Most of the time was the `mix ci` run to the guard failure, the container run and the full suite.
- **Tasks:** 2 (Task 0 decision checkpoint, Task 1 tracer)
- **Files:** 1 created, 3 modified plus the phase deferral log; nothing under `lib/`, `priv/`, `scripts/` or `.github/`

## Accomplishments

- **Contract test first, seen red (Task 1, step 1).** `Sigra.Planning.Phase260CiAliasContractTest` extracts the `ci:` alias entries from the raw `mix.exs` text with a pure `alias_entries(source, alias_name)` (indent-agnostic, quote-tolerant so `"ci.install_golden": [` also reads, comment lines dropped) and judges them with one `check_alias/1` helper. Against the unmodified `mix.exs` the run was `8 tests, 1 failure`: `ci alias lacks \`cmd bash scripts/ci/admin-css-conformance.sh\``, and the planted-source controls and the twin-absence tests passed, so the red is for the intended reason.
- **The alias edit (step 2).** Two entries, `"cmd bash scripts/ci/admin-css-conformance.sh"` and `"cmd bash scripts/ci/admin-token-completeness.sh"`, sit between `compile --warnings-as-errors` and `test --exclude scaffold`, with a comment above the alias stating why and why the `.test.sh` twins are separate (Test G fails on a dirty tracked tree). Same `cmd bash` idiom as `sigra.dep_off`. The contract test went `8 tests, 0 failures`.
- **Observed failure through the real alias (step 3).** A throwaway rule `.sg-planted-260-10 { color: #ff00aa; }` was appended to the end of `priv/templates/sigra.install/admin/sigra_admin.css`. `source tmp/db.env && MIX_ENV=test mix ci` exited 1 after `compile`, printing `admin-css-conformance: FAIL: raw hex color outside :root found:` and `1725:.sg-planted-260-10 { color: #ff00aa; }`, followed by the `Mix.Tasks.Cmd` exit; the log has zero `Running ExUnit` lines, so no test step ran after the failure (the failure is early, not late: threat T-260-22). The file was restored with `git checkout -- priv/templates/sigra.install/admin/sigra_admin.css` and `git diff -- priv` is empty.
- **CI-userland proof (step 4).** `docker run --rm --platform linux/amd64 -v "$(pwd)":/w:ro -w /w ubuntu:24.04` (Linux x86_64, GNU grep 3.11, sed 4.9): `admin-css-conformance.test.sh` printed `Results: 24 passed, 0 failed` (Tests A to K, including the raw-px case K and its allowlist case, the I2 look-alike selectors and the J non-token declarations), `admin-css-conformance.sh` passed CHECK 1 to 3 on the real post-L1 file, `admin-token-completeness.sh` passed (100 tokens, `:root == doc`), `admin-token-completeness.test.sh` printed `Results: 8 passed, 0 failed`. Container exit 0, no line starting `  FAIL:`. This is the proof that CHECK 3 and the explicit-theme cases fail where they should on the PR runner's userland; the darwin `mix ci` observation alone would not show it.
- **Wider gate.** `MIX_ENV=test mix test --exclude scaffold`: 33 doctests, 3 properties, 3140 tests, 0 failures, 12 skipped. The planning, brand and doc-contract directories (651 tests) pass.

## Task Commits

1. **Task 0: owner decision #13** - no commit (decision recorded above)
2. **Task 1 (tracer): alias entries, contract test, pin updates** - `c6dca6439` (feat)
3. **Deferral log: stale CONTRIBUTING leg count, ungated twins** - `f68aecef6` (docs)

**Plan metadata:** docs commit (this SUMMARY, STATE, ROADMAP, REQUIREMENTS).

Commit ledger (measured from the persisted base): `plan_head_before` `8e98a6a2acce8a107ff7d26c0a7ccd3140063c0a`, `plan_head_after` `f68aecef65facedf60cd8ffa92f68e414752927c`, `git rev-list --count` = 2. `actuals.tokens` is characters of added lines over the realized diff divided by 4 (10,656 / 4, deferral log included), against a plan estimate of 20,000; not rounded toward the estimate.

## Tracer gate

The tracer `<verify>` is automated-only (no `<human-check>`), so the gate re-ran it end to end before the plan closed: the contract test, both guards on the working tree, `test -z "$(git diff -- priv)"`, and the `ubuntu:24.04` command (run after the planted file was restored). All passed. Task 1 is the last task of this plan, so there is no expansion task to hold back.

## Test-first notes

Task 1 is red-first: the contract test was written and run against the unmodified `mix.exs` before the alias edit and failed on the real alias lacking the guard entry (above), then went green, so the TDD red evidence is the executed ExUnit output. The planted-source controls are in the same module: a source without the guards, guards placed after the test steps, a comment that only mentions the commands, a `.test.sh` twin wired in, and a well-formed source that must be accepted (so the helper is not vacuously failing).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two existing contract tests pinned the exact `ci` leg list and failed on the planned alias change**
- **Found during:** Task 1, wider run of `test/sigra/planning/`
- **Issue:** `phase_198_contributor_dx_contract_test.exs` (198-01, "ordered seven-leg contributor gate exactly once") and `phase_233_library_economics_contract_test.exs` ("scaffold modules have one explicit ci.install_golden receiver...") assert the exact list of `ci` alias entries. The owner-approved alias change legitimately invalidates both lists. Both failed with the new alias as the only diff.
- **Fix:** Added the two guard entries, in position, to both expected lists with a comment naming Phase 260; renamed the 198-01 title so it no longer claims "seven-leg" (it now says seven legs plus the two CSS guards). The assertions are otherwise unchanged, so the "ordered" and "exactly once" intent is preserved.
- **Files modified:** `test/sigra/planning/phase_198_contributor_dx_contract_test.exs`, `test/sigra/planning/phase_233_library_economics_contract_test.exs`
- **Commit:** `c6dca6439`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact on plan:** two extra test files in the task commit (the plan's `files_modified` listed only `mix.exs` and the new test); no scope or acceptance change. `git diff --stat -- .github scripts priv` is empty.

### Implementation choices that differ from the plan's literal wording

- **The extractor regex is indent-agnostic and quote-tolerant**, not anchored to the six-space indent of the real `mix.exs`. The first version only matched the real indentation, so the planted-source controls (heredocs at a different indent) would have extracted nothing and "failed" for the wrong reason. Caught before the red run and fixed, so the red run reflects the real alias, not an extraction miss. A sibling-alias test (`ci.install_golden`) keeps the extractor honest for the quoted-key form.
- **A `CONTRIBUTING.md` wording fix was deliberately not made.** See Issues Encountered.

## Issues Encountered

- **`CONTRIBUTING.md` now says "exactly seven legs", the alias has nine.** The doc cannot be corrected inside this plan: the Phase 235 source-complete test hashes the live file (`33d045c1...`, "immutable digest drift") and the Phase 235 terminal test requires the line-74 sentence verbatim; the Phase 233 receipt carries the same digest as data. A fix is a re-baseline of sealed v1.47 ratification pins, which is not this plan's call. Logged in `260-deferred-items.md` (plan 10, item 1) for plan 11 or a follow-up.
- **The `.test.sh` twins are on no gate.** By design (owner decision plan text; Test G fails on a dirty tracked tree). They were run on darwin and on `ubuntu:24.04` for this plan; nothing re-runs them automatically. Logged as item 2 of the plan 10 deferral section.
- `.planning/config.json` carries an unrelated uncommitted edit that pre-dates this plan; it was left unstaged and untouched.

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No endpoint, auth path, file-access pattern or schema was added. T-260-22 (guard wired but never executed, or executed after tests): mitigated and observed. The contract test pins entries and position (after `compile`, before `test --exclude scaffold`); the planted raw hex failed the real `mix ci` at the conformance step before any ExUnit output; the planted defect was restored byte-for-byte (`git diff -- priv` empty).

## Verification Run

| Check | Result |
| --- | --- |
| Contract test red before the edit | 8 tests, 1 failure (alias lacks the conformance entry) |
| Contract test green after the edit | 8 tests, 0 failures |
| `MIX_ENV=test mix ci` with planted raw hex | exit 1, `admin-css-conformance: FAIL`, no ExUnit output after it |
| Planted file restored | `git diff -- priv` empty |
| `ubuntu:24.04` (GNU grep 3.11, sed 4.9): conformance self-test | 24 passed, 0 failed |
| `ubuntu:24.04`: both guards on the real file | PASS, PASS (100 tokens) |
| `ubuntu:24.04`: completeness self-test | 8 passed, 0 failed |
| `mix test --exclude scaffold` | 3140 tests, 0 failures, 12 skipped |
| `mix format --check-formatted` (four Elixir files) | exit 0 |
| `git diff --stat -- .github scripts priv` | empty |

## Self-Check: PASSED

- FOUND: `test/sigra/planning/phase_260_ci_alias_contract_test.exs`, `mix.exs` (two guard entries), this SUMMARY
- FOUND: commits `c6dca6439`, `f68aecef6` (ancestors of HEAD)
- `git diff -- priv .github scripts` empty; no home path or personal name in the committed files
