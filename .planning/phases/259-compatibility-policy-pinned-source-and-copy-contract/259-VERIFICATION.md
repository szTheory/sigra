---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
verified: 2026-11-15T15:13:59Z
status: passed
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
covered_digest: "v4:sha256:d34ff8a204127c48115db0bf3af9f8cb4ec8c7834851396707bf44da6e08962b"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 9/9
  gaps_closed:
    - "Human item 1 (owner confirmation of ADR 005 decisions 1-9, 11, 14 and ADR 006's two decisions): recorded as confirmed with a date in both ADRs (commits 81c7d0161, b6ee4b7b1); policy_docs_test and name_clearance_test now pin the dated confirmed status and fail on any 'owner confirmation pending' text."
    - "Human item 2 (reading of SC-4 for registration and passkey options): recorded in ADR 005 'Amendment 2026-11-15' as 'every pre-auth surface has an asserted, honest state'; the registry, tests and docs already implement exactly that reading."
    - "Human item 3 (Playwright login submit): replaced by a static check plus the ExUnit selector-uniqueness test; the browser run is a CI lane on the PR, not a human step."
    - "Human item 4 and warning W-1 (guide Step 1 over-described generated code): guides/flows/password-reset.md Step 1 now calls its snippet 'the corrected shape' and says the generated request view and controller still pass a user struct (commit 75af1ee45). I confirmed the claim against priv/templates/sigra.install/core/reset_password_live.ex:155 and reset_password_controller.ex:24."
  gaps_remaining: []
  regressions: []
---

# Phase 259: Compatibility Policy, Pinned Source and Copy Contract Verification Report

**Phase Goal:** A maintainer can state, and a test enforces, exactly what the rebrand may and may not change: the policy is written, the brand book is pinned in-repo, and the copy and enumeration-safety contracts are under test before any visible change is made.
**Verified:** 2026-11-15T15:13:59Z (HEAD `ea295b572`, working tree clean)
**Status:** passed
**Re-verification:** Yes. The previous report was `human_needed` with 9/9 verified and four human items; those four are now resolved (see `re_verification` above). No regression in any previously verified truth.

## Verdict in one paragraph

The goal is achieved. Every roadmap success criterion resolves to VERIFIED, all fourteen requirement IDs are accounted for, and I re-derived the status from the tree rather than carrying the old items forward. The suite you asked me to re-run is green at 359 tests, the example-host parity suite is green at 60, the vendored book still hashes clean at 72 of 72, and `git diff --stat` over `lib priv brand brandbook .github scripts` against the phase base is empty. I then mutated the product code, the registry, the docs and the vendored book in a throwaway copy (never in the working tree) and watched the tests go red every time, so the contracts are not green by accident. What remains are recorded warnings with a named owner or follow-up, none of which is a must-have: they are listed under Anti-Patterns and "Notes for the next phase planner".

## Re-verification of the four former human items

