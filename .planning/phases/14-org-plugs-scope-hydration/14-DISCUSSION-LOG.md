# Phase 14: Org Plugs + Scope Hydration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 14-org-plugs-scope-hydration
**Areas discussed:** Plug↔LV parity, Stale + 0/1/2+ flow, RequireMembership opts, put_active_organization/2
**Mode:** Interactive, research-backed (4 parallel subagents)

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Plug↔LV parity | How LoadActiveOrganization and on_mount produce byte-identical %Scope{} | ✓ |
| Stale + 0/1/2+ flow | Reconcile SC-1 "reset to nil" vs PITFALLS O-6 "auto-pick" + where 0/1/2+ lives | ✓ |
| RequireMembership opts | Redirect targets, role semantics, defaults | ✓ |
| put_active_organization/2 | Where it lives, what it writes, rotation, per-request caching | ✓ |

**User directive:** "For each of these research using subagents: pros/cons tradeoffs, examples, recommendation, best DX for Elixir/Ecto/Plug/Phoenix, lessons from other Elixir libs and cross-language precedents, great UX aligned with lib vision, principle-of-least-surprise Elixir-native architecture. Help one-shot a perfect recommendation."

---

## Area 1: Plug↔LV Parity

### Options Researched

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| 1. Shared `Hydration.hydrate/3` + mirror active_organization_id into Plug session cookie | Single source of truth for hydration; zero extra LV queries | Two-writer hazard (pitfall O-5); violates Phase 12 "DB is source of truth" invariant | |
| 2. Shared hydrator + LV fetches full `%Sigra.Session{}` via `get_user_and_session_by_token` | Single writer; matches Phase 12 invariant; marginal extra cost (one JOIN on existing lookup) | Slightly more DB work per LV mount than option 1 | ✓ |
| 3. `attach_hook` / socket-assign bridge | "Clever" | Does not solve parity — hook runs in LV process with only session map | |
| 4. Serialize scope snapshot into session cookie | Fastest LV mount | Stale-pointer hazard; revoked-membership invisible until re-login; fails SC-3 | |

**User's choice:** Option 2 — shared library hydrator `Sigra.Scope.Hydration.hydrate/3`; LV path switches `mount_current_scope` to use `get_user_and_session_by_token` (function already exists in generated context).

**Notes:** Research agent #1 initially recommended option 1 (cookie mirror). Research agent #4 argued against cookie mirroring as a two-writer hazard (pitfall O-5). User accepted the synthesized resolution in favor of #4's position. The shared hydrator is the byte-identity mechanism; the DB row is the only writer; `active_organization_id` never touches the signed Plug session cookie.

**Decisions captured:** D-01, D-02, D-03, D-22, D-23

---

## Area 2: Stale-Pointer Policy + 0/1/2+ Flow Wiring

### Sub-area A: Stale-pointer policy

| Policy | Source | Pros | Cons | Selected |
|--------|--------|------|------|----------|
| Reset-to-nil only | ROADMAP SC-1 | Matches Clerk/WorkOS; simple; exercises no-org landing | Jarring UX for users with other orgs remaining | |
| Eager auto-pick in Load | PITFALLS O-6 | Best DX; matches Jetstream/Sequin/Plausible | Duplicates 0/1/2+ logic; unclear "per-session" semantics | |
| **Hybrid** (reset + call same selector as login) | Synthesis | One selector function shared across login + recovery; one audit event; resolves SC-1 vs O-6 apparent conflict | Slightly more code than pure reset | ✓ |

**Resolution:** SC-1 describes the *observable end state when nothing remains to pick*; O-6 describes the *mechanism when something does remain*. Both are satisfied by invoking the same `select_active_organization/3` helper.

### Sub-area B: 0/1/2+ flow wiring

| Option | Pros | Cons | Selected |
|--------|------|------|----------|
| 1. All-in-one `LoadActiveOrganization` | Single plug; matches phx.gen.auth idiom | Plug does real work (DB writes); harder to customize 0-org UX | |
| 2. Separate `EnsureActiveOrganization` plug | Clean separation; overridable | Halt+redirect inside hydration layer; redirect loop risk | |
| 3. Login-time selection + Load plug reads | Selection runs once at login; cheap per-request; stale recovery via same helper | Two call sites for selector (login + recovery) | ✓ |
| 4. Hybrid (login + plug re-selection) | Explicit version of 3 | Essentially identical to 3 | |

**User's choice:** Option 3. Login calls `select_active_organization/3` once inside `Sigra.Auth.create_session/4` and writes the chosen `active_organization_id` to the new session row in the same transaction. Stale recovery inside `LoadActiveOrganization` calls the same helper with `previous: nil`.

**Halt discipline:** `LoadActiveOrganization` NEVER halts — matches phx.gen.auth's Fetch/Require split. `RequireMembership` is the only Phase 14 plug that halts.

**"Per-session, not per-user"** falls out for free because the pointer lives on `user_sessions.active_organization_id` — each device has its own session row.

**Decisions captured:** D-04, D-11, D-12, D-13, D-14

---

## Area 3: RequireMembership Options

### Sub-area A: Redirect target configuration

| Option | Fit with Sigra | Selected |
|--------|----------------|----------|
| NimbleOptions on `use Sigra.Organizations` | Duplicates existing ErrorHandler pattern | |
| Plug init options (legacy `RequireMFA` pattern) | Works but loses flash/UX control; not used by newer plugs | |
| **Extend `Sigra.Plug.ErrorHandler` behaviour** | Matches `RequireAuthenticated`/`RequireScopes` exactly | ✓ |
| Delegate to generated UserAuth helper | Creates two layers doing the same thing | |

