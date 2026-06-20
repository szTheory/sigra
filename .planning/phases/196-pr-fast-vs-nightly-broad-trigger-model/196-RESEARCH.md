# Phase 196: PR-Fast vs Nightly-Broad Trigger Model - Research

**Researched:** 2026-06-20
**Domain:** GitHub Actions workflow topology — conditional job triggers, `needs`/`always()` aggregation, required-check stability
**Confidence:** HIGH (all ci.yml claims verified against the live file; ruleset read live via `gh api`; GitHub Actions semantics confirmed against official docs)

## Summary

This is a CI-restructure phase, not a code phase. The CONTEXT.md is unusually complete (16 file:line-anchored decisions D-01..D-16). The research job was to **ground-truth-verify every anchor** the planner will act on, not to relitigate the locked design. Verdict: **the CONTEXT.md line anchors are remarkably accurate** — nearly every cited line number matches the live `.github/workflows/ci.yml` exactly. Two facts the planner needs that differ from / refine the context: (1) the `phase_51` contract test's RED assertion is the **`installer_milestone_audit:` job-key reference (test line 28)**, not the path-detector count (test line 24, which still passes ×2); (2) MAINTAINING.md is **already correct** about the 5-required-checks-vs-ci-gate framing (lines 100-122) — the "stale premise" D-13 wants reconciled lives in **ROADMAP/CRIT-03 text**, not MAINTAINING.md.

The live ruleset (`14941512`, `enforcement: active`) was read directly and confirms **exactly 5 required status-check contexts**, byte-identical to D-11's list. None of the 5 jobs is in the move list, so required-check stability is structurally preserved by construction. GitHub Actions semantics are confirmed: a job skipped by its own job-level `if:` reports `result == 'skipped'` (official contexts doc), a downstream `if: always()` aggregator still runs, and the current per-lane `!= "success"` loop (ci.yml:1317) would therefore turn red on PRs unless changed — exactly D-09.

**Primary recommendation:** Execute the 16 decisions as written. The only mechanical risks are (a) getting the skip-tolerant `ci-gate` loop condition exactly right (D-09), (b) re-anchoring the phase_51 test to the surviving `fast_checks` step (D-15), and (c) re-reading the live ruleset at execution (D-12) — all three verified below with exact current state.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Verbatim from 196-CONTEXT.md `<decisions>` — all 16 are authoritative and MUST NOT be relitigated:

- **D-01:** Keep ONE `ci.yml`; add a `schedule:` cron alongside existing `workflow_dispatch`/`push:[main]`/`pull_request:[main]`. Mirror `playwright-github-pages.yml:16-18` (`cron: '45 6 * * *'`). Planner picks the exact cron minute, avoiding the `45 6` collision.
- **D-02:** Gate every "broad" job with **job-level `if: github.event_name != 'pull_request'`** (runs on schedule + push:main + workflow_dispatch; skipped on PRs). Safe because every moved job is non-required.
- **D-03:** Condition is `!= 'pull_request'` (NOT `== 'schedule'`) — main pushes + release-dispatch must keep full broad coverage.
- **D-04:** Job-level `if:` for whole-job removal, NOT step-level `event_name` gating (step-level is only for jobs that must keep reporting because required / feed a required aggregator).
- **D-05:** MOVE to non-PR: `install_matrix`, `upgrade_smoke`, `passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke`, `generated_admin_playwright_smoke`.
- **D-06:** KEEP on every PR: the 5 ruleset-protected required lanes; `install_golden_contract`; `library_tests_dep_off`.
- **D-07 (USER-CONFIRMED):** `generated_admin_playwright_smoke` is FULLY moved to nightly. Admin behavior proxied on PR by `example_playwright_smoke`'s admin specs. Residual gap (generated-host template parity becomes nightly-only) accepted, backstopped by DIST-06 `scripts/ci/admin-acceptance-smoke.sh`. MUST be recorded in MAINTAINING.md + VERIFICATION.
- **D-08:** Per-moved-job never-strand rationale recorded in VERIFICATION (see Validation Architecture below).
- **D-09:** Change `ci-gate` per-lane check from `[[ "$result" != "success" ]]` to fail only on failure/cancelled: `[[ "$result" != "success" && "$result" != "skipped" ]]`.
- **D-10:** Only `upgrade_smoke` + `generated_admin_playwright_smoke` are both moved AND in `ci-gate.needs`. Verify the `needs` list at execution; do NOT add moved jobs to `ci-gate.needs`.
- **D-11:** The 5 ruleset lane `name:` strings stay byte-identical AND unconditional on PR (no event_name gating, no rename).
- **D-12 (MANDATORY at execution):** Re-read the live ruleset (`gh api repos/szTheory/sigra/rulesets/14941512`) as ground truth. If a 6th/renamed context appeared, stop and reconcile.
- **D-13:** Reconcile the stale "single stable required check (`ci-gate` aggregator)" premise — enforced required checks are the 5 lane names; `ci-gate` is an internal aggregator, NOT required.
- **D-14:** Add a forced-failure probe as a `workflow_dispatch` input (`force_fail_probe`) that runs an `exit 1` step inside a nightly-gated job. Document `gh workflow run "CI" -f force_fail_probe=true` in MAINTAINING.md. Probe MUST live in a moved/non-PR-gated job.
- **D-15 (FOLD):** Re-anchor `phase_51_install_golden_ci_contract_test.exs` from the removed `installer_milestone_audit:` job key to the surviving `fast_checks` step. Test is already RED on main; MUST be green to merge.
- **D-16:** Re-verify `phase_58_oauth_oa01_ci_contract_test.exs` (workflow slicer) stays green after the ci.yml edit. Verify, don't assume.

