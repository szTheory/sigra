# Phase 91: Org-level MFA enforcement (B2B-01) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-29
**Phase:** 91-org-level-mfa-enforcement-b2b-01
**Areas discussed:** Pipeline integration, Allowlist exemption, Admin self-lockout, Audit shape + idempotency

---

## Pipeline Integration

### Q1 — Plug placement in the generated router

| Option | Description | Selected |
|--------|-------------|----------|
| Inside `:org_scoped` | After LoadOrganizationFromSlug + RequireMembership in existing pipeline. Only `/organizations/:org/*` gated. Account-level routes naturally exempt. Matches success criterion #3. | ✓ |
| On `:require_authenticated` | Every authenticated route gated when active org enforces. Forces explicit allowlist for account-level routes. Higher deadlock risk. | |
| Separate `:org_scoped_mfa` pipeline | Host opts each route in via pipe_through. Defeats "no host code edit needed." | |

**User's choice:** Inside `:org_scoped` (Recommended).
**Notes:** Locks the natural hard-wall + carve-out structure for free.

### Q2 — Halt mode on enforcement failure

| Option | Description | Selected |
|--------|-------------|----------|
| `error_handler.auth_error/2` delegation | Match RequireMembership: pass `:mfa_required` reason to host's error_handler. Customizable copy / route / format. | ✓ |
| Hardcoded redirect with flash | Match RequireMFAEnrolled: Phoenix.Controller.put_flash + redirect. No JSON path, no host hook. | |
| Dual-mode (JSON vs HTML detection) | Detect `accept: application/json`; 403 JSON for API, redirect for HTML. More code now; pays off Phase 96. | |

**User's choice:** error_handler delegation (Recommended).

### Q3 — LiveView coverage strategy

| Option | Description | Selected |
|--------|-------------|----------|
| HTTP plug + on_mount pair | Add `Sigra.LiveView.RequireOrgMfa` on_mount mirroring RequireMembership ↔ OrganizationScope pairing. Catches mid-session policy flips on next live_redirect. | ✓ |
| HTTP plug only | Match success criterion #2 literal wording. Mid-session flips wait until full reload. Simpler. | |
| HTTP plug + PubSub disconnect | Plug + on_mount + per-org PubSub broadcast that disconnects sockets. Closes gap to ms. Phase 16 force-logout pattern but for arguably less-urgent signal. | |

**User's choice:** HTTP plug + on_mount pair (Recommended).

### Q4 — Relation to existing `Sigra.Plug.RequireMFAEnrolled`

| Option | Description | Selected |
|--------|-------------|----------|
| Coexist as siblings | RequireMFAEnrolled = "any user must MFA on this route"; RequireOrgMfa = "this route is in an org and that org enforces." Different responsibilities, no API breakage. | ✓ |
| Compose on top | RequireOrgMfa internally delegates to RequireMFAEnrolled when policy on. Couples them. | |
| Generalize into `Sigra.Plug.RequireMfa` with mode opt | Refactor + deprecate. Cleaner long-term API; v1.21 deprecation cycle cost. | |

**User's choice:** Coexist as siblings (Recommended).

### Q5 — Column shape: boolean vs enum

| Option | Description | Selected |
|--------|-------------|----------|
| Boolean, migrate later | `enforce_mfa_for_members :boolean`. Service-account exemption (Phase 93) handled at plug layer via `scope.actor_type`, not column. | ✓ |
| Enum atom from start | `:string` with `disabled` / `human_members` / `all_actors` values. Pre-decides Phase 93 design. | |
| Boolean + jsonb mfa_policy column | Boolean toggle + nullable jsonb for future structured policy. Premature flexibility. | |

**User's choice:** Boolean, migrate later (Recommended).

### Q6 — Plug option surface

| Option | Description | Selected |
|--------|-------------|----------|
| `:error_handler` + `:enrollment_path` only | Required `:error_handler`, optional `:enrollment_path` (default `/users/settings`). NimbleOptions schema. Minimal surface. | ✓ |
| Add `:grace_period` | 7-day grace before enforcement bites. Defeats success criterion #2 hard cutover. | |
| Add `:exempt_paths` allowlist | Path-string allowlist baked into plug. Couples plug to Phoenix routing surface. | |

**User's choice:** error_handler + enrollment_path only (Recommended).

---

## Allowlist Exemption

### Q1 — Service-account exemption posture

| Option | Description | Selected |
|--------|-------------|----------|
| YAGNI — Phase 93 adds the carve-out | Phase 91 plug enforces uniformly. Phase 93 modifies plug to short-circuit on `scope.actor_type == :service_account`. Documented interaction. | ✓ |
| Build hook now, no-op until Phase 93 | Defensive `Map.get(scope, :actor_type)` clause now. Tiny code cost; eliminates plug edit in Phase 93. | |
| Add `:actor_type` to scope in Phase 91 | Expand Phase 91 scope into the scope-struct surface Phase 92/93 own. | |

**User's choice:** YAGNI (Recommended).

### Q2 — Post-enrollment return flow

| Option | Description | Selected |
|--------|-------------|----------|
| `return_to` in session, fallback to org dashboard | Server-side store; relative-path validation; fallback to `/organizations/:org`. Mirrors phx.gen.auth `:user_return_to`. | ✓ |
| Always land on org dashboard | Simpler; loses deep-link UX. | |
| Always land on `/users/settings` | Most defensive; worst UX (manual re-navigation every trip). | |

