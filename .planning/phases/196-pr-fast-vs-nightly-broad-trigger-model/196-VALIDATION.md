---
phase: 196
slug: pr-fast-vs-nightly-broad-trigger-model
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
---

# Phase 196 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This phase's "system under test" is `.github/workflows/ci.yml` (a trigger-model
> restructure) plus two ExUnit contract tests that assert against its text. There is
> no application code change — feedback comes from ExUnit + YAML lint + `gh api`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir) for the structural contract tests; GitHub Actions itself is the runtime harness for the trigger model. |
| **Config file** | none extra — `mix test` runs the planning contract tests. |
| **Quick run command** | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` |
| **Full suite command** | `mix test` (the two contract tests gate this phase's own merge; phase_51 is currently RED on main) |
| **Estimated runtime** | quick: ~5s (pure-text asserts, no DB) · full: per repo baseline |

---

## Sampling Rate

- **After every task commit:** Run the quick command (the two contract tests). Both MUST be green once D-15 re-anchor lands.
- **After the ci.yml edit:** Lint/parse the workflow (`gh workflow view` / YAML parse) AND re-run the quick command (D-16 slicer must stay green).
- **Before `/gsd-verify-work`:** Full `mix test` green; `gh api repos/szTheory/sigra/rulesets/14941512` re-read shows the same 5 required contexts (D-12).
- **Max feedback latency:** ~5s for the contract tests; YAML parse is sub-second.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 196-01-XX | trigger | 1 | CRIT-02 | — | Broad jobs gated `if: github.event_name != 'pull_request'`; skipped on PR, run on schedule/main/dispatch | structural | `grep -c "github.event_name != 'pull_request'" .github/workflows/ci.yml` | ✅ existing | ⬜ pending |
| 196-01-XX | trigger | 1 | CRIT-02 | — | New `schedule: cron` added, non-colliding with `45 6` slot | structural | `grep -A2 "schedule:" .github/workflows/ci.yml` | ✅ existing | ⬜ pending |
| 196-02-XX | ci-gate | 1 | CRIT-03 | — | ci-gate loop tolerates `skipped` (fails only on failure/cancelled) | structural | `grep "skipped" .github/workflows/ci.yml` (ci-gate result loop ~1317) | ✅ existing | ⬜ pending |
| 196-02-XX | ci-gate | 1 | CRIT-03 | — | 5 ruleset required-check `name:` strings byte-identical & unconditional | structural + live | `gh api repos/szTheory/sigra/rulesets/14941512` diff = empty | ✅ existing | ⬜ pending |
| 196-03-XX | contract | 1 | CRIT-03 | — | phase_51 re-anchored to surviving `fast_checks` step; phase_58 slicer green | unit | quick command above (both green) | ✅ existing | ⬜ pending |
| 196-04-XX | probe | 2 | CRIT-02 | T-196-probe | `force_fail_probe` input drives `exit 1` in a nightly-gated job only | structural | `grep "force_fail_probe" .github/workflows/ci.yml` | ✅ existing | ⬜ pending |
| 196-05-XX | docs | 2 | CRIT-02/03 | — | MAINTAINING.md records nightly cadence, 2 residuals, probe runbook, reconciled required-check reality | docs | `grep -i "nightly\|force_fail_probe\|residual" MAINTAINING.md` | ✅ existing | ⬜ pending |

*Plan/Task IDs are placeholders — the planner assigns final IDs. Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing infrastructure covers all phase requirements. ExUnit + the two planning contract tests already exist (`test/sigra/planning/phase_51_*`, `phase_58_*`); GitHub Actions is the live harness. No new test framework or stub files needed.
- **Pre-existing RED:** `phase_51_install_golden_ci_contract_test.exs:28` is RED on `main` (asserts the removed `installer_milestone_audit:` job key, folded into `fast_checks` by Phase 194). D-15 makes it green — this is a required outcome, not a Wave 0 stub.

---

## Never-Strand Contract (CRIT-02 — the core Nyquist guarantee)

Each MOVED job's correctness invariant MUST remain independently observable on the PR path. Lifted from RESEARCH.md Validation Architecture (verified anchors):

| Moved job | Invariant | PR-path proxy (independent observer) | Residual (nightly-only) |
|-----------|-----------|--------------------------------------|--------------------------|
| `install_matrix` (×4) | Default `mix sigra.install` app compiles/boots | `install_smoke` — a *required* PR lane | flag-combo breadth only |
| `passkeys_*_smoke` | Passkey enabled happy-path | `example_playwright_smoke` passkey specs (ci.yml:1047-1053) — required lane | opt-out + manual-fallback edges only |
| `upgrade_smoke` | Published→local upgrade path | **none** — release-boundary; runs on push:main + release-dispatch | whole upgrade path off PRs (accepted) |
| `generated_admin_playwright_smoke` | Generated-host admin behavior | `example_playwright_smoke` admin specs (ci.yml:959-993) — required lane | template parity → backstopped by DIST-06 `admin-acceptance-smoke.sh` |

**Honest-truth requirement (D-07):** the two residuals (`upgrade_smoke` whole-path, generated-host template parity) MUST be written explicitly into MAINTAINING.md + 196-VERIFICATION — never silently moved.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Nightly lane still fails red on a real regression | CRIT-02 | Cannot wait for a real nightly cron in CI; the forced-failure probe is the executable proxy | `gh workflow run "CI" -f force_fail_probe=true` → confirm the probe's nightly-gated host job goes red & its check reports failure. A normal run with `force_fail_probe=false` stays green. Document in MAINTAINING.md (D-14). |
| Live ruleset required-check set unchanged | CRIT-03 | Branch-protection state lives in GitHub, not the repo | `gh api repos/szTheory/sigra/rulesets/14941512` → 5 contexts byte-identical to pre-change (D-12 mandate at execution). |

*All other phase behaviors (job gating, ci-gate skip-tolerance, contract re-anchor) have automated structural/unit verification.*

---

## Validation Sign-Off

- [ ] Every task has a structural/unit `<verify>` or is covered by the manual probe table above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (the two contract tests run on every commit)
- [ ] Wave 0 covers all MISSING references (none — existing infra)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~5s for contract tests
- [ ] Never-strand contract: every moved job has a named PR-path proxy OR a recorded accepted residual
- [ ] `nyquist_compliant: true` set in frontmatter (set by checker/at sign-off)

**Approval:** pending
