---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 08
subsystem: testing
tags: [exunit, copy-contract, brand-lexicon, banned-terms, shrink-only-baseline, heex, scanner]

requires:
  - phase: 259-02
    provides: pinned brand/brand.json (version-pinned by brand.sha256), the single source of the Do-not-say lexicon and voice.terms avoid-words
provides:
  - test/support/brand/copy_scan.ex, Sigra.Test.Brand.CopyScan: three-scope copy scanner (lexicon, admin, generated), normalization, multiset baseline diff, opt-in baseline init
  - test/sigra/brand/copy_contract_test.exs, Sigra.Brand.CopyContractTest: 56 tests (planted-term units for both rule kinds in all scopes, extraction rules, shrink-only and init rules, real scans equal to the baseline)
  - test/fixtures/brand/copy-baseline.json, deterministic one-entry-per-line shrink-only baseline (42 entries, 3 initialized scopes)
affects: [260, 261, 262, 263]

actuals:
  tokens: 16800
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 5779f99c85262070250afda98105e8f7907f865c
plan_head_after: 89000f7b9fd73c53035acf667d76257ebe01e5de

tech-stack:
  added: []
  patterns:
    - "Scan copy, not code: Elixir and HEEx source is reduced to copy segments (string literals, HEEx text, expression literals, six copy attributes) by a small purpose-built scanner before any term is matched"
    - "Shrink-only baseline as a multiset: a hit not in the baseline fails, a baseline entry with no hit fails, and a repeated line needs a repeated entry"
    - "Initialization state lives in initialized_scopes, so a scope with zero hits is still initialized; init only fills scopes absent from it"
    - "Fail loud, never skip: an unterminated string, heredoc, tag or expression raises naming the file"

key-files:
  created:
    - test/support/brand/copy_scan.ex
    - test/sigra/brand/copy_contract_test.exs
    - test/fixtures/brand/copy-baseline.json
  modified: []

key-decisions:
  - "Hits are strings throughout (scope and kind), so they compare directly with JSON-decoded baseline entries; scan functions take scope atoms"
  - "A hit's line is the matched copy segment (code scopes) or prose line (lexicon), trimmed and whitespace-collapsed with case kept; matching is case-insensitive"
  - "diff_baseline counts duplicates, so a second identical violating line in one file is a new hit rather than hiding behind an existing entry"
  - "The admin scope uses the same copy-segment scanner as generated, with the glossary guard's auth-replica carve-out kept, instead of the line-oriented strip"
  - "Derived avoid-words skip ordinary English (delete, cancel, disable, group, scope, target, subject, suspend, host, consumer) and every parenthetical-qualified entry; the exclusions are recorded in the test moduledoc"
  - "Entries sort by scope name alphabetically, so initializing admin and generated after lexicon inserted lines without modifying any existing line"

patterns-established:
  - "Live red proofs on the real artifacts: planted stale entry, edited baselined template line, a new admin violation, and appended README prose each failed the contract test with the expected message, then were restored"
  - "Independent audit of the scanner: raw greps of the templates and admin files for every banned term and lexicon word were reconciled against the scanner's hits; every unflagged raw hit is a comment, doc, identifier, attribute name or telemetry atom"

requirements-completed: [BCOPY-02]

