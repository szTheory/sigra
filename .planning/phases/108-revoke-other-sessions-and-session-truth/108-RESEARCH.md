# Phase 108: Revoke other sessions and session truth - Research

**Researched:** 2026-05-07 [VERIFIED: repo date]
**Domain:** Session-control-plane productization on Sigra's existing session/audit substrate [VERIFIED: .planning/REQUIREMENTS.md]
**Confidence:** HIGH [VERIFIED: repo evidence]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Phase framing
- **D-108-01 — Phase 108 is the first `SESS-CTRL` slice and centers on `SESS-02` first.** The most concrete missing control-plane gap in the current code is "revoke every other session while preserving the current one." Security-activity history should wait for a follow-on phase instead of overloading this one.
- **D-108-02 — Keep the control plane thin-host and library-owned.** Generated LiveViews/controllers may call library helpers and render returned truth, but they must not re-implement which sessions count as "other," which session is current, or which disconnect/audit side effects run.

### Session mutation contract
- **D-108-03 — Add an explicit library primitive for revoking every session except the current one.** The contract should take the current session's hashed token (or equivalent authoritative current-session identity) and revoke all sibling sessions for the same user while preserving the current session row.
- **D-108-04 — Preserve existing current-session continuity.** Completing "revoke other sessions" must not log out the user who initiated it, must not delete that session row, and must not require the generated host to stitch the current token back together after the fact.
- **D-108-05 — Side effects must match the actual revoked set.** PubSub disconnect broadcasts, returned counts, and audit metadata should reflect only the sessions actually revoked, excluding the preserved current session.
- **D-108-06 — No inferred "other session" logic in the UI.** User-facing and admin-facing surfaces should not compute "other sessions" by client heuristics beyond current-session labeling; the library mutation result should remain authoritative.

### Truthful session surfacing
- **D-108-07 — Current-session identification must be explicit and consistent.** User and admin session surfaces should clearly mark the current session rather than relying only on position in a list or ad hoc copy.
- **D-108-08 — Show only state Sigra already owns.** If the surface exposes recent-auth, sudo freshness, idle timeout posture, or similar state, it must come from persisted session truth or established session rules already in the library.
- **D-108-09 — Do not invent fake precision for timeout or security posture.** If exact countdowns or device-trust semantics are not persisted today, prefer coarse truthful labels or omit them in this phase.
- **D-108-10 — User and admin truth must stay aligned.** The same session rows, current-session marking, and revoke semantics should drive both generated user settings/session pages and admin user detail surfaces.

### Audit and security posture
- **D-108-11 — Audit should distinguish "revoke others" from "revoke all" if the implementation adds a new action.** Reusing `session.revoke_all` for a preserve-current action would blur operator truth; if a new semantic branch is introduced, its audit/event naming should stay explicit.
- **D-108-12 — Current-session preservation is a security invariant, not just UX polish.** The feature must not silently degrade to "log out everywhere" on error paths or ambiguous token handling.
- **D-108-13 — Security-sensitive operations remain controller/library owned where appropriate.** If any revoke action becomes destructive enough to warrant a controller POST or fresh-sudo check, preserve the existing Sigra pattern of library-owned mutation plus thin-host routing rather than moving mutation into LiveView state handlers.

### Decomposition guidance
- **D-108-14 — Defer security-activity history to a later phase.** `SESS-03` spans suspicious-login outcomes and session lifecycle feeds; planning Phase 108 should leave room for a clean follow-on phase instead of partially implementing an activity surface here.
- **D-108-15 — Preserve generator parity.** Any change to example-app auth/session helpers or LiveViews should update the live install templates and relevant template/generator tests so generated hosts do not drift.

### the agent's Discretion
- Exact public function names for the preserve-current revoke primitive and any return payload
- Whether user-facing revoke-other control lives on the existing sessions page, settings page, or a small adjacent surface, as long as it stays thin-host
- Whether current-session and timeout/recent-auth truth render as badges, sublabels, or compact metadata rows
- Whether the admin surface gets a dedicated "revoke other sessions" control in this phase or only the truthful current-session labeling plus the underlying library seam
- Exact audit action name if a new explicit event is introduced

