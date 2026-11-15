---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
verified: 2026-11-15T14:48:56Z
status: human_needed
score: 9/9 must-haves verified
covered_files:
  - .gitattributes
  - .planning/decisions/005-brand-adoption-compatibility-policy.md
  - .planning/decisions/006-name-clearance-search-log-and-claims-register.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-01-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-01-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-02-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-02-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-03-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-03-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-04-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-04-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-05-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-05-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-06-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-06-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-07-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-07-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-08-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-08-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-09-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-09-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-10-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-10-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-11-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-11-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-12-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-12-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-13-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-13-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-14-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-14-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-15-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-15-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-16-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-16-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-17-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-17-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-18-PLAN.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/259-18-SUMMARY.md
  - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md
  - .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md
  - .planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md
  - AGENTS.md
  - CLAUDE.md
  - README.md
  - brand.sha256
  - guides/flows/login-and-logout.md
  - guides/flows/password-reset.md
  - guides/flows/registration.md
  - guides/introduction/architecture.md
  - guides/introduction/code-walkthrough.md
  - guides/introduction/contract.md
  - guides/introduction/demo-showcase.md
  - guides/introduction/getting-started.md
  - guides/recipes/testing.md
  - guides/reference/admin-design-contract.md
  - guides/reference/admin-glossary.md
  - guides/reference/admin-ui-principles.md
  - guides/reference/brand-compatibility.md
  - test/example/README.md
  - test/example/lib/example_web/live/confirmation_live.ex
  - test/example/lib/example_web/live/reset_password_live.ex
  - test/example/lib/example_web/router.ex
  - test/example/priv/playwright/helpers/adminFlows.ts
  - test/example/priv/playwright/helpers/loginSubmit.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts
  - test/example/priv/playwright/tests/golden-path.spec.ts
  - test/example/priv/playwright/tests/organizations.spec.ts
  - test/example/priv/playwright/tests/passkey-options.spec.ts
  - test/example/test/example_web/enumeration_parity_test.exs
  - test/example/test/example_web/live/confirmation_live_test.exs
  - test/example/test/example_web/live/reset_password_live_test.exs
  - test/example/test/example_web/login_submit_selector_test.exs
  - test/fixtures/brand/copy-baseline.json
  - test/fixtures/brand/copy-inventory/generated.tsv
  - test/fixtures/brand/copy-inventory/host.tsv
  - test/fixtures/brand/copy-inventory/library.tsv
  - test/fixtures/brand/frozen-surface.json
  - test/fixtures/brand/legacy-profiles.json
  - test/fixtures/brand/public-surfaces.json
  - test/sigra/brand/claims_docs_test.exs
  - test/sigra/brand/copy_contract_test.exs
  - test/sigra/brand/copy_inventory_test.exs
  - test/sigra/brand/frozen_surface_test.exs
  - test/sigra/brand/install_snippet_test.exs
  - test/sigra/brand/instruction_pointers_test.exs
  - test/sigra/brand/legacy_profiles_test.exs
  - test/sigra/brand/name_clearance_test.exs
  - test/sigra/brand/policy_docs_test.exs
  - test/sigra/brand/regen_guard_test.exs
  - test/sigra/brand/source_pin_test.exs
  - test/sigra/brand/vocabulary_docs_test.exs
  - test/support/brand/copy_inventory.ex
  - test/support/brand/copy_scan.ex
  - test/support/brand/regen_guard.ex
