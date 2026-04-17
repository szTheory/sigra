# Phase 30: Audit Exploration and Export - Research

**Researched:** 2026-04-16
**Domain:** Phoenix LiveView audit exploration and CSV export on Sigra's existing audit/admin runtime [VERIFIED: codebase grep]
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (synthesized from roadmap and adjacent completed phases)

> No `30-CONTEXT.md` exists yet. This section is synthesized from `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/v1.2-DIRECTION.md`, and the locked outputs from Phases 28-29. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/v1.2-DIRECTION.md] [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md] [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md]

### Locked Decisions
- Keep the admin runtime library-owned; host code should stay limited to router mounts, policy, shell, and thin controller seams. [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md] [VERIFIED: CLAUDE.md]
- Preserve the Phase 27 route split: global admin work lives under `/admin/...`, and organization-scoped admin work lives under `/admin/organizations/:org/...`. [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md] [VERIFIED: test/example/lib/example_web/router.ex]
- Keep explorer filters URL-addressable and router-driven, not ephemeral client state. [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]
- Preserve dual-actor attribution through `scope.impersonating_from` and `Sigra.Audit.scope_fields/1` as the canonical assembly point. [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex]
- Impersonation must be visible in the UI without forcing operators to inspect raw metadata blobs. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]
- CSV export must respect the currently resolved admin scope and the currently selected filters. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

### Claude's Discretion
- Exact module names under `Sigra.Admin.Audit.*`. [VERIFIED: user prompt]
- Exact route names for explorer and CSV export, as long as they preserve the Phase 27/28 global-vs-organization split. [VERIFIED: user prompt] [VERIFIED: test/example/lib/example_web/router.ex]
- Exact filter-param encoding, as long as actor, effective user, organization, action family/prefix, outcome, and time range remain shareable in the URL. [VERIFIED: user prompt]
- Exact CSV column set, provided canonical IDs and impersonation state are exported in a stable schema. [VERIFIED: user prompt]

