# Phase 131: Forwarder Behaviour + Threadline Forwarder Library Scaffolding — Research

**Researched:** 2026-05-27
**Domain:** Elixir/Phoenix library code — telemetry forwarder behaviour, optional-dep adapter,
optional Oban worker, runtime config schema extension
**Confidence:** HIGH (every line range cited below was verified against repo HEAD on
`v1.28-data-lifecycle`; Threadline 0.5.0 Hex publish re-verified 2026-05-27;
NimbleOptions `{:list, {:keyword_list, keys}}` capability verified against hexdocs)
**Mode:** Verification & grounding of 33 locked CONTEXT.md decisions (D-01..D-33). No
decisions re-litigated; this document gives the planner exact code excerpts to wrap
precise `<read_first>` lists and `<acceptance_criteria>` around.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TL-01 | Sigra.Audit.Forwarders.Threadline subscribes to `[:sigra, :audit, :log]` and forwards committed rows | §2 audit.ex:286-310 (telemetry already fires on commit only); §2 rate_limiter.ex (behaviour shape mirror); §3 NimbleOptions shape; §6 contract test plan |
| TL-02 | `:auto` / `:async` / `:sync` dispatch matching `Sigra.Delivery` precedent; `:async` raises if Oban absent at boot | §2 delivery.ex:103-115 (oban_running?/0 exact body); §2 delivery.ex:30-36 (delivery_mode dispatch); §5 implementation order |
| TL-03 | Optional `Sigra.Workers.AuditForward` Oban worker wrapped in `if Code.ensure_loaded?(Oban.Worker)`; bounded retries, never rolls back originating audit | §2 audit_cleanup.ex:1 (wrap precedent); §2 email_delivery.ex:73-76 (backoff curve, mirrored by D-15); §2 email_delivery.ex:32-34 (Oban.Worker use); §6 contract test plan |
| TL-04 | Forwarder optional-dep safe; Noop fallback ships; boot-time one-shot Logger.warning when configured but missing | §2 application.ex:68-88 (maybe_warn_audit_cleanup_fallback/0 exact voice); §2 plug/rate_limit.ex:84-95 (resolve_limiter precedent); §2 rate_limiters/noop.ex:1-21 (Noop mirror shape) |
| TL-05 | `[:sigra, :audit, :forward, :ok]` + `[:sigra, :audit, :forward, :error]` separate events | §2 audit.ex:304-310 (existing emit_telemetry shape — must be extended additively per D-31); §6 validation table |
| FB-01 | `Sigra.Audit.Forwarder` behaviour with single `attach/1` callback; Mox-documented test path; generalizes beyond Threadline | §2 rate_limiter.ex:1-26 (exact mirror — single callback + Mox moduledoc); §3 NimbleOptions shape carries arbitrary impl keys; §7 custom-forwarder contract test plan |
</phase_requirements>

## 1. Summary

Phase 131 ships the only new library code in v1.29 SUITE-INTEGRATION: a single-callback
`Sigra.Audit.Forwarder` behaviour, a `Sigra.Audit.Forwarders.Threadline` telemetry-tap
impl that subscribes to `[:sigra, :audit, :log]` and forwards committed audit rows to
Threadline, a `Sigra.Audit.Forwarders.Noop` fallback, an optional
`Sigra.Workers.AuditForward` Oban worker, and the runtime extensions needed to wire them
(`Sigra.Config` `audit[:forwarders]` schema, `Sigra.Application` boot helpers, an
additive `Sigra.Audit.emit_telemetry/1` metadata extension, and `mix.exs`
`no_warn_undefined` entries). Every phase after this (132 recipe / 135 example app /
136 verification) pins against the `:forwarders` config shape frozen here, so the
contract matters more than implementation cleverness.

**Three landmines verified in code:** (1) the existing `emit_telemetry/1` at
`lib/sigra/audit.ex:304-310` emits only `%{action, actor_id, outcome}` — D-31's required
`id` + `occurred_at` extension is a strict superset (the struct already carries both,
confirmed via `lib/sigra/audit/changeset.ex:40` and `lib/sigra/audit.ex:522`). (2)
`oban_running?/0` at `lib/sigra/delivery.ex:113-115` distinguishes "compiled" from
"supervised" — D-12 says do not regress this. (3) `mix.exs` already lists every
optional-worker module in `no_warn_undefined` (lines 82-85); D-18 mirrors this pattern
for Threadline atoms.

**NimbleOptions verification (planner unblocker):** `{:list, {:keyword_list, keys}}` is
a documented NimbleOptions 1.1.x special-case syntax for "list of keyword lists with
per-key type validation" — no hand-roll required for the D-06 forwarders schema. See
§3.

**Threadline Hex status:** v0.5.0 published 2026-05-08, still latest as of 2026-05-27.
No version drift. **One API gap surfaced:** Threadline `record_action/2` has no
documented native idempotency-key option (no `external_id` / `dedupe_key`); the planner
must decide where the audit UUID + `occurred_at` live in the Threadline call (the most
likely answer is `:correlation_id` plus metadata — Phase 132 will verify against
recipe-level tests).

## 2. Verified Code Excerpts

These are the exact current bodies the planner must reference when writing precise
additive-edit tasks. Each excerpt was read from HEAD on `v1.28-data-lifecycle` on
2026-05-27.

### 2.1 `Sigra.Audit.emit_telemetry/1` (audit.ex:286-310) — extend per D-31

```elixir
  @spec emit_telemetry_from_changes(map(), [atom()]) :: :ok
  def emit_telemetry_from_changes(changes, audit_steps \\ [:audit]) do
    case {changes, audit_steps} do
      {m, steps} when is_map(m) and is_list(steps) ->
        Enum.each(steps, fn step ->
          case Map.get(m, step) do
            %_{} = event -> emit_telemetry(event)
            _ -> :ok
          end
        end)

        :ok

      _ ->
        :ok
    end
  end

  defp emit_telemetry(event) do
    :telemetry.execute(
      @telemetry_event,
      %{count: 1},
      %{action: event.action, actor_id: event.actor_id, outcome: event.outcome}
    )
  end
```

