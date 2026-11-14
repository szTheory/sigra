---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 10
subsystem: docs
tags: [docs, enumeration, honest-claims, exunit, doc-contract, sweep]

requires:
  - phase: 259-07
    provides: the public-surfaces registry whose parity rows bound what the docs may claim
  - phase: 259-08
    provides: the copy baseline that keeps new prose free of lexicon words
  - phase: 259-13
    provides: the fix-tracking todos that carry the library moduledoc over-claims this plan cannot edit
provides:
  - README Enumeration row and six guides, the demo-showcase guide and the example README reworded so each enumeration statement names the compared case (one message for an existing and an unknown address at a single attempt) and what is not covered
  - a "Scope of this claim:" paragraph in the registration, password-reset and login-and-logout guides
  - test/sigra/brand/claims_docs_test.exs, 37 tests: retired-phrase checks, scope-paragraph checks, an unbounded-claim recogniser, a repo-wide sweep (README, every guide, example README) and a planning-reference check, all with planted controls
affects: [259-11, 262, 263]

actuals:
  tokens: 7800
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 497a45246f90842a80b9267389a9c51e17940f39
plan_head_after: 4ddf13bbb30e03d2e1894c8eda70f78f51061d7d

tech-stack:
  added: []
  patterns:
    - "Qualifier rule: a paragraph may carry an enumeration safety word only if the same paragraph names the compared case or what is not covered; otherwise the sweep goes red"
    - "Shrink-only allow-lists: the planning-citation list holds one pre-existing pair and the sweep list is empty; a stale entry fails, and every hit is fixed by rewording, never by adding an entry"
    - "Mutation proof: the sweep was run against the pre-edit docs and named every old claim site by file and paragraph"

key-files:
  created:
    - test/sigra/brand/claims_docs_test.exs
  modified:
    - README.md
    - guides/flows/registration.md
    - guides/flows/password-reset.md
    - guides/flows/login-and-logout.md
    - guides/introduction/getting-started.md
    - guides/introduction/architecture.md
    - guides/introduction/code-walkthrough.md
    - guides/introduction/demo-showcase.md
    - test/example/README.md
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md

key-decisions:
  - "Claims are bounded to the three parity rows (password sign-in, magic-link request, MFA challenge). The password reset request screen is registered not_proven, so no doc says it is tested; the README lists it as not covered and the reset guide says Sigra's own tests do not compare that screen"
  - "Where the plan's literal wording was not what the source returns, the source won: the library primitive returns {:ok, :sent} (unknown address) or the token and URL (account), not a bare :ok, and a throttled reset returns {:error, :rate_limited}, not :ok"
  - "The sweep does not strip indented code. A reader still sees a claim in an indented example, so it is reworded (the reset guide's code comment was) rather than exempted"
  - "No registry id, todo path or .planning path appears in published text; the planning-citation check allows exactly one pre-existing README maintainer note and fails if that entry goes stale"

patterns-established:
  - "Doc-contract test module with pure helpers (unbounded?/1, unbounded_paragraphs/2, planning_refs/3) each proven against planted in-memory input before being trusted on the real files"

requirements-completed: [BCOPY-07]

coverage:
  - id: D1
    description: "README Enumeration row and the registration, password-reset and login-and-logout guides carry no retired unbounded phrase, and each guide has one 'Scope of this claim:' paragraph naming timing and the other uncovered dimensions"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/claims_docs_test.exs#retired unbounded phrases and #Scope of this claim paragraphs"
        status: pass
    human_judgment: false
  - id: D2
    description: "getting-started, architecture and code-walkthrough statements bounded; the generator-output code comment in the walkthrough untouched; architecture contract test green"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand test/sigra/architecture_guides_contract_test.exs test/sigra/guides_dx02_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "demo-showcase persona bullet and the example README Dave paragraph stop promising a property and state the compared case and its limits"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/claims_docs_test.exs#retired unbounded phrases"
        status: pass
    human_judgment: false
  - id: D4
    description: "Repo-wide sweep over README, every guide and the example README returns no unqualified enumeration claim, can go red (planted controls; mutation proof against the pre-edit docs), and its allow-list is empty and shrink-only"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/claims_docs_test.exs#unbounded-claim sweep and #sweep helpers (planted controls)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Whether each reworded sentence stays inside the claim the harness supports, and whether the two disclosures (duplicate registration can answer faster; the reset request screen is not compared by Sigra's tests) are wanted in published docs"
    verification: []
    human_judgment: true
    rationale: "A grep and a sweep prove the absence of unbounded phrases and the presence of qualifiers; whether the prose is accurate and appropriately candid is a reading judgment for the owner"

