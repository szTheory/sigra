---
phase: 146-release-gate-and-maintainer-runbook
verified: 2026-05-31T16:34:29Z
status: human_needed
score: 11/11 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run release-ref CI evidence pass from a real v* tag"
    expected: "Manual dispatch on v1.32.0 succeeds and required gate jobs pass with evidence links"
    why_human: "Requires live GitHub Actions run execution and maintainer sign-off"
  - test: "Run publish/recovery flow to Hex and verify visibility"
    expected: "Dry-run/publish steps succeed and Hex API/package page show the released version"
    why_human: "Requires real HEX_API_KEY publish and external hex.pm propagation"
  - test: "Verify HexDocs source links resolve to the release tag"
    expected: "HexDocs for released version is visible and source links resolve via source_ref tag"
    why_human: "Requires external HexDocs rendering state after live publish"
---

# Phase 146: Release Gate And Maintainer Runbook Verification Report

**Phase Goal:** Build deterministic release gates and maintainer runbook for the 1.0 release, enforcing REL1-02 and REL1-03 through release-ref gate evidence, publish/recovery checks, and maintainer-facing release procedure.
**Verified:** 2026-05-31T16:34:29Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Maintainer runbook covers dry-run, package inspection, tag/source-ref checks, Hex publish, docs publish, post-publish visibility, and revert/replace recovery. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` contains required sections and recovery tree with `mix hex.publish --replace`/`--revert` + timing windows. |
| 2 | Release gate matrix includes library tests, install golden/idempotency, fresh install smoke, example/browser smoke, dep-off lane, docs warnings, Hex dry-run, and post-publish checks. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` Release Gate Matrix lists `library_tests`, `install_golden_contract`, `install_smoke`, `example_http_smoke`, `example_playwright_smoke`, `generated_admin_playwright_smoke`, `library_tests_dep_off`, dry-run/package inspection, Hex visibility, HexDocs/source-link. |
| 3 | Release gates run against release ref or explicitly document manual evidence/waiver requirements. | ✓ VERIFIED | `ci.yml` enforces release-tag refs for manual evidence; runbook defines strict ref-rule values and waiver fields. |
| 4 | First-14-day hotfix policy and triage expectations are documented before publish. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` has `## First 14 Days Hotfix Policy` with P0-P3 classes, triage times, evidence minimums, and boundaries. |
| 5 | Failed dry-run or publish has explicit recovery path with no ad-hoc process invention. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` `## Recovery Decision Tree` defines dry-run fail, publish fail, docs/source-link fail, replace/revert windows, follow-up patch path. |
| 6 | Maintainers can rerun canonical CI release gates against immutable release ref (not only main PR/push evidence). | ✓ VERIFIED | `.github/workflows/ci.yml` has `workflow_dispatch`, release-ref guidance, and guard requiring `refs/tags/v*` for manual evidence runs. |
| 7 | Automated publish and manual recovery both verify version/ref truth, docs warnings, package contents, dry-run, publish, and Hex visibility. | ✓ VERIFIED | `.github/workflows/release-please.yml` and `.github/workflows/hex-publish.yml` both include manifest/version/source_ref checks, docs warnings, unpack assertions, dry-run, publish, visibility poll. |
| 8 | Manual recovery rejects malformed or mismatched release inputs before publish. | ✓ VERIFIED | `hex-publish.yml` validates `release_version` SemVer, `tag` shape, tag/version match, then provenance check enforces input commit == expected tag commit. |
| 9 | Canonical 1.0 runbook exists as single maintainer source with gate matrix/checklist/publish/recovery/hotfix policy. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` exists and includes all required canonical sections. |
| 10 | First 14 days after release have explicit severity-driven hotfix and communication rules. | ✓ VERIFIED | `docs/release-runbook-v1-0.md` hotfix section includes severity posture + communication posture rules. |
| 11 | Maintainer router docs point to canonical runbook; stale v1.4/main-proof routes removed. | ✓ VERIFIED | `MAINTAINING.md`, `docs/NEXT-STEPS-MANUAL.md`, `docs/ga-evidence.md` route to runbook; `docs/ga-evidence.md` bans `main` proof URLs and uses pinned `v<version>` guidance. |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.github/workflows/ci.yml` | Dispatchable release-ref gate workflow using existing CI matrix | ✓ VERIFIED | Exists, substantive, and wired; includes release-ref guard and preserved canonical jobs. |
| `.github/workflows/release-please.yml` | Release-tag publish workflow with release truth + package inspection | ✓ VERIFIED | Exists, substantive, and wired; includes tag/version/manifest/source_ref/docs/package/dry-run/publish/visibility flow. |
| `.github/workflows/hex-publish.yml` | Manual recovery workflow with input/provenance validation and post-publish visibility | ✓ VERIFIED | Exists, substantive, and wired; validates input shape and commit provenance against expected tag commit. |
| `docs/release-runbook-v1-0.md` | Canonical release gate matrix, checklist, recovery, hotfix policy | ✓ VERIFIED | Exists and complete with required headings and procedure content. |
| `MAINTAINING.md` | Stable maintainer entry to canonical runbook | ✓ VERIFIED | Links to runbook and keeps index posture (no matrix duplication). |
| `docs/NEXT-STEPS-MANUAL.md` | Manual-only router that defers to runbook and keeps local publish fallback-only | ✓ VERIFIED | Points to runbook and names manual recovery workflow as primary recovery path. |
| `docs/ga-evidence.md` | Release-evidence router with pinned-tag proof-link policy | ✓ VERIFIED | Rewritten as generic router; stale v1.4 narrative/main blob proof route removed. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `.github/workflows/release-please.yml` | `mix.exs` | version and source_ref verification before publish | WIRED | Explicit `@version` and `source_ref` checks present. |
| `.github/workflows/release-please.yml` | `.release-please-manifest.json` | manifest/version cross-check | WIRED | Manifest version read and compared to release output version. |
| `.github/workflows/hex-publish.yml` | `mix.exs` | manual recovery version guard | WIRED | `@version` and `source_ref` checks plus provenance guard present. |
| `MAINTAINING.md` | `docs/release-runbook-v1-0.md` | maintainer entry-point link | WIRED | Canonical runbook pointer present in release path section. |
| `docs/release-runbook-v1-0.md` | `.github/workflows/ci.yml` | gate matrix workflow rows | WIRED | Matrix cites `CI` and canonical gate jobs. |
| `docs/release-runbook-v1-0.md` | `.github/workflows/hex-publish.yml` | manual recovery branch | WIRED | Runbook repeatedly names `Hex publish (manual recovery)`; manual grep confirms match in both source and target. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `.github/workflows/release-please.yml` | `version`, `tag_name` | Release Please outputs + manifest/mix checks | Yes | ✓ FLOWING |
| `.github/workflows/hex-publish.yml` | `inputs.tag`, `inputs.release_version` | workflow_dispatch inputs + git provenance/tag resolution | Yes | ✓ FLOWING |
| `.github/workflows/ci.yml` | `GITHUB_REF`, `github.event_name` | GitHub Actions runtime context | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Workflow syntax valid | `actionlint .github/workflows/ci.yml .github/workflows/hex-publish.yml .github/workflows/release-please.yml` | exit 0 | ✓ PASS |
| Docs gate runnable | `mix docs --warnings-as-errors` | exit 0 | ✓ PASS |
| CI release-ref guard exists and is wired to canonical lanes | `rg -n "release_ref_guard|refs/tags/v\\*|needs: release_ref_guard" .github/workflows/ci.yml` | guard + multiple `needs` matches | ✓ PASS |
| Manual recovery enforces provenance + publish checks | `rg -n "Validate manual release inputs|Verify manual ref provenance|mix hex.publish --dry-run --yes|mix hex.publish --yes|Verify version on Hex.pm" .github/workflows/hex-publish.yml` | all required steps found | ✓ PASS |