**D-31 additive edit:** the metadata map must become
`%{action: event.action, actor_id: event.actor_id, outcome: event.outcome, id: event.id, occurred_at: event.occurred_at}`.

**Why both fields are guaranteed safe to add:**
- `event.id` exists — `priv/templates/sigra.install/core/audit_event.ex:21` declares
  `@primary_key {:id, :binary_id, autogenerate: true}` (UUID, binary_id).
- `event.occurred_at` exists — `lib/sigra/audit/changeset.ex:40` includes
  `:occurred_at` in `@cast_fields`; line 71 makes it
  `validate_required([:action, :outcome, :occurred_at])`. Default is supplied at
  `lib/sigra/audit.ex:522`: `occurred_at: Keyword.get(opts, :occurred_at, DateTime.utc_now())`.

Backwards-compatibility audit: every existing subscriber to `[:sigra, :audit, :log]`
pattern-matches the metadata map on `%{action: _, actor_id: _, outcome: _}` style; a
superset map breaks none. The `Sigra.Telemetry.attach_default_logger` at
`lib/sigra/telemetry.ex:341-348` is the canonical subscriber and tolerates extra keys.

**Header rule for the planner:** the moduledoc at `lib/sigra/audit.ex:13` already
documents `[:sigra, :audit, :log]` as the cross-cutting telemetry passthrough; the
extended metadata shape is documented in the moduledoc as part of this phase, not as a
separate doc-pass.

### 2.2 `Sigra.Delivery.oban_running?/0` (delivery.ex:113-115) — D-12 mirror exactly

```elixir
  # :auto must only route to :async when Oban is actually supervised in the
  # host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
  # mix.exs without wiring the supervisor would otherwise crash on insert.
  defp oban_running? do
    Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
  end
```

The dispatch picker at `delivery.ex:103-108` (called from `deliver/3` at line 30-36):

```elixir
  defp delivery_mode(opts) do
    case Keyword.get(opts, :delivery_mode, :auto) do
      :auto -> if oban_running?(), do: :async, else: :sync
      mode -> mode
    end
  end
```