duration: 9min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 10: Honest enumeration claims in the published docs Summary

**The README, six guides, the demo-showcase guide and the example README now claim only what the parity registry proves (one message for an existing and an unknown address at a single attempt, on sign-in and magic-link requests), say what is not covered, and a 37-test doc contract with a repo-wide sweep keeps it that way.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-11-14T17:02:52Z
- **Completed:** 2026-11-14T17:12:00Z
- **Tasks:** 3 (Task 1 is the tracer)
- **Files:** 1 created, 9 docs modified, plus one entry appended to the phase `deferred-items.md`; zero bytes under lib/, priv/, brandbook/, brand/, .github/ or scripts/

## Accomplishments

- Task 1 (tracer): wrote the claims test first and ran it red for the intended reasons only (retired phrases present, scope paragraphs absent, README row unscoped), then reworded README, registration, password-reset and login-and-logout. Tracer gate: the task has no `gate="blocking-human"`, `human_verify_mode` is the end-of-phase default, auto mode is off and the `<verify>` is automated-only, so the verify was re-run (green) rather than checkpointed; logged "Tracer verified end-to-end - expanding".
- Task 2: getting-started, architecture and code-walkthrough bounded; the walkthrough's fenced generator-output comment ("prevent user enumeration attacks") is untouched.
- Task 3: demo-showcase and example README reworded; the sweep added over README, every `guides/**/*.md` and `test/example/README.md`.
- Mutation proof: with the pre-edit versions of all nine docs restored, the sweep and the retired-phrase test failed and named every old claim site by file and paragraph; the edits were then restored and the module went green.

## Task Commits

1. **Task 1: README and the three flow guides, with the claims test (tracer)** - `332c168f8` (docs)
2. **Task 2: Introduction guides** - `55cdf5484` (docs)
3. **Task 3: Demo-description claim sites and the repo-wide sweep** - `4ddf13bbb` (docs)

**Plan metadata:** the `docs(259-10)` close-out commit that carries this SUMMARY, `deferred-items.md`, STATE.md, ROADMAP.md and REQUIREMENTS.md.

## Owner review pending (non-blocking)

These are security-model wording changes in published docs. None blocks the plan; each is listed so the owner can accept or adjust the wording.

1. **README** Enumeration row: now says sign-in and magic-link requests are tested, in Sigra's example application, to show the same message for an existing and an unknown address at a single attempt; not covered: timing, repeated attempts (lockout and rate limits), registration, password reset requests and passkey sign-in. Question for the owner: the registry records passkey sign-in options as a known difference (a real existence oracle with a filed todo); the README says only "not covered". Say more, or leave the detail to the todo?
2. **registration.md**: intro, the `register/3` bullet and "handled for you" sentence lose the safety labels; the heading "Enumeration-safe error handling" becomes "Handling a duplicate email"; the advice paragraph is framed as the application's choice; a new "Scope of this claim:" paragraph says `register/3` only keeps the uniqueness error out of the changeset, a success signs the user in while a duplicate shows only a flash, and timing is not covered, with a duplicate able to answer faster than a new registration (backed by the existing duplicate-registration timing todo). Question: is publishing the timing difference wanted?
3. **password-reset.md**: library-primitive bullet restated by its real return shapes; the code-block comment, the "critical property" paragraph and the rate-limit sentence reworded; a new "Scope of this claim:" paragraph says the form is meant to show one message at a single attempt, and that timing, repeated requests (the limiter counts only addresses with an account) and an automated comparison of the request screen are not covered, the last because Sigra's own tests do not currently compare it. Question: is it right to publish that the reset request screen is not compared?
4. **login-and-logout.md**: lookup bullet drops the safety label; a new "Scope of this claim:" paragraph bounds the claim to one failed attempt on Sigra's example application and names lockout state (an existing account locks, an unknown address is never tracked) and timing as outside it.
5. **getting-started.md, architecture.md, code-walkthrough.md**: "prevents enumeration attacks", "public failures remain enumeration-safe", "enumeration-safe public failure" and the unknown-email promise on the enterprise branch are replaced by the compared-case wording or dropped.
6. **demo-showcase.md and test/example/README.md**: the Dave persona no longer promises an "enumeration-resistant response" or that the error hides whether the account exists, is locked or is unconfirmed; the example README states the compared case and that locked and unconfirmed states, repeated attempts and timing are not part of it.