### Claude's Discretion
- Exact cron minute/hour for the new `schedule:` (avoid `45 6` collision).
- Exact `if:` expression form.
- The `force_fail_probe` input name + which nightly job hosts the probe step.
- Precise wording of the skip-tolerant `ci-gate` loop.
- Where the reconciled required-check docs + nightly-cadence note + probe runbook land within MAINTAINING.md; whether local-development.md needs a one-line nightly mention.

### Deferred Ideas (OUT OF SCOPE)
- Re-gating the `continue-on-error` admin-design gallery (SEED-006) → Phase 197.
- Playwright sharding / boot-sharing / deterministic readiness → Phase 197.
- `mix ci` local-CI-equivalent + milestone acceptance measurement → Phase 198.
- Three reviewed-but-not-folded todos (admin-design pagination, token-reference CI guard, page04 branding scoring) → Phase 197 / out of CRIT scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description (verbatim from REQUIREMENTS.md) | Research Support |
|----|-------------|------------------|
| CRIT-02 | "Establish a PR-fast vs nightly/main-broad split — move exhaustive/low-probability coverage (install matrix ×4, upgrade smoke, broad galleries) off the every-PR path to `schedule:`/main, keeping a fast representative PR gate. **Never** strand a correctness-critical test on nightly only." | Move-list (D-05) verified against live ci.yml line numbers; never-strand proxies verified (Validation Architecture §). Cron precedent verified at `playwright-github-pages.yml:16-18`. |
| CRIT-03 | "Preserve a single stable required check (`ci-gate` aggregator) and stable child-check names across the redesign — no branch-protection churn, no path/skip pending-check traps." | Live ruleset read: 5 required contexts, none in move list. `ci-gate` skip-tolerance (D-09) verified necessary. **Note:** CRIT-03's own phrasing "single stable required check (`ci-gate`)" is the stale premise D-13 reconciles — the real required surface is the 5 lane names. |

**CRIT-03 framing correction (feeds D-13):** REQUIREMENTS.md line 21 and the ROADMAP still say the required check IS `ci-gate`. The **live ruleset proves otherwise** — `ci-gate` is NOT a required context. The planner should treat the 5 lane names as the required surface and record the CRIT-03-phrasing correction in VERIFICATION (do not edit REQUIREMENTS.md text mid-phase unless the planner decides to; MAINTAINING.md is already correct — see Ground-Truth §7).
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Trigger topology (when broad jobs run) | CI control plane (`on:` + job `if:`) | — | `schedule`/`push`/`dispatch` vs `pull_request` is a workflow-event concern, expressed at the `on:` trigger and job-level `if:`. |
| Required-check enforcement | GitHub repo ruleset (`14941512`) | CI job `name:` strings | Ruleset names the required status contexts; CI jobs *produce* contexts via `name:`. Stability is a contract between the two — never edit one without re-reading the other. |
| Aggregation under conditional jobs | `ci-gate` job (`if: always()` + result loop) | `needs` context | `ci-gate` is an internal DAG gate; its skip-tolerance is pure Actions-expression logic. |
| Correctness backstop for moved jobs | PR-path proxy jobs + DIST-06 acceptance smoke | nightly broad jobs | Never-strand is satisfied at the *test-coverage* tier (a PR-path proxy must independently observe each correctness invariant), not the trigger tier. |
| Contract-test self-verification | `mix test` (phase_51 / phase_58 planning tests) | — | These tests assert ci.yml *structure*; they gate this phase's own merge. |

## Standard Stack

No external packages installed. This phase edits YAML + Markdown + one `.exs` test. The "stack" is GitHub Actions workflow syntax and the repo's existing CI idioms.

### Core (in-repo idioms to reuse)
| Asset | Location | Purpose | Why Standard |
|-------|----------|---------|--------------|
| `schedule: cron` precedent | `playwright-github-pages.yml:14-18` `[VERIFIED: file read]` | Nightly trigger shape to copy | Live in-repo precedent (D-01). Uses `cron: '45 6 * * *'`. |
| `workflow_dispatch` trigger | `ci.yml:6` `[VERIFIED: file read]` | Already present; extend with `inputs:` for D-14 probe | No new trigger needed. |
| `if: always()` aggregator | `ci-gate` `ci.yml:1289` `[VERIFIED]` | Makes ci-gate run even when needs skip/fail | Already in place; only the result loop (1317) changes. |
| Thin name-preserving aggregator | `library_tests` `ci.yml:279-296` `[VERIFIED]` | Pattern for "matrix worker + named aggregator holding required name" | Precedent that `if: always()` + `needs.<job>.result` aggregation is already the house style. |
| Step-level event gate idiom | `fast_checks` `ci.yml:73-85`, `install_golden_contract` `ci.yml:120-135` `[VERIFIED]` | The change-detector `event_name != 'pull_request'` step pattern | D-04 contrast: this is for jobs that must keep reporting; D-02 uses JOB-level for whole-job removal. |

### Alternatives Considered (rejected by CONTEXT.md — do not revisit)
| Instead of | Could Use | Why rejected |
|------------|-----------|--------------|
| One ci.yml + `schedule:` | Separate `nightly.yml` | Second required-check namespace + branch-protection churn — contrary to CRIT-03 (D-01). |
| `!= 'pull_request'` | `== 'schedule'` | Strands main-push + release-dispatch coverage (D-03). |
| Job-level `if:` removal | Step-level event gate | Step-level is for jobs that must keep reporting (D-04). |

**No installation step. No Package Legitimacy Audit needed (zero external packages).**

## GitHub Actions Semantics (verified this session)