coverage:
  - id: D1
    description: "Lexicon scope (README, guides/introduction, guides/flows) scanned with the Do-not-say words read from the pinned brand.json, hits equal a committed non-empty baseline (6 entries, the repo's own negations)"
    requirement: BCOPY-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#real scan of scope :lexicon"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#lexicon_words/0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Admin scope (nine admin files plus shipped admin templates) with glossary terms, brand avoid-words, 'admin (operator)' and the lexicon, with the auth-replica carve-out"
    requirement: BCOPY-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#real scan of scope :admin"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#scan_lines/3 over scope :admin"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated-template scope bans log in/out, login, logout, signin and 'admin (operator)' as copy only, plus the lexicon on the same segments; identifiers, routes and telemetry atoms never match"
    requirement: BCOPY-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#scan_lines/3 over scope :generated"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#real scan of scope :generated"
        status: pass
    human_judgment: false
  - id: D4
    description: "Shrink-only baseline: new hits fail with 'do not baseline', stale entries fail with 'remove this entry', initialization is opt-in and never rewrites an initialized scope"
    requirement: BCOPY-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/copy_contract_test.exs#diff_baseline/2 and init_baseline/3"
        status: pass
    human_judgment: false
  - id: D5
    description: "glossary_test.exs untouched and green; zero bytes shipped under lib, priv, brandbook, brand, .github, scripts"
    requirement: BCOPY-02
    verification:
      - kind: command
        ref: "mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/error_test.exs"
        status: pass
    human_judgment: false
  - id: D6
    description: "Whether the scanned surface is the right definition of 'shipped copy' (attributes outside the six, admin files outside the nine, .exs templates and JS hooks are not scanned) and whether the 36 baselined admin/generated legacy hits are the wording Phases 262-263 should rewrite"
    verification: []
    human_judgment: true
    rationale: "Scope of the contract and the fate of legacy wording are planning and copy judgments; this plan fixed both by explicit file and attribute lists"

duration: 14min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 08: Banned-term and lexicon copy contract Summary

**A three-scope copy scanner (README/guides lexicon, admin chrome, generated templates) with the brand book's Do-not-say words read from the pinned brand.json, matched only against copy segments, and a shrink-only baseline of 42 reviewed hits that fails on any new violation or stale entry.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-11-14T16:35:16Z
- **Completed:** 2026-11-14T16:49:21Z
- **Tasks:** 2
- **Files modified:** 3 (all created; zero bytes under lib/, priv/, brandbook/, brand/, .github/ or scripts/)

## Accomplishments

- Task 1 (tracer): scope (c) lexicon end to end. `lexicon_words/0` takes the first sentence of the `messaging.boilerplate` "Do not say" row of `brand/brand.json` and yields the ten terms; Markdown is scanned with fenced code blocks and HTML comments removed; the 6 hits the repo's own negations produce are the initial baseline (README "a hosted identity product" and "hosted auth", `guides/flows/oauth.md`, `guides/introduction/contract.md`, `installation.md`, `migrating-from-pow-guardian-ueberauth.md`). Tracer verified end-to-end, then expanded.
- Task 2: scopes (a) and (b) on a small purpose-built Elixir/HEEx scanner. String literals, HEEx text nodes, string literals inside `{...}` and `#{...}`, and the `aria-label`, `title`, `placeholder`, `label`, `alt`, `action` values are copy. Identifiers, `~p` and other sigils, route paths, atoms (telemetry lists), comments, `@doc`/`@moduledoc` text and every other attribute are not. Installer EEx tags are stripped in `priv/templates/` files while runtime `<%%= ... %>` tags are kept. The admin scope keeps the glossary guard's auth-replica carve-out (whole balanced `<div>`, admin scope only).
- Baseline initialized through the opt-in mechanism for the two new scopes: 3 admin entries and 33 generated entries, each reviewed as a copy-bearing line, none an identifier or route. Admin hits: `organization_live.ex` "...without losing tenant context." and, in the shipped `admin_shell.ex` template, "Org ·" and "Workspace". Generated hits: the "Log in" / "log in" / "login" copy in flashes, HEEx text, emails and one label ("Login hint domains").
- Independent audit: raw greps over the templates and admin files for every banned term and lexicon word were reconciled against the scanner. Every raw hit the scanner did not flag is a comment, doc, attribute name (`data-passkey-login-status`) or telemetry atom; lexicon words occur in templates only inside comments and docs.
- Live red proofs on the real artifacts (all restored afterwards): a planted stale baseline entry, an edited baselined template line, a new admin violation ("Review logins for this customer") and appended README prose ("A seamless, robust experience.") each failed with the specified messages.

