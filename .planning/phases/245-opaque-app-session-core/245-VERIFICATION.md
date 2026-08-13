---
phase: 245-opaque-app-session-core
verified: 2026-08-13T01:16:13Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/4
  gaps_closed:
    - "Phase 245 formatter gate for lib/sigra/config.ex, test/sigra/app_session_security_event_test.exs, and test/sigra/auth_test.exs."
  gaps_remaining: []
  regressions: []
---

# Phase 245: Opaque App-Session Core Verification Report

**Phase Goal:** First-party apps can hold opaque, rotating credentials whose lifecycle is bounded and reliably revocable.
**Verified:** 2026-08-13T01:16:13Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A first-party app receives only digest-backed opaque credentials with 15-minute access, 30-day refresh-idle, and 90-day absolute defaults. | ✓ VERIFIED | `Sigra.AppSession.issue/4` stores the 32-byte `Sigra.Token` digests in separate access/refresh rows and returns raw values only after `Repo.transaction/1` succeeds. `Sigra.Config.validate_app_session/1` fixes 900/2,592,000/7,776,000 defaults and ordering. PostgreSQL test `issues digest-only opaque credentials…` passed. |
| 2 | Refreshing is atomic, rotates every use, and reuse of a consumed refresh revokes its session family. | ✓ VERIFIED | `RefreshToken.locked_refresh/3` performs digest-bound `FOR UPDATE`; the one `Ecto.Multi` consumes, supersedes, inserts the pair, and optionally audits. PostgreSQL audit-on/off, rollback, and ready/go two-caller tests passed: exactly one rotation and one `:reuse_detected`, then no usable family credential. |
| 3 | A user can revoke one app session or all applicable sessions, and revoked credentials fail on their next authentication attempt. | ✓ VERIFIED | Owner-bound locked family query plus user-wide locked update revoke family/token rows. PostgreSQL tests prove foreign/missing selectors do not mutate another account; both access and refresh fail after one/all revoke. |
| 4 | Password reset, account deletion, sign-out-all, explicit device revocation, and refresh reuse invalidate applicable app sessions on subsequent authentication. | ✓ VERIFIED | Reset and deletion compose `append_revoke_all_multi/4` before their outer transaction commits; sign-out-all fails closed before browser deletion; explicit revoke and reuse invoke durable family revocation. PostgreSQL tests prove next-auth denial, rollback co-fate, owner isolation, and soft/anonymize/hard-delete persistence. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/app_session.ex` | Issue, authenticate, refresh, owner and all-user revocation facade | ✓ VERIFIED | 436 substantive lines; database transaction, state checks, audit composition, and public operations are exercised by PostgreSQL tests. |
| `lib/sigra/app_session/refresh_token.ex` | Locked refresh classification/mutation builders | ✓ VERIFIED | 172 substantive lines; locks by digest, retains family absolute expiry, and writes terminal fields/new rows rather than replacing a digest. |
| `lib/sigra/config.ex` | App-session config/TTL contract | ✓ VERIFIED | Validated paired schema seam and exact defaults are in the runtime config struct; configuration and lifecycle tests exercise it. |
| `lib/sigra/plug/fetch_app_session.ex` / `credential_auth.ex` | Explicit app access pipeline and bounded facts | ✓ VERIFIED | The only accepted transport is one Bearer value; it calls `AppSession.authenticate/2`, reloads the user, builds normal Scope, and projects an allowlisted fact map. |
| `lib/sigra/auth.ex` / `lib/sigra/account/deletion.ex` | Security-event fanout | ✓ VERIFIED | Reset/deletion use caller-owned `Ecto.Multi`; sign-out uses the durable all-family API before browser removal. |
| PostgreSQL test schemas and lifecycle suites | Real persistence, rollback, audit and concurrency evidence | ✓ VERIFIED | Six app-session suites ran against `tmp/db.env`; no test stubs or timing sleeps found. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `AppSession` | configured host schemas | `config.app_session` settings | ✓ WIRED | Runtime settings supply `family_schema`, `token_schema`, and TTLs; tests pass representative host Ecto schemas through `Sigra.Config`. |
| `FetchAppSession` | `AppSession.authenticate/2` | explicit Bearer pipeline | ✓ WIRED | Direct call followed by live-user lookup and `CredentialAuth.put_verified_scope/5`; valid/invalid/revoked/deleted user branches passed. |
| `AppSession` | `RefreshToken` | locked classification then same-Multi mutation | ✓ WIRED | `build_locked_classify_multi/3` precedes `Multi.merge/2`; real two-client test proves serial outcome. |
| `AppSession` | `Audit.log_multi_safe/3` | audit step before transaction result | ✓ WIRED | Audit-on/off/rejected-audit tests show co-fate; telemetry occurs only after success. |
| reset/deletion/sign-out | next app authentication | durable `family.revoked_at` and token terminal state | ✓ WIRED | Public `authenticate/2` checks both row and family state; named PostgreSQL security-event/deletion tests exercise denial. |

The generic key-link helper reported two false negatives: Plan 01 asks for the literal string `config.app_session` although the Elixir struct is accessed as `%{app_session: app_session}`, and Plan 06 gives a prose component name instead of a source path. Direct source tracing and executed end-to-end tests above verify both links.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `AppSession.issue/4` | family and typed credential rows | host schema structs → `Ecto.Multi` → PostgreSQL | UUID family/FK rows and SHA-256 digests asserted in PostgreSQL | ✓ FLOWING |
| `AppSession.authenticate/2` | bounded identity/family/token facts | digest lookup + family state + live configured user | Valid access yields actual host user/Scope; stale/deleted values fail | ✓ FLOWING |
| `FetchAppSession` | `current_scope`, `:sigra_auth` | verified facts + configured repo user lookup | Plug test asserts normal Scope and exact bounded private fields | ✓ FLOWING |
| security events | family/token terminal state | surrounding reset/deletion Multi or sign-out revocation | rollback and next-auth checks use persisted rows | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Issue/authenticate, refresh/reuse, audit co-fate, concurrency, plug, reset, sign-out and deletion | `source tmp/db.env && MIX_ENV=test mix test` over the six app-session suites | 25 tests, 0 failures | ✓ PASS |
| Full Phase 245 focused compatibility gate including browser/PAT/JWT/session/deletion suites | `source tmp/db.env && MIX_ENV=test mix test … --trace` | 168 tests, 0 failures | ✓ PASS |
| Exact formatter closure gate | `mix format --check-formatted lib/sigra/config.ex test/sigra/app_session_security_event_test.exs test/sigra/auth_test.exs` | Exit 0 | ✓ PASS |
| Repository diagnostic | `source tmp/db.env && MIX_ENV=test mix ci` | Exit 1 in full ExUnit; no Phase 245 file/test failure | ℹ️ EXTERNAL FAILURES |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APP-04 | 01, 03, 04 | Digest-only bounded credentials, atomic every-use rotation, consumed-refresh family revoke | ✓ SATISFIED | PostgreSQL issue/expiry/rotation/reuse/audit/concurrency tests pass. |
| APP-05 | 02, 05, 06, 07 | Owner revocation plus reset/deletion/sign-out/reuse next-auth denial | ✓ SATISFIED | Explicit Plug and PostgreSQL owner/security-event/deletion tests pass. |

No APP-04 or APP-05 requirement is orphaned from the phase plans. Phase 246-only generators, emitted migrations/schemas/config/delegates, login ceremonies, and app-session PKCE/direct-password paths are absent from Phase 245's commit file set; the installer/template scan found no app-session generator artifact.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/sigra/auth_test.exs` | 1224 | compiler warning: unused default argument | ⚠️ Warning | Existing test-quality warning surfaced in compatibility run; no failing lifecycle assertion. |