| Former item | What changed | What I checked | Result |
|-------------|--------------|----------------|--------|
| 1. Owner confirmation of recommended defaults | ADR 005 rows 1-9, 11, 14 read "Confirmed as recommended by owner, 2026-11-15"; row 12 keeps "Owner-approved, confirmed 2026-11-13". ADR 006 clear-space, logo-use and no-claim read "confirmed as recommended by owner, 2026-11-15". | `git diff 03f8dca53~1 HEAD` on both ADRs: status words only, decision text unchanged. `policy_docs_test` asserts 11 non-12 rows each carry the status and the date, no row matches `pending`, and the ADR contains none of "owner confirmation pending", "awaiting owner confirmation", "awaits owner confirmation". `name_clearance_test` pins the dated status on the `Label: clear-space.` and `Label: logo-use.` lines and refutes the old phrase. `git grep` finds the old phrase only inside those two `refute` lines and in `.planning/STATE.md:170` (see I-1). | RESOLVED. SC-1 asks for the decisions to be recorded, which was already true; the confirmation is an addition. I could not witness the owner's reply myself: it is relayed by the orchestrator and recorded in the two commits and the ADR amendment. |
| 2. SC-4 reading | ADR 005 "Amendment 2026-11-15, part B": SC-4 means "every pre-auth surface has an asserted, honest state"; registration and passkey stay registered known divergences, asserted to differ, listed as not covered; the owner's direction is that they are fixed as shipped-byte work before Phase 262, tracked by four named todos | `policy_docs_test` carries a test for the amendment, the SC-4 wording and both leak todo filenames. Registry rows confirm the reading: `registration` and `passkey-signin-options` are `known_divergence`. The four todo files exist. | RESOLVED |
| 3. Playwright specs | none | `git grep` of `test/example/priv/playwright`: `loginSubmit` or `LOGIN_SUBMIT_SELECTOR` is used by `adminFlows.ts` and five specs (21 references including the helper itself). No `has-text("Log in")` or `name: "Log in"` button locator remains. `login_submit_selector_test.exs` renders the real example login page and proves the selector matches exactly one element, with planted two-button and `type="button"` controls. | RESOLVED as far as a local run can prove it. The in-browser run is the PR's Playwright shard lanes, which start themselves; it is not a human step |
| 4. Guide Step 1 and deferred scope items | Step 1 now says "The snippet above is the corrected shape" and that "The request view and the request controller that Sigra currently generates into a new app still look the user up with `get_user_by_email` and pass the struct" | Read the diff, then read the generated templates: `reset_password_live.ex:155` and `reset_password_controller.ex:24` both still do `if user = ...get_user_by_email(email)`, and `core/auth.ex:428-429` still has the binary-only head. The wording is accurate. The scope items (R2-WR-04/05/06, R2-IN-02) stay deferred with diagnosis in the todo, by the owner's default | RESOLVED |

## Goal Achievement

### Observable Truths

