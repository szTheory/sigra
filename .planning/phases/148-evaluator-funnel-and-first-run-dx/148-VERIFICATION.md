---
phase: 148-evaluator-funnel-and-first-run-dx
verified: 2026-05-31T21:38:24Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/8
  gaps_closed:
    - "AI-consumption route map preserves the declared canonical evaluator path wording in plan artifacts"
  gaps_remaining: []
  regressions: []
automation_shift_left:
  former_human_test: "10-Minute Evaluator Stopwatch"
  automated_by: "test/example/priv/playwright/tests/demo-showcase.spec.ts"
  ci_lane: "example_playwright_smoke / demo-showcase-chromium"
  result: "passed locally in 852ms"
---

# Phase 148: Evaluator Funnel And First-Run DX Verification Report

**Phase Goal:** evaluator funnel and first-run DX for release adoption; public entry points route evaluators to the demo showcase, the first-run guide is runnable/source-backed, and `mix sigra.doctor` is the canonical first-run verification surface with exact status and exit semantics.
**Verified:** 2026-05-31T21:38:24Z
**Status:** passed
**Re-verification:** Yes — after gap closure and UAT automation shift-left

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | README, Hex package text, ExDoc, and `test/example/README.md` route evaluators to one canonical demo path. | ✓ VERIFIED | `README.md` lane table routes Evaluating to `guides/introduction/demo-showcase.md`; `mix.exs` has `main: "demo-showcase"` and package description URL; `test/example/README.md` links to `https://hexdocs.pm/sigra/demo-showcase.html`. |
| 2 | A fresh evaluator can run the documented demo flow and reach a meaningful auth flow in 10 minutes or less. | ✓ VERIFIED | `tests/demo-showcase.spec.ts` now starts at `/demo/credentials`, logs in as `alice@demo.sigra.dev`, reaches `/users/sessions`, and asserts elapsed browser-path time is <= 10 minutes. Local run passed in 852ms. |
| 3 | Demo persona map explains seeded-account intent including rough edges and auth states. | ✓ VERIFIED | `guides/introduction/demo-showcase.md` and `test/example/README.md` list all six personas plus MFA/OAuth/locked/unconfirmed/scheduled deletion/passkey/admin/multi-org context. |
| 4 | Screenshot grid + limitations make evaluator proof inspectable without certification overclaims. | ✓ VERIFIED | `guides/introduction/demo-showcase.md` references all 4 locked screenshot assets and includes “not production certification” and “not compliance evidence”. |
| 5 | First-run doctor guidance shows exact statuses, success/failure verdict lines, and exit semantics. | ✓ VERIFIED | `guides/introduction/troubleshooting-install.md` includes `[ ]/[~]/[✓]/[!]`, exact OK/ERROR lines, and `exit 0` / `exit 1`; docs-contract test asserts exact strings. |
| 6 | Top-level docs provide explicit evaluator/greenfield/upgrade/migration/advanced-control lanes. | ✓ VERIFIED | `README.md` `## Pick your lane` includes all required lane rows and links. |
| 7 | Evaluator funnel drift is machine-checked. | ✓ VERIFIED | `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` has 3 contract tests across route map, demo proof, and doctor wording/exit behavior. |
| 8 | `doc/llms.txt` satisfies declared Plan 148 artifact wording contract (`Demo Showcase — Vaultr Example App`). | ✓ VERIFIED | `doc/llms.txt` Introduction now contains `- [Demo Showcase — Vaultr Example App](demo-showcase.md)`; `verify.artifacts` for `148-01-PLAN.md` now passes. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `README.md` | lane router with explicit adoption choices | ✓ VERIFIED | Present and substantive; includes required lane labels and links. |
| `mix.exs` | evaluator-first package description + ExDoc main routing | ✓ VERIFIED | Contains evaluator-first URL and `main: "demo-showcase"`. |
| `doc/llms.txt` | evaluator-first route map with exact plan wording | ✓ VERIFIED | Exact phrase `Demo Showcase — Vaultr Example App` present in Introduction section. |
| `guides/introduction/demo-showcase.md` | canonical runnable evaluator path + persona/screenshot/limitations | ✓ VERIFIED | Contains command block, first stop, personas, screenshot asset references, limitation language. |
| `test/example/README.md` | runnable local companion linked to canonical showcase | ✓ VERIFIED | Contains runnable commands, first stop, persona table, and canonical back-link. |
| `guides/introduction/troubleshooting-install.md` | canonical doctor first-run semantics | ✓ VERIFIED | Contains exact states/verdicts/exit semantics and examples. |
| `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` | docs contract lock | ✓ VERIFIED | Contains scoped tests for plans 148-01/02/03 contracts. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `README.md` | `guides/introduction/demo-showcase.md` | Evaluating lane | ✓ WIRED | `verify.key-links` confirms pattern in source. |
| `mix.exs` | `guides/introduction/demo-showcase.md` | docs main page and package description | ✓ WIRED | `main: "demo-showcase"` and target URL present. |
| `doc/llms.txt` | `demo-showcase.md` | Introduction index | ✓ WIRED | Exact link text and target present. |
| `guides/introduction/demo-showcase.md` | screenshot assets + example README routing | screenshot grid + command/persona routing | ✓ WIRED | All declared patterns found. |
| `guides/introduction/troubleshooting-install.md` | `lib/mix/tasks/sigra.doctor.ex` | copied status labels and verdict lines | ✓ WIRED | Declared wording patterns found by key-link verification. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Mix.Tasks.Sigra.Doctor` | rendered diagnosis rows/verdict/wiring | `Mix.Tasks.Sigra.Doctor.run_with_opts/1` -> `Sigra.Doctor.run/1` | Yes | ✓ FLOWING |
| `Sigra.Doctor` | `rows`, `wiring`, `verdict` | `diagnose/1` resolves host config + optional-dep predicates and builds matrix via `build_matrix/4` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Phase 148 docs-contract suite passes | `mix test test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` | 3 tests, 0 failures (local rerun) | ✓ PASS |
| Automated evaluator stopwatch passes | `SIGRA_EXAMPLE_URL=http://127.0.0.1:4000 npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` | 2 tests, 0 failures; timed evaluator test passed in 852ms | ✓ PASS |
| Prior scoped doctor/docs bundle | `mix test test/sigra/doctor_test.exs test/sigra/mix/tasks/doctor_task_test.exs test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` | 32 tests, 0 failures (provided evidence) | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| N/A | `find scripts -path '*/tests/probe-*.sh' -type f` | no probe files found for this phase | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| ADOPT-01 | 148-01, 148-02, 148-03 | Canonical first path from README/Hex/ExDoc/example to runnable demo in 10 minutes | ✓ SATISFIED | Routing/docs/test contracts verified; timed evaluator browser path is automated in the demo-showcase Playwright lane. |
| ADOPT-02 | 148-02, 148-03 | Persona intent map + screenshot grid + explicit limitations | ✓ SATISFIED | `demo-showcase.md`, `test/example/README.md`, and phase test assertions. |
| ADOPT-03 | 148-01, 148-02 | Top-level lane choice for evaluator/greenfield/upgrade/migration/advanced-control | ✓ SATISFIED | `README.md` lane table and AI/Hex route alignment verified. |
| ADOPT-04 | 148-03 | Immediate post-install doctor verification with understandable success/failure output | ✓ SATISFIED | Troubleshooting doctor section exact statuses/verdict/exit semantics + test assertions. |

No orphaned requirement IDs detected for Phase 148: all expected IDs (`ADOPT-01..04`) are declared in plan frontmatter and accounted for.

### Anti-Patterns Found

No blocker debt markers (`TBD`/`FIXME`/`XXX`) or stub placeholders found in phase-modified files.

### Human Verification Required

None. The former 10-minute evaluator stopwatch is now automated by the demo-showcase Playwright lane and runs in the existing PR/main CI path.

### Closure Summary

Prior blocker closed: `doc/llms.txt` now contains the required phrase `Demo Showcase — Vaultr Example App`, and all plan artifact/link checks pass. The only former human UAT item was shifted left into Playwright and passed locally. No remaining verification items were found.

---

_Verified: 2026-05-31T21:38:24Z_
_Verifier: the agent (gsd-verifier)_
