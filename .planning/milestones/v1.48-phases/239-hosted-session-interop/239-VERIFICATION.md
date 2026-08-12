---
phase: 239-hosted-session-interop
verified: 2026-08-10T00:52:10Z
status: passed
score: 14/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 239: Hosted Session Interop Verification Report

**Phase Goal:** Prove the fail-closed SIGRA-to-Crosswake backend-session boundary for personal accounts.
**Verified:** 2026-08-10T00:52:10Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A personal SIGRA session projects to Crosswake without organization authority or credentials/tokens. | ✓ VERIFIED | Database-backed adapter test passes; it asserts `org_id == nil`, HMAC-derived refs distinct from cookie, IDs, and digest, and no credential/provider fields. |
| 2 | Missing, expired, revoked, and account-switched state fails closed; hosted-return data alone grants no authority. | ✓ VERIFIED | The 14-test adapter matrix exercises deletion, missing subject, inactive type, exact idle/absolute boundaries, binding drift, account/session switch, and valid evidence with invalid host state; each denial asserts evaluator non-invocation. |
| 3 | The consumed Crosswake release is one immutable public release. | ✓ VERIFIED | Public tag `crosswake_sigra-v0.1.3` resolves to `70edb8077894fd09d4376591782b511c9d8be664`; the local lock and proof agree on Hex checksum `0c6243…feb8b`. |
| 4 | Exact-SHA Crosswake contract, AuthReturn, and package tests pass. | ✓ VERIFIED | Fresh detached clone at that SHA passed the required formatter check, 15 contract tests, 9 AuthReturn-boundary tests, and 139 complete package tests. |
| 5 | Machine proof is structurally complete and is not accepted merely as maintainer prose. | ✓ VERIFIED | `239-CROSSWAKE-RELEASE-PROOF.json` has the required schema, exact ordered four commands, zero numeric statuses, and `passed` outcomes; the phase contract test validates the same fields. |
| 6 | Personal `org_id: nil` is accepted while blank organization authority is rejected. | ✓ VERIFIED | Adapter and released Crosswake contract test pass with `nil` and nonblank `org_123`, and reject whitespace-only `org_id`. |
| 7 | Each evaluation re-resolves current host storage instead of trusting serialized scope. | ✓ VERIFIED | Adapter calls `Accounts.get_user_and_session_by_token/1` before currentness, binding comparison, lane construction, and evaluator invocation; the real-Ecto replay tests pass. |
| 8 | SIGRA confines `crosswake_sigra` to the example proof host. | ✓ VERIFIED | `test/example/mix.exs` declares `~> 0.1.3`; root `mix.exs` has no Crosswake dependency, enforced by the phase contract test. |
| 9 | Stale version, subject/session mismatch, and account switching deny before evaluation. | ✓ VERIFIED | Binding tests mutate each tuple member and replay distinct user/session cookies; expected categorical denial and `refute_receive :crosswake_evaluator_called` pass. |
| 10 | AuthReturn is evidence-only and authority/credential-smuggling claims are rejected. | ✓ VERIFIED | `evaluate_return/6` first calls the released constructor then the unchanged host evaluation path; tests reject session, subject, org, authority, token, digest, provider, and authorization-code claims. |
| 11 | Consumer instructions preserve the released personal-session boundary. | ✓ VERIFIED | `guides/recipes/b2c-alpha.md` names `crosswake_sigra ~> 0.1.3`, `org_id: nil`, opaque server-owned refs, fresh resolution, and evidence-only handling; its assertions pass in the adapter suite. |
| 12 | One bounded local command composes the release/scope contract and complete database-backed proof. | ✓ VERIFIED | Executable `scripts/ci/hosted-session-interop-proof.sh` uses `set -euo pipefail`, per-command alarm bounds, the source contract, and complete adapter suite; `bash -n` and ShellCheck pass. |
| 13 | The final receipt is exact-SHA, internally consistent, and preserves unresolved planning classifications rather than calling them passed. | ✓ VERIFIED | `239-INTEROP-EVIDENCE.json` records SIGRA SHA, release coordinates, three local commands, all D-01–D-06/XW assertions, and explicit unresolved/unverified disposition arrays. |
| 14 | The receipt’s Wave 0 proof digest matches the actual proof artifact. | ✓ VERIFIED | Both calculated and recorded SHA-256 values are `4c12808426d29e6871e165198bcaede2205d32213f2505e9917ad3e475a3fcff`. |