covered_digest: "v4:sha256:a9fb1259dd96b875971bc059b6a2cead3919a94ca17f580cff00c80af038b0a9"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/8
  gaps_closed:
    - "The enumeration-parity tests pass for every pre-auth surface (BCOPY-03 names sign-in, reset, magic link, resend, registration, invitation, MFA, passkey) and go red exactly once when a deliberately leaky string is injected: password-reset-request is now a parity row (example host repaired, probe plus library-path test); confirmation-resend is now a parity row (payload-ignored class, example host repaired, token-count result dimension); mfa-challenge is counted separately and can no longer stand in for an account-existence surface; the old 'parity or not_proven, at least three of five' tolerance is gone."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Read ADR 005 decisions 1-9, 11 and 14 and ADR 006's two decisions; confirm or amend each."
    expected: "Each 'Recommended default - owner confirmation pending' row is confirmed, or amended in place with a dated note. Only decision 12 is confirmed today (ADR 005 line 3 says so)."
    why_human: "A test can prove a decision is recorded and labelled, not that it is the right decision. Phase 260 (PNG park needs explicit approval) and Phase 263 (install-pin value, logo-use statement) inherit them."
  - test: "Decide whether SC-4 / the milestone Enumeration-parity gate is read as 'every pre-auth surface has an asserted, honest state' (the reading the registry implements) or as 'every listed surface is identical'."
    expected: "Registration and passkey sign-in options are real account-existence leaks that Phase 259 cannot fix (zero shipped bytes). They are registered known_divergence and the tests assert they STILL differ; the docs say 'Not covered: registration, passkey sign-in'. If the owner wants them parity before Phase 262, that is a shipped-byte fix tracked by the existing todos, not a test change."
    why_human: "The roadmap wording 'are identical across ... registration ... passkey' cannot be true while the leaks exist; whether 'tests pass and the leak is recorded' satisfies it is an owner interpretation, not a program-checkable fact."
  - test: "Let the PR's Playwright lanes run the five edited specs and adminFlows.ts."
    expected: "Every login step still clicks the submit button through loginSubmit."
    why_human: "Playwright is not installed locally. The selector is proven unique against the real example login page by an ExUnit test, so the residual risk is low; this is advisory and CI-automatic."
  - test: "Read the password-reset guide Step 1 against the generated template (see Anti-Patterns, W-1) and the three re-review items deferred as owner/scope decisions (R2-WR-04, R2-WR-05, R2-WR-06, R2-IN-02 in the deferred-findings todo)."
    expected: "Step 1 either says its snippet is the corrected shape rather than what the generated view does today, or waits for the generated-host fix; the owner decides whether sigra.gen.oauth and sigra.upgrade templates join the copy scan now or are swept by hand in Phase 262."
    why_human: "Editorial and scope judgments."
---

# Phase 259: Compatibility Policy, Pinned Source and Copy Contract Verification Report

**Phase Goal:** A maintainer can state, and a test enforces, exactly what the rebrand may and may not change: the policy is written, the brand book is pinned in-repo, and the copy and enumeration-safety contracts are under test before any visible change is made.
**Verified:** 2026-11-15T14:48:56Z
**Status:** human_needed
**Re-verification:** Yes, after gap-closure plans 259-14 to 259-18 and the two review-fix rounds

## Verdict in one paragraph

The one gap from the previous report is genuinely closed, in code and with a positive control I ran myself. Every must-have now resolves to VERIFIED, and no regression appeared in the eight truths that already passed. What keeps the status at `human_needed` and not `passed` is a short list that a program cannot settle: eleven recorded decisions still carry "owner confirmation pending", the roadmap's "identical across registration and passkey" wording cannot be literally true while two real leaks exist that this zero-shipped-bytes phase may not fix, and a few editorial and scope warnings from the re-review. Nothing here blocks Phases 260 and 261. Two things the planner should carry forward are in "Notes for the next phase planner".

## Re-verification of the prior gap, in code

The previous report had one failed truth: parity was missing for password reset request and confirmation resend, and mfa-challenge was being counted toward the floor. I checked each claim against the tree, not against the SUMMARYs.

