# Phase 15: Audit Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 15-audit-integration
**Areas discussed:** metadata_from_scope API shape; Migration + index shape; Sigra.Workers behaviour; v1.0 call-site migration + effective_user_id semantics; Audit.Query filter semantics

---

## Gray Area #1: `metadata_from_scope` API shape + nil-scope contract

### Question A — Return shape of the scope→opts helper

| Option | Description | Selected |
|---|---|---|
| A1 | Keyword list returned; caller merges via `Keyword.merge` | |
| A2 | Pre-built opts list that replaces the whole `log_safe` keyword | |
| A3 | Returns a map placed under a `:scope_metadata` key that `log_safe` unpacks | |
| **A4** | **New `log_safe/3` that takes scope as second positional arg; helper stays private** | **✓** |

**User's choice:** A4 — scope-as-second-arg, private internal helper.
**Notes:** Mirrors Phoenix 1.8 `fn(scope, ...)` idiom, Bodyguard/Canada subject-first convention, Ash actor model, Sentry context. Sidesteps the `Keyword.merge` ordering footgun entirely.

### Question B — Nil-scope contract

| Option | Description | Selected |
|---|---|---|
| **B1** | **Single nil-safe helper: `nil → [organization_id: nil, effective_user_id: nil]`** | **✓** |
| B2 | Require non-nil scope; separate `metadata_from_conn/2` for pre-auth | |
| B3 | Scope + actor_id override arg | |

**User's choice:** B1 — one nil-safe entry point.
**Notes:** Pre-auth sites (failed login, password reset, magic link) pass `nil` explicitly — self-documenting intent.

### Question C — Module home

| Option | Description | Selected |
|---|---|---|
| **C1** | **Keep in `Sigra.Audit` module** | **✓** |
| C2 | New `Sigra.Audit.Metadata` submodule | |

**User's choice:** C1 — co-located. Submodule is premature at v1.1.

### Duck-typing adaptation

During analysis, the research subagent noted that `%Sigra.Scope{}` is NOT a library struct — it's generated into the host app via `priv/templates/sigra.install/core/scope.ex` as `<%= context_module %>.Scope`. The library helper cannot pattern-match on a named struct and must duck-type on `%{user, active_organization, impersonating_from}`. This is a necessary adaptation, not a choice. Locked into D-03.

---

## Gray Area #2: Migration strategy + index shape

### Question A — Migration emission strategy

| Option | Description | Selected |
|---|---|---|
| A1 | Update existing `create_audit_events.exs` template + emit alter | |
| **A2** | **Frozen create template + always-emit standalone alter migration** | **✓** |
| A3 | Separate `mix sigra.gen.migration` task | |
| A4 | Bundle into Phase 13 org migrations | |

**User's choice:** A2 — frozen create + standalone alter.
**Notes:** Matches phx_gen_auth, pow, ash_authentication precedent. v1.0 users' migration history stays byte-identical.

### Question B — `organization_id` index shape

| Option | Description | Selected |
|---|---|---|
| B1 | Single-column `(organization_id)` | |
| **B2** | **Composite `(organization_id, inserted_at)`** | **✓** |
| B3 | Composite `(organization_id, inserted_at, id)` with tiebreak | |
| B4 | Partial index `WHERE organization_id IS NOT NULL` | |

**User's choice:** B2 — composite matching existing `(actor_id, inserted_at)` / `(action, inserted_at)` pattern.
**Notes:** Index range scan + stops at LIMIT, no sort. Consistency with existing indexes is its own virtue.

### Question C — `effective_user_id` index in v1.1

| Option | Description | Selected |
|---|---|---|
| C1 | Full composite `(effective_user_id, inserted_at)` now | |
| **C2** | **No index in v1.1; ship column only; add index in v1.2** | **✓** |
| C3 | Single-column `(effective_user_id)` only | |

**User's choice:** C2 — YAGNI. In v1.1, effective_user_id always equals actor_id; existing index serves all queries.

### Question D — Schema + changeset update

| Option | Description | Selected |
|---|---|---|
| **D1** | **Always add both fields; no `--organizations` conditional** | **✓** |
| D2 | Conditional on `--organizations` install flag | |
| D3 | Columns always, changeset conditional | |

**User's choice:** D1 — nullable columns in non-org apps are a rounding error.

### Question E — Query module update