**Library moduledoc over-claims remain in the shipped API documentation.** `lib/sigra/lockout.ex` (line 13, "Messages are enumeration-safe"), `lib/sigra/error.ex` (lines 7 and 138-141) and `lib/sigra/auth.ex` (lines 16, 132, 613 and 1097) state enumeration safety more broadly than the parity rows prove, and they ship in HexDocs. Phase 259 carries zero lib bytes, so this plan could not edit them. This is a stated limitation, not a resolved item; it is tracked by `.planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md` (Plan 259-13) and by registry row `lib-moduledoc-claims`. The generated templates also carry the same labels in code comments and docstrings (for example `priv/templates/sigra.install/core/auth.ex`), which are shipped bytes this plan does not touch.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Library primitive return value stated as the source returns it**
- **Found during:** Task 1
- **Issue:** The plan asked for "returns `:ok` whether or not the email exists". `Sigra.Auth.request_password_reset/3` returns `{:ok, :sent}` for an unknown address and `{:ok, {token, url}}` for an account (`lib/sigra/auth.ex:1112` for the spec, `:1125-1129` for the unknown-address branch); the generated context wraps both into `{:ok, :sent}`. A bare `:ok` would have been a second inaccuracy in the sentence being fixed.
- **Fix:** the bullet states those shapes.
- **Files modified:** guides/flows/password-reset.md
- **Commit:** `332c168f8`

**2. [Rule 1 - Bug] Throttled reset stated as `{:error, :rate_limited}`, not `:ok`**
- **Found during:** Task 1
- **Issue:** The plan asked for "throttled requests return :ok". The library and the generated context return `{:error, :rate_limited}` (`lib/sigra/auth.ex:1131-1133`, `priv/templates/sigra.install/core/auth.ex:465`); the old guide sentence was wrong about this too.
- **Fix:** the sentence says the request is throttled, never enqueues the email, and the library reports `{:error, :rate_limited}`; it keeps the plan's point that only addresses with an account are counted, so request counts can differ.
- **Files modified:** guides/flows/password-reset.md
- **Commit:** `332c168f8`

**3. [Rule 1 - Bug] The code-block comment says "flash message", not ":ok"**
- **Found during:** Task 1
- **Issue:** The plan suggested "# Same :ok whether or not the email exists", but the comment sits above a `put_flash` and redirect, where `:ok` would be inaccurate.
- **Fix:** "# Same flash message whether or not the email exists".
- **Files modified:** guides/flows/password-reset.md
- **Commit:** `332c168f8`

### Plan wording overridden by the registry (must-have truth 1 wins)

- **README Enumeration row and the reset guide's scope paragraph.** The plan said the password-reset request screen is tested to show the same message. The Plan 07 registry records `password-reset-request` as `not_proven` (the example host cannot drive it), and the Plan 07 SUMMARY says this plan may cite only what the three parity rows prove. So the README names sign-in and magic-link requests as tested and lists password reset requests as not covered, and the reset guide says the form is meant to show one message while Sigra's own tests do not compare that screen. This is the honest reading of "claim no more than is proven".

### Interpretation choices

1. **In-memory controls instead of a git-history check inside the test.** Task 2 asked for a positive control that a `git show` of the HEAD version proves the retired strings existed. A test that needs commit `aeda7273d` fails in a shallow CI checkout, so the ExUnit module plants each retired phrase in memory and the git controls were run as shell acceptance checks instead (each printed 1).
2. **The sweep keeps indented code.** The plan text says the sweep strips fenced and indented code; the Task 3 helper spec says fenced code and HTML comments. The stricter reading was implemented, so a claim in an indented example still counts. No indented block in the docs carried one after rewording.
3. **Scope paragraph wording is checked loosely.** The test asserts the bold opener, one occurrence per guide, "timing" and "not covered" in each, plus per-guide keywords (duplicate and sign-in for registration; single attempt and rate limit for reset; single attempt and lockout for sign-in), not the full sentences, so a later edit can improve the prose without breaking the test.
4. **Planning-citation allow-list substring is longer than the path.** The one allowed entry is the README maintainer-note phrase "live in `.planning/PROJECT.md` under **North Star (milestones)**", so a new citation of the same path elsewhere in the README is still flagged.
5. **Scope of the planning-citation check** is the nine edited files, as the plan specifies. Other guides (the upgrade guides, the production-path guide, the admin quality ledger) already cite `.planning/` paths; they are outside this plan's scope and the sweep does not look at them for that.