### Deferred Ideas (OUT OF SCOPE)
- Search backends such as Elasticsearch or OpenSearch for audit v1.2. [VERIFIED: .planning/REQUIREMENTS.md]
- Async/background audit exports with delivery notifications. That is explicitly future `AUD-05`. [VERIFIED: .planning/REQUIREMENTS.md]
- Reopening earlier ownership or impersonation decisions from Phases 27-29. [VERIFIED: user prompt]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUD-01 | Audit records generated during admin and impersonation workflows preserve the real actor, effective user, organization scope, and impersonation context as canonical queryable fields. | Reuse `Sigra.Audit.scope_fields/1` for impersonation rows and add admin-action wrappers where Phase 28 currently reuses user-centric session audit APIs. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/auth.ex] |
| AUD-02 | Admin can investigate audit history from global, per-user, and per-organization views using URL-addressable filters for actor, effective user, organization, action family, and time range. | Build shared URL-param parsing on router-mounted LiveViews and reuse `Sigra.Audit.Query.build/2`, `paginate/3`, and `Sigra.Audit.Cursor`. [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| AUD-03 | Admin can distinguish impersonation activity from normal user activity in the audit explorer without reading raw metadata blobs. | Derive explorer labels and badges from canonical `actor_id`, `effective_user_id`, and explicit `admin.impersonation.*` actions instead of exposing JSON metadata. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/impersonation.ex] |
| AUD-04 | Admin can export the currently filtered audit slice as evidence in a stable, scope-respecting format such as CSV. | Use a thin controller download seam over the same explorer query service; keep ordering fixed and use a proven CSV dumper if formula-safe output is required. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex] [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Security-sensitive runtime should stay library-owned, with generated/example web code kept thin. [VERIFIED: CLAUDE.md]
- Stay on Phoenix 1.8+ and Ecto 3.x patterns; do not introduce a second frontend/admin stack. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/PROJECT.md]
- Prefer existing repo patterns and additive seams over new abstractions. [VERIFIED: CLAUDE.md]
- Keep dependencies minimal; use a new dependency only when it removes real edge-case ownership. [VERIFIED: CLAUDE.md]
- Test happy paths, main failures, and boundary conditions. [VERIFIED: CLAUDE.md]
- Local `mix test` requires a live Postgres at `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md]

## Summary

Phase 30 can reuse most of the hard runtime already in the repo: canonical dual-actor column assembly lives in `Sigra.Audit.scope_fields/1`, filter composition lives in `Sigra.Audit.Query.build/2`, stable keyset pagination already exists in `Sigra.Audit.Query.paginate/3`, and cursor encoding already exists in `Sigra.Audit.Cursor`. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] The planner should treat Phase 30 as an additive admin surface over those seams, not as a new audit subsystem. [VERIFIED: user prompt]

The two planning-critical gaps are both in the current admin integration layer, not in the core audit runtime. First, the Phase 28 user-detail preview filters only `target_id`, which excludes rows like `session.create` that currently write `effective_user_id` without `target_id`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/auth.ex] Second, current admin session-revocation actions delegate to user-centric `Sigra.Auth` helpers with `user_id: target_user.id`, so those audit rows are currently attributed to the target user rather than the acting admin. [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/auth.ex] AUD-01 is not fully satisfied for admin support actions until that attribution seam is corrected. [VERIFIED: .planning/REQUIREMENTS.md]

The strongest architecture for Phase 30 is a shared `Sigra.Admin.Audit` service layer used by four route shapes: global explorer, org explorer, global per-user explorer, and org-scoped per-user explorer. [VERIFIED: test/example/lib/example_web/router.ex] URL filters should stay LiveView-driven through `handle_params/3`, while CSV export should use a thin controller GET endpoint over the exact same normalized filters so bookmarked evidence URLs and downloaded evidence always resolve the same slice. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex]

**Primary recommendation:** Reuse `Sigra.Audit.Query` and `Sigra.Audit.Cursor` directly, add a small admin-specific query wrapper for per-user and impersonation semantics, and ship CSV through a thin controller download seam over the same normalized filter contract. [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Global audit explorer UI | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/router.ex] | API / Backend [VERIFIED: lib/sigra/audit/query.ex] | The entrypoint is a router-mounted LiveView, but the data contract belongs in library-owned query modules. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Organization-scoped audit explorer | API / Backend [VERIFIED: lib/sigra/admin/authorizer.ex] | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/router.ex] | Scope enforcement must stay server-side through `Sigra.Admin.Scope` and `Sigra.Admin.Authorizer`, with the LiveView only rendering the already-scoped slice. [VERIFIED: lib/sigra/admin/scope.ex] |
| Per-user explorer semantics | API / Backend [VERIFIED: lib/sigra/admin/users/detail.ex] | Frontend Server (SSR) [VERIFIED: lib/sigra/admin/live/user_show_live.ex] | The hard part is composing the correct audit filters for a "subject user" view; the LiveView is only the presentation layer. [VERIFIED: lib/sigra/audit/query.ex] |
| URL-addressable filter state | Frontend Server (SSR) [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] | Browser / Client [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] | Router-mounted LiveViews own `handle_params/3`, and the browser just carries the URL. |
| CSV export response | Frontend Server (SSR) [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex] | API / Backend [VERIFIED: lib/sigra/audit/query.ex] | The HTTP download belongs in a controller response, but filter normalization and row selection should be shared library logic. |
| Audit row persistence and ordering | Database / Storage [VERIFIED: test/example/lib/example/accounts/audit_event.ex] | API / Backend [VERIFIED: lib/sigra/audit/query.ex] | Stable evidence slices depend on persisted canonical columns and deterministic `(inserted_at, id)` ordering. [VERIFIED: lib/sigra/audit/cursor.ex] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix` | `~> 1.8` in repo; `1.8.5` current on Hex. [VERIFIED: mix.exs] [CITED: https://hex.pm/packages/phoenix] | Route scopes, controllers, verified routes, file downloads. | Phase 27-29 already use normal Phoenix scopes and thin controllers for security-sensitive transitions; Phase 30 should stay on that path. [VERIFIED: test/example/lib/example_web/router.ex] |
| `phoenix_live_view` | `~> 1.1` in repo; `1.1.27` current on Hex. [VERIFIED: mix.exs] [CITED: https://hex.pm/packages/phoenix_live_view/versions] | URL-driven explorer UI via router-mounted LiveViews. | `handle_params/3` is the official URL state boundary for router-mounted LiveViews. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| `ecto` + `ecto_sql` | `~> 3.12` in repo. [VERIFIED: mix.exs] | Query composition and DB access for audit slices. | Existing audit runtime, admin scopes, and example app already depend on Ecto queries rather than ad hoc SQL strings. [VERIFIED: lib/sigra/audit/query.ex] |
| Existing `Sigra.Audit` runtime | repo-local. [VERIFIED: lib/sigra/audit.ex] | Canonical actor/effective-user/organization field assembly and safe logging. | Phase 30 should build on the canonical audit columns already emitted by Sigra, not invent parallel metadata parsing. [VERIFIED: test/example/lib/example/accounts/audit_event.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Audit.Query` + `Sigra.Audit.Cursor` | repo-local. [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] | Shared audit filtering, keyset pagination, and stable cursors. | Use for every explorer and export query. Do not replace with offset pagination for audit pages. [VERIFIED: lib/sigra/audit/query.ex] |
| `flop` | `0.26.3` locked in repo. [VERIFIED: mix hex.info] | Existing admin list-query ergonomics. | Keep for Phase 28 user surfaces, but do not force audit pages onto offset/page-number semantics when the audit runtime already has purpose-built cursors. [VERIFIED: lib/sigra/admin/users/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] |
| `flop_phoenix` | `0.26.0` locked in repo. [VERIFIED: mix hex.info] | Existing admin pagination/filter UI helpers. | Reuse existing visual primitives where helpful, but keep audit cursor semantics authoritative. [VERIFIED: lib/sigra/admin/live/users_index_live.ex] |
| `nimble_csv` | `1.3.0` current on Hex. [VERIFIED: mix hex.info] [CITED: https://hexdocs.pm/nimble_csv/changelog.html] | RFC4180-style CSV dumping with documented formula-escaping support. | Add only if Phase 30 wants Sigra to own stable, formula-safe CSV output instead of hand-rolled quoting and injection handling. [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `Sigra.Audit.Query` keyset pagination [VERIFIED: lib/sigra/audit/query.ex] | Offset/page-number pagination via `Flop` | Offset pagination is simpler to render, but it weakens evidence stability on a mutable append-only table compared with the existing `(inserted_at, id)` keyset contract. [VERIFIED: lib/sigra/audit/cursor.ex] |
| Thin controller CSV endpoint [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex] | LiveView `send_download` flow [ASSUMED] | LiveView download helpers can work, but they do not give the planner the same directly addressable evidence URL shape as a plain GET export endpoint. [ASSUMED] |
| `nimble_csv` [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] | Hand-rolled CSV escaping | Hand-rolled CSV is acceptable only if the planner also owns RFC4180 quoting, CRLF line endings, and spreadsheet-formula injection handling. That is not the lowest-risk choice. [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] |

**Installation:**
```bash
# Existing stack is already present.
# Add only if the planner chooses a library-backed CSV exporter:
mix.exs -> {:nimble_csv, "~> 1.3"}
```

**Version verification:** `phoenix 1.8.5` is current on Hex. [CITED: https://hex.pm/packages/phoenix] `phoenix_live_view 1.1.27` is current on Hex versions. [CITED: https://hex.pm/packages/phoenix_live_view/versions] `flop 0.26.3`, `flop_phoenix 0.26.0`, and `nimble_csv 1.3.0` were verified in-session with `mix hex.info`. [VERIFIED: mix hex.info]

## Architecture Patterns

### System Architecture Diagram

```text
Browser URL / admin nav / user-detail "View full audit"
  -> Router-mounted LiveView
     -> normalize query params (scope + filters + cursor + limit)
     -> Sigra.Admin.Audit.Explorer
        -> Sigra.Admin.Scope / Sigra.Admin.Authorizer scope gate
        -> Sigra.Admin.Audit.QueryParams
        -> Sigra.Admin.Audit.Query
           -> Sigra.Audit.Query.build(...)
           -> Sigra.Audit.Query.paginate(...)
           -> optional actor/effective-user/user-subject joins
        -> Repo.all()
        -> presenter derives impersonation badge from canonical columns
     -> HEEx render
        -> "Export CSV" link carries the same normalized query string

GET /admin.../audit/export.csv
  -> thin AuditExportController
     -> same QueryParams normalizer
     -> same Explorer query service
     -> CSV encoder
     -> file response with deterministic header order and row order
```

### Recommended Project Structure

```text
lib/
├── sigra/admin/audit/
│   ├── explorer.ex        # shared list/export orchestration
│   ├── query.ex           # admin-specific query wrapper over Sigra.Audit.Query
│   ├── query_params.ex    # URL filter normalization + cursor parsing
│   ├── presenter.ex       # impersonation badges / row labels / stable export columns
│   └── csv_export.ex      # CSV row mapping and encoding
├── sigra/admin/live/
│   ├── audit_index_live.ex
│   └── audit_user_live.ex
test/example/lib/example_web/controllers/admin/
└── audit_export_controller.ex
```

### Pattern 1: Shared Query Service for All Explorer Entrypoints
**What:** Put all filtering, scoping, cursor parsing, and result shaping into one library-owned service, and let route-specific LiveViews only supply the base scope context. [VERIFIED: lib/sigra/admin/live/users_index_live.ex] [VERIFIED: lib/sigra/admin/users/detail.ex]

**When to use:** For `/admin/audit`, `/admin/users/:id/audit`, `/admin/organizations/:org/audit`, and `/admin/organizations/:org/users/:id/audit`. [VERIFIED: test/example/lib/example_web/router.ex]

**Example:**
```elixir
# Source: repo pattern adapted from lib/sigra/admin/live/users_index_live.ex
def handle_params(params, _uri, socket) do
  with {:ok, filters} <-
         Sigra.Admin.Audit.QueryParams.normalize(params, socket.assigns.admin_scope),
       {:ok, page} <-
         Sigra.Admin.Audit.Explorer.list(socket.assigns.sigra_config, socket.assigns.admin_scope, filters) do
    {:noreply, assign(socket, page: page, current_params: filters)}
  end
end
```

### Pattern 2: Controller-Owned CSV Download over Shared Filter Contract
**What:** Use a thin controller action for CSV so the same query string that drives the explorer UI also yields a directly addressable evidence file. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex]

**When to use:** For `GET .../audit/export.csv` on every scope entrypoint. [VERIFIED: user prompt]

**Example:**
```elixir
# Source: repo controller delegation pattern from test/example/lib/example_web/controllers/admin/impersonation_controller.ex
def index(conn, params) do
  admin_scope = conn.assigns.admin_scope

  with {:ok, filters} <- Sigra.Admin.Audit.QueryParams.normalize(params, admin_scope),
       {:ok, rows} <- Sigra.Admin.Audit.Explorer.export_rows(config(), admin_scope, filters) do
    csv = Sigra.Admin.Audit.CSVExport.dump(rows)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="audit-export.csv"))
    |> send_resp(200, csv)
  end
end
```

### Pattern 3: Impersonation Display Derived from Canonical Columns
**What:** Render impersonation state from `actor_id`, `effective_user_id`, and explicit `admin.impersonation.*` action names instead of exposing raw metadata JSON. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/impersonation.ex]

**When to use:** In explorer rows, filter chips, and export columns. [VERIFIED: user prompt]

**Example:**
```elixir
# Source: canonical field contract in lib/sigra/audit.ex
def impersonated?(event) do
  event.actor_id &&
    event.effective_user_id &&
    event.actor_id != event.effective_user_id
end
```

### Anti-Patterns to Avoid
- **Offset pagination for audit evidence:** The repo already has keyset cursor support; replacing it with page offsets reintroduces duplicate/missing-row risk on a mutable log. [VERIFIED: lib/sigra/audit/cursor.ex]
- **Per-route hand-built audit queries:** Repeating slightly different `where` trees across global, user, and org pages will drift and break scope parity. [VERIFIED: test/example/lib/example_web/router.ex]
- **Metadata-driven impersonation UI:** Phase 29 intentionally elevated dual-actor data into canonical columns so Phase 30 would not need to parse blobs. [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md] [VERIFIED: lib/sigra/audit.ex]
- **Using `organization_scope: {:including_global, org_id}` for a whole org explorer:** That branch is appropriate for a user detail preview, but it would leak all global rows on an org index page. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/audit/query.ex]

## Canonical Repo References

Planner and implementer should read these files before writing Phase 30 plans or code:

- `.planning/ROADMAP.md` — Phase 30 goal, success criteria, and v1.2 sequencing. [VERIFIED: .planning/ROADMAP.md]
- `.planning/REQUIREMENTS.md` — `AUD-01` through `AUD-04` plus out-of-scope guardrails. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/phases/28-user-operations-surface/28-CONTEXT.md` — URL-state, route split, and user-detail preview boundary that Phase 30 extends. [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md]
- `.planning/phases/29-secure-impersonation/29-CONTEXT.md` — canonical dual-actor attribution and visible impersonation rules. [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md]
- `lib/sigra/audit.ex` — canonical `actor_id`, `effective_user_id`, and `organization_id` derivation. [VERIFIED: lib/sigra/audit.ex]
- `lib/sigra/audit/query.ex` — supported audit filters and keyset pagination. [VERIFIED: lib/sigra/audit/query.ex]
- `lib/sigra/audit/cursor.ex` — stable cursor encoding/decoding. [VERIFIED: lib/sigra/audit/cursor.ex]
- `lib/sigra/admin/users/detail.ex` — current recent-audit preview behavior and its scope assumptions. [VERIFIED: lib/sigra/admin/users/detail.ex]
- `lib/sigra/admin/users/actions.ex` — current admin-session action seam that drops real admin attribution. [VERIFIED: lib/sigra/admin/users/actions.ex]
- `lib/sigra/auth.ex` — current session audit writers that the admin wrapper currently reuses. [VERIFIED: lib/sigra/auth.ex]
- `lib/sigra/impersonation.ex` — explicit impersonation lifecycle actions and metadata. [VERIFIED: lib/sigra/impersonation.ex]
- `test/example/lib/example_web/router.ex` — current global/org route split and controller-vs-LiveView boundaries. [VERIFIED: test/example/lib/example_web/router.ex]
- `test/example/lib/example_web/components/admin_shell.ex` — current shell/nav seam where Audit is still a placeholder label. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
- `test/example/lib/example/accounts/audit_event.ex` — canonical audit schema columns available to the explorer/exporter. [VERIFIED: test/example/lib/example/accounts/audit_event.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audit pagination | Offset pagination over `audit_events` | `Sigra.Audit.Query.paginate/3` + `Sigra.Audit.Cursor` | The repo already has portable keyset pagination on `(inserted_at, id)`. [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] |
| CSV quoting and formula escaping | Ad hoc string concatenation | `NimbleCSV` if Phase 30 wants library-backed export safety | CSV dumping has quoting, line-ending, and formula-injection edge cases already documented by NimbleCSV. [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] |
| Scope enforcement in explorer queries | Template-side filtering after loading rows | `Sigra.Admin.Scope` + `Sigra.Admin.Authorizer` at query time | ADMIN-04 requires server-side scope enforcement, not trimmed UI results. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/sigra/admin/authorizer.ex] |
| Impersonation detection | Parsing metadata blobs for impersonation ids | `actor_id`, `effective_user_id`, and `admin.impersonation.*` actions | Phase 29 already made impersonation queryable in canonical columns. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/impersonation.ex] |