| Prior gap item | What I checked | Result |
|----------------|----------------|--------|
| Reset request page cannot mount | `test/example/lib/example_web/router.ex:119` now reads `live "/reset-password", ResetPasswordLive, :new`. `reset_password_live.ex` `send_instructions` (lines 168-188) calls `Example.Accounts.deliver_user_reset_password_instructions(email, ...)` unconditionally with the binary email; `get_user_by_email` is gone from the view. | CLOSED |
| Reset request has no probe | Registry row `password-reset-request` is `parity`, compare `status, redirect, flash, body`, blocker null. `probe("password-reset-request", ...)` submits the real LiveView form. A separate test proves the existing email writes exactly one `reset_password` token for that account and the unknown email writes none (so the existing probe reached the library, it is not a no-op). | CLOSED |
| Confirmation resend uncompletable | `router.ex` serves `/confirm` from `live_session :confirmation` on `:mount_current_scope` inside a `[:browser]` scope, outside `redirect_if_user_is_authenticated`. `confirmation_live.ex` reads the user through a nil-safe `session_user/1` (lines 192-197). `confirmation_live_test.exs` asserts on `confirmed_at` and token rows in both session states. | CLOSED |
| Confirmation resend has no probe | Registry row `confirmation-resend` is `parity` with a `result` dimension (confirmation tokens created for the payload email). Honest scope: the handler ignores its payload and no email-keyed resend form exists, so this proves a visitor-supplied email is ignored. The row note keeps the phrases `payload` and `email-keyed resend form`, pinned by a test. | CLOSED (bounded, see W-2) |
| mfa-challenge counted toward the floor | `named_surface_violations/1` judges each of the five named ids on its own: three account-existence ids, one payload-ignored id, one code-kind id. Each must be `parity` with a null blocker; no total exists, so mfa-challenge cannot satisfy or substitute for an account-existence surface. The "parity or not_proven" tolerance and the "at least three of five" floor are removed. Decision recorded in the registry note and the deferred todo (WR-08 residual marked resolved). | CLOSED |

### Positive controls I ran myself

The in-suite "leak" control appends a string after the response is captured, so it proves the comparator, not that a probe observes the product. I therefore mutated product code in a scratch copy of the tracked tree (the working tree was never touched; `git status` is empty) and reverted each mutation:

| Mutation (scratch copy only) | Expected | Observed |
|------------------------------|----------|----------|
| Reset view flashes "No account found for that email." when the address has no account | parity red at `password-reset-request`, on `flash` | 4 failures, including `password-reset-request: [{:flash, "If your email is in our system...", "No account found for that email."}]` and the non-vacuity test naming the unknown probe's captured flash |
| Resend handler acts on the payload email (sends confirmation mail) but redirects identically | parity red on `result` only | 4 failures; `confirmation-resend: [{:result, %{confirmation_tokens: 2}, %{confirmation_tokens: 0}}]`. The visible redirect was identical, so only the token-count dimension saw it |
| Drop `:new` from the reset route | reset page raises on mount | `CaseClauseError` in 9 places, 10 failures across parity plus the reset regression suite |
| Registry: `password-reset-request` set to `not_proven` with a valid `path:line` blocker (the shape the old rule accepted) | named-surface rule red | `password-reset-request: state is "not_proven" but a named surface must be parity` reported on the real fixture |
| README Enumeration row replaced with "enumeration-safe" | claims tests red | 4 failures |
| README lists password-reset requests under "Not covered" again | row lock red | 1 failure |
| Guide testing snippet passes a user struct again | call-shape test red | 2 failures |

The baseline in the same scratch copy was 38 tests, 0 failures before any mutation, so the reds are caused by the mutations.

## Goal Achievement

### Observable Truths

