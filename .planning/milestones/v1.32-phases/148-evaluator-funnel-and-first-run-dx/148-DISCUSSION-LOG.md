# Phase 148: Evaluator Funnel And First-Run DX - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-31
**Phase:** 148-evaluator-funnel-and-first-run-dx
**Mode:** assumptions
**Areas analyzed:** Canonical First Path, Demo Persona Map, Screenshot Grid And Proof Boundaries, Doctor / First-Run Verification, Scope Boundary

## Assumptions Presented

### Canonical First Path

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Make `guides/introduction/demo-showcase.md` the canonical evaluator-first path, then route README, Hex package text/metadata, ExDoc, `doc/llms.txt`, and `test/example/README.md` to it. | Likely | `README.md`, `mix.exs`, `doc/llms.txt`, `guides/introduction/demo-showcase.md`, `test/example/README.md` |

### Demo Persona Map

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use the existing six-persona data as the source of truth; improve explanation and routing, not persona shape or seeded behavior. | Confident | `test/example/lib/example/demo/personas.ex`, `test/example/README.md`, `guides/introduction/demo-showcase.md`, `.planning/REQUIREMENTS.md` |

### Screenshot Grid And Proof Boundaries

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Reuse the four existing committed demo screenshots as the screenshot grid and keep the limitation language honest: evaluator proof, not production certification. | Confident | `guides/assets/*demo-showcase-chromium.png`, `test/example/priv/playwright/tests/demo-showcase.spec.ts`, `README.md` |

### Doctor / First-Run Verification

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Thread `mix sigra.doctor` into first-run guidance as the immediate post-install verification step, with expected success/failure examples drawn from the existing task output states. | Likely | `lib/mix/tasks/sigra.doctor.ex`, `lib/sigra/doctor.ex`, `guides/recipes/deployment.md`, `guides/introduction/troubleshooting-install.md` |

### Scope Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| This phase should be docs/asset/routing/test-proof work only: no new auth primitives, no generated-host UI redesign, no live OAuth credential setup, and no persona-banner feature. | Confident | `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md`, `guides/introduction/demo-showcase.md` |

## Corrections Made

No corrections — all assumptions confirmed.