### Deferred Ideas (OUT OF SCOPE)
- Recent security activity / sign-in history feed (`SESS-03`)
- richer suspicious-login timeline or anomaly explanations
- new device-fingerprint models or GeoIP enrichment
- background session policy enforcement beyond existing timeout rules
- broad account/security-center redesign outside the current session control plane
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SESS-02 | Authenticated users can revoke every other session while preserving the current session, and the generated host surfaces truthful success and failure outcomes. | Use a library-owned preserve-current revoke seam built on the already-shipped `:except_token` path in `Sigra.Auth.delete_all_sessions/3` and `Sigra.SessionStore.delete_all_for_user/2`; wire user-facing success copy from the returned revoked count rather than inferring in the UI. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/session_store.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex] |
| SESS-03 | Users can inspect recent security activity derived from Sigra-owned truth, including recent sign-ins, suspicious-login outcomes, and meaningful session lifecycle events. | Phase 108 should not implement this requirement; the phase boundary explicitly defers activity/feed work to a later `SESS-CTRL` slice. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] |
| SESS-04 | Generated user and admin session surfaces clearly identify the current session and expose recent-auth or timeout state where Sigra already tracks it. | Derive the authoritative current-session hash from the raw session token using the same lookup/hash path as `Example.Accounts.get_user_and_session_by_token/1`, then add explicit current-session/session-state presentation on both user and admin surfaces using existing `hashed_token`, `sudo_at`, `last_active_at`, and timeout rules from `FetchSession`/`RequireSudo`. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/session.ex] [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/require_sudo.ex] |
| SESS-05 | Session-management UX stays thin-host and least-surprise: Sigra owns revoke/activity business rules and generated controllers/LiveViews render those rules without duplicating policy. | Keep revocation orchestration in `Sigra.Auth` and generated wrappers in example/template `Accounts` modules; preserve parity through template tests and example-app coverage. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: priv/templates/sigra.install/core/auth.ex] [VERIFIED: test/sigra/templates/session_templates_test.exs] |
</phase_requirements>

## Summary

Phase 108 should be bounded to `SESS-02` plus the thin slice of `SESS-04`/`SESS-05` needed to make current-session truth visible on existing user and admin session surfaces. The strongest local pattern is not greenfield session management; it is the already-shipped preserve-current path behind password change and the already-shipped `:except_token` option in both the session-store behaviour and the Ecto adapter. [VERIFIED: guides/flows/account-lifecycle.md] [VERIFIED: lib/sigra/session_store.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex] [VERIFIED: lib/sigra/account/password_change.ex]

The current user-facing sessions LiveView already knows the authoritative current session by comparing the current raw cookie token to each listed session hash, but its bulk action is still "log out of all devices" and explicitly logs out the initiator. The admin user detail surface already lists the same session rows through `Sigra.Auth.list_sessions/3`, but it has no current-session labeling and only offers revoke-one / revoke-all semantics. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex]

The main planning risk is truth drift, not missing primitives. `Sigra.Auth.delete_all_sessions/3` currently handles listing, filtered delete, PubSub disconnect, telemetry, and `session.revoke_all` audit in one place, so a preserve-current feature should remain a library-owned orchestration seam instead of pushing "other session" math into LiveViews or admin actions. Security-activity feed work should stay out of Phase 108 because the phase context explicitly defers it and the current admin "Recent Audit" surface is audit-preview oriented, not a user-facing security-activity model. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] [VERIFIED: lib/sigra/admin/users/detail.ex]

**Primary recommendation:** Implement Phase 108 as three plans: library preserve-current revoke contract and audit semantics first, generated user-session UX and template parity second, admin/session-truth alignment third. [VERIFIED: repo synthesis]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Revoke every other session except current | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | `Sigra.Auth` already owns delete-all, audit, telemetry, and PubSub disconnect semantics; LiveViews only trigger and render outcomes. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |
| Current-session identification on user surface | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | API / Backend [VERIFIED: reasoning from repo architecture] | The user surface should derive the current hashed session token authoritatively from the raw token using the existing account/session lookup path, then compare hashes against listed session rows. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |
| Current-session/session-state identification on admin surface | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | API / Backend [VERIFIED: reasoning from repo architecture] | Admin detail is rendered in LiveView, but the session rows come from `Sigra.Auth.list_sessions/3` through `Sigra.Admin.Users.Detail.load!/3`. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| Idle/absolute timeout truth | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | Timeout validity is enforced in `Sigra.Plug.FetchSession`; the UI should only surface coarse truth derived from those rules. [VERIFIED: lib/sigra/plug/fetch_session.ex] |
| Sudo freshness truth | API / Backend [VERIFIED: reasoning from repo architecture] | Frontend Server (LiveView) [VERIFIED: reasoning from repo architecture] | `Sigra.Plug.RequireSudo` evaluates `session.sudo_at`; surfaces should reflect the same state instead of inventing separate heuristics. [VERIFIED: lib/sigra/plug/require_sudo.ex] |
| Live session disconnect side effect | Frontend Server infrastructure / PubSub [VERIFIED: reasoning from repo architecture] | API / Backend [VERIFIED: reasoning from repo architecture] | The library computes session topics and broadcasts disconnect messages after delete-all; the host stores the corresponding `live_socket_id` in session state. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] |

