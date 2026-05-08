# Phase 109: Security activity and session history truth - Research

**Researched:** 2026-05-08 [VERIFIED: repo date]  
**Domain:** User-facing security activity derived from Sigra-owned audit/session truth [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md]  
**Confidence:** HIGH [VERIFIED: repo evidence]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Phase framing
- **D-109-01 — Phase 109 is the second `SESS-CTRL` slice and centers on `SESS-03`.** Do not reopen preserve-current revoke semantics except where the new activity surface needs to display the resulting lifecycle events truthfully.
- **D-109-02 — Keep the activity surface thin-host and library-owned.** Generated LiveViews/controllers may request prepared activity rows and render them, but they must not query raw audit tables or reinterpret security event meaning themselves.

### Source-of-truth rules
- **D-109-03 — Security activity must come from Sigra-owned persisted truth only.** Use existing audit rows, suspicious-login signals, and session/session-related library data. If an important activity type is not currently persisted with enough fidelity, add the missing library-owned audit/event emission instead of fabricating activity in the UI.
- **D-109-04 — Normalize activity through a dedicated presentation seam.** The user-facing surface should not expose raw action strings like `session.create` or `security.suspicious_login` directly; Sigra should map them into stable labels, timestamps, and any bounded descriptive metadata needed by both generated-host and admin surfaces.
- **D-109-05 — Recent sign-ins and session lifecycle events must stay semantically distinct.** A successful sign-in, suspicious-login detection, revoke-other-sessions action, revoke-all action, and single-session revoke should not collapse into one generic "security event" label when the underlying truth differs.

### Scope and honesty
- **D-109-06 — Show only bounded metadata Sigra already owns.** IP, coarse location fields already captured, event timestamp, actor/effective-user context, session type, and outcome are acceptable. Do not invent exact device trust, geolocation certainty, or risk severity beyond what existing truth supports.
- **D-109-07 — Keep user/admin truth aligned without copying admin UX wholesale.** The user-facing feed may be simpler than the admin audit explorer, but overlapping events should share the same underlying semantics and not contradict the admin surface.
- **D-109-08 — Suspicious-login outcomes are visibility work, not a new detection engine.** Reuse the current suspicious-login contract and notification truth; Phase 109 should surface its outcomes, not redesign how suspicion is detected.
- **D-109-09 — Session activity ordering and pagination must be deterministic.** If the surface is paginated or capped, ordering should be authoritative and stable, following the same inserted-at/id tie-break discipline used in admin audit paths.

### Decomposition guidance
- **D-109-10 — Preserve generator parity.** Any generated-host security-activity page, helper, or route changes must update the live install templates and template tests so installed apps match the example app.
- **D-109-11 — Prefer extending existing audit/query infrastructure over parallel read models.** If admin audit presenters or query builders already solve scoping, labeling, or filtering problems, Phase 109 should reuse or adapt them rather than introduce a second incompatible pipeline.
- **D-109-12 — Keep the first activity surface focused on recent account/session security events.** Do not widen this phase into organization activity feeds, webhook history, or unrelated account-center concerns.

### the agent's Discretion
- Exact public module/function names for the security-activity query and presenter seam
- Whether the user-facing surface lives on the existing sessions page, a security page, or a closely adjacent generated route
- Exact row shape, copy, and whether event grouping is needed, as long as raw audit semantics stay intact
- Whether any currently missing audit events should be added in this phase to make the feed honest
- Whether admin/detail surfaces need small presenter refactors to share normalization logic cleanly

### Deferred Ideas (OUT OF SCOPE)
- arbitrary end-user audit filtering/export
- geolocation/risk scoring beyond existing coarse metadata
- a broader "security center" or device-intelligence dashboard
- organization-wide or admin-product activity feeds unrelated to the current user's account/session story
- session storage redesign or new event-store infrastructure
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-03 | Users can inspect recent security activity derived from Sigra-owned truth, including recent sign-ins, suspicious-login outcomes, and meaningful session lifecycle events. | Use a library-owned query/presenter seam over persisted audit/session truth, with targeted emission fixes for the gaps called out below. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/sigra/admin/audit/query.ex] [VERIFIED: lib/sigra/admin/audit/presenter.ex] [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/suspicious_login.ex] |
| SESS-04 | Generated user and admin session surfaces clearly identify the current session and expose recent-auth or timeout state where Sigra already tracks it. | Reuse the current-session/session-state work already present on the user and admin session surfaces; Phase 109 should align activity labels with those same semantics, not add a second truth model. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| SESS-05 | Session-management UX stays thin-host and least-surprise: Sigra owns revoke/activity business rules and generated controllers/LiveViews render those rules without duplicating policy. | Put event selection, normalization, ordering, and semantic mapping in a Sigra library seam; generated `Accounts` and LiveViews should only request rows and render them. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: test/example/lib/example/accounts.ex] |
</phase_requirements>

