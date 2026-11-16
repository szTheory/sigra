---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 18
subsystem: docs
tags: [enumeration-claims, readme, password-reset-guide, claims-register, doc-contract-test, gap-closure, zero-shipped-bytes, phase-gate]

requires:
  - phase: 259-compatibility-policy-pinned-source-and-copy-contract
    provides: example-host repairs and parity rows for the reset request (Plan 259-14) and the confirmation resend (Plan 259-15), the named-surface rule (Plan 259-16), the generated-host todos wired to the registry (Plan 259-17)
provides:
  - README Enumeration row naming password-reset requests among the tested cases (single attempt, example application) and listing the generated code as not covered
  - password-reset guide scope paragraph rewritten to the example-application bound, with the false "tests do not currently run a comparison" clause removed and one sentence under the Step 1 snippet saying the generated context takes the email as a string
  - claims_docs_test updated moduledoc, README-row and reset-scope assertions, a retired false clause, and planted controls
  - ADR 006 register cells for the reset, mfa and confirmation-resend rows aligned, and the stale Limitations claim removed
  - deferred-items.md resolution notes for the example-host items and the "still open for the generated host" pointers
  - the whole phase gate run once, green, with no owner override
affects: [259-VERIFICATION, BCOPY-03, BCOPY-07]

actuals:
  tokens: 6625
  tasks: 2
  commits: 2

plan_head_before: fb7586149a3d3669d06d52320a0530b62c40d17b
plan_head_after: 3a357f164fe0e1a2a458b9757a4c2d55ca3a9b6d
commits: 2

tech-stack:
  added: []
  patterns:
    - "A published sentence is retired as a FALSE STATEMENT, not only as an unbounded claim: the old 'tests do not currently run a comparison' clause went into the @retired map, and the in-memory planted-phrase test now expects it among the phrases the sweep families do not describe"
    - "Docs restate only the dimensions a parity row compares (status, redirect, flash, page, single attempt) and say where it ran (example application); the register keeps the example-host-only and counted-separately notes the README does not carry"

key-files:
  created: []
  modified:
    - README.md
    - guides/flows/password-reset.md
    - test/sigra/brand/claims_docs_test.exs
    - .planning/decisions/006-name-clearance-search-log-and-claims-register.md
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md

key-decisions:
  - "The README row says 'password-reset requests' (hyphenated) in the tested set and carries no confirmation-resend mention: its row is example-host evidence about a payload email being ignored, and no published claim rests on it."
  - "The guide's scope paragraph keeps its opener, single-attempt bound, timing and rate-limit not-covered items; the false clause was replaced by the example-application bound, which names the compared dimensions (status, redirect, flash, page) and tells the reader to check their own request page."
  - "The Step 1 snippet was NOT rewritten (it still passes a looked-up user); one plain sentence under it says the generated context takes the email as a string and to check this against the generated code."
  - "No sweep allow-list entry was added; the new wording passed the sweep as written."
  - "The ADR Limitations bullet carries a dated 'As of 2026-11-15' marker, in the record's own amend-in-place-with-a-date style."

patterns-established:
  - "When a retired phrase is a false statement rather than an unbounded claim, extend the in-memory planted-phrase test's expected remainder instead of weakening the sweep"

requirements-completed: [BCOPY-03, BCOPY-07]