No unreferenced `TBD`, `FIXME`, or `XXX`, empty production implementation, hardcoded successful empty data path, raw-token audit output, or sleep-based concurrency control was found in Phase 245 artifacts.

## Re-verification and Repository CI Attribution

Commit `45a2c15b` changes only formatter layout in the three previously blocked files; `14f0d503` records the closure artifacts. The exact formatter command now exits 0, and the expanded focused PostgreSQL/compatibility gate passes 168 tests with no regressions.

The verifier independently reran `source tmp/db.env && MIX_ENV=test mix ci`. It now passes the formatter stage and enters the full ExUnit suite, but exits 1 on pre-existing cross-phase failures: Phase 234 missing Playwright inventory/evidence, Phase 236 traceability and the user-owned dirty `.planning/config.json` scope-fence input, Phase 240/240.3 missing artifacts, architecture-guide source drift already reported by Phase 244, and Phase 244 generated-host dependency/runtime setup failure. No failure names a Phase 245 artifact or APP-04/APP-05 behavior. The architecture-guide report predates the formatter closure and `45a2c15b` leaves the cited `Config.defstruct` at the same line; it is not caused by its validator-only formatting diff.

Those repository failures remain non-green and are not waived as CI evidence. They are not actionable Phase 245 gaps, so the four roadmap truths and all phase-owned quality gates are verified.

---

_Verified: 2026-08-13T01:16:13Z_
_Verifier: the agent (gsd-verifier)_
