---
phase: 148
slug: evaluator-funnel-and-first-run-dx
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-31
---

# Phase 148 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + ExDoc docs build + targeted docs contract assertions |
| **Config file** | `mix.exs`, `.github/workflows/ci.yml`, `test/example/priv/playwright/tests/demo-showcase.spec.ts` |
| **Quick run command** | `mix docs --warnings-as-errors` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~90-180 seconds for quick docs build; project test runtime depends on local Postgres state |

---

## Sampling Rate

- **After every task commit:** Run `mix docs --warnings-as-errors`.
- **After every plan wave:** Run `mix test`.
- **Before `$gsd-verify-work`:** Full suite plus docs build must be green, or any skipped manual/browser lane must be recorded with evidence.
- **Max feedback latency:** 180 seconds for docs-only edits before broader test gates.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 148-01-01 | 01 | 0 | ADOPT-01, ADOPT-03 | T-148-01 | Public entry surfaces route to one canonical evaluator path without conflicting first commands | docs contract | `rg` assertions across `README.md`, `mix.exs`, `doc/llms.txt`, `guides/introduction/demo-showcase.md`, `test/example/README.md` | no - Wave 0 | pending |
| 148-01-02 | 01 | 1 | ADOPT-01, ADOPT-03 | T-148-01 | README/HexDocs/AI index lane routing remains coherent and docs build | docs build | `mix docs --warnings-as-errors` | yes | pending |
| 148-02-01 | 02 | 1 | ADOPT-02 | T-148-02 | Persona and screenshot claims match committed source/assets and avoid certification overclaim | docs contract + asset presence | `rg` persona/state terms; `ls guides/assets/*demo-showcase-chromium.png` | partial | pending |
| 148-03-01 | 03 | 1 | ADOPT-04 | T-148-03 | First-run doctor guidance reuses task status vocabulary and exit semantics | command + docs contract | `mix sigra.doctor --quiet`; `rg` doctor status vocabulary in docs | partial | pending |
| 148-03-02 | 03 | 1 | ADOPT-01, ADOPT-04 | T-148-01 / T-148-03 | Evaluator can follow the documented first path in ten minutes or less | manual UAT | recorded stopwatch run using documented commands | no - manual | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] Add a narrow docs routing-contract assertion covering canonical links and first-command consistency across README, `mix.exs`/ExDoc extras, `doc/llms.txt`, `guides/introduction/demo-showcase.md`, and `test/example/README.md`.
- [ ] Add explicit doctor guidance checks for success/failure status vocabulary and exit-code explanation in the chosen canonical troubleshooting surface.
- [ ] Define the manual stopwatch UAT evidence format for the documented first-10-minutes evaluator path.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh evaluator reaches a meaningful auth flow in 10 minutes or less | ADOPT-01 | End-to-end evaluator timing depends on local setup, Postgres availability, and browser interaction | From a fresh checkout or cleaned example app state, run the documented commands, open the documented first live stop, log in with a seeded persona, and record elapsed time plus any deviations. |

---

## Validation Sign-Off

- [ ] All tasks have automated verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all missing references.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 180s for docs-only checks.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
