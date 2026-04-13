# Phase 17: Invitation Flow + Email - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 17-invitation-flow-email
**Areas discussed:** Token envelope, Expired sweep, Accept route, Revoke UX, Rate limit, Partial-unique index, Re-invite role change, Multi orchestration, Email template layout
**Research method:** 5 parallel `gsd-advisor-researcher` subagents covering all 9 decision points. User asked for one-shot deep recommendations across all areas. User confirmed "yes" to all 9 recommendations in a single pass.

---

## Token envelope binding

| Option | Description | Selected |
|--------|-------------|----------|
| A. Sign raw_token only | Matches `sigra-confirm-token` precedent; email bound via DB check at accept time | |
| B. Sign `%{"t" => raw, "e" => downcase(email)}` with string keys | Email binding is cryptographic; tamper invalidates HMAC before DB lookup | ✓ |
| C. Sign `raw <> ":" <> sha256(email)` | Compact binary framing; custom split on verify | |

**User's choice:** B — "by construction, not convention" matches the phase's stated threat model. String keys avoid atom-table growth on decode.
**Refs cited:** Bytepack (Dashbit SaaS reference app) signs envelope term for invite/transfer flows; phx.gen.auth uses Option A for confirm tokens where holder == principal, but invitations are the exception; Pow's convention-based approach has surfaced hijack-adjacent bugs historically.

---

## Expired-invite lifecycle sweep

| Option | Description | Selected |
|--------|-------------|----------|
| A. On-read filter only | Zero infra; rows accumulate indefinitely | |
| B. Oban cron only | Hygienic but correctness depends on cron running | |
| C. Both — filter (correctness) + optional Oban worker (hygiene) | Non-negotiable correctness layer + opt-in PII sweep via Phase 15 `Sigra.Workers` behaviour | ✓ |

**User's choice:** C — correctness cannot depend on a cron the host might not run; Oban worker is hygiene/PII and slots cleanly into existing Phase 15 behaviour with no-op fallback.
**Refs cited:** phx.gen.auth UserToken uses on-read only; Oban itself ships `Oban.Plugins.Pruner` as idiomatic opt-in cleanup; Pow uses on-read, no sweeper; Bytepack uses Oban cron.

---

## Accept route topology

| Option | Description | Selected |
|--------|-------------|----------|
| A. Single LV at `/invitations/:token/accept` with 3 render branches (signup / accept / mismatch) | Mount/3 branches on `(current_user, invitation.email)`; mismatch renders zero accept form | ✓ |
| B. Landing + /signup + /accept (3 routes) | Clean URLs per state; token passes through 3 routes (leak surface) | |
| C. /accept + /signup + /mismatch (3 routes) | Mismatch as bookmarkable URL; stale after sign-out | |

**User's choice:** A — coheres with Phase 16 D-07 / D-23, matches phx.gen.auth confirmation idiom, matches GitHub/Slack/Linear/Notion/Vercel. Mismatch-as-render-branch with zero accept form in the DOM makes the Jetstream #907 hijack class structurally impossible, not just server-guarded.
**Refs cited:** GitHub `/orgs/:org/invitation`, Slack `/signup/xxx`, Linear `/join/:token`, Notion `/invite/:token`, phx.gen.auth `/users/confirm/:token` — all single-route-with-branches; AshAuthentication Phoenix magic-link accept is also single-route.

---

## Revoke UX

| Option | Description | Selected |
|--------|-------------|----------|
| A. Simple `<.modal>` confirm | Matches Phase 16 D-19 member-removal; stock Phoenix 1.8 components | ✓ |
| B. Typed-email confirm | Violates Phase 16 D-29 (typed-confirm reserved for destructive org-level actions) | |
| C. Toast-undo (5s undo affordance) | Requires `live_toast` dep or custom flash slot; inconsistent with Phase 16 rhythm | |

**User's choice:** A — revoke is strictly less destructive than member removal, which uses simple confirm. Stronger affordance would be incoherent; more complex affordance earns no payoff. Copy: "Revoke invitation for {email}? They will no longer be able to join {org.name} with this link."
**Refs cited:** GitHub, Slack, Linear, Notion, Vercel all use simple one-click revoke; Gmail's undo-send is the canonical toast-undo but protects irrecoverable actions; invite revoke is trivially recoverable via re-invite so toast-undo doesn't earn its complexity.

---

## Rate-limit shape + budget

| Option | Description | Selected |
|--------|-------------|----------|
| A. `{:org_invite_create, user_id}` @ 20/day | INV-09 literal; multi-org admins share budget | |
| B. `{:org_invite_create, user_id, org_id}` @ 20/day | Per-(user,org) isolation; compromised admin farms 20×N | |
| C. `{:org_invite_create, org_id}` @ 50/day | Caps org-wide velocity; violates INV-09 "per user" wording | |
| D. Dual key: per-user 20/day + per-org 50/day | Defense-in-depth; honors INV-09 + accommodates day-1 bursts + caps compromise blast radius | ✓ |
| E. `{:org_invite_create, email_hash}` @ 3/day | Orthogonal to volume abuse; addresses harassment | |

**User's choice:** D — 2× Hammer calls on ETS backend is microseconds; honors INV-09 literal + matches GitHub/Slack layered model + accommodates 4-admin founding team inviting 50 teammates on day 1. Both keys configurable via NimbleOptions, either can be `:infinity` to disable.
**Refs cited:** GitHub uses layered per-user + org-level secondary rate limits; Slack ~400/day workspace-wide on free; Devise-invitable ships no rate limiting (punts to Rack::Attack).

