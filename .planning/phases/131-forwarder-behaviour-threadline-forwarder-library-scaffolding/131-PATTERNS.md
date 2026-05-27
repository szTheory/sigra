# Phase 131: Forwarder Behaviour + Threadline Forwarder Library Scaffolding — Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 15 (10 NEW, 5 MODIFIED)
**Analogs found:** 15 / 15 (every file has an in-repo precedent — research already grounded each in line-range citations)

## Conventions for cross-referencing

- "**(see RESEARCH.md §X)**" → the exact code excerpt the planner needs already lives in RESEARCH.md; do not re-quote it here.
- "Verified" → I read the analog file at HEAD on `v1.28-data-lifecycle` and confirmed the cited line range.
- D-XX → decision in `131-CONTEXT.md`.
- Every analog path is absolute.

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality | D-XX grounding |
|---|---|---|---|---|---|
| **NEW** `lib/sigra/audit/forwarder.ex` | behaviour (single callback) | contract-only | `/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex` (1-26) | EXACT structural mirror | D-01, D-04, D-32, D-33 |
| **NEW** `lib/sigra/audit/forwarders/noop.ex` | fail-open fallback impl | no-op | `/Users/jon/projects/sigra/lib/sigra/rate_limiters/noop.ex` (1-21) | EXACT structural mirror | D-22, D-23, D-24 |
| **NEW** `lib/sigra/audit/forwarders/threadline.ex` | telemetry-tap impl | event-driven (`:telemetry.attach` → `handle_event/4` → optional Oban enqueue) | `/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex` (1-47) for `try/rescue` voice + impl shape; `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex` (1) for outer `Code.ensure_loaded?` wrap | Role match (impl + optional-dep wrap); pattern composed from two analogs | D-03, D-10, D-11, D-19, D-20, D-21 |
| **NEW** `lib/sigra/audit/forwarders.ex` (dispatcher) | dispatch router | request-response routing (`:auto`/`:async`/`:sync`) | `/Users/jon/projects/sigra/lib/sigra/delivery.ex` (1-116) — particularly `delivery_mode/1` (103-108) + `oban_running?/0` (113-115) | EXACT semantic mirror (different domain) | D-10, D-11, D-12, D-26 |
| **NEW** `lib/sigra/workers/audit_forward.ex` | optional Oban worker | batch (Oban job → reload audit row → forward) | `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex` (1-103) for `use Oban.Worker` + `backoff/1` + cancel taxonomy; `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex` (1, 31-33) for outer `Code.ensure_loaded?(Oban.Worker)` wrap | EXACT structural mirror (two-analog compose) | D-13, D-14, D-15, D-16, D-17, D-18 |
| **MODIFIED (additive)** `lib/sigra/audit.ex` | existing module — extend `emit_telemetry/1` metadata | event emission | self (`lib/sigra/audit.ex:286-310`) — additive metadata-map extension | Self-referential (RESEARCH.md §2.1 has full verbatim excerpt) | D-31 |
| **MODIFIED** `lib/sigra/application.ex` | OTP `Application` callback — add 2 helpers + 2 calls | boot-time one-shot | self (`lib/sigra/application.ex:68-88` for `maybe_warn_audit_cleanup_fallback/0`; `21-27` for `start/2` call sequence; `30-38, 92-101` for config-lookup pattern); also `lib/sigra/plug/rate_limit.ex:84-95` for `Code.ensure_loaded?` + `Logger.warning` voice (D-23 split) | Self-referential (one-shot warning idiom is the literal precedent) | D-02, D-25, D-26, D-27 |
| **MODIFIED** `lib/sigra/config.ex` | NimbleOptions schema — add `:forwarders` sub-key under `:audit` | config validation | `lib/sigra/config.ex:434-458` (the `email:` block with `delivery_mode:`) for per-entry dispatch-knob precedent; `lib/sigra/config.ex:793-820` for the in-place `audit:` block to extend | EXACT (precedent is in the same file) | D-05, D-06, D-07, D-08, D-09 |
| **MODIFIED** `mix.exs` | compile-time hint list + optional dep | config | `mix.exs:65-87` (existing `no_warn_undefined` list); `mix.exs:101-111` (optional-deps cluster in `defp deps`) | EXACT (same-file precedent) | D-18 (corollary) |
| **NEW / DEFERRABLE** `.github/workflows/ci.yml` (dep-off CI lane) | CI config | batch | RESEARCH.md §6 row 2 (`:dep_off` tag spec); v1.21 HARD-02 dep-off lane precedent | Out-of-scope option flagged for planner — see "Planner discretion" section below | — |
| **NEW** `test/sigra/audit/forwarder_test.exs` | test (behaviour contract) | unit | `test/sigra/workers/behaviour_test.exs` (1-29) | Role match (behaviour-contract test with stub-module pattern) | D-01, D-04 |
| **NEW** `test/sigra/audit/forwarders/noop_test.exs` | test (fallback contract) | unit | (no existing `noop_test.exs` — closest is `test/sigra/audit/changeset_test.exs` for the AAA + `Sigra.Test.AuditEvent` import idiom) | Pattern compose | D-22 |
| **NEW** `test/sigra/audit/forwarders/threadline_test.exs` | test (impl + failure isolation + idempotency) | unit + integration | `test/sigra/rate_limiters/hammer_test.exs` (1-30) for impl-with-stub-dep idiom (`MockHammer` analog → `MockThreadline`) | Role match | D-19, D-20, D-31 |
| **NEW** `test/sigra/audit/forwarders/dispatch_test.exs` | test (dispatch routing) | unit | `test/sigra/audit/changeset_test.exs` (1-30) for AAA scaffold style — there is no existing `delivery_test.exs` direct sibling under `test/sigra/`; choose dispatch routing assertions modeled on `Sigra.Delivery` source semantics | Pattern compose | D-10, D-12, D-26 |
| **NEW** `test/sigra/workers/audit_forward_test.exs` | test (Oban worker) | unit | `test/sigra/workers/audit_cleanup_test.exs` (1-40) for Wave 0 scaffold + `StubRepo` + cancel-taxonomy assertion style | EXACT (same directory + same era) | D-13, D-16, D-17 |