## Project Constraints (from CLAUDE.md)

- Root `mix test` requires a live Postgres at `localhost:5432` with `postgres/postgres`; missing DB is a hard failure, not a skipped lane. [VERIFIED: CLAUDE.md] [VERIFIED: test/test_helper.exs]
- Security-sensitive code belongs in the library and generated host code should stay thin; this matches the project's stated hybrid lib+generator architecture. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/PROJECT.md]
- Generated-host parity matters; template changes should be verified through template/generator coverage, not just example-app edits. [VERIFIED: CLAUDE.md] [VERIFIED: test/sigra/templates/session_templates_test.exs]
- No additional project skills are configured, so planning should follow repo-local patterns instead of hidden skill rules. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | 1.8.5 [VERIFIED: mix.lock] | Web/runtime framework for generated host and admin LiveViews. [VERIFIED: mix.lock] | Existing session/user/admin surfaces are already built on Phoenix conventions; Phase 108 should extend them rather than introduce a parallel surface. [VERIFIED: mix.lock] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| Phoenix LiveView | 1.1.28 [VERIFIED: mix.lock] | Generated user-session and admin session UI runtime. [VERIFIED: mix.lock] | Both session surfaces in scope are LiveViews today. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex] |
| Ecto | 3.13.5 [VERIFIED: mix.lock] | Persistence/query layer for `user_sessions` and audit rows. [VERIFIED: mix.lock] | The preserve-current contract depends on `delete_all` filtering and existing session/audit row truth. [VERIFIED: lib/sigra/session_stores/ecto.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] |
| `Sigra.Auth` | repo-local [VERIFIED: lib/sigra/auth.ex] | Canonical session orchestration, audit, telemetry, and PubSub disconnect logic. [VERIFIED: lib/sigra/auth.ex] | This module already owns `delete_all_sessions/3`, `list_sessions/3`, `revoke_session/3`, and `confirm_sudo/3`. [VERIFIED: lib/sigra/auth.ex] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.SessionStores.Ecto` | repo-local [VERIFIED: lib/sigra/session_stores/ecto.ex] | Implements persisted list/delete/update session row operations. [VERIFIED: lib/sigra/session_stores/ecto.ex] | Use for preserve-current deletes via the existing `:except_token` filter. [VERIFIED: lib/sigra/session_stores/ecto.ex] |
| `Sigra.Admin.Users.Detail` | repo-local [VERIFIED: lib/sigra/admin/users/detail.ex] | Loads admin session rows and recent audit preview for user detail pages. [VERIFIED: lib/sigra/admin/users/detail.ex] | Use when aligning admin session truth with user-facing session truth. [VERIFIED: lib/sigra/admin/users/detail.ex] |
| `Example.Accounts` / install `auth.ex` template | repo-local [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: priv/templates/sigra.install/core/auth.ex] | Thin generated-host wrapper over library session APIs. [VERIFIED: test/example/lib/example/accounts.ex] | Extend here only to expose the new library contract; do not duplicate revoke rules in host code. [VERIFIED: test/example/lib/example/accounts.ex] |
| `ExampleWeb.Auth.SessionLive` / install `session_live.ex` template | repo-local [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: priv/templates/sigra.install/core/session_live.ex] | Current end-user session management surface. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] | Use for the preserve-current bulk action and explicit current-session/session-state labeling. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New preserve-current wrapper in `Sigra.Auth` [VERIFIED: recommendation] | Reuse `delete_all_sessions/3` directly from LiveView with `:except_token` threaded manually. [VERIFIED: lib/sigra/auth.ex] | This keeps code smaller but leaks security semantics and outcome shaping into host code, violating the thin-host boundary. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] |
| Explicit preserve-current audit action [ASSUMED] | Reuse `session.revoke_all` with `count < total`. [VERIFIED: lib/sigra/auth.ex] | Reusing `session.revoke_all` is lower churn but risks audit/operator ambiguity between "everything" and "everything except current." [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] |
| Current-session labeling only on user surface [ASSUMED] | Current-session labeling on both user and admin surfaces. [VERIFIED: context scope] | User-only labeling is less work, but it breaks the context requirement that admin/user truth stay aligned. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] |

**Installation:** Existing dependencies are already present in the repo; no new package is required for the recommended approach. [VERIFIED: mix.exs]

```bash
mix deps.get
```

## Phase Decomposition

### Recommended boundary

Phase 108 should deliver the preserve-current revoke contract, explicit current-session truth on the in-scope session surfaces, and parity coverage. It should not deliver a user-facing security-activity feed, suspicious-login history explorer, or new session-storage semantics. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] [VERIFIED: .planning/REQUIREMENTS.md]

### Recommended plans

| Plan | Scope | Likely Files Touched | Why This Split |
|------|-------|----------------------|----------------|
| 108-01 | Add a library-owned preserve-current revoke seam, count/result payload, and audit/telemetry semantics. [VERIFIED: recommendation from repo patterns] | `lib/sigra/auth.ex`, `lib/sigra/session_store.ex`, `lib/sigra/session_stores/ecto.ex`, `test/sigra/auth_test.exs`, `test/sigra/session_stores/ecto_test.exs`, possibly `test/sigra/admin/users_actions_test.exs`. [VERIFIED: repo paths] | This isolates the core security invariant and side effects before any UI work. [VERIFIED: repo synthesis] |
| 108-02 | Wire generated user-session UX to the new seam and surface explicit current-session / coarse session-state truth. [VERIFIED: recommendation from repo patterns] | `test/example/lib/example/accounts.ex`, `test/example/lib/example_web/live/auth/session_live.ex`, `test/example/lib/example_web/user_auth.ex`, `priv/templates/sigra.install/core/auth.ex`, `priv/templates/sigra.install/core/session_live.ex`, `priv/templates/sigra.install/core/user_auth.ex`, `test/sigra/templates/session_templates_test.exs`, new example LiveView test file. [VERIFIED: repo paths] | User-facing truth is the visible requirement driver for `SESS-02`. [VERIFIED: .planning/REQUIREMENTS.md] |
| 108-03 | Align admin session truth and docs/tests without broadening into activity-feed work. [VERIFIED: recommendation from repo patterns] | `lib/sigra/admin/users/detail.ex`, `lib/sigra/admin/users/actions.ex`, `lib/sigra/admin/live/user_show_live.ex`, `test/example/test/example_web/live/admin_user_show_live_test.exs`, `guides/flows/login-and-logout.md`, `guides/flows/account-lifecycle.md`. [VERIFIED: repo paths] | Admin already shares the same session rows, so current-session labeling and revoke semantics should be reconciled after the library/user slice is stable. [VERIFIED: lib/sigra/admin/users/detail.ex] |

## Architecture Patterns

### System Architecture Diagram

```text
Browser click
  -> User Session LiveView / Admin User Show LiveView
  -> generated Accounts wrapper
  -> Sigra.Auth preserve-current revoke seam
  -> SessionStore.list_by_user
  -> SessionStore.delete_all_for_user(except_token: current_hashed_token)
  -> audit write + telemetry event + PubSub disconnect for revoked siblings
  -> updated session list + revoked count/result
  -> LiveView flash / badges / refreshed list