Roadmap success criteria are the contract; PLAN must-haves added detail but never reduced scope. SC-4 has several independent clauses, so it is split.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: ADR, `contract.md` section and `guides/reference/brand-compatibility.md` carry the frozen list, add-only list, ownership-lane table, surface map with a brand owner, the recorded decisions and an upgrade-note skeleton | VERIFIED | Unchanged since the first verification; `policy_docs_test.exs` is in the green 366-test brand run. ADR 005 line 3 states plainly that all decisions except #12 are recommended defaults awaiting owner confirmation (Human Verification 1). |
| 2 | SC-2: consumed brand subset pinned in `brand/` with `brand.sha256`; any edited byte turns the drift test red; privacy scan; `brandbook/` untouched; `git diff --stat -- lib priv` empty | VERIFIED | `shasum -a 256 -c brand.sha256`: 72 lines, every one `OK`. `git diff --stat aeda7273d HEAD -- lib priv brand brandbook .github scripts` is empty for the whole phase (control: the same range without the path filter is 113 files changed, 22075 insertions). Privacy grep over added lines outside `.planning` and `brand/` finds no home path (control: planted `/Users/someone/x` matched) and no email; the only hits for the owner's public GitHub handle are in plan text citing a Hex package link, and the handle is already in `README.md`. |
| 3 | SC-3: frozen-surface ratchet green, can only grow; legacy Branding profiles render byte-identically | VERIFIED | `frozen_surface_test.exs` and `legacy_profiles_test.exs` pass in the brand run. Caveat unchanged: WR-05 (a human can loosen the fixture JSON in the same commit; no base-branch diff gate), deferred to an owner decision. |
| 4a | SC-4 (copy): reconciled vocabulary table, per-lane inventory, banned-term/lexicon drift test with shrink-only baseline | VERIFIED (with warnings) | `vocabulary_docs_test`, `copy_inventory_test`, `copy_contract_test`, `regen_guard_test` pass. Coverage holes are documented in code headers and in the deferred-findings todo: HEEx attribute values and JS hooks (WR-03), admin scope pinned to nine files (WR-04), and, new in the re-review, `sigra.gen.oauth` and `sigra.upgrade` templates outside every scope (R2-WR-05). I confirmed R2-WR-05: `copy_scan.ex:83` reads only `priv/templates/sigra.install`, and `priv/templates/sigra.gen.oauth/oauth_controller.ex:96` ships "Log in to link your ... account". |
| 4b | SC-4 (install snippet): three-segment `{:sigra, "~> x.y.z"}`, all equal | VERIFIED | `install_snippet_test.exs` green. My grep over README, `guides`, `docs`, `priv/templates`: 11 tuples, all `~> 1.5.0`. |
| 4c | SC-4 (Playwright): "Log in" text locators replaced by the test-only `loginSubmit` helper | VERIFIED | No `has-text("Log in")` button locator remains under `test/example/priv/playwright`; `loginSubmit` is used by five specs and `adminFlows.ts`. `login_submit_selector_test.exs` passes (part of the 60-test example run). Browser run is CI-only (Human Verification 3, advisory). |
| 4d | SC-4 (enumeration): parity tests pass for every pre-auth surface and go red exactly once on an injected leak | VERIFIED | Registry now holds 5 `parity` rows (the five named surfaces), 3 `known_divergence` (registration, passkey options, repeat-attempt lockout), 2 `by_design` (invitation, enterprise discovery), 3 `not_proven` (two rate limits and the library moduledoc claims, none of them a named request surface). `enumeration_parity_test.exs`: 38 tests, 0 failures. Positive control: `a leak on exactly one parity surface yields exactly one diff` and `every parity surface can go red` cover all five parity ids and assert at least four other rows stay `:same` (non-vacuity). My product-level mutations (above) show each probe observes the real response. Interpretation note in Human Verification 2: registration and passkey are asserted-to-differ, not parity. |
| 4e | SC-4 (honesty): docs and tests claim no enumeration safety beyond what is proven | VERIFIED (with warnings) | README Enumeration row (line 177) now names sign-in, magic-link and password-reset requests as tested "in Sigra's example application ... at a single attempt", lists timing, repeat attempts, registration, passkey sign-in and the generated code as not covered, and says only three flow guides state a scope (the three that do). It does not mention resend or MFA. My broad grep over README, `guides`, `docs`, `CHANGELOG.md`, `SECURITY.md` finds no unbounded claim in prose (the remaining hits are a quoted code comment and a threat description). Mutation proofs above show the claims tests go red on regression. Warnings: W-1 below, the narrow claim recogniser (R2-WR-06) and library moduledocs that say "enumeration-safe" (tracked by todo, not editable under zero-lib-bytes). |
| 5 | SC-5: name-clearance record "search log, not clearance" with `crosswake_sigra`, claims register, logo-use and clear-space decisions, no trademark claim; pointer fix only after owner approval; privacy and process budget hold | VERIFIED | `name_clearance_test.exs` green, including the cross-check that every register status agrees with its registry row; the register rows for reset (`bounded`) and resend (`bounded`, counted separately) read as the registry does. `git diff --stat .github scripts` empty. No `!` or BREAKING in any of the 111 commits since the phase base; types are chore, docs, feat (one, the known `4dad2ca17` noise), fix, test. |

**Score:** 9/9 truths verified (0 present-but-behavior-unverified).

### Gap-closure plans 259-14 to 259-18: must-haves against the tree

