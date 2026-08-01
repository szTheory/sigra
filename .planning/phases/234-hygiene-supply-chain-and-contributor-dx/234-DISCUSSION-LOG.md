# Phase 234: Hygiene, Supply Chain, and Contributor DX - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md; this log preserves the analysis.

**Date:** 2026-07-31
**Phase:** 234-hygiene-supply-chain-and-contributor-dx
**Mode:** assumptions
**Areas analyzed:** Local Gate Parity, Immutable Dependencies and Update Coverage, Playwright Inventory and SEED-006 Closure, Pending Todo Boundaries

## Assumptions Presented

### Local Gate Parity

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `mix ci` becomes the single local command exercised by a PR lane, including format and locked-dependency validation while retaining existing coverage. | Confident | `mix.exs`; `.github/workflows/ci.yml`; `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` |

### Immutable Dependencies and Update Coverage

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Pin the remaining mutable Release Please action to its dereferenced commit and add Dependabot coverage for root Mix and nested Playwright npm dependencies. | Confident | `.github/workflows/release-please.yml`; `.github/dependabot.yml`; `mix.exs`; `mix.lock`; `test/example/priv/playwright/package.json`; `test/example/priv/playwright/package-lock.json` |

### Playwright Inventory and SEED-006 Closure

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Commit a fail-closed spec-to-lane inventory, resolve the two currently uninvoked specs, and close SEED-006 from current live evidence rather than reopening remediation. | Confident | `test/example/priv/playwright/tests/`; `.github/workflows/ci.yml`; `.github/workflows/playwright-github-pages.yml`; `scripts/ci/`; `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md`; `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md` |

### Pending Todo Boundaries

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Defer all four reviewed todos because each crosses a policy boundary outside DX-01/02/03/04/06. | Likely | Four pending todo files; `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md`; milestone scope guardrails in `.planning/ROADMAP.md` |

## Corrections Made

No corrections. The user explicitly delegated grouping to the researched recommendations and approved following them.

## External Research

- **Release Please v5 pin:** Live tag dereferencing showed annotated `refs/tags/v5` object `0dfd8538845b8e92600d271a895a5372865d4062` targets commit `45996ed1f6d02564a971a2fa1b5860e934307cf7`; `v5.0.0` points directly to that commit. Decision: `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0`. Sources: GitHub Git Data API and the official `googleapis/release-please-action` v5.0.0 release.
- **Dependabot ecosystems:** Official GitHub documentation confirms `package-ecosystem: "mix"` at `/` and `package-ecosystem: "npm"` at `/test/example/priv/playwright`. Offline schema/shape/path checks are useful but not authoritative runtime proof; retain GitHub update-job logs after default-branch processing and an update PR when an update exists.

## Methodology

- **Decisive Defaulting:** Used repo-consistent defaults for command shape, immutable pins, update directories, and inventory behavior.
- **Escalation Threshold:** Kept required-check, canary, release-note, and retry-policy changes outside the phase because they cross separate trust or public-contract boundaries.
- **Research Depth Calibration:** Combined roadmap/requirements, prior phase contexts, source inspection, live receipts, and official GitHub/repository research before locking decisions.
- **Phase Context Expectation:** Captured selected defaults, hard-fail boundaries, and agent discretion without leaving an implementation menu for downstream agents.