**User's choice:** return_to in session with org dashboard fallback (Recommended).

---

## Admin Self-Lockout

### Q1 — Pre-flight check on enable

| Option | Description | Selected |
|--------|-------------|----------|
| Hard pre-flight refuse | `set_mfa_policy(scope, org, true)` returns `{:error, :admin_must_enroll_first}` if admin not MFA-enrolled. UI disables toggle. Matches GitHub/GitLab/Auth0/Okta. | ✓ |
| Warn-and-confirm modal | Toggle works; confirm dialog warns. Doesn't prevent foot-gun. | |
| Allow + recoverable | No guard; admin gets locked out next request, recovers via enroll. Simplest code. Jarring UX. | |

**User's choice:** Hard pre-flight refuse (Recommended).

### Q2 — Impact preview before enabling

| Option | Description | Selected |
|--------|-------------|----------|
| Inline count: "N of M members will be redirected" | One COUNT query in LV mount. Improves admin's decision quality. Auth0/Okta UX. | ✓ |
| Simple toggle, no preview | Just checkbox + save. Hides blast radius. | |
| Preview + send-warning-email opt | Preview + checkbox to email unenrolled members. Scope creep (new template + Oban worker). | |

**User's choice:** Inline count preview (Recommended).

### Q3 — Confirmation friction

| Option | Description | Selected |
|--------|-------------|----------|
| Light: simple confirm + impact preview | New "Security" section between General and Danger Zone. Confirm form on toggle save (both directions). No sudo. No typed-confirm. | ✓ |
| Medium: sudo on enable, confirm on disable | Asymmetric friction. Aligned with escalating-risk pattern. | |
| Heavy: sudo + typed-confirm both | Match Danger Zone. Unusual for B2B IdP UX. Overkill for a recoverable setting. | |

**User's choice:** Light friction (Recommended).

---

## Audit Shape + Idempotency

### Q1 — Audit row metadata payload

| Option | Description | Selected |
|--------|-------------|----------|
| `%{old_value, new_value}` | Matches codebase precedent (rename / slug_change / member_role_change). actor_id already populated by append_audit helper. | ✓ |
| Add `affected_member_count` snapshot | Records blast radius at policy-change time. Adds COUNT query to txn; stale by next request. | |
| Add `org_name` + `org_slug` snapshot | Forensic readability after rename/delete. Most queries already join on organization_id. | |

**User's choice:** `%{old_value, new_value}` (Recommended).

### Q2 — No-op toggle handling

| Option | Description | Selected |
|--------|-------------|----------|
| Skip Multi entirely, return `{:ok, org}` | `changeset.changes` empty → short-circuit, no audit row. Idiomatic Ecto. SOC 2 / ISO 27001 want state changes, not button clicks. | ✓ |
| Always write audit row | `metadata.no_op: true`. Pollutes audit table. | |
| Return `{:error, :no_change}` | Loud failure; breaks Ecto idiom. | |

**User's choice:** Skip Multi entirely (Recommended).

### Q3 — Action name canonicalization

| Option | Description | Selected |
|--------|-------------|----------|
| Canonicalize to `organization.mfa_policy_change` | Matches codebase: organization.{create,update,rename,delete,slug_change,member_role_change}. One-line ROADMAP edit. | ✓ |
| Keep ROADMAP literal: `organization.mfa_policy_changed` | Past tense; one inconsistency documented in CONTEXT footnote. No ROADMAP edit. | |

**User's choice:** Canonicalize (Recommended). Planner edits ROADMAP success criterion #1 wording during phase commit.

---

## Claude's Discretion

The following details were left to planner/researcher discretion (captured in CONTEXT.md):

- AuthErrorHandler reason atom name (`:mfa_required` vs `:org_mfa_required`)
- Stable error atom (`:mfa_policy_aborted` vs `:enforce_mfa_aborted` vs `:org_mfa_policy_aborted`)
- Session key for return_to (`:org_mfa_return_to` vs reusing `:user_return_to`)
- Exact NimbleOptions schema field names
- Exact LV "Security" section progressive-disclosure shape and copy wording
- Exact inline copy for impact preview and admin-must-enroll-first error
- Whether `Repo.transact/2` (Ecto 3.13) replaces `Repo.transaction/1` for the new path
- Test file naming: `require_org_mfa_test.exs`, `organizations_mfa_policy_audit_atomicity_test.exs`, generator-host integration test name

## Deferred Ideas

- Grace period for existing members (GitLab pattern; defeats success criterion #2 hard-cutover)
- Email notification to unenrolled members on policy change (Auth0 pattern; scope creep)
- PubSub-broadcast disconnect for already-mounted LV sockets (mid-session enforcement gap closer; on_mount catches next navigate, in-practice gap is seconds)
- Service-account exemption hook (Phase 93)
- Per-route `:org_scoped_mfa` opt-in pipeline (defeats success criterion #3)
- GitHub-style member ejection on enforcement (success criterion #2 wording precludes)
- Generalizing RequireMFAEnrolled + RequireOrgMfa into single `Sigra.Plug.RequireMfa` with `mode:` opt (deprecation cycle deferred)
