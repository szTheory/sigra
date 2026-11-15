---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
verified: 2026-11-15T01:10:00Z
status: gaps_found
score: 7/8 must-haves verified
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
  - guides/reference/admin-design-contract.md
  - guides/reference/admin-glossary.md
  - guides/reference/admin-ui-principles.md
  - guides/reference/brand-compatibility.md
  - test/example/README.md
  - test/example/priv/playwright/helpers/adminFlows.ts
  - test/example/priv/playwright/helpers/loginSubmit.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts
  - test/example/priv/playwright/tests/golden-path.spec.ts
  - test/example/priv/playwright/tests/organizations.spec.ts
  - test/example/priv/playwright/tests/passkey-options.spec.ts
  - test/example/test/example_web/enumeration_parity_test.exs
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
covered_digest: "v4:sha256:9aefa36c4f507f003c0f8743bac941d0c5bf775e724b1e86bfc81929f541dc7f"
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The enumeration-parity tests pass for every pre-auth surface (BCOPY-03 names sign-in, reset, magic link, resend, registration, invitation, MFA, passkey) and go red exactly once when a deliberately leaky string is injected"
    status: partial
    reason: "The harness, the registry and the positive control are real and green (32 example-host tests, 0 failures). But two named pre-auth surfaces, password-reset-request and confirmation-resend, have NO test at all: both are registered not_proven because the example host cannot mount the reset request page or complete a resend. A third named surface counted as parity, mfa-challenge, compares a wrong authenticator code against a wrong backup code, not an existing against an unknown account. So only sign-in and magic-link request are genuine existing-versus-unknown-identity parity probes. The plan's own 'at least three of five' floor and escape hatch were used, but a plan cannot shrink a roadmap success criterion."
    artifacts:
      - path: "test/fixtures/brand/public-surfaces.json"
        issue: "password-reset-request and confirmation-resend rows are state not_proven with compare: [] (no probe)"
      - path: "test/example/test/example_web/enumeration_parity_test.exs"
        issue: "named-surface test accepts not_proven for two of five and counts mfa-challenge (code kind, not account existence) toward the floor of three"
      - path: "test/example/lib/example_web/router.ex"
        issue: "line 112: live \"/reset-password\" has no :new live action, so ResetPasswordLive.mount/3 raises on nil live_action; the example host cannot drive the request form (the example host is test code, not a shipped byte)"
      - path: "test/example/lib/example_web/live/confirmation_live.ex"
        issue: "line 158: resend handler reads current_scope.user, which is nil for an anonymous visitor; signed-in visitors are redirected before mount (router.ex:106), so no session state completes a resend"
    missing:
      - "A deterministic existing-versus-unknown probe for the password-reset request, or an owner-accepted override recording that the example host cannot drive it"
      - "A deterministic probe for the confirmation resend (or an owner-accepted override), or a registry row that stops listing it among the five named surfaces"
      - "A decision on whether mfa-challenge may count toward the named-parity floor (already filed as the residual of WR-08 in the deferred-findings todo)"
deferred: []
---

# Phase 259: Compatibility Policy, Pinned Source and Copy Contract Verification Report

**Phase Goal:** A maintainer can state, and a test enforces, exactly what the rebrand may and may not change: the policy is written, the brand book is pinned in-repo, and the copy and enumeration-safety contracts are under test before any visible change is made.
**Verified:** 2026-11-15T01:10:00Z
**Status:** gaps_found
**Re-verification:** No, initial verification

## Verdict in one paragraph

Thirteen of fourteen requirement areas are genuinely achieved and enforced by tests that pass on a clean tree, with zero shipped bytes. One roadmap success-criterion clause is not met as written: the enumeration-parity tests do not cover every pre-auth surface. Two surfaces the requirement names (password reset request, confirmation resend) have no probe, and a third counted as parity is not an account-existence comparison. The shortfall is documented honestly in the registry, the claims register and a deferred-items file, and it looks intentional, so an owner override is a legitimate way to close it (suggested block below). It is not hidden and it does not block Phases 260 and 261; it does need a decision or a fix before Phase 262, which re-runs parity on touched pre-auth slices.

## Goal Achievement

### Observable Truths

