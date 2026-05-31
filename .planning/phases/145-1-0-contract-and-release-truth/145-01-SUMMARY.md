---
phase: 145-1-0-contract-and-release-truth
plan: 01
subsystem: public-contract
tags: [docs, contract, semver, security]
requires: []
provides:
  - Canonical public Sigra 1.0 contract page
  - README and CHANGELOG version-axis routing
  - Top-level security invariants and non-goals
affects: [phase-146-release-gates, phase-147-upgrade-lanes, public-docs]
tech-stack:
  added: []
  patterns: [single public contract surface, library-vs-host ownership table]
key-files:
  created:
    - guides/introduction/contract.md
  modified:
    - README.md
    - CHANGELOG.md
    - SECURITY.md
    - mix.exs
key-decisions:
  - "Hex SemVer is the installable version axis; GSD v1.x labels remain planning milestones."
  - "Security and ownership claims are bounded by the library/generator split."
patterns-established:
  - "Public release-truth docs link to one canonical contract page instead of duplicating the full contract in README."
requirements-completed: [REL1-04, CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04]
duration: 45min
completed: 2026-05-31
---

# Phase 145 Plan 01 Summary

**Canonical Sigra 1.0 public contract page with top-level version-axis and security-boundary routing**

## Summary

Plan 01 created `guides/introduction/contract.md` as the public 1.0 contract surface and packaged it in ExDoc extras. README now links the contract from first-path navigation and uses the selected `{:sigra, "~> 1.0"}` package line. CHANGELOG now separates installable Hex SemVer from GSD planning milestones with `0.3.0` as current published truth and `1.0.0` as the selected release path. SECURITY.md now exposes product security invariants and non-goals without claiming host deployment or compliance guarantees.

## Task Commits

| Task | Commit | Notes |
|------|--------|-------|
| 145-01-01 Add canonical public 1.0 contract page | `ac1d7ce` | Created `guides/introduction/contract.md`; added it to ExDoc extras. |
| 145-01-02 Wire public version-axis and contract pointers | `fc10cff` | Updated README and CHANGELOG routing/version-axis text. |
| 145-01-03 Add security invariants and non-goals | `21269d3` | Added SECURITY.md invariant and non-goal tables. |
| Formatter correction | `c9c65c8` | Removed trailing comma in `mix.exs` exposed by the ExDoc extras edit. |
| Post-review release contract cleanup | `a367c2b` | Clarified pre-publish caveats and release-truth wording in scoped docs. |
| Clean code review report | `eb703c8` | Recorded clean standard-depth review after all post-review fixes. |

## Verification

| Command | Result | Evidence |
|---------|--------|----------|
| `bash -lc 'set -euo pipefail; test -f guides/introduction/contract.md; rg -n "## Version Axes|## Supported Stack|## Ownership Boundaries|## SemVer And Deprecation Policy|## Security Invariants|## Non-Goals" guides/introduction/contract.md; rg -n "Elixir.*~> 1\\.18|Phoenix 1\\.8|Ecto.*~> 3\\.12|Postgres|OptionalDeps|Sigra\\.Doctor|mix sigra\\.doctor|Library-owned|Generated-host-owned|Shared seams|host-owned authorization|compliance certification" guides/introduction/contract.md; rg -n "guides/introduction/contract.md" mix.exs; rg -n "@version \"0\\.3\\.0\"" mix.exs'` | PASS | Required contract headings, supported stack terms, ownership seams, ExDoc extra, and unchanged `@version "0.3.0"` found. |
| `bash -lc 'set -euo pipefail; rg -n "Sigra 1\\.0 contract|guides/introduction/contract.md|\\{:sigra, \"~> 1\\.0\"\\}" README.md; rg -n "Planning milestones vs Hex releases|installable Hex|0\\.3\\.0|1\\.0\\.0|planning milestones" CHANGELOG.md; ! rg -n "\\{:sigra, \"~> 0\\.2\"\\}" README.md'` | PASS | README contract link and `~> 1.0` example found; README no longer contains `~> 0.2`; CHANGELOG explainer contains required terms. |
| `bash -lc 'set -euo pipefail; rg -n "## Security Invariants|## Security Non-Goals|Sessions|Tokens|MFA|passkeys|audit durability|mail|Oban|OAuth|generated-host|host-owned authorization|compliance certification|hosted control plane|authorization engine|Mailglass|public RC train|new auth primitives" SECURITY.md; rg -n "SECURITY.md|guides/introduction/contract.md|invariants|non-goals" README.md'` | PASS | SECURITY.md and README contain required invariant/non-goal references. |
| `mix format --check-formatted mix.exs` | PASS | Touched Elixir config file is formatter-clean after commit `c9c65c8`. |
| `mix docs --warnings-as-errors` | PASS | ExDoc generated HTML and markdown docs successfully. |
| `mix format --check-formatted` | FAIL, pre-existing unrelated drift | The global formatter check reports unformatted files outside Plan 01's declared write set, including install-golden fixtures, enterprise SSO files, and unrelated tests. These were not modified by Plan 01; fixing them would be unrelated scope expansion. |

## Deviations

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Remove trailing comma exposed in `mix.exs`**

- **Found during:** Plan-level formatter verification
- **Issue:** Adding the contract guide to ExDoc extras caused `mix format --check-formatted mix.exs` to flag an existing trailing comma in the adjacent list.
- **Fix:** Removed the trailing comma after `guides/recipes/companion-libs/mailglass.md`.
- **Files modified:** `mix.exs`
- **Verification:** `mix format --check-formatted mix.exs`
- **Committed in:** `c9c65c8`

**Total deviations:** 1 auto-fixed blocking verification issue.

## Blockers

`mix format --check-formatted` still fails globally on pre-existing unrelated files outside the Plan 01 write set. The scoped formatter check for `mix.exs`, the source assertions, and `mix docs --warnings-as-errors` pass.

## Self-Check

PASSED for Plan 01 deliverables. Global formatter drift remains a phase-level verification risk outside this plan's changed files.
