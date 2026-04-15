# Phase 17: Invitation Flow + Email - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Owner or admin of an organization invites a user by email. System generates a
replay-safe, email-bound HMAC invitation token, sends an `organization_invitation_email`,
and accepts the invite through a single unscoped LiveView that handles three branches:
anonymous signup, signed-in match, and signed-in mismatch. Accept is atomic with user
confirmation (for signup branch) or membership creation (for signed-in branch), enforced
in library-owned `Ecto.Multi`s. Invitation creation is rate-limited. Pending invitations
are listed on `OrganizationMembersLive` and `OrganizationsLive.Index` via library
queries that replace the Phase 16 stubs — additively, with zero Phase 16 file moves.

Closes the Jetstream #907 / Keycloak CVE-2026-1529 "accept-as-any-logged-in-user"
invite-hijack class *by construction* (HMAC-bound email + render-branch mismatch with
zero accept form in the DOM), not by convention.

**IN scope:** Token generation/verify (`sigra-org-invite-token`), hashed storage,
email template + generated delivery hook, single accept LV with 3 render branches,
revoke action with simple confirm modal, dual-key Hammer rate limiting,
`list_pending_invitations/1` + `list_pending_invitations_for_email/1` library queries,
Phase 16 stub fill-in, optional `Sigra.Workers.CleanupExpiredInvitations` worker.

**OUT of scope (defer to later phase):** Bulk invite, resend-same-token, shareable
"invite link" (token-as-link), SSO/SCIM user provisioning, invitation analytics,
per-email target rate limit.

</domain>

<decisions>
## Implementation Decisions

### Token + Crypto

- **D-01: Sign the invitation token as a term, email cryptographically bound into the payload.**
  Generate `{raw, hashed} = Sigra.Token.generate_hashed_token()`, then
  `signed = Plug.Crypto.sign(secret_key_base, "sigra-org-invite-token", %{"t" => raw, "e" => String.downcase(invitation.email)})`
  and `encoded = Base.url_encode64(signed, padding: false)`. Store `hashed` in
  `organization_invitations.hashed_token`. **String keys** on the signed map (not atoms)
  to avoid atom-table growth on decode. On verify, destructure `%{"t" => raw, "e" => email}`
  and reject if the decoded email does not equal the DB row's `email` (defense-in-depth).
  Token purpose string: `"sigra-org-invite-token"`.

  **Rationale:** Invitations are the one flow where the holder of the link is not yet
  the authenticated principal, so the `sigra-confirm-token` precedent (which signs raw
  token only and binds identity by convention at accept time) is the wrong anchor.
  Signing email into the HMAC payload means `Plug.Crypto.verify` rejects any tampered
  email *before a DB row is ever touched*. This is "by construction, not convention" —
  the explicit goal of Phase 17.

  A one-line comment in `Sigra.Token` documents why invitations diverge from
  `sigra-confirm-token` so future contributors understand the exception.

- **D-02: Token purpose is `"sigra-org-invite-token"`.** Registered alongside the
  existing purpose strings (`sigra-confirm-token`, `sigra-reset-token`, etc.) in
  whatever Sigra canonical location lists them.

### Schema + DB Invariants

- **D-03: Pending-invite uniqueness uses an `IS NULL`-only partial index.**
  Migration template emits (for PG + SQLite):

  ```elixir
  create unique_index(:organization_invitations,
           [:organization_id, :email],
           where: "accepted_at IS NULL AND revoked_at IS NULL",
           name: :organization_invitations_pending_index)
  ```

  The predicate uses only `IS NULL` (an IMMUTABLE-safe operator). **It MUST NOT
  include `expires_at > now()` or any function call** — Postgres rejects non-IMMUTABLE
  functions in index predicates. This avoids repeating the Phase 16 slug-alias migration
  bug captured in STATE.md.

  **MySQL fallback:** No partial index (MySQL 8 lacks them). Instead, enforce uniqueness
  via `Repo.transact/2` + advisory row lock inside `Sigra.Organizations.Invitations.create/2`.
  A changeset-level guard (`check_pending_uniqueness`) runs on **all** adapters as
  belt-and-suspenders. The MySQL gap is a defense-in-depth gap, not a correctness gap —
  the library Multi path is authoritative.

  Per-adapter conditional migration emission is already the Sigra convention (Phase 11).