These are the load-bearing platform facts the plan depends on. All confirmed against official GitHub docs this session.

1. **`needs.<job_id>.result` possible values:** `success`, `failure`, `cancelled`, `skipped`. `[CITED: docs.github.com/.../reference/workflows-and-actions/contexts#needs-context]` — confirms `skipped` is a real propagated value.

2. **A job skipped by its own job-level `if:` propagates `result == 'skipped'`** to dependents. The downstream `ci-gate` uses `if: always()` (ci.yml:1289), so it **still executes** when a need is skipped. `[CITED: docs.github.com — using conditions to control job execution]` + corroborated by the repo's own `library_tests` `if: always()` aggregator pattern. The current per-lane loop fails on anything `!= "success"` (ci.yml:1317), so a `skipped` need would turn ci-gate **red on every PR** without D-09's `&& "$result" != "skipped"` tweak. `[VERIFIED: ci.yml:1304-1325 read]`

3. **A skipped required check is treated as neutral/Success for merge gating** — a job skipped by its `if:` does NOT block a PR even if it is a required context. `[CITED: github.com/orgs/community discussions]` This is *why* D-02's job-level skip is safe for non-required jobs, and *why* the 5 required lanes must NOT be event-gated (D-11) — gating a required lane off PRs would make it perpetually skipped→but the ruleset still expects a context, risking a pending/never-arriving trap. (None of the 5 is gated, so this is structurally avoided.)

4. **`schedule`, `push`, `workflow_dispatch` all yield `github.event_name != 'pull_request'`** — distinct values (`'schedule'`, `'push'`, `'workflow_dispatch'`), none equal `'pull_request'`. `[CITED: docs.github.com — events that trigger workflows]` D-02's gate therefore runs broad jobs on all three and skips only on PRs.

5. **`workflow_dispatch` inputs (D-14):**
   - Define under `on.workflow_dispatch.inputs.<name>` with `description`/`required`/`default`/`type` (use `type: boolean` for a force-fail flag). `[CITED: docs.github.com]`
   - Read in a step or `if:` via **`inputs.<name>`** (preferred; preserves type) — e.g. `if: ${{ inputs.force_fail_probe == true }}` or `if: ${{ github.event.event_name != 'pull_request' && inputs.force_fail_probe }}`. The legacy `github.event.inputs.<name>` (always a string) also works. `[CITED: docs.github.com]`
   - On non-dispatch events (`schedule`/`push`/`pull_request`) `inputs.force_fail_probe` is unset/falsy, so the probe step stays inert. Plan the probe step's `if:` to both (a) be inside a non-PR-gated job and (b) guard on the input.

## Ground-Truth Verification of CONTEXT.md Anchors

> Every claim below is from a direct read of the live files this session. **The CONTEXT.md line anchors are almost entirely accurate.** Discrepancies are flagged ⚠️.

### §1 — Moved-job anchors (D-05)
| Job (CONTEXT anchor) | Live `name:` string `[VERIFIED]` | Live job-def line | Verdict |
|----------------------|-----------------------------------|-------------------|---------|
| `install_matrix` (ci.yml:604) | `Install matrix (flag combinations)` | **604** | ✅ exact |
| `upgrade_smoke` (ci.yml:502) | `Upgrade smoke (published source series -> local candidate)` | **502** | ✅ exact |
| `passkeys_manual_fallback_smoke` (ci.yml:554) | `Passkeys manual fallback smoke` | **554** | ✅ exact |
| `passkeys_opt_out_smoke` (ci.yml:733) | `Passkeys opt-out smoke` | **733** | ✅ exact |
| `generated_admin_playwright_smoke` (ci.yml:1156, ~60m) | `Generated admin Playwright smoke`, `timeout-minutes: 60` (1162) | **1156** | ✅ exact |

### §2 — Kept / required-lane anchors (D-06, D-11)
| Job | Live `name:` string `[VERIFIED]` | Job-def line | In ruleset? | In `ci-gate.needs`? |
|-----|-----------------------------------|--------------|-------------|---------------------|
| `library_tests` (aggregator) | `Library tests` | 279 | ✅ required | ✅ (1281) |
| `library_tests_shard` (matrix worker) | `Library tests shard ${{ matrix.partition }}` | 176 | ✗ (worker) | ✗ |
| `example_unit_smoke` | `Example unit smoke (ExUnit + ConnTest)` | 382 | ✅ required | ⚠️ **NOT in ci-gate.needs** |
| `install_smoke` | `Install smoke (fresh phx.new + sigra.install)` | 440 | ✅ required | ✅ (1283) |
| `example_http_smoke` | `Example HTTP smoke (boot + curl critical routes)` | 783 | ✅ required | ✅ (1285) |
| `example_playwright_smoke` | `Example Playwright smoke (full lifecycle)` | 858 | ✅ required | ✅ (1286) |
| `install_golden_contract` | `Install golden + idempotency contract (subprocess harness)` | 102 | ✗ (path-gated) | ✅ (1280) |
| `library_tests_dep_off` | `Library tests (dep-off — Threadline absent)` | 298 | ✗ | ✅ (1282) |

⚠️ **Planner note:** `example_unit_smoke` is a *required* check but is **NOT** in `ci-gate.needs` (the needs list lines 1279-1288 omits it). The set of 5 required checks and the set of `ci-gate.needs` are **overlapping but distinct**. This reinforces D-13: `ci-gate` is an internal aggregator, not the required surface. The planner must not assume "required == in ci-gate.needs."