coverage:
  - id: D1
    description: "README Enumeration row names password-reset requests as tested at a single attempt in the example application, lists timing, repeated attempts, registration, passkey sign-in and the generated code under Not covered, and no longer lists reset requests there; the password-reset guide scope paragraph is bounded to the example application with the generated-app caveat, and one sentence under the Step 1 snippet says the generated context takes the email as a string"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "test/sigra/brand/claims_docs_test.exs#the README row names password-reset requests as tested, not under Not covered"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/claims_docs_test.exs#the password reset scope bounds the comparison to the example application"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/claims_docs_test.exs#no claim unit (paragraph, table row or list item) makes an unqualified enumeration claim"
        status: pass
    human_judgment: true
    rationale: "The tests lock the key phrases, the bounds and the sweep, but no test compares the prose to the registry's compare lists; whether the wording claims exactly what the parity rows prove and no more is for the verifier to read against test/fixtures/brand/public-surfaces.json."
  - id: D2
    description: "claims_docs_test carries the new covered set in its moduledoc, asserts the README row and reset scope, and retires the false clause so it cannot return; a planted copy of the clause is reported and the in-memory planted-phrase test accounts for it"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "test/sigra/brand/claims_docs_test.exs#the retired false clause is registered for the password reset guide and reported when planted"
        status: pass
      - kind: other
        ref: "RED run before the doc edits: 49 tests, 4 failures, all on the new assertions; GREEN after: 336 tests in test/sigra/brand, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "ADR 006 register cells for the reset request, mfa-challenge and confirmation-resend rows describe the docs as they now read and state the counted-separately and example-host-only bounds; the stale Limitations claim is replaced; every row status still agrees with the registry"
    requirement: BCOPY-03
    verification:
      - kind: unit
        ref: "test/sigra/brand/name_clearance_test.exs (18 tests, 0 failures, includes the status-agreement and example-host-limitation checks)"
        status: pass
    human_judgment: false
  - id: D4
    description: "deferred-items.md records the 259-07 example-host items as resolved by Plans 259-14 and 259-15, corrects the generated-confirm sentence for the LiveView flavor from the Plan 259-17 fresh read, and marks 259-13 item 1 and 259-10 item 2 as still open for the generated host and tracked by the 259-17 todo"
    requirement: BCOPY-03
    verification:
      - kind: other
        ref: "acceptance greps: Resolved count 2 (control: 0 at HEAD), 'Still open for the generated host' count 2, one removed line (the extended opening sentence), every cited path and line resolved"
        status: pass
    human_judgment: true
    rationale: "The notes are prose records of source readings (generated host read in source, not executed); no test asserts them."
  - id: D5
    description: "The whole phase gate passes: the full example suite, MIX_ENV=test mix ci, the zero-shipped-bytes gate and every privacy leg, with no owner override written"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app: 391 tests, 0 failures"
        status: pass
      - kind: integration
        ref: "MIX_ENV=test mix ci from the repo root: exit 0 (format, deps checks, compile --warnings-as-errors, 2985 tests 0 failures 12 skipped, install golden 65 tests 0 failures, sigra.dep_off)"
        status: pass
    human_judgment: false

duration: ~4min
completed: 2026-11-15
status: complete
---

# Phase 259 Plan 18: Docs, register and deferred items aligned with the repaired registry Summary

**The README Enumeration row and the password-reset guide now say what the parity rows prove (sign-in, magic-link and password-reset requests, single attempt, example application, generated code not covered), the false "tests do not currently run a comparison" sentence is retired and guarded, ADR 006 and deferred-items.md agree, and the whole phase gate ran green with no owner override.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-11-15T14:14:11Z
- **Completed:** 2026-11-15T14:18Z
- **Tasks:** 2 (Task 1 `tdd="true"`, Task 2 `auto`)
- **Files modified:** 5 (0 created apart from this SUMMARY)
- **Shipped bytes changed:** 0 (nothing under `lib/`, `priv/`, `brandbook/`, `brand/`, `.github/`, `scripts/`)

## Accomplishments

- **README row.** Only the Enumeration table row changed: sign-in, magic-link and password-reset requests are tested, in the example application, to show the same message for an existing and an unknown address at a single attempt. Not covered now reads: timing, repeated attempts (lockout and rate limits), registration, passkey sign-in, and the code generated into your own application (the example application is a hand-maintained copy). Confirmation resend is not mentioned. No enumeration-safety label.
- **Guide scope paragraph.** Still exactly one paragraph, opener unchanged. The final clause was replaced: Sigra's tests compare the request screen for an existing and an unknown address (same response status, redirect, flash and page) for a single attempt in the example application only, which is a hand-maintained copy and not the code generated into your app, so check the request page in your application. Not covered: response timing; and repeated requests, because the optional rate limiter only counts addresses that have an account. The Step 1 snippet and the rate-limit section were not touched; one sentence under the snippet says the generated `deliver_user_reset_password_instructions/2` takes the email address as a string (only function head requires a binary), so pass the submitted email, and check this against the generated code.
- **Doc-contract test.** Moduledoc covered set updated; README-row test extended with a `[tested, not_covered]` split (reset requests in the first half, absent from the second, the other not-covered items present) and a planted-failure control; reset-scope test asserts "example application", "single attempt", "generated into your app" and the absence of the retired clause; the retired clause is registered for the guide with its own planted control.
- **Register.** The reset row's "Where it appears" cell now describes the README row and guide scope paragraph as they read (no more "README lists it as not covered" or "is meant to show"); the mfa row says it is counted separately from the account-existence surfaces and cannot stand in for them; the confirmation-resend row keeps Plan 259-15's wording and adds example-host-only and counted-separately (it proves a payload email is ignored, not that an existing and an unknown address answer alike). The Limitations bullet no longer says the registry records two cases where the example cannot complete a flow; it says the example host was repaired for those two flows, a generated host may still differ, and the generated reset request page is tracked as a defect.
- **Deferred items.** Original text of every item kept (the only removed line is the opening sentence, which was extended). 259-07 item 1 and item 2 carry dated "Resolved (2026-11-15), in the example host only" notes; item 2 also carries the correction that its generated-host sentence is superseded for the LiveView flavor (Phase 246, commits `6be7eff6b` and `590eb4ed3`, with the cited generated-source lines, all resolved when checked). 259-13 item 1 and 259-10 item 2 carry "Still open for the generated host; now tracked by the todo created in Plan 259-17". 259-07 item 3, 259-10 item 1 and all 259-12 items are untouched.