| Option | Description | Selected |
|---|---|---|
| E1 | Add `:organization_id` filter only | |
| **E2** | **Add both `:organization_id` and `:effective_user_id` filters** | **✓** |
| E3 | Add `for_scope/2` convenience | |

**User's choice:** E2 — ship both filters for v1.2 forward-compat; skip `for_scope/2` (deferred).

---

## Gray Area #3: `Sigra.Workers` behaviour shape

### Question A — Behaviour shape

| Option | Description | Selected |
|---|---|---|
| **A1** | **Pure `@behaviour Sigra.Workers` + tiny helper module; no macro** | **✓** |
| A2 | `use Sigra.Worker` macro that injects `use Oban.Worker` | |
| A3 | `use Sigra.Worker` macro without Oban | |
| A4 | Plain helper module, no behaviour | |
| A5 | Behaviour + `defoverridable` defaults | |

**User's choice:** A1 — mirrors `Phoenix.LiveView.on_mount` and `Plug`. Dashbit rule: macros are for unavoidable boilerplate.

### Question B — Args contract enforcement

| Option | Description | Selected |
|---|---|---|
| B1 | Required at perform time only | |
| B2 | Optional/graceful | |
| **B3+B1** | **Enqueue helper validates + behaviour wrapper re-fetches (belt-and-suspenders)** | **✓** |
| B4 | Per-worker contract | |

**User's choice:** B3+B1 — fail-fast at enqueue + loud perform-time re-check.

### Question C — Scope reconstruction

| Option | Description | Selected |
|---|---|---|
| C1 | Full DB reload of user/org/membership | |
| **C2** | **Minimal id-only skeleton using host's `Scope` struct** | **✓** |
| C3 | Dedicated `Sigra.Workers.Scope` struct | |
| C4 | `log_safe(:worker, opts)` special mode | |

**User's choice:** C2 — preserves `log_safe(action, scope, opts)` cohesion. Worker scopes are audit-only.

### Question D — Reference worker

| Option | Description | Selected |
|---|---|---|
| **D1** | **`AccountDeletion`** | **✓** |
| D2 | `EmailDelivery` | |
| D3 | `AuditCleanup` | |
| D4 | New example module | |
| D5 | Both `AccountDeletion` + `EmailDelivery` | |

**User's choice:** D1 — only worker where a real audit event naturally lands in v1.1 scope.

### Question E — Mandatory vs opt-in

| Option | Description | Selected |
|---|---|---|
| E1 | All Sigra workers use the behaviour | |
| **E2** | **Only org-aware workers; tenant-agnostic workers opt out** | **✓** |
| E3 | `@tenant_agnostic true` module attribute | |

**User's choice:** E2 — `AuditCleanup` / `TokenCleanup` stay untouched. Documented in `Sigra.Workers` moduledoc.

### Refinement during discussion

The initial subagent proposal added `user_schema/0` and `org_schema/0` helpers to the host's generated Scope module. Rejected in favor of a library-side `Sigra.Scope.build/3` helper (see D-23) — keeps the host's generated code untouched and gives login sites + workers one shared constructor.

---

## Gray Area #4: Call-site migration scope + `effective_user_id` semantics

### Question A — Migration scope

| Option | Description | Selected |
|---|---|---|
| A1 | All-at-once single sweep of all sites | |
| A2 | Progressive (only Cat 1 sites where scope is available) | |
| A3 | Only new sites; defer v1.0 migration | |
| **A4** | **Two-step: mechanical nil sweep, then semantic enrichment** | **✓** |

**User's choice:** A4 — maps onto Phase 15's multi-plan structure.
**Notes:** Verified call-site count is 79, not 25 or 50. At 79 sites, one giant PR mixes mechanical rename with semantic enrichment in one reviewable unit — bad. A4 splits into Plan 15-01 (mechanical) and Plan 15-02 (semantic).

### Question B — Failed-login `effective_user_id` semantics

| Option | Description | Selected |
|---|---|---|
| B1 | Always nil at failed-login sites | |
| B2 | Populate from looked_up_user.id | |
| **B3** | **Use `target_id` for subject; `effective_user_id` strictly for authenticated principal** | **✓** |

**User's choice:** B3 — OWASP ASVS V7.1 + NIST 800-63B §5.2.2 compliance. Matches Rails `Audited` / `PaperTrail` actor/subject split.

### Question C — Login-time scope synthesis