**Score:** 14/14 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json` | Immutable release and command proof | ✓ VERIFIED | Schema, coordinates, exact command order, outcomes, and digest independently checked. |
| `.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json` | Normalized release receipt | ✓ VERIFIED | Every release coordinate equals the Wave 0 proof. |
| `test/example/lib/example/accounts/crosswake_session_adapter.ex` | Fresh host authority boundary | ✓ VERIFIED | Substantive implementation with lookup, currentness, opaque binding, fact-only projection, and evidence-only return path. |
| `test/example/test/example/accounts/crosswake_session_adapter_test.exs` | Real-row fail-closed matrix | ✓ VERIFIED | 14 executable tests pass against configured PostgreSQL. |
| `guides/recipes/b2c-alpha.md` | Consumer contract | ✓ VERIFIED | Released dependency and boundary semantics are present and test-asserted. |
| `scripts/ci/hosted-session-interop-proof.sh` | Bounded proof runner | ✓ VERIFIED | Executable, syntax/ShellCheck clean, failure-propagating, receipt written last. |
| `test/sigra/planning/phase_239_hosted_session_interop_test.exs` | Fast release/scope contract | ✓ VERIFIED | 4 tests pass. |
| `.planning/phases/239-hosted-session-interop/239-INTEROP-EVIDENCE.json` | Exact-SHA seal | ✓ VERIFIED | Valid JSON with matching Wave 0 digest and honest unresolved dispositions. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Release proof | Public Crosswake tag/package | tag, SHA, release metadata | ✓ WIRED | Live Git tag equals the recorded SHA; lockfile checksum equals the recorded checksum. |
| Normalized release receipt | Example dependency and guide | `~> 0.1.3` requirement | ✓ WIRED | Phase contract test proves receipt, `test/example/mix.exs`, and guide alignment. |
| Adapter | SIGRA session store | `Accounts.get_user_and_session_by_token/1` | ✓ WIRED | Fresh raw-cookie lookup feeds each evaluation; Ecto tests demonstrate missing/deleted rows deny. |
| Adapter | Crosswake Contracts/Evaluator | fact-only lane/context then evaluator | ✓ WIRED | `new_session_authority_lane`, `new_auth_context`, and evaluator call occur only after host validation/binding. |
| Adapter | AuthReturn | public `AuthReturn.new_envelope/1` | ✓ WIRED | Valid envelope is emitted only as `result.evidence`; invalid/smuggled envelopes deny before evaluator use. |
| Proof runner | Adapter suite | bounded `mix test` call | ✓ WIRED | Runner invokes the complete adapter test file after its fast contract. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `crosswake_session_adapter.ex` | `{user, session}` / `ExpectedBinding` | Raw cookie → `Accounts.get_user_and_session_by_token/1` → Ecto session/user store | Yes; fixtures create persisted hashed-token sessions and tests delete/mutate real rows | ✓ FLOWING |
| `crosswake_session_adapter.ex` | Crosswake lane/context | Fresh binding plus server session timestamps/version | Yes; evaluator capture test observes the original route and expected version | ✓ FLOWING |
| `evaluate_return/6` | `result.evidence` | Released `AuthReturn.new_envelope/1` | Yes; valid envelope produces evidence only after host authority permits evaluation | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| SIGRA release/scope contract | `MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs` | 4 tests, 0 failures | ✓ PASS |
| Fail-closed host boundary | `source tmp/db.env && cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs` | 14 tests, 0 failures | ✓ PASS |
| External immutable release | clean clone at `70ed…e664`, exact four documented commands | 15 contract + 9 AuthReturn + 139 full-suite tests, all passing | ✓ PASS |
| Runner static integrity | `bash -n` and `shellcheck -x scripts/ci/hosted-session-interop-proof.sh` | both exit 0 | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| XW-01 | 239-00 through 239-06 | Personal backend session projects without organization invention or credential exposure. | ✓ SATISFIED | Nil-org projection, opaque-reference/secret-negative checks, released contract replay, guide, and proof all pass. |
| XW-02 | 239-00 through 239-06 | Missing, expired, revoked, switched, or return-only state fails closed. | ✓ SATISFIED | Real-storage denial matrix, evaluator non-invocation, binding mismatch, and evidence-only tests all pass. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `.planning/phases/239-hosted-session-interop/239-VALIDATION.md` | frontmatter / task table | Stale initial planning status (`draft`, pending Wave 0 rows) | ℹ️ Info | Not consumed by the proof runner or the final receipt; it does not contradict the independently rerun evidence. |

## Gaps Summary

No blocking gaps found. The three descriptor-less planning prohibitions remain honestly labeled `unverified` in the historical receipt, but their concrete boundary behaviors are independently exercised by the passing release and adapter tests; they are not silent passes or human-only claims.

---

_Verified: 2026-08-10T00:52:10Z_
_Verifier: the agent (gsd-verifier)_