## Task Commits

1. **Task 1: Reword the README row and the guide scope, align claims_docs_test** - `cdede986d` (docs)
2. **Task 2: Align the register and resolve the deferred items** - `3a357f164` (docs)

The phase gate (example suite, `mix ci`, zero-bytes, privacy legs) is a no-file-change step and has no commit of its own.

**Plan metadata:** the SUMMARY commit that follows this file, then a STATE/ROADMAP/REQUIREMENTS commit.

## TDD Evidence

**Task 1 RED, observed before any doc edit.** The test file was edited first, the docs left at HEAD, and `mix test test/sigra/brand/claims_docs_test.exs` ran: 49 tests, 4 failures, each on a new assertion for the intended reason: the retired clause is still in the guide (twice: the registered-and-planted test and the retired-phrase check), the reset scope lacks "example application", and the README row lacks "password-reset requests". The other 45 passed, so this was not a compile or load fault. Semantic assessment: all four targets executed and failed on the planned defect. This RED was not run through `gsd_run check tdd-red-evidence` (ExUnit output is not a supported report format, and the plan is `type: execute`).

**Task 1 GREEN:** after the README, guide and sentence edits, `claims_docs_test` plus `name_clearance_test` ran 67 tests, 0 failures; the whole `test/sigra/brand` directory ran 336 tests, 0 failures (`copy_contract_test` scans the same README and guides and stayed green).

**Controls.** The README after-"Not covered" check printed 1 against `git show HEAD:README.md` and 0 against the edited file, so it can fail. The guide's old clause printed 1 at HEAD and 0 after. The safety-label scan matched a planted label.

### TDD Gate Compliance

Task 1 is `tdd="true"` but the plan specifies one `docs(259-18)` commit for README, guide and test together, so there is no separate RED `test` commit. The RED is the observed failing run above. The plan is `type: execute`, so no plan-level gate sequence is mandated. Flagged here rather than hidden.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The in-memory planted-phrase test would have gone red once the false clause was retired**
- **Found during:** Task 1, while writing the test edits (before the RED run)
- **Issue:** `the retired strings are flagged when planted in memory` asserted `retired -- detectable == Map.fetch!(@retired, @readme)`, i.e. that the README's vague row is the only retired phrase the sweep families do not describe. The new retired clause is a false statement, not an unbounded enumeration claim, so `unbounded?/1` does not describe it and the assertion would fail.
- **Fix:** the expectation now sorts both sides and expects the README entries plus the new clause; the comment names both. The sweep families and the allow-list were not touched.
- **Files modified:** `test/sigra/brand/claims_docs_test.exs`
- **Commit:** `cdede986d`

**2. [Rule 1 - Bug] First register wording tripped an acceptance criterion**
- **Found during:** Task 2 acceptance run
- **Issue:** the reset row's "Where it appears" cell said the README "lists the generated code as not covered", and the criterion requires the phrase "not covered" to be gone from that row (it counted 1, expected 0).
- **Fix:** reworded to "among what is not compared"; recount 0, `name_clearance_test` re-run green (18 tests).
- **Files modified:** `.planning/decisions/006-name-clearance-search-log-and-claims-register.md`
- **Commit:** `3a357f164` (fixed before the commit)

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug). **Impact:** none on scope; both inside the plan's own files.

## Issues Encountered

- The first zero-shipped-bytes control I tried (a diff over `HEAD~30..HEAD~20`) printed 0 lines because that range never touched `lib/`, so it proved nothing. Replaced with the last commit that did touch `lib/` (`bf507137b`): its diff is non-empty (2 lines), while the same pathspec against the base `62ef40442` is empty.
- The example suite logs several `GenServer terminating ... accept_invitation is not bound on branch=` errors. They are the intended output of the structural-defense tests (391 tests, 0 failures), not failures.
- The plan names the base commit `62ef40442` (HEAD when planned); the branch has since moved, and every check against it covers the whole gap-closure set, not only this plan.
- Negative checks use `test -z "$(...)"`, never `wc -l | grep -qx 0`, and each was shown able to fail.

## Verification Results

