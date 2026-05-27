# Phase 131: Forwarder Behaviour + Threadline Forwarder Library Scaffolding - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `131-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 131-forwarder-behaviour-threadline-forwarder-library-scaffolding
**Mode:** assumptions
**Calibration:** minimal_decisive (user profile: opinionated)
**Areas analyzed:** Behaviour Shape & Lifecycle; `forwarders:` Config Shape; Dispatch Wiring; Oban Worker Shape; Failure Isolation; Noop Fallback; Boot-Time Wiring; Telemetry Event Shape; Custom-Forwarder Contract Surface

## Assumptions Presented

### Behaviour Shape & Lifecycle (FB-01)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Single callback `attach(keyword) :: :ok \| {:error, term}`; library-called from `Sigra.Application.start/2`; handler id `{__MODULE__, opts[:id] \|\| :default}` | Confident | `lib/sigra/rate_limiter.ex:1-26`, `lib/sigra/application.ex:21-27`, `lib/sigra/telemetry.ex:341-348`, `.planning/research/ARCHITECTURE.md:95-101` |

### `forwarders:` Config Shape

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `:forwarders` under existing `audit:` keyword; list of keyword lists `[module:, dispatch:, id:, ...opts]`; per-forwarder dispatch knob | Likely | `lib/sigra/config.ex:434-458` (per-feature `delivery_mode` precedent in `email:`); `lib/sigra/config.ex:793-820` (existing `audit:` keyword); `.planning/research/ARCHITECTURE.md:121-135` |

### Dispatch Wiring (TL-02)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Routing lives in shared dispatcher (`Sigra.Audit.Forwarders.dispatch/3` or inline in worker); Threadline impl delegates; custom forwarders get same routing | Confident | `lib/sigra/delivery.ex:30-115` (Delivery owns dispatch, EmailDelivery owns mailer-specific perform); `lib/sigra/delivery.ex:113` ("running, not just loaded" comment) |

### Oban Worker Shape (TL-03)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Sigra.Workers.AuditForward` thin args `%{"forwarder", "audit_event_id", "occurred_at"}`; reload row at perform; `max_attempts: 5`; exp backoff; `{:cancel, _}` taxonomy; never raises | Confident | `lib/sigra/workers/email_delivery.ex:33-103`; T-3-INFRA-01 at line 17; `.planning/research/ARCHITECTURE.md:150` |

### Failure Isolation

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `handle_event/4` wraps body in `try/rescue/catch` catching ALL exceptions; fires `[:sigra, :audit, :forward, :error]`; returns `:ok` to telemetry; handler NEVER raises | Confident | `:telemetry.attach/4` contract (raisers auto-detached); `lib/sigra/rate_limiters/hammer.ex:31-39` rescue-all fail-open precedent; `.planning/research/PITFALLS.md:54-60` |

### Noop Fallback (TL-04)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Noop.attach/1` returns `:ok`, does NOT subscribe, does NOT log; one-shot warning emitted from `Sigra.Application.start/2` upstream | Confident | `lib/sigra/rate_limiters/noop.ex:1-21` (zero side effects); `lib/sigra/plug/rate_limit.ex:84-95` (warning at resolver, not at Noop) |

### Boot-Time Wiring (TL-04)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `Sigra.Application.start/2` adds `attach_forwarders/0` + `maybe_warn_missing_forwarder_deps/0` alongside existing diagnostics; `:async`+Oban-missing raises at boot | Confident | `lib/sigra/application.ex:21-27, 68-88`; TL-02 explicit raise-at-boot requirement; `.planning/research/PITFALLS.md:11-37` (drift cost of host-owned wiring) |

### Telemetry Event Shape (TL-05)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `:ok` measurements `%{count: 1, duration_ms: integer}`, metadata `%{forwarder, audit_event_id, action, dispatch}`; `:error` measurements `%{count: 1}`, metadata `%{forwarder, audit_event_id?, action?, reason, kind, attempt?}`; **extend existing `[:sigra, :audit, :log]` metadata with `id` + `occurred_at`** | Likely | `lib/sigra/audit.ex:304-310` (current metadata insufficient for dedup); `.planning/research/ARCHITECTURE.md:391` (open question explicitly flagged); `.planning/research/PITFALLS.md:62-67` (Pitfall 4 dedup) |

### Custom-Forwarder Contract Surface (FB-01 + SC#5)

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `attach(keyword)` minimum keys: `:id`, `:dispatch`, `:audit_schema`, `:repo`, `:oban` + impl-specific; behaviour does NOT define `handle_event/4` | Likely | `lib/sigra/rate_limiter.ex:1-26` (tiny-seam parallel); `lib/sigra/delivery.ex:47` (`:oban` override pattern); `.planning/research/PITFALLS.md:104-135` (scope-creep risk) |

## Corrections Made

No corrections — user selected "Yes, proceed" on all 9 assumptions. All assumptions captured as locked decisions D-01 through D-33 in `131-CONTEXT.md`.

## External Research

None performed in this step — codebase precedents covered all areas. Two items flagged for the **planner** to verify before locking ancillary contracts (do NOT change Phase 131 library-code shape):

1. **Threadline `record_action/2` (or `publish/1`) exact signature on Hex 0.5.0** — Phase 132 recipe needs this; Phase 131 stubs behind a private function.
2. **NimbleOptions support for `{:list, :keyword_list}` with module values** — no precedent in current `lib/sigra/config.ex`; planner verifies in `nimble_options` 1.1.x docs. If unsupported, falls back to a custom validator with explicit doc for the `forwarders:` shape.