## Summary

Sigra already persists most of the truth Phase 109 needs: successful logins emit `auth.login.success`, session creation emits `session.create`, suspicious-login detection emits `security.suspicious_login`, explicit revokes emit `session.delete`, `session.revoke_all`, and `session.revoke_others`, and sudo confirmation emits `session.sudo_enter` / `session.sudo_expire`. Admin surfaces already prove the right architectural shape: `Sigra.Admin.Audit.Query` scopes events, `Sigra.Admin.Audit.Presenter` normalizes them, and `Sigra.Admin.Users.Detail.recent_audit_preview/3` enforces stable `inserted_at desc, id desc` ordering. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/suspicious_login.ex] [VERIFIED: lib/sigra/admin/audit/query.ex] [VERIFIED: lib/sigra/admin/audit/presenter.ex] [VERIFIED: lib/sigra/admin/users/detail.ex]

The gap is not storage redesign; it is semantic packaging. The current generated user surface at `/users/sessions` has session truth and revoke controls but no activity feed. More importantly, two user-visible lifecycle moments are not yet represented honestly enough for a feed: MFA completion only emits telemetry and a second `session.create`, and generated logout deletes the session through `Sigra.Auth.delete_session/3` without user attribution, which leaves the resulting `session.delete` audit row unable to distinguish “you signed out” from an unattributed revoke. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/controllers/session_controller.ex] [VERIFIED: guides/flows/audit-logging.md]

**Primary recommendation:** Add a library-owned `Sigra.SecurityActivity` seam that reuses audit query infrastructure and emits two missing bounded events or audit semantics before UI work: an attributed logout event and an MFA-completion event. [VERIFIED: repo synthesis]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Security-activity query construction | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | Query scoping and ordering already live in Sigra library modules, not in generated views. [VERIFIED: lib/sigra/admin/audit/query.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] |
| Activity row normalization / label mapping | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | Generated surfaces should not reinterpret raw audit actions; Phase 109 context locks this boundary. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: lib/sigra/admin/audit/presenter.ex] |
| User-facing recent-activity rendering | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | API / Backend [VERIFIED: reasoning from repo architecture] | The existing `/users/sessions` surface is a LiveView and is the natural thin host for the new feed. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |
| Missing event emission for logout / MFA completion | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (controller) [VERIFIED: reasoning from repo architecture] | The persisted truth must be written in Sigra-owned code paths; host controllers may pass user/session context but should not invent event semantics. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/controllers/session_controller.ex] |
| Admin/user semantic alignment | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | The admin detail page already previews audit rows from library presenter output, so the user feed should extend that shared normalization path. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |

## Project Constraints (from CLAUDE.md)

