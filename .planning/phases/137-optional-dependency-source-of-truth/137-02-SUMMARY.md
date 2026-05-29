---
phase: 137-optional-dependency-source-of-truth
plan: "02"
subsystem: optional-deps
tags: [refactor, optional-deps, sot, security]
dependency_graph:
  requires: ["137-01"]
  provides: ["OD-02-single-leaf"]
  affects: [lib/sigra/crypto.ex, lib/sigra/hashers/bcrypt.ex, lib/sigra/mfa.ex, lib/sigra/jwt/signer.ex, lib/sigra/plug/rate_limit.ex, lib/sigra/oauth/strategies/apple.ex, lib/sigra/oauth/strategies/facebook.ex, lib/sigra/oauth/strategies/github.ex, lib/sigra/oauth/strategies/generic.ex, lib/sigra/oauth/strategies/google.ex]
tech_stack:
  added: []
  patterns: ["optional-dep SOT delegation via Sigra.OptionalDeps", "byte-preserved branch bodies on guard swap"]
key_files:
  created: []
  modified:
    - lib/sigra/crypto.ex
    - lib/sigra/hashers/bcrypt.ex
    - lib/sigra/mfa.ex
    - lib/sigra/jwt/signer.ex
    - lib/sigra/plug/rate_limit.ex
    - lib/sigra/oauth/strategies/apple.ex
    - lib/sigra/oauth/strategies/facebook.ex
    - lib/sigra/oauth/strategies/github.ex
    - lib/sigra/oauth/strategies/generic.ex
    - lib/sigra/oauth/strategies/google.ex
decisions:
  - "Guard token swap only — every branch body, raise block, and else-clause preserved byte-for-byte as the OD-02 no-behavior-change proof"
  - "Timing-protection else-branch in crypto.ex and hashers/bcrypt.ex preserved verbatim (T-137-03 ASVS V2/timing)"
  - "All 5 Assent raise-guards follow identical unless/raise pattern; all 5 delegated identically"
metrics:
  duration: "~8 minutes"
  completed: "2026-05-29"
  tasks_completed: 2
  files_changed: 10
  guards_delegated: 11
---

# Phase 137 Plan 02: Delegate Single-Leaf Optional-Dep Guards to SOT Summary

Mechanical token-swap of all 11 single-leaf `Code.ensure_loaded?/1` runtime guards across 10 files to `Sigra.OptionalDeps.<dep>_available?()`, completing OD-02 for the Bucket A subset. Branch bodies, raise blocks, timing-protection else-clauses, and Noop fallbacks are byte-preserved — that invariance is the behavioral no-change proof.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Delegate Bcrypt + EQRCode guards (crypto, hashers/bcrypt, mfa) | 14f7180 | lib/sigra/crypto.ex, lib/sigra/hashers/bcrypt.ex, lib/sigra/mfa.ex |
| 2 | Delegate Joken, Hammer, and 5 Assent raise/resolve guards | a945a9b | lib/sigra/jwt/signer.ex, lib/sigra/plug/rate_limit.ex, lib/sigra/oauth/strategies/{apple,facebook,github,generic,google}.ex |

## Guard Delegation Table