| Plan | Must-have | Status | Evidence |
|------|-----------|--------|----------|
| 14 | Reset page mounts (`:new`), view passes binary email, row is `parity`, probe non-vacuous, library-path reach test, positive control across the larger set, register row `bounded`, zero shipped bytes | VERIFIED | Code read above; tests pass; mutations above; register row reads `bounded`; shipped diff empty |
| 15 | Confirm page reachable in both session states, nil-safe resend/code entry, signed-in resend/confirm assert on `confirmed_at`, `confirmation-resend` parity with `result`, token-count control, register row `bounded` | VERIFIED | `confirmation_live_test.exs` (anonymous and signed-in describes) and `enumeration_parity_test.exs` "confirmation-resend probe is real" including the control that a direct delivery takes the count 0 to at least 1 |
| 16 | Named-surface rule tightened, three classes judged apart, planted controls, positive control over the larger set, WR-08 residual closed | VERIFIED | `named_surface_violations/1`, 9 registry-describe controls, `@required_dimensions` pin; todo bullet reads "resolved by Plan 259-16" |
| 17 | Generated-host defects filed, not fixed; confirm todo re-read against current sources; registry todo field wired and asserted | VERIFIED | New todo exists with "read in source, not executed" labels; I confirmed its core claims: `lib/sigra/install/features/core.ex:410-411` and the golden router lines 119-120 emit `live "/reset-password", ResetPasswordLive` with no action, the generated `reset_password_live.ex:155` still does `if user = ...get_user_by_email(email)`, and the context head at `priv/templates/sigra.install/core/auth.ex:428-429` requires a binary. The confirm todo's Phase 246 claim also holds: `core.ex:394-395` emits `live_session :sigra_confirmation` on `:mount_current_scope`, golden router lines 98-102 agree, both cited commits exist. |
| 18 | README, guide, `claims_docs_test`, register cells and `deferred-items.md` aligned to the repaired registry; phase gate green | VERIFIED | Docs read above. Gate re-run by me at HEAD (below). |
| review | R2-WR-01 guide snippets, R2-WR-02 README wording, R2-WR-03 dimension pin, R2-IN-01 README sentence fixed; R2-WR-04, R2-WR-05, R2-WR-06, R2-IN-02 deferred with diagnosis in the todo | VERIFIED | The four fixes are in the tree and covered by tests I mutated; the four deferrals are recorded in `259-REVIEW-DISPOSITION.md` and the todo. |

### Deferred Items

Items not yet met but explicitly tracked. None is a gap against this phase's success criteria.

| # | Item | Tracked in | Note |
|---|------|-----------|------|
| 1 | Generated reset request page defects (no `:new` action in the installer route, user struct passed to a binary-only head) | `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md`, severity major | Shipped-byte fix; out of scope under zero-lib-bytes. Not matched to a roadmap phase by name, so it stays a todo, not a `deferred` frontmatter entry. |
| 2 | Generated non-live confirm controller flavor | `.planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` | Narrowed by the Plan 259-17 status update; fast-follow disposition unchanged |
| 3 | Registration timing oracle, passkey options oracle, lockout and rate-limit channels, lib moduledoc over-claims | four filed todos named in the registry | Real leaks, asserted to still differ |

### Advisory (New Scope, Unevidenced)