### §3 — `ci-gate.needs` exact membership (D-10) `[VERIFIED: ci.yml:1279-1288]`
Exactly 9 jobs, in order:
```
install_golden_contract, library_tests, library_tests_dep_off, install_smoke,
upgrade_smoke, example_http_smoke, example_playwright_smoke,
generated_admin_playwright_smoke, fast_checks
```
**Of the 5 moved jobs, exactly 2 are in this list:** `upgrade_smoke` (1284) and `generated_admin_playwright_smoke` (1287). → **D-10 is CONFIRMED.** `install_matrix`, `passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke` are NOT in `ci-gate.needs`, so moving them needs no aggregator change. The skip-tolerant loop (D-09) handles the two that are.

### §4 — `ci-gate` result loop (D-09) `[VERIFIED: ci.yml:1289, 1304-1325]`
- `if: always()` is at **line 1289** ✅.
- Per-lane check at **line 1317**: `if [[ "$result" != "success" ]]; then` ✅ — this is the exact line D-09 changes to `if [[ "$result" != "success" && "$result" != "skipped" ]]; then`.
- The loop iterates 9 env-mapped lane vars (1305-1314); `result="${!lane}"` indirect-expands each (1316). The two moved-and-needed jobs (`UPGRADE_SMOKE` 1297, `GENERATED_ADMIN_PLAYWRIGHT_SMOKE` 1300) will resolve to `skipped` on PRs.
- **No structural change to the env block or loop body needed beyond the single condition.** A real `failure`/`cancelled` on a still-PR-running lane stays red.

### §5 — Cron-collision check (D-01, Claude's discretion) `[VERIFIED: playwright-github-pages.yml:16-18]`
- The ONLY other cron in the repo is `playwright-github-pages.yml` → `cron: '45 6 * * *'` (06:45 UTC). `[VERIFIED: grep across `.github/workflows/`]`
- **Recommendation:** pick a slot offset by ≥1h to avoid runner contention with the Pages publisher. A clean, easily-reasoned choice: **`cron: '30 4 * * *'`** (04:30 UTC) — well clear of 06:45, off-peak, and a "round" minute distinct from `45`. (Any value not `45 6` satisfies D-01; this is a recommendation, not a mandate. `[ASSUMED]` that 04:30 is low-contention — GitHub schedules best-effort, exact minute is not guaranteed.)

### §6 — Required-check ruleset (D-12, MANDATORY re-read) `[VERIFIED: gh api this session]`
`gh api repos/szTheory/sigra/rulesets/14941512` succeeded. `enforcement: active`, `strict_required_status_checks_policy: true`. The `required_status_checks` contexts are **exactly 5, byte-identical to D-11**:
1. `Library tests`
2. `Example unit smoke (ExUnit + ConnTest)`
3. `Install smoke (fresh phx.new + sigra.install)`
4. `Example HTTP smoke (boot + curl critical routes)`
5. `Example Playwright smoke (full lifecycle)`

**No 6th context. No `ci-gate` in the required list.** D-11 and D-13 are both confirmed against live ground truth. ⚠️ **D-12 still mandates the planner re-run this `gh api` at execution time** — the ruleset is mutable and this snapshot is from 2026-06-20.

### §7 — Doc reconciliation (D-13) — refinement for the planner `[VERIFIED: MAINTAINING.md:100-122 read]`
⚠️ **MAINTAINING.md is ALREADY correct.** Lines 100-122 already state: the 5 enforced checks are the job `name:` strings, and **"`ci-gate` is NOT an enforced required check… It is an internal aggregator."** It even documents the verify command (line 117). **The stale "single stable required check (`ci-gate`)" premise lives in ROADMAP / REQUIREMENTS CRIT-03 (REQUIREMENTS.md:21), NOT in MAINTAINING.md.** So D-13's reconciliation work is: (a) record in 196-VERIFICATION that CRIT-03's phrasing is stale and the 5-lane reality stands; (b) optionally add a nightly-cadence subsection to MAINTAINING.md's CI docs (the required-check section needs no correction — it's already right). The planner should NOT "fix" MAINTAINING.md's required-check list; it should *add* the nightly/probe runbook.

### §8 — Contract tests (D-15, D-16)
**`phase_51_install_golden_ci_contract_test.exs`** `[VERIFIED: file read + `mix test` run]`:
- Test **51-01** (line 20) asserts THREE things:
  1. line 24: the canonical path-detector regex appears **exactly twice** in ci.yml — `[VERIFIED]` it currently appears **2×** (in `fast_checks` step `ci.yml:78` and `install_golden_contract` step `ci.yml:131`). ✅ **still passes.**
  2. line 27: `assert yml =~ "install_golden_contract:"` — ✅ still present (ci.yml:102).
  3. line 28: `assert yml =~ "installer_milestone_audit:"` — ❌ **RED.** `[VERIFIED: grep returns nothing]` Phase 194 folded that **job** into the `fast_checks` job; the surviving anchor is a **step** named `Installer milestone audit (INT-01..03)` (ci.yml:83) that runs `scripts/ci/installer-milestone-audit.sh` (ci.yml:85).
- `mix test` output confirms: **"2 tests, 1 failure"**, failure at line 28, `assert yml =~ "installer_milestone_audit:"`. `[VERIFIED: test run this session]`
- Test **51-02** (line 31) asserts MAINTAINING.md + v1.4-GA-UAT.md doc links — ✅ passes; unaffected.
- **D-15 re-anchor target:** change line 28's `"installer_milestone_audit:"` assertion to match the surviving **step**. The robust new anchors (any/all): the step name `"Installer milestone audit"` and/or the run command `"scripts/ci/installer-milestone-audit.sh"`. ⚠️ The module `@moduledoc` (lines 2-6) and the test name (line 20) also reference the removed `installer_milestone_audit` *job* — the planner should update the wording for honesty, but only the **line-28 assertion** is the hard RED. Note the path-detector-×2 assertion (line 24) is **independent of D-02** (D-02 doesn't touch those two detector steps), so it should stay green after the phase edit — but verify post-edit.