**Key insight:** The repo already solved the hard storage problem for Phase 30. The remaining work is joining those canonical audit primitives to the admin route/scope model without losing attribution or filter parity. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: test/example/lib/example_web/router.ex]

## Common Pitfalls

### Pitfall 1: Treating `target_id` as the whole per-user history
**What goes wrong:** Explorer and preview pages miss rows like `session.create` that currently populate `effective_user_id` but not `target_id`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/auth.ex]
**Why it happens:** The existing Phase 28 preview uses `target_id` only. [VERIFIED: lib/sigra/admin/users/detail.ex]
**How to avoid:** Add an admin-specific "subject user" query layer that can express `(effective_user_id == user_id OR target_id == user_id)` without weakening the lower-level audit query builder. [VERIFIED: lib/sigra/audit/query.ex]
**Warning signs:** User explorer shows support mutations but not sign-in/session lifecycle rows for the same user. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/auth.ex]

### Pitfall 2: Reusing user-centric session audit APIs for admin support actions
**What goes wrong:** Admin session revocations are logged as though the target user performed them. [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/auth.ex]
**Why it happens:** `Sigra.Admin.Users.Actions` currently passes `user_id: target_user.id` into generic session helpers. [VERIFIED: lib/sigra/admin/users/actions.ex]
**How to avoid:** Add admin-owned wrappers or new `Sigra.Auth` options that pass real `actor_id`, `effective_user_id`, and `target_id` separately for admin support actions. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/sigra/audit.ex]
**Warning signs:** Exported evidence shows `actor_id == effective_user_id == target_user.id` for obviously admin-driven revocations. [VERIFIED: lib/sigra/auth.ex]

