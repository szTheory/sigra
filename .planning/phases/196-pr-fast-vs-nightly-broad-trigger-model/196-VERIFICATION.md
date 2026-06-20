---
phase: 196
slug: pr-fast-vs-nightly-broad-trigger-model
created: 2026-06-20
status: recorded
---

# Phase 196 — Verification Record

This document captures two post-execution verification records for Phase 196:
(a) the D-13 correction — reconciling the stale CRIT-03 phrasing against live ground truth, and
(b) the D-08 per-moved-job never-strand proxy table — the complete CRIT-02 audit trail for all
5 jobs moved to nightly/main-only coverage.

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
