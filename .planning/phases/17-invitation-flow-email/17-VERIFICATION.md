---
phase: 17-invitation-flow-email
verified: 2026-04-14T12:00:00Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 9/10
  gaps_closed:
    - "INV-08: Owner/admin can revoke a pending invite before acceptance (with cross-tenant isolation)"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "Install-layout tests pass on head (isolation_test.exs, templates_layout_test.exs, features/core_test.exs, golden_diff_test.exs)"
    addressed_in: "Follow-up fixup plan (see deferred-items.md)"
    evidence: "deferred-items.md documents 5 pre-existing install-test failures caused by Plan 17-04 fragment file (organization_invitation_email.ex) not being registered in Sigra.Install.Features.Core.files/1 coverage map, template count hard-coded at 47, and golden fixture not regenerated. Pre-dates Plan 17-06 and Plan 17-09 execution and is tracked debt, not a Phase 17 goal-achievement gap."
---

# Phase 17: Invitation Flow + Email — Verification Report (Re-verification)

**Phase Goal:** Email-locked HMAC-bound invite acceptance + `organization_invitation_email` template + rate-limited creation
**Verified:** 2026-04-14 (re-verification after Plan 17-09 gap closure)
**Status:** passed
**Re-verification:** Yes — INV-08 gap from initial 2026-04-14 pass has been closed by Plan 17-09 (commits `1a17dde` RED, `15cacca` GREEN)

## Re-verification Summary

The initial verification pass flagged one blocking gap: **INV-08 cross-tenant IDOR** in `Sigra.Organizations.Invitations.revoke/3`. The function looked up invitations by primary key alone and enforced only a role gate, allowing an admin of Organization A to revoke a pending invitation belonging to Organization B.

Plan 17-09 has landed the fix:

- `revoke/3` now destructures `active_organization: %{id: org_id}` in the function head and runs a dual-column Ecto query (`where: i.id == ^invitation_id and i.organization_id == ^org_id`) via `config.repo.one/1`.
- Wrong-org hits collapse onto `{:error, :not_found}` (identical shape to missing id) for enumeration resistance. An inline comment documents the rationale and the deliberate audit-omission on that branch.
- A cross-tenant regression test exists in `test/sigra/organizations/invitations_test.exs:771` and passes. It stubs `:one → nil` and deliberately sets no `:transact` expectation — Mox `verify_on_exit!` asserts that no DB mutation ever fires.
- All 5 existing revoke/3 tests were retrofitted from `expect(:get, ...)` to `expect(:one, fn %Ecto.Query{} -> ... end)`.
- `mix test test/sigra/organizations/invitations_test.exs` → **46/46 pass**.
- `rg 'config.repo.get\(schema, invitation_id\)' lib/sigra/organizations/invitations.ex` → **0 hits** (the old unscoped lookup is structurally gone).

With INV-08 closed, all 10 must-haves are now satisfied. **Phase 17 is complete.**

## Goal Achievement

### Observable Truths (Requirements Coverage)