- Root `mix test` depends on a live Postgres at `localhost:5432` with `postgres/postgres`; the repo is not configured to silently skip DB-backed tests. [VERIFIED: CLAUDE.md]
- Security-sensitive logic belongs in the library; generated host code stays thin and should delegate rather than re-implement policy. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/PROJECT.md]
- Template parity matters for generated host changes; example-app edits alone are not sufficient. [VERIFIED: CLAUDE.md] [VERIFIED: test/sigra/templates/session_templates_test.exs]
- No project-local skills were configured in `.claude/skills` or `.agents/skills`, so there are no extra repo-local rule overlays for this phase. [VERIFIED: CLAUDE.md] [VERIFIED: filesystem scan]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | 1.8.5 [VERIFIED: mix.lock] | Runtime for generated controllers and LiveViews. [VERIFIED: mix.lock] | The user-facing and admin-facing surfaces in scope are already Phoenix-native. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| Phoenix LiveView | 1.1.28 [VERIFIED: mix.lock] | UI layer for the current session surface and admin detail surface. [VERIFIED: mix.lock] | Phase 109 should extend existing session/security screens, not introduce a second UI stack. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| Ecto / Ecto SQL | 3.13.5 [VERIFIED: mix.lock] | Query layer for audit rows and persisted sessions. [VERIFIED: mix.lock] | Existing admin audit preview and session store semantics already rely on Ecto query composition. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex] |
| `Sigra.Auth` | repo-local [VERIFIED: lib/sigra/auth.ex] | Canonical source of login, session, revoke, and sudo audit semantics. [VERIFIED: lib/sigra/auth.ex] | Missing event emissions should be fixed here or through a tightly adjacent Sigra-owned seam. [VERIFIED: lib/sigra/auth.ex] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Admin.Audit.Query` | repo-local [VERIFIED: lib/sigra/admin/audit/query.ex] | Scoped audit filtering, including `subject_user_id`. [VERIFIED: lib/sigra/admin/audit/query.ex] | Reuse for recent security-activity selection instead of querying raw audit rows in LiveView. [VERIFIED: lib/sigra/admin/users/detail.ex] |
| `Sigra.Admin.Audit.Presenter` | repo-local [VERIFIED: lib/sigra/admin/audit/presenter.ex] | Canonical action-label normalization for admin surfaces. [VERIFIED: lib/sigra/admin/audit/presenter.ex] | Extend or wrap for user-facing activity labels so overlapping events stay aligned. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| `Sigra.SuspiciousLogin` | repo-local [VERIFIED: lib/sigra/suspicious_login.ex] | Existing suspicious-login detection and audit emission. [VERIFIED: lib/sigra/suspicious_login.ex] | Treat as an input signal to the activity feed, not a redesign target. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| Generated `Example.Accounts` wrapper | repo-local [VERIFIED: test/example/lib/example/accounts.ex] | Thin host API that should expose the new activity seam. [VERIFIED: test/example/lib/example/accounts.ex] | Add one wrapper entrypoint here after the library seam exists. [VERIFIED: test/example/lib/example/accounts.ex] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Library-owned `Sigra.SecurityActivity` seam [VERIFIED: recommendation] | Query `audit_events` directly from `SessionLive`. [VERIFIED: repo possibility] | Faster to prototype but violates `D-109-02` and `D-109-11`, and would fork semantics away from admin surfaces. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| Reusing admin query/presenter infrastructure [VERIFIED: recommendation] | Build a new user-only activity read model. [VERIFIED: repo possibility] | A second read model would duplicate scoping, ordering, and labeling logic the repo already owns. [VERIFIED: lib/sigra/admin/audit/query.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] |
| Explicit logout + MFA completion event coverage [VERIFIED: recommendation] | Infer logout and MFA completion from existing `session.delete` / `session.create` rows. [VERIFIED: current code] | Inference would be lossy: logout rows can be unattributed today, and MFA completion currently looks like a second generic sign-in. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example/accounts.ex] |

**Installation:** No new dependency is required for the recommended implementation. [VERIFIED: mix.exs]

```bash
mix deps.get
```

## Phase Decomposition

### Recommended boundary

Phase 109 should not redesign storage or build an end-user audit explorer. It should add one library-owned activity seam, close the minimum missing event-emission gaps needed for honest rows, extend the existing user session surface, and align admin/docs/template coverage afterward. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md]

### Recommended plans

| Plan | Scope | Likely Files Touched | Why This Split |
|------|-------|----------------------|----------------|
| 109-01 | Add the library-owned security-activity query/presenter seam and close missing event-emission gaps. [VERIFIED: recommendation] | `lib/sigra/auth.ex`, new `lib/sigra/security_activity*.ex`, `lib/sigra/admin/audit/presenter.ex` or adjacent shared presenter module, `test/sigra/auth_test.exs`, new security-activity query/presenter tests. [VERIFIED: repo paths] | The planner needs the semantic contract before any generated UI can render it truthfully. [VERIFIED: repo synthesis] |
| 109-02 | Wire the generated user-facing activity surface and template parity on the existing sessions page. [VERIFIED: recommendation] | `test/example/lib/example/accounts.ex`, `test/example/lib/example_web/live/auth/session_live.ex`, `priv/templates/sigra.install/core/auth.ex`, `priv/templates/sigra.install/core/session_live.ex`, new example LiveView tests, `test/sigra/templates/session_templates_test.exs`. [VERIFIED: repo paths] | This isolates thin-host UX and install parity after the underlying row contract is settled. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |
| 109-03 | Align admin preview labels where needed, update docs, and close verification/edge-case gaps. [VERIFIED: recommendation] | `lib/sigra/admin/users/detail.ex`, `lib/sigra/admin/live/user_show_live.ex`, `test/example/test/example_web/live/admin_user_show_live_test.exs`, `guides/flows/login-and-logout.md`, `guides/flows/account-lifecycle.md`, `guides/flows/audit-logging.md`. [VERIFIED: repo paths] | Admin/user truth should converge last so the shared presenter contract is final before docs and preview assertions are updated. [VERIFIED: lib/sigra/admin/users/detail.ex] |

## Architecture Patterns

### System Architecture Diagram

```text
Persisted session/audit truth
  -> Sigra.SecurityActivity.list_recent(user_id, opts)
  -> reuse Sigra.Admin.Audit.Query filters + stable ordering
  -> normalize rows through shared presenter
  -> generated Accounts.recent_security_activity(user)
  -> SessionLive "Recent security activity" section