### Pitfall 3: Letting org explorer pages include global rows by default
**What goes wrong:** Org admins can see unrelated global events. [VERIFIED: lib/sigra/audit/query.ex]
**Why it happens:** `organization_scope: {:including_global, org_id}` is useful for a user-scoped preview, but it is not safe as the default org-wide explorer filter. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/audit/query.ex]
**How to avoid:** Use `{:only, org_id}` as the base filter for org explorer indexes, and opt into `including_global` only for a scoped per-user lens if that behavior is intentionally preserved from Phase 28. [VERIFIED: lib/sigra/audit/query.ex]
**Warning signs:** Org-scoped exports contain rows with `organization_id = nil` and no user-specific narrowing filter. [VERIFIED: lib/sigra/audit/query.ex]

### Pitfall 4: Metadata-only impersonation UI
**What goes wrong:** Operators must inspect JSON blobs to understand who really acted. [VERIFIED: user prompt]
**Why it happens:** It is tempting to dump `metadata` directly because impersonation lifecycle events already add contextual metadata. [VERIFIED: lib/sigra/impersonation.ex]
**How to avoid:** Build row presenters and export columns from canonical IDs first, then optionally append metadata as supporting context only. [VERIFIED: lib/sigra/audit.ex]
**Warning signs:** UI copy says "open metadata" to identify impersonation. [VERIFIED: user prompt]