## Task Commits

1. **Task 1: Scope (c) lexicon scan, shrink-only baseline, planted-term control (tracer)** - `bebad41af` (test)
2. **Task 2: Scopes (a) admin chrome and (b) generated templates** - `89000f7b9` (test)

**Plan metadata:** the `docs(259-08)` close-out commit that carries this SUMMARY, STATE.md, ROADMAP.md and REQUIREMENTS.md.

Tracer gate: auto mode off, `human_verify_mode` end-of-phase, tracer `<verify>` automated-only, so the verify was re-run (26 tests green, compile `--warnings-as-errors` clean); logged "Tracer verified end-to-end - expanding".

## Files Created/Modified

- `test/support/brand/copy_scan.ex` - `Sigra.Test.Brand.CopyScan`: `scopes/0`, `lexicon_words/0`, `files_for/1`, `banned_terms/1`, `scan_lines/3`, `copy_segments/3`, `scan/1`, `normalize/1`, `load_baseline/0`, `diff_baseline/2`, `init_baseline/3`, `init_baseline!/0`, `init_requested?/0`, `init_command/0`, `render_baseline/2`, `baseline_path/0`
- `test/sigra/brand/copy_contract_test.exs` - `Sigra.Brand.CopyContractTest`: 56 tests, `async: true`, no scaffold tag; the moduledoc records the intentionally excluded avoid-words
- `test/fixtures/brand/copy-baseline.json` - committed baseline: schema `sigra.brand-copy-baseline/v1`, `initialized_scopes` (admin, generated, lexicon), 42 entries on one line each with sorted keys, no line numbers

## Decisions Made

See `key-decisions` above. The load-bearing ones: duplicates are counted (a repeated violating line cannot hide behind an existing entry), the admin scope shares the generated scope's copy-segment scanner rather than the glossary's line strip, and ordinary-English avoid-words are excluded from the derived terms and recorded in the test moduledoc.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Auth-replica carve-out silently did nothing**
- **Found during:** Task 2 (first real admin scan showed "Log in" from `lib/sigra/admin/components.ex`, inside the preview block)
- **Issue:** `Regex.scan(..., return: :index)` yields `[[{start, len}], ...]`; the match pattern expected `[{start, len} | _]`, so the `with` always fell to its `else` branch and returned the body unchanged.
- **Fix:** match `[[{open, _}] | _]`. Added a planted-source test that fails if the carve-out stops working (the heading above the block is scanned, the block is not, and the same block is scanned under `:generated`).
- **Files modified:** test/support/brand/copy_scan.ex, test/sigra/brand/copy_contract_test.exs
- **Committed in:** 89000f7b9

**2. [Rule 3 - Blocking] Base-relative acceptance criterion cannot be empty**
- **Found during:** Task 1 acceptance
- **Issue:** `git diff --stat aeda7273d -- README.md guides test/sigra/admin/glossary_test.exs` must be empty, but Plan 259-01 (earlier in this phase, commits `aa8c64c5b`, `0d52ee77d`) legitimately added a section to `guides/introduction/contract.md` and a new `guides/reference/brand-compatibility.md`.
- **Fix:** verified the criterion's intent instead: `git diff --stat HEAD~2 -- README.md guides test/sigra/admin/glossary_test.exs` (this plan's own commits) is empty. No prose, guide or glossary test was edited by this plan.
- **Files modified:** none

### Interpretation choices (no behavior outside the plan's scopes)

