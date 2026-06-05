# Phase 145: 1.0 Contract And Release Truth - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md -- this log preserves the analysis.

**Date:** 2026-05-31
**Phase:** 145-1-0-contract-and-release-truth
**Mode:** assumptions
**Areas analyzed:** Release Source Of Truth, Public Version-Axis Messaging, Single 1.0 Contract Surface, Release Please 1.0 Jump, Ownership Boundaries, Security Invariants And Non-Goals

## Assumptions Presented

### Release Source Of Truth

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 145 should treat `mix.exs` as the canonical version source and align all release artifacts to a direct Hex `1.0.0` cut from `main` (no default public RC lane). | Confident | `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/research/SUMMARY.md`, `mix.exs`, `.release-please-manifest.json`, `release-please-config.json`, `MAINTAINING.md`, `docs/NEXT-STEPS-MANUAL.md` |

### Public Version-Axis Messaging

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The public contract must explicitly and prominently explain the two axes (planning milestones vs installable Hex SemVer) in top-level docs, not only in maintainer/internal text. | Likely | `CHANGELOG.md`, `README.md`, `MAINTAINING.md` |

### Single 1.0 Contract Surface

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 145 should define one canonical "1.0 contract" surface covering Elixir/OTP/Phoenix/Ecto/Postgres support and optional-dependency posture, then link to detail docs. | Likely | `mix.exs`, `README.md`, `lib/sigra/optional_deps.ex`, `lib/sigra/doctor.ex`, `lib/mix/tasks/sigra.doctor.ex`, `MAINTAINING.md`, `.planning/REQUIREMENTS.md` |

### Release Please 1.0 Jump

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep existing pre-1.0 bump settings for normal pre-1.0 behavior, but use explicit `release-as: "1.0.0"` for the one-time 1.0 Release PR and remove/update it after merge. | Likely | `release-please-config.json`, `.release-please-manifest.json`, Release Please manifest docs |

### Ownership Boundaries

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The 1.0 contract should preserve the existing hybrid model and explicitly separate library-owned core, generated-host-owned code, and shared seam integrations. | Confident | `README.md`, `lib/sigra.ex`, `mix.exs`, `guides/introduction/suite-integration.md`, `guides/flows/account-lifecycle.md`, `guides/recipes/companion-oauth-provider.md`, `.planning/REQUIREMENTS.md` |

### Security Invariants And Non-Goals

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 145 should add/standardize a top-level security invariants + non-goals table that states what Sigra guarantees versus what remains host responsibility. | Likely | `README.md`, `SECURITY.md`, `docs/uat-ci-coverage.md`, `guides/flows/audit-logging.md`, `guides/introduction/suite-integration.md`, `MAINTAINING.md`, `.planning/REQUIREMENTS.md` |

## Corrections Made

No corrections -- all assumptions confirmed.

## External Research

- Elixir/OTP support: Elixir 1.18 supports OTP 25-27, with OTP 28 support from Elixir 1.18.4. Source: https://hexdocs.pm/elixir/1.18.4/compatibility-and-deprecations.html
- Phoenix baseline: Phoenix 1.8 declares Elixir `~> 1.15`, but Sigra's own `mix.exs` currently raises the package contract to Elixir `~> 1.18`. Source: https://raw.githubusercontent.com/phoenixframework/phoenix/v1.8.1/mix.exs
- PostgreSQL range: Postgrex supports PostgreSQL 8.4, 9.0-9.6, and later, but Sigra should state its own tested/supported Postgres posture. Source: https://raw.githubusercontent.com/elixir-ecto/postgrex/master/README.md
- Release Please one-time jump: Release Please manifest docs support `release-as` for manually setting the next version and warn to remove or update it after the release PR merges. Source: https://raw.githubusercontent.com/googleapis/release-please/main/docs/manifest-releaser.md