**Decision:** Extend the existing `Sigra.Plug.ErrorHandler` behaviour with `:no_active_org` and `:insufficient_role` error types. Zero new configuration surface. Host devs customize redirect/flash/content-negotiation in the same file (`MyAppWeb.AuthErrorHandler`) where they already customize other auth errors.

### Sub-area B: Role matching semantics

| Option | Used by | Selected |
|--------|---------|----------|
| **Set membership ("one of")** | Pundit, Bodyguard, Phoenix 1.8 scopes, Plausible, Oban Pro, Cased | ✓ |
| Hierarchical | Laravel Jetstream (widely regretted) | |
| Permission-based | CanCanCan / Casbin (too much machinery for v1.1) | |

**Decision:** `roles: [:owner, :admin]` means "role must be one of these atoms." Hierarchical ordering is a well-documented trap. Every mature Elixir authz lib uses set membership.

**Extra:** Validate `:roles` is a subset of host's `@sigra_org_config[:roles]` at `init/1`; raise `ArgumentError` on typos. Compile-time failure, not request-time.

### Sub-area C: Default when `:roles` omitted

| Option | Selected |
|--------|----------|
| **Any membership accepted** | ✓ |
| Must explicitly declare | |

**Decision:** Pundit/Bodyguard/Phoenix-scopes precedent. Forcing explicit declaration adds boilerplate to the 80% case.

### Sub-area D: Halt + error shape

**Decision:** Match `RequireAuthenticated`/`RequireScopes` exactly — call `error_handler.auth_error(conn, type, opts)` then `Plug.Conn.halt/1`. Handler owns response shape (redirect+flash for HTML, JSON 403 for API via content negotiation).

**Decisions captured:** D-05, D-06, D-07, D-08, D-09, D-10

---

## Area 4: put_active_organization/2

### Sub-area A: Where does it live?

| Option | Selected |
|--------|----------|
| 1. Pure Scope function only | |
| 2. Library function only | |
| **3. Split: pure `Scope.put_active_organization/3` + impure `Sigra.Plug.put_active_organization/2` orchestrator** | ✓ |
| 4. Thin-wrapper context function only | (as a thin defdelegate on top of 3) |

**Decision:** Split. Pure data function on generated `Scope` template matches Phoenix 1.8 guide verbatim. Impure orchestrator lives in library. Generated `MyOrgs` wrapper adds a `defdelegate set_active_organization(conn, org), to: Sigra.Plug, as: :put_active_organization` for discoverability.

### Sub-area B: What gets written?

**Decision:** DB column `user_sessions.active_organization_id` (authoritative), `conn.private[:sigra_session]` (refreshed struct), `conn.assigns[:current_scope]` (new scope via `Scope.put_active_organization/3`). **NO** Plug session cookie write (would create two-writer hazard, pitfall O-5).

### Sub-area C: Session token rotation on switch?

| Option | Selected |
|--------|----------|
| Rotate | |
| **Don't rotate** | ✓ |
| Rotate on suspicious signal | |

**Decision:** Scope transition ≠ trust transition. Rotation would kill LiveView connections, flicker every open tab, buy zero security benefit. Jetstream/Clerk/acts_as_tenant all skip rotation. `renew_session` stays scoped to `log_in_user` / `log_out_user`.

### Sub-area D: Per-request membership caching

| Option | Selected |
|--------|----------|
| 1. Always fresh | |
| **2. Per-conn memo in `scope.membership`** | ✓ |
| 3. ETS cross-request cache | |

**Decision:** Membership is already on `scope.membership` (Phase 12 field). `LoadActiveOrganization` fetches once and stashes; `RequireMembership` reads from assigns. Zero extra DB queries per request beyond the one Load already does. ETS cross-request cache deferred to v1.2.

**Decisions captured:** D-15, D-16, D-17, D-18, D-19, D-20, D-21

---

## Final Confirmation

**Question:** Lock in this synthesis as the Phase 14 direction?
**User's choice:** Lock it all in.

---

## Claude's Discretion

- CD-01: Exact location of the `put_active_organization/2` orchestrator (`Sigra.Plug.put_active_organization/2` vs module function placement).
- CD-02: Audit event name format.
- CD-03: Whether `Hydration` lives at `lib/sigra/scope/hydration.ex` or `lib/sigra/organizations/scope_hydration.ex`.
- CD-04: "Most recent" ordering strategy for `select_active_organization/3` fallback.
- CD-05: Test file organization.
- CD-06: Whether `SessionStore.update_active_organization/3` is a new behaviour callback or extension-only.

## Deferred Ideas

- ETS cross-request membership cache (v1.2).
- Hierarchical roles (rejected permanently).
- `users.last_active_organization_id` cross-device resume pointer (product decision, not v1.1).
- `:strategy` option for `select_active_organization/3` (v1.2+).
- Session token rotation on org switch (rejected).
- Named `Sigra.Session.put_active_organization_id/2` setter (stays deferred).
- Cookie-mirrored `active_organization_id` (rejected).
- LV `attach_hook`-based hydration (rejected — does not solve parity).
- Oban-based proactive stale-session cleanup on membership removal (v1.2+ polish).
- Cross-tab scope drift detection via LV `handle_params` (Phase 16).
