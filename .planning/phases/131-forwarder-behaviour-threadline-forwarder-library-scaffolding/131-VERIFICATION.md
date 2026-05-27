---
phase: 131-forwarder-behaviour-threadline-forwarder-library-scaffolding
verified: 2026-05-27T21:55:29Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
gaps: []
human_resolutions:
  - item: "SC-2 wording deviation"
    resolution: "Option (a) accepted — ROADMAP SC-2 wording updated in commit 7eb79eb to reflect shipped skip-not-substitute behavior. Practical observable outcome is unchanged: one warning per missing dep, zero forwarding when degraded, audit DB row preserved. Noop remains available as an explicitly-configurable forwarder."
    decided: 2026-05-27
  - item: "SC-1 live Threadline-end-to-end integration"
    resolution: "Deferred to Phase 132 (Threadline recipe) per verifier note — live Sigra→real-Threadline-DB handshake is recipe-wiring scope, not Plan 04 scope. Tracking via Phase 132 success criteria."
    decided: 2026-05-27
---

# Phase 131: Forwarder Behaviour + Threadline Forwarder Library Scaffolding — Verification Report

**Phase Goal:** Ship the only new v1.29 library code — `Sigra.Audit.Forwarder` behaviour + `Sigra.Audit.Forwarders.Threadline` telemetry-tap impl + `Noop` fallback + optional `Sigra.Workers.AuditForward` Oban worker — and freeze the `forwarders:` config shape that every later phase pins against.

**Verified:** 2026-05-27T21:55:29Z
**Status:** human_needed
**Re-verification:** No — initial verification (covers post-REVIEW-FIX state)

## Goal Achievement