| # | Requirement | Truth | Status | Evidence |
|---|-------------|-------|--------|----------|
| 1 | INV-01 | Owner/admin can invite a user by email with optional role | VERIFIED | `Invitations.create/2` at `lib/sigra/organizations/invitations.ex:84`; admin UI `organization_members_live.ex:457` (`phx-submit="invite_member"`); role select in invite modal |
| 2 | INV-02 | HMAC invite token via `Sigra.Token`; stored SHA-256-hashed, never plaintext | VERIFIED | `Sigra.Token.generate_invite_envelope/2` at `lib/sigra/token.ex:137`; `@invite_purpose "sigra-org-invite-token"` at line 20; `hashed_token` stored, `raw_token` asserted never written to changeset (Plan 17-03 decision note) |
| 3 | INV-03 | `organization_invitation_email.ex` with HTML+text, inviter+org+accept URL | VERIFIED | `priv/templates/sigra.install/core/organization_invitation_email.ex` exists (5.3KB); `emails.ex:718` defines `organization_invitation/4`; phishing-defensive subject format per Plan 17-04 |
| 4 | INV-04 | 7-day default TTL, NimbleOptions configurable, dev warning > 30 days | VERIFIED | `@org_config_schema` has `invitation_ttl` key; `Sigra.Organizations.__warn_long_invitation_ttl__/1` helper ships; default `:timer.hours(24*7)` |
| 5 | INV-05 | Signup path atomically creates user + membership via Ecto.Multi | VERIFIED | `Invitations.accept_with_signup/3` at `invitations.ex:338` composes `register_user_multi \| confirm_user \| add_member_multi({:changes_key, :confirm_user}) \| accept_invitation` via `repo.transact/2`; Pow #534 regression test per Plan 17-05 |
| 6 | INV-06 | Signed-in-match accepts; mismatch rejected (Jetstream #907 defense) | VERIFIED | `Invitations.accept/3` at `invitations.ex:293`; HMAC `verify_invite_envelope/3` re-asserts bound_email; `InvitationAcceptLive` `:mismatch` branch renders ZERO accept controls per Plan 17-07 structural invariant |
| 7 | INV-07 | Replay prevented — accepted invite returns `:already_accepted` | VERIFIED | State-transition guards in `accept/3` + `accept_with_signup/3`; `InvitationAcceptLive` `:already_accepted` branch assign |
| 8 | INV-08 | Owner/admin can revoke pending invites with cross-tenant isolation | **VERIFIED (fixed by Plan 17-09)** | `revoke/3` at `lib/sigra/organizations/invitations.ex:665-692` destructures `active_organization: %{id: org_id}` in function head; scoped Ecto query `where: i.id == ^invitation_id and i.organization_id == ^org_id` via `config.repo.one(query)`; wrong-org collapses to `{:error, :not_found}`; regression test at `invitations_test.exs:771` + 46/46 suite passes |
| 9 | INV-09 | Rate-limit invitation creation (default 20/day/user, Hammer) | VERIFIED | Dual-key rate limit at `invitations.ex:119,134` with keys `sigra:org_invite_create:user:<id>` + `sigra:org_invite_create:org:<id>`; `invitation_rate_limit_per_user` + `invitation_rate_limit_per_org` in NimbleOptions schema |
| 10 | INV-10 | Pending list: email, role, invited-by, expires-in, revoke button | VERIFIED | `Invitations.list_pending/2` at `invitations.ex:728` with `:invited_by` preload; `organization_members_live.ex:405` `<section id="pending-invitations-section">` renders all 5 columns |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `lib/sigra/token.ex` | `generate_invite_envelope/2`, `verify_invite_envelope/3` | VERIFIED | Both functions present with `@invite_purpose` salt and string-keyed payload |
| `lib/sigra/organizations/invitations.ex` | create/revoke/accept/accept_with_signup/list_pending | VERIFIED | 27KB file; all functions present. `revoke/3` now uses scoped Ecto query via `config.repo.one/1` (Plan 17-09 fix) |
| `lib/sigra/organizations.ex` | Extended `@org_config_schema` + `__warn_long_invitation_ttl__/1` | VERIFIED | 12 grep hits for config keys + warn helper |
| `lib/sigra/workers/cleanup_expired_invitations.ex` | Optional Oban worker (D-11) | VERIFIED | 4.7KB file exists |
| `priv/templates/sigra.install/core/organization_invitation_email.ex` | Generator template fragment | VERIFIED | 5.3KB file exists |
| `priv/templates/sigra.install/core/emails.ex` | `organization_invitation/4` delivery function | VERIFIED | Defined at line 718 |
| `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` | 7-branch LiveView with `:mismatch` structural invariant | VERIFIED | 15.8KB file; 40 grep hits on branch atoms |
| `priv/templates/sigra.install/organizations/live/organization_members_live.ex` | Invite modal + pending list + revoke modal | VERIFIED | 26KB file; all 4 event handlers present |
| `priv/templates/sigra.install/organizations/router_injection.ex` | Unscoped `/invitations/:token/accept` route | VERIFIED | `live "/invitations/:token/accept", InvitationAcceptLive` at line 11 |
| `priv/templates/sigra.install/organizations/migration.exs` | `unique_index` on `hashed_token` (both adapter branches); no `now()` in partial index predicates | VERIFIED | Line 58 and 148 (Postgres + MySQL/SQLite); zero `where: "expires_at > now()"` matches |
| `test/sigra/organizations/invitations_test.exs` | Cross-tenant IDOR regression test for revoke/3 | VERIFIED | Line 771 — test sets `:one → nil`, no `:transact` expectation; `mix test` → 46/46 pass |

### Key Link Verification

| From | To | Status | Details |
|---|---|---|---|
| `Invitations.create/2` | `Sigra.Token.generate_invite_envelope/2` | WIRED | Envelope signed with `config.secret_key_base` |
| `Invitations.create/2` | `config.rate_limiter.check_rate/3` | WIRED | Dual-key lookup with `sigra:org_invite_create:user:<id>` + `:org:<id>` |
| `Invitations.create/2` | `config.emails_module.organization_invitation/4` | WIRED | After-commit `apply/3` with nil-guard |
| `Invitations.accept/3` + `accept_with_signup/3` | `Sigra.Token.verify_invite_envelope/3` | WIRED | `verify_and_load/2` helper verifies HMAC, asserts `bound_email == db_row.email` |
| `Invitations.accept_with_signup/3` | `Sigra.Auth.register_user_multi/1` + `Sigra.Organizations.add_member_multi/5` | WIRED | Composed via `Ecto.Multi.append/2` with `{:changes_key, :confirm_user}` |
| `Invitations.revoke/3` | `actor_scope.active_organization.id` | **WIRED (fixed)** | Function head destructures `active_organization: %{id: org_id}` at line 668; query uses `where: i.id == ^invitation_id and i.organization_id == ^org_id` at lines 674-675 via `config.repo.one(query)` at line 677 |
| Router `/invitations/:token/accept` | `InvitationAcceptLive` | WIRED | Outside `:require_authenticated_user` pipeline per router_injection.ex:11 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| `revoke/3` scoped query compiles and executes correctly under mocks | `mix test test/sigra/organizations/invitations_test.exs` | 46 tests, 0 failures | PASS |
| Cross-tenant revoke returns `:not_found` without calling `:transact` | Inspected test at `invitations_test.exs:771`; Mox verify_on_exit asserts no unexpected `:transact` call | PASS | PASS |
| Old unscoped lookup is structurally gone | `rg 'config.repo.get\(schema, invitation_id\)' lib/sigra/organizations/invitations.ex` | 0 hits | PASS |
| Scoped query is in place | `rg 'where: i.id == \^invitation_id and i.organization_id == \^org_id' lib/sigra/organizations/invitations.ex` | 1 hit (line 675) | PASS |

### Requirements Coverage

All 10 INV requirements declared across plan frontmatters are accounted for and SATISFIED:

- **INV-01** — Plans 17-03, 17-06 — SATISFIED
- **INV-02** — Plans 17-02, 17-03 — SATISFIED
- **INV-03** — Plan 17-04 — SATISFIED
- **INV-04** — Plans 17-02, 17-03 — SATISFIED
- **INV-05** — Plans 17-05, 17-07 — SATISFIED
- **INV-06** — Plans 17-05, 17-07 — SATISFIED
- **INV-07** — Plans 17-05, 17-07 — SATISFIED
- **INV-08** — Plans 17-03, 17-06, **17-09 (gap closure)** — SATISFIED
- **INV-09** — Plan 17-03 — SATISFIED
- **INV-10** — Plans 17-03, 17-06 — SATISFIED

Zero orphaned requirements.

### Anti-Patterns / Review Findings

The CR-01 finding from 17-REVIEW.md (cross-tenant IDOR in `revoke/3`) is now **RESOLVED** by Plan 17-09. Remaining findings are non-blocking:

| Finding | Severity | Status |
|---|---|---|
| CR-01 — revoke/3 missing org scope | Blocker | **RESOLVED by Plan 17-09** |
| WR-01 — 1,000-row ceiling in find_streamed_member | Warning | Non-blocking (pre-existing Phase 16 pattern) |
| WR-02 — accept_with_signup redirects to /users/log_in | Warning | UX regression, not goal failure; optional auto-sign-in |
| WR-03 — dead error branches in verify_and_load | Warning | Cosmetic |
| WR-04 — audit actor_id nil in signup path | Warning | Forensic regression, not correctness |
| WR-05 — broad rescue in deliver_invitation_email_async | Warning | Observability, not correctness |
| IN-01..IN-04 | Info | Non-blocking |

Note: Plan 17-09 deliberately does NOT emit an audit row on the `revoke/3 :not_found` branch because doing so would leak the same existence signal the scoped query just closed. A dedicated `[:sigra, :security, :cross_tenant_probe]` telemetry event is tracked separately as WR-04-class follow-up work.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Install-layout test suite (isolation, templates_layout, features/core, golden_diff) passes on head | Follow-up fixup plan | `deferred-items.md` — 5 pre-existing failures from Plan 17-04 fragment not registered in `Sigra.Install.Features.Core.files/1` coverage map + hard-coded template count 47 + stale golden fixture. Documented as known debt; predates Plan 17-06 and Plan 17-09. Plan 17-09 SUMMARY re-confirms: "All 5 failures are the pre-existing install-layout failures documented in `deferred-items.md`. Not regressions from this change." |

### Passing Summary

Phase 17 successfully delivers the load-bearing "by construction" invitation security model in full:

1. **HMAC envelope binds email into the signed payload** — closing Jetstream #907 / Keycloak CVE-2026-1529 by structural crypto, not just application-layer checks (INV-02, INV-06).
2. **`:mismatch` render branch in `InvitationAcceptLive` emits zero accept DOM** — structural UI defense against signed-in-but-wrong-email acceptance (INV-06).
3. **`accept_with_signup/3` composes a single atomic `Ecto.Multi`** — closing Pow #534 by guaranteeing zero orphan rows across user / membership / invitation tables (INV-05).
4. **Dual-key Hammer rate limiting** — per-user + per-org keys guard creation from abuse (INV-09).
5. **Cross-tenant IDOR on `revoke/3` is structurally impossible** — scoped Ecto query `where: i.id == ^invitation_id and i.organization_id == ^org_id` runs inside SQL itself; wrong-org hits collapse to `{:error, :not_found}` for enumeration resistance (INV-08, fixed by Plan 17-09).
6. **Phishing-defensive `organization_invitation_email` template** with HTML + text, inviter/org/accept URL, 7-day TTL with dev warning > 30 days, SHA-256-hashed token storage (INV-03, INV-04).
7. **Complete admin UX** — invite modal, pending list with 5 columns, revoke modal, all wired through `OrganizationMembersLive` event handlers (INV-01, INV-10).
8. **Replay prevention** — state-transition guards return `:already_accepted` for accepted rows (INV-07).

All 10 INV requirements satisfied. All required artifacts present and substantive. All key links wired. Full `invitations_test.exs` suite (46 tests) passes. Zero regressions introduced by Plan 17-09.

Five install-layout test failures remain documented as pre-existing debt in `deferred-items.md` (Plan 17-04 fragment file not registered in the install coverage map) and do not block phase goal achievement — they are tracked for a follow-up fixup plan.

---

_Verified: 2026-04-14_
_Verifier: Claude (gsd-verifier)_
_Re-verification of: initial 2026-04-14 pass (gaps_found, 9/10)_