### Pitfall 5: Placeholder Audit navigation never gets wired to current scope
**What goes wrong:** Operators cannot tell whether they are entering global or org audit mode from the shell. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
**Why it happens:** The current shell renders "Audit" as static text in both desktop and mobile nav. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
**How to avoid:** Make the Audit nav target scope-aware in the same way the Users link already is. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
**Warning signs:** The global and org user pages have explorer entry links, but the shell still has a dead Audit label. [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]

## Code Examples

Verified patterns from current sources:

### URL-Driven LiveView State
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
@impl true
def handle_params(params, _uri, socket) do
  {:noreply, socket}
end
```

### Reusing Existing Keyset Pagination
```elixir
# Source: /Users/jon/projects/sigra/lib/sigra/audit/query.ex
query
|> Sigra.Audit.Query.build(filters)
|> Sigra.Audit.Query.paginate(cursor, limit)
```

### Canonical Dual-Actor Extraction
```elixir
# Source: /Users/jon/projects/sigra/lib/sigra/audit.ex
[
  organization_id: org && org.id,
  effective_user_id: user && user.id,
  actor_id: actor && actor.id
]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Offset/page-number pagination on mutable logs [ASSUMED] | Keyset pagination on `(inserted_at, id)` via `Sigra.Audit.Query.paginate/3`. [VERIFIED: lib/sigra/audit/query.ex] | Present in current audit runtime. [VERIFIED: lib/sigra/audit/query.ex] | Better evidence stability and no duplicate/missing rows from concurrent inserts. [VERIFIED: lib/sigra/audit/cursor.ex] |
| Metadata-only impersonation tagging [ASSUMED] | Canonical `actor_id` + `effective_user_id` plus explicit impersonation lifecycle actions. [VERIFIED: lib/sigra/audit.ex] [VERIFIED: lib/sigra/impersonation.ex] | Locked in Phase 29. [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md] | Phase 30 can render impersonation directly without JSON inspection. [VERIFIED: user prompt] |
| Generic admin list pagination via `Flop` [VERIFIED: lib/sigra/admin/users/query.ex] | Audit-specific cursor pagination plus URL filters. [VERIFIED: lib/sigra/audit/cursor.ex] | Existing split in repo today. [VERIFIED: lib/sigra/admin/users/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] | Planner should not flatten the two list models into one lowest-common-denominator paginator. [VERIFIED: lib/sigra/admin/users/query.ex] [VERIFIED: lib/sigra/audit/query.ex] |