- **D-04: Expired rows are NOT deleted on read.** List queries filter with
  `accepted_at: nil AND revoked_at: nil AND expires_at > now()`. Expired rows remain
  in-table — hard-deletion happens (optionally) in the Oban worker. See D-11.

### Re-invite Semantics

- **D-05: Re-inviting an already-pending email = revoke old + insert new.**
  When an admin invites `user@example.com` as `:member` and then invites the same
  email as `:admin` before acceptance, Sigra stamps `revoked_at` / `revoked_by_id`
  on the first row and inserts a brand-new row with the new role + new token +
  new `expires_at`. The invitee receives two emails; the old URL 404s; the audit
  timeline is clean (`invited @ T1 as member → revoked @ T2 → re-invited @ T2 as admin`).

  **Rationale:** Only option that preserves the D-03 partial-unique invariant *and*
  a clean audit trail without a separate `role_changes` table. Also future-proof —
  if a later phase decides to sign `role` into the token envelope, old tokens are
  already invalid. Two emails is arguably correct: the invitee should see that their
  role changed.

### Accept Flow

- **D-06: Single LiveView at `/invitations/:token/accept`, unscoped, with three render branches.**
  The LV is NOT inside the `/organizations/:org` scope block (Phase 16 D-23). In `mount/3`:

  1. Decode base64 → `Plug.Crypto.verify` with purpose `"sigra-org-invite-token"`
     and `max_age: invitation_ttl_seconds`. Extract `%{"t" => raw, "e" => bound_email}`.
  2. `hashed = Sigra.Token.hash_token(raw)` → DB lookup by `hashed_token`.
  3. Guard: `bound_email == String.downcase(invitation.email)` (cryptographic assert).
  4. Guard: `invitation.accepted_at` nil and `invitation.revoked_at` nil and
     `invitation.expires_at > now()`, else assign appropriate error branch.
  5. Assign `:branch` by pattern-matching `(current_user, invitation.email)`:

     - `(nil, _)` → **`:signup`** branch: inline signup form with `email` field pre-filled
       from `invitation.email` and `disabled` (locked). Also `readonly` server-side —
       changeset rejects any attempt to post a different email.
     - `(%{email: e}, e)` where citext-insensitive match → **`:accept`** branch: one-click
       "Join {org.name} as {role}" button. Shows inviter name + expiry.
     - `(%{email: _other}, _)` → **`:mismatch`** branch: explicit page
       "This invitation is for **{invitation.email}**. You are signed in as
       **{current_user.email}**." with a "Sign out and try again" link and **zero accept
       form / zero accept button** in the rendered DOM. Hijack class is structurally
       impossible, not just server-guarded.

  `render/1` dispatches via a `case @branch do` to three function components
  (`:signup_branch`, `:accept_branch`, `:mismatch_branch`). One LV, one mount, one token
  verify, one token lookup.

  **Rationale:** Matches GitHub, Slack, Linear, Notion, Vercel — every gold-standard
  SaaS uses a single route with render branches. Matches `phx.gen.auth` 1.8's
  `/users/confirm/:token` idiom. Coheres with Phase 16 D-07 ("one LV, branches") and
  Phase 16 D-23 ("accept LV lives at `/invitations/:token/accept`, unscoped").
  Minimizes token-leak surface (no redirects between sub-routes carrying the token
  in referrer). The mismatch branch rendering zero accept UI is the structural
  Jetstream #907 defense.