| Option | Description | Selected |
|---|---|---|
| C1 | Synthesize scope inline at login sites | |
| C2 | Pass nil at login; first audit event has no org | |
| **C3** | **Library-side `Sigra.Scope.build/3` helper** | **✓** |

**User's choice:** C3 — reused by workers and login sites. Also fixes `session.create` ordering bug (today fires before org selection).
**Notes:** The subagent initially proposed `Sigra.Scope.for_login/2` on the host's Scope module. Rejected because Scope is host-generated and Sigra doesn't know the module name. `Sigra.Scope.build(scope_module, user, opts)` in the library is the clean fix.

### Question D — Pre-auth sites with resolved user

| Option | Description | Selected |
|---|---|---|
| D1 | Always nil scope | |
| **D2** | **`Scope{user: user, active_organization: nil}` where user resolved + `target_id: user.id`** | **✓** |
| D3 | Thread request context only | |

**User's choice:** D2 — self-documenting "user known, org unknown."

### Additional decisions locked in

- **Credo custom check** `Sigra.Credo.NoLogSafe2InLib` — forbids arity-2 `log_safe` in `lib/sigra/**`. Load-bearing for "one idiom in lib/" enforcement.
- **`session.create` ordering fix** — intentional semantic improvement. CHANGELOG entry required.
- **Unknown-email failed login** — log IP + UA only; no email hash in metadata (keyed HMAC rejected for key-management surface).
- **Test strategy** — `assert_audit_logged/2` helper in `Sigra.Testing`, per-site assertion. No snapshot tests.

---

## Gray Area #5: `Sigra.Audit.Query` filter semantics

### Question A — `organization_id: nil` interpretation

| Option | Description | Selected |
|---|---|---|
| **A1** | **Pass-through `WHERE IS NULL`** | **✓** |
| A2 | Treat as no-filter | |
| A3 | Raise on nil | |

**User's choice:** A1 — code-origin builder; callers construct filters deliberately; library-emitted events legitimately have `IS NULL`.

### Question B — "This org plus global events" filter mode

| Option | Description | Selected |
|---|---|---|
| B1 | Single filter = strict equality; admin UI composes its own OR | |
| **B2** | **`:organization_scope` tagged tuple: `{:only, id}` / `{:including_global, id}`** | **✓** |
| B3 | `:organization_id` defaults to including-global; strict is `:organization_id_only` | |

**User's choice:** B2 — tagged tuple is idiomatic Elixir and self-documenting. Keeps `:organization_id` as dumb equality.

### Question C — `:scope` shortcut

| Option | Description | Selected |
|---|---|---|
| C1 | No shortcut; callers build filters | |
| C2 | `:scope` filter key that expands | |
| **C3** | **Separate `Sigra.Audit.Query.for_scope/2` helper — deferred to v1.2** | **✓** |

**User's choice:** C3 but deferred. v1.1 doesn't need it; ship when the admin UI caller exists.

### Question D — Unknown key handling

| Option | Description | Selected |
|---|---|---|
| D1 | Keep silent ignore | |
| **D2** | **Raise with helpful message listing valid keys** | **✓** |
| D3 | Log a warning via telemetry | |

**User's choice:** D2 — silent ignore is a footgun; typos return unfiltered audit results (security-adjacent bug).
**Notes:** Breaking change for v1.0 users. CHANGELOG entry required. v1.1 is the right release window.

---

## Claude's Discretion

- Exact split boundaries between Plan 15-01 / 15-02 / 15-03.
- Arg key naming for `AccountDeletion` refactor (`"scope_module"` vs `"scope"` etc.).
- ExUnit tags, fixture file locations, test-helper internal structure.
- Whether `Sigra.Credo.NoLogSafe2InLib` lives in `lib/sigra/credo/` or a test-only path.

## Deferred Ideas

- `Sigra.Audit.Query.for_scope/2` convenience → v1.2 when admin UI caller exists
- `effective_user_id` composite index → v1.2 alongside impersonation
- `log_multi/3` scope support → v1.2 if admin UI needs multi-variant emission
- Partial index / UNION rewrite for `:including_global` → v1.2 if query hits scale
- `Sigra.Workers` adoption for `EmailDelivery` → v1.2 for admin-sent emails
- Cloak-encrypted audit metadata → orthogonal, out of scope
- `--no-organizations` conditional for audit columns → v1.2 if generator flag lands