**Deprecated/outdated:**
- Using only the Phase 28 recent-audit preview as the Phase 30 query model is outdated for this phase, because it filters by `target_id` only and is intentionally just a preview surface. [VERIFIED: .planning/phases/28-user-operations-surface/28-CONTEXT.md] [VERIFIED: lib/sigra/admin/users/detail.ex]

## Recommended Task Decomposition

1. **Repair audit attribution seams for admin support actions**  
   Add admin-aware wrappers for session revoke / revoke-all so `actor_id`, `effective_user_id`, and `target_id` are canonical for support work. [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/auth.ex]
2. **Add shared audit query-param normalization and subject-user semantics**  
   Normalize URL params, decode cursors, and add the per-user semantics missing from `target_id`-only previews. [VERIFIED: lib/sigra/audit/cursor.ex] [VERIFIED: lib/sigra/admin/users/detail.ex]
3. **Build global and org explorer LiveViews**  
   Add `/admin/audit` and `/admin/organizations/:org/audit`, wire shell nav, and render impersonation-aware rows. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
4. **Build per-user explorer entrypoints and pivots**  
   Add `/admin/users/:id/audit` and `/admin/organizations/:org/users/:id/audit`, plus links from the existing user detail Recent Audit section. [VERIFIED: lib/sigra/admin/live/user_show_live.ex]
5. **Add thin CSV export controller + shared exporter**  
   Add `.csv` endpoints that consume the exact same normalized filter contract. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex]
6. **Land verification coverage**  
   Add library query tests for new filter semantics, example app LiveView/controller tests for scope-safe exploration/export, and at least one direct-path org-scope export denial test. [VERIFIED: test/sigra/audit/query_test.exs] [VERIFIED: test/example/test/example_web/controllers/impersonation_controller_test.exs]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A plain GET controller export endpoint is the best fit over LiveView download helpers for evidence URLs. | Alternatives Considered | Low — the planner could switch to LiveView download mechanics without changing the core query/export architecture. |
| A2 | Offset pagination is the main legacy alternative for audit pages in comparable stacks. | State of the Art | Low — it does not affect the repo-specific recommendation to reuse the existing keyset cursor. |

## Open Questions

1. **Should per-user org-scoped explorer pages include global rows for the same user?**
   - What we know: The current user-detail preview uses `organization_scope: {:including_global, org_id}`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/audit/query.ex]
   - What's unclear: Whether that preview behavior should expand into the full explorer, or whether the dedicated explorer should be stricter for org admins.
   - Recommendation: Lock this in planning. If operator continuity matters more, preserve `including_global` only on user-scoped org views; keep org index views `{:only, org_id}`.

