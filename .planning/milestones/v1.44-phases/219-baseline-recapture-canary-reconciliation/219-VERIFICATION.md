---
phase: 219-baseline-recapture-canary-reconciliation
verified: 2026-07-09T22:06:21Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: null
---

# Phase 219: Baseline Recapture + Canary Reconciliation Verification Report

**Phase Goal:** After the elevation wave, all ~115 committed PNG baselines are recaptured in-CI
(ubuntu), allowlists are reset to empty steady-state, and the snapshot-canary drift guard plus
generated-host parity are green.

**Verified:** 2026-07-09T22:06:21Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All ~115 committed PNG baselines recaptured in-CI (ubuntu/amd64, never darwin), reviewable PR with zero spurious drift | ✓ VERIFIED | Local count: `admin-design.spec.ts-snapshots/*.png`=84, `admin-checkpoints.spec.ts-snapshots/*.png`=27, `demo-showcase.spec.ts-snapshots/*.png`=4 (115 total) on current HEAD (`0181c7f3`, branch `gsd/phase-219-baseline-recapture-canary-reconciliation`). CI run `29051223765` (workflow_dispatch, event confirmed via `gh run view --json event`): `Recapture admin-design baselines (in-CI)` = success, `Recapture admin-checkpoint baselines (in-CI)` = success. Bot PR #71 (`gh pr view 71`) state=MERGED, baseRefName=phase-219 branch, mergedAt=2026-07-09T21:49:33Z — merge commit `ed692906` present in `git log`. |
| 2 | Both snapshot allowlists reset to empty steady-state | ✓ VERIFIED | `snapshot-allowlist` and `snapshot-allowlist-design` inspected directly: 0 non-comment/non-blank lines in either file; header "canary must NEVER appear here" preserved in both. |
| 3 | Snapshot-canary drift guard exits zero on a clean re-run (both lanes) | ✓ VERIFIED | Ran independently: `bash scripts/ci/snapshot-canary-guard.sh --base HEAD` → `PASS (0 changed slug(s), all within allowlist)`, exit 0. `SNAP_DIR=.../admin-design.spec.ts-snapshots bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist snapshot-allowlist-design --canary board-notice` → same PASS, exit 0. |
| 4 | Generated-host parity is green (install-golden byte-diff + acceptance-smoke runtime render) | ✓ VERIFIED | CI run `29051223765` (`gh run view --json jobs`): `Install golden + idempotency contract (subprocess harness)` = success; `Generated admin Playwright smoke` = success. Run event = `workflow_dispatch` (confirmed via `gh run view --json event`), so the stale ci.yml:1320 PR-skip condition did not apply — this is the non-skipped, authoritative proof the plan required. |
| 5 | Compile prerequisite (D-02) resolved durably: example `icon/1` accepts/forwards arbitrary global attrs | ✓ VERIFIED | `core_components.ex:446-451` declares `attr :rest, :global` and renders `<span class={[@name, @class]} {@rest} />`. Independently ran `cd test/example && MIX_ENV=dev mix compile --warnings-as-errors` → exit 0. |
| 6 | Branch-scoped recapture dispatch mechanism exists without weakening the general release-ref tag requirement (D-04) | ✓ VERIFIED | `ci.yml` workflow_dispatch inputs include `recapture_branch` (string, default ''). `release_ref_guard` step: non-workflow_dispatch → exit 0; non-empty `recapture_branch` → exit 0 (recapture-only relaxation); otherwise falls through unchanged to the `refs/tags/v*` case-check (ci.yml:38-61) — tag requirement intact for all other manual dispatches. Both recapture jobs' `gh pr create --base` source `RECAPTURE_BASE: ${{ github.event.inputs.recapture_branch }}` (ci.yml:1650, 1967); PR #71's actual baseRefName confirms this resolved correctly. |
| 7 | Canary can never be silenced via allowlist (D-06) | ✓ VERIFIED | `scripts/ci/snapshot-canary-guard.sh:58-60`: `if [[ -n "${ALLOWED[$CANARY]:-}" ]]; then fail ...`. Ran independently: `bash scripts/ci/snapshot-canary-guard.sh --base HEAD --canary board-notice --allow board-notice --allowlist /dev/null` → non-zero exit with `FAIL: canary 'board-notice' must never be allowlisted...`. |
| 8 | PR #70 closed as subsumed (D-01) | ✓ VERIFIED | `gh pr view 70 --json state` → `CLOSED`. |

