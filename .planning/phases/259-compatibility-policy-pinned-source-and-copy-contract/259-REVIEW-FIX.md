---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
fixed_at: 2026-11-15T14:40:00Z
review_path: .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-REVIEW.md
iteration: 2
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 259: Code Review Fix Report (re-review after gap closure)

**Fixed at:** 2026-11-15T14:40:00Z
**Source review:** .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-REVIEW.md
**Iteration:** 2 (this report replaces the iteration 1 report; the iteration 1 fixes WR-01, WR-02, WR-03 wording, WR-06, WR-07 and WR-08 of the first review are already committed)

**Summary:**
- Findings in scope: 4 (WR-01, WR-02, WR-03, IN-01), a subset chosen by the orchestrator
- Fixed: 4
- Skipped: 0
- Deferred to the todo by the orchestrator, no edit made: 4 (WR-04, WR-05, WR-06, IN-02)

Edits ran in the main checkout on branch `milestone/v1.51-brand-identity-adoption` (sequential, no worktree), as instructed. Each defect was confirmed in the source before editing. Nothing under `lib/`, `priv/`, `brandbook/`, `brand/`, `.github/` or `scripts/` changed.

## Fixed Issues

### WR-01: The password-reset guide still teaches the call its own new sentence says is wrong

**Files modified:** `guides/flows/password-reset.md`, `guides/introduction/getting-started.md`, `guides/recipes/testing.md`, `test/sigra/brand/claims_docs_test.exs`
**Commit:** 6a6629289
**Applied fix:** Confirmed against `priv/templates/sigra.install/core/auth.ex:428` (one function head, `when is_binary(email)`) and the repaired example host (`test/example/lib/example_web/live/reset_password_live.ex`). The password-reset guide's request-handler snippet now passes the submitted email, drops the `if user =` precheck, is named `send_instructions` and redirects to the login page as the example host does; its Testing snippet now passes `user.email`; and the correction sentence now says what a user-struct call does (a `FunctionClauseError` for an address with an account, a normal return for one without) and to check the generated call. Grep found two more guides with the same defect (`getting-started.md` step 7 and `recipes/testing.md`); both now pass the email. A new claims test fails when any guide, the README or the example README passes a user struct (`user`, `@user`, `current_user`, `socket.assigns.user`) to `deliver_user_reset_password_instructions`, plus a check that it sees both calls in the password-reset guide, with planted controls for the one-line, wrapped, assigns and `current_user` shapes. Positive control: against the old guides the new tests go red naming four offenders; against the new guides they are green.

Note (not changed, tracked by the existing generated-host todo): the generated template `priv/templates/sigra.install/core/reset_password_live.ex` and the generated reset controller still look the user up and pass the struct. That is a shipped-byte change and out of scope here; the guides now describe the correct call and tell the reader to check the generated one.

### WR-02: "Show the same message" overstates a harness that compares the flash map, not what a visitor sees

**Files modified:** `README.md`, `test/sigra/brand/claims_docs_test.exs`, `.planning/decisions/006-name-clearance-search-log-and-claims-register.md`
**Commit:** c2dc9a5f4
**Applied fix:** The README Enumeration row now says the three request types are tested, in Sigra's example application, "to return the same status, redirect, flash message and page for an existing and an unknown address at a single attempt", which is what the harness compares. The old phrase "to show the same message for an existing and an unknown address" is a retired string, and the README row lock now requires "the same status, redirect, flash message and page" (the "single attempt", "example application", "password-reset requests" and Not covered locks are untouched and still green). I took the review's note that the claims register carries the same looser claim and changed the claim cell of its three rows (sign-in, magic-link, password reset) to the same bounded wording; the register's evidence and status columns are unchanged and `name_clearance_test` is green. `public-surfaces.json` row notes already described the flash map and followed body accurately and were not changed for this finding. Positive control: against the old README the retired-phrase and row-lock tests go red.

### WR-03: A parity row's compared dimensions are not pinned, so "same message" can lose its only evidence silently

