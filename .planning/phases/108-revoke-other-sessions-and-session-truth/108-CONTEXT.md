# Phase 108: Revoke other sessions and session truth - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning
**Source:** Local synthesis from v1.24 requirements because `ROADMAP.md` has milestone-level `SESS-CTRL` framing but no decomposed Phase 108 entry yet

<domain>
## Phase Boundary

Turn Sigra's already-shipped session substrate into a truthful "revoke every other session" control plane for both user-facing and admin-facing session surfaces.

This phase is the first `SESS-CTRL` slice. It should productize the existing session listing, per-session revoke, revoke-all, timeout, and sudo substrate into a library-owned contract that preserves the current session while ending every other session cleanly. Generated host surfaces should render that truth without duplicating the business rules.

**Explicitly in scope:**
- a library-owned "revoke every other session except current" primitive
- truthful outcome reporting for the current session vs. revoked sibling sessions
- generated user session UX for "log out other devices/sessions" without destroying the current session
- generated/admin session surfacing that clearly identifies the current session and any already-tracked security state worth showing here
- audit and disconnect behavior that stays aligned with the actual session rows being revoked

**Explicitly out of scope:**
- recent security activity or sign-in history feeds derived from audit truth
- new session storage models, alternate adapters, or token formats
- generic account-center expansion unrelated to session/security controls
- hosted-control-plane-style device intelligence, geolocation enrichment, or fraud scoring
- operator policy beyond truthful rendering of library-owned session state

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<specifics>
## Specific Ideas

- The current generated user session LiveView already has:
  - per-session revoke
  - current-session badge via connect params
  - "log out of all devices" that destroys the current session too
- The current library already has:
  - `Sigra.Auth.delete_all_sessions/3` with `:except_token`
  - session listing that excludes `:mfa_pending`
  - timeout and sudo rules in `Sigra.Plug.FetchSession` / `Sigra.Session`
  - audit and PubSub disconnect behavior for broad revocation
- That means Phase 108 should productize existing seams, not redesign them:
  - expose a dedicated preserve-current revoke contract
  - thread truthful counts/messages through user/admin surfaces
  - add labels for current session and already-known session posture

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing
- `.planning/PROJECT.md` — v1.24 is the active session-control-plane milestone and the next action explicitly says to plan Phase 108
- `.planning/REQUIREMENTS.md` — authoritative `SESS-02..05` milestone contract and out-of-scope boundaries
- `.planning/ROADMAP.md` — milestone-level note that `SESS-CTRL` is the active follow-on and phase planning starts at 108
- `.planning/STATE.md` — continuity note that Phase 108 is the next active work
- `.planning/MILESTONE-ARC.md` — ranking and ownership rules: deepen shipped substrate, preserve thin-host generated UX, and avoid hosted-control-plane sprawl

### Existing session/auth seams
- `lib/sigra/auth.ex` — canonical session list/revoke/revoke-all/sudo APIs; `delete_all_sessions/3` already supports `:except_token`
- `lib/sigra/session.ex` — authoritative session struct fields already owned by the library
- `lib/sigra/session_stores/ecto.ex` — persisted session row operations and current delete/list/update behavior
- `lib/sigra/plug/fetch_session.ex` — idle/absolute timeout evaluation already tracked in the request path
- `lib/sigra/plug/require_sudo.ex` — existing fresh-auth boundary pattern if planning decides revoke-other requires stronger gating
- `lib/sigra/suspicious_login.ex` — existing suspicious-login truth, explicitly deferred as an activity-feed input for a later phase

### Generated-host/user seams
- `test/example/lib/example/accounts.ex` — generated auth/session helpers (`list_sessions`, `revoke_session`, `revoke_all_sessions`, `confirm_sudo`)
- `test/example/lib/example_web/live/auth/session_live.ex` — current user-facing active-sessions UI and its current-session token handling
- `test/example/lib/example_web/user_auth.ex` — Plug session token ownership, current-scope loading, impersonation/session continuity
- `test/example/lib/example/accounts/user_session.ex` — generated host session schema fields available for truthful surfacing
- `priv/templates/sigra.install/core/auth.ex` — installer auth helper template parity
- `priv/templates/sigra.install/core/user_auth.ex` — installer web auth helper parity
- `priv/templates/sigra.install/core/session_live.ex` — installer user session surface parity

### Admin/operator seams
- `lib/sigra/admin/users/actions.ex` — scope-aware admin session revoke wrappers
- `lib/sigra/admin/live/user_show_live.ex` — current admin session truth and revoke-all surface
- `lib/sigra/admin/users/detail.ex` — admin detail-loading seam that feeds session lists and related truth

### Existing docs and tests
- `guides/flows/login-and-logout.md` — existing "log out everywhere" contract and current session-management guidance
- `guides/flows/account-lifecycle.md` — preserve-current session precedent via password-change flow
- `test/sigra/templates/session_templates_test.exs` — template contract coverage for session generator artifacts
- `test/example/test/example_web/session_*` and session-related LiveView/Conn tests — current behavior baseline for generated session UX

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `delete_all_sessions/3` already accepts `:except_token`, which is the likely kernel of a preserve-current implementation.
- The generated session LiveView already knows the current token via connect params and marks "This device".
- Session rows already carry `sudo_at`, `last_active_at`, IP, parsed user-agent data, and organization scope.
- Admin user detail already loads session rows and exposes revoke/revoke-all controls.

### Established Patterns
- Sigra prefers library-owned security logic with thin generated-host wrappers.
- Truthful operator and user-facing surfaces should read persisted library truth instead of reconstructing state client-side.
- Sensitive flows often use controller/plug boundaries when request-time guarantees matter more than LiveView state.
- Generator parity is enforced through both live templates and fixture/template tests.

### Integration Points
- `Sigra.Auth` for a new preserve-current revoke seam and audit/event contract
- generated account/auth helpers for exposing the new seam to host apps
- user sessions LiveView for the visible "revoke other sessions" control and truthful messaging
- admin user detail for aligned current-session truth and possibly scoped preserve-current support
- docs/tests/templates for generator parity and regression coverage

</code_context>

<deferred>
## Deferred Ideas

- Recent security activity / sign-in history feed (`SESS-03`)
- richer suspicious-login timeline or anomaly explanations
- new device-fingerprint models or GeoIP enrichment
- background session policy enforcement beyond existing timeout rules
- broad account/security-center redesign outside the current session control plane

</deferred>

---

*Phase: 108-revoke-other-sessions-and-session-truth*
*Context gathered: 2026-05-07*