**Total deviations:** 3 auto-fixed (Rule 1, all in the same guide), 1 registry override, 5 interpretation choices. **Impact:** all within the plan's files plus the phase's deferred-items log; the claim surface is narrower than the plan's literal text where the source or registry disagreed with it.

## Deferred Issues

Logged in `deferred-items.md` (phase directory), section "From Plan 259-10", not fixed:

1. The reset guide's rate-limit and TTL config blocks do not match the `Sigra.Config` schema, and the generated context passes no `:rate_limiter` to `request_password_reset/3`, so the throttle sentence describes behaviour a generated host may not have (read in source, not executed). The sentence was kept conditional.
2. The reset guide's request snippet repeats the user-struct call whose binary-only head mismatch Plan 259-13 recorded for the generated controller.

Not recorded in `.planning/WINDOWS.md` (a scope limit of this phase; an open entry would block `/gsd-ship`).

## Issues Encountered

None blocking.

## Authentication Gates

None.

## Known Stubs

None. No stub patterns, skipped tests or unrun verifies in the files created.

## Threat Flags

None. Docs and one test module; no new network, auth or file-access surface. Mitigations: T-259-31 (docs overclaim) by the rewording, scope paragraphs and retired-phrase test; T-259-32 (internal references in published text) by the planning-citation check; T-259-33 (baseline churn) by `copy_contract_test` staying green with no baselined line edited and no lexicon word or sign-in-as-"log in" wording added; T-259-40 (regression) by the sweep with its qualifier rule, empty shrink-only allow-list and planted controls.

## Verification Results

- Plan verification item 1: `mix test test/sigra/brand test/sigra/architecture_guides_contract_test.exs test/sigra/planning/phase_242_shift_left_contract_test.exs test/sigra/planning/phase_249_release_docs_contract_test.exs`: 264 tests, 0 failures. With `test/sigra/guides_dx02_test.exs` added (reading-time budget: 18.59 min of 30), 263 tests, 0 failures at the Task 2 commit. `claims_docs_test.exs` alone: 37 tests, 0 failures.
- Item 2 (zero shipped bytes, git failure cannot read clean, untracked included): PASS. Item 3 (privacy gate with planted-failure control): PASS. Item 4: `mix format --check-formatted` clean.
- Task 1 acceptance criteria: the four retired-phrase greps print nothing, and their controls against `git show aeda7273d:<path>` each print 1; `Scope of this claim:` count is 1 in each of the three flow guides; the README "Safer defaults" line is gone and the `| **Enumeration** |` row count is 1; no added line cites `.planning` or `public-surfaces`; the only `.planning` hit among the edited files is README.md:34.
- Task 2 acceptance criteria: the four-phrase grep prints nothing (control prints 1); `mix.exs` and `doc/llms.txt` unchanged; the first line of each of the three guides is unchanged; no changed line mentions "prevent user enumeration" (the fenced comment is untouched).
- Task 3 acceptance criteria: `enumeration-resistant|does not reveal whether the account exists` prints nothing in demo-showcase and the example README (control prints 1); the remaining `enumeration safe/resistant/prevent` grep hit is the walkthrough's fenced generator comment only; the demo-showcase H1 is unchanged.
- New prose adds no Do-not-say lexicon word, no "log in" wording and no `{:sigra,` tuple; no baselined line was edited.

## Next Phase Readiness

Plan 259-11's claims register can reference the parity rows as the only proven surfaces; the docs now say the same. Phase 262-263 copy work should rewrite the generated-template over-claims (code comments and docstrings still use "enumeration-safe") and the library moduledocs together, because both need shipped bytes. `STATE.md` `Current Plan` is a completed-count and the disk-derived plan list is authoritative.

## Self-Check: PASSED

Created and modified files exist on disk; commits `332c168f8`, `55cdf5484` and `4ddf13bbb` are ancestors of HEAD and are the only commits in the plan range (`rev-list --count` = 3); every task acceptance criterion and the plan-level verification commands were re-run green after the last code commit; no stub patterns found.