- **D-07: Signup-branch atomicity = library-owned `Ecto.Multi` composed from existing multis.**
  New public function `Sigra.Organizations.Invitations.accept_with_signup/3` in
  `lib/sigra/organizations/invitations.ex` owns the full Multi:

  ```elixir
  Ecto.Multi.new()
  |> Ecto.Multi.append(Sigra.Auth.register_confirmed_user_multi(params, opts))
  |> Ecto.Multi.append(Sigra.Organizations.add_member_multi(org, user_ref, role))
  |> Ecto.Multi.update(:accept_invitation, fn %{user: u} ->
       Invitation.accept_changeset(invitation, accepted_by: u)
     end)
  |> Ecto.Multi.run(:audit, &emit_audit_events/2)
  |> repo.transact()
  ```

  The generated LV is a ~5-line `handle_event("accept_with_signup", params, socket)`
  that pattern-matches `{:ok, %{user: u, membership: m, accept_invitation: inv}}` and
  assigns the session scope. Signed-in-match branch uses
  `Sigra.Organizations.Invitations.accept/3` (no user creation, just membership + stamp).

  Composes via `Ecto.Multi.append/2`, not `merge/2` — no name collisions because each
  sub-Multi uses namespaced step names (`register_user`, `confirm_user`, `add_member`,
  `accept_invitation`).

  **Rationale:** Matches Phase 13 pattern (library owns Multis, generated code is
  thin wrapper). Closes the Pow orphan-row bug class (Pow issue #534) by construction.
  Unit-testable against `Sigra.Testing` without spinning up a LV harness. No circular
  context dep — Invitations stays under `Sigra.Organizations` because invitations are
  org-scoped (FK to `organization_id`, role enum from the Organizations domain).
  A new top-level `Sigra.Invitations` peer context was rejected: inverts the dep graph
  and splits the schema's natural home.

- **D-08: Revoke = simple confirm modal, not typed confirm, not toast-undo.**
  Stock Phoenix 1.8 `<.modal>` with copy:

  > *Revoke invitation for **{email}**? They will no longer be able to join
  > **{org.name}** with this link.*

  Confirm button: `"Revoke invitation"` (destructive-red variant). No typed-email
  confirmation, no 5-second toast-undo.

  **Rationale:** Matches Phase 16 D-19 (simple confirm for member removal). Revoke
  is *strictly less destructive* than member removal — the admin can re-invite in
  5 seconds — so using typed-confirm (D-29, reserved for destructive org-level
  actions) or toast-undo would be incoherent with Phase 16's modal rhythm and more
  complex for less payoff. Toast-undo also requires a dep (`live_toast`) or a
  custom flash-slot component, contradicting Sigra's "core components only" constraint.
  GitHub, Slack, Linear, Notion all use simple one-click confirm for invite revoke.

### Rate Limiting

- **D-09: Dual-key Hammer rate limit on invitation creation.**
  Two keys checked in order on every `create/2` call:

  1. `{:org_invite_create, user_id}` → default **20/day** (INV-09 literal)
  2. `{:org_invite_create, org_id}` → default **50/day**

  If either key exceeds its limit, creation returns `{:error, :rate_limited}` with
  a structured reason so the LV can show the correct flash ("You have invited too
  many people today" vs "This organization has reached its daily invitation limit").
  The user key is checked first.

  NimbleOptions surface (on the config passed to `Sigra.Organizations`):

  ```elixir
  [
    invitation_rate_limit_per_user: [
      type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
      default: {20, :timer.hours(24)},
      doc: "..."
    ],
    invitation_rate_limit_per_org: [
      type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
      default: {50, :timer.hours(24)},
      doc: "..."
    ]
  ]
  ```

  Host apps set either tuple to `:infinity` to disable that layer. The `Noop`
  rate limiter bypasses both. Matches Phase 14/15's rate-limiter abstraction.

  **Rationale:** Honors INV-09's literal "default 20/day per user" wording.
  Accommodates realistic day-1 onboarding (a 4-admin founding team can collectively
  invite 50 teammates on day 1 without hitting the ceiling). Caps compromised-account
  blast radius — a rogue admin of 5 orgs can't farm 100 invites/day. Matches the
  layered model GitHub and Slack enforce server-side. 2× Hammer calls (ETS backend)
  is microseconds of cost.

### TTL + Expiry

- **D-10: Invitation TTL default 7 days, NimbleOptions-configurable, dev-warning >30d.**
  Exact spec from Phase 17 Success Criterion 1. NimbleOptions key:
  `invitation_ttl: [type: :pos_integer, default: :timer.hours(24 * 7), ...]`.
  A compile-time or first-use dev warning fires if the configured TTL exceeds 30 days
  (phishing-window guidance) but does not block runtime.

- **D-11: Expired rows — on-read filter always, optional Oban cleanup worker.**
  **Correctness layer (always on):** Every list/lookup query filters
  `accepted_at IS NULL AND revoked_at IS NULL AND expires_at > now()`. A request that
  hits an expired row surfaces "this invitation has expired" with no membership side
  effects.

  **Hygiene layer (optional):** Sigra ships `Sigra.Workers.CleanupExpiredInvitations`
  implementing the `Sigra.Workers` behaviour (Phase 15). Host apps that use Oban
  opt in by adding it to their cron config. Default retention: **30 days past
  `expires_at`** before hard-delete (configurable via NimbleOptions). If Oban is not
  present, the worker is a no-op, mirroring the Hammer/Noop fallback pattern.

  **Rationale:** Correctness cannot depend on a cron the host might not run — the
  on-read filter is non-negotiable. The Oban worker is hygiene/PII (stale invite
  email addresses accumulating in `organization_invitations`), naturally fits the
  existing `Sigra.Workers` behaviour Phase 15 teaches hosts how to wire in, and
  mirrors `Oban.Plugins.Pruner` as the idiomatic "opt-in periodic cleanup" pattern.

### Email Template

- **D-12: Generated `organization_invitation_email.ex` in `{app}_web/emails/`.**
  Follows the v1.0 `api_token_created_email.ex` precedent exactly. Host app owns the
  template file — copy, branding, subject line, inline CSS, HTML + text multipart —
  and edits it directly without touching the library. Registered in the generated
  `auth_mailer.ex`.

  The library calls the template via:

  ```elixir
  apply(config.emails_module, :organization_invitation, [invitation, org, inviter, accept_url])
  ```

  where `config.emails_module` is already the pattern used by other Sigra-generated
  emails. The library owns *when* to send (dispatched from `Invitations.create/2`'s
  Multi, either in a `Multi.run` step or an after-commit hook — planner's discretion
  based on whether send failure should roll back the invitation) and *what shape*
  the arguments are (the security-relevant part: signed `accept_url`, never raw tokens).

  **Rationale:** Matches v1.0 email convention — existing Sigra users find the new
  file where they'd expect it (principle of least surprise). Devs customizing
  invitation copy (the overwhelmingly common case) edit one file in their own
  codebase with zero library indirection. A library-owned HEEx default with a
  behaviour-callback override was rejected: two places to look for templates,
  library recompile needed for copy tweaks, diverges from v1.0 convention.
  `phx.gen.auth` 1.8 and Ash Authentication both use the same "host owns delivery,
  lib owns trigger" split.

### New Public Library Surface

- **D-13: New `Sigra.Organizations.Invitations` module owns the invitation lifecycle.**
  Located at `lib/sigra/organizations/invitations.ex`. Public API:

  ```elixir
  # Create pending invitation (rate-limited, sends email inside Multi)
  @spec create(config :: map(), attrs :: map()) ::
          {:ok, invitation} | {:error, :rate_limited | :last_owner | changeset}

  # Signup branch — composed Multi with register+confirm+membership+accept
  @spec accept_with_signup(config :: map(), signed_token :: String.t(), user_params :: map()) ::
          {:ok, %{user: user, membership: m, invitation: inv}} | {:error, atom() | changeset}

  # Signed-in-match branch — membership + accept only
  @spec accept(config :: map(), signed_token :: String.t(), current_user :: user) ::
          {:ok, %{membership: m, invitation: inv}} | {:error, :mismatch | :expired | :revoked | :already_accepted}

  # Revoke pending invitation (owner/admin only)
  @spec revoke(config :: map(), invitation_id :: id, actor :: user) ::
          {:ok, invitation} | {:error, :not_pending | :unauthorized}

  # List queries — fill Phase 16 stubs
  @spec list_pending(config :: map(), organization :: org) :: [invitation]
  @spec list_pending_for_user(config :: map(), user :: user) :: [invitation]
  ```

  The top-level `Sigra.Organizations` module's `use` macro re-exports these functions
  with the injected `@sigra_org_config` (matches Phase 13 D-pattern). The Phase 16
  stub `list_pending_invitations_for_user/2` in `lib/sigra/organizations.ex:725-734`
  is replaced with a real query that delegates to `Sigra.Organizations.Invitations.list_pending_for_user/2`.

### Phase 16 Seam Fill-ins

- **D-14: Phase 17 is additive on top of Phase 16. Zero file moves, zero Phase 16 test churn.**
  Fills:
  - `OrganizationMembersLive` `@streams.pending_invitations` — stub stream populated
    by `Sigra.Organizations.Invitations.list_pending/1`. Adds: header "Invite member"
    button, invite-form modal (email + role select), revoke action per row, empty state.
  - `OrganizationsLive.Index` pending-invite render branch (Phase 16 D-07, branch
    `([], [_|_])`) — wires to `list_pending_for_user/1` and renders Accept/Decline
    buttons. Accept submits to `/invitations/:token/accept` (the LV's signed-in
    branch). Decline (optional, planner's call) posts a revoke-equivalent for the
    invitee side, or is deferred — scope discussion in planner.

  **The stub section `<section id="pending-invitations">` and the disabled "Invite
  member" button from Phase 16 Plan 05 are the intentional extension points.** Phase
  17 mirrors Plan 05's event-handler naming (`"invite_member"`, `"revoke_invitation"`)
  and Plan 04's error-remap helper shape (per Phase 16 VERIFICATION.md recommendation).

### Claude's Discretion

- **Email HTML/text copy, subject line, inline CSS specifics** — follow v1.0 conventions,
  planner decides exact wording. Subject line should include `{org.name}` and
  `{inviter.name}` for phishing-guard clarity ("Jane from Acme invited you to join Acme").
- **Exact placement of email send inside Multi vs after-commit hook** — planner's call
  based on whether a mailer failure should roll back the invitation row. Recommendation:
  **after successful commit**, not inside the Multi. Mailer failures should log + surface,
  not undo the DB row (the admin can re-send if it bounces). Hammer rate-limit increment
  happens before the Multi runs, so a rolled-back Multi does not refund the budget —
  acceptable (Hammer `hit` is idempotent and cheap).
- **Invite form UI polish** — role-select default value, placeholder text, validation
  feedback shape, spinner state during submit — standard Phoenix 1.8 `<.simple_form>`
  idioms, planner decides.
- **`:require_active_organization` pipeline macro** — Phase 16 D-23 deferred this to
  Phase 17 or 18. Revisit during planning: if the `/invitations/:token/accept` route
  exposes the need for a router macro, capture it; otherwise defer.
- **Audit event naming** — emit `:organization_invitation_created`,
  `:organization_invitation_revoked`, `:organization_invitation_accepted` audit events
  via Phase 15's `Sigra.Audit` + `metadata_from_scope/2`. Exact metadata shape is
  planner's call within Phase 15 conventions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 17 core
- `.planning/ROADMAP.md` §Phase 17 — Goal, requirements INV-01..INV-10, pitfalls O-2 + O-3, Success Criteria 1-5
- `.planning/REQUIREMENTS.md` §Invitations (INV) — full INV-01..INV-10 text, coverage matrix
- `.planning/PROJECT.md` — v1.1 scope decisions, hybrid lib+generator principles, "Library is org-aware" philosophy shift

### Upstream phases this builds on
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` — Organizations context shape, `for_org/2` scoping discipline, `Ecto.Multi` + last-owner guard, `use Sigra.Organizations` macro pattern
- `.planning/phases/15-audit-integration/15-CONTEXT.md` — `Sigra.Audit`, `metadata_from_scope/2`, `Sigra.Workers` behaviour
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` §D-07 (one-LV-three-branches), §D-19 (simple confirm modal), §D-23 (Phase 17 stub strategy + accept LV route), §D-29 (typed-confirm reserved for org-destructive)
- `.planning/phases/16-org-liveviews-switcher/VERIFICATION.md` — Plan 05 event-handler naming + Plan 04 error-remap helper shape recommendations

### Crypto + Token precedent
- `lib/sigra/token.ex` — `generate_hashed_token/0`, `hash_token/1`, `generate/4`, `verify/4`; the `sigra-confirm-token` / `sigra-reset-token` purpose-string convention D-01 explicitly diverges from (string-keyed-map payload vs raw-token payload)
- `lib/sigra/auth.ex:577-650` — `generate_confirmation_token/3` + `confirm_user/3` — the base-64 envelope pattern D-01 extends

### Rate limiter
- `lib/sigra/rate_limiter.ex` — behaviour
- `lib/sigra/rate_limiters/hammer.ex` — Hammer 7.x `hit(key, scale_ms, limit)` adapter, fail-open semantics (D-41 from Phase 14)
- `lib/sigra/rate_limiters/noop.ex` — Noop fallback (optional-dep philosophy)

### Existing invitation seams
- `priv/templates/sigra.install/organizations/organization_invitation.ex` — generated schema with `hashed_token`, `email` (citext), `role`, `accepted_at`, `revoked_at`, `expires_at`, `invited_by_id`, `accepted_by_id`, plus `unique_constraint(:organization_invitations_pending_index)`
- `lib/sigra/organizations.ex:725-734` — Phase 16 stub `list_pending_invitations_for_user/2` that D-13 replaces
- Generated `OrganizationMembersLive` from Phase 16 Plan 05 — `<section id="pending-invitations">` stub and disabled "Invite member" button extension points
- Generated `OrganizationsLive.Index` from Phase 16 Plan 03 — pending-invite render branch (Phase 16 D-07 branch `([], [_|_])`)

### Email + mailer precedent
- `priv/templates/sigra.install/core/api_token_created_email.ex` — the exact template shape D-12 follows
- `priv/templates/sigra.install/core/auth_mailer.ex` — generated mailer D-12 registers against
- `priv/templates/sigra.install/core/emails.ex` — generated emails context module

### External specs (security threat model)
- Jetstream #907 — "accept invitation as any logged-in user" — the canonical Elixir bug D-01 + D-06 close by construction
- Keycloak CVE-2026-1529 — same class of bug in a different stack — referenced in Phase 17 goal
- Pow issue #534 — invitation-token orphan-row bug D-07's library-owned Multi closes

### Phoenix + Elixir stdlib
- `Plug.Crypto.sign/4` + `Plug.Crypto.verify/4` — term serialization stability (erlang term format, string-keyed maps to avoid atom-table growth)
- `Ecto.Multi.append/2` — the compose primitive D-07 uses to chain `Sigra.Auth` + `Sigra.Organizations` multis

### Phase 16 follow-up — fold into Phase 17 prep
- STATE.md "Phase 16 follow-up" note: library slug-alias migration template uses `now()` in a Postgres partial-unique index predicate, which Postgres rejects. Phase 17 D-03 explicitly avoids repeating this by using an `IS NULL`-only predicate. **If planner decides to also fix the slug-alias migration in Phase 17 (because it's the same class of fix), capture it as a Plan 17-0X sidecar.** Otherwise note it as still pending.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Sigra.Token.generate_hashed_token/0` + `hash_token/1`** — the `(raw, hashed)` tuple
  pattern D-01 extends. Lives at `lib/sigra/token.ex:87+`.
- **`Plug.Crypto.sign/4` + `Plug.Crypto.verify/4`** — already used by `generate_confirmation_token`
  in `lib/sigra/auth.ex:583`. D-01 calls them with a string-keyed map instead of raw binary.
- **`Sigra.RateLimiters.Hammer.hit/3`** — existing rate-limiter with Noop fallback.
  D-09 calls it twice per invitation create.
- **`Ecto.Multi.append/2`** — composes existing `Sigra.Auth.register_confirmed_user_multi/2`
  (or equivalent — confirm planner finds the exact name) with the new
  `Sigra.Organizations.add_member_multi/2` from Phase 13.
- **Phase 13's `use Sigra.Organizations` macro** — D-13 re-exports
  `Sigra.Organizations.Invitations.*` functions through it with injected `@sigra_org_config`.
- **`Sigra.Workers` behaviour** (Phase 15) — D-11's optional `CleanupExpiredInvitations`
  worker implements this, stays a no-op if Oban absent.
- **`Sigra.Audit` + `metadata_from_scope/2`** (Phase 15) — audit event emission for
  create/revoke/accept.
- **v1.0 `api_token_created_email.ex` template** — exact shape D-12 mirrors for
  `organization_invitation_email.ex`.
- **Phoenix 1.8 stock `<.modal>`, `<.simple_form>`, `<.button>`, `<.flash>`** — all that
  D-06 + D-08 need; no new components.

### Established Patterns

- **Hybrid lib+generator (PROJECT.md):** security-critical logic (tokens, Multis,
  rate limits, HMAC verify) in `lib/sigra/*`; generated wrapper + templates in
  `priv/templates/sigra.install/organizations/`. D-07 + D-12 + D-13 keep this split clean.
- **Contexts own their Multis (Phase 13 D-pattern):** `Sigra.Organizations.add_member_multi`
  is the precedent D-07 extends.
- **Per-purpose token salts:** `sigra-confirm-token`, `sigra-reset-token`, `sigra-oauth-state`.
  D-02 adds `sigra-org-invite-token` to the canon.
- **Tuple-shaped rate-limit keys:** `{:login_attempt, user_id}`, `{:password_reset, user_id}`.
  D-09 follows with `{:org_invite_create, user_id}` + `{:org_invite_create, org_id}`.
- **One LiveView, branches in mount/render (Phase 16 D-07):** D-06 applies the same
  philosophy to the accept LV.
- **Simple confirm modal for reversible destructive actions (Phase 16 D-19):** D-08
  extends this to revoke.
- **Per-adapter conditional migrations (Phase 11):** D-03's MySQL fallback uses this.
- **NimbleOptions for all config surfaces:** D-09 + D-10 + D-11 add their keys to
  the Sigra Organizations config schema.

### Integration Points

- **Router:** new unscoped route `/invitations/:token/accept` added to the generated
  router template. Must be outside `:require_authenticated_user` pipeline (invitee may
  not be signed in) and outside any `/organizations/:org` scope block.
- **Generated `auth_mailer.ex`:** registers `organization_invitation_email.ex` alongside
  existing templates.
- **`lib/sigra/organizations.ex` Phase 16 stub (line 725-734):** `list_pending_invitations_for_user/2`
  replaced with real delegation to `Sigra.Organizations.Invitations.list_pending_for_user/2`.
- **Phase 16 `OrganizationMembersLive` stub section:** invite form modal + pending-invite
  stream + revoke action wired in additively.
- **Phase 16 `OrganizationsLive.Index` pending-invite render branch:** wired to real
  list query, Accept button routes to `/invitations/:token/accept`.
- **Optional Oban cron:** `Sigra.Workers.CleanupExpiredInvitations` slotted into host app's
  Oban config.

</code_context>

<specifics>
## Specific Ideas

- **"By construction, not by convention"** — the phrase from Phase 17's ROADMAP goal
  is the explicit test for D-01 (sign email into HMAC) and D-06 (mismatch branch renders
  zero accept form). Every downstream decision must be judged against this standard.
- **"Principle of least surprise"** — D-12's email template layout, D-08's revoke modal,
  and D-06's single-LV-three-branches all optimize for devs and users finding things
  where they expect them, matching Phase 16 rhythms and gold-standard SaaS UX.
- **Phase 16 follow-up slug-alias migration fix** — same Postgres IMMUTABLE-predicate
  class as D-03. Planner should decide whether to fix it in Phase 17 as a sidecar or
  defer to a dedicated phase.
- **Jetstream #907 regression test** is a hard deliverable from Success Criterion 3 —
  must be in the plan's test matrix, wired against D-06's mismatch branch specifically.
- **Pow #534 orphan-row regression test** — D-07's library-owned Multi should include
  a targeted test showing that a mid-Multi failure leaves no user row, no membership
  row, no invitation-accepted stamp.

</specifics>

<deferred>
## Deferred Ideas

- **Bulk invite** — "invite 20 people at once" CSV or textarea input. Not in INV-01..INV-10.
  Belongs in a later UX polish phase.
- **Resend-same-token** — "resend invitation email without creating a new row". D-05
  revokes+recreates on role change, but pure resend-without-change was not in requirements.
  Add if users ask for it post-v1.1.
- **Shareable invite link** (`token` not bound to a specific email, anyone-with-the-link
  joins) — explicit anti-feature per PROJECT.md ("accept as any logged-in user" is the
  exact vulnerability Phase 17 closes). Will never be added without an explicit
  security-model revision.
- **SSO/SCIM user provisioning** — out of scope for v1.1, earmarked for v1.2 admin track.
- **Invitation analytics** (open rate, click rate, time-to-accept) — would require mailer
  hooks into Swoosh delivery events. Out of scope.
- **Per-email-target rate limit** (`{:org_invite_create, email_hash}`, 3/day) —
  addresses harassment of a specific target address rather than volume abuse. Good
  hardening pass for a Phase 17.x once real abuse telemetry exists.
- **`:require_active_organization` router pipeline macro** — Phase 16 D-23 deferred;
  revisit during Phase 17 planning and possibly defer again to Phase 18.
- **Decline-invite from invitee side** (invitee can decline an invite without being
  signed-in as matching email) — minor UX nicety, planner may include in-scope if
  trivial or defer.

### Reviewed Todos (not folded)

- **Phase 11 (Generator Feature System) planning** — blocked by v1.1 Foundation work
  order, not Phase 17's concern.
- **Phase 19 / Phase 20 kickoff spikes** — passkey track, out of Phase 17 scope.

</deferred>

---

*Phase: 17-invitation-flow-email*
*Context gathered: 2026-04-13*
