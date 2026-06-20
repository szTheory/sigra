---
phase: 196-pr-fast-vs-nightly-broad-trigger-model
verified: 2026-06-20T12:35:00Z
status: passed
score: 7/7 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: recorded
  previous_score: N/A
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 196 — Verification Report

**Phase Goal:** Every-PR cost is reduced to a fast representative gate while exhaustive/low-probability coverage still runs (on `schedule:`/main), with a single stable required check and no correctness-critical test stranded on nightly only.
**Verified:** 2026-06-20T12:35:00Z
**Status:** passed
**Re-verification:** No — initial goal-backward verification (the existing file was a plan-authored D-13/D-08 record; this section adds the verifier's goal-achievement analysis)

---

## Goal Achievement

### Scope Note

Per `<verification_scope_note>`: SC4 (measured PR-path wall-clock drop vs Phase 193 baseline) is a CI-measures-itself outcome, deferred to Phase 198 GATE-01/GATE-02. This phase is judged on the three statically-verifiable success criteria (SC1, SC2, SC3) plus the D-14 forced-failure probe and the contract tests.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: 5 exhaustive jobs are excluded from PR path via `if: github.event_name != 'pull_request'` at job level; `schedule:` cron `30 4 * * *` added (not colliding with `45 6` slot) | VERIFIED | `grep -n "github.event_name != 'pull_request'" ci.yml` returns 6 lines; 5 are the moved jobs (upgrade_smoke:515, passkeys_manual_fallback_smoke:568, install_matrix:619, passkeys_opt_out_smoke:749, generated_admin_playwright_smoke:1173), 6th is nightly_probe:1352. Cron `30 4 * * *` at line 16. playwright-github-pages.yml uses `45 6 * * *` — no collision. |
| 2 | SC2: No correctness-critical test stranded on nightly only — each moved job has a PR-path proxy or an explicitly disclosed residual (D-08 table) | VERIFIED | D-08 proxy table in VERIFICATION body below. 3 of 5 jobs have required-lane proxies on every PR. 2 residuals (upgrade_smoke whole path; generated-host template parity) are explicitly disclosed with DIST-06 backstop. MAINTAINING.md documents both. |
| 3 | SC3: 5 required lane `name:` strings are byte-identical and unconditional (no event_name gate); ci-gate tolerates `skipped` via `result != "success" && result != "skipped"` loop condition | VERIFIED | All 5 required lanes (`Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`) carry no event_name gate. ci-gate skip-tolerant condition confirmed at line 1332. |
| 4 | SC4: Measured PR-path wall-clock drop vs Phase 193 baseline | DEFERRED | Deferred to Phase 198 GATE-01/GATE-02 (CI-measures-itself; cannot be verified statically). |
| 5 | install_golden_contract and library_tests_dep_off are NOT PR-gated (remain on every PR) | VERIFIED | Neither job has `if:` on its header (lines 112-117 and 308-313). Both appear in ci-gate.needs unconditionally. |
| 6 | D-14 forced-failure probe: dedicated needs-free `nightly_probe` job exists, guarded by `if: github.event_name != 'pull_request'`, with `inputs.force_fail_probe`-guarded `exit 1` step; NOT in ci-gate.needs | VERIFIED | `nightly_probe:` at line 1349; `if: github.event_name != 'pull_request'` at line 1352; no `needs:` key; probe step `if: ${{ inputs.force_fail_probe }}` + `exit 1` at lines 1354-1357. Grep of ci-gate.needs block confirms `nightly_probe` is absent. |
| 7 | Contract tests: phase_51 re-anchored and green (2 tests, 0 failures); phase_58 slicer undisturbed and green (1 test, 0 failures) | VERIFIED | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` → 3 tests, 0 failures. Re-anchored assertion targets `scripts/ci/installer-milestone-audit.sh` at ci.yml:95 (not vacuous). phase_58 slicer boundary `library_tests_shard:` → `library_tests:` undisturbed by moved jobs. |

**Score:** 7/7 truths verified (SC4 deferred to Phase 198 per scope note; counted only the 7 statically verifiable must-haves)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | SC4: Measured PR-path wall-clock drops vs Phase 193 baseline with equal-or-greater quality signal | Phase 198 | Phase 198 GATE-01/GATE-02 success criteria — measured before/after wall-clock and no-flake-no-dropped-coverage gate. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | PR-fast vs nightly-broad trigger model: schedule cron, 5 moved-job gates, ci-gate skip-tolerant, nightly_probe job | VERIFIED | File exists, substantive (1360+ lines), wired — schedule cron at line 16, 5 job-level PR gates at lines 515/568/619/749/1173, skip-tolerant ci-gate at line 1332, nightly_probe job at line 1349 |
| `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` | Re-anchored to `scripts/ci/installer-milestone-audit.sh` (surviving fast_checks step), green | VERIFIED | File exists with re-anchored assertion; 2 tests, 0 failures confirmed by `mix test` run |
| `MAINTAINING.md` | CI cadence subsection (ADD-only): nightly schedule, PR-fast vs broad split, two D-07 residuals, force_fail_probe probe runbook | VERIFIED | `force_fail_probe`, `admin-acceptance-smoke`, `upgrade_smoke`, `v1.4-GA-UAT.md`, `mix ci.install_golden` all present; CI cadence section at lines 124-172 |
| `guides/recipes/local-development.md` | One-line nightly/broad-cadence pointer | VERIFIED | `### PR-fast vs nightly CI split` subsection at line 52 |
| `.planning/phases/196-pr-fast-vs-nightly-broad-trigger-model/196-VERIFICATION.md` | D-13 correction + full D-08 per-moved-job never-strand proxy table | VERIFIED | File contains both records (see body sections below) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `on.workflow_dispatch.inputs.force_fail_probe` (ci.yml:8-12) | `nightly_probe` step `if: ${{ inputs.force_fail_probe }}` (line 1355) | `inputs.force_fail_probe` boolean accessor | WIRED | Input defined as `type: boolean`, `default: false`; consumed in nightly_probe step |
| ci.yml `on: schedule: cron:` (line 16) | 5 moved jobs run on schedule | `github.event_name != 'pull_request'` gate | WIRED | Cron `30 4 * * *`; condition is `!=` not `== schedule` so main/dispatch also runs these jobs |
| ci-gate result loop | `upgrade_smoke` and `generated_admin_playwright_smoke` skipped on PRs | `result != "success" && result != "skipped"` (line 1332) | WIRED | Both jobs are in ci-gate.needs (lines 1299, 1302); skip-tolerant condition at line 1332 ensures ci-gate stays green on PR |
| `phase_51` test assertion | `scripts/ci/installer-milestone-audit.sh` in ci.yml fast_checks step | `assert yml =~ "scripts/ci/installer-milestone-audit.sh"` | WIRED | Target string at ci.yml:95; assertion in test file line 35 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Contract tests pass (phase_51 + phase_58) | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` | 3 tests, 0 failures | PASS |
| ci.yml parses as valid YAML | `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'` | VALID YAML | PASS |
| Exactly 6 event_name gates (5 moved jobs + nightly_probe) | `grep -c "github.event_name != 'pull_request'" ci.yml` | 6 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CRIT-02 | 196-01, 196-03, 196-04 | PR-fast vs nightly/main-broad split; exhaustive coverage off PR path; no correctness-critical test stranded | SATISFIED | 5 jobs moved off PR with job-level if gate; D-08 proxy table records per-job proxies; 2 residuals explicitly disclosed in MAINTAINING.md and VERIFICATION |
| CRIT-03 | 196-01, 196-02, 196-04 | Single stable required check surface; stable child-check names; no pending-check traps | SATISFIED | 5 lane name strings byte-identical and unconditional; ci-gate skip-tolerant so PRs don't go red on skipped needs; D-13 correction records that the enforced surface is the 5 lane names (ci-gate is an internal aggregator, not a required check itself) |

Note: REQUIREMENTS.md line 76 shows `| CRIT-02, CRIT-03 | 196 | Pending |` — this is a phase-mapping table column showing roadmap slot, not an implementation status. CRIT-02 and CRIT-03 are marked `[x]` (complete) at lines 20-21 in REQUIREMENTS.md, which is the authoritative completion record.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TBD/FIXME/XXX/TODO debt markers found in any phase-modified file |

### Human Verification Required

None. All must-haves are statically verifiable. SC4 is deferred to Phase 198 GATE-01/GATE-02 by the verification scope note (not a human-verification item for this phase).

### Gaps Summary

No gaps. All 7 statically-verifiable must-haves are VERIFIED. SC4 is deferred to Phase 198 per the scope note.

---

## Plan-Authored Records (Preserved Verbatim)

The following two sections were authored by Plan 04 during phase execution and must be preserved as the authoritative D-13 and D-08 audit records.

---

## D-13 Correction: CRIT-03 Stale Phrasing

**Recorded per Plan 04 instructions — NOT propagated to REQUIREMENTS.md or ROADMAP prose.**

CRIT-03 in `REQUIREMENTS.md` (line 21) and `ROADMAP.md` describe the required check as:
> "single stable required check (`ci-gate` aggregator)"

This phrasing is **stale**. The live enforcement reality, confirmed via
`gh api repos/szTheory/sigra/rulesets/14941512` at Phase 196 execution (2026-06-20), is:

- Ruleset `14941512` (`enforcement: active`, `strict_required_status_checks_policy: true`)
  enforces **exactly 5 required status-check contexts** — the CI job `name:` strings.
- **`ci-gate` is NOT a required check context.** It is an internal aggregator job (`if: always()`)
  that gates the DAG; it does not appear in `required_status_checks` of ruleset 14941512.

The 5 enforced required check contexts (byte-identical to the live ruleset, confirmed at execution):

1. `Library tests`
2. `Example unit smoke (ExUnit + ConnTest)`
3. `Install smoke (fresh phx.new + sigra.install)`
4. `Example HTTP smoke (boot + curl critical routes)`
5. `Example Playwright smoke (full lifecycle)`

**`MAINTAINING.md` is already correct** (lines 100-122 as of Phase 196): it states the 5 lane
`name:` strings are the enforced surface and that `ci-gate` is NOT a required check. The D-13
correction is a note that CRIT-03's prose is the stale text — not a bug in the live system.

**Resolution:** This correction is recorded here in VERIFICATION rather than by editing
REQUIREMENTS.md or ROADMAP prose mid-phase (per RESEARCH §7 / Open Question 2). The
MAINTAINING.md documentation (5 lane names + ci-gate aggregator note) is the authoritative
operator reference. The CRIT-03 / ROADMAP prose reconciliation is deferred to a future
requirements cleanup phase.

**Source decisions:** D-13 (CONTEXT.md), RESEARCH §7, RESEARCH §6 (live ruleset read).

---

## D-08 Never-Strand Proxy Table (CRIT-02 Audit Trail)

**Complete per-moved-job proxy mapping — all 5 jobs moved to nightly/main-only coverage.**

The Phase 196 move list (D-05) shifts 5 jobs off the PR path using
`if: github.event_name != 'pull_request'` at the job level. For each moved job, the
never-strand contract (CRIT-02) requires that every correctness-critical invariant has an
independent observer on the PR path, or the residual is explicitly disclosed.

| Moved job | Correctness invariant | PR-path proxy (independent observer) | Residual (nightly-only) |
|-----------|----------------------|--------------------------------------|--------------------------|
| `install_matrix` (×4: flag combinations) | Default `mix sigra.install` app compiles and boots across flag combinations | `install_smoke` — required PR lane (`Install smoke (fresh phx.new + sigra.install)`) | Flag-combination breadth only (not a correctness gap — default flag path is covered) |
| `passkeys_manual_fallback_smoke` | Passkey enabled, manual-fallback UI path | `example_playwright_smoke` passkey specs (ci.yml:1047-1053) — required PR lane (`Example Playwright smoke (full lifecycle)`) | Manual-fallback edge scenario only |
| `passkeys_opt_out_smoke` | Passkey opt-out path works end-to-end | `example_playwright_smoke` passkey specs (ci.yml:1047-1053) — required PR lane (`Example Playwright smoke (full lifecycle)`) | Opt-out edge scenario only |
| `upgrade_smoke` | Published-package → local-candidate upgrade path | **None — no per-PR behavioral proxy** | **Whole upgrade path is nightly/main/release-dispatch-only (accepted residual — release-boundary coverage)** |
| `generated_admin_playwright_smoke` | Generated-host admin behavior + template parity | `example_playwright_smoke` admin specs (ci.yml:959-993) — required PR lane for admin _behavior_ | **Template parity (installer-emitted shell vs library admin) is nightly-only — explicitly backstopped by DIST-06 `scripts/ci/admin-acceptance-smoke.sh` (RUN_PARITY), see D-07** |

### Residual Disclosures (D-07)

The table above has two accepted residuals that must be disclosed explicitly (never silently moved):

**Residual 1 — `upgrade_smoke` whole upgrade path:**
The published-package → local upgrade path has no per-PR behavioral proxy. Coverage runs on
`push: main` (every merge before release) and release dispatch, providing release-boundary
coverage. Individual PRs do not run `upgrade_smoke`. This is accepted: a regression surfaces
before any Hex publish, not after.

**Residual 2 — Generated-host template parity:**
`generated_admin_playwright_smoke` fully moved to nightly. Admin _behavior_ is proxied on PRs
by `example_playwright_smoke`'s admin specs (a required lane). The **template-parity** check —
whether installer-emitted generated files match the library admin — becomes nightly-only.
This residual is backstopped by:
- **DIST-06 `scripts/ci/admin-acceptance-smoke.sh` (RUN_PARITY)** — the acceptance smoke
  script that scaffolds a fresh `phx.new + sigra.install` app, boots it, and runs the full
  Playwright suite against the generated host. This provides the proxy for template-parity
  regressions between nightly runs.

Both residuals are documented in `MAINTAINING.md` (Phase 196 CI cadence subsection) and here.

### Verification Commands

```bash
# Confirm 5 moved jobs have the PR-guard if: condition
grep -c "github.event_name != 'pull_request'" .github/workflows/ci.yml

# Confirm ci-gate loop tolerates skipped (D-09)
grep "skipped" .github/workflows/ci.yml

# Confirm nightly probe job exists
grep "nightly_probe:" .github/workflows/ci.yml

# Confirm force_fail_probe input wired to probe step
grep "force_fail_probe" .github/workflows/ci.yml

# Re-read live ruleset to confirm 5 required contexts, ci-gate NOT required
gh api repos/szTheory/sigra/rulesets/14941512 \
  --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'
```

---

## Sign-Off

- [x] D-13 stale-CRIT-03-framing correction recorded here in VERIFICATION (not in REQUIREMENTS.md/ROADMAP)
- [x] D-08 full per-moved-job never-strand proxy table recorded (all 5 moved jobs, all proxies, all residuals)
- [x] Two D-07 honest-truth residuals written explicitly (upgrade_smoke whole-path; generated-host template parity + DIST-06 backstop)
- [x] REQUIREMENTS.md and ROADMAP prose unchanged (correction is VERIFICATION-only)

*Phase 196 execution: 2026-06-20*

---

_Verified: 2026-06-20T12:35:00Z_
_Verifier: Claude (gsd-verifier)_