Security-sensitive mutations
  -> Sigra.Auth login/logout/revoke/MFA completion paths
  -> write bounded audit rows for missing semantics
  -> same activity seam reads those rows later
```

The planner should keep both arrows pointed into Sigra-owned code first: writes become honest in the library, then reads normalize that truth for hosts. [VERIFIED: repo synthesis]

### Recommended Project Structure

```text
lib/sigra/
├── auth.ex                     # existing session/auth emitters
├── suspicious_login.ex         # existing suspicious-login source
├── admin/audit/                # reusable query/presenter infrastructure
└── security_activity*.ex       # new Phase 109 seam

test/example/lib/example/
├── accounts.ex                 # thin wrapper
└── web/live/auth/session_live.ex

priv/templates/sigra.install/core/
├── auth.ex
└── session_live.ex
```

### Pattern 1: Use audit rows as the canonical feed source, not live session rows

**What:** Build the recent activity feed from persisted audit events scoped to the current subject user, then enrich with bounded session metadata only when the audit row already points at a session lifecycle event. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: lib/sigra/admin/audit/query.ex]

**When to use:** Use for recent sign-ins, suspicious-login outcomes, revoke events, and sudo/auth lifecycle rows. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/suspicious_login.ex]

**Example:**
```elixir
# Source: lib/sigra/admin/users/detail.ex
audit_schema
|> Sigra.Admin.Audit.Query.build(subject_user_id: user_id)
|> order_by([event], desc: event.inserted_at, desc: event.id)
|> limit(^5)
```

### Pattern 2: Normalize duplicate login/session signals into one user-facing semantic row

**What:** Treat `session.create` as the canonical persisted anchor for “a session exists now,” while using adjacent audit actions such as `security.suspicious_login` or a new MFA-completion event to refine the label. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/suspicious_login.ex]

**When to use:** Use when the raw audit stream would otherwise show both `auth.login.success` and `session.create` for one sign-in flow. [VERIFIED: lib/sigra/auth.ex]

**Example:**
```elixir
# Source: lib/sigra/auth.ex
Audit.log_safe("auth.login.success", ...)
...
Sigra.Audit.log_safe("session.create", ...)
```

The feed should not render both rows as two separate “successful sign-in” entries for one password login. [VERIFIED: repo synthesis]

### Pattern 3: Add missing audit semantics in library code before rendering UI copy

**What:** If the persisted event stream cannot distinguish logout from targeted revoke, or MFA-completion from a second bare session create, fix the write path first. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: lib/sigra/auth.ex]

**When to use:** Use for user-facing labels that would otherwise require UI inference. [VERIFIED: repo synthesis]

**Example:**
```elixir
# Source: lib/sigra/auth.ex
def complete_mfa_verification(config, user, old_session, opts \\ []) do
  session_store.delete(old_session.hashed_token, store_opts)
  case create_session(config, user, %{type: target_type}) do
