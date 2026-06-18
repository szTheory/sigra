---
phase: 191-microcopy-ia-sweep
plan: "01"
subsystem: admin-copy
tags: [glossary, drift-guard, exunit, copy-enforcement]
depends_on: []
requires: []
provides: [admin-glossary-doc, glossary-drift-guard-test]
affects: [test/sigra/admin/glossary_test.exs, guides/reference/admin-glossary.md]
tech_stack:
  added: []
  patterns: [dom-marker-carve-out, stateful-doc-strip, word-boundary-banned-terms, exunit-source-parse]
key_files:
  created:
    - guides/reference/admin-glossary.md
    - test/sigra/admin/glossary_test.exs
  modified: []
decisions:
  - "DOM-marker anchoring (not hardcoded line numbers) for branding_live.ex carve-out: state machine on class=sigra-auth sigra-auth--preview"
  - "Stateful @doc/@moduledoc block stripper added to prevent false positives from doc-string content in components.ex"
  - "HEEx comment pattern (<%!--) added to strip_patterns to prevent false positives from inline comments"
  - "*_testid= pattern added to strip login_testid= component attribute assignments in branding_live.ex"
  - "account not in banned_terms — too many legitimate uses; 6 account-as-person-noun violations handled per-line in Wave 2"
metrics:
  duration: "~4 minutes"
  completed: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
status: complete
---

# Phase 191 Plan 01: Glossary Doc + RED Drift Guard Summary

Admin glossary document and ExUnit source-parsing drift guard. The guard fails RED on pre-edit source (6 violations) and will turn GREEN after Wave 2 copy edits land.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author guides/reference/admin-glossary.md | 27322a40 | guides/reference/admin-glossary.md |
| 2 | Author test/sigra/admin/glossary_test.exs (source-parsing drift guard) | 04621ca1 | test/sigra/admin/glossary_test.exs |

## What Was Built

### Task 1 — `guides/reference/admin-glossary.md`

Machine-parseable canonical-term reference document with:

- **`## Canonical Terms`** — 18-row pipe-delimited table matching the GOV.UK A–Z "use X not Y" shape. Columns: `Canonical | Banned synonyms | Context rule | Enforcement`. Covers all D-02 concepts plus 4 new rows from the string inventory: `sessions` vs `logins`, `sign-in preview` vs `Login preview`, `effective user` vs `target/victim`, `(specific message)` vs generic flashes.
- Boundary rule for `user` (global) vs `member` (org surface) prominently stated. `account` as person-noun declared banned; security-idiom exception (`account takeover`) documented.
- `sign in` (verb, two words) vs `sign-in` (modifier, hyphenated) explicitly distinguished.
- **`## Voice Rubric`** — 5 subsections: cross-cutting gate, error rubric (E-6 enumeration boundary branch), empty state rubric (4 subtypes classified), success rubric, warning/destructive confirm rubric.
- **`## Exemplars`** — 5 compliant codebase examples sourced from user_show_live.ex and users_index_live.ex.
- Header note linking to the drift guard test.

### Task 2 — `test/sigra/admin/glossary_test.exs`

ExUnit source-parsing drift guard (D-07):

- Reads 8 in-scope files via `File.read!/1` with relative paths
- `strip_carve_outs/2` — DOM-marker state machine anchored on `"sigra-auth sigra-auth--preview"` class string; tracks `<div` nesting depth to find the matching `</div>`; lines before and after the carve-out block remain in the scanned set
- `strip_non_copy_lines/1` — first runs stateful `strip_doc_and_heex_comment_blocks/1` (removes `@doc`/`@moduledoc` heredoc content lines + `<%!-- --%>` HEEx comment block lines), then applies 16 line-pattern filters
- `banned_terms/0` — 11 entries covering: log in/out, logout, signin, sign off, login (noun), logins (plural), org (abbrev), teammates, collaborators, seat

**RED test output on pre-edit source (6 violations):**