**Planner note:** the Phase 131 dispatcher (whether placed in `Sigra.Audit.Forwarders`
or inline in the worker per Claude's-discretion D-9 first bullet) reads
`Keyword.get(opts, :dispatch, :auto)` — **but per-forwarder, not top-level** (D-07
distinction from `email[:delivery_mode]`). The boot-time `:async`-without-Oban raise
(D-26) happens in `attach_forwarders/0`, not at first dispatch — the raise must surface
the misconfig at boot, not on first audited login.

### 2.3 `Sigra.Workers.EmailDelivery.backoff/1` (email_delivery.ex:73-76) — D-15 reuse

```elixir
    @impl Oban.Worker
    def backoff(%Oban.Job{attempt: attempt}) do
      # Exponential backoff with jitter: ~15s, ~60s (per D-25)
      trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
    end
```

**D-15:** `Sigra.Workers.AuditForward` mirrors this curve verbatim. Note that
`EmailDelivery` uses `max_attempts: 3` (`email_delivery.ex:32-34`); D-14 bumps the
forwarder to `max_attempts: 5`. The backoff curve is independent of `max_attempts`, so
verbatim reuse is correct.

**Cancel taxonomy precedent (D-16):** `email_delivery.ex` uses `{:cancel, _}` for
non-retryable failures (line 52, line 64-65, line 99); D-16's four cancel tuples
(`:audit_event_not_found`, `:unknown_forwarder`, `:schema_mismatch`,
`{:error, reason}` for retryable) mirror this idiom.

### 2.4 `Sigra.Application.maybe_warn_audit_cleanup_fallback/0` (application.ex:68-88) — D-25 voice mirror

```elixir
  @doc false
  def maybe_warn_audit_cleanup_fallback do
    retention = Application.get_env(:sigra, :audit, [])[:retention_days]

    cond do
      is_nil(retention) ->
        :ok

      Code.ensure_loaded?(Oban) ->
        :ok

      true ->
        Logger.warning("""
        [Sigra.Audit] retention_days=#{inspect(retention)} is configured but Oban is not loaded.
        Audit log retention cleanup will not run automatically.
        Call Sigra.Audit.cleanup(repo: MyApp.Repo, audit_schema: MyApp.Accounts.AuditEvent, retention_days: #{retention})
        from your own scheduler, or add :oban to your mix.exs deps.
        """)

        :ok
    end
  end
```

The full `start/2` callback hook surface (application.ex:21-27):

```elixir
  @impl Application
  def start(_type, _args) do
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    verify_vault!()

    Supervisor.start_link([], strategy: :one_for_one, name: Sigra.Supervisor)
  end
```

**D-25 planner pattern:** add two calls before the supervisor start, in this order:

```elixir
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    maybe_warn_missing_forwarder_deps()   # NEW per D-25
    attach_forwarders()                    # NEW per D-25 (raises if :async + no Oban per D-26)
    verify_vault!()
```

The config-lookup pattern (application.ex:30-38, 90-101) — `Application.get_env(otp_app, :sigra_config)` then `Keyword.get` — is the **single** config-resolution idiom across boot diagnostics (D-27). Reuse it exactly; do not introduce a second pattern.

`maybe_warn_missing_forwarder_deps/0` exact voice mirror (planner draft):

```elixir
  @doc false
  def maybe_warn_missing_forwarder_deps do
    otp_app = Application.get_env(:sigra, :otp_app)

    forwarders =
      case otp_app && Application.get_env(otp_app, :sigra_config) do
        opts when is_list(opts) ->
          opts |> Keyword.get(:audit, []) |> Keyword.get(:forwarders, [])

        _ ->
          []
      end

    Enum.each(forwarders, fn forwarder_opts ->
      module = Keyword.fetch!(forwarder_opts, :module)

      unless Code.ensure_loaded?(module) do
        Logger.warning("""
        [Sigra.Audit] Forwarder #{inspect(module)} is configured but its module is not loaded.
        Audit events will not be forwarded. Add the corresponding dep to mix.exs (e.g.
        `{:threadline, "~> 0.5", optional: true}`), or remove the forwarder entry from
        your sigra_config/0 `audit: [forwarders: [...]]` block.
        See guides/recipes/companion-libs/threadline.md for full wiring.
        """)
      end
    end)

    :ok
  end
```

### 2.5 Wrap precedent — `Sigra.Workers.AuditCleanup` (audit_cleanup.ex:1) — D-18

```elixir
if Code.ensure_loaded?(Oban.Worker) do
  defmodule Sigra.Workers.AuditCleanup do
    @moduledoc """
    ...
    """
    use Oban.Worker, ...
```

`Sigra.Workers.AuditForward` follows this exact outer-wrap shape (D-18). Threadline impl
gets the same treatment, wrapping against `Threadline` itself.

### 2.6 Behaviour + Noop mirror — `Sigra.RateLimiter` (rate_limiter.ex:1-26) — D-04 voice

Full module:

```elixir
defmodule Sigra.RateLimiter do
  @moduledoc """
  Behaviour for rate limiting implementations.

  Sigra supports both IP-based and account-based rate limiting. When
  Hammer is available, `Sigra.RateLimiters.Hammer` provides the
  implementation. When Hammer is absent, `Sigra.RateLimiters.Noop`
  is used as a fail-open fallback with a logged warning.

  ## Return Values

  Rate limiters return tagged tuples following Hammer's convention:

  - `{:allow, count}` -- request allowed, `count` is the current request count
  - `{:deny, retry_after_ms}` -- request denied, `retry_after_ms` indicates when to retry

  ## Mox Usage

      Mox.defmock(MockRateLimiter, for: Sigra.RateLimiter)
  """

  @doc "Checks whether a request identified by `key` should be allowed."
  @doc since: "0.1.0"
  @callback check_rate(key :: String.t(), limit :: pos_integer(), window_ms :: pos_integer()) ::
              {:allow, count :: pos_integer()} | {:deny, retry_after_ms :: pos_integer()}
end
```

**Phase 131 mirror (planner draft for `Sigra.Audit.Forwarder`):**

```elixir
defmodule Sigra.Audit.Forwarder do
  @moduledoc """
  Behaviour for audit-event forwarders.

  A forwarder subscribes (in `attach/1`) to the `[:sigra, :audit, :log]` telemetry
  event and ships committed audit rows to a downstream sink (Threadline, Datadog,
  Honeycomb, OpenTelemetry, in-house). Sigra's `audit_events` table remains the
  source of truth — forwarders are post-commit projections.

  Sigra ships `Sigra.Audit.Forwarders.Threadline` (when `:threadline` is present)
  and `Sigra.Audit.Forwarders.Noop` (fail-open fallback). Hosts can implement
  their own forwarder by `@behaviour`-ing this module and registering it in their
  `sigra_config/0` `audit: [forwarders: [...]]` list.

  ## Mox Usage

      Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)
  """

  @doc "Attaches the forwarder. Called once from Sigra.Application.start/2."
  @doc since: "0.4.0"
  @callback attach(opts :: keyword()) :: :ok | {:error, term()}
end
```

The Hammer impl precedent (`rate_limiters/hammer.ex:27-40`) is the `try/rescue` failure
isolation pattern — D-19's `try/rescue/catch` block in the Threadline impl mirrors this
voice exactly.

### 2.7 Noop mirror — `Sigra.RateLimiters.Noop` (rate_limiters/noop.ex:1-21) — D-22/D-24

Full module (the one the planner stamps directly with rename + behaviour swap):

```elixir
defmodule Sigra.RateLimiters.Noop do
  @moduledoc """
  No-op rate limiter that always allows requests.

  > #### Warning {: .warning}
  >
  > This is a fallback implementation used when no rate limiting library
  > (such as Hammer) is configured. It provides **no actual rate limiting**.
  > For production use, configure a real rate limiter.

  This module is used automatically when the `:limiter` config option is
  `nil` and Hammer is not available. A warning is logged once at startup.
  """

  @behaviour Sigra.RateLimiter

  @impl Sigra.RateLimiter
  def check_rate(_key, _limit, _window_ms) do
    {:allow, 1}
  end
end
```

**Phase 131 mirror for `Sigra.Audit.Forwarders.Noop` (per D-22 + D-24):**

```elixir
defmodule Sigra.Audit.Forwarders.Noop do
  @moduledoc """
  No-op audit forwarder.

  > #### Warning {: .warning}
  >
  > This is a fallback used when a forwarder is configured (e.g. Threadline)
  > but its dep is not loaded. It silently drops events. The upstream
  > `Logger.warning` is emitted from `Sigra.Application.start/2`
  > (see `maybe_warn_missing_forwarder_deps/0`), not from here — this module
  > does not subscribe to telemetry and does not log.
  """

  @behaviour Sigra.Audit.Forwarder

  @impl Sigra.Audit.Forwarder
  def attach(_opts), do: :ok
end
```

D-23 is explicit: the warning lives upstream in `Sigra.Application`, not in Noop.

### 2.8 Boot-time resolve-with-fallback pattern — `Sigra.Plug.RateLimit.resolve_limiter/1` (plug/rate_limit.ex:84-95)

```elixir
  defp resolve_limiter(nil) do
    if Code.ensure_loaded?(Hammer) do
      Sigra.RateLimiters.Hammer
    else
      Logger.warning(
        "[Sigra] No rate limiter configured. Using Noop (fail-open). " <>
          "Add :hammer to your deps for IP rate limiting."
      )

      Sigra.RateLimiters.Noop
    end
  end

  defp resolve_limiter(module), do: module
```

**D-23 maps directly:** the equivalent split for Phase 131 is "if the configured
forwarder module is not loaded, attach Noop instead and (upstream from
`Sigra.Application`) log one warning." `attach_forwarders/0` is the resolve point.

### 2.9 `Sigra.Config` `:audit` schema (config.ex:793-820) — D-05 extension point

Current entry (must be edited in place; do NOT add a new top-level key):

```elixir
    audit: [
      type: :keyword_list,
      default: [],
      doc: "Structured audit logging options (Phase 9). See `Sigra.Audit`.",
      keys: [
        audit_schema: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "The generated AuditEvent schema module. Default: nil."
        ],
        retention_days: [
          type: {:or, [:pos_integer, nil]},
          default: nil,
          doc: "Days to retain audit events. nil = keep forever (D-09). Default: nil."
        ],
        max_metadata_bytes: [
          type: :pos_integer,
          default: 8_192,
          doc: "Cap on JSON-encoded metadata byte size (D-20). Default: 8192."
        ],
        reserved_prefixes: [
          type: {:list, :string},
          default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.),
          doc:
            "Reserved action prefixes developers cannot use (D-17, D-18). Default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.)."
        ]
      ]
    ]
```

The matching struct stanzas (config.ex:854 + 888) are already `audit: keyword()` /
`audit: []` — **no struct change needed**, the schema extension is additive within the
existing `audit` key (see §3 for the exact schema text). The struct definition (lines
823-855 type + 857-889 defstruct) does not require modification.

### 2.10 `mix.exs` `no_warn_undefined` (mix.exs:65-87) — D-18 extension list

```elixir
  defp elixirc_options do
    [
      no_warn_undefined: [
        # Optional deps (mix.exs: optional: true)
        Bcrypt,
        Hammer,
        Swoosh.Email,
        Oban,
        Oban.Worker,
        Oban.Job,
        Assent.Strategy.Apple,
        Assent.Strategy.Facebook,
        Assent.Strategy.Github,
        Assent.Strategy.Google,
        Joken,
        Joken.Signer,
        Joken.Config,
        EQRCode,
        # Internal modules defined only when an optional dep is loaded
        Sigra.Workers.AccountDeletion,
        Sigra.Workers.AuditCleanup,
        Sigra.Workers.EmailDelivery,
        Sigra.Workers.TokenCleanup
      ]
    ]
  end
```

**Phase 131 additions (planner appends, preserving section comments):**

Optional-deps section (alphabetical by precedent — insert after `Swoosh.Email`):

```elixir
        Threadline,
        Threadline.ActorRef,
        Threadline.AuditChange,
        Threadline.AuditTransaction,
```

Internal-modules section (insert after `Sigra.Workers.EmailDelivery` to keep alphabetical):

```elixir
        Sigra.Workers.AuditForward,
```

Also add the optional Threadline dep to `defp deps` at the existing optional-deps block
(mix.exs:101-111, between `:joken` and `:nimble_totp` or at the end of the
optional cluster):

```elixir
      {:threadline, "~> 0.5", optional: true},
```

The `~> 0.5` constraint matches STACK.md's verified pin and Threadline's 0.x release
posture.

### 2.11 Host wiring precedent — `test/example/lib/example/accounts.ex:590-622`

Current `audit:` block (lines 604-609):

```elixir
      # Activate Sigra's built-in audit integration. Without this wiring,
      # Sigra.Audit.log_safe/2 is a silent no-op and no audit rows are
      # written for session.create, auth.login.*, etc.
      audit: [
        audit_schema: Example.Accounts.AuditEvent
      ],
```

**Phase 135 (not Phase 131) extends this** — Phase 131 only needs the schema to *accept*
the `forwarders:` key; the example host wiring lands in Phase 135. The planner should
NOT add a `forwarders:` block to `test/example` in Phase 131. (Mentioned here so the
planner can confirm the file is read-only context, not an edit target.)

The example app's `otp_app` is `:example` (`test/example/config/config.exs:41`:
`config :sigra, :otp_app, :example`), which is what
`Application.get_env(otp_app, :sigra_config)` returns — confirming the boot helpers'
config-lookup path works in the example app for Phase 135.