## Pattern Assignments

Sequenced by §5 of RESEARCH.md (compile-time dependency order).

---

### 1. `lib/sigra/audit/forwarder.ex` (NEW — behaviour)

**Analog:** `/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex` lines 1-26 (full module — **see RESEARCH.md §2.6 for verbatim excerpt + the Phase 131 mirror draft**).

**Planner must keep EXACTLY identical to the analog:**

- Single `@callback` only; no second seam.
- `## Mox Usage` H2 in moduledoc + the one-line `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)` example (D-04).
- `@doc since: "0.4.0"` on the callback (v1.29 is shipping in 0.4.x per Sigra version cadence; planner verifies against `mix.exs` `@version`).

**May differ from the analog:**

- The callback signature itself: `attach(opts :: keyword()) :: :ok | {:error, term()}` (vs Hammer's `check_rate/3`).
- Moduledoc body text — written for the forwarder domain (audit projection downstream; Sigra audit row stays SoT; D-21 boundary doctrine). RESEARCH.md §2.6 second code block is the planner's literal draft.

**D-XX grounding:** D-01 (single `attach/1`), D-04 (Mox doc mirror), D-32 (keyword arg minimum keys documented in moduledoc, not validated by behaviour), D-33 (NO `handle_event/4` callback).

---

### 2. `lib/sigra/audit/forwarders/noop.ex` (NEW — fallback)

**Analog:** `/Users/jon/projects/sigra/lib/sigra/rate_limiters/noop.ex` lines 1-21 (full module — **see RESEARCH.md §2.7 for verbatim excerpt + the Phase 131 mirror draft**).

**Planner must keep EXACTLY identical to the analog:**

- `> #### Warning {: .warning}` ExDoc admonition block in moduledoc (D-24).
- `@behaviour Sigra.Audit.Forwarder` directly under `@moduledoc`.
- `@impl Sigra.Audit.Forwarder` on `attach/1`.
- `attach/1` body is literally `:ok` (D-22). NO `:telemetry.attach/4` call. NO `Logger` call (D-23 — warning lives upstream in `Sigra.Application`).

**May differ from the analog:**

- Moduledoc body text — adapted to forwarder domain ("silently drops events" vs "always allows requests").
- Reference to `maybe_warn_missing_forwarder_deps/0` instead of "logged once at startup" (D-23 calls this out explicitly).

**D-XX grounding:** D-22, D-23, D-24.

---

### 3. `lib/sigra/audit/forwarders/threadline.ex` (NEW — impl)

**Composed from two analogs:**

| Pattern slice | Analog | Lines |
|---|---|---|
| Outer `if Code.ensure_loaded?(Threadline) do` wrap | `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex` | 1 (**see RESEARCH.md §2.5**) |
| `try/rescue` failure isolation around impl body | `/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex` | 27-40 (verified — the `try / rescue _ -> Logger.warning(...); {:allow, 0} end` shape) |
| `@behaviour` + `@impl` markers, single `attach/1` then `handle_event/4` | (`Sigra.Audit.Forwarder` from §1 of this map) | — |

**Verified Hammer impl excerpt (lines 27-40, planner uses as `try/rescue` voice mirror):**

```elixir
  @impl Sigra.RateLimiter
  def check_rate(key, limit, window_ms) do
    module = hammer_module()

    try do
      # Hammer 7.x: hit(key, scale_ms, limit) -- note parameter order
      module.hit(key, window_ms, limit)
    rescue
      _ ->
        # Fail open per D-41 if Hammer GenServer not running
        Logger.warning("[Sigra] Hammer rate limiter unavailable, failing open")
        {:allow, 0}
    end
  end
```

**Planner must keep EXACTLY identical to the composed pattern:**

- Outer `if Code.ensure_loaded?(Threadline) do … end` wraps the entire `defmodule` (D-18; mirror precedent `audit_cleanup.ex:1`).
- `handle_event/4` body wrapped in `try / rescue _ -> ... / catch _, _ -> ... end` — **MUST catch all of `:error`, `:exit`, `:throw`** (D-19, D-20). The Hammer analog only catches `rescue _` (i.e. `:error`); the Threadline impl extends to `catch :exit, _` and `catch :throw, _` because D-20 calls auto-detach the worst failure mode and the planner CANNOT regress this.
- On any caught failure: emit `[:sigra, :audit, :forward, :error]` with `%{count: 1}` + metadata-with-`:kind` (D-29), and **return `:ok` to `:telemetry`** (D-20 — never raise to telemetry).
- Handler id derived from `{__MODULE__, opts[:id] || :default}` (D-03 — supports multiple attach calls; matches `lib/sigra/telemetry.ex:341-348` `@handler_name` idiom).

**May differ:**

- The `try`-body itself: builds Threadline call args from audit metadata (UUID + `occurred_at` → `:correlation_id` per §4/§7.2 recommendation), then calls `Sigra.Audit.Forwarders.dispatch/3` (D-10 — see #4).
- `attach/1` body: validates impl-specific keys via its own NimbleOptions sub-schema (RESEARCH.md §3 paragraph "Threadline-specific opts validated inside…"), calls `:telemetry.attach(handler_id, [:sigra, :audit, :log], &__MODULE__.handle_event/4, opts)`.

**D-XX grounding:** D-03, D-10, D-11, D-12, D-18, D-19, D-20, D-21, D-30.

---

### 4. `lib/sigra/audit/forwarders.ex` (NEW — shared dispatcher)

**Analog:** `/Users/jon/projects/sigra/lib/sigra/delivery.ex` lines 1-116 (full module — **see RESEARCH.md §2.2 for the verbatim `delivery_mode/1` + `oban_running?/0` excerpts** at lines 103-115).

**Verified `delivery.ex:103-115` (cited literally in §2.2):**

```elixir
  defp delivery_mode(opts) do
    case Keyword.get(opts, :delivery_mode, :auto) do
      :auto -> if oban_running?(), do: :async, else: :sync
      mode -> mode
    end
  end

  # :auto must only route to :async when Oban is actually supervised in the
  # host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
  # mix.exs without wiring the supervisor would otherwise crash on insert.
  defp oban_running? do
    Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil
  end
```

**Planner must keep EXACTLY identical to the analog:**

- `oban_running?/0` body — **byte-for-byte**, including the `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` two-arm check and the comment explaining the "compiled vs supervised" distinction (D-12 explicit: do not regress).
- The `:auto → if oban_running?(), do: :async, else: :sync / mode -> mode` case shape inside `dispatch_mode/1` (the Phase 131 equivalent of `delivery_mode/1`).

**May differ from the analog:**

- Module name: `Sigra.Audit.Forwarders` (the namespace already exists — it hosts `Threadline` and `Noop`; per RESEARCH.md §7.1 recommendation, dispatcher lives at this same namespace, not inside the worker).
- Option key: `:dispatch` instead of `:delivery_mode` (D-07: per-forwarder dispatch knob, not top-level — mirrors `email[:delivery_mode]` but lives inside each `forwarders[N]` keyword entry, not at `audit[:dispatch]`).
- Public function: `Sigra.Audit.Forwarders.dispatch(forwarder_module, event_metadata, opts) :: :ok | {:error, term}`. Per D-10 Claude's-discretion bullet 1 + RESEARCH.md §7.1, this is a NEW standalone module (not a private fn on the worker) so custom always-`:sync` forwarders can reuse it from `handle_event/4`.

**D-XX grounding:** D-10, D-11, D-12, D-26 (the boot-time `:async`-without-Oban raise lives in `Sigra.Application.attach_forwarders/0`, NOT in this dispatcher — the dispatcher only routes already-validated `:auto`/`:async`/`:sync` values).

---

### 5. `lib/sigra/workers/audit_forward.ex` (NEW — optional Oban worker)

**Composed from two analogs (both wrap patterns mandatory):**

| Pattern slice | Analog | Lines |
|---|---|---|
| Outer `if Code.ensure_loaded?(Oban.Worker) do` wrap | `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex` | 1, 31-33 (**see RESEARCH.md §2.5**) |
| `use Oban.Worker, queue:, max_attempts:` + `perform/1` + `backoff/1` + cancel taxonomy + `Telemetry.span` | `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex` | 1-103 (**see RESEARCH.md §2.3** for the verbatim `backoff/1` body at 73-76, which the planner mirrors byte-for-byte per D-15) |

**Verified `email_delivery.ex:32-34` (the `use Oban.Worker` line — planner mirrors with `max_attempts: 5` per D-14):**

```elixir
    use Oban.Worker,
      queue: :sigra_mailer,
      max_attempts: 3
```

**Verified `email_delivery.ex:73-76` (the `backoff/1` curve — planner copies verbatim per D-15):**

```elixir
    @impl Oban.Worker
    def backoff(%Oban.Job{attempt: attempt}) do
      # Exponential backoff with jitter: ~15s, ~60s (per D-25)
      trunc(:math.pow(attempt, 4) + 15 + :rand.uniform(10) * attempt)
    end
```

**Planner must keep EXACTLY identical to the composed pattern:**

- Outer `if Code.ensure_loaded?(Oban.Worker) do … end` (D-18; analog `audit_cleanup.ex:1`).
- `use Oban.Worker` with `max_attempts: 5` (D-14 — note the deliberate bump from EmailDelivery's `max_attempts: 3` because audit retries don't user-spam).
- `backoff/1` body byte-for-byte from `email_delivery.ex:73-76` (D-15).
- Cancel-taxonomy idiom: `{:cancel, :audit_event_not_found}`, `{:cancel, :unknown_forwarder}`, `{:cancel, :schema_mismatch}` for non-retryable; `{:error, reason}` for retryable (D-16). The EmailDelivery analog uses the same `{:cancel, _atom}` vs `{:error, _}` idiom (e.g. `{:cancel, :user_not_found}` at `email_delivery.ex:52`; `{:cancel, "unknown email type: ..."}` at `email_delivery.ex:99`).
- `Telemetry.span([:sigra, :audit, :forward], …, fn -> … end)` wrapping the `perform/1` body — mirror `email_delivery.ex:40-69` literal voice.
- Job args = `%{"forwarder" => module_string, "audit_event_id" => uuid, "occurred_at" => iso8601}` only — **thin reference**, never the full payload (D-13 per T-3-INFRA-01; EmailDelivery's same-shape precedent at `email_delivery.ex:9-15` moduledoc + 50-69 perform body).
- `perform/1` reloads the audit row from `repo + audit_schema` (D-13) — same shape as EmailDelivery's `case repo.get(user_schema, args["user_id"])` at `email_delivery.ex:50-52`.
- Worker fires `[:sigra, :audit, :forward, :error]` on any non-`:ok` exit and **NEVER raises** (D-17). The originating audit transaction committed before enqueue; failure here cannot roll it back.

**May differ:**

- `queue:` value — `:sigra_audit_forward` (D-14), not `:sigra_mailer`.
- `resolve_config/0` reads from `Application.fetch_env!(:sigra, :sigra_config)` rather than four separate top-level keys (audit-domain modules live inside `audit:` keyword nested in `sigra_config`).
- The "reload" call uses `Application.get_env(otp_app, :sigra_config) |> Keyword.get(:audit) |> Keyword.fetch!(:audit_schema)` to find the schema module (D-32 enumerates `:audit_schema` + `:repo` as required keys in the forwarder's `attach/1` opts; the worker reconstructs them from the same opts on perform).

**D-XX grounding:** D-13, D-14, D-15, D-16, D-17, D-18.

---

### 6. `lib/sigra/audit.ex` (MODIFIED — additive metadata extension in `emit_telemetry/1`)

**Analog:** self. **See RESEARCH.md §2.1 for the verbatim current body of `emit_telemetry_from_changes/2` + `emit_telemetry/1` at lines 286-310**, and the exact two-key additive edit:

> "the metadata map must become `%{action: event.action, actor_id: event.actor_id, outcome: event.outcome, id: event.id, occurred_at: event.occurred_at}`."

**Planner must keep EXACTLY identical:**

- The function signature `defp emit_telemetry(event)` and the `:telemetry.execute/3` call shape — only the metadata map literally changes.
- The `@telemetry_event` module attribute reference (no change to event name).
- `%{count: 1}` measurements unchanged.

**May differ:**

- The metadata map adds two keys (`:id`, `:occurred_at`) — additive, backwards-compatible. RESEARCH.md §2.1 paragraph "Backwards-compatibility audit" confirms zero existing subscribers break.

**Pre-flight check (per RESEARCH.md §2.1):**

- `event.id` exists — confirmed in `priv/templates/sigra.install/core/audit_event.ex:21` (`@primary_key {:id, :binary_id, autogenerate: true}`).
- `event.occurred_at` exists — confirmed in `lib/sigra/audit/changeset.ex:40` (`@cast_fields`) + `lib/sigra/audit.ex:522` (`Keyword.get(opts, :occurred_at, DateTime.utc_now())`).

**D-XX grounding:** D-31 (cross-system dedupe canonical key per Pitfall 4).

---

### 7. `lib/sigra/application.ex` (MODIFIED — add 2 helpers + 2 call sites)

**Self-referential analog:** `maybe_warn_audit_cleanup_fallback/0` at `/Users/jon/projects/sigra/lib/sigra/application.ex` lines 68-88 (**see RESEARCH.md §2.4 for the verbatim current body + the planner-draft `maybe_warn_missing_forwarder_deps/0` at the end of §2.4**).

**Verified `start/2` call sequence (lines 21-27 — D-25 patches in two NEW calls in the order shown):**

```elixir
  @impl Application
  def start(_type, _args) do
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    verify_vault!()

    Supervisor.start_link([], strategy: :one_for_one, name: Sigra.Supervisor)
  end
```

**D-25 target sequence (planner edits to this exact ordering — see RESEARCH.md §2.4 trailing block):**

```elixir
    maybe_warn_audit_cleanup_fallback()
    maybe_warn_missing_cookie_domain()
    maybe_warn_missing_forwarder_deps()   # NEW (D-25)
    attach_forwarders()                    # NEW (D-25 + D-26 — raises if :async + no Oban)
    verify_vault!()
```

**Planner must keep EXACTLY identical to the precedent:**

- `@doc false` annotation on every new private-ish boot helper (matches `maybe_warn_audit_cleanup_fallback/0` line 67 + `maybe_warn_missing_cookie_domain/0` line 29).
- `Application.get_env(:sigra, :otp_app)` → `Application.get_env(otp_app, :sigra_config)` → `Keyword.get` cascade (D-27 explicit: **single config-resolution pattern across boot diagnostics; do NOT introduce a second pattern**). Lines 30-38 + 92-101 are both literal precedents for this idiom — mirror byte-for-byte.
- `Logger.warning("""…""")` heredoc voice + structure (RESEARCH.md §2.4 — describe gap, name the dep, link recipe path, offer actionable fallback). The planner-draft text in RESEARCH.md §2.4 trailing code block is the literal voice mirror.
- Cross-analog: `lib/sigra/plug/rate_limit.ex:84-95` `resolve_limiter/1` is the **"if dep loaded → use it; else log + use Noop"** split (D-23). `attach_forwarders/0` implements the same split at the forwarder level: for each entry, if `Code.ensure_loaded?(forwarder[:module])` → call `attach(opts)`; else skip (the Noop path is implicit — no attach is no-op).

**Verified `plug/rate_limit.ex:84-95` (the D-23 split precedent):**

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
```

**May differ:**

- The two new helpers exist in *this* module (`Sigra.Application`), not split across `Plug.RateLimit` + `Application`. The split is **temporal** (warn at boot, attach at boot) rather than **structural**.
- `attach_forwarders/0` adds D-26 logic: if any entry has `dispatch: :async` and `oban_running?/0` is false, **raise** with a message naming the forwarder + dep + `:auto` recommendation. This raise has no exact same-file precedent; the closest voice mirror is `verify_vault!/1` (lines 113-124) which raises a heredoc when passkeys are enabled but the vault module is a stub. Mirror that heredoc voice.

**D-XX grounding:** D-02, D-25, D-26, D-27.

---

### 8. `lib/sigra/config.ex` (MODIFIED — extend `:audit` NimbleOptions schema with `:forwarders`)

**Two precedents (both in the same file):**

| Pattern slice | Analog | Lines |
|---|---|---|
| The `:audit` block to extend in place | `lib/sigra/config.ex` | 793-820 (verified; the verbatim block is in **RESEARCH.md §2.9**) |
| Per-entry dispatch knob lives inside the keyword, not top-level | `lib/sigra/config.ex` `email[:delivery_mode]` | 434-458 (verified — see excerpt below) |

**Verified `email:` block (lines 434-458) — the precedent the planner mirrors for *placing* `:dispatch` inside each forwarder entry rather than at `audit[:dispatch]`:**

```elixir
    email: [
      type: :keyword_list,
      default: [],
      doc: "Email delivery options.",
      keys: [
        from_address: [
          type: :string,
          doc: "From address for transactional emails. Default derived from endpoint config."
        ],
        delivery_mode: [
          type: {:in, [:auto, :async, :sync]},
          default: :auto,
          doc: "Email delivery mode. :auto detects Oban presence. Default: :auto."
        ],
        ...
      ]
    ],
```

**The `:forwarders` schema entry the planner adds inside the existing `audit:` `keys:` block — see RESEARCH.md §3 for the canonical NimbleOptions shape:**

```elixir
forwarders: [
  type: {:list, {:keyword_list, [
    module:   [type: :atom, required: true, doc: "..."],
    dispatch: [type: {:in, [:auto, :async, :sync]}, default: :auto, doc: "..."],
    id:       [type: :atom, default: :default, doc: "..."]
  ]}},
  default: [],
  doc: "Audit forwarders (Phase 131, v1.29 SUITE-INTEGRATION). Each entry is a keyword list with :module, :dispatch, :id, and arbitrary impl-specific keys (e.g. Threadline carries :endpoint, :api_key)."
]
```

**Planner must keep EXACTLY identical:**

- The new key lives INSIDE the existing `audit:` `keys:` block at lines 797-819, NOT as a new top-level config key (D-05 explicit).
- `default: []` — empty list = no attach calls, no boot warnings, zero overhead (D-09).
- Per-entry `:dispatch` (NOT top-level `:dispatch`) — mirrors `email[:delivery_mode]` precedent (D-07).
- The struct type (lines 854) and defstruct (line 888) already declare `audit: keyword()` / `audit: []`. **No struct change needed** (verified — see RESEARCH.md §2.9 paragraph "The matching struct stanzas…").

**May differ — planner's choice (see RESEARCH.md §3 "Caveat the planner must surface"):**

- Whether to enumerate impl-specific keys (`:endpoint`, `:api_key`, `:repo`, `:audit_schema`, `:oban`) in the NimbleOptions `keys:` block (option 2: validated at config-build time) OR accept arbitrary opts via the `oauth[:providers]` precedent (option 1: validated inside each impl's `attach/1`, file `config.ex:40` `providers: [type: :keyword_list, default: []]`). **RESEARCH.md §3 recommends option 1** because it preserves D-08 ("custom forwarders carry arbitrary keys"). Planner verifies whether NimbleOptions 1.1.x supports `:keep_unknown` (or equivalent) and falls back to option 1 if not.

**D-XX grounding:** D-05, D-06, D-07, D-08, D-09.

---

### 9. `mix.exs` (MODIFIED — extend `no_warn_undefined` + optional dep)

**Analog:** self (`mix.exs:65-87` + 101-111 — both verified; **see RESEARCH.md §2.10 for the verbatim current `no_warn_undefined` block + the exact additions**).

**Verified additions per RESEARCH.md §2.10:**

- Optional-deps section (alphabetical, insert after `Swoosh.Email`):
  ```elixir
  Threadline,
  Threadline.ActorRef,
  Threadline.AuditChange,
  Threadline.AuditTransaction,
  ```
- Internal-modules section (insert after `Sigra.Workers.EmailDelivery` to preserve alphabetical order):
  ```elixir
  Sigra.Workers.AuditForward,
  ```
- New optional dep in `defp deps` (insert in the existing optional-deps cluster, after `{:joken, ...}`):
  ```elixir
  {:threadline, "~> 0.5", optional: true},
  ```

**Planner must keep EXACTLY identical:**

- The `# Optional deps (mix.exs: optional: true)` and `# Internal modules defined only when an optional dep is loaded` section comments at lines 66 + 81 — preserve in place (D-18 — the comment structure is the precedent for *why* this section exists; adding entries without preserving comments would obscure future maintenance).
- `~> 0.5` Threadline pin — matches `STACK.md` and Threadline 0.5.0 as latest (verified 2026-05-27).

**May differ:** none — additive line-insertion only.

**D-XX grounding:** D-18 (corollary).

---

### 10. CI dep-off lane (DEFERRABLE — planner discretion)

**Analog:** v1.21 HARD-02 dep-off CI lane (referenced in RESEARCH.md §6 row 2). No direct code precedent in `.github/workflows/ci.yml` at this writing — research recommends Phase 131 land the lane alongside the impl.

**Planner discretion:** RESEARCH.md §6 last paragraph + Assumption A4 explicitly defer this to planner judgment. Recommendation: **add a Phase 131 task that lands the lane** so regressions catch during implementation rather than at Phase 136 PROOF-01 milestone close. If the planner sizes Phase 131 as already heavy, defer to Phase 136 with an `# A4` annotation.

**No D-XX grounding** — this is a process decision, not a locked decision.

---

## Test File Analogs

(Per RESEARCH.md §6 Wave 0 list — every test file below must exist before parallel impl begins. The existing `test/sigra/audit/` directory has 7 sibling files; the closest analog is paired per test.)

| New test file | Closest analog | Pattern grounding | D-XX |
|---|---|---|---|
| `test/sigra/audit/forwarder_test.exs` | `/Users/jon/projects/sigra/test/sigra/workers/behaviour_test.exs` (1-29) | Behaviour-contract test with stub-module (`StubWorker` → `StubForwarder`); `defmodule StubForwarder do @behaviour Sigra.Audit.Forwarder ... end` inside the test body; verify `Mox.defmock(MockForwarder, for: Sigra.Audit.Forwarder)` succeeds (Success Criterion #5) | D-01, D-04 |
| `test/sigra/audit/forwarders/noop_test.exs` | `/Users/jon/projects/sigra/test/sigra/audit/changeset_test.exs` (1-30) | AAA + `use ExUnit.Case, async: true` + Wave 0 note comment. Assertions: `Noop.attach(_) == :ok`; `refute_received {:telemetry_attached, _}` (no `:telemetry.attach` happens); no `Logger` output | D-22 |
| `test/sigra/audit/forwarders/threadline_test.exs` | `/Users/jon/projects/sigra/test/sigra/rate_limiters/hammer_test.exs` (1-30) | `defmodule MockThreadline do ... end` (analog: `MockHammer` at line 9); `import Mox`, `setup :verify_on_exit!`; tests assert (a) happy path → `[:sigra, :audit, :forward, :ok]` fires + Threadline receives UUID via `:correlation_id`, (b) `MockThreadline` raises mid-`handle_event/4` → `[:sigra, :audit, :forward, :error]` fires AND handler stays attached on SECOND event (D-20 auto-detach landmine test in red ink per RESEARCH.md §8) | D-19, D-20, D-31 |
| `test/sigra/audit/forwarders/dispatch_test.exs` | `/Users/jon/projects/sigra/test/sigra/audit/changeset_test.exs` (1-30) — AAA scaffold style; assertions modeled directly on `lib/sigra/delivery.ex:103-115` semantics | Tests: `dispatch(_, _, dispatch: :sync)` → inline; `dispatch(_, _, dispatch: :async)` with Oban supervised → enqueue; `dispatch(_, _, dispatch: :auto)` with no Oban → inline; `dispatch(_, _, dispatch: :auto)` with Oban supervised → enqueue. Boot-time `:async`-without-Oban raise tested in `application_test.exs`, NOT here | D-10, D-12 |
| `test/sigra/workers/audit_forward_test.exs` | `/Users/jon/projects/sigra/test/sigra/workers/audit_cleanup_test.exs` (1-40) | Wave 0 scaffold pattern (line 4-5 comment); `defmodule StubRepo do ... end` analog at line 9; `function_exported?(AuditForward, :perform, 1)`; cancel-taxonomy assertions (`{:cancel, :audit_event_not_found}` when `StubRepo.get/2` returns `nil`); `backoff/1` returns identical curve to `EmailDelivery` (D-15 byte-for-byte assertion) | D-13, D-14, D-15, D-16, D-17 |

**Boot-time test (extend existing `test/sigra/application_test.exs` if present, else new):**

| Test | Analog | Asserts |
|---|---|---|
| `attach_forwarders/0` raises on `:async + no Oban` | RESEARCH.md §6 row 4 + D-26 | `assert_raise RuntimeError, ~r/Sigra\.Audit\.Forwarders\.Threadline.+:async.+oban.+:auto/, fn -> Sigra.Application.attach_forwarders() end` |
| `maybe_warn_missing_forwarder_deps/0` emits one Logger.warning per missing forwarder | `lib/sigra/application.ex:68-88` (the `maybe_warn_audit_cleanup_fallback/0` precedent has no direct test today — Wave 0 of Phase 131 establishes one; pattern from `test/sigra/audit/changeset_test.exs` for AAA voice) | `ExUnit.CaptureLog.capture_log/1` around start sequence; assert log contains `Sigra.Audit.Forwarders.Threadline` and "guides/recipes/companion-libs/threadline.md" |

---

## Shared Patterns (cross-cutting; planner applies to every relevant file)

### Optional-dep wrap

**Source:** `/Users/jon/projects/sigra/lib/sigra/workers/audit_cleanup.ex:1` + `/Users/jon/projects/sigra/lib/sigra/workers/email_delivery.ex:1` (both verified)

**Apply to:** `lib/sigra/audit/forwarders/threadline.ex` (against `Threadline`) AND `lib/sigra/workers/audit_forward.ex` (against `Oban.Worker`).

```elixir
if Code.ensure_loaded?(Threadline) do
  defmodule Sigra.Audit.Forwarders.Threadline do
    ...
  end
end
```

The closing `end` after the `defmodule … end` is at file end. No alternative `else` branch — when the dep is absent, the module simply does not exist, and `attach_forwarders/0` falls through Noop (D-23 split).

---

### `try/rescue/catch` handler robustness (Pitfall: auto-detach landmine)

**Source:** `/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex:27-40` (verified) — the `try / rescue _ -> ... end` voice. Phase 131 EXTENDS this to also catch `:exit` and `:throw` per D-19, D-20.

**Apply to:** `lib/sigra/audit/forwarders/threadline.ex` `handle_event/4` body — and any future forwarder impl's `handle_event/4`.

```elixir
def handle_event(_event, _measurements, metadata, opts) do
  try do
    # impl body — payload mapping + Sigra.Audit.Forwarders.dispatch/3 call
  rescue
    kind, reason ->
      :telemetry.execute(
        [:sigra, :audit, :forward, :error],
        %{count: 1},
        %{forwarder: :threadline, audit_event_id: metadata[:id], action: metadata[:action], reason: reason, kind: :error, attempt: nil}
      )
      :ok
  catch
    :exit, reason ->
      :telemetry.execute([:sigra, :audit, :forward, :error], %{count: 1}, %{kind: :exit, reason: reason, ...})
      :ok

    :throw, value ->
      :telemetry.execute([:sigra, :audit, :forward, :error], %{count: 1}, %{kind: :throw, reason: value, ...})
      :ok
  end
end
```

**MANDATORY invariant** (D-20, RESEARCH.md §8 "handler auto-detach landmine"): every code path returns `:ok` to `:telemetry`. **Never** `:stop`. **Never** raise. The corresponding acceptance test asserts the handler stays attached on a SECOND event after the first event raised.

---

### Config-lookup pattern (single idiom across boot diagnostics — D-27)

**Source:** `/Users/jon/projects/sigra/lib/sigra/application.ex:30-38` + `92-101` (verified — both use the same cascade)

**Apply to:** `maybe_warn_missing_forwarder_deps/0` AND `attach_forwarders/0`.

```elixir
otp_app = Application.get_env(:sigra, :otp_app)

forwarders =
  case otp_app && Application.get_env(otp_app, :sigra_config) do
    opts when is_list(opts) ->
      opts |> Keyword.get(:audit, []) |> Keyword.get(:forwarders, [])

    _ ->
      []
  end
```

**Do NOT** introduce `Application.fetch_env!/2`, `Application.get_all_env/1`, or any other variant for the same lookup. D-27 is explicit.

---

### Telemetry one-shot emission with category-atom metadata

**Source:** `/Users/jon/projects/sigra/lib/sigra/audit.ex:304-310` (verified — the existing emission shape).

**Apply to:** the new `[:sigra, :audit, :forward, :ok]` and `[:sigra, :audit, :forward, :error]` events (TL-05 / D-28 / D-29 / D-30).

- Measurements: `%{count: 1, duration_ms: integer}` for `:ok`; `%{count: 1}` for `:error`.
- Forwarder name in metadata is an **atom** (`:threadline`), not a module — matches existing telemetry category atoms (`:security`, `:mfa`, `:oauth` from `lib/sigra/telemetry.ex`). D-30 explicit.

---

## No Analog Found

(None — every file in Phase 131's scope has at least one in-repo precedent.)

The one "no-direct-precedent" item is **`attach_forwarders/0`'s D-26 raise on `:async + no Oban`** — voice-mirrored from `verify_vault!/1` (`application.ex:113-124`) which is the closest "raise heredoc when host misconfig blocks boot" in the same file.

---

## Metadata

**Analog search scope:**
- `/Users/jon/projects/sigra/lib/sigra/` (full tree)
- `/Users/jon/projects/sigra/lib/sigra/audit/` (existing siblings: changeset.ex, multi.ex, query.ex, etc.)
- `/Users/jon/projects/sigra/lib/sigra/rate_limiters/` (Noop + Hammer precedents)
- `/Users/jon/projects/sigra/lib/sigra/workers/` (EmailDelivery + AuditCleanup + TokenCleanup + AccountDeletion)
- `/Users/jon/projects/sigra/test/sigra/audit/` (7 existing tests)
- `/Users/jon/projects/sigra/test/sigra/workers/` (6 existing tests)
- `/Users/jon/projects/sigra/test/sigra/rate_limiters/` (hammer_test.exs)
- `/Users/jon/projects/sigra/mix.exs` (no_warn_undefined block + deps)

**Files scanned (read-only, verified at HEAD):** 13
- 10 analog source files (`rate_limiter.ex`, `rate_limiters/noop.ex`, `rate_limiters/hammer.ex`, `delivery.ex`, `workers/email_delivery.ex`, `workers/audit_cleanup.ex`, `application.ex`, `plug/rate_limit.ex`, `audit.ex` (excerpt), `config.ex` (two excerpts), `telemetry.ex` (excerpt), `mix.exs` (excerpt))
- 3 analog test files (`test/sigra/workers/behaviour_test.exs`, `test/sigra/workers/audit_cleanup_test.exs`, `test/sigra/rate_limiters/hammer_test.exs`, `test/sigra/audit/changeset_test.exs`)

**Pattern extraction date:** 2026-05-27

**Cross-references the planner must trust:**
- RESEARCH.md §2.1–§2.10 contain every verbatim excerpt cited above. PATTERNS.md does not duplicate; it grounds and orients.
- CONTEXT.md D-01–D-33 are the locked decisions; PATTERNS.md only quotes D-XX to anchor analog choices.

## PATTERN MAPPING COMPLETE

All 15 Phase 131 files mapped to in-repo analogs with verified line-range citations; no analog gaps; RESEARCH.md §2 excerpts cross-referenced (not duplicated); planner can write `<read_first>` lists + `<action>` specs directly from this map.