2. **Should CSV include raw `metadata` at all in v1?**
   - What we know: The requirement emphasizes canonical fields and non-metadata impersonation visibility. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: user prompt]
   - What's unclear: Whether reviewers need raw metadata for evidence bundles or whether stable fixed columns are enough.
   - Recommendation: Default to fixed canonical and derived columns only; add `metadata_json` last only if a concrete evidence consumer requires it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Library and example-app tests | ✓ [VERIFIED: local command] | `1.19.5` [VERIFIED: local command] | — |
| Erlang/OTP | Elixir runtime | ✓ [VERIFIED: local command] | `28` [VERIFIED: local command] | — |
| Node.js | Playwright/browser verification | ✓ [VERIFIED: local command] | `v22.14.0` [VERIFIED: local command] | Example-app ExUnit coverage only |
| npm | Playwright package execution | ✓ [VERIFIED: local command] | `11.1.0` [VERIFIED: local command] | `npx` from local install if added later |
| PostgreSQL client/server access | `mix test` for repo and example app | ✓ [VERIFIED: local command] | `psql 14.17` client [VERIFIED: local command] | Dockerized Postgres per `CLAUDE.md` |
| Docker | Disposable local Postgres and browser smoke envs | ✓ [VERIFIED: local command] | `29.3.1` [VERIFIED: local command] | Existing local Postgres |
| Playwright CLI | Browser export/explorer smoke | ✗ [VERIFIED: local command] | — | Defer browser artifact coverage to Phase 31; use ExUnit + controller/LiveView tests in Phase 30 |

**Missing dependencies with no fallback:**
- None identified for planning or implementation. [VERIFIED: local command]