## 3. NimbleOptions Schema Verification

**Verified `[CITED: hexdocs.pm/nimble_options]` 2026-05-27:** NimbleOptions 1.1.x
supports `{:list, {:keyword_list, keys}}` as a documented special-case syntax for "a
list of keyword lists where each keyword list has typed sub-keys."

Quoting the NimbleOptions docs verbatim (per WebFetch 2026-05-27):

> "If `subtype` is a keyword list or map, you won't be able to pass `:keys` directly.
> For this reason, `:keyword_list`, `:non_empty_keyword_list`, and `:map` are special
> cased and can be used as the subtype by using `{:keyword_list, keys}`,
> `{:non_empty_keyword_list, keys}` or `{:keyword_list, keys}`."

**Result: no hand-roll required.** The D-06 shape expresses cleanly:

```elixir
forwarders: [
  type: {:list, {:keyword_list, [
    module: [
      type: :atom,
      required: true,
      doc: "Module implementing the `Sigra.Audit.Forwarder` behaviour."
    ],
    dispatch: [
      type: {:in, [:auto, :async, :sync]},
      default: :auto,
      doc: "Per-forwarder dispatch policy. Mirrors email[:delivery_mode]."
    ],
    id: [
      type: :atom,
      default: :default,
      doc: "Handler-id key — supports multiple attach calls of the same impl."
    ]
  ]}},
  default: [],
  doc: "Audit forwarders (Phase 131, v1.29 SUITE-INTEGRATION). Each entry is a keyword list with :module, :dispatch, :id, and arbitrary impl-specific keys (e.g. Threadline carries :endpoint, :api_key)."
]
```

**Caveat the planner must surface:** the impl-specific keys (`:endpoint`, `:api_key`,
`:repo`, `:audit_schema`, `:oban`, `:audit_event_id` strategy) are **NOT** validated by
this schema — NimbleOptions cannot express "arbitrary additional keys." That is by
design (D-08: custom host forwarders carry arbitrary keys). Two acceptable
implementations:

1. **Recommended:** validate only the canonical four keys (`:module`, `:dispatch`,
   `:id`, plus require `:module`). Anything else passes through as opaque opts to the
   forwarder's `attach/1`. Each impl validates its own keys at attach time. This is
   what the existing `oauth[:providers]` shape does (`lib/sigra/config.ex:40`
   `providers: [type: :keyword_list, default: [], doc: "Provider configurations."]`
   — note no `keys:` block).

2. **Alternative:** add `:allow_unknown` (a NimbleOptions option for keyword-list-typed
   keys) if available in 1.1.x. The planner should verify whether `:keys` with
   `:keep_unknown` or equivalent exists in 1.1.x; if not, default to option 1.

**Threadline-specific opts validated *inside* `Sigra.Audit.Forwarders.Threadline.attach/1`:** the
impl pulls its own NimbleOptions sub-schema at attach time for `:endpoint`, `:api_key`,
`:repo`, `:audit_schema`. This keeps the cross-impl seam minimal (D-08) and lets
Datadog/Honeycomb implement different option shapes.

**Fallback if NimbleOptions cannot express the desired shape after the planner
verifies:** (a) hand-roll a `validate_forwarders/1` in `Sigra.Config` that returns
`{:ok, list}` / `{:error, NimbleOptions.ValidationError}`; (b) flatten the shape to
`forwarders: [{Module, [opts]}, ...]` (tuple-list); (c) skip schema validation for the
forwarder sub-keys (matches the `oauth[:providers]` precedent). The planner picks
based on what NimbleOptions accepts at compile time.

**Recommendation:** option 1 above. The `oauth[:providers]` precedent already exists in
the same file (`config.ex:40`), is well-understood, and survives NimbleOptions version
bumps.

## 4. Threadline Hex Re-verification (2026-05-27)

| Property | Value | Source |
|----------|-------|--------|
| Latest version | `0.5.0` | hex.pm/packages/threadline (re-fetched 2026-05-27) |
| Publish date | 2026-05-08 | same |
| Constraint to pin | `~> 0.5` | matches STACK.md (HIGH confidence); appropriate for 0.x — minors may break per Hex convention |
| `record_action/2` signature | `record_action(name, opts \\ [])` | hexdocs.pm/threadline/Threadline.html |
| Required opts | `:actor` or `:actor_ref` (`%ActorRef{}`), `:repo` | same |
| Documented optional opts | `:status`, `:verb`, `:category`, `:reason`, `:comment`, `:correlation_id`, `:request_id`, `:job_id` | same |
| Return values | `{:ok, %AuditAction{}}` / `{:error, %Ecto.Changeset{}}` / `{:error, :missing_actor}` / `{:error, :invalid_actor_ref}` / `{:error, :missing_repo}` | same |
| **Native idempotency-key option** | **None documented** | same |

**Implication for D-31 + Pitfall 4 idempotency:** Threadline does not expose a native
`external_id` / `dedupe_key` parameter. The planner has three viable paths:

1. **Send audit UUID as `:correlation_id`** — `correlation_id` is a documented optional
   parameter (per hexdocs). This is the closest semantic match. Threadline-side
   uniqueness on `correlation_id` becomes a host-managed concern (recipe documents an
   optional unique index on the Threadline table). **Recommended for v1.29.**

2. **Embed UUID + `occurred_at` in the Threadline event's metadata payload** — less
   ergonomic but works with stock Threadline. Host queries on metadata can dedupe at
   read time.

3. **Defer cross-system dedupe to Threadline 0.6 / 1.0** when (if) a native idempotency
   key lands — accept duplicate Threadline rows on Oban retry in v1.29, document in
   recipe Failure Modes section.