The roadmap success criteria are the contract. PLAN must-haves added detail and never reduced scope. SC-4 has several independent clauses, so it is split.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: the ADR, the `contract.md` section and `guides/reference/brand-compatibility.md` carry the frozen list, add-only list, ownership-lane table, surface map with a brand owner, the recorded decisions and an upgrade-note skeleton | VERIFIED | ADR 005 has `## Frozen list`, `## Add-only list`, `## Ownership lanes`, `## Surface map`, `## Recorded decisions` (Decisions 1-7 plus related), and the owner decision table. The guide has the same four lists plus `## Consumed brand subset`, `## SemVer and changelog treatment` and `## Upgrade notes` with five numbered steps. `contract.md:43` is `## Brand and visual compatibility` with the lane table and the SemVer sentence. `policy_docs_test` is in the green 359. |
| 2 | SC-2: consumed brand subset pinned in `brand/` with a root `brand.sha256`; editing any byte turns the one drift test red; privacy scan including SVG/PDF metadata; `brandbook/` untouched; `git diff --stat -- lib priv` empty for the phase | VERIFIED | `shasum -a 256 -c brand.sha256`: 72 lines, 72 `OK`. `.gitattributes` is `brand/** -text linguist-vendored`. `git diff --stat aeda7273d HEAD -- lib priv brand brandbook .github scripts` is empty (control: the unfiltered range is 117 files, 22580 insertions). Privacy grep over added lines outside `.planning` and `brand/` finds no home path (control: a planted `/Users/someone/x` matches the same regex) and no non-test email. `source_pin_test` has a real-tree privacy scan plus 13 planted-failure controls for the scanner. **My mutation:** appending one space to a vendored `brand/BRAND.md` turned `source_pin_test` red, naming that file (the only failure in the file, 30 tests). |
| 3 | SC-3: frozen-surface ratchet green, can only grow; legacy Branding profiles render byte-identically | VERIFIED | `frozen-surface.json` holds 11 categories: `css_custom_properties_sg` (100), `css_custom_properties_sigra_auth` (35), `css_classes_sg` (168), `css_classes_sigra_auth` (66), `profile_defaults` (25), `config_option_paths` (170), `routes` (60), `verified_route_helpers` (54), `gettext_domains` (`sigra`), `data_testids` (25) and `installer_targets` (the four logo and stylesheet filenames, which is where the logo filenames are frozen). **My mutations:** removing a frozen custom property name everywhere turned `css_custom_properties_sg: baseline is a subset of the current surface` red; changing the `Profile` accent default `#c2410c` to `#c2410d` turned the ratchet's default-value test and four legacy-profile output tests red. |
| 4a | SC-4 (copy): reconciled vocabulary table, per-lane inventory, banned-term and lexicon drift test with shrink-only baseline | VERIFIED (with warnings) | `admin-glossary.md` rows 57-69 carry the rulings (Active/Unconfirmed/Locked, "Deletion scheduled" kept, "Admin" not "Admin (operator)", "Review users"), each opening with Agrees or Differs and anchored to a file:line that `vocabulary_docs_test` resolves. Inventory TSVs: library 344 lines, generated 631, host 24. `copy_contract_test` compares scan hits to `copy-baseline.json` exactly (no new, no stale). **My mutation:** adding "please log in again" to a generated `sudo_controller.ex` flash string turned the generated-scope test red with "new banned term ... fix the copy, do not baseline new violations". Warnings: scan coverage holes are documented (see W-5, W-6). |
| 4b | SC-4 (install snippet): three-segment `{:sigra, "~> x.y.z"}`, all equal | VERIFIED | My grep over README, `guides`, `docs`, `priv/templates`: 11 tuples, all `~> 1.5.0`. **My mutation:** a two-segment `~> 1.5` in README turned three `install_snippet_test` tests red (three-segment, all-equal, real docs report no findings). |
| 4c | SC-4 (Playwright): "Log in" text locators replaced by the test-only `loginSubmit` helper | VERIFIED | `helpers/loginSubmit.ts` exports `LOGIN_SUBMIT_SELECTOR = '#login_form button:not([type="button"])'`; used by `adminFlows.ts` and five specs. The `Log in` strings that remain in `demo-showcase.spec.ts` are heading assertions and a code comment, not submit locators. The ExUnit selector test is in the green 60. `admin-generated.spec.ts` still locates "Sign in with password" by text; that is a generated-host button with a different label and is outside the "Log in" locators this requirement names (see I-2). |
| 4d | SC-4 (enumeration): parity tests pass for every pre-auth surface and go red exactly once on an injected leak | VERIFIED | Registry `public-surfaces.json` has 13 rows: 5 `parity` (password-signin, magic-link-request, password-reset-request, confirmation-resend, mfa-challenge), 3 `known_divergence` (repeat-attempt lockout, registration, passkey-signin-options), 2 `by_design` (invitation-accept, enterprise-sso-discovery), 3 `not_proven` (two rate limits and lib moduledoc claims; none is a named request surface). Every BCOPY-03 surface has an asserted state. `enumeration_parity_test.exs`: 38 tests, 0 failures, including the control "a leak on exactly one parity surface yields exactly one diff, the others stay :same". **My product-level mutations (below)** show each probe observes the real response. Interpretation is now owner-recorded (ADR 005 amendment B). |
| 4e | SC-4 (honesty): docs and tests claim no enumeration safety beyond what is proven | VERIFIED (with warnings) | README Enumeration row (line 177) bounds the claim to sign-in, magic-link and password-reset requests in the example application at a single attempt and lists what is not covered. **My mutation:** replacing the row with "Sigra is enumeration-safe by default across every flow" turned five `claims_docs_test` tests red (unbounded-claim sweep, retired phrases, row lock, scope paragraphs, sweep controls). Warnings W-5 and W-8. |
| 5 | SC-5: name-clearance record titled "search log, not clearance" with `crosswake_sigra`, claims register, logo-use and clear-space decisions, no trademark claim; pointer fix only after owner approval; privacy and process budget hold | VERIFIED | ADR 006 title is "Name and trademark posture: search log, not clearance"; `## The same-name package: crosswake_sigra` (0.1.3, Apache-2.0, lookup re-run 2026-11-14); `## Decision: no trademark claim`; clear-space and logo-use decisions. No `®`, `™` or "registered trademark" anywhere in README, guides, docs, `CLAUDE.md` or `AGENTS.md`. BPOL-06 pointer fix is in `CLAUDE.md:230`, `AGENTS.md:8`, `admin-ui-principles.md` and `admin-design-contract.md`, under the owner approval recorded as ADR decision 12 on 2026-11-13. `git diff --stat .github scripts` is empty (process budget). No `!` marker or BREAKING footer in any commit since the phase base; types are docs 72, test 26, chore 12, fix 10, feat 1. `name_clearance_test` cross-checks every register status against its registry row: when I downgraded a registry row in the scratch copy and left the register alone, that test went red on its own. |