```

This path currently emits telemetry only, not an audit row that explains the session transition. [VERIFIED: lib/sigra/auth.ex]

### Anti-Patterns to Avoid

- **Raw-action rendering in LiveView:** Do not render `session.revoke_others` or `security.suspicious_login` directly in generated UI. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md]
- **Duplicated login rows:** Do not show both `auth.login.success` and `session.create` as separate sign-in events without a deliberate merge rule. [VERIFIED: lib/sigra/auth.ex]
- **Session-list-as-history:** Do not infer recent security history by diffing current active sessions; revoked and deleted sessions are only visible in audit truth. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex]
- **Invented timeout history:** Do not claim “session expired” history until a persisted event exists; timeout enforcement currently deletes rows without audit. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/workers/token_cleanup.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-surface activity semantics | Separate user-only and admin-only label maps. [VERIFIED: recommendation] | One shared Sigra presenter seam, possibly extending `Sigra.Admin.Audit.Presenter`. [VERIFIED: lib/sigra/admin/audit/presenter.ex] | Overlapping rows must stay aligned across user/admin surfaces. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| Feed ordering | LiveView-side sorting or client-side truncation. [VERIFIED: recommendation] | DB ordering by `inserted_at desc, id desc` in the query seam. [VERIFIED: lib/sigra/admin/users/detail.ex] | Stable ordering is a locked phase requirement. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| Logout/MFA semantics | UI inference from generic `session.delete` / `session.create` rows. [VERIFIED: recommendation] | Library-owned extra audit emission or explicit audit-action selection. [VERIFIED: lib/sigra/auth.ex] | The current persisted truth is insufficiently specific for those flows. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example/accounts.ex] |

**Key insight:** The hard problem here is semantic truth, not pagination or rendering. The repo already has the right audit/session substrate, but two missing lifecycle labels need to be written at the source before a user-facing feed can stay honest. [VERIFIED: repo synthesis]

## Common Pitfalls

### Pitfall 1: Counting one login flow twice
**What goes wrong:** The feed shows two “sign in” rows for one password login. [VERIFIED: risk from current event catalog]  
**Why it happens:** Successful password login emits `auth.login.success`, and the same flow later emits `session.create`. [VERIFIED: lib/sigra/auth.ex]  
**How to avoid:** Normalize those raw rows into one user-facing semantic event, with suspicious-login and MFA rows acting as adjunct context rather than duplicate sign-ins. [VERIFIED: repo synthesis]  
**Warning signs:** Adjacent rows share the same actor, same timestamp neighborhood, and both read like plain success logins. [ASSUMED]

### Pitfall 2: Mislabeling MFA completion as a fresh sign-in
**What goes wrong:** The feed implies the user signed in again when they merely completed step-up auth. [VERIFIED: risk from current flow]  
**Why it happens:** `complete_mfa_verification/4` deletes the `mfa_pending` session, creates a new session, and emits only telemetry. [VERIFIED: lib/sigra/auth.ex]  
**How to avoid:** Add an audit row for MFA completion or session upgrade and map it to a distinct user-facing label. [VERIFIED: recommendation from repo evidence]  
**Warning signs:** MFA-enabled accounts show an unexplained second `session.create` shortly after login. [VERIFIED: lib/sigra/auth.ex] [ASSUMED]

### Pitfall 3: Treating logout and admin revoke as the same event
**What goes wrong:** A user-facing feed cannot tell whether the account owner signed out or support/admin revoked a session. [VERIFIED: risk from current flow]  
**Why it happens:** Generated logout currently calls `delete_user_session_token/1`, which delegates to `Sigra.Auth.delete_session/3` without `user_id`, so the audit row is a generic `session.delete` with nil user attribution. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: lib/sigra/auth.ex]  
**How to avoid:** Add explicit logout audit semantics and pass attribution through a library-owned logout seam. [VERIFIED: recommendation from repo evidence]  
**Warning signs:** Recent activity contains unattributed `session.delete` rows or cannot honestly render “you signed out.” [VERIFIED: lib/sigra/auth.ex] [ASSUMED]

### Pitfall 4: Promising timeout history Sigra does not persist
**What goes wrong:** The feed claims session expiry history that the database cannot prove. [VERIFIED: risk from current code]  
**Why it happens:** Timeout enforcement in `FetchSession` and cleanup workers deletes expired sessions without corresponding audit rows. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/workers/token_cleanup.ex]  
**How to avoid:** Either keep timeout history out of the first feed or add explicit expiry audit emission in a later scoped change. [VERIFIED: recommendation from repo evidence]  
**Warning signs:** Product copy says “recent timeouts” but grep finds only deletes and telemetry, not audit rows. [VERIFIED: repo grep]

## Code Examples

Verified patterns from local source:

### Stable subject-user audit query
```elixir
# Source: lib/sigra/admin/audit/query.ex
def for_subject_user(queryable, user_id) when is_binary(user_id) do
  from(event in queryable,
    where: event.effective_user_id == ^user_id or event.target_id == ^user_id
  )
