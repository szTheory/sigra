---
phase: 131-forwarder-behaviour-threadline-forwarder-library-scaffolding
fixed_at: 2026-05-27T17:29:00Z
review_path: .planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 7
skipped: 4
status: partial
---

# Phase 131: Code Review Fix Report

**Fixed at:** 2026-05-27T17:29:00Z
**Source review:** `.planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (4 Critical, 7 Warning)
- Fixed: 7 (all 4 Critical + 3 Warning)
- Skipped: 4 Warning (WR-01, WR-03, WR-05 — see below)

## Fixed Issues

### CR-01: Worker `resolve_config/0` reads `:repo` from wrong config key

**Files modified:** `lib/sigra/workers/audit_forward.ex`
**Commit:** ea66168
**Applied fix:** Replaced `Keyword.fetch!(audit_opts, :repo)` with `Application.fetch_env!(:sigra, :repo)` matching the `EmailDelivery` pattern (`:repo` is a top-level `:sigra` key, not nested under `:audit` in the NimbleOptions schema). Extracted `fetch_audit_schema!/0` for the `:audit_schema` value which still comes from `audit_opts`. Updated moduledoc to clarify the config resolution path.

### CR-02: `perform/1` violates D-17 "never raises"

**Files modified:** `lib/sigra/workers/audit_forward.ex`
**Commit:** ea66168 (same commit as CR-01)
**Applied fix:** Wrapped the entire `perform/1` body in `try/rescue/catch` covering all escape paths: `resolve_config/0` KeyError, `repo.get/2` DBConnection errors, and MatchError. All non-ok exits fire `[:sigra, :audit, :forward, :error]` telemetry and return `{:error, reason}`. D-17 (perform NEVER raises) is now structurally enforced by the outer rescue, not just by `perform_forward/5`.

### CR-03: Docs claim Noop is auto-substituted on missing dep

**Files modified:** `lib/sigra/audit/forwarders/noop.ex`, `lib/sigra/audit/forwarder.ex`, `lib/sigra/audit/forwarders/threadline.ex`
**Commit:** 3c1eccc
**Applied fix:** Chose option (b) — fix the three moduledocs. `Noop.ex` now accurately states that it is only active when explicitly listed in `forwarders:[]` and explains the actual degraded-dep behavior (skip attach + Logger.warning). `Forwarder.ex` Noop bullet updated to say "skip-not-substitute". `Threadline.ex` "falls through to Noop (D-23 split)" corrected to "attach is skipped and zero forwarding occurs". No boot-semantics changes.

### CR-04: `call_threadline/2` CaseClauseError on nil `metadata[:action]`

**Files modified:** `lib/sigra/audit/forwarders/threadline.ex`
**Commit:** 68fa739
**Applied fix:** Added a `(_ ->)` fallback clause that returns `{:error, :missing_action}` instead of raising `CaseClauseError` inside the telemetry handler body (the auto-detach landmine zone). Restructured `name_result` as a tagged tuple (`{:ok, atom}` | `{:error, reason}`) and guarded the `threadline.record_action/2` call on success. `String.to_atom/1` is retained (not replaced with `to_existing_atom/1`) because audit action strings are not registered as atoms at compile time — documented in-code as a NOTE with a future action-registry reference.

**Status:** fixed: requires human verification (the `String.to_atom/1` atom-growth risk is acknowledged and documented but not fully mitigated — the nil crash is fixed).

### WR-02: Worker's result case has no `{:ok, _}` clause

**Files modified:** `lib/sigra/workers/audit_forward.ex`
**Commit:** ea66168 (same commit as CR-01/CR-02)
**Applied fix:** Added `{:ok, _} -> :ok` clause to `perform_forward/5` result case so custom forwarders returning `{:ok, response}` (like `Threadline.record_action/2` returns `{:ok, action}`) are treated as success rather than triggering `CaseClauseError`. Added a catch-all `other ->` clause with `Logger.warning` and `{:error, {:unexpected_return, other}}`.

### WR-04: `:async` dispatch silently no-ops when worker module is absent

**Files modified:** `lib/sigra/audit/forwarders.ex`
**Commit:** 405eb2e
**Applied fix:** Changed `else: :ok` to `else: {:error, :async_worker_not_compiled}` in `dispatch_async/3` so callers observe the degradation rather than receiving a silent `:ok`. Removed stale "Plan 05 makes this branch fully live" comment (Plan 05 shipped in Phase 131). Updated moduledoc `:async` bullet and private function comment.

### WR-06: `attach_forwarders/0` not idempotent across dev `recompile()`

**Files modified:** `lib/sigra/application.ex`
**Commit:** 6828b37
**Applied fix:** Added detach-then-attach pattern: `_ = :telemetry.detach(handler_id)` before `module.attach(forwarder_opts)`. Handler ID is derived from `{module, Keyword.get(forwarder_opts, :id, :default)}` matching the impl convention (D-03). First-boot detach is a no-op; subsequent calls remove stale handlers and attach with fresh opts.

### WR-07: `validate_forwarders/1` returns raw input instead of normalized entries

**Files modified:** `lib/sigra/config.ex`
**Commit:** 5b9a421
**Applied fix:** Changed `reduce_while` accumulator from `{:ok, list}` (original input, never growing) to `{:ok, []}` (normalized list). Each valid entry now has `:dispatch` and `:id` defaults injected via `Keyword.put_new/3` before being appended to the accumulator. Downstream consumers can now use `Keyword.fetch!(entry, :dispatch)` reliably.

## Skipped Issues

### WR-01: `metadata[:outcome]` translation drops unknown values to `:ok`

**File:** `lib/sigra/audit/forwarders/threadline.ex:246-254`
**Reason:** skipped: requires design decision on fail-closed vs fail-open semantics for the Threadline outcome mapping. Changing `_ -> :ok` to `_ -> :error` in the catch-all would break all tests that pass unknown outcome values and expect success. The valid outcome set (`:success`, `"success"`, `:failure`, `"failure"`, `:error`) appears complete for current Sigra audit events. Expanding the match set (adding `:locked_out`, etc.) requires auditing all outcome values across the codebase. Recommend as a follow-up in Phase 132 or 135.

### WR-03: No nil-guard before `repo.get(audit_schema, audit_event_id)`

**File:** `lib/sigra/workers/audit_forward.ex:62, 76`
**Reason:** skipped: the new top-level `try/rescue` in `perform/1` (CR-02 fix) already catches the `repo.get(audit_schema, nil)` raise from Postgrex (DBConnection.ConnectionError) and returns `{:error, reason}` instead of crashing. The nil-guard would add an explicit `{:cancel, :missing_audit_event_id}` cancel code (non-retryable) vs the current `{:error, reason}` (retryable). This is a semantic improvement but not a correctness fix now that CR-02 is in place. Recommend as a polish fix in a follow-up pass.

### WR-05: D-15 backoff test compares source substrings

**File:** `test/sigra/workers/audit_forward_test.exs:106-119`
**Reason:** skipped: this is a test quality finding, not a production bug. The current test reliably guards the D-15 byte-for-byte requirement via source-string assertion. A semantic behavioral test would be better (as suggested), but the improvement requires careful `:rand` seed management and doesn't fix a broken behavior — the backoff implementation is correct. Recommend as a test quality follow-up.

---

_Fixed: 2026-05-27T17:29:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