**Score:** 9/9 truths verified (0 present-but-behavior-unverified).

None of the nine truths asserts a runtime state transition or cancellation invariant in shipped code; the behaviour-bearing ones (parity, reset, resend) are exercised by named tests that I ran and mutated, so no truth is left at `PRESENT_BEHAVIOR_UNVERIFIED`. No truth holds by an undeclared precondition: the one structural assumption (the example host stands in for generated code) is stated in the README and the registry, not hidden, so no `coincidental_reliance_items` entry is raised.

### Mutation controls I ran myself

All in a throwaway copy made from `git ls-files` plus the build directories (the working tree was never touched; `git status --short` was empty after every run). The copy's baseline was green before any mutation. Each mutation was reverted and the copy re-checked.

| # | Mutation (scratch only) | Expected | Observed |
|---|-------------------------|----------|----------|
| 1 | Reset view flashes "No account found for that email." when the address has no account | parity red on `password-reset-request` | 4 failures; `password-reset-request: [{:flash, "If your email is in our system...", "No account found for that email."}]`, plus the non-vacuity test naming the unknown probe's captured flash |
| 2 | Resend handler acts on the payload email (sends confirmation mail) but redirects identically | red on the result dimension only | 4 failures; `confirmation-resend: [{:result, %{confirmation_tokens: 2}, %{confirmation_tokens: 0}}]` |
| 3 | Registry: `password-reset-request` downgraded to `not_proven` with a blocker | named-surface rule red | 7 failures including `password-reset-request: state is "not_proven" but a named surface must be parity`; separately `name_clearance_test` caught the register-versus-registry disagreement |
| 4 | One space appended to vendored `brand/BRAND.md` | pin red | `source_pin_test` 1 failure naming `brand/BRAND.md` |
| 5 | Every occurrence of a frozen `--sg-space-1` name removed from the admin CSS template | ratchet red | `css_custom_properties_sg: baseline is a subset of the current surface` |
| 6 | `Profile` accent default changed `#c2410c` to `#c2410d` | ratchet and legacy red | 6+ failures across `frozen_surface_test` and `legacy_profiles_test` |
| 7 | README install tuple changed to two segments | install snippet red | 3 failures |
| 8 | Banned phrase added to a generated flash string | generated-scope copy test red | 1 failure naming the file and the string |
| 9 | README Enumeration row replaced with an unbounded claim | claims tests red | 5 failures |

Two of my first attempts were invalid negatives, and I discarded them rather than count them: a rename of only a CSS declaration (the extractor also matches the name in `var(...)` uses, so the name survived) and a plant into a template with no `put_flash`. I redid both with a mutation that provably took effect.

## Gap-closure plans 259-14 to 259-18 and review fixes: regression check

| Plan | Must-have | Status | Evidence |
|------|-----------|--------|----------|
| 14 | Reset page mounts (`:new`), view passes the binary email, row is `parity`, probe non-vacuous | VERIFIED | `router.ex:119` is `live "/reset-password", ResetPasswordLive, :new`; `reset_password_live.ex` `send_instructions` calls the context unconditionally with the binary email; mutation 1 |
| 15 | Confirm page reachable in both session states, nil-safe, `confirmation-resend` parity with a `result` dimension | VERIFIED | `session_user/1` is nil-safe; mutation 2 |
| 16 | Named-surface rule judged per class, no "at least three of five" tolerance | VERIFIED | mutation 3 |
| 17 | Generated-host defects filed, not fixed | VERIFIED | todos exist; I re-confirmed the template lines above |
| 18 | README, guide, claims tests, register and deferred-items aligned to the repaired registry | VERIFIED | mutation 9 |
| quick 261115-dug | ADR confirmations, guide Step 1 fix, tests re-pinned | VERIFIED | diff read above; 359 tests green |

