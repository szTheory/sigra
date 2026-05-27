# Phase 131: Forwarder Behaviour + Threadline Forwarder Library Scaffolding - Context

**Gathered:** 2026-05-27 (assumptions mode, `minimal_decisive` calibration)
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the only new v1.29 library code — `Sigra.Audit.Forwarder` behaviour plus
`Sigra.Audit.Forwarders.Threadline` telemetry-tap impl plus `Sigra.Audit.Forwarders.Noop`
fallback plus the optional `Sigra.Workers.AuditForward` Oban worker — and freeze the
`forwarders:` config shape that every later v1.29 phase (132 recipe, 135 example app,
136 verification) pins against.

**Hard scope anchors (from ROADMAP.md / REQUIREMENTS.md, NOT re-litigated here):**

- Naming is `Sigra.Audit.Forwarders.Threadline` (Forwarders, plural — signals "Sigra
  audit DB row remains source-of-truth; Threadline is a post-commit projection, never
  a destination swap").
- Scattered `Code.ensure_loaded?` precedent stands. `Sigra.OptionalDeps` SOT is
  deferred out of v1.29.
- `mix sigra.doctor` is deferred out of v1.29.
- No `--with-threadline` (or any `--with-*`) install flag — zero precedent. Pure
  runtime config via host `sigra_config/0`.
- Mailglass is recipe-only in v1.29; do NOT re-land the orphaned Phase 111/114
  adapter as part of Phase 131.
- The forwarder fires only from the `{:ok, _}` branch of `Sigra.Audit` — rolled-back
  transactions never forward. Threadline downtime never blocks login.
</domain>

<decisions>
## Implementation Decisions

### Behaviour Shape & Lifecycle (FB-01)

- **D-01:** `Sigra.Audit.Forwarder` defines a single `@callback attach(keyword) :: :ok | {:error, term}`. No other callbacks — `attach/1` is the sole seam.
- **D-02:** `attach/1` is **library-called** from `Sigra.Application.start/2` via a new `attach_forwarders/0` helper (alongside existing `maybe_warn_audit_cleanup_fallback/0`). Host apps do not call `attach/1` directly — pure runtime config is enough.
- **D-03:** Handler id derived from `{__MODULE__, opts[:id] || :default}` so the same impl can attach multiple times with different ids if a host wires two Threadline endpoints. Test teardown calls `:telemetry.detach(handler_id)` with the same key.
- **D-04:** Behaviour module documents Mox usage in its moduledoc, mirroring `Sigra.RateLimiter` (`lib/sigra/rate_limiter.ex:17-19`) so adopters see `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` is the supported test path.

### `forwarders:` Config Shape (FREEZE — Phase 132/135/136 pin against this)

- **D-05:** Add `:forwarders` key under the existing `audit:` keyword in `Sigra.Config` (`lib/sigra/config.ex:793-820`).
- **D-06:** Shape is a **list of keyword lists**, where each entry carries `[module: Module, dispatch: :auto | :async | :sync, id: atom_or_nil, ...impl_opts]`. Threadline-specific opts (`:endpoint`, `:api_key`, etc.) live inside the same per-forwarder keyword list.
- **D-07:** `:dispatch` is **per-forwarder**, not top-level — matches `email[:delivery_mode]` precedent (`lib/sigra/config.ex:434-458`). Lets two forwarders run with different policies (e.g. Threadline `:async`, Datadog `:sync`).
- **D-08:** Custom host forwarders (Datadog, Honeycomb, OTel, in-house) appear in the same `:forwarders` list with `module: MyForwarder` — zero ceremony beyond implementing the behaviour and adding a line to config.
- **D-09:** Default value for `:forwarders` is `[]` (empty list). Absent / empty list = no attach calls, no boot warnings, zero overhead.

Example shape (canonical — Phase 132 recipe pins literally this block):

```elixir
audit: [
  audit_schema: MyApp.Accounts.AuditEvent,
  retention_days: 90,
  forwarders: [
    [
      module: Sigra.Audit.Forwarders.Threadline,
      dispatch: :auto,
      id: :default,
      endpoint: System.get_env("THREADLINE_ENDPOINT"),
      api_key: System.get_env("THREADLINE_API_KEY")
    ]
  ]
]
```

### Dispatch Wiring (TL-02)

- **D-10:** Routing for `:auto` / `:async` / `:sync` lives in a **shared dispatcher** — recommended placement `Sigra.Audit.Forwarders.dispatch/3` (or inline in `Sigra.Workers.AuditForward` if cleaner) — that the Threadline impl's `handle_event/4` delegates to.
- **D-11:** Threadline impl owns *only* the Threadline-specific payload mapping (audit row → Threadline call args). Dispatch logic stays shared so host-defined custom forwarders get the same `:auto`/`:async`/`:sync` semantics for free.
- **D-12:** Oban-presence detection mirrors `Sigra.Delivery.oban_running?/0` (`lib/sigra/delivery.ex:113-115`) exactly — `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil`. The "running, not just loaded" distinction matters; do not regress it.

### Oban Worker Shape (TL-03)

- **D-13:** `Sigra.Workers.AuditForward` job args: `%{"forwarder" => module_string, "audit_event_id" => uuid, "occurred_at" => iso8601}`. Thin reference only — **no full payload in args** per T-3-INFRA-01. Worker reloads the audit row from `repo + audit_schema` at perform time.
- **D-14:** `use Oban.Worker, queue: :sigra_audit_forward, max_attempts: 5` — bumped from `EmailDelivery`'s `max_attempts: 3` because audit retries don't spam users.
- **D-15:** `backoff/1` mirrors `EmailDelivery` curve: `trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)` (`lib/sigra/workers/email_delivery.ex:73-76`).
- **D-16:** Cancel taxonomy:
  - `{:cancel, :audit_event_not_found}` — row deleted between enqueue and perform (e.g. retention cleanup raced).
  - `{:cancel, :unknown_forwarder}` — forwarder module no longer compiled/loaded.
  - `{:cancel, :schema_mismatch}` — Threadline shipped a breaking schema change; not retryable.
  - `{:error, reason}` — network / timeout / transient.
- **D-17:** Worker `perform/1` fires `[:sigra, :audit, :forward, :error]` on any non-`:ok` exit and never raises. The originating auth/audit transaction already committed; failure here cannot roll it back (per Pitfall 2).
- **D-18:** Worker module is wrapped in `if Code.ensure_loaded?(Oban.Worker) do … end` per `lib/sigra/workers/audit_cleanup.ex` precedent. Add Oban.* atoms to `mix.exs` `no_warn_undefined` if any new symbols are referenced outside that block.

### Failure Isolation

- **D-19:** Threadline `handle_event/4` wraps the entire body in `try / rescue _ -> ... / catch _, _ -> ... end`. Catch **all** kinds — `:error`, `:exit`, `:throw`. On any caught failure, emit `[:sigra, :audit, :forward, :error]` and return `:ok` to `:telemetry`.
- **D-20:** Handler MUST NEVER raise to `:telemetry`. A raised handler is auto-detached by the `:telemetry` library for the rest of BEAM uptime — a single bad event would silently disable forwarding. This is the worst failure mode and is non-negotiable.
- **D-21:** Boundary doctrine: the forwarder ships events to a downstream sink that can drop them; correctness comes from the Sigra audit DB row remaining authoritative (Pitfall 2 in research), not from handler liveness.

### Noop Fallback (TL-04)

- **D-22:** `Sigra.Audit.Forwarders.Noop.attach/1` returns `:ok` immediately, does **NOT** subscribe to telemetry, and does **NOT** log anything itself.
- **D-23:** The one-shot "Threadline configured but dep missing" `Logger.warning` is emitted **upstream** from `Sigra.Application.start/2`, not from inside Noop. Mirrors `Sigra.RateLimiters.Noop` + `Sigra.Plug.RateLimit.resolve_limiter/1` split (`lib/sigra/rate_limiters/noop.ex` + `lib/sigra/plug/rate_limit.ex:84-95`).
- **D-24:** Noop's @moduledoc carries the fail-open warning admonition (`> #### Warning {: .warning}`) mirroring `Sigra.RateLimiters.Noop`.

### Boot-Time Wiring (TL-04)

- **D-25:** `Sigra.Application.start/2` (`lib/sigra/application.ex:21-27`) gains two new one-shot helpers called alongside existing `maybe_warn_audit_cleanup_fallback/0`:
  - `maybe_warn_missing_forwarder_deps/0` — for each configured forwarder, if `Code.ensure_loaded?(forwarder[:module])` is false, log one warning advising the dep + recipe link, then skip attach.
  - `attach_forwarders/0` — for each configured forwarder whose module IS loaded, call `forwarder.module.attach(opts)`. Library-owned attachment.
- **D-26:** **`:async` dispatch + Oban absent at boot ⇒ raise** (TL-02 explicit). The raise message names the offending forwarder, the missing dep, and points at `:auto` as the recommended fallback. Boot-time fail is correct here — silent degradation to `:sync` would mask the misconfiguration.
- **D-27:** Config lookup uses the existing `Application.get_env(otp_app, :sigra_config)` pattern (`lib/sigra/application.ex:34-38, 92-101`). Single config-resolution pattern across all boot diagnostics.

### Telemetry Event Shape (TL-05)

- **D-28:** `[:sigra, :audit, :forward, :ok]` — measurements `%{count: 1, duration_ms: integer}`, metadata `%{forwarder: :threadline, audit_event_id: uuid, action: string, dispatch: :sync | :async}`.
- **D-29:** `[:sigra, :audit, :forward, :error]` — measurements `%{count: 1}`, metadata `%{forwarder: atom, audit_event_id: uuid | nil, action: string | nil, reason: term, kind: :error | :exit | :throw, attempt: pos_integer | nil}`.
- **D-30:** Forwarder name in metadata is an **atom** (`:threadline`), not a module — matches the existing telemetry "category" idiom in `lib/sigra/telemetry.ex` (`:security`, `:mfa`, `:oauth`).
- **D-31:** **Existing `[:sigra, :audit, :log]` metadata is extended (additive, backwards-compatible)** to include `id` (the audit row UUID) and `occurred_at` (timestamp). Currently `lib/sigra/audit.ex:304-310` emits only `%{action, actor_id, outcome}` — insufficient because Pitfall 4 (cross-system deduplication) requires UUID + occurred_at as the canonical idempotency key for Threadline writes.

### Custom-Forwarder Contract Surface (FB-01 + Success Criterion #5)

- **D-32:** `attach(keyword) :: :ok | {:error, term}` keyword arg minimum keys:
  - `:id` — atom, handler-id uniqueness, defaults to `:default`.
  - `:dispatch` — `:auto | :async | :sync`, defaults to `:auto`.
  - `:audit_schema` — module needed by the worker to reload rows in `:async` path.
  - `:repo` — module needed by the worker to load rows.
  - `:oban` — module override for tests, defaults to `Oban` (matches `lib/sigra/delivery.ex:47` `Keyword.get(opts, :oban, Oban)`).
  - Plus arbitrary impl-specific keys (Threadline carries `:endpoint`, `:api_key`).
- **D-33:** The behaviour does **NOT** define `handle_event/4` or any payload-shape callbacks. What happens after `attach/1` is impl business. Hosts can wire Datadog / Honeycomb / OTel without conforming to a Sigra-mandated payload shape.

### Claude's Discretion

- Whether the shared dispatcher lives in `Sigra.Audit.Forwarders.dispatch/3` (a new module) or as a private function inside `Sigra.Workers.AuditForward`. Either is acceptable as long as custom forwarders can call the same routing logic.
- Whether the Threadline impl's per-event idempotency key is `"#{uuid}:#{occurred_at}"` or just `uuid` (Sigra UUIDs are already unique; `occurred_at` is belt-and-suspenders). Planner picks based on Threadline's API shape.
- Exact `Logger.warning` message text for the "forwarder configured but dep missing" case — mirror the tone of `maybe_warn_audit_cleanup_fallback/0`.

### Folded Todos

None — no pending todos crossed Phase 131's scope window.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Repo files — precedents Phase 131 must mirror

- `/Users/jon/projects/sigra/lib/sigra/audit.ex` — telemetry contract (lines 286-310); **`emit_telemetry/1` metadata MUST be extended here per D-31**.
- `/Users/jon/projects/sigra/lib/sigra/application.ex` — boot-time warning + attach hook precedent (lines 21-27, 68-88, 34-38, 92-101).
- `/Users/jon/projects/sigra/lib/sigra/config.ex` — extend `audit:` schema (lines 793-820) + config struct (lines 854-889). **`:forwarders` key lives here per D-05.**
- `/Users/jon/projects/sigra/lib/sigra/delivery.ex` — dispatch pattern + Oban-presence detection (lines 30-115).
- `/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex` — single-callback behaviour shape with Mox doc (lines 1-26).
- `/Users/jon/projects/sigra/lib/sigra/rate_limiters/noop.ex` — Noop fallback shape (lines 1-21).
- `/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex` — impl + `try/rescue` failure isolation (lines 27-40).
- `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex` — Oban worker shape + backoff curve + cancel taxonomy (lines 33-103).
- `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex` — `if Code.ensure_loaded?(Oban.Worker)` wrapping precedent.
- `/Users/jon/projects/sigra/lib/sigra/telemetry.ex` — `attach_default_logger` handler-id pattern (lines 341-348).
- `/Users/jon/projects/sigra/lib/sigra/plug/rate_limit.ex` — `resolve_limiter/1` with `Code.ensure_loaded?` + `Logger.warning` (lines 84-95).
- `/Users/jon/projects/sigra/mix.exs` — `no_warn_undefined` block (lines 65-87); add Threadline atoms here.
- `/Users/jon/projects/sigra/test/example/lib/example/accounts.ex` — host `sigra_config/0` wiring (lines 590-622); Phase 135 will add `forwarders:` here.

### Planning artifacts

- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — TL-01..05 + FB-01.
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` — Phase 131 Success Criteria #1–#5.
- `/Users/jon/projects/sigra/.planning/research/SUMMARY.md` — locked decisions, build order, naming rationale.
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md` — Phase 131 file-by-file plan (lines 79-265, esp. 95-101 handler-id shape, 121-135 config shape draft, 391 telemetry metadata gap).
- `/Users/jon/projects/sigra/.planning/research/PITFALLS.md` — boundary doctrine (Pitfall 2, lines 54-60), handler robustness (lines 11-200), idempotency (Pitfall 4, lines 62-67).
- `/Users/jon/projects/sigra/.planning/research/STACK.md` — Threadline 0.5.0 Hex publish status (verified 2026-05-27).
- `/Users/jon/projects/sigra/.planning/METHODOLOGY.md` — decisive defaulting, escalation threshold rules used to scope this phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Behaviour pattern**: `Sigra.RateLimiter` is the lockstep parallel — single tight callback, module-level Mox doc, paired with `Sigra.RateLimiters.Noop` + `Sigra.RateLimiters.Hammer`. Phase 131 mirrors structure under `Sigra.Audit.Forwarder` + `.Forwarders.Noop` + `.Forwarders.Threadline`.
- **Dispatch pattern**: `Sigra.Delivery` owns `:auto`/`:async`/`:sync` selection + Oban-presence detection (`oban_running?/0`) — copy this exact split between dispatcher and impl.
- **Worker pattern**: `Sigra.Workers.EmailDelivery` is the canonical precedent — `use Oban.Worker, max_attempts:`, `backoff/1`, `{:cancel, _}` for non-retryable, `Telemetry.span` wrapping perform body, `resolve_config/0` reading `Application.fetch_env!(:sigra, _)`. `Sigra.Workers.AuditForward` follows the same shape.
- **Boot diagnostics pattern**: `Sigra.Application.maybe_warn_audit_cleanup_fallback/0` is the literal precedent for "config-set, dep-missing → one-shot `Logger.warning`."
- **Optional-dep wrapping pattern**: `lib/sigra/workers/audit_cleanup.ex` and `lib/sigra/workers/email_delivery.ex` both wrap the entire `defmodule … end` in `if Code.ensure_loaded?(Oban.Worker) do`. Threadline impl wraps the same way against `Threadline`.

### Established Patterns

- **Telemetry one-shot emission**: `%{count: 1}` measurements + structured metadata. Span-style events use `[..., :stop]` suffix. Phase 131 uses one-shot pair (`:ok` / `:error`) per TL-05 — `:ok` carries `duration_ms` measurement for observability.
- **Config lookup**: `Application.get_env(otp_app, :sigra_config)` then `Keyword.get` into nested keywords. Phase 131 reads `:forwarders` via `audit: [forwarders: [...]]`.
- **Telemetry category atoms**: `:security`, `:mfa`, `:oauth`, etc. used as metadata tags. Phase 131 adds `:threadline` (and future forwarders contribute their own atoms).
- **NimbleOptions discipline**: every public config surface validates via `NimbleOptions`; documentation auto-generated from schema. The `:forwarders` key extends this — planner verifies `NimbleOptions` 1.1.x supports `{:list, :keyword_list}` of typed-key entries (flagged as a planner verification, NOT a phase scope risk).

### Integration Points

- **`Sigra.Audit.emit_telemetry/1`** (`lib/sigra/audit.ex:304-310`): MUST be extended with `id` + `occurred_at` metadata fields per D-31. Backwards-compatible additive change.
- **`Sigra.Application.start/2`** (`lib/sigra/application.ex:21-27`): MUST add `maybe_warn_missing_forwarder_deps/0` + `attach_forwarders/0` calls.
- **`Sigra.Config` `:audit` keyword schema** (`lib/sigra/config.ex:793-820`): MUST add `:forwarders` sub-key with the shape locked in D-06.
- **`mix.exs` `no_warn_undefined`** (lines 65-87): MUST add `Threadline` (and any referenced submodules) to suppress compile warnings when the optional dep is absent.
- **`Sigra.Audit.Forwarders.Threadline.handle_event/4`** (NEW): the only new telemetry handler. Wraps body in `try/rescue/catch` per D-19.
- **`Sigra.Workers.AuditForward`** (NEW, optional): wrapped in `if Code.ensure_loaded?(Oban.Worker)`. Reloads row via `repo + audit_schema`.
</code_context>

<specifics>
## Specific Ideas

- **Recipe-pin contract**: the `audit: [..., forwarders: [[module:, dispatch:, id:, ...opts]]]` block locked in D-06 is what Phase 132's `guides/recipes/companion-libs/threadline.md` pastes literally. Phase 135's `test/example/lib/example/accounts.ex` adds the same block. Phase 136 verification asserts both match.
- **Idempotency key construction**: Threadline writes use Sigra `audit_event_id` (UUID) + `occurred_at`. Whether the forwarder concatenates them or sends them as separate fields depends on Threadline's API surface (planner-verified in Phase 132 research).
- **One-shot warning text style**: mirror `maybe_warn_audit_cleanup_fallback/0`'s `Logger.warning` voice — describe the config gap, link to the recipe path (`guides/recipes/companion-libs/threadline.md`), and offer the actionable fallback (drop the forwarders entry or add `{:threadline, "~> 0.5"}` to deps).
</specifics>

<deferred>
## Deferred Ideas

- **`Sigra.OptionalDeps` SOT module** — consolidation refactor for the 29+ scattered `Code.ensure_loaded?` guards. Triggered when a 3rd new optional-dep adapter lands OR when `mix sigra.doctor` is built. Out of v1.29 scope per STATE.md + ROADMAP backlog.
- **`mix sigra.doctor` adopter-facing diagnostic task** — referenced in v1.21 HARD-02 narrative but never shipped. Separate post-v1.29 quick task.
- **Threadline correlation-ID propagation (Sigra → Threadline trace correlation)** — v1.30 candidate. Closes the loop with Threadline's existing one-way wire.
- **Recipe-contract test fixtures** — walks `guides/recipes/companion-libs/*.md` and asserts required section headings. Phase 134 budget-permitting; otherwise defer.
- **Library-resident Mailglass adapter recovery** — separate post-v1.29 quick task to decide whether to recover `lib/sigra/mailers/adapters/mailglass.ex` + `--with-mailglass` flag from the orphaned wip branches.
- **A `Sigra.Audit.Forwarder.detach/1` callback in the behaviour** — Phase 131 detach is per-impl via `:telemetry.detach/1` with the same handler id. If hot config reload becomes a need, a 2nd callback joins the behaviour in a later phase; not needed today.
- **A `handle_event/4` callback in the behaviour** — explicitly NOT included per D-33. Forces custom forwarders into Sigra's payload shape; defeats the seam. Revisit only if multiple forwarder impls converge on an identical mapper signature.

### Reviewed Todos (not folded)

None reviewed this round — no pending todos crossed Phase 131's scope window.
</deferred>
