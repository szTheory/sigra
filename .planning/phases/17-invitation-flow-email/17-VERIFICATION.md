---
phase: 17-invitation-flow-email
verified: 2026-04-14T00:00:00Z
status: gaps_found
score: 9/10 must-haves verified
overrides_applied: 0
gaps:
  - truth: "INV-08: Owner/admin can revoke a pending invite before acceptance (with cross-tenant isolation)"
    status: failed
    reason: "Sigra.Organizations.Invitations.revoke/3 looks up the invitation by primary key alone and does not assert inv.organization_id == actor_scope.active_organization.id. An admin of Organization A can revoke a pending invite belonging to Organization B (cross-tenant IDOR). CR-01 in 17-REVIEW.md."
    artifacts:
      - path: "lib/sigra/organizations/invitations.ex"
        issue: "revoke/3 (lines 663-677) calls config.repo.get(schema, invitation_id) with no org scoping. The generated OrganizationMembersLive.handle_event(\"confirm_revoke\", %{\"id\" => id}, ...) passes client-supplied id straight through without revalidating against the current org's pending list."
    missing:
      - "Tighten revoke/3 query to `from i in schema, where: i.id == ^invitation_id and i.organization_id == ^actor_scope.active_organization.id` and collapse cross-tenant lookups onto :not_found (to avoid existence leak)"
      - "Regression test in test/sigra/organizations/invitations_test.exs: create invitation in Org B, call revoke/3 with admin scope for Org A, assert {:error, :not_found} and that the Org B row remains pending (accepted_at: nil, revoked_at: nil)"
deferred:
  - truth: "Install-layout tests pass on head (isolation_test.exs, templates_layout_test.exs, features/core_test.exs, golden_diff_test.exs)"
    addressed_in: "Follow-up fixup plan (see deferred-items.md)"
    evidence: "deferred-items.md documents 5 pre-existing install-test failures caused by Plan 17-04 fragment file (organization_invitation_email.ex) not being registered in Sigra.Install.Features.Core.files/1 coverage map, template count hard-coded at 47, and golden fixture not regenerated. Pre-dates Plan 17-06 execution and is tracked debt, not a Phase 17 goal-achievement gap."
---

# Phase 17: Invitation Flow + Email — Verification Report

**Phase Goal:** Email-locked HMAC-bound invite acceptance + `organization_invitation_email` template + rate-limited creation
**Verified:** 2026-04-14
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Requirements Coverage)