## Deferred Items

Items not met but explicitly tracked. None is a gap against this phase's success criteria.

| # | Item | Tracked in | Note |
|---|------|-----------|------|
| 1 | Generated reset request page defects (no `:new` action in the installer route; user struct passed to a binary-only head) | `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` | Shipped-byte fix; the owner's direction (ADR 005 amendment B) is before Phase 262. See planner note 1 |
| 2 | Generated non-live confirm controller flavor | `.planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` | Same direction |
| 3 | Registration timing oracle and passkey options oracle | `.planning/todos/pending/2026-11-13-duplicate-registration-timing-oracle.md`, `.planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md` | Real leaks, asserted to still differ |
| 4 | Residual `brandbook/` pointers in three further admin reference guides | `.planning/todos/pending/2026-11-13-residual-brandbook-pointers.md` | Outside the owner-approved four-file scope (ADR decision 12) |

### Advisory (New Scope, Unevidenced)

None. Every finding below carries deterministic evidence (a source line, command output or a mutation result).

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| ADR 005, ADR 006, `guides/reference/brand-compatibility.md`, `contract.md` section | policy and register | VERIFIED | `policy_docs_test`, `name_clearance_test`, `claims_docs_test` |
| `brand.sha256`, `.gitattributes` | pin | VERIFIED | 72/72 OK; `brand/** -text linguist-vendored` |
| `test/fixtures/brand/*.json`, `copy-inventory/*.tsv` | ratchets, baselines, inventory | VERIFIED | present, non-empty, mutation-checked |
| `test/fixtures/brand/public-surfaces.json` | parity registry | VERIFIED | 13 rows: 5 parity, 3 known_divergence, 2 by_design, 3 not_proven |
| `test/sigra/brand/*.exs` (12), `test/support/brand/*.ex` (3) | contracts | VERIFIED | 359-test run green (with `guides_dx02_test.exs`) |
| `test/example/test/example_web/enumeration_parity_test.exs` | parity harness | VERIFIED | 38 tests, 0 failures, mutation-checked |
| `test/example/test/example_web/live/{reset_password,confirmation}_live_test.exs`, `login_submit_selector_test.exs` | regression and selector suites | VERIFIED | in the green 60 |
| `test/example/lib/example_web/{router.ex,live/reset_password_live.ex,live/confirmation_live.ex}` | repaired example host | VERIFIED | code read; test code, not a shipped byte |
| `test/example/priv/playwright/helpers/loginSubmit.ts` | login helper | VERIFIED | used by five specs and `adminFlows.ts` |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `router.ex:119` | `ResetPasswordLive.mount/3` | `:new` live action | WIRED | dropping it raised `CaseClauseError` in the previous report's mutation |
| `router.ex` `live_session :confirmation` | `ConfirmationLive` | `:mount_current_scope` | WIRED | anonymous and signed-in tests mount |
| registry rows | parity test | probe clause, expected-flash table, `@required_dimensions`, `@expected_todos` | WIRED | mutation 3 and the in-file controls |
| registry rows | claims register in ADR 006 | `name_clearance_test` status cross-check | WIRED | mutation 3 |
| README and guides | registry | `claims_docs_test` row locks and sweep | WIRED | mutation 9 |
| `brand/brand.json` | lexicon scan | `CopyScan.lexicon_words/0` | WIRED | `copy_contract_test` reads ten terms from the pinned book |
| ADR 005 amendment | todos | `policy_docs_test` filename assertions | WIRED | both leak todos named and asserted |

## Data-Flow Trace (Level 4)