**Score:** 8/8 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/example/lib/example_web/components/core_components.ex` | `attr :rest, :global` + `{@rest}` spread on `icon/1` | ✓ VERIFIED | Confirmed present; compiles clean. |
| `.github/workflows/ci.yml` (`recapture_branch` input) | New workflow_dispatch input | ✓ VERIFIED | Present with correct default/description. |
| `.github/workflows/ci.yml` (demo-showcase recapture step) | Folded into `admin_checkpoint_recapture` | ✓ VERIFIED | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --update-snapshots` present (ci.yml:1953); `DEMO_SNAP_DIR` variable present for git-add (ci.yml:1971). |
| `.github/workflows/ci.yml` (impersonation-banner delete-rebirth) | Delete-then-commit step before recapture | ✓ VERIFIED | Present as `git rm -q --ignore-unmatch ... impersonation-banner-admin-checkpoints-*.png` + commit, superseding the original `find -delete` plan text after a mid-phase bug fix (documented in 219-03 SUMMARY, commit `fb780889`) — the working-tree-only delete was found to yield `modified` not `added`; the git-commit-first approach is the corrected, functionally-equivalent implementation. |
| `scripts/ci/snapshot-canary-guard.sh` (canary-never-allowlistable assertion) | Hard-fail on canary in ALLOWED map | ✓ VERIFIED | Present at lines 58-60; empirically triggers FAIL. |
| `test/example/priv/playwright/snapshot-allowlist`, `snapshot-allowlist-design` | Empty steady-state | ✓ VERIFIED | 0 active lines each. |
| 84+27+4 PNG baselines | amd64-native, committed | ✓ VERIFIED | Counted directly on disk; matches expected 115. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `recapture_branch` input | `release_ref_guard` bypass | conditional exit 0 when non-empty | ✓ WIRED | Confirmed in ci.yml:50-52; tag path unaffected when empty. |
| `recapture_branch` input | `gh pr create --base` (both recapture jobs) | `RECAPTURE_BASE` env var | ✓ WIRED | ci.yml:1650, 1967; PR #71's actual base confirms end-to-end. |
| impersonation-banner delete-commit | `--update-snapshots` → guard self-gate | ordering (commit before recapture) | ✓ WIRED | Confirmed present in ci.yml and confirmed effective via the live CI run's guard PASS log ("OK canary first-established (added)" per 219-03 SUMMARY; independently reconfirmed guard exits 0 post-merge). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| example compiles warnings-as-errors | `cd test/example && MIX_ENV=dev mix compile --warnings-as-errors` | exit 0 | ✓ PASS |
| snapshot-canary-guard passes clean (admin-checkpoints lane) | `bash scripts/ci/snapshot-canary-guard.sh --base HEAD` | `PASS (0 changed slug(s), all within allowlist)`, exit 0 | ✓ PASS |
| snapshot-canary-guard passes clean (admin-design lane) | `SNAP_DIR=... bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist snapshot-allowlist-design --canary board-notice` | same PASS, exit 0 | ✓ PASS |
| canary-never-allowlistable enforcement | `bash scripts/ci/snapshot-canary-guard.sh --base HEAD --canary board-notice --allow board-notice --allowlist /dev/null` | `FAIL: canary 'board-notice' must never be allowlisted...`, non-zero exit | ✓ PASS |
| PNG counts | `ls .../*.png \| wc -l` ×3 dirs | 84 / 27 / 4 | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh`-style probes declared or discovered for this phase; the phase's verification surface is the CI-native recapture jobs (verified via `gh run view` against the authoritative run) plus the local re-runnable guard script (executed directly above). Step 7c: N/A — no probe scripts in scope.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| RECAP-01 | 219-01, 219-02, 219-03, 219-04, 219-05 | After the wave, ~115 PNG baselines recaptured in-CI, allowlists reset to empty steady-state, snapshot-canary drift guard + generated-host parity green | ✓ SATISFIED | All 5 plans' coverage entries map to this ID; independently confirmed via truths 1-8 above. REQUIREMENTS.md line 90 (`RECAP-01 \| 219 \| Complete`) matches actual state. |

No orphaned requirements — REQUIREMENTS.md maps only RECAP-01 to Phase 219, and it is claimed by all 5 plans' frontmatter.

### Anti-Patterns Found

None. Scanned all phase-modified files (`ci.yml`, `snapshot-canary-guard.sh`, `core_components.ex`, both `snapshot-allowlist*` files) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` — no matches.

### Human Verification Required

None. The single retained human touchpoint (D-05 operator scope-check of the recapture PR) was already completed synchronously during plan 219-03 execution (documented in the SUMMARY and independently confirmed here: PR #71 merged, only 3 impersonation-banner PNGs changed). No further human verification items identified.

### Out-of-Scope / Known Non-Regressions (not gaps)

Confirmed via independent CI log inspection (job `86232133350`, "Fast checks"), the `fast_checks` job failure on run `29051223765` is caused by `Error: Cannot find module 'cheerio'` in an unrelated eval/panel script — occurring AFTER two separate `snapshot-canary-guard.sh` invocations in the same job both logged `PASS (0 changed slug(s), all within allowlist)`. This confirms the failure is not a snapshot/canary regression from this phase; it is the pre-existing 218-era eval-infra gap already tracked at `.planning/todos/pending/2026-07-09-fastchecks-cheerio-missing-dep.md`, and `fast_checks` is not one of Phase 219's success criteria. `Upgrade smoke` and `Admin eval render + probe` failures are likewise pre-existing/non-gating per the SUMMARY and this verifier's independent check that `Upgrade smoke` is a known env-dependent lane. `ci-gate` shows `failure` on this run only because it aggregates `fast_checks`; the individual required-for-this-phase lanes (`Example Playwright smoke`, `Generated admin Playwright smoke`, `Install golden...`, both recapture jobs, `Release ref guard`) all show `success`.

### Gaps Summary

No gaps. All 3 ROADMAP success criteria and all plan-level must-haves across 219-01 through 219-05 are independently verified against the live codebase and the authoritative CI run — not merely SUMMARY.md claims. The 115-PNG count, empty allowlists, canary-guard clean exits, canary-never-allowlistable enforcement, and both generated-host parity lanes were all re-executed or re-inspected directly by this verifier rather than trusted from prior narration.

---

_Verified: 2026-07-09T22:06:21Z_
_Verifier: Claude (gsd-verifier)_