**`phase_58_oauth_oa01_ci_contract_test.exs`** `[VERIFIED: file read]`:
- Slices the workflow by splitting on `"library_tests_shard:"` then on `"\n  library_tests:"` (lines 28-30) to isolate the shard-worker body, then asserts the body contains `"Run library tests"`, `"mix test --partitions 2"`, and `refute … --exclude.*oauth` (lines 44-48).
- D-02's job-level-`if:` approach does **not** reorder or rename `library_tests_shard`/`library_tests`, and none of the moved jobs sit between them. **So this test should stay green.** ⚠️ D-16 mandates re-running it after the ci.yml edit (verify, don't assume). One subtle risk: if the planner adds the `schedule:`/`inputs:` block or reorders jobs such that a moved job lands *between* `library_tests_shard:` and `library_tests:`, the slicer's second split would capture extra text — but the move jobs are all far from that boundary today, so keep them there.

## Architecture Patterns

### Trigger-topology data flow

```
                    ┌─────────────────────────────────────────────┐
   GitHub event ───▶│ on: workflow_dispatch (+inputs.force_fail)   │
   (PR / push:main /│     push:[main] / pull_request:[main]        │
    schedule cron / │     schedule: cron '30 4 * * *'  ← NEW (D-01)│
    manual dispatch)└───────────────┬─────────────────────────────┘
                                     │ each job evaluates its if:
                 ┌───────────────────┴────────────────────┐
                 ▼                                         ▼
   github.event_name == 'pull_request'        event_name != 'pull_request'
   (PR-fast gate)                              (schedule + push:main + dispatch)
   ┌──────────────────────────────┐           ┌────────────────────────────────┐
   │ 5 REQUIRED lanes (unconditional)         │ MOVED broad jobs (D-02 if:):    │
   │  Library tests                │           │  install_matrix (×4)            │
   │  Example unit smoke           │           │  upgrade_smoke ───────────┐     │
   │  Install smoke                │           │  passkeys_manual_fallback │     │
   │  Example HTTP smoke           │           │  passkeys_opt_out         │     │
   │  Example Playwright smoke     │           │  generated_admin_pw ──────┤     │
   │ + install_golden_contract     │           │  + force_fail_probe step  │     │
   │   (path-gated, kept)          │           │    (D-14, inside a moved   │     │
   │ + library_tests_dep_off (kept)│           │     job, inputs-guarded)  │     │
   └──────────────┬───────────────┘           └───────────┬───────────────┘     │
                  │  (on PR these 2 moved-&-needed jobs → result: skipped) ◀─────┘
                  ▼                                         ▼
          ┌──────────────────────────────────────────────────────────┐
          │ ci-gate  (if: always(), internal aggregator — NOT required)│
          │ loop: fail only if result ∉ {success, skipped}  ← D-09     │
          └──────────────────────────────────────────────────────────┘
                  │
                  ▼
   GitHub branch ruleset 14941512 enforces the 5 REQUIRED contexts
   (ci-gate is NOT one of them)  — required surface unchanged by this phase
```

### Pattern: job-level event gate (D-02)
```yaml
# Source: ci.yml house style; semantics CITED above
upgrade_smoke:
  name: Upgrade smoke (published source series -> local candidate)
  runs-on: ubuntu-latest
  if: github.event_name != 'pull_request'   # ← the ONLY structural add per moved job
  needs: release_ref_guard
  # …body unchanged…
```
Every moved job gains exactly this one `if:` line; bodies, `services.postgres`, caches, `$GITHUB_STEP_SUMMARY` stay byte-identical (CONTEXT `<code_context>`).

### Pattern: skip-tolerant aggregator loop (D-09)
```bash
# ci.yml:1317 — change this single condition:
-   if [[ "$result" != "success" ]]; then
+   if [[ "$result" != "success" && "$result" != "skipped" ]]; then
```

