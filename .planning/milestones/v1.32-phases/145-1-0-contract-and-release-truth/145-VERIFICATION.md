---
phase: 145-1-0-contract-and-release-truth
verified: 2026-05-31T15:45:30Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/8
  gaps_closed:
    - "Plan 01 key link: contract page cross-links to SECURITY details"
  gaps_remaining: []
  regressions: []
---

# Phase 145: 1.0 Contract And Release Truth Verification Report

**Phase Goal:** Lock the public 1.0 contract and remove version/scope ambiguity before release automation work.
**Verified:** 2026-05-31T15:45:30Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | `mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`, README, and maintainer docs agree on selected Hex `1.0.0` path. | ✓ VERIFIED | `release-as: "1.0.0"` in `release-please-config.json`; manifest `"." : "0.3.0"`; `@version "0.3.0"`; README/CHANGELOG/MAINTAINING explain direct `1.0.0` path with pre-release caveat. |
| 2 | Public docs explain planning milestones vs installable Hex versions. | ✓ VERIFIED | `CHANGELOG.md` contains “Planning milestones vs Hex releases” with explicit package-vs-planning split. |
| 3 | A single 1.0 contract states supported Elixir/OTP/Phoenix/Ecto/Postgres/optional-dependency posture. | ✓ VERIFIED | `guides/introduction/contract.md` includes required stack table and optional dependency posture (`Sigra.OptionalDeps`, `Sigra.Doctor`, `mix sigra.doctor`). |
| 4 | Docs separate library-owned, generated-host-owned, and shared seams. | ✓ VERIFIED | Ownership boundaries table in `guides/introduction/contract.md` includes all three ownership classes. |
| 5 | Security invariants and non-goals are top-level visible without host-overclaim. | ✓ VERIFIED | `SECURITY.md` contains invariant/non-goal sections; README security section points to both `SECURITY.md` and contract page. |
| 6 | Release Please has one-time `release-as: "1.0.0"` while manifest remains last shipped `0.3.0`. | ✓ VERIFIED | `release-please-config.json` + `.release-please-manifest.json` values match release-path contract. |
| 7 | Maintainer docs explain direct `1.0.0` path, `release-as` cleanup, and Phase 146 ownership boundaries. | ✓ VERIFIED | `MAINTAINING.md` includes direct 1.0 path, post-release cleanup for `release-as`, and Phase 146 handoff statement. |
| 8 | First-path install examples use `{:sigra, "~> 1.0"}` and preserve companion sister-library pins. | ✓ VERIFIED | README, installation guide, and companion recipes use `~> 1.0`; companion pins remain present; no `Mailglass.deliver/2` stale reference found in public docs scope. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `guides/introduction/contract.md` | Canonical public 1.0 contract | ✓ VERIFIED | Exists, substantive sections present, and now explicitly links `SECURITY.md`. |
| `README.md` | Public contract pointer + `~>1.0` | ✓ VERIFIED | Includes first-path `{:sigra, "~> 1.0"}` and links contract/security surfaces. |
| `SECURITY.md` | Security invariants/non-goals | ✓ VERIFIED | Security invariants and non-goals documented as public contract boundaries. |
| `CHANGELOG.md` | Dual-axis explanation | ✓ VERIFIED | Installable SemVer vs planning-milestone axis documented. |
| `mix.exs` | ExDoc includes contract, package version remains pre-release truth | ✓ VERIFIED | `@version "0.3.0"` and `guides/introduction/contract.md` included in docs extras. |
| `release-please-config.json` | One-time release jump config | ✓ VERIFIED | `packages["."].release-as` set to `1.0.0`. |
| `.release-please-manifest.json` | Last shipped pre-release version | ✓ VERIFIED | `"." : "0.3.0"` retained. |
| `MAINTAINING.md` | Maintainer release-truth docs | ✓ VERIFIED | Release path + cleanup + phase-boundary ownership guidance present. |
| `guides/introduction/installation.md` | First-path install docs aligned | ✓ VERIFIED | Uses `{:sigra, "~> 1.0"}` and links back to contract. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `README.md` | `guides/introduction/contract.md` | public contract link | ✓ WIRED | Link present in first-path integration instructions. |
| `guides/introduction/contract.md` | `SECURITY.md` | security detail handoff | ✓ WIRED | `guides/introduction/contract.md` now includes `[`SECURITY.md`](../../SECURITY.md)`. |
| `release-please-config.json` | `MAINTAINING.md` | release-as cleanup instruction | ✓ WIRED | Maintainer guide explains cleanup after one-time `release-as`. |
| `guides/introduction/installation.md` | `guides/introduction/contract.md` | 1.0 contract cross-link | ✓ WIRED | Installation page points to contract (`contract.html`). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Docs/config artifacts in this phase | N/A | N/A | N/A | SKIPPED (static docs/config phase; no dynamic runtime data-flow artifacts) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Scoped formatter check for touched root config | `mix format --check-formatted mix.exs` | Pass | ✓ PASS |
| Docs build warning-cleanliness | `mix docs --warnings-as-errors` | Generated docs successfully (`doc/index.html`, `doc/llms.txt`) | ✓ PASS |
| Companion contract recipe tests | `mix test test/sigra/recipes/companion_lib_contract_test.exs` | `2 tests, 0 failures` (with unrelated `Chimeway.Repo` connection logs) | ✓ PASS |
| Global formatter health | `mix format --check-formatted` | Fails on unrelated pre-existing files outside Phase 145 write set | ⚠️ WARNING (non-blocking caveat) |

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| None discovered for this phase | `find scripts -path '*/tests/probe-*.sh' -type f` | No phase probe scripts found | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| REL1-01 | 145-02-PLAN | 1.0 release alignment surfaces | ✓ SATISFIED | Release metadata (`release-as`, manifest, mix version) and docs are consistent. |
| REL1-04 | 145-01/02-PLAN | Version-axis clarity for users | ✓ SATISFIED | CHANGELOG dual-axis explainer and README/contract framing are explicit. |
| CONTRACT-01 | 145-01/02-PLAN | Single public 1.0 contract with stack posture | ✓ SATISFIED | Contract page has stack/support posture sections and tables. |
| CONTRACT-02 | 145-01/02-PLAN | Ownership boundary separation | ✓ SATISFIED | Contract ownership table defines library/host/shared seams. |
| CONTRACT-03 | 145-01/02-PLAN | SemVer/API/deprecation clarity | ✓ SATISFIED | Contract SemVer/deprecation section states stable vs private surfaces. |
| CONTRACT-04 | 145-01-PLAN | Security invariants/non-goals | ✓ SATISFIED | Security sections in contract + `SECURITY.md`; key link now wired. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `guides/recipes/companion-libs/lockspire.md` | 153 | `TODO` mention in explanatory snippet | ⚠️ Warning | Non-blocking documentation note; not a `TBD`/`FIXME`/`XXX` debt marker in Phase 145 must-have wiring. |

### Gaps Summary

No remaining must-have gaps. The prior blocker (missing `contract.md -> SECURITY.md` key link) is closed and verified in repository content.

Non-blocking caveat: global `mix format --check-formatted` still reports unrelated pre-existing drift outside the Phase 145 write set.

---

_Verified: 2026-05-31T15:45:30Z_  
_Verifier: the agent (gsd-verifier)_
