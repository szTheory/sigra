# Phase 232: Playwright Economics — Authenticate Once, Then Shard - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-31
**Phase:** 232-playwright-economics-authenticate-once-then-shard
**Mode:** assumptions
**Areas analyzed:** Authentication Reuse and Measurement, Parallelization and Isolation Boundary,
Required Context and Shared Boot Prelude, Auth-Schema Prefix Todo Scope

## Assumptions Presented

### Authentication Reuse and Measurement

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Add one explicit setup dependency per design project, each with a unique policy-valid admin identity and its own `storageState`; retain only navigation and deterministic readiness in per-test setup. | Likely | `test/example/priv/playwright/playwright.config.ts`; `test/example/priv/playwright/tests/admin-design.spec.ts`; `test/example/lib/example/sigra_admin_policy.ex` |

### Parallelization and Isolation Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Parallelize independent Playwright seams as CI matrix shards with isolated PostgreSQL/database/app ownership; do not unlock shared-state workers directly. | Confident | `test/example/priv/playwright/playwright.config.ts`; `.github/workflows/ci.yml`; `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` |

### Required Context and Shared Boot Prelude

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Put shards behind a terminal aggregator named exactly `Example Playwright smoke (full lifecycle)` and replace duplicated boot logic with one reusable workflow-level definition. | Likely | `MAINTAINING.md`; `.planning/ROADMAP.md`; `.github/workflows/ci.yml`; `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` |

### Auth-Schema Prefix Todo Scope

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Resolve shard isolation with separate databases and reject a production runtime auth-schema override from this phase. | Confident | `test/example/lib/example/accounts/user.ex`; `test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs`; `lib/mix/tasks/sigra.install.ex`; `lib/sigra/branding.ex`; `.planning/todos/pending/2026-06-20-runtime-auth-prefix-override.md` |

## Methodology Applied

- **Decisive Defaulting:** Selected storage-state setup followed by database/app-isolated matrix
  shards; ruled out a config-only worker increase.
- **Escalation Threshold:** Identified a runtime auth-schema override as a generated-host/public
  contract change and avoided that expansion.
- **Research Depth Calibration:** Preserved separate PW-01 and PW-02 measurement receipts and
  required retry-free execution proof.
- **User Experience Bias:** Preserved deterministic admin selectors, hooks, LiveView/font
  readiness, and the no-sleeps test posture.

## Folded Todos

- `2026-06-20-playwright-parallelization-per-shard-db.md` — folded as the PW-02 isolation shape.
- `2026-06-20-runtime-auth-prefix-override.md` — folded for explicit evaluation; rejected as the
  isolation mechanism because separate databases satisfy PW-02 without expanding the runtime
  generated-host contract.

## Corrections Made

No corrections — all assumptions confirmed.
