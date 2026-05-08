# Phase 109: Security activity and session history truth - Context

**Gathered:** 2026-05-08
**Status:** Ready for planning
**Source:** Local synthesis from v1.24 requirements plus completed Phase 108 planning because `ROADMAP.md` still has milestone-level `SESS-CTRL` framing only

<domain>
## Phase Boundary

Turn Sigra's existing audit, suspicious-login, and session lifecycle truth into a user-facing recent security activity surface that stays aligned with the admin/operator view.

Phase 108 already covered the preserve-current revoke contract and current-session truth. Phase 109 should pick up the explicitly deferred `SESS-03` work: recent sign-ins, suspicious-login outcomes, and meaningful session lifecycle events rendered through a thin-host generated surface backed by library-owned query/presentation rules.

**Explicitly in scope:**
- a Sigra-owned security-activity query/presentation seam for generated hosts
- recent sign-in and session lifecycle activity derived from existing audit/session truth
- suspicious-login outcomes surfaced as user-visible activity without inventing new fraud semantics
- truthful generated-host UX for reviewing recent account/session security events
- alignment between user-facing activity labels and the admin audit/detail surfaces where they overlap

**Explicitly out of scope:**
- new session mutation semantics beyond Phase 108's preserve-current work
- session-store redesign, alternate adapters, or event-storage redesign
- geo enrichment, device fingerprinting, trust scoring, or fraud/risk engines
- generic full audit explorer UX for end users with arbitrary filters/export
- hosted-control-plane style security center expansion unrelated to recent session/security truth

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<specifics>
## Specific Ideas

- The repo already has audit truth for session lifecycle and related auth events, including `session.create`, `session.revoke_all`, `session.revoke_others`, and `security.suspicious_login`.
- The admin user detail page already renders a small "Recent Audit" preview and links to the full scoped audit explorer, which is strong evidence that Phase 109 should reuse audit query/presenter seams rather than invent a new event source.
- The generated user session LiveView already exposes current-session and revoke-other controls after Phase 108, but it has no recent security activity/history surface yet.
- That suggests a bounded split:
  - library/query/presenter seam first
  - generated-host user surface and template parity second
  - admin/user alignment, docs, and edge-case coverage last

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing
- `.planning/PROJECT.md` — v1.24 remains the active session-control-plane milestone
- `.planning/REQUIREMENTS.md` — authoritative `SESS-02..05` milestone contract; `SESS-03` is the focus here
- `.planning/ROADMAP.md` — milestone-level `SESS-CTRL` note; phase decomposition still absent from the active roadmap
- `.planning/STATE.md` — continuity note that v1.24 planning follows the webhook milestone closeout
- `.planning/MILESTONE-ARC.md` — ranking and ownership rules favor deepening shipped substrate with truthful rough-edge UX

### Prior phase boundary
- `.planning/phases/108-revoke-other-sessions-and-session-truth/108-CONTEXT.md` — authoritative statement that `SESS-03` was deferred to a follow-on phase
- `.planning/phases/108-revoke-other-sessions-and-session-truth/108-RESEARCH.md` — evidence about existing session/admin seams and truth boundaries
- `.planning/phases/108-revoke-other-sessions-and-session-truth/108-SOURCE-AUDIT.md` — confirms activity-feed work was intentionally excluded from Phase 108

### Existing audit and activity seams
- `lib/sigra/audit.ex` — canonical audit write contract and reserved-prefix semantics
- `lib/sigra/admin/audit/query.ex` — scoped audit query builder used by admin surfaces
- `lib/sigra/admin/audit/presenter.ex` — canonical audit presentation layer for admin/user-facing labels if reusable
- `lib/sigra/admin/users/detail.ex` — current recent-audit preview seam on the admin user detail page
- `lib/sigra/admin/live/user_show_live.ex` — current admin rendering for the recent-audit preview
- `lib/sigra/suspicious_login.ex` — existing suspicious-login detection, telemetry, and audit emission
- `lib/sigra/auth.ex` — existing session lifecycle audit emission and session control contracts
- `lib/sigra/session.ex` — authoritative session fields already owned by the library

### Generated-host/user seams
- `test/example/lib/example/accounts.ex` — generated wrapper surface where a user-facing activity query may be exposed
- `test/example/lib/example_web/live/auth/session_live.ex` — current generated user session page with no recent security activity feed yet
- `priv/templates/sigra.install/core/auth.ex` — installer parity for generated account/session helpers
- `priv/templates/sigra.install/core/session_live.ex` — installer parity for the user session surface

### Existing docs and tests
- `test/example/test/example_web/live/auth/session_live_test.exs` — current generated-host session LiveView baseline
- `test/example/test/example_web/live/admin_user_show_live_test.exs` — admin user detail baseline including recent-audit preview assertions
- `test/example/test/example_web/live/admin_audit_user_live_test.exs` — scoped audit explorer behavior baseline
- `test/example/test/example_web/audit_integration_test.exs` — session-create audit evidence
- `guides/flows/login-and-logout.md` — public contract for session and sign-in/out behavior
- `guides/flows/account-lifecycle.md` — related user-facing account/session truth guidance

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The admin detail surface already prepares a bounded recent-audit preview with stable ordering and presentation.
- Suspicious-login already emits a dedicated audit event and optional email notification.
- Session lifecycle audit events already exist in the auth/session stack.
- The generated-host session LiveView is the most natural existing surface to extend unless planning finds a cleaner adjacent security page.

### Established Patterns
- Sigra prefers library-owned query/mutation semantics with thin generated-host wrappers.
- Admin surfaces already use query-builder plus presenter layers to keep audit semantics centralized.
- Template parity is enforced through example-app plus raw-template tests.
- Security surfaces must stay honest about missing certainty; if the system does not own a detail, omit it.

### Integration Points
- audit query/presenter modules for normalized activity rows
- `Sigra.Auth` or a related library module for any missing session/security event emission
- generated `Accounts` wrappers for the user-facing activity API
- generated session/security LiveView for the visible recent-activity surface
- docs/tests/templates for parity and contract coverage

</code_context>

<deferred>
## Deferred Ideas

- arbitrary end-user audit filtering/export
- geolocation/risk scoring beyond existing coarse metadata
- a broader "security center" or device-intelligence dashboard
- organization-wide or admin-product activity feeds unrelated to the current user's account/session story
- session storage redesign or new event-store infrastructure

</deferred>

---

*Phase: 109-security-activity-and-session-history-truth*
*Context gathered: 2026-05-08*