**Missing dependencies with fallback:**
- Playwright CLI is not installed globally, but the repo already contains Playwright config under `test/example/priv/playwright/`, and Phase 30 can rely on ExUnit coverage while Phase 31 owns browser artifacts. [VERIFIED: test/example/priv/playwright/playwright.config.ts] [VERIFIED: local command]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit in repo root and in `test/example`. [VERIFIED: mix.exs] [VERIFIED: test/example/mix.exs] |
| Config file | Root `mix.exs`; example-app `test/example/mix.exs`; Playwright config at `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: mix.exs] [VERIFIED: test/example/mix.exs] [VERIFIED: test/example/priv/playwright/playwright.config.ts] |
| Quick run command | `mix test test/sigra/audit/query_test.exs test/sigra/audit/query_filters_test.exs test/sigra/impersonation_test.exs` [VERIFIED: test/sigra/audit/query_test.exs] [VERIFIED: test/sigra/audit/query_filters_test.exs] [VERIFIED: test/sigra/impersonation_test.exs] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && (cd test/example && mix test)` [VERIFIED: CLAUDE.md] [VERIFIED: test/example/mix.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUD-01 | Admin and impersonation rows keep canonical actor/effective-user/org attribution | unit + example integration | `mix test test/sigra/impersonation_test.exs test/sigra/audit/query_filters_test.exs` plus `cd test/example && mix test test/example_web/audit_integration_test.exs` | Partial — attribution regression file exists, Phase 30-specific admin attribution tests do not. [VERIFIED: test/sigra/impersonation_test.exs] [VERIFIED: test/example/test/example_web/audit_integration_test.exs] |
| AUD-02 | Global, per-user, and per-org explorers honor URL filters and scope | example LiveView + controller | `cd test/example && mix test test/example_web/live/admin_audit_* test/example_web/controllers/admin_audit_*` | ❌ Wave 0 |
| AUD-03 | Impersonation is clearly surfaced without metadata inspection | unit + example LiveView | `mix test test/sigra/impersonation_test.exs` plus `cd test/example && mix test test/example_web/live/admin_audit_*` | ❌ Wave 0 |
| AUD-04 | CSV export preserves current filtered slice and scope | example controller + direct-path | `cd test/example && mix test test/example_web/controllers/admin_audit_export_controller_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Targeted root `mix test ...` and targeted `cd test/example && mix test ...` commands covering the changed seam. [VERIFIED: mix.exs] [VERIFIED: test/example/mix.exs]
- **Per wave merge:** Root audit/unit tests plus example app audit LiveView/controller tests. [VERIFIED: mix.exs] [VERIFIED: test/example/mix.exs]
- **Phase gate:** Root suite and example app suite green before `/gsd-verify-work`. [VERIFIED: .planning/config.json]

### Wave 0 Gaps
- [ ] `test/sigra/audit/query_subject_user_test.exs` — covers per-user explorer semantics beyond `target_id`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/auth.ex]
- [ ] `test/sigra/audit/query_impersonation_filter_test.exs` — covers derived impersonation filter/presenter semantics if added. [VERIFIED: lib/sigra/impersonation.ex]
- [ ] `test/example/test/example_web/live/admin_audit_index_live_test.exs` — covers global and org explorer filter URLs plus nav wiring. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: test/example/lib/example_web/components/admin_shell.ex]
- [ ] `test/example/test/example_web/live/admin_user_audit_live_test.exs` — covers per-user pivots from user detail. [VERIFIED: lib/sigra/admin/live/user_show_live.ex]
- [ ] `test/example/test/example_web/controllers/admin_audit_export_controller_test.exs` — covers CSV scope, headers, ordering, and filter parity. [VERIFIED: user prompt]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: .planning/REQUIREMENTS.md] | Reuse authenticated admin routes and current scope hydration before explorer/export access. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| V3 Session Management | yes [VERIFIED: .planning/phases/29-secure-impersonation/29-CONTEXT.md] | Preserve `current_scope` and `impersonating_from` semantics during audit exploration and export. [VERIFIED: test/example/lib/example_web/user_auth.ex] |
| V4 Access Control | yes [VERIFIED: .planning/REQUIREMENTS.md] | Use `Sigra.Admin.Scope` and `Sigra.Admin.Authorizer` for every query/export path. [VERIFIED: lib/sigra/admin/scope.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] |
| V5 Input Validation | yes [VERIFIED: .planning/REQUIREMENTS.md] | Normalize URL params explicitly and reject unsupported keys. Existing audit query already raises on unknown filters. [VERIFIED: lib/sigra/audit/query.ex] |
| V6 Cryptography | no direct new crypto [VERIFIED: codebase grep] | No new crypto is needed for Phase 30 itself; reuse existing session/auth primitives. [VERIFIED: test/example/lib/example_web/user_auth.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Org-scope bypass by query-string tampering | Elevation of Privilege | Re-resolve admin scope from route + policy and apply it server-side before querying or exporting. [VERIFIED: lib/sigra/admin/scope.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] |
| CSV formula injection in evidence downloads | Tampering | Use documented formula escaping if CSV libraries are used, or explicitly escape dangerous prefixes in exporter code. [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html] |
| Exporting a different slice than the UI currently shows | Repudiation | Share one filter-normalization and query service between LiveView and export controller. [VERIFIED: test/example/lib/example_web/controllers/admin/impersonation_controller.ex] [VERIFIED: lib/sigra/admin/live/users_index_live.ex] |
| Metadata-only impersonation display obscures real actor | Repudiation | Derive labels from canonical `actor_id` and `effective_user_id`. [VERIFIED: lib/sigra/audit.ex] |
| Unstable ordering causes duplicate/missing evidence rows | Repudiation | Keep export and explorer ordering fixed to `(inserted_at desc, id desc)` and use keyset cursors. [VERIFIED: lib/sigra/audit/query.ex] [VERIFIED: lib/sigra/audit/cursor.ex] |

## Sources

### Primary (HIGH confidence)
- `https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html` — `handle_params/3`, router-mounted URL state, and patch semantics. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]
- `https://hexdocs.pm/phoenix/Phoenix.Router.html` — Phoenix scope/pipeline/controller routing behavior. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html]
- `https://hexdocs.pm/nimble_csv/NimbleCSV.html` — CSV dumping and formula-escaping guidance. [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html]
- `https://hexdocs.pm/nimble_csv/changelog.html` — current NimbleCSV version and `escape_formula` history. [CITED: https://hexdocs.pm/nimble_csv/changelog.html]
- `https://hex.pm/packages/phoenix` — current Phoenix release metadata. [CITED: https://hex.pm/packages/phoenix]
- `https://hex.pm/packages/phoenix_live_view/versions` — current LiveView versions. [CITED: https://hex.pm/packages/phoenix_live_view/versions]
- Local codebase modules and planning files listed in **Canonical Repo References**. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)
- `mix hex.info flop` — locked/current Flop package information in this environment. [VERIFIED: mix hex.info]
- `mix hex.info flop_phoenix` — locked/current Flop Phoenix package information in this environment. [VERIFIED: mix hex.info]
- `mix hex.info nimble_csv` — current NimbleCSV package information in this environment. [VERIFIED: mix hex.info]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - Repo stack and official docs are clear, but the CSV dependency decision is still a planner choice. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/nimble_csv/NimbleCSV.html]
- Architecture: HIGH - The route split, scope enforcement, audit query seams, and controller precedent are already present in repo code. [VERIFIED: test/example/lib/example_web/router.ex] [VERIFIED: lib/sigra/admin/authorizer.ex] [VERIFIED: lib/sigra/audit/query.ex]
- Pitfalls: HIGH - The missing per-user query semantics and admin-attribution gap are directly visible in current code. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/auth.ex]

**Research date:** 2026-04-16
**Valid until:** 2026-05-16