| Check | Result |
|-------|--------|
| `claims_docs_test` RED (tests first, docs at HEAD) | 49 tests, 4 failures, all on the new assertions |
| `claims_docs_test` + `name_clearance_test` after the doc edits | 67 tests, 0 failures |
| `mix test test/sigra/brand` | 336 tests, 0 failures |
| `mix format --check-formatted` on the test file | pass |
| Task 1 acceptance (8 criteria) | all pass; controls: HEAD README copy prints 1, HEAD guide prints 1, planted label matches |
| Task 2 acceptance (stale Limitations gone, reset row, Resolved/Still-open counts, parity count, three `not_proven` rows) | all pass; controls: HEAD still has the stale bullet (1), HEAD Resolved count 0, HEAD reset row 'not covered' 1 |
| Registry end state | 5 parity rows; `not_proven` is exactly `magic-link-rate-limit`, `password-reset-rate-limit`, `lib-moduledoc-claims` |
| Example suite `cd test/example && MIX_ENV=test mix test --include example_app` | 391 tests, 0 failures |
| `MIX_ENV=test mix ci` (repo root) | exit 0: format, deps checks, `compile --warnings-as-errors`, 2985 tests 0 failures 12 skipped, install golden 65 tests 0 failures, `sigra.dep_off` |
| Zero shipped bytes vs `62ef40442` (lib, priv, brandbook, brand, .github, scripts) | pass; control: last commit touching `lib/` has a non-empty diff |
| Privacy: home-path leg over the diff outside the phase dir | pass; planted `/Users/someone/y` matched |
| Privacy: personal name over the diff | pass (self-match control passed) |
| Privacy: personal name over the vendored brand tree (recursive) | pass (tracked-tree sample non-empty, recursive self-match passed) |
| Privacy: vendored origin over the whole diff and the phase directory | pass (self-match control passed) |
| Privacy: configured maintainer address | pass (an address was configured, so the leg ran and did not skip; self-match control passed) |
| Privacy: address-shape scan over added lines | pass (planted `corp.io` shape survived the filters) |
| Scope: files changed outside `test/example`, `test/fixtures`, `test/sigra/brand`, `README.md`, `guides/flows`, `.planning` | none |
| Failures naming `enumeration_parity_test`, `claims_docs_test`, `name_clearance_test`, `reset_password_live_test` or `confirmation_live_test` | none |
| Owner override written | none |

No failure appeared that needed the origin/main comparison, so none was run.

## Known Stubs

None. No placeholder, hardcoded empty value or unwired data source in any file touched (a scan of the added lines for TODO, FIXME, placeholder and "coming soon" found nothing). No `.planning/WINDOWS.md` entry was opened.

## Threat Flags

None. No `lib/` or `priv/` byte changed. The threat register is mitigated: T-259-57 (the wording is bounded to the example application, single attempt and the compared dimensions with an explicit generated-app caveat, the confirmation resend is not mentioned publicly, and the sweep and the new assertions guard it), T-259-58 (the false clause is retired and guarded, the register status is cross-checked against the registry, deferred-items carries resolution notes), T-259-59 (the existing planning-citation check passed over README and guides; the new wording cites none) and T-259-60 (the sweep allow-list stays empty; nothing was added).

## Handoff

- **Verifier (Phase 259, SC-4 enumeration truth):** the five parity rows split three ways: three account-existence probes (password sign-in, magic-link request, password-reset request), one payload-ignored probe (confirmation resend) and one code-kind probe (mfa-challenge), the latter two counted separately in the register and never cited as account-existence evidence; the positive controls were shown red; `259-VERIFICATION.md` needs no override. The one judgment call for the verifier is D1: read the README row and the guide scope paragraph against the `compare` lists in `test/fixtures/brand/public-surfaces.json`.
- **Still open, not part of this phase:** the generated host's reset request page (route without `:new`, user struct passed to a binary-only head) and the non-live confirm controller flavor are tracked by the two Plan 259-17 todos and are read in source, not executed. A fix needs a `lib/` and `priv/` change, a golden rebless under phx_new 1.8.8 and the guide snippets (the guide's Step 1 snippet still shows the user-struct call; one added sentence says what the generated context takes). The two rate-limit rows stay `not_proven`.
- **This was the last plan of the phase:** `requirements.ready-ids` reports BCOPY-03 and BCOPY-07 ready (no sibling plan declaring them lacks a SUMMARY).

## Self-Check: PASSED

All five modified files exist; commits `cdede986d` and `3a357f164` are ancestors of HEAD (a planted bogus hash `deadbeef0` is reported MISSING). The measured commit count from the on-disk ledger is 2.

---
*Phase: 259-compatibility-policy-pinned-source-and-copy-contract*
*Completed: 2026-11-15*
