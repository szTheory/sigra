# Phase 137: Optional-Dependency Source of Truth - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-29
**Phase:** 137-optional-dependency-source-of-truth
**Mode:** assumptions (calibration: minimal_decisive)
**Areas analyzed:** Module API shape; Compile-time vs runtime guard treatment; Scope boundary & compound guards

## Assumptions Presented

### Module API shape
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Per-dep zero-arity predicates (`oban_available?/0` …) wrapping `Code.ensure_loaded?`; module at `lib/sigra/optional_deps.ex` sibling to `rate_limiter.ex`; NOT a `available?(dep_atom)` dispatcher; un-memoized | Confident | OD-01 text; `crypto.ex:244`, `mfa.ex:1059`, `jwt/signer.ex:18`, `plug/rate_limit.ex:85`, `oauth/strategies/*.ex`; `rate_limiter.ex` triad |

### Compile-time vs runtime guard treatment
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `defmodule`-wrapping guards stay literal `Code.ensure_loaded?` and do NOT delegate; only runtime in-body guards delegate; SC#2 scoped to runtime guards | Confident | `workers/*.ex:1`, `audit/forwarders/threadline.ex:1`; compile-ordering hazard; `audit/forwarders.ex:133-137` `apply/3`+`no_warn_undefined` (D-18) precedent |

### Scope boundary & compound guards
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Compound guards delegate load-half only (liveness/arity stays at call site); encryption gets NO `cloak_available?/0` (mirror `__sigra_encryption_mode__/0` stub check instead); variable/Credo/test-helper guards out of scope; ≈14 in-scope sites; `no_warn_undefined` unchanged | Confident | `delivery.ex:110-115`, `forwarders.ex:80-101`, `validation.ex:91`, `account/deletion.ex:307-308`; `application.ex:185-206` `verify_vault!`; `mix.exs:65-91` |

## Corrections Made

No corrections — all three assumptions confirmed as presented ("Yes, proceed").

## External Research

None performed — the analyzer flagged no external-research gaps. This is a pure internal
refactor of existing Elixir `Code.ensure_loaded?` patterns, fully grounded by the codebase.
Confirmed: `Code.ensure_loaded?/1` inside the SOT generates no compile warnings, so no
`mix.exs:65-91` `no_warn_undefined` changes.