**Files modified:** `test/example/test/example_web/enumeration_parity_test.exs`, `test/fixtures/brand/public-surfaces.json`
**Commit:** 37aa60daa
**Applied fix:** Added `@required_dimensions` (the three account-existence rows pin status, redirect, flash and body; `confirmation-resend` also pins result; `mfa-challenge` pins status, redirect and flash) and `dropped_dimension_violations/1`, asserted against the real registry. Further tests assert the pin names exactly the named rows and cannot be weakened for the account-existence rows, drop each pinned dimension in turn from a copy of the registry and require the pin to report exactly that row and that dimension, and show the old non-vacuity rule accepting a row trimmed to `["body"]` or `["status", "redirect", "body"]` while the pin reports the lost flash. No `compare` list changed; the registry's top-level note now names the pin. Mutation proof on the real fixture: trimming `password-reset-request` to `["body"]` left the old non-vacuity, leak and `run_all` tests green and turned the new pin test red (reported as `compare dropped ["status", "redirect", "flash"]`); the fixture was restored with `git checkout --`.

### IN-01: README says "Each flow guide on HexDocs states its own scope"; only three of eight do

**Files modified:** `README.md`, `test/sigra/brand/claims_docs_test.exs`
**Commit:** 320324c8d
**Applied fix:** Verified `guides/flows/` has eight guides and only `registration.md`, `login-and-logout.md` and `password-reset.md` carry the bold scope paragraph. The sentence now reads "The registration, sign-in and password-reset guides on HexDocs each state their own scope." No scope paragraphs were invented for the other guides. A claims test compares the set of flow guides that carry a scope paragraph with the three the README names, so adding or removing a scope paragraph forces the sentence to change; its planted control gives `mfa.md` a scope paragraph and shows the set differs. The old sentence is also a retired string. The Not covered list lock now ends at its own sentence, so the new sentence (which contains "password-reset") is not read as part of that list; a planted control proves a later sentence is excluded and a stale reset entry is still caught.

## Deferred (no edit)

Per the orchestrator, WR-04, WR-05, WR-06 and IN-02 were not fixed. Their full diagnosis, probe evidence and suggested fixes were appended to `.planning/todos/pending/2026-11-14-brand-harness-review-deferred-findings.md` under "Re-review after gap closure (2026-11-15)" in commit dda479613.

| Finding | Reason deferred | Where recorded |
|---------|-----------------|----------------|
| WR-04 scanner misses `<>`-joined literals | scanner design work, no current hit masked | todo section, commit dda479613 |
| WR-05 `sigra.gen.oauth` and `sigra.upgrade` templates outside every scope and inventory lane | owner decision (grows the baseline); Phase 262 must sweep those directories by hand until decided | todo section, commit dda479613 |
| WR-06 unbounded-claim recogniser misses ordinary wordings | recogniser redesign, nothing hidden today | todo section, commit dda479613 |
| IN-02 scanner gaps (entities, lone lowercase word, visible attributes) | needs a reviewed baseline refresh, nothing hidden today | todo section, commit dda479613 |

## Verification

Where it ran: the main checkout on `milestone/v1.51-brand-identity-adoption` against the Dockerized test Postgres from `tmp/db.env`, not an isolated worktree, so the numbers are reproducible from the tree a reader sees.

- `mix format --check-formatted` (root): passed. `mix format --check-formatted` on the edited example test file inside `test/example`: passed.
- `mix test test/sigra/brand test/sigra/templates/installer_drift_test.exs`: 366 tests, 0 failures.
- `cd test/example && mix test --include example_app test/example_web/enumeration_parity_test.exs test/example_web/live/confirmation_live_test.exs test/example_web/live/reset_password_live_test.exs`: 53 tests, 0 failures (the parity file alone: 38 tests, 0 failures).
- Zero shipped bytes: `test -z "$(git diff --name-only 62ef40442 HEAD -- lib priv brandbook brand .github scripts)"` passed. The same command shape over `README.md guides` returned the four edited docs, which shows the check can report a change.
- Privacy: a case-sensitive scan of every added line in `0c7464479..HEAD` for home paths, personal email and personal names returned nothing; a planted `/Users/someone/x` line is matched by the same style of pattern.
- Mutation and revert proofs are described under each finding. Working tree is clean after the last commit.

---

_Fixed: 2026-11-15T14:40:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