end
```

### Existing recent-audit preview ordering
```elixir
# Source: lib/sigra/admin/users/detail.ex
|> order_by([event], desc: event.inserted_at, desc: event.id)
|> limit(^@audit_preview_limit)
```

### Current suspicious-login audit emission
```elixir
# Source: lib/sigra/suspicious_login.ex
Sigra.Audit.log_safe(
  "security.suspicious_login",
  Sigra.Scope.from_config(config, %{id: user_id}),
  ...
)
```

### Current preserve-current revoke audit emission
```elixir
# Source: lib/sigra/auth.ex
{count, nil} =
  revoke_sessions(config, user_id, Keyword.put(opts, :except_token, current_hashed_token),
    audit_action: "session.revoke_others"
  )
```

## Event Sufficiency Audit

| Event / Signal | Exists | Honest for user-facing feed? | Notes |
|----------------|--------|------------------------------|-------|
| `session.create` | Yes [VERIFIED: lib/sigra/auth.ex] | Yes, with normalization [VERIFIED: recommendation] | Best persisted anchor for a created session, but should usually collapse with `auth.login.success` into one “Signed in” row. [VERIFIED: lib/sigra/auth.ex] |
| `auth.login.success` | Yes [VERIFIED: lib/sigra/auth.ex] | Yes, as supporting semantic input [VERIFIED: recommendation] | Useful to detect successful authentication, but duplicative if shown raw beside `session.create`. [VERIFIED: lib/sigra/auth.ex] |
| `security.suspicious_login` | Yes [VERIFIED: lib/sigra/suspicious_login.ex] | Yes [VERIFIED: lib/sigra/suspicious_login.ex] | Carries IP and coarse geo metadata already bounded by the phase scope. [VERIFIED: lib/sigra/suspicious_login.ex] |
| `session.delete` | Yes [VERIFIED: lib/sigra/auth.ex] | Partially [VERIFIED: recommendation] | Honest for targeted revoke when attribution is passed, but generated logout currently produces unattributed rows. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: lib/sigra/auth.ex] |
| `session.revoke_all` | Yes [VERIFIED: lib/sigra/auth.ex] | Yes [VERIFIED: lib/sigra/auth.ex] | Good input for “signed out of all devices.” [VERIFIED: lib/sigra/auth.ex] |
| `session.revoke_others` | Yes [VERIFIED: lib/sigra/auth.ex] | Yes [VERIFIED: lib/sigra/auth.ex] | Good input for “signed out of other devices.” [VERIFIED: lib/sigra/auth.ex] |
| `session.sudo_enter` / `session.sudo_expire` | Yes [VERIFIED: lib/sigra/auth.ex] | Yes, if kept bounded [VERIFIED: recommendation] | Fits “recent auth/security activity” if the planner wants it in the first feed. [VERIFIED: lib/sigra/auth.ex] |
| MFA verification completion audit row | No [VERIFIED: lib/sigra/auth.ex] | No [VERIFIED: recommendation] | Missing emission; current flow only emits telemetry plus a new `session.create`. [VERIFIED: lib/sigra/auth.ex] |
| Explicit logout audit row | No [VERIFIED: repo grep] | No [VERIFIED: recommendation] | Docs claim `auth.logout`, but no library audit writer exists in the repo. [VERIFIED: guides/flows/audit-logging.md] [VERIFIED: repo grep] |
| Timeout-expired session audit row | No [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/workers/token_cleanup.ex] | No [VERIFIED: recommendation] | Do not promise timeout history in the first feed unless Phase 109 grows scope. [VERIFIED: recommendation from repo evidence] |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Admin-only recent audit preview with generic action-label normalization. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/audit/presenter.ex] | Extend the same normalization pattern into a user-facing security-activity seam. [VERIFIED: recommendation] | Phase 109 planning target, 2026-05-08. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] | Keeps user/admin truth aligned instead of inventing a second event model. [VERIFIED: recommendation] |
| User session page shows only active sessions and revoke controls. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] | Add a recent security activity section on the existing page. [ASSUMED] | Phase 109 recommended implementation. [VERIFIED: recommendation] | Lowest-churn surface adjacent to existing session truth. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |

**Deprecated/outdated:**
- `guides/flows/audit-logging.md` lists `auth.logout` as a built-in event, but repo grep did not find a corresponding library audit emission. Treat that guide entry as stale until Phase 109 reconciles it. [VERIFIED: guides/flows/audit-logging.md] [VERIFIED: repo grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The best first user-facing location for the feed is the existing `/users/sessions` LiveView rather than a new `/users/security` route. [ASSUMED] | State of the Art / Recommended plans | Could cause avoidable route churn if the planner or user prefers a dedicated security page. |

## Open Questions (RESOLVED)

1. **Timeout-expiry history is OUT of scope for Phase 109.**
   - Resolution: keep timeout as present-state only in this slice. Do not add timeout-history rows to the first recent-activity feed.
   - Why: timeout enforcement currently deletes expired sessions without persisted audit rows, so a history surface would require new source truth beyond the bounded scope of this phase. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/workers/token_cleanup.ex]
   - Planning consequence: `109-01..03` must continue to exclude timeout-history claims while preserving existing `SESS-04` present-state truth on touched surfaces. [VERIFIED: phase plans]

2. **Logout truth is modeled as `auth.logout`.**
   - Resolution: use an explicit `auth.logout` persisted semantic for owner-initiated sign-out.
   - Why: this matches the existing docs vocabulary and cleanly separates voluntary logout from targeted revoke, revoke-all, and generic session deletion semantics. [VERIFIED: guides/flows/audit-logging.md] [VERIFIED: lib/sigra/auth.ex]
   - Planning consequence: `109-01` should add the persisted `auth.logout` event path, and `109-03` should reconcile docs/admin labels to that exact contract. [VERIFIED: phase plans]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Running tests and verifying library changes | ✓ [VERIFIED: exec] | 1.19.5 [VERIFIED: exec] | — |
| `mix` | Running ExUnit and formatter/test commands | ✓ [VERIFIED: exec] | — [VERIFIED: exec] | — |
| PostgreSQL | Repo tests per project constraints | ✓ [VERIFIED: exec] | 14.17 client; local server accepting connections on `localhost:5432` [VERIFIED: exec] | — |
| Docker | Optional local Postgres bootstrap | ✓ [VERIFIED: exec] | 29.4.1 [VERIFIED: exec] | Use existing local Postgres. [VERIFIED: exec] |

**Missing dependencies with no fallback:**
- None. [VERIFIED: environment audit]

**Missing dependencies with fallback:**
- None. [VERIFIED: environment audit]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Mix / Phoenix test stack [VERIFIED: repo structure] |
| Config file | `test/test_helper.exs` [VERIFIED: repo file] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/example/test/example_web/live/auth/session_live_test.exs -x` [VERIFIED: repo patterns] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-03 | Recent activity rows are selected from persisted subject-user truth with stable ordering. [VERIFIED: requirement + recommendation] | unit / integration | `mix test test/sigra/admin/audit/query_test.exs` [VERIFIED: repo file] | ✅ |
| SESS-03 | Suspicious-login rows appear with bounded metadata and normalized labels. [VERIFIED: requirement + recommendation] | unit | `mix test test/sigra/suspicious_login_test.exs` [VERIFIED: repo file] | ✅ |
| SESS-03 | MFA completion and logout semantics become honest persisted activity. [VERIFIED: recommendation] | unit / integration | `mix test test/sigra/auth_test.exs` [VERIFIED: repo file] | ⚠️ extend existing |
| SESS-04 | User/admin surfaces stay aligned on current-session and related security labels. [VERIFIED: requirement] | LiveView | `mix test test/example/test/example_web/live/auth/session_live_test.exs test/example/test/example_web/live/admin_user_show_live_test.exs` [VERIFIED: repo files] | ✅ |
| SESS-05 | Generated host remains thin and template parity holds. [VERIFIED: requirement] | template / LiveView | `mix test test/sigra/templates/session_templates_test.exs` [VERIFIED: repo file] | ✅ |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/example/test/example_web/live/auth/session_live_test.exs -x` [VERIFIED: recommendation from repo structure]
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/suspicious_login_test.exs test/example/test/example_web/live/auth/session_live_test.exs test/example/test/example_web/live/admin_user_show_live_test.exs test/sigra/templates/session_templates_test.exs` [VERIFIED: recommendation from repo structure]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: workflow norm]

