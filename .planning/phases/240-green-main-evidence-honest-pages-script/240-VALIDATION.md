---
phase: 240
slug: green-main-evidence-honest-pages-script
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-18
---

# Phase 240 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `240-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (`mix ci`), `node:test` (prohibition guards), plain-bash `*.test.sh` self-tests |
| **Config file** | `mix.exs:144-157` (`ci` alias); guards need none |
| **Quick run command** | `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` |
| **Guard run command** | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` |
| **Full suite command** | `MIX_ENV=test mix ci` (requires live Postgres + phx_new 1.8.8) |
| **Estimated runtime** | quick < 5s · guards < 10s · full suite several minutes |

---

## Sampling Rate

- **After every task commit:** `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` + `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs`
- **After every plan wave:** `MIX_ENV=test mix ci`
- **Before `/gsd-verify-work`:** full suite green, plus the live SC-1/SC-2 JSON receipt and `gh issue view 231 --json state`
- **Max feedback latency:** 10 seconds for the offline loop (guards + shell self-tests)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | GREEN-05 | T-240-01 | GET 403 exits 1 instead of POST-creating a Pages site | unit (stub `get_403`) | `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | GREEN-05 | T-240-01 | A body containing `403` on a 500 does not read as tolerable | unit (stub `get_500`) | same | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | GREEN-05 | T-240-01 | PUT 204 (empty body) is read as success | unit (stub `put_204`) | same | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | GREEN-05 | T-240-01 | PUT 403 stays tolerable and is the ONLY tolerated failure | unit (stub `put_403`) | same | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | GREEN-05 | T-240-01 | PUT 422/500 exits 1 — the loud-RED demonstration (SC-3) | unit (stub `put_500`) | same | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | GREEN-04 | T-240-02 | The evidence workflow's step list has not drifted from `ci.yml`'s job | unit (guard) | `node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` | ❌ W0 | ⬜ pending |
| TBD | 02 | 1 | GREEN-04 | T-240-02 | That guard fires RED on a dropped-step fixture (negative control) | unit (negative control) | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p20-green-04-step-drift.yml node --test --test-reporter=tap scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | GREEN-04 | T-240-03 | Collector fails closed on truncated `/jobs` pagination (`total_count` ≠ length) | unit (stub) | `bash scripts/ci/capture-green-04-evidence.test.sh` | ❌ W0 | ⬜ pending |
| TBD | 03 | 2 | GREEN-04 | T-240-03 | Collector refuses a dirty tree / HEAD mismatch (D-13 trap) | unit (stub) | same | ❌ W0 | ⬜ pending |
| TBD | 04 | 3 | GREEN-04 | — | n≥20 legs, all `success`, at final committed HEAD | integration (live) | `bash scripts/ci/capture-green-04-evidence.sh …` then `jq -e '.sc1.leg_count >= 20 and .sc1.verdict == "pass"'` | ❌ W0 (operator dispatch) | ⬜ pending |
| TBD | 04 | 3 | GREEN-04 | — | SC-2 `main` window readable from the API, not prose | integration (live) | `jq -e '.sc2.flake_attributable_red_count == 0'` on the same receipt | ❌ W0 (operator dispatch) | ⬜ pending |
| TBD | 04 | 3 | GREEN-04 | — | The ledger satisfies p12's slot grammar | unit | `GSD_PROHIB_SUBJECT=.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md node --test --test-reporter=tap scripts/ci/prohibitions/p12-run-id-provenance.test.mjs` | ✅ guard exists | ⬜ pending |
| TBD | 05 | 4 | GREEN-05 | — | Issue #231 is CLOSED | integration (live) | `gh issue view 231 --json state --jq '.state'` → `CLOSED` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task IDs are filled in by the planner; the rows above are the required coverage floor.*

---

## Wave 0 Requirements

- [ ] `scripts/ci/ensure-github-pages-legacy-branch.test.sh` — GREEN-05, 10 stub modes (`get_200_already_gh_pages`, `get_404`, `get_403`, `get_500`, `build_type_workflow`, `no_token`, `put_204`, `put_403`, `put_422`, `put_500`) (fake `gh` on PATH, per `capture-terminal-ratification-evidence.test.sh:60-125`)
- [ ] `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` — GREEN-04 step-drift guard
- [ ] `test/fixtures/prohibitions/p20-green-04-step-drift.yml` — GREEN-04 RED fixture (ROADMAP standing constraint 6)
- [ ] `scripts/ci/capture-green-04-evidence.sh` + `scripts/ci/capture-green-04-evidence.test.sh` — GREEN-04
- [ ] `.github/workflows/green-04-evidence.yml` — GREEN-04 dispatch-only evidence workflow
- [ ] One `fast_checks` step in `ci.yml` (near `:261`) wiring the Pages self-test so it is actually run

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| n≥20 matrix dispatch of `green-04-evidence.yml` | GREEN-04 | `workflow_dispatch` on `main` needs operator credentials; the workflow file must be merged to the default branch first (RESEARCH A2) | `gh workflow run green-04-evidence.yml --ref main`, wait 4 waves at `max-parallel: 5` (~75–100 runner-min), note the run id |
| Issue #231 comment + close | GREEN-05 / SC-4 | Outward-facing mutation on a public repo; requires operator `gh auth` | `gh issue comment 231 --body-file …` then `gh issue close 231`, then re-read `gh issue view 231 --json state` |
| Live Pages payload re-read at closure | GREEN-05 / SC-4 | Point-in-time state; RESEARCH marks live claims as expiring | `gh api repos/szTheory/sigra/pages` |

*Everything else in this phase has automated, offline verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s on the offline loop
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