### Probe Execution

Step 7c: SKIPPED (no declared probes and no `scripts/*/tests/probe-*.sh` files present).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| REL1-02 | 146-01, 146-02 | Maintainer can run 1.0 release gate matrix blocking publish unless required lanes green or waived with evidence. | ✓ SATISFIED | CI release-ref guard + canonical gate matrix/checklist + publish/dry-run/docs/package/visibility gating in workflows/runbook. |
| REL1-03 | 146-01, 146-02 | Maintainer can follow deterministic 1.0 runbook covering publish, checks, recovery, and first-14-day hotfix policy. | ✓ SATISFIED | Canonical runbook sections implemented; recovery decision tree and hotfix policy explicit; maintainer routers updated. |

No orphaned Phase 146 requirement IDs were found between plan frontmatter and `.planning/REQUIREMENTS.md`.

### Anti-Patterns Found

No blocker or warning anti-patterns found in phase-modified files.  
No `TBD`, `FIXME`, or `XXX` debt markers were found in scoped files.

### Human Verification Required

### 1. Release-Tag CI Evidence Run

**Test:** Dispatch `CI` on an actual release tag (for example `v1.32.0`) and collect run evidence.  
**Expected:** All required gate jobs pass (or documented waivers recorded) with evidence URLs and reviewer sign-off.  
**Why human:** Requires live GitHub Actions execution and operator evidence review.

### 2. Live Publish + Hex Visibility

**Test:** Execute real publish path (`Release Please` or `Hex publish (manual recovery)`) with production `HEX_API_KEY`.  
**Expected:** Dry-run and publish pass; Hex API/package page confirms visibility of released version.  
**Why human:** Requires external hex.pm interaction and real credentialed publish.

### 3. HexDocs Source-Link Validation

**Test:** After release, inspect HexDocs for released version and verify source links resolve to `v<version>`.  
**Expected:** Docs version is available and source links target release tag, not `main`.  
**Why human:** Depends on external HexDocs state post publish.

### Gaps Summary

No code/documentation implementation gaps were found for Phase 146 must-haves.  
Status is `human_needed` only because live external publish/visibility checks cannot be proven by static repository inspection.

---

_Verified: 2026-05-31T16:34:29Z_  
_Verifier: the agent (gsd-verifier)_