### Pattern: forced-failure probe (D-14)
```yaml
on:
  workflow_dispatch:
    inputs:
      force_fail_probe:
        description: 'Force the nightly probe step to exit 1 (verifies nightly lane fails red)'
        type: boolean
        default: false
# …inside a MOVED (non-PR-gated) job, e.g. upgrade_smoke or a dedicated nightly job…
  - name: Forced-failure probe (nightly self-test)
    if: ${{ inputs.force_fail_probe }}
    run: |
      echo "force_fail_probe=true: intentionally failing to prove the nightly lane reports red"
      exit 1
```
Runbook line for MAINTAINING.md: `gh workflow run "CI" -f force_fail_probe=true` (the dispatch must target a ref where the job's `if: != 'pull_request'` is satisfied — i.e. a branch/tag, which `workflow_dispatch` always is). ⚠️ Note the host job already needs `if: github.event_name != 'pull_request'`; the probe step additionally needs `if: ${{ inputs.force_fail_probe }}`. If the host job is `release_ref_guard`-needed and dispatched from a non-`v*` tag, `release_ref_guard` would fail first — pick a host job whose `needs` won't pre-empt the probe, or dispatch from a `v*` ref. (Of the moved jobs: `passkeys_manual_fallback_smoke`, `passkeys_opt_out_smoke`, `install_matrix` have **no `needs:`**, so they reach the probe step regardless of ref — good probe hosts. `upgrade_smoke` + `generated_admin_playwright_smoke` `needs: release_ref_guard`.)

### Anti-Patterns to Avoid
- **Event-gating a required lane.** Never add `if: event_name != 'pull_request'` to any of the 5 ruleset lanes — a perpetually-skipped required context invites pending-check / merge-outage traps (D-11). Verified none of the 5 is in the move list.
- **Adding moved jobs to `ci-gate.needs`.** D-10: the 3 non-needed moved jobs must stay out of `ci-gate.needs`; adding them creates new skipped entries the loop would have to tolerate for no benefit.
- **Renaming the matrix worker / aggregator.** Disturbing the `library_tests_shard:` → `library_tests:` ordering breaks the phase_58 slicer (D-16) and could orphan the `Library tests` required context.
- **"Fixing" MAINTAINING.md's required-check list.** It's already correct (§7). Only ADD nightly/probe docs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Run only off PRs" | Custom branch-name string parsing | `if: github.event_name != 'pull_request'` | Native, covers schedule+push+dispatch in one expression (D-02/D-03). |
| Nightly trigger | A second `nightly.yml` | `schedule: cron` in the same `ci.yml` | Avoids a second required-check namespace (D-01). |
| Aggregator that tolerates skips | A bespoke status-collection action | The existing `if: always()` + `needs.*.result` loop | Already the house pattern (`library_tests`, `ci-gate`). |
| Forced-failure test of nightly | A synthetic code regression / a sleep-until-cron | `workflow_dispatch` boolean input + `exit 1` step | No cron wait, no fake commit (D-14). |
| Reading required-check truth | Trusting ROADMAP/MAINTAINING prose | `gh api repos/szTheory/sigra/rulesets/14941512` | The ruleset is the only ground truth (D-12). |

**Key insight:** Every mechanism this phase needs already exists in the repo's CI; the phase is almost entirely *applying one `if:` line per moved job* + *one condition change in ci-gate* + *one test re-anchor* + *docs*. The risk is precision, not novelty.

## Runtime State Inventory

> This is a CI-restructure (rename-adjacent) phase. State that survives a file edit:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore keys reference job names. | None. |
| Live service config | **GitHub branch ruleset `14941512`** stores the 5 required-check *context strings* in GitHub's config (NOT in git). If any of the 5 `name:` strings changed, the ruleset would strand a pending context. `[VERIFIED: gh api]` | **Code edit only — do NOT touch the 5 names (D-11).** No ruleset API change in this phase. Re-read at execution (D-12). |
| OS-registered state | None. GitHub Actions schedules are derived from the `on.schedule` block in the workflow file itself; nothing is OS-registered. | None. |
| Secrets/env vars | No secret/env-var names change. `force_fail_probe` is a workflow *input*, not a secret. | None. |
| Build artifacts | None. No compiled/installed artifact carries a CI job name. The phase_51 test asserts against ci.yml text at `mix test` time (no stale build). | None — but `mix test` must be re-run post-edit (D-15/D-16 verify). |

**Canonical question answered:** After ci.yml is edited, the only runtime system holding the old strings is **GitHub's ruleset** — and this phase deliberately does NOT change any of the 5 names it stores, so there is nothing to migrate. The forced-failure probe (D-14) is the executable proof the new nightly path actually runs.

## Common Pitfalls

### Pitfall 1: `ci-gate` goes red on every PR after the move
**What goes wrong:** Moving `upgrade_smoke` + `generated_admin_playwright_smoke` makes their `needs.<job>.result == 'skipped'` on PRs; the unchanged loop (`!= "success"`) treats `skipped` as failure → ci-gate red on every PR.
**Why it happens:** `skipped` ≠ `success`. The loop's binary "success-or-die" check is too strict.
**How to avoid:** D-09 — `&& "$result" != "skipped"`. Verify the exact line is 1317 today.
**Warning signs:** A green PR where ci-gate alone is red with "Required release lane UPGRADE_SMOKE: skipped".

### Pitfall 2: phase_51 test stays red / over-edited
**What goes wrong:** The planner re-anchors the wrong assertion (e.g. weakens the path-detector ×2 check on line 24, which is *not* the RED one) or leaves line 28 still asserting the removed job key.
**Why it happens:** Test 51-01 bundles 3 assertions; only line 28 is RED.
**How to avoid:** Change **only** line 28's `"installer_milestone_audit:"` to a surviving anchor (`"Installer milestone audit"` step name and/or `"scripts/ci/installer-milestone-audit.sh"`). Keep line 24 (×2) and line 27 (`install_golden_contract:`) intact. Update moduledoc/test-name wording for honesty.
**Warning signs:** `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` still shows a failure, or the test now passes vacuously.

### Pitfall 3: probe job pre-empted by `release_ref_guard`
**What goes wrong:** Hosting the D-14 probe in a job that `needs: release_ref_guard`, then dispatching from a non-`v*` ref → `release_ref_guard` fails (ci.yml:35-42) and the probe job is skipped before the probe step runs, so the probe "passes" misleadingly.
**Why it happens:** `release_ref_guard` hard-fails `workflow_dispatch` runs not on `refs/tags/v*`.
**How to avoid:** Host the probe in a `needs`-free moved job (`passkeys_*`, `install_matrix`) OR document that the probe dispatch must use a `v*` ref.
**Warning signs:** Probe run shows the host job skipped/blocked rather than red on the `exit 1` step.

### Pitfall 4: phx_new pin drift breaks a moved job silently
**What goes wrong:** Moved install/upgrade jobs pin `mix archive.install --force hex phx_new 1.8.7` (SEED-004). They now run only nightly/main, so a phx_new-version-sensitive break surfaces a day late, not on PR.
**Why it happens:** That's the *intended* tradeoff of moving exhaustive coverage off PR (D-08: `upgrade_smoke` has no PR proxy).
**How to avoid:** This is accepted per D-08; the never-strand guarantee covers *correctness-critical* coverage via PR proxies (Validation Architecture §). Record the upgrade_smoke residual explicitly.
**Warning signs:** A green PR followed by a red nightly on a release-boundary job.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All jobs run on every PR (~22m wall-clock) | PR-fast gate + nightly/main broad split | This phase (196) | CRIT-02; GATE-01 targets well under ~22m, ideally <~12m PR path. |
| `installer_milestone_audit:` standalone job | Folded into `fast_checks` job as a named step | Phase 194 (CACHE-02) | phase_51 test left RED (D-15 folds the fix here). |
| `library_tests` monolith | `library_tests_shard` matrix + `library_tests` aggregator | Phase 195 (TEST-01) | phase_58 slicer re-anchored to the shard worker; D-16 re-verifies. |
| Required check = `ci-gate` (stale prose) | Required checks = 5 lane `name:` strings; ci-gate internal | Phase 194 (194-D01/D15) | D-13 reconciles CRIT-03/ROADMAP phrasing; MAINTAINING.md already correct. |

**Deprecated/outdated:**
- The phrase "single stable required check (`ci-gate` aggregator)" in CRIT-03 / ROADMAP — superseded; the 5 lane names are the enforced surface.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `cron: '30 4 * * *'` (04:30 UTC) is a low-contention slot clear of the `45 6` Pages cron. | §5 Cron-collision | Low — any non-`45 6` value satisfies D-01; GitHub crons are best-effort anyway. Planner may pick differently (discretion). |
| A2 | The phase_58 slicer stays green because no moved job lands between `library_tests_shard:` and `library_tests:`. | §8 | Low — verified the boundary is far from move targets, but D-16 mandates a post-edit `mix test` run regardless. |

**All other claims are `[VERIFIED]` (live file/`gh`/`mix test` reads) or `[CITED]` (official GitHub docs).** No package/registry assumptions (zero external deps).

## Open Questions (RESOLVED)

1. **Which moved job hosts the D-14 probe step?**
   - What we know: probe must be in a non-PR-gated job (D-14); `needs`-free moved jobs (`passkeys_*`, `install_matrix`) avoid the `release_ref_guard` pre-emption pitfall.
   - What's unclear: whether the planner prefers reusing an existing moved job vs a tiny dedicated `nightly_probe` job (cleaner blast-radius, one extra runner).
   - Recommendation: a dedicated `needs`-free, `if: github.event_name != 'pull_request'` job named e.g. `nightly_probe` whose only step is the inputs-guarded `exit 1` — clearest semantics, no entanglement with a real job's `needs`. (Planner's discretion per CONTEXT.)
   - RESOLVED: Plan 03 adopts the recommendation — a dedicated `needs`-free `nightly_probe` job hosts the inputs-guarded `force_fail_probe` `exit 1` step.