| # | Requirement | Truth | Status | Evidence |
|---|-------------|-------|--------|----------|
| 1 | INV-01 | Owner/admin can invite a user by email with optional role | VERIFIED | `Invitations.create/2` at `lib/sigra/organizations/invitations.ex:84`; admin UI at `organization_members_live.ex:457` (`phx-submit="invite_member"`); role select in invite modal |
| 2 | INV-02 | HMAC invite token via `Sigra.Token`; stored SHA-256-hashed, never plaintext | VERIFIED | `Sigra.Token.generate_invite_envelope/2` at `lib/sigra/token.ex:137`; `@invite_purpose "sigra-org-invite-token"` at line 20; `hashed_token` stored, `raw_token` asserted never written to changeset (Plan 17-03 decision note) |
| 3 | INV-03 | `organization_invitation_email.ex` with HTML+text, inviter+org+accept URL | VERIFIED | `priv/templates/sigra.install/core/organization_invitation_email.ex` exists (5.3KB); `emails.ex:718` defines `organization_invitation/4`; phishing-defensive subject format per Plan 17-04 must-haves |
| 4 | INV-04 | 7-day default TTL, NimbleOptions configurable, dev warning > 30 days | VERIFIED | `@org_config_schema` has `invitation_ttl` key (Plan 17-02 SUMMARY); `Sigra.Organizations.__warn_long_invitation_ttl__/1` helper ships; default `:timer.hours(24*7)` |
| 5 | INV-05 | Signup path atomically creates user + membership via Ecto.Multi | VERIFIED | `Invitations.accept_with_signup/3` at `invitations.ex:338` composes `register_user_multi \|> confirm_user \|> add_member_multi({:changes_key, :user}) \|> accept_invitation` via `repo.transact/2`; Pow #534 regression test per Plan 17-05 must-haves |
| 6 | INV-06 | Signed-in-match accepts; mismatch rejected (Jetstream #907 defense) | VERIFIED | `Invitations.accept/3` at `invitations.ex:293`; HMAC `verify_invite_envelope/3` re-asserts bound_email; `InvitationAcceptLive` :mismatch branch renders ZERO accept controls per Plan 17-07 structural invariant |
| 7 | INV-07 | Replay prevented — accepted invite returns `:already_accepted` | VERIFIED | State-transition guards in `accept/3` + `accept_with_signup/3`; `InvitationAcceptLive` has `:already_accepted` branch assign |
| 8 | INV-08 | Owner/admin can revoke pending invites with cross-tenant isolation | **FAILED** | `revoke/3` at `invitations.ex:663-677` is missing `inv.organization_id == actor_scope.active_organization.id` check. Cross-tenant IDOR — see CR-01 in 17-REVIEW.md. Role gate present (`role in @auth_roles`), but no org-scope assertion. |
| 9 | INV-09 | Rate-limit invitation creation (default 20/day/user, Hammer) | VERIFIED | Dual-key rate limit at `invitations.ex:119,134` with keys `sigra:org_invite_create:user:<id>` + `sigra:org_invite_create:org:<id>`; `invitation_rate_limit_per_user` + `invitation_rate_limit_per_org` in NimbleOptions schema |
| 10 | INV-10 | Pending list: email, role, invited-by, expires-in, revoke button | VERIFIED | `Invitations.list_pending/2` at `invitations.ex:713` with `:invited_by` preload; `organization_members_live.ex:405` `<section id="pending-invitations-section">` renders all 5 columns |

**Score:** 9/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/sigra/token.ex` | `generate_invite_envelope/2`, `verify_invite_envelope/3` | VERIFIED | Both functions present with `@invite_purpose` salt and string-keyed payload |
| `lib/sigra/organizations/invitations.ex` | create/revoke/accept/accept_with_signup/list_pending | VERIFIED (with gap) | 27KB file; all functions present. revoke/3 has org-scope gap (see gaps) |
| `lib/sigra/organizations.ex` | Extended `@org_config_schema` with 7 keys + `__warn_long_invitation_ttl__/1` | VERIFIED | 12 grep hits for config keys + warn helper |
| `lib/sigra/workers/cleanup_expired_invitations.ex` | Optional Oban worker (D-11) | VERIFIED | 4.7KB file exists |
| `priv/templates/sigra.install/core/organization_invitation_email.ex` | Generator template fragment | VERIFIED | 5.3KB file exists |
| `priv/templates/sigra.install/core/emails.ex` | `organization_invitation/4` delivery function | VERIFIED | Defined at line 718 |
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` | 7-branch LiveView with :mismatch structural invariant | VERIFIED | 15.8KB file; 40 grep hits on branch atoms |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` | Invite modal + pending list + revoke modal | VERIFIED | 26KB file; all 4 event handlers present |
| `priv/templates/sigra.install/organizations/router_injection.ex` | Unscoped `/invitations/:token/accept` route | VERIFIED | `live "/invitations/:token/accept", InvitationAcceptLive` at line 11 |
| `priv/templates/sigra.install/organizations/migration.exs` | `unique_index` on `hashed_token` (both adapter branches); no `now()` in partial index predicates | VERIFIED | Line 58 and 148 (Postgres + MySQL/SQLite); zero `where: "expires_at > now()"` matches |

### Key Link Verification

| From | To | Status | Details |
|---|---|---|---|
| `Invitations.create/2` | `Sigra.Token.generate_invite_envelope/2` | WIRED | Envelope signed with `config.secret_key_base` |
| `Invitations.create/2` | `config.rate_limiter.check_rate/3` | WIRED | Dual-key lookup with `sigra:org_invite_create:user:<id>` + `:org:<id>` |
| `Invitations.create/2` | `config.emails_module.organization_invitation/4` | WIRED | After-commit `apply/3` with nil-guard |
| `Invitations.accept/3` + `accept_with_signup/3` | `Sigra.Token.verify_invite_envelope/3` | WIRED | `verify_and_load/2` helper verifies HMAC, asserts `bound_email == db_row.email` |
| `Invitations.accept_with_signup/3` | `Sigra.Auth.register_user_multi/1` + `Sigra.Organizations.add_member_multi/5` | WIRED | Composed via `Ecto.Multi.append/2` with `{:changes_key, :user}` (actually `:confirm_user` per Plan 17-05 SUMMARY) |
| `Invitations.revoke/3` | `actor_scope.active_organization.id` | **NOT_WIRED** | Only role-checked; cross-tenant org id not asserted |
| Router `/invitations/:token/accept` | `InvitationAcceptLive` | WIRED | Outside `:require_authenticated_user` pipeline per router_injection.ex:11 |

### Requirements Coverage

All 10 INV requirements declared across plan frontmatters are accounted for:

- **INV-01** — Plans 17-03, 17-06 — SATISFIED
- **INV-02** — Plans 17-02, 17-03 — SATISFIED
- **INV-03** — Plan 17-04 — SATISFIED
- **INV-04** — Plans 17-02, 17-03 — SATISFIED
- **INV-05** — Plans 17-05, 17-07 — SATISFIED
- **INV-06** — Plans 17-05, 17-07 — SATISFIED
- **INV-07** — Plans 17-05, 17-07 — SATISFIED
- **INV-08** — Plans 17-03, 17-06 — **BLOCKED** (cross-tenant IDOR in `revoke/3`)
- **INV-09** — Plan 17-03 — SATISFIED
- **INV-10** — Plans 17-03, 17-06 — SATISFIED

Zero orphaned requirements.

### Anti-Patterns / Review Findings

CR-01 from 17-REVIEW.md is the sole critical finding and maps 1:1 to the INV-08 gap above. Five warnings (WR-01..WR-05) and four info items (IN-01..IN-04) from 17-REVIEW.md are non-blocking quality improvements and do not affect phase goal achievement:

| Finding | Severity | Impact on Phase Goal |
|---|---|---|
| CR-01 — revoke/3 missing org scope | Blocker | Blocks INV-08 — surfaced in gaps |
| WR-01 — 1,000-row ceiling in find_streamed_member | Warning | Non-blocking (pre-existing Phase 16 pattern) |
| WR-02 — accept_with_signup redirects to /users/log_in | Warning | UX regression, not goal failure; optional auto-sign-in |
| WR-03 — dead error branches in verify_and_load | Warning | Cosmetic |
| WR-04 — audit actor_id nil in signup path | Warning | Forensic regression, not a correctness bug |
| WR-05 — broad rescue in deliver_invitation_email_async | Warning | Observability, not correctness |
| IN-01..IN-04 | Info | Non-blocking |

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Install-layout test suite (isolation, templates_layout, features/core, golden_diff) passes on head | Follow-up fixup plan | `deferred-items.md` — 5 pre-existing failures from Plan 17-04 fragment not registered in `Sigra.Install.Features.Core.files/1` coverage map + hard-coded template count 47 + stale golden fixture. Documented as known debt; predates Plan 17-06. |

### Gaps Summary

Phase 17 successfully delivers the load-bearing "by construction" invitation security model: HMAC envelope binds email into the signed payload (closing Jetstream #907 / Keycloak CVE-2026-1529 by structural crypto), the `:mismatch` render branch in `InvitationAcceptLive` emits zero accept DOM (structural UI defense), `accept_with_signup/3` composes a single atomic `Ecto.Multi` (closing Pow #534), and dual-key Hammer rate limiting guards creation. 9 of 10 requirements are satisfied in full.

**One blocking gap remains (INV-08):** `Invitations.revoke/3` authorizes the actor by role only and looks up the invitation by primary key without asserting `inv.organization_id == actor_scope.active_organization.id`. An admin of Organization A who obtains an invitation id from Organization B can silently revoke B's pending invite, and the resulting audit row is tagged with the attacker's org — hard to trace in post-incident review. The fix is mechanical: tighten the `repo.get` to a `from i in schema, where: i.id == ^invitation_id and i.organization_id == ^org_id` query and add a cross-tenant regression test.

Five install-layout test failures are documented as pre-existing debt in `deferred-items.md` (Plan 17-04 fragment file not registered in the install coverage map) and do not block phase goal achievement — they are tracked for a follow-up fixup plan.

---

_Verified: 2026-04-14_
_Verifier: Claude (gsd-verifier)_