---

## Pending-invite partial-unique predicate

| Option | Description | Selected |
|--------|-------------|----------|
| A. PG partial `WHERE accepted_at IS NULL AND revoked_at IS NULL` (IS-NULL only, IMMUTABLE-safe) | Declarative invariant on PG+SQLite; MySQL fallback via `Repo.transact` + advisory lock | ✓ |
| B. Generated `status` column + partial on `status='pending'` | Extra column; generated-column syntax diverges across adapters | |
| C. App-only `SELECT FOR UPDATE` in Multi | Zero DDL; loses DB safety net | |
| D. Always-unique on `(org_id, email)` (no partial) | Forces hard-delete of accepted/revoked rows; destroys audit trail | |

**User's choice:** A — IS-NULL predicate is built-in operator, not a function call, so the Postgres IMMUTABLE rule (which bans `now()`, the exact Phase 16 slug-alias pitfall captured in STATE.md) does not apply. Belt-and-suspenders changeset guard runs on all adapters.
**Refs cited:** PG docs 11.8 explicitly bless IS NULL predicates for "allow only one null"; phx.gen.auth does NOT enforce uniqueness on pending tokens (invitation semantics are stricter, admin-facing invariant).

---

## Re-invite with different role

| Option | Description | Selected |
|--------|-------------|----------|
| A. Revoke old + insert new | Clean "exactly one pending row" invariant; full audit trail; old link dies | ✓ |
| B. Mutate existing row in place | Single email; idempotent link; loses audit granularity | |
| C. Return `{:error, :already_pending}` | Forces explicit admin intent; DX friction | |

**User's choice:** A — only option that preserves the partial-unique invariant AND a clean audit trail without a separate `role_changes` table. Two emails is arguably correct: the invitee should see role changed. Future-proof if a later phase signs role into the HMAC payload.
**Refs cited:** GitHub mutates in place; Slack/Linear/Notion revoke-and-resend; phx.gen.auth confirmation tokens invalidate all on confirm (precedent for "new token supersedes old").

---

## Multi orchestration boundary (signup-accept atomicity)

| Option | Description | Selected |
|--------|-------------|----------|
| A. `Sigra.Organizations.Invitations.accept_with_signup/3` owns Multi; composes via `Multi.append` | Security-critical atomicity in lib (Phase 13 pattern); closes Pow #534 orphan-row class | ✓ |
| B. LV builds Multi inline | Violates hybrid lib+generator principle; atomicity leaks to generated code | |
| C. Two lib calls wrapped in `Repo.transact/2` at LV | LV owns rollback semantics; error mapping ugly | |
| D. New top-level `Sigra.Invitations` context | Inverts dep graph (Invitations → Auth + Orgs); invitation is not an aggregate root | |

**User's choice:** A — matches Phase 13 precedent (lib owns Multis, generated code is thin wrapper), unit-testable against `Sigra.Testing` without LV harness, no circular context dep. Invitations stays under `Sigra.Organizations` because invitations are org-scoped.
**Refs cited:** phx.gen.auth keeps confirm+delete-tokens Multi inside Accounts; Ash Authentication uses single-resource atomicity; Pow issue #534 (orphan-row bug) was precisely caused by splitting invitation creation across controller callbacks with no transaction; Ecto docs endorse `Multi.append/2` for composing Multis from separate modules.

---

## Email template module layout

| Option | Description | Selected |
|--------|-------------|----------|
| A. Generated `{app}_web/emails/organization_invitation_email.ex` (v1.0 pattern) | Matches `api_token_created_email.ex` precedent; host owns copy | ✓ |
| B. Library default + behaviour callback override | Two places to look; library recompile needed for copy tweaks | |
| C. Generated HEEx `.html.heex` template file | Extra view module + template dir; inconsistent with v1.0 inline function-component style | |

**User's choice:** A — matches existing Sigra v1.0 convention exactly (principle of least surprise), host owns copy/branding where devs expect it, library stays template-free. Library calls `apply(config.emails_module, :organization_invitation, [invitation, org, inviter, accept_url])`.
**Refs cited:** phx.gen.auth 1.8 generates `user_notifier.ex` with inline `deliver/3` helpers; Swoosh idiom is per-module email builders for transactional mail; Ash Authentication uses sender modules the host implements.

---

## Claude's Discretion

Items where the planner has latitude within the locked decisions:

- Email HTML/text copy specifics, subject line, inline CSS (follow v1.0 conventions)
- Exact placement of email send inside Multi vs after-commit hook (rec: after commit)
- Invite form UI polish — role-select default, placeholder text, validation feedback
- Whether to fold the Phase 16 slug-alias migration fix into Phase 17 as a sidecar
- Audit event metadata shape within Phase 15 conventions
- Whether to include invitee-side "decline" action (lower priority)
- `:require_active_organization` router pipeline macro — revisit during planning

## Deferred Ideas

See CONTEXT.md `<deferred>` section for full list. Key items:

- Bulk invite, resend-same-token, shareable link, SSO/SCIM, analytics, per-email-target rate limit
- `:require_active_organization` router macro (possibly Phase 17 or 18)
- Invitee-side decline flow (optional, planner's call)