```
lib/sigra/admin/live/organization_live.ex:77 — found 'org' — use 'organization' instead
lib/sigra/admin/live/organization_live.ex:82 — found 'org' — use 'organization' instead
lib/sigra/admin/live/organization_live.ex:96 — found 'teammates' — use 'member(s)' instead
lib/sigra/admin/live/user_show_live.ex:502 — found 'logins' — use 'sessions' instead
lib/sigra/admin/live/branding_live.ex:102 — found 'login' — use 'sign-in' instead
lib/sigra/admin/live/branding_live.ex:583 — found 'Login' — use 'sign-in' instead
```

Carve-out confirmed: `branding_live.ex:601` (`<h1>Log in</h1>`) NOT reported. `components.ex` 0 violations.

## Verification Results

| Check | Result |
|-------|--------|
| `guides/reference/admin-glossary.md` exists | PASS |
| All 3 sections present | PASS |
| 18+ glossary rows | PASS |
| `test/sigra/admin/glossary_test.exs` exists | PASS |
| `mix compile` exits 0 | PASS |
| `mix test test/sigra/admin/glossary_test.exs` FAILS RED | PASS (1 test, 1 failure) |
| `branding_live.ex:583` "Login preview" IS caught | PASS |
| `branding_live.ex:601` inside carve-out NOT caught | PASS |
| `components.ex` 0 violations | PASS |
| Test completes < 5 seconds | PASS (0.1s) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed false positives from @doc string content (components.ex:98 teammates)**
- **Found during:** Task 2 verification — initial test run showed `components.ex:98` as a violation
- **Issue:** The `@doc """..."""` strip rule removed the `@doc` attribute line but not the heredoc content lines. `body="Add teammates..."` in a doc example appeared as a visible-copy violation.
- **Fix:** Added stateful `strip_doc_and_heex_comment_blocks/1` function that tracks `@doc`/`@moduledoc` heredoc state and removes all content lines inside the heredoc block.
- **Files modified:** `test/sigra/admin/glossary_test.exs`
- **Commit:** 04621ca1

**2. [Rule 1 - Bug] Fixed false positive from HEEx comment (organization_live.ex:89)**
- **Found during:** Task 2 verification — initial test run showed `organization_live.ex:89` as a violation
- **Issue:** `<%!-- Org-only demoted scoped-detail tail ... --%>` HEEx comment line was not stripped; `\borg\b` matched "Org-only" in the comment.
- **Fix:** Added `~r/<%!--/` to `@strip_patterns` and added HEEx comment block tracking to the stateful stripper.
- **Files modified:** `test/sigra/admin/glossary_test.exs`
- **Commit:** 04621ca1

**3. [Rule 1 - Bug] Fixed false positive from login_testid= attribute (branding_live.ex:187, 221, 319)**
- **Found during:** Task 2 verification — initial test run showed `branding_live.ex:187`, `221`, `319` as violations for `login_testid="admin-auth-branding-...-login-preview"` component attribute assignments
- **Issue:** The `data-testid=` strip pattern did not cover `*_testid=` component attribute names.
- **Fix:** Added `~r/\w+_testid=/` to `@strip_patterns`.
- **Files modified:** `test/sigra/admin/glossary_test.exs`
- **Commit:** 04621ca1

## Known Stubs

None. The glossary doc is a complete reference document; the test is a functional drift guard. No stubs exist.

## Threat Flags

None. This plan creates documentation and a source-reading test only. No network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- `guides/reference/admin-glossary.md` exists: FOUND
- `test/sigra/admin/glossary_test.exs` exists: FOUND
- Commit 27322a40 exists: FOUND
- Commit 04621ca1 exists: FOUND
- `mix compile` exits 0: CONFIRMED
- `mix test test/sigra/admin/glossary_test.exs` fails RED with 6 clean violations: CONFIRMED
- `branding_live.ex:583` Login preview IS caught: CONFIRMED
- `branding_live.ex:601` inside carve-out NOT caught: CONFIRMED