### Wave 0 Gaps
- [ ] Add a dedicated library test file for the new activity query/presenter seam; no such file exists yet. [VERIFIED: repo grep]
- [ ] Add explicit tests for logout attribution and MFA-completion activity semantics; existing auth tests cover revoke-other and suspicious login but not those feed-specific rows. [VERIFIED: test/sigra/auth_test.exs] [VERIFIED: test/sigra/suspicious_login_test.exs]
- [ ] Add user-facing LiveView assertions for the new recent-activity section; current `SessionLiveTest` covers only preserve-current revoke behavior. [VERIFIED: test/example/test/example_web/live/auth/session_live_test.exs]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: phase domain] | Use existing Sigra-authored login/logout/MFA audit seams; do not infer auth state in UI. [VERIFIED: lib/sigra/auth.ex] |
| V3 Session Management | yes [VERIFIED: phase domain] | Use `Sigra.Auth` session lifecycle events and session-store truth. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/session.ex] |
| V4 Access Control | yes [VERIFIED: phase domain] | Scope activity queries to the current subject user through library-owned filters. [VERIFIED: lib/sigra/admin/audit/query.ex] |
| V5 Input Validation | yes [VERIFIED: default security enforcement] | Reuse normalized query/filter params and bounded presenter output. [VERIFIED: lib/sigra/admin/audit/query.ex] |
| V6 Cryptography | no [VERIFIED: phase scope] | No new crypto is required; reuse existing token hashing and signed session semantics. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-user activity disclosure | Information Disclosure | Scope by subject user in the library query seam; never query raw `audit_events` from LiveView with ad hoc filters. [VERIFIED: lib/sigra/admin/audit/query.ex] |
| Semantic spoofing by host UI | Tampering | Centralize labels and row types in a Sigra presenter seam. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] |
| Duplicate or unstable feed rows | Repudiation | Use stable DB ordering and explicit merge rules for `auth.login.success` plus `session.create`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/auth.ex] |
| Overexposed metadata | Information Disclosure | Restrict output to IP, coarse geo, timestamps, and already-owned bounded session metadata. [VERIFIED: .planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md] [VERIFIED: lib/sigra/suspicious_login.ex] |