2. **Does this phase edit REQUIREMENTS.md/ROADMAP CRIT-03 prose, or only record the correction in VERIFICATION?**
   - What we know: D-13 says "record the correction in VERIFICATION rather than perpetuating the stale framing"; MAINTAINING.md is already correct.
   - Recommendation: record in 196-VERIFICATION; leave REQUIREMENTS.md/ROADMAP text as-is unless the planner explicitly scopes a prose fix (the *enforcement reality* is already documented in MAINTAINING.md).
   - RESOLVED: Plan 04 records the D-13 correction in 196-VERIFICATION.md only (VERIFICATION-only); REQUIREMENTS.md/ROADMAP prose is left untouched per the recommendation.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI (authed) | D-12 live ruleset re-read at execution | ✓ | authed this session (read `14941512` OK) | If unauthed at execution: fall back to the 5 names in MAINTAINING.md:106-110 / 194-CONTEXT.md, and the planner MUST flag re-verification. |
| `mix` + Postgres (test DB) | Running phase_51/phase_58 contract tests (D-15/D-16) | ✓ (mix ran; contract tests are pure-text, no DB needed) | — | The two planning tests read ci.yml text only; the Postgres connection errors in the run log are from *other* async tests and do not affect these structural assertions. |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** `gh` auth at execution (fallback documented above).

## Validation Architecture

