# Phase 143: Playwright Demo Spec & Screenshots - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 143-playwright-demo-spec-screenshots
**Mode:** assumptions
**Areas analyzed:** Demo Spec Structure, Persona Auth Assertions, Screenshot Capture Strategy, Seeds-Smoke Implementation

## Assumptions Presented

### Demo Spec Structure (PW-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `demo-showcase-chromium` project partition via `testMatch`/`testIgnore` regex pattern | Confident | `playwright.config.ts` — identical pattern for `ADMIN_CHECKPOINTS_SPEC`, `ADMIN_GENERATED_SPEC` |
| Global `workers: 1` applies; no per-project override needed | Confident | `playwright.config.ts:41` |

### Persona Auth Assertions (PW-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `data-testid="demo-persona-row-{local}"` for `/demo/credentials` assertions | Confident | `credentials_live.ex` — Phase 142 D-03/D-06 testid contract |
| Structural email-based locators on `#admin-users-desktop-results` for admin pages | Confident | Existing `admin-user-operations.spec.ts`, `admin-audit.spec.ts` helpers |

### Screenshot Capture Strategy (PW-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `toHaveScreenshot` committed under `demo-showcase.spec.ts-snapshots/` | Confident | `admin-checkpoints.spec.ts-snapshots/` has 15 committed PNGs; `artifacts/` is git-ignored |
| Single `demo-showcase-chromium` project; no mobile/dark variants | Likely | PW-02 success criteria specifies evaluator screenshots, not multi-theme coverage |
| Screenshots: `/demo/credentials`, `/admin/users`, `/admin/users/{admin-id}`, `/admin/audit` | Likely | Phase 143 ROADMAP SC#3 + Phase 141 D-10 amendment dropping API-token row |

### Seeds-Smoke Implementation (PW-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| PW-03 already satisfied by `seeds_test.exs` (idempotency + dave/frank auth columns) | Confident | `seeds_test.exs:89` (SEED-01 twice), `:130` (dave.locked_at), `:138` (frank.scheduled_deletion_at) |
| Phase 143 PW-03 work = cross-reference comment only | Confident | `mix test` alias already runs seeds_test.exs in CI; no new test code needed |

## Corrections Made

No corrections — all assumptions confirmed by user.

## External Research

No external research needed — codebase analysis was sufficient for all four areas.