CONTEXT.md D-9 second bullet leaves this to the planner (Claude's discretion). **The
research recommendation is path 1.** Phase 132's recipe research will confirm whether
`correlation_id` survives Threadline-side uniqueness as a dedupe vector.

## 5. Implementation Order

CONTEXT.md does not lock a build order; this is research recommendation only. Honor
sequencing where compilation depends on it (behaviour must be loaded before impls); the
rest is a suggestion.

**Hard sequencing (compile-time dependencies):**

1. **`lib/sigra/audit/forwarder.ex`** — behaviour. Single `@callback attach(keyword) :: :ok | {:error, term()}`. Mirrors `Sigra.RateLimiter` exactly (§2.6).
2. **`lib/sigra/audit/forwarders/noop.ex`** — `@behaviour Sigra.Audit.Forwarder` + `def attach(_opts), do: :ok`. Mirrors `Sigra.RateLimiters.Noop` (§2.7).
3. **`lib/sigra/audit/forwarders/threadline.ex`** — `@behaviour Sigra.Audit.Forwarder` + `attach/1` + `handle_event/4`. Entire `defmodule` wrapped in `if Code.ensure_loaded?(Threadline) do`. `handle_event/4` body wrapped in `try / rescue _ -> ... / catch _, _ -> ... end` (D-19). On caught failure, emit `[:sigra, :audit, :forward, :error]` and return `:ok` to `:telemetry` (D-20 — never raise to telemetry).
4. **`lib/sigra/workers/audit_forward.ex`** — optional Oban worker wrapped in `if Code.ensure_loaded?(Oban.Worker) do` (§2.5). `use Oban.Worker, queue: :sigra_audit_forward, max_attempts: 5` (D-14). `backoff/1` mirrors `EmailDelivery` curve verbatim (§2.3). `perform/1` reloads the audit row by `audit_event_id` from `repo + audit_schema`, then calls `forwarder_module.handle_event/4`-equivalent path (or a shared `Sigra.Audit.Forwarders.dispatch/3` per D-10 Claude's-discretion). Cancel taxonomy (D-16) follows `EmailDelivery` idiom.
5. **`lib/sigra/audit.ex` `emit_telemetry/1` extension** — additive metadata keys `id` + `occurred_at` per D-31 (§2.1). Can land anytime after step 1.
6. **`lib/sigra/config.ex` `:audit` schema extension** — add `:forwarders` sub-key per §3 + D-05/D-06. Can land anytime after step 1, but must land before step 7 because the boot helpers `Keyword.get(:forwarders, [])` from this schema.
7. **`lib/sigra/application.ex` boot helpers** — `maybe_warn_missing_forwarder_deps/0` + `attach_forwarders/0` per §2.4 + D-25/D-26/D-27. Adds two calls to `start/2`. The raise on `:async + no Oban` (D-26) lives in `attach_forwarders/0`.
8. **`mix.exs` `no_warn_undefined` + `deps` extension** — §2.10. Must land last because compile validation depends on the module files existing first.

**Test files (parallel to implementation, separated for clarity):**

- `test/sigra/audit/forwarder_test.exs` — behaviour contract test (Mox-defmock + custom forwarder attaches successfully — Success Criterion #5).
- `test/sigra/audit/forwarders/threadline_test.exs` — happy path (telemetry → Threadline.record_action call), failure isolation (Threadline raises → `:forward, :error` event fires, no auth rollback), idempotency strategy (UUID surfaces in payload).
- `test/sigra/audit/forwarders/noop_test.exs` — `attach/1` returns `:ok`, does not subscribe.
- `test/sigra/workers/audit_forward_test.exs` — perform happy path + cancel taxonomy + backoff + audit-event-not-found.
- `test/sigra/application_test.exs` (extend existing if present) — `:async + no Oban` raises; missing-dep emits warning.

**Sequencing-relaxed (do-in-any-order after step 1):** behaviour file (1), audit.ex
emit_telemetry extension (5), and config schema extension (6) are all independent.
Steps 2-4 depend on step 1. Steps 7-8 depend on everything else.

## 6. Validation Architecture (Nyquist Dimension 8)

All v1.29 work runs against the live Postgres at `localhost:5432`
(`postgres`/`postgres`) per `./CLAUDE.md` "Local development prerequisites" — there is
no `:postgres` tag exclusion. The Phase 131 `:integration` tag below means "requires
the audit_events table to be migrated in the test repo," which is already the case for
the existing `test/sigra/audit/` suite. No new CI infrastructure required.

| # | Success Criterion | Test Type | Sampling Boundary | Failure Observability | Tag |
|---|-------------------|-----------|-------------------|----------------------|-----|
| 1 | Threadline present + configured → audit commit produces matching Threadline row with UUID+occurred_at as canonical key; `[:sigra, :audit, :forward, :ok]` fires | integration | per-PR (full suite) | Telemetry event NOT fired = test fails; Threadline row missing = test fails; metadata `id` mismatch = test fails | `:integration` (Postgres required) |
| 2 | Threadline absent → `mix compile && mix test` green; one boot `Logger.warning` per configured-but-missing forwarder; Noop substitutes | dep-off CI lane (existing v1.21 HARD-02 model) | per-PR | Compile warning = lane fails; missing Logger.warning = lane fails; Noop not attached = downstream tests would fail | `:dep_off` (new lane — runs without `:threadline` in `mix.lock`) |
| 3 | Forced Threadline failure → `[:sigra, :audit, :forward, :error]` fires; originating Sigra audit row remains committed in DB | integration | per-PR | DB row count after failure = 1 (audit table); telemetry event matchcount = 1 (:error); auth flow returns `:ok` | `:integration` |
| 4 | `:auto`/`:async`/`:sync` dispatch matches `Sigra.Delivery` semantics; `:async` raises at boot if Oban absent | unit + boot-error contract | per-PR | Boot raise message contains forwarder name + dep name + `:auto` recommendation; `:auto` picks worker when Oban supervised, inline otherwise | `:unit` for dispatch; boot test runs with Oban supervised vs not |
| 5 | Custom forwarder via `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` successfully attaches; same path Threadline uses | unit (contract) | per-PR | `Mox.expect/2` on `attach/1` not called = test fails; behaviour mismatch = compile-time `@impl` warning | `:unit` |

**Sampling rates:**
- Per task commit: `mix test test/sigra/audit/` (existing CI alias)
- Per wave merge: `mix test` (root) — runs everything except `test/example/` per `mix.exs:27-35`
- Phase gate (Phase 136): full suite + dep-off lane + `mix docs --warnings-as-errors` + `mix credo --strict` per PROOF-01

**Wave 0 gaps (test files that must exist before parallel implementation):**

- `test/sigra/audit/forwarder_test.exs` — behaviour contract test
- `test/sigra/audit/forwarders/threadline_test.exs` — impl tests
- `test/sigra/audit/forwarders/noop_test.exs` — fallback contract
- `test/sigra/workers/audit_forward_test.exs` — Oban worker tests
- (existing `test/sigra/audit/` directory already houses 7 sibling test files — pattern established; no new conftest needed)

The dep-off CI lane (`:dep_off`) is new — Phase 131 adds it as a planner-owned task or
defers to Phase 136 PROOF-01 (recommendation: add a Phase 131 task that lands the lane
alongside the impl, so the lane catches regressions during implementation rather than
at milestone close).

## 7. Open Questions for Planner

CONTEXT.md flagged three Claude's-discretion items; this research disposes of two and
leaves one for the planner.

### 7.1 Shared dispatcher location — Claude's-discretion bullet 1

CONTEXT.md says: "Whether the shared dispatcher lives in
`Sigra.Audit.Forwarders.dispatch/3` (a new module) or as a private function inside
`Sigra.Workers.AuditForward`."

**Research recommendation: new `Sigra.Audit.Forwarders.dispatch/3` module.** Two
reasons:

1. **Symmetry with `Sigra.Delivery`** — the existing dispatch precedent
   (`lib/sigra/delivery.ex:30-115`) is a standalone module, not a private function on
   the worker. Phase 131's `Sigra.Audit.Forwarders` namespace already exists (it hosts
   `Threadline` and `Noop`); adding a sibling `dispatch/3` keeps the parallel clean.
2. **D-11 enforcement** — D-11 says "Threadline impl owns ONLY the Threadline-specific
   payload mapping; dispatch stays shared." If dispatch lives inside the worker, custom
   forwarders that bypass the worker (e.g. always-`:sync` shipping straight from
   `handle_event/4`) cannot reuse it. A standalone dispatcher is reachable from any
   forwarder.

### 7.2 Idempotency-key construction — Claude's-discretion bullet 2

CONTEXT.md says: "Whether the Threadline impl's per-event idempotency key is
`"#{uuid}:#{occurred_at}"` or just `uuid` (Sigra UUIDs are already unique;
`occurred_at` is belt-and-suspenders). Planner picks based on Threadline's API shape."

**Research finding (§4):** Threadline has no native idempotency-key parameter. The UUID
+ `occurred_at` pair lands on `correlation_id` (recommended) or in metadata. Whichever
landing spot, the planner picks ONE primary key (recommend just `uuid` — Sigra UUIDs
are v4 random, collision probability is negligible; `occurred_at` adds nothing on top
of a UUID).

### 7.3 Logger.warning message text — Claude's-discretion bullet 3

CONTEXT.md says: "Exact `Logger.warning` message text for the 'forwarder configured but
dep missing' case — mirror the tone of `maybe_warn_audit_cleanup_fallback/0`."

**Resolved** in §2.4 with a draft. Planner can adjust voice; the structural elements
(module name interpolated, recipe path linked, actionable fallback offered) are
mandatory. CONTEXT.md `<specifics>` line 200 enforces "link to the recipe path
(`guides/recipes/companion-libs/threadline.md`)" — that recipe file does not exist yet
(it ships in Phase 132). The Phase 131 warning text can reference the path as a forward
link; the file lands one phase later.

### 7.4 Unresolved (genuinely deferred — planner does not need to resolve in Phase 131)

- **Where impl-specific opts validation lives.** §3 recommends "each impl validates its
  own keys inside `attach/1`." The planner can either (a) document this convention in
  the behaviour moduledoc, or (b) leave it implicit and trust impl authors to follow
  the Threadline impl as precedent. (a) is slightly more disciplined; (b) is lighter.

## 8. Pitfalls Re-stated (LOUD)

These three landmines drove three of CONTEXT.md's locked decisions. The planner must
write acceptance criteria that catch each one explicitly.

### Pitfall 2: Boundary doctrine — forwarder failure NEVER rolls back the audit transaction

**From PITFALLS.md §Pitfall 2 (lines 41-71):** The Sigra audit DB row is
source-of-truth. Threadline is a post-commit projection. Failures in the forwarder
MUST NOT roll back the originating auth/audit transaction.

This is locked in D-21 ("boundary doctrine: forwarder ships events to a downstream
sink that can drop them; correctness comes from the Sigra audit DB row remaining
authoritative"). The planner writes:

- **Acceptance criterion:** "A deliberately failed Threadline write fires
  `[:sigra, :audit, :forward, :error]` AND the Sigra audit row count in Postgres is
  unchanged from before the test (== 1, not 0)."
- **Implementation guard:** the Threadline impl's `handle_event/4` is a separate
  process from the original auth `Repo.transaction/1`. Telemetry already fires only on
  `{:ok, _}` commit (audit.ex:286-302), so there is no transaction to roll back.

### Pitfall 4: Idempotency requires UUID + `occurred_at` propagation

**From PITFALLS.md §Pitfall 4 (lines 220-242):** Cross-system deduplication needs a
stable event ID. Sigra audit row's UUID + `occurred_at` are the canonical pair.

This is locked in D-31 (extend `emit_telemetry/1` to carry `id` + `occurred_at`). The
planner writes:

- **Acceptance criterion:** "After extension, `[:sigra, :audit, :log]` telemetry
  metadata contains both `:id` (UUID string) and `:occurred_at` (`DateTime`). A test
  asserts both keys are present with non-nil values."
- **Implementation guard:** §2.1 confirms both fields are guaranteed present on the
  audit event struct — `id` from `@primary_key {:id, :binary_id, autogenerate: true}`,
  `occurred_at` from `validate_required([:action, :outcome, :occurred_at])`.

### Handler auto-detach landmine (most dangerous failure mode)

**From PITFALLS.md handler-robustness lines 11-200 (paraphrased) and CONTEXT.md D-20:**
The `:telemetry` library AUTO-DETACHES any handler that raises. The auto-detach is
permanent for the lifetime of the BEAM — a single bad event silently disables audit
forwarding for the rest of uptime. The host has no signal this happened.

The planner writes:

- **Acceptance criterion:** "The Threadline impl's `handle_event/4` wraps its entire
  body in `try / rescue _kind, _reason -> ... / catch :exit, _ -> ... / catch :throw, _ -> ... end` (or
  the more compact `try / rescue / catch` with `:error`, `:exit`, `:throw` all caught).
  A test that injects a `raise/1` mid-handler asserts the handler stays attached for
  the SECOND event after the failed one."
- **Implementation guard:** D-19 + D-20 — `handle_event/4` returns `:ok` to telemetry
  on every code path, including caught failure. Never `:stop`, never raise.

This is the single most dangerous failure mode in the phase. Plan the acceptance
criterion for it in red ink.

## 9. Sources

### Primary (HIGH confidence — verified against repo HEAD 2026-05-27)

- `/Users/jon/projects/sigra/lib/sigra/audit.ex:286-310` — current `emit_telemetry/1` body
- `/Users/jon/projects/sigra/lib/sigra/audit/changeset.ex:30-45` — confirms `:occurred_at` cast field
- `/Users/jon/projects/sigra/lib/sigra/application.ex:21-27, 68-88` — boot hook precedent
- `/Users/jon/projects/sigra/lib/sigra/config.ex:793-820` — `:audit` schema
- `/Users/jon/projects/sigra/lib/sigra/config.ex:854-889` — config struct (no change needed)
- `/Users/jon/projects/sigra/lib/sigra/delivery.ex:30-36, 103-115` — dispatch + `oban_running?/0`
- `/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex:1-26` — behaviour + Mox moduledoc precedent
- `/Users/jon/projects/sigra/lib/sigra/rate_limiters/noop.ex:1-21` — Noop shape precedent
- `/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex:27-40` — `try/rescue` failure isolation precedent
- `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:32-103` — Oban worker + `backoff/1` + cancel taxonomy
- `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex:1` — `if Code.ensure_loaded?(Oban.Worker) do` wrap precedent
- `/Users/jon/projects/sigra/lib/sigra/telemetry.ex:341-348` — `attach_default_logger` handler-id precedent
- `/Users/jon/projects/sigra/lib/sigra/plug/rate_limit.ex:84-97` — `resolve_limiter/1` with `Code.ensure_loaded?` + `Logger.warning`
- `/Users/jon/projects/sigra/mix.exs:63-88, 90-124` — `no_warn_undefined` block + deps
- `/Users/jon/projects/sigra/test/example/lib/example/accounts.ex:590-622` — host wiring (Phase 135 edit target, not Phase 131)
- `/Users/jon/projects/sigra/test/example/config/config.exs:41` — `config :sigra, :otp_app, :example`
- `/Users/jon/projects/sigra/priv/templates/sigra.install/core/audit_event.ex:20-33` — confirms audit event PK is `binary_id` UUID

### Primary (HIGH confidence — verified against external sources 2026-05-27)

- [hex.pm/packages/threadline](https://hex.pm/packages/threadline) — `0.5.0`, 2026-05-08 (still latest)
- [hexdocs.pm/threadline/Threadline.html](https://hexdocs.pm/threadline/Threadline.html) — `record_action/2` signature; documented optional opts; no native idempotency-key parameter
- [hexdocs.pm/nimble_options/NimbleOptions.html](https://hexdocs.pm/nimble_options/NimbleOptions.html) — `{:list, {:keyword_list, keys}}` special-case syntax documented for NimbleOptions 1.1.x

### Planning artifacts (HIGH confidence)

- `/Users/jon/projects/sigra/.planning/phases/131-forwarder-behaviour-threadline-forwarder-library-scaffolding/131-CONTEXT.md` — locked decisions D-01..D-33
- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` — TL-01..TL-05 + FB-01
- `/Users/jon/projects/sigra/.planning/ROADMAP.md:61-73` — Phase 131 Success Criteria #1-#5
- `/Users/jon/projects/sigra/.planning/research/SUMMARY.md` — locked stack + build order + naming rationale
- `/Users/jon/projects/sigra/.planning/research/ARCHITECTURE.md:79-265` — Phase 131 file-by-file plan
- `/Users/jon/projects/sigra/.planning/research/PITFALLS.md` — Pitfall 2 (boundary doctrine, lines 41-71), Pitfall 4 (idempotency, lines 220-242), handler robustness (woven through lines 11-200)
- `/Users/jon/projects/sigra/.planning/research/STACK.md:25-37` — Threadline 0.5.0 publish status

## 10. Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Threadline `record_action/2` will accept the audit row's UUID via `:correlation_id` as an effective idempotency key | §4, §7.2 | Phase 132 recipe verification surfaces this — if `correlation_id` doesn't dedupe Threadline-side, fall back to metadata-embedded UUID + recipe-documented unique index. Low risk because Phase 131 doesn't actually invoke `record_action/2`; the planner punts the specific landing spot to the Threadline impl, which Phase 132 exercises end-to-end. |
| A2 | NimbleOptions 1.1.x `{:list, {:keyword_list, keys}}` validation rejects malformed entries at `Sigra.Config.new!/1` compile time, not lazily | §3 | If validation is lazy, the boot-time `attach_forwarders/0` becomes the failure surface instead of the config struct — still safe (boot raise on malformed shape), just less ergonomic. The planner can verify by writing a Wave 0 unit test that asserts `Sigra.Config.new!(audit: [forwarders: [[:bad_shape]]])` raises `NimbleOptions.ValidationError`. |
| A3 | The "raise at boot when `:async` + no Oban" landing spot is `attach_forwarders/0` (D-26), not the dispatcher | §5 step 7, §6 row 4 | If the raise fires lazily on first event, the misconfig surfaces at first authenticated request (bad UX). D-26 is explicit on boot-time fail; just confirming. |
| A4 | The dep-off CI lane shipping in Phase 131 (vs deferred to Phase 136) is the lower-risk choice | §6 last paragraph | If deferred, regressions ship into Phase 132+ without detection. Recommendation: land the lane in Phase 131. The planner picks based on phase budget. |

Items A1 and A3 are flagged in §7 as Claude's-discretion or planner-verification items.
A2 is verifiable in Wave 0. A4 is a phase-scope decision for the planner.

## 11. Metadata

**Confidence breakdown:**
- Standard stack & verified excerpts: HIGH — every line range read from HEAD on `v1.28-data-lifecycle`, 2026-05-27.
- NimbleOptions shape verification: HIGH — directly quoted from hexdocs.pm.
- Threadline Hex re-verification: HIGH — hex.pm fetched 2026-05-27 confirms 0.5.0 still latest.
- Threadline API landing spot (idempotency key): MEDIUM — `correlation_id` is documented but its dedupe behavior is Threadline-implementation-specific; Phase 132 will verify against the recipe.
- Pitfalls re-statement: HIGH — re-grounded in PITFALLS.md primary research.

**Research date:** 2026-05-27
**Valid until:** 2026-06-27 (30 days for stable library architecture; Threadline release cadence is the only fast-moving variable — re-check before Phase 132 recipe ships)

## RESEARCH COMPLETE

Phase 131 research grounds all 33 locked CONTEXT.md decisions in exact line-range
evidence; verifies NimbleOptions can express the D-06 schema natively; re-confirms
Threadline 0.5.0 is current; surfaces one Threadline-API gap (no native
idempotency-key option) the planner must dispose of via `:correlation_id`; and
spotlights the three pitfalls (boundary doctrine, idempotency propagation, handler
auto-detach) that drive Phase 131's acceptance criteria. Ready for `/gsd-plan-phase 131`.