None. Every finding below has deterministic evidence (a source line, a command output or a mutation result).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| ADR 005, ADR 006, `guides/reference/brand-compatibility.md`, `contract.md` section | policy and register | VERIFIED | asserted by `policy_docs_test`, `name_clearance_test`, `claims_docs_test` |
| `brand.sha256`, `.gitattributes` | pin | VERIFIED | 72/72 OK |
| `test/fixtures/brand/*.json`, `copy-inventory/*.tsv` | ratchets, baselines, inventory | VERIFIED | green; coverage limits stated in headers |
| `test/fixtures/brand/public-surfaces.json` | parity registry | VERIFIED | 13 rows: 5 parity, 3 known_divergence, 2 by_design, 3 not_proven |
| `test/sigra/brand/*.exs` (12), `test/support/brand/*.ex` (3) | contracts | VERIFIED | 366 tests with the installer-drift test, 0 failures |
| `test/example/test/example_web/enumeration_parity_test.exs` | parity harness | VERIFIED | 38 tests, 0 failures |
| `test/example/test/example_web/live/{reset_password,confirmation}_live_test.exs` | regression suites | VERIFIED | green, mutation-checked |
| `test/example/lib/example_web/{router.ex,live/reset_password_live.ex,live/confirmation_live.ex}` | repaired example host | VERIFIED | code read; test code, not a shipped byte |
| `test/example/priv/playwright/helpers/loginSubmit.ts` | login helper | VERIFIED | used by five specs and `adminFlows.ts` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `router.ex:119` | `ResetPasswordLive.mount/3` | `:new` live action feeds the `case socket.assigns.live_action` | WIRED | dropping it raises `CaseClauseError` (mutation) |
| `router.ex` `live_session :confirmation` | `ConfirmationLive` | `:mount_current_scope` assigns `current_scope`, nil when anonymous | WIRED | anonymous and signed-in tests both mount |
| registry rows | parity test | probe clause, `expected_parity_flash/1` clause, `@required_dimensions`, `@expected_todos` | WIRED | a trimmed `compare` list, a `not_proven` downgrade or a dropped todo path each go red |
| registry `password-reset-request` row | generated-host todo | `todo` field, asserted to be a real file | WIRED | file exists |
| README / guide | registry | `claims_docs_test` row locks, retired phrases, scope bounds | WIRED | README regressions go red (mutations) |
| `brand/brand.json` | lexicon scan | `CopyScan.lexicon_words/0` | WIRED | unchanged from the first verification |

### Data-Flow Trace (Level 4)