Roadmap success criteria are the contract; PLAN must-haves added detail but never reduced scope. SC-4 has several independent clauses, so it is split.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC-1: ADR, `contract.md` section and `guides/reference/brand-compatibility.md` carry the frozen list, add-only list, ownership-lane table, surface map with a brand-owner column, the recorded decisions and an upgrade-note skeleton | VERIFIED | ADR 005 (165 lines) has all seven decisions, lane table, nine-row surface map with Brand owner column, frozen counts that I re-measured (100 `--sg-*` properties via grep, matches). Guide repeats them plus consumed-subset table, SemVer treatment and a five-step upgrade skeleton with an intentionally empty "Visual and copy changes" table. `contract.md` has a compact section pointing at the guide (diff read). `policy_docs_test.exs` passes. 11 of 12 owner decisions are labelled "Recommended default - owner confirmation pending" (see Human Verification). |
| 2 | SC-2: consumed brand subset pinned in `brand/` with root `brand.sha256`; editing any byte turns the single drift test red; every imported file passes the privacy scan incl. SVG/PDF metadata; `brandbook/` untouched; `git diff --stat -- lib priv` empty | VERIFIED | `shasum -a 256 -c brand.sha256` independently: exit 0, 72/72 OK, 72 files on disk. `.gitattributes` has `brand/** -text linguist-vendored`. `git diff --stat aeda7273d HEAD -- lib priv brand brandbook .github scripts` is empty (positive control: the same diff lists 49 other files). `source_pin_test.exs` has in-memory mutate/remove/add controls and scanner planted-failure controls for home paths, emails, file URLs, SVG metadata, PNG chunks, PDF Author and Creator/Producer, JPG Exif. I additionally derived the user's name tokens at run time and grepped the whole `brand/` tree including binaries: the only hit is the vendored `brand/index.html` og:image URL (the book's authoring origin, byte-pinned and already on main before this phase; accepted as T-259-07). The origin and name are absent from every added line of the phase diff and from the phase directory. The vendored PDFs carry only Title, Creator (browser UA) and Producer (Skia). All emails in `brand/` are fictional `.test` addresses. |
| 3 | SC-3: frozen-surface ratchet green, can only grow; legacy Branding profiles render byte-identically | VERIFIED | `frozen_surface_test.exs`: 11 categories (config option paths 170, `sg-*` classes 168, `sigra-auth*` classes 66, `--sg-*` 100, `--sigra-auth-*` 35, test ids 25, gettext domain 1, installer targets 4, profile defaults 25, routes 60, `~p` helpers 54), each extracted live from source and asserted `baseline SUBSET-OF current` and non-empty; `extend_only/2` refuses a shrinking proposal; the extension writer is CI-guarded. `legacy_profiles_test.exs`: explicit/partial/defaults x six public `Branding` functions compared with `==` to a committed fixture, with a positive control. All green. Caveat: WR-05 (a human can shrink the baseline JSON in the same commit as the break; no base-branch diff gate) is deferred, see Anti-Patterns. |
| 4a | SC-4 (copy): reconciled vocabulary table, per-lane copy inventory, banned-term/lexicon drift test with shrink-only baseline | VERIFIED (with warnings) | Glossary has a 23-row "Brand book v2.0 reconciliation" table (Active/Unconfirmed/Locked, "Deletion scheduled" kept, "Admin" not "Admin (operator)", "Review users"); I spot-checked six `path:line` anchors against source and all match. Inventory TSVs exist for library (322 rows), generated (608), host (4) and are asserted equal to a fresh extraction. `copy_contract_test.exs` scans lexicon/admin/generated scopes against `copy-baseline.json` (shrink-only both directions; 36 admin and generated hits plus 6 lexicon hits baselined, 42 entries). Warnings: the inventory and the admin scope have documented coverage holes (WR-03 scope part, WR-04). |
| 4b | SC-4 (install snippet): three-segment `{:sigra, "~> x.y.z"}`, all equal across README, guides, docs, templates | VERIFIED | `install_snippet_test.exs` scans README, `guides/**`, `docs/**`, `priv/templates/**`; non-vacuity checks and planted controls. My own grep: every tuple is `~> 1.5.0`; no two-segment form anywhere. |
| 4c | SC-4 (Playwright): the "Log in" text locators replaced by the test-only `loginSubmit` helper | VERIFIED | `helpers/loginSubmit.ts` exists; the diff removed 11 `button:has-text("Log in")` locators across `adminFlows.ts` and five specs (the roadmap's "eight" counts specs/sites; none remain anywhere in the repo, verified by a repo-wide search; the three surviving `"Log in to ..."` hits are heading assertions on the demo brand lab, not button locators). `login_submit_selector_test.exs` proves the selector matches exactly one element on the real example login page and has planted controls. Playwright itself is not installed locally, so the specs' browser run is CI-only (see Human Verification, advisory). |
| 4d | SC-4 (enumeration): parity tests pass for every pre-auth surface and go red exactly once on an injected leak | FAILED (partial) | Positive control is real: `a leak on exactly one parity surface yields exactly one diff` and `every parity surface can go red` pass; non-vacuity guard (WR-08) asserts real flash/body capture. But reset request and confirmation resend have no probe, and `mfa-challenge` is a code-kind comparison. Registry: 3 parity, 3 known_divergence (registration, passkey options, lockout), 2 by_design, 5 not_proven. See Gaps. |
| 4e | SC-4 (honesty): docs and tests claim no enumeration safety beyond what is proven | VERIFIED (with warning) | README "Enumeration" row, `login-and-logout`, `password-reset`, `registration`, `architecture`, `code-walkthrough`, `demo-showcase`, `getting-started` were reworded with "Scope of this claim" bounds; `claims_docs_test.exs` sweeps claim units (paragraph, table row, list item) for unbounded claims with planted controls including a mutation of the real README. My independent grep over README, guides, docs and CHANGELOG finds no remaining unbounded claim in prose (the one hit is a quoted code comment inside a fenced block). Warning: library moduledocs published on HexDocs (`lib/sigra/lockout.ex:13`, `lib/sigra/error.ex`, `lib/sigra/auth.ex`) and installer template comments still say "enumeration-safe"; they cannot be edited under the zero-lib-bytes rule and are tracked by a filed todo and bounded by the claims register. |
| 5 | SC-5: name-clearance record titled "search log, not clearance" with `crosswake_sigra`, claims register, logo-use and clear-space decisions, no trademark claim; pointer fix only after owner approval; privacy grep and process budget hold | VERIFIED | ADR 006 title "Name and trademark posture: search log, not clearance"; lookup table; `crosswake_sigra` section (I re-queried the Hex API: exists, 0.1.3, Apache-2.0, 463 downloads, matches); clear-space decision records the book disagreeing with itself; logo-use wording; 21-row claims register; explicit "no trademark claim". BPOL-06 approval is a pre-phase fact: `git show aeda7273d:.planning/REQUIREMENTS.md` already reads "owner approval granted 2026-11-13". The edits are minimal pointer changes in `CLAUDE.md`, `AGENTS.md`, `admin-ui-principles.md`, `admin-design-contract.md`. Privacy: no home-path shape in added lines or the phase dir (the 17 hits are regex literals in plan text, not real paths). Process budget: `git diff --stat .github scripts` empty; no new workflow, ledger, fake or Mix task; no `!` or BREAKING in any of the 78 commits. |

**Score:** 7/8 truths verified (0 present-but-behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.planning/decisions/005-brand-adoption-compatibility-policy.md` | policy ADR | VERIFIED | 165 lines, substantive, asserted by `policy_docs_test.exs` |
| `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` | name record and register | VERIFIED | substantive; asserted by `name_clearance_test.exs` and `claims_docs_test.exs` |
| `guides/reference/brand-compatibility.md` | public guide | VERIFIED | not an ExDoc extra by design |
| `guides/introduction/contract.md` | compact section | VERIFIED | additive H2, H1 unchanged |
| `brand.sha256`, `.gitattributes` | pin | VERIFIED | 72/72 files, independently checked |
| `test/fixtures/brand/frozen-surface.json` | ratchet baseline | VERIFIED | 11 categories, non-empty |
| `test/fixtures/brand/legacy-profiles.json` | byte-identity fixture | VERIFIED | three shapes x six functions |
| `test/fixtures/brand/copy-baseline.json` | shrink-only baseline | VERIFIED | 42 reviewed legacy hits |
| `test/fixtures/brand/copy-inventory/*.tsv` | per-lane inventory | VERIFIED (bounded) | coverage headers state what is not extracted |
| `test/fixtures/brand/public-surfaces.json` | parity registry | VERIFIED but incomplete | 13 rows; 5 not_proven |
| `test/sigra/brand/*.exs` (12 files) and `test/support/brand/*.ex` (3) | contracts | VERIFIED | 331 tests, 0 failures |
| `test/example/test/example_web/enumeration_parity_test.exs` | parity harness | PARTIAL | green, but see Gaps |
| `test/example/priv/playwright/helpers/loginSubmit.ts` | login helper | VERIFIED | used by 5 specs + `adminFlows.ts` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| ADR 005 frozen list | `frozen-surface.json` + ratchet test | counts re-measured; extractors read live sources | WIRED | 100 `--sg-*` matches my own grep |
| `brand/brand.json` | lexicon scan | `CopyScan.lexicon_words/0` reads the pinned file | WIRED | ten Do-not-say terms asserted verbatim |
| glossary reconciliation rows | product source | `path:line` anchors checked by `vocabulary_docs_test.exs` | WIRED | six anchors hand-checked |
| registry rows | todos | fixed todo paths, existence asserted | WIRED | four enumeration todos present in `.planning/todos/pending/` |
| `loginSubmit.ts` | Playwright specs | import and call | WIRED | no text locator remains |
| `public-surfaces.json` | claims register / README | register cites registry states; README restates only bounded claims | WIRED | `claims_docs_test.exs` |

### Data-Flow Trace (Level 4)

Not applicable: no runtime-rendered dynamic data was added. Every artifact is a document, fixture or test. The tests read real sources (templates, CSS, `Profile.defaults/0`, golden router, `lib/sigra/config.ex` AST) rather than hardcoded lists, and each has a non-vacuity guard.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Brand contract suite | `source tmp/db.env && MIX_ENV=test mix test test/sigra/brand` | 331 tests, 0 failures | PASS |
| Example-host parity + selector uniqueness | `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs test/example_web/login_submit_selector_test.exs` | 32 tests, 0 failures | PASS |
| Pin independent of ExUnit | `shasum -a 256 -c brand.sha256` | exit 0, 72 OK, 0 failures | PASS |
| Formatting | `mix format --check-formatted` | exit 0 | PASS |
| Clean tree | `git status --short` | empty | PASS |
| Hex same-name package | `curl https://hex.pm/api/packages/crosswake_sigra` | 0.1.3, Apache-2.0, 463 downloads | PASS |
| Full root `mix test` | see Environment note below | not relied on | SKIPPED |

Environment note: a bare `mix test` was started to catch collateral breakage from the new guide and `test/support/brand/*.ex` files. It runs the scaffold-tagged tests that `mix ci` excludes and was still running when this report was finalized, so its result is not used. The summary of plan 11 records `MIX_ENV=test mix ci` green (2939 tests, 0 failures) at the phase gate; I did not re-run `mix ci`.

### Probe Execution

SKIPPED: no PLAN declares a `probe-*.sh` and this is not a migration or tooling phase with conventional probes.

### Requirements Coverage

All fourteen IDs from the plans match the fourteen REQUIREMENTS.md maps to Phase 259; no orphans.

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| BPOL-01 | 259-01 | Compatibility policy: ADR, contract.md section, guide; frozen/add-only/lanes/surface map | SATISFIED | Truth 1 |
| BPOL-02 | 259-02 | Vendored subset, `brand.sha256`, one drift test, `.gitattributes`, `brandbook/` untouched, privacy scan | SATISFIED | Truth 2. Personal-names clause is not in the ExUnit test by design; I re-ran it independently at verification time (clean except the pre-existing, byte-pinned authoring-origin URL) and plan 11 recorded the same gate |
| BPOL-03 | 259-05 | Add-only ratchet; legacy profiles byte-identical | SATISFIED | Truth 3 |
| BPOL-04 | 259-11 | Name-clearance record "search log, not clearance", `crosswake_sigra`, claims register, logo-use and clear-space | SATISFIED | Truth 5 |
| BPOL-05 | 259-01 | Decision records | SATISFIED (recorded) | All seven decisions recorded in ADR 005; 11 await owner confirmation |
| BPOL-06 | 259-09 | Instruction-file pointer fix, owner approval | SATISFIED (narrow) | Four files fixed, approval pre-dates the phase. Three admin reference guides and `test/example/AGENTS.md` still cite `brandbook/`; filed as todos (warning) |
| BPOL-07 | 259-01 | Upgrade-note skeleton | SATISFIED | Guide "Upgrade notes" 1-5 |
| BCOPY-01 | 259-12 | Reconciled vocabulary table | SATISFIED | Truth 4a |
| BCOPY-02 | 259-08 | Banned-term and lexicon drift test, shrink-only baseline | SATISFIED | Truth 4a (WR-04 scope warning) |
| BCOPY-03 | 259-07, 259-13 | Public-surface registry and parity tests for the eight surfaces, with a positive control | PARTIAL | Truth 4d: reset and resend have no probe |
| BCOPY-04 | 259-06 | Committed copy inventory per ownership lane | SATISFIED (bounded) | Three lanes, exact-equality test; coverage limits stated in each header |
| BCOPY-05 | 259-04 | Three-segment install-snippet test | SATISFIED | Truth 4b |
| BCOPY-06 | 259-03 | `loginSubmit` helper replaces text locators | SATISFIED | Truth 4c |
| BCOPY-07 | 259-10, 259-11, 259-13 | Honest-claims pass, timing todo cited | SATISFIED (bounded) | Truth 4e; four enumeration todos filed |

### Anti-Patterns Found

A grep of every added line outside `.planning/` (and the manifest) for `TBD`, `FIXME`, `XXX`, `TODO`, `HACK` and `PLACEHOLDER` returns nothing, so the debt-marker gate is clear. No stub implementations. These items are warnings, none blocks:

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/sigra/brand/frozen_surface_test.exs`, `copy_contract_test.exs` + fixtures | n/a | WR-05: both ratchets protect a name only while it is in the committed JSON; a same-commit edit of the fixture loosens them, no base-branch diff gate, no CODEOWNERS; an unknown scope in a baseline entry is never compared | Warning | "can only grow" holds for the opt-in writer and for accidental drift, not for a deliberate fixture edit; relies on review. Deferred to an owner decision (CI base diff touches the `.github` budget) |
| `test/support/brand/copy_inventory.ex`, `copy_scan.ex` | n/a | WR-03 scope: inventory does not extract about 115 literal HEEx attribute copies (`aria-label`, `title`, `placeholder`, ...) or JS hook copy; coverage headers say so | Warning | "every copy change is a reviewable diff" is not true for those forms; Phase 262 attribute rewording would not appear in the inventory diff (the banned-term scan does read attributes) |
| `test/support/brand/copy_scan.ex` | 66-76 | WR-04: admin scope pinned to nine files; `lib/sigra/error.ex` (27 `safe_message` strings) and `lib/sigra/admin/audit/presenter.ex` are outside every scan | Warning | banned terms added there would pass |
| `guides/reference/admin-token-reference.md`, `admin-fractal-scorecard.md`, `admin-graphic-design-lens.md`, `test/example/AGENTS.md` | various | residual `brandbook/` pointers | Warning | BPOL-06's "admin guides" is read narrowly (the two guides CLAUDE.md names); todos `residual-brandbook-pointers` and `example-agents-md-retired-brand-pointer` filed |
| `lib/sigra/lockout.ex:13`, `error.ex`, `auth.ex`; installer templates | various | published moduledocs and template comments say "enumeration-safe" | Warning | zero-lib-bytes rule forbids editing; bounded in the register, todo filed |
| `4dad2ca17` `feat(259-09)` | n/a | a `feat` commit type for a docs-only pointer edit | Info | release-please will list it as a feature at the next release; harmless but noisy. No `!`, no BREAKING footer in any phase commit |

### Gaps Summary

**One gap (BLOCKER for Phase 262 readiness, not for Phases 260 and 261).**

SC-4 requires the enumeration-parity tests to pass "for every pre-auth surface", and BCOPY-03 names eight surfaces. The harness is well built: a registry-driven comparator, normalization limited to CSRF tokens, request ids and the echoed email, a non-vacuity guard, a positive control that goes red exactly once, and honest `known_divergence` rows that assert the three real leaks still differ (registration, passkey options, repeat-attempt lockout). What is missing is coverage, not quality:

1. **Password reset request has no probe.** The example host's router declares `live "/reset-password"` without a `:new` action, so the page raises on mount. I confirmed this in source (`router.ex:112`, `reset_password_live.ex` `case socket.assigns.live_action`). Observation worth the owner's attention, read in source and not executed: the installer emits the same route shape for LiveView installs (`lib/sigra/install/features/core.ex` lines 410-411, and the golden router fixture), and the generated `reset_password_live.ex` has the same `case`, so the reset request page may crash on mount in a LiveView-flavored generated host too. No browser test reaches it. This is more than an example-host quirk and no todo currently says so.
2. **Confirmation resend has no probe.** `confirmation_live.ex:158` and `router.ex:106` make it uncompletable in both session states in the example host; an existing todo says the generated confirm routes share the defect.
3. **MFA is counted as parity but compares code kinds.** The row note and claims register say so honestly; the "at least three of five" floor only holds because it counts. Effective existing-versus-unknown-account parity probes: two (sign-in, magic-link request).

The shortfall is not hidden: the registry, the claims register (ADR 006), the README row ("Not covered: ... password reset requests") and `deferred-items.md` all state it, and nothing over-claims. That is why it is a coverage gap and not a dishonesty gap. It is not deferrable under Step 9b: Phase 262's roadmap criterion says parity "re-runs green on touched pre-auth slices", a re-run, so no later phase builds the missing probes.

**This looks intentional.** To accept the reduced coverage, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "The enumeration-parity tests pass for every pre-auth surface and go red exactly once when a deliberately leaky string is injected"
    reason: "Password reset request and confirmation resend cannot be driven in the example host (router.ex:112, confirmation_live.ex:158); registered not_proven with cited blockers, bounded in the claims register, README lists both as not covered, and mfa-challenge is bounded as a code-kind comparison. Phase 262 must not change reset or resend responses until a probe exists."
    accepted_by: "{owner}"
    accepted_at: "{ISO timestamp}"
```

Otherwise close it by repairing the example host (add the `:new` action and the binary-email call; make resend reachable) and adding the two probes, ideally with a todo for the LiveView-flavor reset page.

### Human Verification Required

Genuinely not verifiable by a program. These are recorded for the owner; none changes the status above, which is already `gaps_found`.

#### 1. Owner confirmation of the recommended-default decisions

**Test:** Read ADR 005 decisions 1-9, 11, 14 and ADR 006's two decisions; confirm or amend each.
**Expected:** Each "Recommended default - owner confirmation pending" row is confirmed (or amended in place with a dated note). Only decision 12 is confirmed today.
**Why human:** a test can prove a decision is recorded and labelled, not that it is the right decision. Phase 260 (PNG park, which needs explicit approval) and Phase 263 (install-pin value, logo-use statement) inherit them.

#### 2. Playwright specs in a real browser

**Test:** Let the PR's `example_playwright_shard` lanes run the five edited specs and `adminFlows.ts`.
**Expected:** every login step still clicks the submit button.
**Why human:** Playwright is not installed locally. The selector is proven unique by an ExUnit test against the real example login page, so the residual risk is low; this is advisory.

#### 3. Wording and scope judgments

**Test:** Read the glossary rulings 2, 3, 5 (they follow pending decisions), the claims reword in the flow guides, and the copy-inventory coverage headers.
**Expected:** each stays inside what the harness proves; the three lanes are the right inventory scope or a wider one is requested (WR-03/WR-04).
**Why human:** editorial and scope judgments.

### Notes for the next phase planner

- ROADMAP Phase 262 success criterion 1 lists the status words "(Deleting, Locked, Unconfirmed, Active)". ADR 005 decision 6 and Phase 259's own SC-1 keep "Deletion scheduled". Reconcile the roadmap text before Phase 262 plans, or the plan will contradict the recorded decision.
- The ratchet and baseline fixtures should be reviewed as security-relevant diffs in later phases (WR-05), since they are loosened by editing JSON.

---

_Verified: 2026-11-15T01:10:00Z_
_Verifier: Claude (gsd-verifier)_