```

All revoke-set membership and side effects should be computed before the UI renders outcome copy. [VERIFIED: lib/sigra/auth.ex]

### Recommended Project Structure

```text
lib/sigra/                    # Library-owned session contract, audit semantics, admin detail loader
test/example/lib/example/     # Generated-host wrapper and user/admin LiveViews used as parity source
priv/templates/sigra.install/ # Install templates that must stay in lockstep with example code
test/sigra/ + test/example/   # Library and generated-host verification layers
guides/flows/                 # Public contract docs for session and account lifecycle behavior
```

### Pattern 1: Preserve-Current Revoke as a Library Wrapper

**What:** Add a dedicated `Sigra.Auth` entrypoint that receives the authoritative current-session identity and delegates bulk deletion through the existing `:except_token` path. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/session_store.ex]

**When to use:** Use this for end-user "log out other sessions/devices" flows and any admin-preserve-current flow that must exclude the initiator's current session rather than revoking every row. [VERIFIED: context scope]

**Example:**

```elixir
# Source: lib/sigra/auth.ex + lib/sigra/session_store.ex
except_token = Keyword.get(opts, :except_token)
{count, _} = session_store.delete_all_for_user(user_id, Keyword.put(store_opts, :except_token, except_token))
```

This is the strongest local reuse point because both the behaviour and the Ecto adapter already acknowledge preserve-current deletes. [VERIFIED: lib/sigra/session_store.ex] [VERIFIED: lib/sigra/session_stores/ecto.ex]

### Pattern 2: Current-Session Truth from Authoritative Hashed-Token Derivation

**What:** Drive current-session labeling from the authoritative hashed session token derived from the raw cookie token, not from direct raw-bytes vs hashed-token comparison and not from browser heuristics. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex]

**When to use:** Use on the user session page and reuse the same truth source when adding admin current-session labeling. [VERIFIED: test/example/lib/example/accounts.ex] [ASSUMED]

**Example:**

```elixir
# Source: test/example/lib/example/accounts.ex
with {:ok, raw_bytes} <- Base.url_decode64(raw_token, padding: false) do
  hashed = Sigra.Token.hash_token(raw_bytes)
  store.fetch(hashed, store_opts)