Not applicable to shipped code: no runtime-rendered dynamic data was added to anything that ships. For the example-host repairs the data flow is real: the reset probe's existing-email request writes a `reset_password` `UserToken` row (queried straight from `Example.Repo`), and the resend probe's `result` dimension reads confirmation token rows. Both are asserted in tests and both responded to my mutations.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Brand contract suite plus installer drift | `source tmp/db.env && MIX_ENV=test mix test test/sigra/brand test/sigra/templates/installer_drift_test.exs` | 366 tests, 0 failures | PASS |
| Example-host parity, selector, reset and confirm suites | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs test/example_web/login_submit_selector_test.exs test/example_web/live/confirmation_live_test.exs test/example_web/live/reset_password_live_test.exs` | 60 tests, 0 failures | PASS |
| Full example suite | `cd test/example && MIX_ENV=test mix test --include example_app` | 396 tests, 0 failures | PASS |
| Local gate at HEAD | `MIX_ENV=test mix ci` | exit 0: 33 doctests, 3 properties, 2991 tests, 0 failures, 12 skipped; install golden 65 tests, 0 failures | PASS |
| Pin independent of ExUnit | `shasum -a 256 -c brand.sha256` | 72 OK, 0 not OK | PASS |
| Formatting | `MIX_ENV=test mix format --check-formatted` | exit 0 | PASS |
| Zero shipped bytes | `git diff --stat aeda7273d HEAD -- lib priv brand brandbook .github scripts` | empty (control: unfiltered diff is 113 files) | PASS |
| Debt markers | grep of added lines outside `.planning` and `brand/` for TBD, FIXME, XXX, TODO, HACK, PLACEHOLDER | none (control: planted `FIXME` matched) | PASS |
| Working tree | `git status --short` after every run | empty | PASS |

The `error: undefined variable "web_module"` lines in the `mix ci` output are emitted by template-compile tests that pass; the run exits 0.

### Probe Execution

SKIPPED: no PLAN declares a `probe-*.sh`, and this is not a migration or tooling phase.

### Requirements Coverage

All fourteen IDs declared across the eighteen plans match the fourteen REQUIREMENTS.md maps to Phase 259; no orphans.

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| BPOL-01 | 259-01 | SATISFIED | Truth 1 |
| BPOL-02 | 259-02 | SATISFIED | Truth 2 |
| BPOL-03 | 259-05 | SATISFIED | Truth 3 |
| BPOL-04 | 259-11 | SATISFIED | Truth 5 |
| BPOL-05 | 259-01 | SATISFIED (recorded) | decisions recorded; 11 await owner confirmation (Human Verification 1) |
| BPOL-06 | 259-09 | SATISFIED (narrow) | four files fixed after pre-phase approval; residual `brandbook/` pointers in three admin reference guides and `test/example/AGENTS.md` are filed todos |
| BPOL-07 | 259-01 | SATISFIED | guide "Upgrade notes" |
| BCOPY-01 | 259-12 | SATISFIED | Truth 4a |
| BCOPY-02 | 259-08 | SATISFIED (bounded) | Truth 4a; WR-04 and R2-WR-05 scope warnings |
| BCOPY-03 | 259-07, 259-13, 259-14, 259-15, 259-16, 259-17, 259-18 | SATISFIED | Truth 4d, now with all five named surfaces `parity`, each probe observing the real response, and the rest honestly registered |
| BCOPY-04 | 259-06 | SATISFIED (bounded) | exact-equality test over three lanes; coverage limits stated in each header |
| BCOPY-05 | 259-04 | SATISFIED | Truth 4b |
| BCOPY-06 | 259-03 | SATISFIED | Truth 4c |
| BCOPY-07 | 259-10, 259-11, 259-13, 259-14, 259-15, 259-17, 259-18 | SATISFIED (bounded) | Truth 4e |

`.planning/REQUIREMENTS.md` currently shows BCOPY-03 and BCOPY-07 as Complete and the other twelve as "Gaps Found" (left over from the first, failed verification). The orchestrator should reconcile that table when the phase is completed.

### Anti-Patterns Found

No debt marker, stub implementation or hardcoded-empty data in any added line outside `.planning`. Nothing below blocks. Severities are warnings or info.

| ID | File | Pattern | Severity | Impact |
|----|------|---------|----------|--------|
| W-1 | `guides/flows/password-reset.md:16-36` | Step 1 says "The generated `ResetPasswordLive` renders a form ... Submitting it calls:" and shows the corrected binary-email handler, but the generated template `priv/templates/sigra.install/core/reset_password_live.ex:155` still looks the user up and passes the struct. Line 36 half-discloses this ("Check the call in the code generated into your app") and the scope paragraph and README bound the claim to the example application | Warning | A reader can take the snippet as a description of generated code. It over-describes the generated view, though it makes no enumeration-safety claim beyond what is proven. Fix by wording ("the corrected shape") or by the generated-host fix in the filed todo |
| W-2 | `test/fixtures/brand/public-surfaces.json` row `confirmation-resend` | The row is labelled `parity` but proves "a payload email is ignored", not that an existing and an unknown address answer alike; no email-keyed resend form exists, so there is no existing-versus-unknown channel to compare | Warning | Honestly stated in the row, the register and the test moduledoc, and counted as its own class, so nothing over-claims. Recorded so the word "parity" on that row is not read as enumeration evidence |
| W-3 | `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` ("Other places that still carry the struct call") and `deferred-items.md` (259-10 item 2) | Both still say the published guide snippets pass the user struct; the WR-01 fix (commit `6a6629289`) corrected them afterwards | Info | Stale planning prose only; the guide is right |
| W-4 | `test/example/lib/example_web/live/confirmation_live.ex:104` | `handle_params(%{"token" => ...})` still dereferences `socket.assigns.current_scope.user`, which would raise for an anonymous visitor. The example routes no `:token` param to this LiveView (the token link is a controller), so it is unreachable; the line is kept because an installer-drift test requires that binding | Info | Already recorded in `deferred-items.md` (Plan 259-15 item 1) |
| W-5 | `test/support/brand/copy_scan.ex` (R2-WR-04 and R2-IN-02), `test/sigra/brand/claims_docs_test.exs` (R2-WR-06) | Scanner misses a phrase split over `<>`-joined literals and HTML entities; the claim recogniser misses wordings such as "prevents username enumeration" and "enumeration-proof". The re-reviewer probed each. No scanned file or doc contains such a shape today | Warning | Regression guards narrower than their titles; deferred with diagnosis and no current hit masked |
| W-6 | `priv/templates/sigra.gen.oauth/**`, `priv/templates/sigra.upgrade/**` | Outside every copy scope and inventory lane (R2-WR-05); they ship "Log in to link your ... account" and "You'll still be able to log in with" | Warning | Not on the Phase 262 worklist unless an owner decision adds them or Phase 262 sweeps them by hand |
| W-7 | `test/sigra/brand/frozen_surface_test.exs`, `copy_contract_test.exs` + fixtures | WR-05 from the first review: both ratchets can be loosened by editing JSON in the same commit; no base-branch diff gate | Warning | "Can only grow" holds for the opt-in writer and accidental drift, not a deliberate fixture edit; relies on review |
| W-8 | `lib/sigra/lockout.ex:13`, `error.ex`, `auth.ex`, installer template comments | Published moduledocs still say "enumeration-safe" | Warning | Zero-lib-bytes rule forbids editing here; bounded by the register, todo filed |

### Human Verification Required

These are the items a program cannot settle. They are listed in the frontmatter `human_verification` block as well.

#### 1. Owner confirmation of the recommended-default decisions

**Test:** Read ADR 005 decisions 1-9, 11 and 14, and ADR 006's two decisions; confirm or amend each.
**Expected:** Each "Recommended default - owner confirmation pending" row is confirmed, or amended in place with a dated note. Only decision 12 is confirmed today.
**Why human:** A test proves a decision is recorded and labelled, not that it is the right one. Phase 260 (the PNG park needs explicit approval) and Phase 263 (install-pin value, logo-use statement) inherit them.

#### 2. Reading of "every pre-auth surface" for registration and passkey

**Test:** Decide whether SC-4 and the milestone Enumeration-parity gate mean "every surface has an asserted, honest state" (what the registry implements) or "every listed surface is identical".
**Expected:** Registration and passkey sign-in options are real account-existence leaks that a zero-shipped-bytes phase cannot fix. They are registered `known_divergence`, the tests assert they still differ, and the docs say "Not covered: registration, passkey sign-in". If parity is wanted before Phase 262, that is a shipped-byte fix tracked by existing todos, not a test change.
**Why human:** The roadmap gate text ("identical across ... registration ... passkey") cannot be literally true while the leaks exist; whether "recorded and asserted" satisfies it is an owner interpretation.

#### 3. Playwright specs in a real browser (advisory)

**Test:** Let the PR's Playwright lanes run the five edited specs and `adminFlows.ts`.
**Expected:** Every login step still clicks the submit button through `loginSubmit`.
**Why human:** Playwright is not installed locally. The selector is proven unique against the real example login page by an ExUnit test, so the residual risk is low and CI does this on the PR.

#### 4. Editorial and scope judgments

**Test:** Read W-1 (guide Step 1 against the generated template) and decide the deferred scope items: R2-WR-04, R2-WR-05, R2-WR-06, R2-IN-02.
**Expected:** Step 1 either says its snippet is the corrected shape or waits for the generated-host fix; the owner decides whether `sigra.gen.oauth` and `sigra.upgrade` join the copy scan now or are swept by hand in Phase 262.
**Why human:** Editorial and scope judgments.

### Gaps Summary

No gaps. The single prior gap is closed with code, tests and independent positive controls. The status is `human_needed` because the human-verification section is not empty, per the decision tree; none of the four items blocks Phases 260 and 261.

### Notes for the next phase planner

- **Parity re-run in Phase 262 is example-host only.** ROADMAP Phase 262 criterion 1 and 5 say enumeration parity "re-runs green on touched pre-auth slices". The harness drives `test/example`, a hand-maintained copy, so a change to a generated template is only proven if the example is changed to match (the template, example and golden parity tests of Phase 260 are what keep them aligned). Also, the generated reset request page has two filed defects, so Phase 262 4c, which rewrites generated auth screens, should either fix them first or leave the generated reset view and the installer route alone.
- **Reconcile the Phase 262 status words.** ROADMAP Phase 262 criterion 1 lists "(Deleting, Locked, Unconfirmed, Active)"; ADR 005 decision 6 and Phase 259's SC-1 keep "Deletion scheduled". Fix the roadmap text before Phase 262 plans.
- **Treat the ratchet and baseline fixtures as security-relevant diffs** in later phases (W-7), since they are loosened by editing JSON.
- **The generated confirm and reset todos are fast-follow candidates.** The reset one is marked major and, read in source, may crash a `--live` install's reset page on mount.

---

_Verified: 2026-11-15T14:48:56Z_
_Verifier: Claude (gsd-verifier)_