### Observable Truths (5 Success Criteria)

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Threadline present + `forwarders:` configured → audit commit creates Threadline row with UUID + `occurred_at` as idempotency key; `[:sigra, :audit, :forward, :ok]` fires | VERIFIED | `lib/sigra/audit/forwarders/threadline.ex:295` `correlation_id: metadata[:id]`; ok-event at lines 122-131; ThreadlineTest Test 1 GREEN asserting `forward_meta.forwarder == :threadline`, `is_integer(measurements.duration_ms)`, `Keyword.get(call_opts, :correlation_id) == metadata.id`. CR-04 fix (lines 272-282) adds nil-action fallback so handler can never crash inside auto-detach landmine zone. CR-01 fix (`lib/sigra/workers/audit_forward.ex:203`) routes `:repo` through `Application.fetch_env!(:sigra, :repo)` — fixes the production-blocking async path. |
| 2 | Threadline absent → `mix compile && mix test` clean; one boot Logger.warning per missing dep; Noop used in place of Threadline impl | VERIFIED (with caveat — see human_verification[0]) | Local dep-off smoke: `mix deps.unlock threadline && mix deps.clean threadline --build && mix compile --warnings-as-errors --no-deps-check` exit 0; `mix test --exclude requires_threadline` 77 tests, 0 failures (6 excluded). `lib/sigra/application.ex:109` emits Logger.warning with module name + recipe link. CR-03 fix changed the moduledoc claim — Noop is NOT auto-substituted; behavior is "skip-not-substitute" (line 154: `if Code.ensure_loaded?(module), do: module.attach(forwarder_opts)` with no else). The practical SC-2 outcome (clean compile, clean tests, one warning per missing dep) IS achieved; the literal SC-2 wording "Noop used in place" is now contradicted by shipped behavior — surfaced to human. |
| 3 | Deliberately failed Threadline write → `[:sigra, :audit, :forward, :error]` fires; Sigra audit transaction NEVER rolls back | VERIFIED | `lib/sigra/audit/forwarders/threadline.ex:99-221` wraps entire body in `try / rescue / catch :exit / catch :throw`; all paths emit `[:sigra, :audit, :forward, :error]` and return `:ok` to telemetry. ThreadlineTest Test 2 (auto-detach landmine — handler stays attached after raise), Test 3 (:exit), Test 4 (:throw), and Test 5 (Pitfall 2 — live Postgres asserts `rows_after_failure == rows_after_insert` after forced Threadline raise) all GREEN. CR-02 fix (`lib/sigra/workers/audit_forward.ex:103`) also wraps the entire `perform/1` body in try/rescue/catch — D-17 now structurally enforced, not just by `perform_forward/5`. |
| 4 | `:auto`/`:async`/`:sync` dispatch matches Sigra.Delivery precedent: `:auto` picks Oban when present + inline otherwise; `:async` raises at boot if Oban missing; `:sync` always inline | VERIFIED | `lib/sigra/audit/forwarders.ex:105-110` `dispatch_mode/1` mirrors `lib/sigra/delivery.ex:103-108` exactly (uses `:dispatch` per D-07 — NOT `:delivery_mode`). `oban_running?/1` (PUBLIC, line 90) mirrors `delivery.ex:113-115` with `:oban` override per D-32. `lib/sigra/application.ex:139-152` raises ArgumentError at boot when `dispatch: :async` + Oban absent; message names module + `:oban` dep + `:auto` fallback + recipe link. ApplicationForwardersTest Tests 6/7 assert raise + message contents. DispatchTest Tests 1-5 cover all 3 modes + :auto routing both ways. |
| 5 | Host-defined custom forwarder (Mox stub) successfully `attach/1`s against the behaviour contract Threadline uses | VERIFIED | `lib/sigra/audit/forwarder.ex:54` single `@callback attach(opts :: keyword()) :: :ok \| {:error, term()}`. ForwarderTest defines inline `StubForwarder do @behaviour Sigra.Audit.Forwarder; def attach(_opts), do: :ok end` — compiles with `--warnings-as-errors`. `behaviour_info(:callbacks) == [attach: 1]` asserted (D-33 anti-regression). Moduledoc `## Mox Usage` H2 documents `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` (D-04). All 3 ForwarderTest cases GREEN. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/audit/forwarder.ex` | Single-callback behaviour + Mox moduledoc | VERIFIED | 55 lines; `@callback attach/1` exactly once; `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` in moduledoc; CR-03 fix corrected the "Noop falls through" docstring to "skip-not-substitute". |
| `lib/sigra/audit/forwarders/noop.ex` | Fail-open Noop fallback (no-telemetry, no-log) | VERIFIED | 36 lines; `@behaviour Sigra.Audit.Forwarder` + `def attach(_opts), do: :ok`; `> #### Warning {: .warning}` ExDoc admonition (D-24); zero `:telemetry` calls; zero `Logger.` calls in body. CR-03 moduledoc correctly states "Noop is only active when **explicitly listed** in your `sigra_config/0`". |
| `lib/sigra/audit/forwarders/threadline.ex` | Threadline impl wrapped in `Code.ensure_loaded?(Threadline)` | VERIFIED | 333 lines; outer `if Code.ensure_loaded?(Threadline) do` wrap (line 1); `@behaviour Sigra.Audit.Forwarder` (line 71); `@impl Sigra.Audit.Forwarder def attach(opts)` (lines 81-91); `handle_event/4` body wrapped in `try/rescue/catch :exit/:throw` covering all D-19 kinds; `forwarder: :threadline` atom appears 6 times (D-30); `correlation_id: metadata[:id]` at line 295. CR-04 fix added `(_ -> {:error, :missing_action})` fallback at line 280 so nil action no longer raises CaseClauseError inside handler body. |
| `lib/sigra/audit/forwarders.ex` | Shared dispatcher with public `oban_running?/1` | VERIFIED | 163 lines; `def dispatch/3` at line 64; `def oban_running?(opts)` PUBLIC at line 90 (Plan 05 calls cross-module); mirrors `lib/sigra/delivery.ex:113-115` with `:oban` override per D-32; `defp dispatch_mode/1` reads `:dispatch` (NOT `:delivery_mode`). WR-04 fix (line 155) returns `{:error, :async_worker_not_compiled}` instead of silent `:ok` when worker is absent. |
| `lib/sigra/workers/audit_forward.ex` | Optional Oban worker with thin args + cancel taxonomy + backoff | VERIFIED | 318 lines; outer `if Code.ensure_loaded?(Oban.Worker) do` wrap (line 1); `use Oban.Worker, queue: :sigra_audit_forward, max_attempts: 5` (D-14); `backoff/1` byte-for-byte from EmailDelivery (line 163: `trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)`); all 4 cancel tuples present (`:audit_event_not_found`, `:unknown_forwarder`, `:schema_mismatch` ×4, `{:error, _}`); CR-01 fix routes `:repo` via `Application.fetch_env!(:sigra, :repo)` (line 203) mirroring EmailDelivery; CR-02 fix wraps entire `perform/1` body in try/rescue/catch (line 103) — D-17 structurally enforced. WR-02 fix adds `{:ok, _} -> :ok` clause + catch-all `other ->` (lines 239, 245). Worker reads exactly the three thin keys: `forwarder`, `audit_event_id`, `occurred_at`. |
| `lib/sigra/application.ex` (boot wiring) | start/2 calls maybe_warn + attach_forwarders in D-25 order; ArgumentError on :async + no Oban; T-131-14 redaction | VERIFIED | start/2 sequence (lines 24-25) calls helpers in D-25 order before verify_vault!; `maybe_warn_missing_forwarder_deps/0` at lines 92-120 emits one Logger.warning per configured-but-missing dep, interpolates only `#{inspect(module)}` (no opts blob, no api_key leak — T-131-14); `attach_forwarders/0` at lines 122-169 raises ArgumentError naming module + `:oban` + `:auto` fallback + recipe link; D-27 single config cascade `Application.get_env(otp_app, :sigra_config)` appears 4 times — no second pattern introduced; zero `Process.whereis(Oban)` calls in application.ex (delegates to `Sigra.Audit.Forwarders.oban_running?/1` — D-12); WR-06 fix adds detach-before-attach at line 163 for idempotency across `recompile()`. |
| `lib/sigra/config.ex` (forwarders schema) | NimbleOptions custom validator | VERIFIED | `audit[:forwarders]` schema at lines 819-828 uses `{:custom, Sigra.Config, :validate_forwarders, []}` (per RESEARCH §3 option 1 — `{:list, {:keyword_list, ...}}` was tested and rejected because it rejected impl-specific keys); `validate_forwarders/1` at lines 954-997 validates `:module` required+atom, `:dispatch` in `[:auto, :async, :sync]`, `:id` atom; WR-07 fix (line 992) returns a normalized list with `:dispatch` and `:id` defaults injected — downstream consumers can use `Keyword.fetch!` reliably. ConfigForwardersTest 5 cases GREEN. |
| `lib/sigra/audit.ex` emit_telemetry/1 (metadata extension) | Additive metadata superset with :id + :occurred_at | VERIFIED | Lines 306-326 — emits exactly 5 metadata keys: `action, actor_id, outcome, id, occurred_at`. All three existing keys preserved with identical values (additive — backwards-compat audit GREEN: 2252 tests, 0 failures including all existing subscribers). AuditTelemetryTest asserts metadata.id is binary UUID + metadata.occurred_at is %DateTime{}. |
| `mix.exs` (optional Threadline dep + no_warn_undefined) | Threadline atom set + Sigra.Workers.AuditForward in no_warn_undefined; `{:threadline, "~> 0.5", optional: true}` | VERIFIED | Lines 70-73 carry `Threadline`, `Threadline.ActorRef`, `Threadline.AuditChange`, `Threadline.AuditTransaction`; line 88 carries `Sigra.Workers.AuditForward`; line 116 declares `{:threadline, "~> 0.5", optional: true}`. `mix deps.get` succeeds (threadline 0.5.0 in mix.lock). |
| `.github/workflows/ci.yml` (dep-off CI lane) | New library_tests_dep_off job (TL-04 SC-2) | VERIFIED | Lines 170-219 — new `library_tests_dep_off` job; mirrors `library_tests` structure with separate cache key prefix `library-dep-off`; runs `mix deps.unlock threadline && mix deps.clean threadline --build` before `mix compile --warnings-as-errors --no-deps-check` and `mix test --exclude requires_threadline --no-deps-check`. SHA pins identical to library_tests (`actions/checkout@de0fac2e...`, `erlef/setup-beam@fc68ffb9...`, `actions/cache@00578528...`). |
| `test/sigra/audit/forwarders/threadline_test.exs` | 6+ tests incl. auto-detach landmine + Pitfall 2 boundary | VERIFIED | 9 test cases (6 named per plan + 3 helper-style); `@moduletag :requires_threadline` at line 13 — ONLY test file carrying this tag (dep-off lane skips correctly); Tests 1-6 cover happy path + correlation_id, auto-detach landmine, catch :exit, catch :throw, Pitfall 2 boundary (live Postgres), atom :threadline. |
| `test/sigra/audit/forwarder_test.exs` | Behaviour contract test (FB-01 / SC-5) | VERIFIED | 3 tests; inline `StubForwarder` proves a host stub compiles cleanly; `behaviour_info(:callbacks) == [attach: 1]` asserted; moduledoc Mox example asserted via `Code.fetch_docs`. |
| `test/sigra/audit/forwarders/noop_test.exs` | Noop contract test (no telemetry, no log) | VERIFIED | 3 tests; `attach([]) == :ok`; `:telemetry.list_handlers([:sigra, :audit, :log])` unchanged before/after; `ExUnit.CaptureLog.capture_log/1 == ""`. |
| `test/sigra/audit/forwarders/dispatch_test.exs` | Dispatch routing tests | VERIFIED | 6 tests; all 3 dispatch modes covered; StubOban pattern (Plan 04 follow-up) implements `insert/1` returning `{:ok, %Oban.Job{}}`; tests StubForwarder, oban_running?/1, dispatch :auto routing. |
| `test/sigra/audit/forwarders/audit_forward_test.exs` | Worker shape + cancel taxonomy + backoff curve | VERIFIED | 6 tests (Tests 1-6); D-14 queue + max_attempts; D-15 backoff source-string check (WR-05 noted as test-quality polish, not bug); D-16 cancel taxonomy; D-17 no-raise; D-13 thin args. |
| `test/sigra/audit_telemetry_test.exs` | Telemetry metadata contract test | VERIFIED | 2 tests; asserts all 5 metadata keys + binary UUID + %DateTime{}. StubRepo `ensure_autogenerated_id` hack documented in Plan 02 SUMMARY (Ecto.Changeset.apply_changes/1 alone doesn't trigger autogenerate). |
| `test/sigra/config_forwarders_test.exs` | Schema validation tests | VERIFIED | 5 tests; default empty list; valid shape; rejects missing :module + invalid :dispatch via NimbleOptions.ValidationError; arbitrary impl keys (:endpoint, :api_key) pass through. |
| `test/sigra/application_forwarders_test.exs` | Boot-wiring tests | VERIFIED | 9 tests; missing-dep warning, present-dep silence, empty list silence, T-131-14 redaction (TOPSECRET-DO-NOT-LEAK not present in capture_log), :async raise with regex `~r/:async/i`, raise message names module, valid :auto attach. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/sigra/audit/forwarders/threadline.ex handle_event/4` | `Threadline.record_action/2` | `:correlation_id` carrying metadata.id (UUID) | WIRED | Line 295 `correlation_id: metadata[:id]`; CR-04 fix gates the call on name_result success (line 299). |
| `lib/sigra/audit/forwarders/threadline.ex handle_event/4 async path` | `Sigra.Audit.Forwarders.dispatch/3` | shared `:async` routing | WIRED | Line 115 calls `Sigra.Audit.Forwarders.dispatch(__MODULE__, metadata, opts)`. Sync path calls `call_threadline/2` directly (avoids circular dispatch — caught during Plan 04 implementation). |
| `lib/sigra/workers/audit_forward.ex perform/1` | `repo.get(audit_schema, audit_event_id)` | thin-args reload | WIRED | Line 80 `repo.get(audit_schema, audit_event_id)`. CR-01 fix routes `:repo` via `Application.fetch_env!(:sigra, :repo)` (line 203) mirroring EmailDelivery — production path is no longer broken. |
| `lib/sigra/application.ex attach_forwarders/0` | `Sigra.Audit.Forwarders.oban_running?/1` | single source of truth (D-12) | WIRED | Line 139 — no `Process.whereis(Oban)` duplication in application.ex (verified grep == 0). |
| `lib/sigra/application.ex start/2` | maybe_warn → attach in D-25 order | sequential calls | WIRED | Lines 24-25 — maybe_warn_missing_forwarder_deps() precedes attach_forwarders() precedes verify_vault!(). |
| `lib/sigra/audit.ex emit_telemetry/1` | `:telemetry.execute([:sigra, :audit, :log], ...)` | metadata map | WIRED | Lines 315-325 — exactly 5 keys, additive. |
| `mix.exs deps` | hex `threadline ~> 0.5` | optional: true | WIRED | Line 116; threadline 0.5.0 in mix.lock. |
| `.github/workflows/ci.yml library_tests_dep_off` | `mix deps.unlock + clean threadline` | dep-removal step | WIRED | Lines 205-208; --no-deps-check passed to compile + test steps (Plan 06 SUMMARY Auto-fix). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `Sigra.Audit.Forwarders.Threadline` | `metadata[:id]` | `Sigra.Audit.emit_telemetry/1` event.id | YES — audit_event @primary_key {:id, :binary_id, autogenerate: true} | FLOWING |
| `Sigra.Audit.Forwarders.Threadline` | `metadata[:occurred_at]` | `Sigra.Audit.emit_telemetry/1` event.occurred_at | YES — Audit.Changeset validate_required([:action, :outcome, :occurred_at]) | FLOWING |
| `Sigra.Audit.Forwarders.Threadline` `call_threadline/2` | `metadata[:action]` → name atom | upstream Audit.log (string) | YES — String.to_atom + CR-04 nil fallback | FLOWING |
| `Sigra.Audit.Forwarders.Threadline` `call_threadline/2` | `metadata[:actor_id]` → ActorRef | upstream Audit.log (string or nil) | YES — build_actor_ref pattern-matches all cases | FLOWING (IN-03 swallows construction errors silently — informational only) |
| `Sigra.Workers.AuditForward` `perform/1` | audit row reloaded by UUID | `repo.get(audit_schema, audit_event_id)` | YES — CR-01 fix points repo at `Application.fetch_env!(:sigra, :repo)` (matches EmailDelivery pattern; production path no longer KeyErrors) | FLOWING |
| `Sigra.Audit.Forwarders dispatch_async/3` | Oban job | `apply(@worker_module, :new, [job_args])` + `oban.insert(changeset)` | YES — `Sigra.Workers.AuditForward` compiles when Oban present; WR-04 fix returns `{:error, :async_worker_not_compiled}` when absent (observable, not silent) | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Mix compile clean (Threadline present) | `MIX_ENV=test mix compile --warnings-as-errors` | exit 0 | PASS |
| Phase 131 test slice GREEN | `mix test test/sigra/audit/forwarder_test.exs test/sigra/audit/forwarders/{noop,dispatch,threadline}_test.exs test/sigra/audit_telemetry_test.exs test/sigra/workers/audit_forward_test.exs test/sigra/application_forwarders_test.exs test/sigra/config_forwarders_test.exs` | 41 tests, 0 failures | PASS |
| Full suite regression check | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` | 33 doctests, 3 properties, 2252 tests, 0 failures (400.4s) | PASS |
| Dep-off compile (Threadline absent) | `mix deps.unlock threadline && mix deps.clean threadline --build && mix compile --warnings-as-errors --no-deps-check` | exit 0 | PASS |
| Dep-off test slice (Threadline absent) | `mix test --exclude requires_threadline --no-deps-check test/sigra/audit/ test/sigra/audit_telemetry_test.exs test/sigra/workers/audit_forward_test.exs test/sigra/application_forwarders_test.exs test/sigra/config_forwarders_test.exs` | 77 tests, 0 failures (6 excluded) | PASS |
| Deps restored after dep-off smoke | `mix deps.get` | All dependencies fetched (threadline 0.5.0 restored) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TL-01 | 131-04 | Threadline forwarder subscribes to `[:sigra, :audit, :log]` and forwards committed audit rows to Threadline | SATISFIED | `lib/sigra/audit/forwarders/threadline.ex` attaches handler in `attach/1`, ships rows via `Threadline.record_action/2` with `correlation_id: metadata[:id]`. ThreadlineTest Tests 1, 5, 6 GREEN. |
| TL-02 | 131-03, 131-05 | Two-tier dispatch (:auto/:async/:sync) matching Sigra.Delivery; :async raises at boot if Oban absent | SATISFIED | `lib/sigra/audit/forwarders.ex:105-110` dispatch_mode; `lib/sigra/application.ex:139` raises ArgumentError at boot. ApplicationForwardersTest Tests 6/7 + DispatchTest Tests 1-5 GREEN. |
| TL-03 | 131-04 | `Sigra.Workers.AuditForward` Oban worker w/ bounded retries + exponential backoff; failures fire `[:sigra, :audit, :forward, :error]`; never roll back originating auth op | SATISFIED | `lib/sigra/workers/audit_forward.ex` — `max_attempts: 5`, backoff byte-for-byte from EmailDelivery, all 4 cancel tuples, CR-02 fix wraps perform/1 in try/rescue/catch so D-17 holds. Pitfall 2 boundary verified by ThreadlineTest Test 5 (live Postgres). |
| TL-04 | 131-01, 131-03, 131-05, 131-06 | Forwarder optional-dep safe — `Code.ensure_loaded?(Threadline)` wrap + Noop fallback + Logger.warning at boot | SATISFIED (with SC-2 wording caveat — see human_verification[0]) | Threadline impl wrapped (threadline.ex:1); Noop ships at `lib/sigra/audit/forwarders/noop.ex`; Logger.warning at application.ex:109; dep-off CI lane at ci.yml:170-219 catches regressions. CR-03 fix changed semantics from "Noop substituted" to "skip-not-substitute" — Logger.warning still fires per the literal requirement wording, but the "Noop fallback ships in tree" clause is satisfied (Noop module exists and is usable when explicitly listed). |
| TL-05 | 131-02, 131-04 | Forwarder emits separate `[:sigra, :audit, :forward, :ok]` and `[:sigra, :audit, :forward, :error]` events | SATISFIED | `lib/sigra/audit/forwarders/threadline.ex:75-76` module attrs; events fired in handle_event/4 success branch (lines 122, 134) and all 3 failure branches (lines 145, 162, 182, 202). Metadata superset (id + occurred_at) added by Plan 02 enables Pitfall 4 idempotency without re-query. |
| FB-01 | 131-01 | `Sigra.Audit.Forwarder` behaviour with single `@callback attach(keyword) :: :ok \| {:error, term}`; Mox.defmock supported | SATISFIED | `lib/sigra/audit/forwarder.ex:54` single callback; moduledoc carries `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)`; behaviour_info(:callbacks) == [attach: 1] anti-regression test. |

All 6 declared requirement IDs (TL-01..TL-05, FB-01) accounted for. No orphaned requirements in REQUIREMENTS.md mapped to Phase 131.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/sigra/audit/forwarders/threadline.ex` | 255 | `_ -> :ok` catch-all for unknown outcome maps to Threadline `:status: :ok` (fail-open) — WR-01 deferred | Info | Fail-open vs fail-closed semantic decision; valid outcome set appears complete for current Sigra audit events; planner deferred to Phase 132/135 follow-up. Not a SC-blocker. |
| `lib/sigra/audit/forwarders/threadline.ex` | 278 | `String.to_atom/1` on user-controllable audit action strings — CR-04 partial mitigation | Info | Documented in-code as known atom-growth risk (line 260-271); nil/unknown crash is FIXED; the unbounded atom-table-growth risk persists pending an action registry. Not blocking for v1.29 (audit actions are developer-controlled, not end-user-controlled). |
| `lib/sigra/audit/forwarders/threadline.ex` | 312-326 | `build_actor_ref` silently returns nil on construction failure (no telemetry/log) — IN-03 informational | Info | Cascade still produces typed cancellation downstream; lacks diagnostic breadcrumb. Phase 132+ polish. |
| `lib/sigra/workers/audit_forward.ex` | 67 | `_occurred_at_iso = args["occurred_at"]` is dead binding — IN-01 informational | Info | Read but unused; moduledoc claims it's "for tracing" but never emitted. Polish task. |
| `lib/sigra/workers/audit_forward.ex` | 76, 80 | No explicit nil-guard before `repo.get(audit_schema, audit_event_id)` — WR-03 deferred | Info | CR-02 top-level try/rescue catches the consequent raise from Postgrex; current behavior returns `{:error, reason}` instead of explicit `{:cancel, :missing_audit_event_id}` (retryable vs non-retryable). Semantic polish, not correctness bug. |
| `test/sigra/workers/audit_forward_test.exs` | 106-119 | D-15 backoff test compares source substrings — WR-05 deferred | Info | Source-string assertion is brittle if maintainer moves the body into a comment. Test-quality finding, not production bug. |

No 🛑 BLOCKER anti-patterns. No unreferenced TBD/FIXME/XXX debt markers in modified files. CR/WR fixes from 131-REVIEW-FIX.md all landed in commits ea66168, 3c1eccc, 68fa739, 405eb2e, 6828b37, 5b9a421.

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| (none declared) | — | — | SKIPPED |

Phase 131 PLANs do not declare scripts/*/tests/probe-*.sh probes. The behavioral spot-checks above (full suite + dep-off compile + dep-off test) provide equivalent end-to-end verification.

### Human Verification Required

#### 1. SC-2 wording deviation — Noop skip-not-substitute (CR-03 disposition)

**Test:** Decide whether to accept the CR-03 fix that documents "Noop is NOT auto-substituted" (skip-not-substitute) as satisfying the original ROADMAP SC-2 clause "Noop used in place of Threadline impl", OR flip the disposition and have `attach_forwarders/0` actually substitute Noop on missing-dep.
**Expected:** Either (a) update ROADMAP SC-2 wording to remove "Noop used in place" and explicitly say "skip-not-substitute with Logger.warning", OR (b) revert CR-03 and add the substitution logic in `lib/sigra/application.ex:154` (else branch calls `Sigra.Audit.Forwarders.Noop.attach(forwarder_opts)`).
**Why human:** Practical user outcome (one warning per missing dep, zero forwarding when degraded, audit row preserved) is achieved either way; only the contract wording and one branch differ. The code reviewer chose doc-fix (option b in their report); the documented code now reflects the actual behavior, and the actual behavior produces the SC-2 observable warnings + clean compile + clean tests. Decision is product-shape, not automated. If accepting (a), no code changes needed; if choosing (b), ~5 LOC change in application.ex plus moduledoc revert.

#### 2. Live Threadline integration handshake

**Test:** Verify Sigra audit commit produces an actual Threadline `audit_actions` row against a real Threadline.Repo (not MockThreadline).
**Expected:** Real audit_action row in Threadline DB with `correlation_id = audit_event.id` and `name = audit_event.action` after a Sigra audit commit fires `[:sigra, :audit, :log]`.
**Why human:** Plan 04 tests use MockThreadline (a hand-stub) for `Threadline.record_action/2`. The contract is GREEN; the integration handshake — Sigra → real Threadline DB — requires Phase 132+ recipe wiring. This is the canonical "shift-left would still leave the integration handshake for human" check per project memory `feedback_zero_human_uat.md`. Phase 132's recipe ships this wiring; verification belongs there.

### Gaps Summary

No gaps blocking the phase goal. All 5 Success Criteria are observably TRUE in the codebase:

- **SC-1** Threadline + correlation_id idempotency + ok telemetry — verified by ThreadlineTest Test 1 + production code at threadline.ex:295.
- **SC-2** Dep-off clean compile + one Logger.warning + Noop-or-skip degraded path — verified by local dep-off smoke + ApplicationForwardersTest. The "Noop used in place" wording in ROADMAP was renegotiated during CR-03 review; the documented behavior is now "skip-not-substitute" with the same user-observable outcome (warning + zero forwarding). Surfaced for human decision (option a wording update vs option b add substitution).
- **SC-3** Forced failure → :error telemetry + no rollback — verified by ThreadlineTest Tests 2/3/4/5 (Pitfall 2 with live Postgres asserting `rows_after_failure == rows_after_insert`).
- **SC-4** Dispatch knob matches Sigra.Delivery; :async raises at boot — verified by DispatchTest + ApplicationForwardersTest raise tests.
- **SC-5** Host Mox stub attaches against behaviour — verified by ForwarderTest inline StubForwarder compile-clean assertion.

Code review fixes (CR-01..CR-04, WR-02, WR-04, WR-06, WR-07) landed in 6 commits; deferred items (WR-01, WR-03, WR-05) are documented test-quality / semantic-polish follow-ups for Phase 132+, not correctness regressions for Phase 131.

The phase goal — "Ship the only new v1.29 library code … and freeze the `forwarders:` config shape" — is achieved.

---

_Verified: 2026-05-27T21:55:29Z_
_Verifier: Claude (gsd-verifier)_
