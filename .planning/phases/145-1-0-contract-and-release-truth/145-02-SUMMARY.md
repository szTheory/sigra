---
phase: 145-1-0-contract-and-release-truth
plan: 02
subsystem: release-truth
tags: [release, docs, contract, semver]
requires:
  - phase: 145-01
    provides: Canonical public 1.0 contract and README/security routing
provides:
  - One-time Release Please `release-as: "1.0.0"` override
  - Maintainer-facing direct Hex 1.0 release path
  - First-path install examples aligned to `{:sigra, "~> 1.0"}`
affects: [phase-146-release-gates, phase-147-upgrade-lanes, public-docs]
tech-stack:
  added: []
  patterns: [release-as one-time override, manifest remains last-shipped truth]
key-files:
  created: []
  modified:
    - release-please-config.json
    - MAINTAINING.md
    - guides/introduction/installation.md
    - guides/introduction/getting-started.md
    - guides/introduction/first-hour.md
    - guides/recipes/companion-libs/threadline.md
    - guides/recipes/companion-libs/mailglass.md
    - guides/recipes/companion-libs/accrue.md
    - guides/recipes/companion-libs/lockspire.md
    - guides/recipes/companion-libs/relyra.md
    - guides/recipes/companion-libs/rulestead.md
key-decisions:
  - "Release Please gets a one-time `release-as: \"1.0.0\"` override; `.release-please-manifest.json` remains at last shipped `0.3.0` until the release PR records the new release."
  - "Phase 146 owns release gates, dry-run/package inspection, recovery, and first-14-day hotfix policy."
patterns-established:
  - "First-path install examples use the selected 1.0 line while companion library pins remain independently versioned."
requirements-completed: [REL1-01, REL1-04, CONTRACT-01, CONTRACT-02, CONTRACT-03]
duration: 35min
completed: 2026-05-31
---

# Phase 145 Plan 02 Summary

**Release metadata, maintainer policy, and public install examples aligned around direct Hex 1.0**

## Summary

Plan 02 configured Release Please for the one-time `1.0.0` release PR without changing `.release-please-manifest.json` or `mix.exs` early. Maintainer docs now state the direct Hex `1.0.0` path, the `release-as` cleanup rule, and Phase 146's ownership of detailed release gates and recovery. First-path public install examples now use `{:sigra, "~> 1.0"}`, and companion recipes preserve sister-library pins while updating only the Sigra tuple.

## Task Commits

| Task | Commit | Notes |
|------|--------|-------|
| 145-02-01 Configure one-time Release Please 1.0 jump | `3d035af` | Added package-level `"release-as": "1.0.0"` while preserving manifest/version truth. |
| 145-02-02 Update maintainer docs for direct Hex 1.0 path | `2aa0f28` | Added `## Sigra 1.0 release path` and historical pre-1.0 pointer. |
| 145-02-03 Update first-path install examples | `9599704` | Updated intro and companion recipe Sigra tuples to `~> 1.0`; preserved sister-library pins. |
| Post-review companion recipe cleanup | `9dceb62` | Fixed nested recipe links and corrected Lockspire/Relyra path and parameter examples. |
| Post-review changelog cleanup | `df83626` | Corrected the unreleased compare base and malformed doc reference. |
| Post-review Mailglass cleanup | `5e2b17d` | Aligned the Mailglass failure-mode text with the real `deliver/1` API. |
| Verification Mailglass cleanup | final verification commit | Corrected a remaining introduction guide reference from `Mailglass.deliver/2` to `Mailglass.deliver/1`. |
| Clean code review report | `eb703c8` | Recorded clean standard-depth review after all post-review fixes. |

## Verification

| Command | Result | Evidence |
|---------|--------|----------|
| `node -e "JSON.parse(require('fs').readFileSync('release-please-config.json', 'utf8')); JSON.parse(require('fs').readFileSync('.release-please-manifest.json', 'utf8'));"` | PASS | Release Please config and manifest parse as JSON. |
| `rg -n '"release-as"[[:space:]]*:[[:space:]]*"1\.0\.0"' release-please-config.json` | PASS | `release-as` found in `release-please-config.json`. |
| `rg -n '"\."[[:space:]]*:[[:space:]]*"0\.3\.0"' .release-please-manifest.json` | PASS | Manifest remains last shipped `0.3.0`. |
| `rg -n '@version "0\.3\.0"' mix.exs` | PASS | Package version remains owned by the future Release Please release PR. |
| `rg -n "## Sigra 1\.0 release path|release-as|0\.3\.0|Release Please release PR|remove or update|Phase 146|first-14-day hotfix" MAINTAINING.md` | PASS | Maintainer release path and cleanup policy present. |
| `rg -n '\{:sigra, "~> 1\.0"\}' README.md guides/introduction/installation.md guides/introduction/getting-started.md guides/introduction/first-hour.md guides/recipes/companion-libs/*.md` | PASS | First-path and companion recipe Sigra examples use `~> 1.0`. |
| `! rg -n '\{:sigra, "~> 0\.2"\}' README.md guides/introduction/installation.md guides/introduction/getting-started.md guides/introduction/first-hour.md guides/recipes/companion-libs/*.md` | PASS | Targeted public first-path docs and companion recipes no longer contain the old `~> 0.2` Sigra tuple. |
| `mix docs --warnings-as-errors` | PASS | ExDoc generated HTML and markdown docs successfully. |
| `mix test test/sigra/recipes/companion_lib_contract_test.exs` | PASS | 2 tests, 0 failures. The run emitted unrelated Chimeway.Repo config connection logs, but exited 0. |
| `mix format --check-formatted` | FAIL, pre-existing unrelated drift | The global formatter check reports unformatted files outside Plan 02's declared write set, including install-golden fixtures, enterprise SSO files, and unrelated tests. These were not modified by Plan 02; fixing them would be unrelated scope expansion. |

## Deviations

None - plan executed exactly as written.

## Blockers

`mix format --check-formatted` still fails globally on pre-existing unrelated files outside the Plan 02 write set. JSON/source assertions, docs build, and companion recipe contract tests pass.

## Self-Check

PASSED for Plan 02 deliverables. Global formatter drift remains a phase-level verification risk outside this plan's changed files.