## Sources

### Primary (HIGH confidence)
- `lib/sigra/auth.ex` - login success, session create/delete/revoke, sudo, MFA completion, and current audit emission coverage.
- `lib/sigra/suspicious_login.ex` - suspicious-login detection and audit emission.
- `lib/sigra/admin/audit/query.ex` - scoped audit query contract.
- `lib/sigra/admin/audit/presenter.ex` - existing audit normalization seam.
- `lib/sigra/admin/users/detail.ex` - recent-audit preview ordering and subject-user usage.
- `test/example/lib/example/accounts.ex` - generated wrapper semantics, including raw-token logout deletion path.
- `test/example/lib/example_web/live/auth/session_live.ex` - current user session surface and best existing host entrypoint.
- `test/example/lib/example_web/controllers/session_controller.ex` - logout telemetry and MFA-completion controller flow.
- `guides/flows/login-and-logout.md` - documented preserve-current/logout contract.
- `guides/flows/account-lifecycle.md` - preserve-current and sudo lifecycle docs.
- `guides/flows/audit-logging.md` - documented built-in event catalog, including the stale `auth.logout` claim.
- `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/MILESTONE-ARC.md`, `.planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md`, `.planning/phases/108-revoke-other-sessions-and-session-truth/108-RESEARCH.md`, `.planning/phases/109-security-activity-and-session-history-truth/109-CONTEXT.md` - milestone and phase boundary constraints.

### Secondary (MEDIUM confidence)
- None. [VERIFIED: source audit]

### Tertiary (LOW confidence)
- None. [VERIFIED: source audit]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended pieces are already present in `mix.lock` or repo-local modules. [VERIFIED: mix.lock] [VERIFIED: repo files]
- Architecture: HIGH - the repo already demonstrates the query/presenter/thin-host split on admin audit surfaces. [VERIFIED: lib/sigra/admin/audit/query.ex] [VERIFIED: lib/sigra/admin/users/detail.ex]
- Pitfalls: HIGH - each identified pitfall traces to concrete current code paths, not hypothetical external patterns. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: test/example/lib/example/accounts.ex]

**Research date:** 2026-05-08 [VERIFIED: repo date]  
**Valid until:** 2026-06-07 [ASSUMED]