end
```

### Pattern 3: Session-State Surfacing Must Reuse Existing Owned Fields Only

**What:** Render only state already persisted or already enforced by the library, namely `last_active_at`, `sudo_at`, session `type`, and the timeout rules in `FetchSession`/`RequireSudo`. [VERIFIED: lib/sigra/session.ex] [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/require_sudo.ex]

**When to use:** Use for coarse labels like "sudo active", "sudo expired", "remember me session", or "last active" summaries; do not add second-by-second timeout countdowns in this phase. [VERIFIED: context scope] [ASSUMED]

### Anti-Patterns to Avoid

- **UI-computed revoke set:** Do not compute "other sessions" in LiveView by filtering the list and then calling per-session revoke in a loop; the library already has a bulk delete + disconnect path. [VERIFIED: lib/sigra/auth.ex]
- **Audit semantic collapse:** Do not report preserve-current revocation as plain `session.revoke_all` without an explicit reviewed decision, because operator truth becomes ambiguous. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] [ASSUMED]
- **Admin/user truth drift:** Do not add current-session badges or session-state copy to only one surface; both surfaces read the same session rows. [VERIFIED: lib/sigra/admin/users/detail.ex] [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex]
- **Invented timeout precision:** Do not expose an exact idle countdown unless that value is actually persisted or computed authoritatively per request. [VERIFIED: lib/sigra/plug/fetch_session.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Preserve-current bulk revoke | A new ad hoc query path inside LiveView or admin actions. [VERIFIED: recommendation] | `Sigra.Auth` wrapper over `delete_all_sessions/3` + `:except_token`. [VERIFIED: lib/sigra/auth.ex] | Reuses existing delete, disconnect, telemetry, and audit orchestration. [VERIFIED: lib/sigra/auth.ex] |
| Current-session truth | Browser-only device heuristics or list-position assumptions. [VERIFIED: recommendation] | Authoritative current hashed token derivation from the raw session token, then hash-to-hash comparison against listed sessions. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] | The raw current token is already stored in the session, and the account lookup path already knows how to derive the persisted session hash correctly. [VERIFIED: test/example/lib/example/accounts.ex] |
| Session-state truth | A separate read model for "recent auth" or timeout state. [VERIFIED: recommendation] | Existing `sudo_at`, `last_active_at`, session `type`, and timeout rules. [VERIFIED: lib/sigra/session.ex] [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/require_sudo.ex] | A parallel model would drift from the request-time enforcement path. [VERIFIED: lib/sigra/plug/fetch_session.ex] |

**Key insight:** The repository already has the hard parts of session control; Phase 108 should package them into an explicit contract and truthful surfaces, not add a second session policy engine. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: lib/sigra/account/password_change.ex]

## Common Pitfalls

### Pitfall 1: Disconnect Topic Mismatch

**What goes wrong:** Revoked sessions stay connected in LiveView even though the DB rows were deleted. [VERIFIED: risk from existing topic wiring]
**Why it happens:** The host stores `live_socket_id` as `"users_sessions:" <> Base.url_encode64(raw_token)`, while the library currently broadcasts using `Base.url_encode64(session.hashed_token)`. Any preserve-current path that reuses this mechanism inherits that mapping risk. [VERIFIED: test/example/lib/example_web/user_auth.ex] [VERIFIED: lib/sigra/auth.ex]
**How to avoid:** Verify topic compatibility before treating PubSub disconnect as authoritative proof; if needed, fix the mapping inside the library/host contract rather than per surface. [VERIFIED: repo synthesis]
**Warning signs:** Bulk revoke deletes rows successfully but the initiator still sees sibling LiveViews connected until refresh. [ASSUMED]

### Pitfall 2: Audit Meaning Drift Between "Revoke All" and "Revoke Others"

**What goes wrong:** Operators cannot tell whether the initiating session was preserved. [VERIFIED: context decision]
**Why it happens:** `delete_all_sessions/3` always writes `session.revoke_all` today, even when `:except_token` is used. [VERIFIED: lib/sigra/auth.ex]
**How to avoid:** Either add a dedicated action name or encode an explicit semantic discriminator in audit metadata, with the library as the single writer. [VERIFIED: context decision] [ASSUMED]
**Warning signs:** Admin recent-audit preview shows identical rows for "logout everywhere" and "logout other sessions." [VERIFIED: lib/sigra/admin/users/detail.ex] [ASSUMED]

### Pitfall 3: Current-Session Identification Drift

**What goes wrong:** User and admin surfaces disagree on which session is current. [VERIFIED: risk from current code shape]
**Why it happens:** The user surface has explicit current-token logic, while the admin surface currently has none. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: lib/sigra/admin/live/user_show_live.ex]
**How to avoid:** Centralize "is current session?" truth in a reusable helper or shared contract instead of duplicating subtly different comparisons. [ASSUMED]
**Warning signs:** Admin labels are based on recency, IP, or browser labels rather than the authoritative token/session identity. [ASSUMED]

### Pitfall 4: Showing Timeout or Sudo State That the Library Does Not Actually Persist

**What goes wrong:** The UI claims a session is "fresh" or "expiring soon" without matching request behavior. [VERIFIED: risk from timeout/sudo architecture]
**Why it happens:** Idle/absolute timeouts are enforced at request time, and `RequireSudo` only evaluates `sudo_at`; there is no persisted countdown field. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/require_sudo.ex]
**How to avoid:** Render coarse labels backed by existing fields or omit the label in this phase. [VERIFIED: context decision]
**Warning signs:** UI copy includes exact minutes remaining without any matching server-side source of truth. [ASSUMED]

## Code Examples

Verified patterns from local source:

### Preserve-current bulk revoke kernel

```elixir
# Source: lib/sigra/auth.ex
except_token = Keyword.get(opts, :except_token)
{count, _} = session_store.delete_all_for_user(user_id, delete_opts)
```

`delete_opts` already carries `:except_token` when present. [VERIFIED: lib/sigra/auth.ex]

### Current-session badge kernel

```elixir
# Source: test/example/lib/example_web/live/auth/session_live.ex
current_token = get_connect_params(socket)["_sigra_token"]
current_session?(session, current_token)
```

This is the existing generated-host truth source for "This device." [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex]

### Existing preserve-current precedent outside Phase 108

```elixir
# Source: lib/sigra/account/password_change.ex
except_token = Keyword.get(opts, :except_token)
session_store.delete_all_for_user(user.id, except_token: except_token)
```

This proves Sigra already treats preserve-current invalidation as a normal session-lifecycle operation. [VERIFIED: lib/sigra/account/password_change.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| User session page supports revoke-one and revoke-all, but revoke-all logs out the current session. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] | Phase 108 should add a preserve-current bulk revoke path without replacing the existing lower-level revoke-all substrate. [VERIFIED: context scope] | Not yet shipped; this is the Phase 108 target. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] | Closes the main `SESS-02` gap without redesigning storage. [VERIFIED: .planning/REQUIREMENTS.md] |
| Admin detail shows session rows but has no explicit current-session truth. [VERIFIED: lib/sigra/admin/live/user_show_live.ex] | Phase 108 should align admin labeling with the same session truth already used on the user surface. [VERIFIED: context scope] | Not yet shipped; this is the Phase 108 target. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] | Reduces admin/user truth drift for `SESS-04`. [VERIFIED: .planning/REQUIREMENTS.md] |
| Preserve-current session invalidation already exists as a lower-level pattern for password/email lifecycle flows. [VERIFIED: lib/sigra/account/password_change.ex] [VERIFIED: lib/sigra/account/email_change.ex] | Phase 108 should expose that pattern as an explicit session-control-plane contract. [VERIFIED: recommendation] | Preserve-current lifecycle code shipped before v1.24. [VERIFIED: guides/flows/account-lifecycle.md] | Reuse is safer than inventing a parallel session policy path. [VERIFIED: repo synthesis] |

**Deprecated/outdated:**

- Treating `SESS-CTRL` as a greenfield device-management milestone is outdated because session/device labeling and preserve-current invalidation substrate are already substantially shipped. [VERIFIED: .planning/MILESTONE-ARC.md] [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A dedicated audit action such as `session.revoke_others` is preferable to overloading `session.revoke_all`. [ASSUMED] | Alternatives Considered / Common Pitfalls | Planner may overspec an audit rename that the maintainer would rather encode in metadata only. |
| A2 | Admin current-session truth should ship in Phase 108 even if admin does not get a dedicated preserve-current button. [ASSUMED] | Phase Decomposition | Planner could over-scope admin mutation work if only labeling truth was intended. |
| A3 | A shared helper for current-session identification is likely worth adding to avoid duplicated token-comparison logic. [ASSUMED] | Common Pitfalls | Planner may reserve a refactor slice that the implementation can avoid. |

## Open Questions (RESOLVED)

1. **Should preserve-current bulk revoke emit a new audit action or reuse `session.revoke_all` with richer metadata?**
   - Resolution: use a distinct preserve-current audit semantic such as `session.revoke_others` so operator truth does not blur with destructive revoke-all behavior. [RESOLVED: planner + checker alignment]
   - Why: `delete_all_sessions/3` currently emits `session.revoke_all`, but the phase context explicitly warns against semantic blur and the plan set now depends on distinct wording across library, admin, and docs. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md]

2. **Does the admin surface need a preserve-current action in Phase 108, or only aligned truth labeling?**
   - Resolution: Phase 108 stops at aligned current-session/session-state labeling on the admin surface and does not add a new admin-only preserve-current bulk action. [RESOLVED: planner + checker alignment]
   - Why: that keeps the phase bounded to `SESS-02` plus minimum `SESS-04/05` truth work, while deferring any broader admin operator story to a later slice if it proves necessary. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Root and example test runs | ✓ [VERIFIED: local shell] | 1.19.5 [VERIFIED: local shell] | — |
| `elixir` | Compilation and test runs | ✓ [VERIFIED: local shell] | 1.19.5 / OTP 28 [VERIFIED: local shell] | — |
| PostgreSQL client (`psql`) | Root tests expect a live Postgres-backed environment | ✓ [VERIFIED: local shell] | 14.17 [VERIFIED: local shell] | Docker-hosted DB still required if local server is absent. [VERIFIED: CLAUDE.md] |
| Docker | Fast local Postgres bootstrap | ✓ [VERIFIED: local shell] | 29.4.1 [VERIFIED: local shell] | Use any already-running local Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md] |

**Missing dependencies with no fallback:**

- None found in this environment audit. [VERIFIED: local shell]

**Missing dependencies with fallback:**

- None found in this environment audit. [VERIFIED: local shell]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix.ConnTest / Phoenix.LiveViewTest on both root and example app. [VERIFIED: test/test_helper.exs] [VERIFIED: test/example/test/test_helper.exs] |
| Config file | Root `test/test_helper.exs`; example app `test/example/test/test_helper.exs`. [VERIFIED: repo paths] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/plug/fetch_session_test.exs test/sigra/plug/require_sudo_test.exs test/sigra/admin/users_actions_test.exs` [VERIFIED: repo paths] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && (cd test/example && MIX_ENV=test mix test)` [VERIFIED: CLAUDE.md] [VERIFIED: mix.exs] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-02 | Preserve-current revoke deletes sibling sessions only, emits truthful count, and does not disconnect the initiator. [VERIFIED: requirement + repo synthesis] | unit + integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/auth_test.exs test/sigra/session_stores/ecto_test.exs test/sigra/admin/users_actions_test.exs` [VERIFIED: repo paths] | ✅ existing files to extend [VERIFIED: repo paths] |
| SESS-02 | Generated user session surface exposes "log out other sessions" and preserves current login. [VERIFIED: requirement + repo synthesis] | LiveView example-app | `(cd test/example && MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs)` [ASSUMED: command path after file creation] | ❌ Wave 0 [VERIFIED: `rg --files` search] |
| SESS-04 | User/admin surfaces clearly identify current session and truthful session state. [VERIFIED: requirement] | LiveView + unit | `(cd test/example && MIX_ENV=test mix test test/example_web/live/admin_user_show_live_test.exs test/example_web/user_auth_test.exs)` [VERIFIED: repo paths] | ✅ admin/user_auth files exist; user session LiveView file missing. [VERIFIED: repo paths] |
| SESS-05 | Generated wrappers remain thin and template parity is preserved. [VERIFIED: requirement] | template + generator | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/templates/session_templates_test.exs` [VERIFIED: repo path] | ✅ existing file [VERIFIED: repo path] |

### Sampling Rate

- **Per task commit:** Run the root quick suite above, plus the example-app targeted suite for any changed generated surface. [VERIFIED: repo synthesis]
- **Per wave merge:** Run root targeted tests and `(cd test/example && mix test ...)` for touched example-admin/user files. [VERIFIED: repo synthesis]
- **Phase gate:** Run the documented full-suite command before `/gsd-verify-work`. [VERIFIED: CLAUDE.md]

### Wave 0 Gaps

- [ ] `test/example/test/example_web/live/auth/session_live_test.exs` — missing dedicated user-session LiveView coverage for preserve-current revoke and current-session truth. [VERIFIED: `rg --files` search]
- [ ] Extend `test/sigra/auth_test.exs` — add explicit preserve-current semantic assertions beyond the current `except_token` path. [VERIFIED: test/sigra/auth_test.exs]
- [ ] Extend `test/example/test/example_web/live/admin_user_show_live_test.exs` — add assertions for current-session labeling / truthful bulk-revoke copy. [VERIFIED: test/example/test/example_web/live/admin_user_show_live_test.exs]
- [ ] Extend `test/sigra/templates/session_templates_test.exs` — assert any new wrapper/template entrypoint or UI copy fragments required for parity. [VERIFIED: test/sigra/templates/session_templates_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: requirement scope] | Reuse current authenticated session identity; do not authorize preserve-current revoke from untrusted client heuristics. [VERIFIED: context scope] |
| V3 Session Management | yes [VERIFIED: requirement scope] | Server-side session rows via `Sigra.SessionStores.Ecto` and server-owned revoke/delete flows. [VERIFIED: lib/sigra/session_stores/ecto.ex] |
| V4 Access Control | yes [VERIFIED: requirement scope] | User scope controls own sessions; admin actions stay scope-checked through `Sigra.Admin.Users.Actions` and `Detail.load_user!/4`. [VERIFIED: lib/sigra/admin/users/actions.ex] [VERIFIED: lib/sigra/admin/users/detail.ex] |
| V5 Input Validation | yes [VERIFIED: requirement scope] | Base64 decode and typed session-token handling in generated/user/admin flows; reject malformed tokens rather than guessing. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [VERIFIED: test/example/lib/example/accounts.ex] |
| V6 Cryptography | yes [VERIFIED: session design] | Continue using Sigra token hashing and opaque session tokens; never surface or persist raw tokens beyond the cookie/session path. [VERIFIED: lib/sigra/session.ex] [VERIFIED: test/example/lib/example/accounts.ex] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Preserve-current action accidentally revokes the initiator | Denial of service [VERIFIED: risk from requirement] | Library-owned `:except_token` path plus explicit tests around count, remaining row, and no disconnect for the preserved session. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/sigra/auth_test.exs] |
| User/admin truth drift about which session is current | Spoofing / Repudiation [VERIFIED: risk from current code shape] | Reuse a single authoritative current-session identification rule across both surfaces. [VERIFIED: test/example/lib/example_web/live/auth/session_live.ex] [ASSUMED] |
| Ambiguous audit trail for revoke-other vs revoke-all | Repudiation [VERIFIED: context decision] | Keep a distinct library-owned semantic branch via explicit action name or metadata discriminator. [VERIFIED: .planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md] [ASSUMED] |
| Timeout/sudo copy overstates freshness | Elevation of privilege [VERIFIED: risk from timeout/sudo architecture] | Surface only what `FetchSession` and `RequireSudo` actually enforce. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/require_sudo.ex] |

## Sources

### Primary (HIGH confidence)

- `/.planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md` - authoritative phase boundary, locked decisions, and deferred scope. [VERIFIED: repo file]
- `/.planning/REQUIREMENTS.md` - active `SESS-02..05` milestone contract. [VERIFIED: repo file]
- `/.planning/MILESTONE-ARC.md` - ownership boundary and corrected milestone framing. [VERIFIED: repo file]
- `/lib/sigra/auth.ex` - current delete-all/list/revoke/sudo orchestration and audit/PubSub behavior. [VERIFIED: repo file]
- `/lib/sigra/session_store.ex` and `/lib/sigra/session_stores/ecto.ex` - existing preserve-current adapter contract and implementation. [VERIFIED: repo files]
- `/lib/sigra/plug/fetch_session.ex` and `/lib/sigra/plug/require_sudo.ex` - authoritative timeout and sudo freshness rules. [VERIFIED: repo files]
- `/lib/sigra/admin/users/detail.ex`, `/lib/sigra/admin/users/actions.ex`, `/lib/sigra/admin/live/user_show_live.ex` - admin session truth/read paths and mutation wrappers. [VERIFIED: repo files]
- `/test/example/lib/example/accounts.ex`, `/test/example/lib/example_web/user_auth.ex`, `/test/example/lib/example_web/live/auth/session_live.ex` - generated-host parity baseline and current-session labeling source. [VERIFIED: repo files]
- `/guides/flows/login-and-logout.md` and `/guides/flows/account-lifecycle.md` - documented revoke-all and preserve-current lifecycle precedent. [VERIFIED: repo files]
- `/mix.exs` and `/mix.lock` - framework versions and root/example test layout constraints. [VERIFIED: repo files]

### Secondary (MEDIUM confidence)

- None. [VERIFIED: research session]

### Tertiary (LOW confidence)

- None. [VERIFIED: research session]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Phase 108 reuses repo-local modules and versions already locked in `mix.exs` / `mix.lock`. [VERIFIED: mix.exs] [VERIFIED: mix.lock]
- Architecture: HIGH - The library-vs-generated-host boundary is explicit in project docs and reflected in the current session/admin code. [VERIFIED: .planning/PROJECT.md] [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: lib/sigra/auth.ex]
- Pitfalls: MEDIUM - The disconnect-topic mismatch and audit naming ambiguity are real repo risks, but the best final mitigation still depends on one or two implementation choices not yet locked. [VERIFIED: lib/sigra/auth.ex] [VERIFIED: test/example/lib/example_web/user_auth.ex] [ASSUMED]

**Research date:** 2026-05-07 [VERIFIED: local shell]
**Valid until:** 2026-06-06 for repo-local planning, unless session/admin surfaces change materially before planning starts. [ASSUMED]