| File | Line | Old Guard | New Guard | Dep |
|------|------|-----------|-----------|-----|
| lib/sigra/crypto.ex | 244 | `Code.ensure_loaded?(Bcrypt)` | `Sigra.OptionalDeps.bcrypt_available?()` | Bcrypt |
| lib/sigra/hashers/bcrypt.ex | 39 | `Code.ensure_loaded?(Bcrypt)` | `Sigra.OptionalDeps.bcrypt_available?()` | Bcrypt |
| lib/sigra/hashers/bcrypt.ex | 48 | `Code.ensure_loaded?(Bcrypt)` | `Sigra.OptionalDeps.bcrypt_available?()` | Bcrypt |
| lib/sigra/mfa.ex | 1059 | `Code.ensure_loaded?(EQRCode)` | `Sigra.OptionalDeps.eqrcode_available?()` | EQRCode |
| lib/sigra/jwt/signer.ex | 18 | `Code.ensure_loaded?(Joken)` | `Sigra.OptionalDeps.joken_available?()` | Joken |
| lib/sigra/plug/rate_limit.ex | 85 | `Code.ensure_loaded?(Hammer)` | `Sigra.OptionalDeps.hammer_available?()` | Hammer |
| lib/sigra/oauth/strategies/apple.ex | 76 | `Code.ensure_loaded?(Assent)` | `Sigra.OptionalDeps.assent_available?()` | Assent |
| lib/sigra/oauth/strategies/facebook.ex | 80 | `Code.ensure_loaded?(Assent)` | `Sigra.OptionalDeps.assent_available?()` | Assent |
| lib/sigra/oauth/strategies/github.ex | 77 | `Code.ensure_loaded?(Assent)` | `Sigra.OptionalDeps.assent_available?()` | Assent |
| lib/sigra/oauth/strategies/generic.ex | 83 | `Code.ensure_loaded?(Assent)` | `Sigra.OptionalDeps.assent_available?()` | Assent |
| lib/sigra/oauth/strategies/google.ex | 74 | `Code.ensure_loaded?(Assent)` | `Sigra.OptionalDeps.assent_available?()` | Assent |

## Verification Results

- `git grep -n "Code.ensure_loaded?" lib/sigra/crypto.ex lib/sigra/hashers/bcrypt.ex lib/sigra/mfa.ex lib/sigra/jwt/signer.ex lib/sigra/plug/rate_limit.ex lib/sigra/oauth/strategies/*.ex` — returns NOTHING (all 11 guards delegated)
- `mix test test/sigra/crypto_test.exs` — 24 tests, 0 failures
- `mix test test/sigra/plug/rate_limit_test.exs` — 16 tests, 0 failures
- `mix compile --warnings-as-errors` — exits 0 (no new `no_warn_undefined` entry)

## Deviations from Plan

None — plan executed exactly as written. The two Bcrypt "drift sites" in hashers/bcrypt.ex were identified in the plan as "DRIFT site not in CONTEXT.md — in scope per RESEARCH Bucket A" and were included and delegated.

## Known Stubs

None.

## Threat Flags

None — pure delegation refactor, no new external input or trust boundary changes. Timing-protection else-branches (T-137-03) and raise-guards (T-137-04) verified byte-preserved.

## Self-Check: PASSED

- lib/sigra/crypto.ex: FOUND (contains `Sigra.OptionalDeps.bcrypt_available?()`)
- lib/sigra/hashers/bcrypt.ex: FOUND (contains `Sigra.OptionalDeps.bcrypt_available?()` twice)
- lib/sigra/mfa.ex: FOUND (contains `Sigra.OptionalDeps.eqrcode_available?()`)
- lib/sigra/jwt/signer.ex: FOUND (contains `Sigra.OptionalDeps.joken_available?()`)
- lib/sigra/plug/rate_limit.ex: FOUND (contains `Sigra.OptionalDeps.hammer_available?()`)
- lib/sigra/oauth/strategies/apple.ex: FOUND (contains `Sigra.OptionalDeps.assent_available?()`)
- lib/sigra/oauth/strategies/facebook.ex: FOUND (contains `Sigra.OptionalDeps.assent_available?()`)
- lib/sigra/oauth/strategies/github.ex: FOUND (contains `Sigra.OptionalDeps.assent_available?()`)
- lib/sigra/oauth/strategies/generic.ex: FOUND (contains `Sigra.OptionalDeps.assent_available?()`)
- lib/sigra/oauth/strategies/google.ex: FOUND (contains `Sigra.OptionalDeps.assent_available?()`)
- Commit 14f7180: FOUND
- Commit a945a9b: FOUND