> Nyquist validation is ENABLED (`.planning/config.json: nyquist_validation: true`). This section drives 196-VALIDATION.md (Dimension 8) and the never-strand evidence in VERIFICATION.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) for the contract tests; GitHub Actions itself is the "test harness" for the trigger model. |
| Config file | none extra — `mix test` runs the planning contract tests. |
| Quick run command | `mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` |
| Full suite command | `mix test` (these tests gate this phase's own merge) |

### Never-Strand Guarantees → PR-path proxy map (D-07, D-08)

Each MOVED correctness-relevant invariant MUST be independently observable on the PR path. This table is the executable never-strand contract (CRIT-02):

| Moved job | Correctness invariant | PR-path proxy that independently observes it | Residual (nightly-only) | `[source]` |
|-----------|----------------------|----------------------------------------------|--------------------------|-----------|
| `install_matrix` (×4) | Default `mix sigra.install` produces a compiling/booting app | `install_smoke` (bare default install, `scripts/ci/install-smoke.sh`) — a *required* PR lane | Only flag-combo breadth (`--no-passkeys` / `--no-organizations` perms) | D-08 `[VERIFIED: install_smoke is required, ci.yml:440]` |
| `passkeys_manual_fallback_smoke` / `passkeys_opt_out_smoke` | Passkey enabled happy-path works | `example_playwright_smoke` runs `passkeys-hooks.spec.ts`, `passkey-login.spec.ts`, `passkey-options.spec.ts` (ci.yml:1050-1053) — a *required* PR lane | Opt-out + manual-fallback edges only | D-08 `[VERIFIED: ci.yml:1047-1053]` |
| `upgrade_smoke` | Published→local-candidate upgrade path | **No per-PR behavioral proxy** — release-boundary coverage; still runs on push:main + release-dispatch | The whole upgrade path is nightly/main-only on PRs (accepted; not per-feature-PR correctness) | D-08 — record explicitly in VERIFICATION |
| `generated_admin_playwright_smoke` | Generated-host admin *behavior* | `example_playwright_smoke` admin specs (`admin-user-operations`, `impersonation`, `admin-audit`, `admin-modal-interaction`, `admin-checkpoints`, ci.yml:959-993) — a *required* PR lane | Generated-host **template parity** (installer shell vs lib admin) → nightly-only, backstopped by DIST-06 `scripts/ci/admin-acceptance-smoke.sh` | D-07 (USER-CONFIRMED) `[VERIFIED: ci.yml:959-993]` |

**Honest-truth requirement (D-07):** the two residuals (`upgrade_smoke` whole-path, generated-host template parity) MUST be written explicitly into MAINTAINING.md + 196-VERIFICATION — not silently moved.

### Forced-failure probe as the executable never-fails-silently test (D-14)
The probe is the Nyquist "the detector actually detects" check: it proves the nightly lane **fails red on a real regression** and propagates to its own check.
- **Per task commit:** `mix test <the two planning contract tests>` green (re-anchor + slicer).
- **Per phase gate:** full `mix test` green; ci.yml lints/parses; `gh api` ruleset re-read shows 5 unchanged contexts.
- **Self-measuring CI evidence (zero-human-UAT, from phase Verification block):**
  1. PR-path vs nightly-path **job inventory diff** (which jobs carry the `if:`; which skip on a PR run).
  2. **Required/child-check name diff** before/after = empty (5 names byte-identical).
  3. **Forced-failure probe**: `gh workflow run "CI" -f force_fail_probe=true` → the probe's host (nightly-gated) job goes red, proving the nightly trigger path executes and reports failure. A normal nightly/dispatch run with `force_fail_probe=false` stays green.
  4. **PR wall-clock** measured vs Phase-193 baseline (GATE-01 target: well under ~22m, ideally <~12m) with equal-or-greater PR-gate quality signal.

## Security Domain

`security_enforcement` is enabled (absent = enabled). This phase changes **no** auth code, secrets, crypto, input-validation, or data paths — it only reorders CI job triggers and edits docs/one test.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2–V6 (auth/session/access/input/crypto) | no | No application code touched. |
| V14 Config (CI/CD supply chain) | marginally | Existing controls preserved: pinned action SHAs (`actions/checkout@df4cb1c…`, `setup-beam@fc68ffb…`), least-privilege `permissions: contents: read` (ci.yml:16-17), env-var-indirected matrix flags (`MATRIX_FLAGS`, ci.yml:687, WR-02). Moving jobs does NOT relax any of these — bodies move unchanged. |

| Threat Pattern | STRIDE | Mitigation (unchanged by this phase) |
|----------------|--------|--------------------------------------|
| Command injection via matrix value | Tampering | `MATRIX_FLAGS` env indirection already in place (ci.yml:681-692); preserved on move. |
| Unpinned action drift | Tampering | All `uses:` already SHA-pinned; no new actions added. |
| `workflow_dispatch` input abuse (D-14) | Elevation | `force_fail_probe` is a boolean that only triggers `exit 1` — no privileged effect; cannot be set on PR/schedule events. |

## Sources

### Primary (HIGH confidence — verified this session)
- `.github/workflows/ci.yml` — full file read; every job/line anchor verified (jobs at 24/48/102/176/279/298/382/440/502/554/604/733/783/858/1156/1276; ci-gate.needs 1279-1288; if:always 1289; loop condition 1317).
- `gh api repos/szTheory/sigra/rulesets/14941512` — live ruleset, 5 required contexts, `enforcement: active`.
- `.github/workflows/playwright-github-pages.yml:14-18` — sole other cron (`45 6 * * *`).
- `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` — read + `mix test` run (confirmed 1 failure at line 28).
- `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` — read (slicer anchors lines 28-30, 44-48).
- `MAINTAINING.md:100-122` — required-check docs (already correct).
- `.planning/REQUIREMENTS.md:20-21` — CRIT-02/CRIT-03 verbatim.
- `.planning/config.json` — `nyquist_validation: true`.

### Secondary (MEDIUM confidence — official GitHub docs)
- docs.github.com — workflows-and-actions/contexts (`needs.<job>.result` ∈ {success, failure, cancelled, skipped}).
- docs.github.com — events that trigger workflows (workflow_dispatch inputs; event_name values).
- github.com/orgs/community discussions 25286/26945/45058 — `if: always()` + skipped-needs behavior; skipped required check treated as neutral.

## Metadata

**Confidence breakdown:**
- ci.yml anchors / move list / ci-gate.needs: HIGH — direct file read, line-by-line.
- Required-check ruleset: HIGH — live `gh api` read.
- GitHub Actions skip/needs/inputs semantics: HIGH (contexts result-values, event names, inputs) / MEDIUM (skipped→always() edge fully corroborated by repo's own `if: always()` aggregators but the exact official sentence is implicit).
- Contract-test RED state: HIGH — `mix test` executed, failure reproduced.
- Cron slot recommendation: MEDIUM — recommendation, planner discretion.

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 for GitHub Actions semantics (stable). ⚠️ The ruleset snapshot and ci.yml line numbers are **point-in-time** — D-12 mandates a live `gh api` re-read and the planner should re-grep line numbers at execution since any prior commit can shift them.
