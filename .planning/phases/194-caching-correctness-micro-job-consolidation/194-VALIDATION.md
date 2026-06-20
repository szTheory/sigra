---
phase: 194
slug: caching-correctness-micro-job-consolidation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-19
---

# Phase 194 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> **This is a CI-infrastructure phase** — it changes `.github/workflows/ci.yml`,
> `scripts/ci/*` bash guards, and `MAINTAINING.md`. There is **no ExUnit/Playwright
> work**. Validation is *CI-self-validation*: the workflow must parse, lint, and run
> green on a live PR, and mechanical `grep` assertions enforce the structural
> invariants (key shape, job fold, ci-gate rewire). The 5 protected required-check
> names are verified against the **live ruleset** at execution (D-03).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (CI infra). Validation = workflow parses + lints + runs green on a PR; guard scripts are the executable contracts |
| **Config file** | `.github/workflows/ci.yml` |
| **Quick run command** | `actionlint .github/workflows/ci.yml` (if available) — else `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` for parse-only |
| **Full suite command** | Push the branch → `gh run watch` the live CI run to green |
| **Estimated runtime** | Quick: ~2s (lint/parse + greps). Full: live CI wall-clock (~17–30m) |

---

## Sampling Rate

- **After every task commit:** Run `actionlint` / YAML parse + the targeted `grep` assertions for the task's invariant.
- **After every plan wave:** Push the branch and `gh run watch` the live CI; confirm green AND the 5 protected contexts still report.
- **Before `/gsd-verify-work`:** Live CI green on the PR + D-03 live-ruleset re-read shows no drift from the 5 names.
- **Max feedback latency:** Quick assertions < 5s; full live-CI signal is the wave gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 194-01-* | 01 | 1 | CACHE-01 | — | Every deps+`_build` cache key carries OS/arch+OTP+Elixir+MIX_ENV+lockfile+buster across all 11 blocks; hex-registry blocks intentionally untouched | smoke (grep) | `grep -cE 'otp.*elixir.*-v1' .github/workflows/ci.yml` ≥ 11 | ✅ | ⬜ pending |
| 194-01-* | 01 | 1 | CACHE-01 | — | `mix deps.get` remains an unconditional always-run step in every lane (never gated on cache-hit) | smoke (grep) | guard-step count for deps fetch unchanged vs baseline | ✅ | ⬜ pending |
| 194-01-* | 01 | 1 | CACHE-01 | — | Cache hit-rate surfaced via `$GITHUB_STEP_SUMMARY` (`if: always()`), reading `steps.<id>.outputs.cache-hit`; no new third-party action | smoke (grep) | `grep -c 'outputs.cache-hit' .github/workflows/ci.yml` increased; no new `uses:` SHA | ✅ | ⬜ pending |
| 194-02-* | 02 | 2 | CACHE-02 | — | 6 leaf guards folded into one `fast_checks` job (single checkout, distinct named `run:` steps); `release_ref_guard` stays standalone (D-12) | smoke (grep) | `grep -c 'fast_checks:' ci.yml`==1; old 6 guard job keys absent; `release_ref_guard:` present | ✅ | ⬜ pending |
| 194-02-* | 02 | 2 | CACHE-02 | — | `ci-gate.needs` rewired in lockstep (drop snapshot+ledger, add fast_checks); aggregation loop still red-on-red | smoke (grep) | `fast_checks` in `ci-gate.needs`; dropped guards absent from needs + result loop | ✅ | ⬜ pending |
| 194-02-* | 02 | 2 | CACHE-02 | — | `installer_milestone_audit` PR-path detect gate ported faithfully into the fold (no run-on-every-PR regression) | smoke (grep) | detect-gate `if:` condition present on that step inside `fast_checks` | ✅ | ⬜ pending |
| 194-D1 | 02 | 2 | D-01/D-02/D-03 | — | The 5 protected required-check `name:` strings remain byte-identical | live | `gh api repos/szTheory/sigra/rulesets/14941512` ∩ ci.yml job `name:`s == the 5 names | ✅ (runtime) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Confirm `actionlint` availability locally; if absent, fall back to `python3` YAML `safe_load` parse + grep assertions. Optional install: `brew install actionlint`.
- [ ] Author a single VERIFICATION assertion script (or inline grep block) that checks: (a) ≥11 precision-keyed deps+`_build` blocks, (b) absence of the 6 folded job keys, (c) presence of `fast_checks` + standalone `release_ref_guard`, (d) `ci-gate.needs` delta. This covers CACHE-01/CACHE-02 mechanically before pushing.

*No ExUnit/Playwright work in this phase — those suites are unchanged consumers of the cache.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cache hit-rate measurably stable/improved vs Phase 193 baseline | CACHE-01 (Success #2) | Requires ≥2 live CI runs (cold-fill run + warm run) to observe the hit transition; the D-04 key change forces one cold run first | After merge, trigger a second run on an unchanged branch; read the cache-hit lines in `$GITHUB_STEP_SUMMARY` and compare to `193-BASELINE.md` |
| Aggregate runner-startup overhead reduced by the fold | CACHE-02 (Success #3) | Per-job startup overhead is observable only from live Actions run timing across before/after runs | Compare job count + queue/startup time vs `193-BASELINE.md` from the live run |

*Both are zero-human-UAT in spirit — they are read off CI's own summaries/timings, not a human clicking through. They simply require live runs that can't execute at plan time.*

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` grep/lint verify or a live-CI Wave gate
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the assertion-script gap
- [ ] No watch-mode flags (CI is the watcher)
- [ ] Quick feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner/nyquist pass)

**Approval:** pending