Not applicable to shipped code: nothing that ships was added. For the example-host repairs the flow is real: the reset probe's existing-email request writes a `reset_password` `UserToken` row and the resend probe's `result` dimension counts confirmation tokens; mutations 1 and 2 show both respond.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Brand contracts plus the guide DX test | `source tmp/db.env && MIX_ENV=test mix test test/sigra/brand test/sigra/guides_dx02_test.exs` | 359 tests, 0 failures | PASS |
| Example-host parity, selector, reset and confirm suites | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs test/example_web/login_submit_selector_test.exs test/example_web/live/confirmation_live_test.exs test/example_web/live/reset_password_live_test.exs` | 60 tests, 0 failures | PASS |
| Pin independent of ExUnit | `shasum -a 256 -c brand.sha256` | 72 OK | PASS |
| Zero shipped bytes | `git diff --stat aeda7273d HEAD -- lib priv brand brandbook .github scripts` | empty (control: unfiltered diff is 117 files) | PASS |
| Formatting | `MIX_ENV=test mix format --check-formatted` | exit 0 | PASS |
| Debt markers | grep of added lines outside `.planning` and `brand/` for TBD, FIXME, XXX, TODO, HACK, PLACEHOLDER | none | PASS |
| Working tree | `git status --short` | empty before and after | PASS |

I did not re-run the full `mix ci` (2991 tests): everything changed since the last full run is documentation plus two brand doc-contract tests, and all of those are in the 359 above. The previous report's full-gate result at an earlier HEAD (exit 0, 2991 tests, 0 failures) is not re-claimed here.

## Probe Execution

SKIPPED: no PLAN declares a `probe-*.sh`, and this is not a migration or tooling phase.

## Requirements Coverage

All fourteen IDs declared across the eighteen plans match the fourteen `.planning/REQUIREMENTS.md` maps to Phase 259; no orphans, none missing.

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| BPOL-01 | 259-01 | SATISFIED | Truth 1 |
| BPOL-02 | 259-02 | SATISFIED | Truth 2 |
| BPOL-03 | 259-05 | SATISFIED | Truth 3 |
| BPOL-04 | 259-11 | SATISFIED | Truth 5 |
| BPOL-05 | 259-01 | SATISFIED | decisions recorded and now owner-confirmed with dates |
| BPOL-06 | 259-09 | SATISFIED (narrow) | four files fixed under the 2026-11-13 approval; residual pointers are a filed todo (W-9) |
| BPOL-07 | 259-01 | SATISFIED | guide "Upgrade notes" |
| BCOPY-01 | 259-12 | SATISFIED | Truth 4a |
| BCOPY-02 | 259-08 | SATISFIED (bounded) | Truth 4a; W-5, W-6 |
| BCOPY-03 | 259-07, 13-18 | SATISFIED | Truth 4d; five parity rows, the rest honestly registered |
| BCOPY-04 | 259-06 | SATISFIED (bounded) | exact-equality test over three lanes |
| BCOPY-05 | 259-04 | SATISFIED | Truth 4b |
| BCOPY-06 | 259-03 | SATISFIED | Truth 4c |
| BCOPY-07 | 259-10, 11, 13-15, 17, 18 | SATISFIED (bounded) | Truth 4e |

`.planning/REQUIREMENTS.md` still shows BCOPY-03 and BCOPY-07 as `[x]` Complete and the other twelve as `[ ]` with "Gaps Found" in the traceability table (left over from the first, failed verification). The orchestrator should reconcile that table when it completes the phase.

## Anti-Patterns Found

No debt marker, stub implementation or hardcoded-empty data in any added line outside `.planning` and `brand/`. Nothing blocks. All items are warnings or info, each with a recorded home.

| ID | File | Pattern | Severity | Impact |
|----|------|---------|----------|--------|
| W-2 | `test/fixtures/brand/public-surfaces.json` row `confirmation-resend` | Labelled `parity` but proves "a payload email is ignored"; no email-keyed resend form exists, so there is no existing-versus-unknown channel to compare | Warning | Honestly stated in the row, the register and the test header, counted as its own class. Do not read "parity" on that row as enumeration evidence |
| W-5 | `test/support/brand/copy_scan.ex`, `test/sigra/brand/claims_docs_test.exs` | Scanner misses a phrase split over `<>`-joined literals or HTML entities; claim recogniser misses wordings such as "prevents username enumeration" | Warning | Regression guards narrower than their titles; deferred with diagnosis; no current hit is masked |
| W-6 | `priv/templates/sigra.gen.oauth/**`, `priv/templates/sigra.upgrade/**` | Outside every copy scope and inventory lane; they ship "Log in to link your ... account" | Warning | Owner default (UAT): sweep by hand in Phase 262. Not on the Phase 262 worklist yet |
| W-7 | `frozen_surface_test.exs`, `copy_contract_test.exs` and fixtures | Both ratchets can be loosened by editing JSON in the same commit; no base-branch diff gate | Warning | "Can only grow" holds for the opt-in writer and accidental drift, not a deliberate fixture edit; relies on review |
| W-8 | `lib/sigra/lockout.ex:13`, `error.ex`, `auth.ex`, installer template comments | Published moduledocs still say "enumeration-safe" | Warning | Zero-lib-bytes rule forbids editing here; bounded by the register |
| W-9 | `guides/reference/admin-graphic-design-lens.md`, `admin-token-reference.md`, `admin-fractal-scorecard.md` | Still cite `brandbook/` paths | Warning | Outside the four-file scope the owner approved; `brandbook/` still exists so the paths resolve; todo filed |
| I-1 | `.planning/STATE.md:170` | Still says the clear-space authority is "owner confirmation pending (ADR 006)" | Info | Stale planning prose; both ADRs and their tests are correct. Orchestrator-owned file |
| I-2 | `test/example/priv/playwright/tests/admin-generated.spec.ts:74,101` | Locates the generated password button by its text "Sign in with password" | Info | Not a "Log in" locator, so outside BCOPY-06; Phase 262 may change that label, and this is the place that will break |
| I-3 | `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` line 56, `deferred-items.md` (259-10 item 2) | Still say the guide snippets pass the user struct; commit `6a6629289` corrected them | Info | Stale planning prose only |
| I-4 | `test/example/lib/example_web/live/confirmation_live.ex:104` | `handle_params(%{"token" => ...})` dereferences `current_scope.user`, which would raise for an anonymous visitor | Info | Unreachable: the example routes no `:token` param to this LiveView; kept because an installer-drift test requires the binding; recorded in `deferred-items.md` |

### Human Verification Required

None. The four former items are resolved above, and none of what remains needs a person: the browser run of the Playwright specs is an automatic PR lane, and the remaining warnings are recorded deferrals with an owner default or a filed todo. The one thing I could not do myself is witness the owner's reply; the repo records it (two commits, an ADR amendment, the UAT file), and the phase goal does not depend on it because SC-1 requires the decisions to be recorded, not confirmed.

## Gaps Summary

No gaps. Every must-have is verified against the tree and, for the contracts, against mutations that make each one go red. Status is `passed`.

## Notes for the next phase planner

1. **The owner's "fix the leaks before Phase 262" has no phase to carry it.** ADR 005 amendment B says the registration and passkey-options leaks, plus the generated confirm and reset-request fixes, are shipped-byte work before Phase 262. Phase 260's success criterion 5 forbids changing copy, markup or `Profile` keys, and Phase 261 is tokens and type, so neither is a natural home. Schedule it (a quick task or an inserted phase) or the todos will still be open when Phase 262 starts.
2. **Parity re-run in Phase 262 is example-host only.** The harness drives `test/example`, a hand-maintained copy, so a generated-template change is proven only if the example is changed to match. The generated reset request page has two filed defects, so Phase 262's 4c, which rewrites generated auth screens, should either fix them first or leave that view and the installer route alone.
3. **Reconcile the Phase 262 status words.** ROADMAP Phase 262 criterion 1 lists "(Deleting, Locked, Unconfirmed, Active)"; ADR 005 decision 6 (now confirmed) and Phase 259's SC-1 keep "Deletion scheduled". Fix the roadmap text before Phase 262 plans.
4. **Treat the ratchet and baseline fixtures as security-relevant diffs** in later phases (W-7); they are loosened by editing JSON.
5. **Add `sigra.gen.oauth`, `sigra.upgrade` and `admin-generated.spec.ts` to the Phase 262 worklist** (W-6, I-2) or decide explicitly that they are out of scope.

---

_Verified: 2026-11-15T15:13:59Z_
_Verifier: Claude (gsd-verifier)_