- `normalize/1` trims and collapses whitespace and keeps case ("lowercase-insensitive" read as case-insensitive matching); the baseline stays readable.
- `diff_baseline/2` returns the keyword list `[new: hits, stale: entries]` and counts duplicates (stronger than set membership).
- Hits hold `scope` and `kind` as strings; the hit `line` for code scopes is the copy segment rather than the whole source line.
- Entries sort `{scope, file, kind, line}` with scope alphabetical, so adding admin and generated after lexicon inserted lines and changed none (no trailing-comma rewrite of the previous last line happened).
- Public `copy_segments/3`, `banned_terms/1`, `init_baseline/3` and `render_baseline/2` were added so extraction, term lists and init are unit-testable with no file I/O.
- "admin (operator)" is also banned under `:generated` (the plan lists it for both).

---

**Total deviations:** 1 auto-fixed (Rule 1 bug), 1 blocking criterion reinterpreted (Rule 3), plus 7 interpretation choices
**Impact on plan:** None on scope. Three files, zero shipped bytes.

## Deferred Issues

Known limits of the specified scope, each a way a copy change can pass the scanner unseen. None was added because the plan fixes the file lists and the attribute list:

1. **Attributes outside the six.** `data-confirm` (for example the "You will be logged out." dialog in `core/session_live.ex`) and `phx-disable-with` are visible copy but are not scanned.
2. **Admin files outside the nine.** `lib/sigra/admin/{audit,organizations,users}/**` and the other admin modules are not in scope (a), same as the glossary guard; the library copy inventory (Plan 259-06) does cover them.
3. **`.exs` and `.js` templates** (migrations, test templates, `admin_hooks.js`, `passkey_browser.js`) are not scanned.
4. **Developer messages.** A `Logger` or `raise` message containing "login" in a template would count as copy and need rewording; none exists today.

Real legacy wording found and baselined (shrink-only, for Phases 262-263): "Org ·" and "Workspace" in the shipped `admin_shell.ex` template, "tenant context" in `organization_live.ex`, and 33 "log in"/"login" copy lines across the generated templates. Not recorded in `.planning/WINDOWS.md`, because they are scope limits and accepted baseline entries, and an open ledger entry would block `/gsd-ship`.

## Issues Encountered

None blocking. The carve-out bug (deviation 1) was caught by reading the first real admin scan, not by a test; the planted-source test now guards it.

## Authentication Gates

None.

## Known Stubs

None. No stub patterns, skipped tests or unrun verifies in the files created.

## Threat Flags

None. All three files are test-only; no new network, auth or file-access surface. Mitigations for T-259-24 (lexicon over README and guides), T-259-25 (no rewrite path after the initial commit; new hits fail with "do not baseline"; stale entries fail) and T-259-26 (generated copy scanned for the sign-in vocabulary) are in place.

## Verification Results

- Plan verification 1: `mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/error_test.exs`: 225 tests, 0 failures. `mix test test/sigra/brand/copy_contract_test.exs`: 56 tests, 0 failures.
- Plan verification 2: `MIX_ENV=test mix compile --warnings-as-errors --force`: zero `warning:` lines.
- Plan verification 3 (zero shipped bytes, untracked-aware): PASS. Verification 4 (privacy gate with planted-failure control): PASS. Verification 5 (`mix format --check-formatted`): PASS.
- Acceptance: lexicon entries 6 (at least 3), `hosted` present in the baseline with README control line printed, scope-name lines 3 and entry lines 42 (one per line), `log_in_user` and `/users/log_in` in the baseline 0 (control: template has 2), shrink-only base-relative check PASS, glossary_test and prose untouched by this plan.

## Next Phase Readiness

Phases 262-263 copy edits now surface as one of: a new hit (fix the copy), or a stale baseline entry (remove it in the same reviewed commit that fixes the wording). The baseline can only shrink. Initialize a future scope with `SIGRA_BRAND_COPY_BASELINE=init mix test test/sigra/brand/copy_contract_test.exs`. BCOPY-01 (vocabulary reconciliation) remains Plan 259-12.

## Self-Check: PASSED

Created files all present on disk; commits `bebad41af` and `89000f7b9` are ancestors of HEAD; `commits: 2` measured from the persisted ledger; every task acceptance criterion and plan-level verification command re-run green.
