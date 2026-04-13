# Phase 17: Invitation Flow + Email — Research

**Researched:** 2026-04-13
**Domain:** Organization invitations — email-bound HMAC tokens, atomic multi-step
accept flows, email delivery, pending-invite LiveView surfaces
**Confidence:** HIGH on library seams and Sigra conventions (read directly from
tree); MEDIUM on a small number of load-bearing API assumptions called out in
the Assumptions Log.

## Summary

Phase 17 is almost entirely an *additive, wiring* phase: every dependency
(schema, migration, partial index, rate limiter, audit pipeline, scope plug,
OrganizationMembersLive stub, OrganizationsLive.Index pending-branch stub,
email-template fragment pattern, Sigra.Workers behaviour, NimbleOptions
config schema) already exists in the tree. CONTEXT.md is fully locked on
every design decision. Research here is about verifying the integration
seams, calling out two API-shape assumptions the CONTEXT leaves implicit,
and producing a prescriptive test+validation plan.

The single highest-leverage finding is this: **CONTEXT D-07 presumes a
`Sigra.Auth.register_confirmed_user_multi/2` (or equivalent) and a
`Sigra.Organizations.add_member_multi/5` exist to `Multi.append` together.
Neither exists today.** `Sigra.Auth.register/3` runs its own
`repo.insert/1` with no Multi seam (lib/sigra/auth.ex:146-203); and
`Sigra.Organizations.add_member/5` builds its changeset but runs its own
`repo.transaction/1` internally (lib/sigra/organizations.ex:554-576). Phase
17 must therefore expose a Multi-builder for each — a small, principled
refactor that keeps the public functions working and adds composable Multi
primitives underneath. This is the plan's first load-bearing task.

**Primary recommendation:** Wave 0 of the plan should land (a) the two
Multi-builder extractions, (b) the `Sigra.Token.generate_hashed_envelope/4`
/ `verify_hashed_envelope/4` addition (D-01), and (c) the
`Sigra.Organizations.Invitations` module skeleton with NimbleOptions keys
added to `@org_config_schema`. Every later wave is composition over those.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 Token envelope:** Sign `%{"t" => raw, "e" => String.downcase(email)}`
with string keys via `Plug.Crypto.sign/4`, purpose `"sigra-org-invite-token"`.
Store `hashed_token` (SHA-256 of raw) in DB. On verify: decode base64 →
`Plug.Crypto.verify` → destructure `%{"t" => raw, "e" => bound_email}` →
lookup by `hash_token(raw)` → assert `bound_email == downcase(row.email)`.

**D-02 Purpose string:** `"sigra-org-invite-token"`.

**D-03 Partial unique index:** Postgres/SQLite use
`create unique_index(..., where: "accepted_at IS NULL AND revoked_at IS NULL")`.
MySQL fallback: no partial index + `Repo.transact/2` + advisory lock
+ belt-and-suspenders changeset guard on all adapters. NEVER include
`now()` or any non-IMMUTABLE function in the predicate.

**D-04 Expired rows:** Not deleted on read; list queries filter
`accepted_at IS NULL AND revoked_at IS NULL AND expires_at > now()`.

**D-05 Re-invite:** revoke old row + insert new row (two emails, clean audit,
partial-unique invariant preserved).

**D-06 Accept route:** Single unscoped LiveView at
`/invitations/:token/accept` with branches `:signup`, `:accept`, `:mismatch`,
`:invalid`, `:expired`, `:revoked`, `:already_accepted`. Mismatch branch
MUST contain zero accept form/button in the rendered DOM (hijack defense by
construction — checker grep-target).

**D-07 Multi orchestration:** `Sigra.Organizations.Invitations.accept_with_signup/3`
and `.accept/3` own library-level Multis via `Multi.append` composition.
Generated LV is a thin event-handler wrapper.

**D-08 Revoke UX:** simple `<.modal>` confirm (not typed, not toast-undo).

**D-09 Rate limit:** dual-key Hammer — `{:org_invite_create, user_id}`
20/day default + `{:org_invite_create, org_id}` 50/day default; user key
checked first; either key configurable to `:infinity` to disable; Noop
limiter bypasses both.

**D-10 TTL:** `invitation_ttl` default `:timer.hours(24 * 7)`; dev warning
(first-use) if > 30 days; NimbleOptions-configurable.

**D-11 Expired cleanup:** correctness = on-read filter (always);
hygiene = optional `Sigra.Workers.CleanupExpiredInvitations` worker
implementing `Sigra.Workers` behaviour; no-op if Oban absent; default
retention 30 days past `expires_at`.

**D-12 Email template:** Generated fragment file
`priv/templates/sigra.install/core/organization_invitation_email.ex`
mirroring `api_token_created_email.ex` shape exactly; registered in
`auth_mailer.ex`/`emails.ex`; library triggers via
`apply(config.emails_module, :organization_invitation, [invitation, org, inviter, accept_url])`.
Send happens **after successful commit** (planner discretion, recommended).

**D-13 Public library surface:** New `Sigra.Organizations.Invitations` module
at `lib/sigra/organizations/invitations.ex` with `create/2`, `accept/3`,
`accept_with_signup/3`, `revoke/3`, `list_pending/2`, `list_pending_for_user/2`.
Re-exported via the `use Sigra.Organizations` macro.

**D-14 Phase 16 seams:** Phase 17 is ADDITIVE. Zero Phase 16 file moves,
zero Phase 16 test churn. Fill `OrganizationMembersLive`
`<section id="pending-invitations-section">` + header "Invite member" button;
fill `OrganizationsLive.Index` `([], [_|_])` branch; replace
`Sigra.Organizations.list_pending_invitations_for_user/2` stub
(lib/sigra/organizations.ex:724-734).

### Claude's Discretion

- Email HTML/text copy specifics (follow v1.0 `api_token_created_email`
  convention — already locked in UI-SPEC anyway)
- Send-inside-Multi vs after-commit hook — recommended **after commit**
- Invite form UI polish (role select default, placeholder) — defaults
  locked in UI-SPEC (`member` default, `teammate@example.com` placeholder)
- Whether to fold the Phase 16 slug-alias migration fix (Postgres `now()`
  in partial-unique predicate) into Phase 17 as a sidecar
- Audit event metadata shape within Phase 15 conventions
- Decline from invitee side (deferred in UI-SPEC)
- `:require_active_organization` router macro (defer recommended)

### Deferred Ideas (OUT OF SCOPE)

- Bulk invite (CSV / textarea)
- Resend-same-token
- Shareable invite link (token not bound to email) — explicit anti-feature
- SSO/SCIM user provisioning
- Invitation analytics
- Per-email-target rate limit `{:org_invite_create, email_hash}`
- `:require_active_organization` router pipeline macro
- Invitee-side decline

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INV-01 | Owner/admin can invite a user by email with optional role | `OrganizationMembersLive` header button + modal (UI-SPEC §Invite-Member Modal); `Invitations.create/2` (D-13) |
| INV-02 | Single-use HMAC token, SHA-256 hashed in DB, never plaintext | D-01 envelope pattern; reuses `Sigra.Token.generate_hashed_token/0` (lib/sigra/token.ex:94) + new `"sigra-org-invite-token"` purpose; DB column `hashed_token :binary` already in migration (priv/templates/sigra.install/organizations/migration.exs:40) |
| INV-03 | Email contains accept URL, org, inviter, expiry; HTML+text multipart with inline CSS | D-12 generates fragment file mirroring `api_token_created_email.ex` shape (priv/templates/sigra.install/core/api_token_created_email.ex); UI-SPEC §Organization Invitation Email locks subject/body/CTA/fallback-URL |
| INV-04 | Default 7d expiry, NimbleOptions-configurable, dev warning > 30d | D-10 adds `invitation_ttl` key to `@org_config_schema` (lib/sigra/organizations.ex:38-103); first-use Logger.warning in `use Sigra.Organizations` or `Invitations.create/2` |
| INV-05 | No-account invitee signs up; email pre-filled and locked; atomic user+membership in one Multi | D-07 `accept_with_signup/3` uses `Multi.append` to compose register-user-multi + add-member-multi + accept_invitation update; UI-SPEC §Accept LV Signup Branch locks `disabled + readonly` email input |
| INV-06 | Signed-in-match accepts, signed-in-mismatch blocks with explicit page; citext-insensitive | D-06 three-branch render: mismatch branch contains ZERO accept DOM (by construction); `:email, :citext` already in migration:38 |
| INV-07 | Accepting marks `accepted_at` inside Multi; replay returns "already accepted" flash | D-07 Multi includes `Multi.update(:accept_invitation, ...)`; idempotency enforced by `accepted_at IS NULL` guard in accept path |
| INV-08 | Owner/admin can revoke pending invite; revoked returns "no longer valid" | D-08 simple confirm modal; `Invitations.revoke/3` stamps `revoked_at` + `revoked_by_id`; accept LV handles `:revoked` branch |
| INV-09 | Rate-limit invite creation (default 20/day/user via Hammer) | D-09 dual-key, delegates to `Sigra.RateLimiters.Hammer` / `.Noop` (lib/sigra/rate_limiters/*.ex); `check_rate(key, limit, window_ms)` string-key signature |
| INV-10 | Pending list shows email, role, invited-by, expires-in, revoke button | UI-SPEC §Pending Invitations List locks five columns + aria-label; `list_pending/2` library query replacing Phase 16 stub at lib/sigra/organizations.ex:725-734 |

## Project Constraints (from CLAUDE.md)

- **Phoenix ~> 1.8**, Ecto ~> 3.13, Elixir ~> 1.18, OTP 27
- **PostgreSQL primary** with `citext` for email; MySQL/SQLite via conditional migration
- **All tokens HMAC-protected and SHA-256 hashed at rest**; timing-safe compares
- **Hammer ~> 7.3** with ETS backend; Noop fallback (library philosophy: Hammer optional)
- **Swoosh ~> 1.25** for email, behaviour-wrapped `Sigra.Mailer`
- **Oban ~> 2.17 optional**; inline fallback; worker no-op when Oban absent
- **NimbleOptions for all public config surfaces**
- **Library-first:** security-critical in `lib/sigra/`, thin generator wrappers in
  `priv/templates/sigra.install/`
- **OWASP**, enumeration prevention, no hand-rolled crypto
- **Minimal deps**, no Tesla, no Pow
- **Elixir 1.18 built-in JSON**; Ecto 3.13 `Repo.transact/2` (not deprecated `Repo.transaction/2`)
- **Testing:** AAA, flat, self-contained; comprehensive (happy + boundary + errors)

## Standard Stack

Phase 17 adds **zero new dependencies**. Every building block is already
pulled in by v1.0/v1.1:

### Core (all already vendored)

| Library | Version in tree | Purpose in Phase 17 |
|---------|-----------------|---------------------|
| `plug_crypto` | (transitive via Phoenix 1.8) | `Plug.Crypto.sign/4` + `verify/4` — token envelope HMAC (D-01) [VERIFIED: existing use in lib/sigra/auth.ex:583] |
| `ecto_sql` ~> 3.13 | in mix.lock | `Ecto.Multi` + `Repo.transact/2` (D-07 composition) [CITED: hexdocs.pm/ecto/Ecto.Multi.html#append/2] |
| `hammer` ~> 7.3 | existing `Sigra.RateLimiters.Hammer` wrapper | Dual-key rate limit (D-09) [VERIFIED: lib/sigra/rate_limiters/hammer.ex:28-40] |
| `nimble_options` ~> 1.1 | used by `@org_config_schema` | New keys: `invitation_ttl`, `invitation_rate_limit_per_user`, `invitation_rate_limit_per_org`, `invitation_cleanup_retention` [VERIFIED: lib/sigra/organizations.ex:38-103] |
| `swoosh` ~> 1.25 | v1.0 mailer already in tree | `organization_invitation_email` fragment via `emails.ex` [VERIFIED: priv/templates/sigra.install/core/emails.ex:12] |
| `oban` ~> 2.17 (optional) | `Sigra.Workers` behaviour in place | `CleanupExpiredInvitations` worker implements behaviour; no-op if Oban absent [VERIFIED: lib/sigra/workers.ex] |

### Elixir Stdlib Primitives

- `:crypto.hash(:sha256, raw_token)` — already wrapped by `Sigra.Token.hash_token/1`
- `:crypto.strong_rand_bytes/1` — already wrapped by `Sigra.Token.generate_hashed_token/0`
- `Base.url_encode64/2` (with `padding: false`) — base64 envelope wrapper
- `Plug.Crypto.secure_compare/2` — constant-time compare (already wrapped by `Sigra.Token.secure_compare/2`)

### Alternatives Considered

| Instead of | Alternative | Why Rejected |
|------------|-------------|--------------|
| `Plug.Crypto.sign/4` string-keyed map envelope | Sign raw token + assert email at DB compare time | Violates "by construction" — matches the exact Jetstream #907 / Keycloak CVE-2026-1529 failure mode |
| Term-encoded tuple envelope | `{raw, email}` tuple | Works but less inspectable; string-keyed map is more debugger-friendly and avoids atom-table concerns already raised in CONTEXT |
| Dedicated crypto lib (Joken JWT) | — | Adds dep; `Plug.Crypto` is stdlib and already used for every other Sigra token |

## Architecture Patterns

### Module Layout (to create)

```
lib/sigra/
├── organizations.ex                  # (extend __org_config_schema__ + delegators)
├── organizations/
│   └── invitations.ex                # NEW — library module owning Multis + lookups
├── token.ex                          # (extend with envelope helpers — see Code Examples)
├── workers/
│   └── cleanup_expired_invitations.ex  # NEW, optional
└── auth.ex                           # (extract register_user_multi/1 — see Gap 1)

priv/templates/sigra.install/
├── core/
│   ├── organization_invitation_email.ex   # NEW fragment (mirrors api_token_created_email.ex)
│   ├── emails.ex                           # (extend: inject invitation fn)
│   └── auth_mailer.ex                      # (no change — existing delivery path)
└── organizations/
    └── live/
        ├── organization_members_live.ex    # (extend: modal, stream, handlers, revoke modal)
        ├── organizations_live/index.ex     # (fill [_|_] branch)
        └── invitation_accept_live.ex       # NEW — single LV, 3+ branches
```

### Pattern 1: Library-owned Multi with thin LV wrapper

**What:** Security-critical Ecto.Multi lives in the library; generated LV
is a ~5-line event handler.

**When to use:** Any flow touching security-critical atomicity (auth, org
membership, invitation acceptance).

**Example from Phase 13 precedent:**

```elixir
# lib/sigra/organizations.ex:554-576 — existing pattern
def add_member(config, scope, org, user, role) do
  with :ok <- run_before_hook(config, :before_add_member, [org, user, role, scope]) do
    Multi.new()
    |> Multi.insert(:membership, build_membership_changeset(...))
    |> append_audit(config, "organization.member_add", scope, ...)
    |> config.repo.transaction()
    |> normalize_multi_result()
  end
end
```

Phase 17 extends this pattern to a *composed* Multi. The composition
boundary is `Multi.append/2`, not `merge/2`:

```elixir
# lib/sigra/organizations/invitations.ex — D-07 shape
def accept_with_signup(config, signed_token, user_params) do
  with {:ok, invitation, raw} <- verify_and_load(config, signed_token),
       :ok <- check_still_pending(invitation) do
    Multi.new()
    |> Multi.append(Sigra.Auth.register_user_multi(user_params, auth_opts_from(config)))
    |> Multi.run(:confirm_user, fn repo, %{user: u} ->
         repo.update(Ecto.Changeset.change(u, confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)))
       end)
    |> Multi.append(Sigra.Organizations.add_member_multi(config, invitation.organization_id, :accept_user, invitation.role))
    |> Multi.update(:accept_invitation, fn %{accept_user: user} ->
         Invitation.accept_changeset(invitation, accepted_by_id: user.id)
       end)
    |> Sigra.Audit.log_multi_safe("organization.invitation.accepted", Sigra.Scope.from_opts([], nil),
         metadata: %{invitation_id: invitation.id, role: to_string(invitation.role)})
    |> config.repo.transact()
    |> normalize_multi_result()
  end
end
```

Note the use of `Ecto.Multi.append/2` — the sub-Multis must use disjoint
step names. Convention: sub-Multi from `Sigra.Auth` uses `:user`,
`:confirm_user`; sub-Multi from `Sigra.Organizations` uses `:membership`;
invitation step is `:accept_invitation`.

### Pattern 2: HMAC envelope with string-keyed map payload

**What:** Bind email into the token payload so HMAC verification rejects
tampering before any DB row is touched.

**When to use:** Whenever the token holder is NOT yet the authenticated
principal (invitations, transfer-of-ownership, delegation grants).

**Source:** Dashbit's Bytepack reference app uses this pattern for invite
/ transfer flows [ASSUMED — cited in CONTEXT.md discussion log;
not re-verified in this session]. Phoenix `phx.gen.auth` 1.8 confirmation
flow uses the *opposite* pattern (raw-token sign, bind at DB lookup) because
the holder of the confirm link is already the user being confirmed — the
threat model differs.

```elixir
# NEW helpers on Sigra.Token — see Code Examples section for full module
@invite_purpose "sigra-org-invite-token"

def generate_invite_envelope(secret_key_base, email) when is_binary(email) do
  {raw, hashed} = generate_hashed_token()
  signed = Plug.Crypto.sign(secret_key_base, @invite_purpose,
             %{"t" => raw, "e" => String.downcase(email)})
  {Base.url_encode64(signed, padding: false), hashed}
end

def verify_invite_envelope(secret_key_base, encoded, max_age_seconds) do
  with {:ok, signed} <- Base.url_decode64(encoded, padding: false),
       {:ok, %{"t" => raw, "e" => email}} <-
         Plug.Crypto.verify(secret_key_base, @invite_purpose, signed, max_age: max_age_seconds) do
    {:ok, %{raw_token: raw, bound_email: email, hashed_token: hash_token(raw)}}
  else
    {:error, :expired} -> {:error, :expired}
    _ -> {:error, :invalid}
  end
end
```

### Pattern 3: Single LV with branched `mount/3` and pattern-matched render

**What:** One route, one `mount/3`, assign `:branch` atom, `render/1`
dispatches via `case @branch do`.

**When to use:** Any flow with finite user states at entry (signed-in
match / signed-in mismatch / anonymous signup / error states) where a
single bookmarkable URL is desirable.

**Source:** Phase 16 D-07 precedent (`OrganizationsLive.Index` 3-branch).
`phx.gen.auth` 1.8 `/users/confirm/:token` follows the same pattern.
GitHub, Slack, Linear, Notion, Vercel all use single-route invite accept.

**Canonical assign table for `InvitationAcceptLive`:**

| Branch atom | Trigger | Rendered component | Reachability |
|-------------|---------|--------------------|-------------|
| `:signup` | `current_user == nil` | `signup_branch/1` with locked email | unauth only |
| `:accept` | citext-equal `current_user.email == invitation.email` | `accept_branch/1` with one-click button | auth only |
| `:mismatch` | auth, emails differ | `mismatch_branch/1` — ZERO accept DOM | auth only |
| `:invalid` | HMAC verify fail or bound_email != db_email | `error_card/1` generic copy (no info leak) | any |
| `:expired` | `expires_at <= now()` | `error_card/1` with inviter email shown | any |
| `:revoked` | `revoked_at != nil` | `error_card/1` "no longer valid" | any |
| `:already_accepted` | `accepted_at != nil` | `error_card/1` + if member, redirect | any |

### Pattern 4: After-commit side effects (recommended for email delivery)

```elixir
# Inside Invitations.create/2
with {:ok, %{invitation: inv}} <- run_multi(config, multi) do
  # Fire-and-forget email send AFTER the Multi commits.
  # Failures log + surface as flash — DO NOT roll back the invitation row.
  deliver_invitation_email(config, inv, org, inviter, accept_url)
  {:ok, inv}
end
```

Rationale (planner discretion D-12): a mailer transient failure is
recoverable (admin can revoke + re-invite or, in a future phase, resend).
Rolling back the DB row on email failure means the invitee sees an
inconsistent state ("my admin said they invited me but there's no record")
AND the rate limiter has already been incremented (Hammer `hit` is not
transactional with the DB). Accept the mismatch window; log + flash
instead.

### Pattern 5: Per-adapter conditional migration emission

Existing Phase 11 convention. The migration template already emits
Postgres/SQLite partial-unique + MySQL full-unique at
priv/templates/sigra.install/organizations/migration.exs:52-55 and :133.
Phase 17 does NOT touch the migration — the schema is already correct
in this file.

**BUT:** the migration currently has `create index(:organization_invitations, [:hashed_token])`
at line 57 (non-unique). Phase 17 should verify whether a unique index
is safer — multiple hashed_token collisions on a 32-byte SHA-256 space are
astronomically unlikely, but a UNIQUE index protects against a bug in
token generation that could silently allow duplicates. **Planner
decision: make `hashed_token` unique.** Cost is zero; value is a
load-bearing invariant.

### Anti-Patterns to Avoid

- **Signing raw token only and binding email at DB compare time.** The
  Jetstream #907 / Keycloak CVE-2026-1529 bug class — server-side guards
  drift from documentation and miss edge cases. D-01 signs email INTO
  the HMAC so tampering is rejected before any DB touch.
- **Rendering the accept form in ALL branches and hiding via `if` in the
  DOM.** The mismatch branch must not emit the accept form AT ALL, not
  just hide it with CSS or `<%= if ... do %>`. The checker grep-target
  (UI-SPEC §Structural Checker Invariants) enforces this.
- **Using `merge/2` to compose Multis across modules.** `Multi.merge/2`
  is for dynamic Multi composition based on previous-step results.
  `Multi.append/2` is for static pre-built sub-Multis from different
  modules. Phase 17 composes pre-built sub-Multis → use `append`.
- **Including `expires_at > now()` in the partial-unique predicate.**
  Postgres rejects non-IMMUTABLE functions in index predicates — the
  exact Phase 16 slug-alias migration bug STATE.md captures as a
  follow-up. D-03 explicitly uses IS-NULL-only predicate.
- **Putting the email send inside the Multi.** A `Multi.run` step that
  calls the mailer ties email deliverability to DB commit atomicity,
  which means a mailer flap rolls back the invitation row and re-runs
  all side effects. Send after commit.
- **Hand-rolling atom conversion on the decoded Plug.Crypto verify
  result.** String keys on the signed map prevent atom-table growth;
  `Plug.Crypto.verify` returns exactly what was signed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time-constant token comparison | Custom byte-by-byte loop | `Sigra.Token.secure_compare/2` → `Plug.Crypto.secure_compare/2` | Timing attacks |
| HMAC signing | Custom `:crypto.mac` call | `Plug.Crypto.sign/4` + `verify/4` with purpose string | Audit-reviewed, batteries-included |
| SHA-256 token hash | Custom `:crypto.hash` | `Sigra.Token.hash_token/1` (already wraps `:crypto.hash(:sha256, _)`) | Consistency, already timing-tested |
| Random secure bytes | `:crypto.strong_rand_bytes/1` naked | `Sigra.Token.generate_hashed_token/0` returns `{raw, hashed}` pair | Pair invariant |
| Base64 URL-safe encoding | `Base.encode64` with manual replace | `Base.url_encode64(_, padding: false)` | Stdlib handles padding + URL-safe alphabet |
| Rate-limit bucket logic | Custom ETS + GenServer | `Sigra.RateLimiters.Hammer.check_rate/3` | Hammer 7.x atomic ETS backend |
| Multi atomicity across user+membership+invitation | Three sequential `Repo.insert` with manual rollback on error | `Ecto.Multi.append` + `Repo.transact` | Pow #534 orphan-row bug — exactly this class of error |
| Case-insensitive email compare | `String.downcase` on both sides in app code | `:email, :citext` column type + DB-level compare | Belt-and-suspenders — already in migration |
| Token envelope term framing | Custom `<<raw::binary-32, sha256_email::binary-32>>` split | `Plug.Crypto.sign` with a string-keyed map | Map is inspectable, trivially extended with `role` or other fields in future phases |
| Mail HTML wrapping | Custom `<html>` scaffold | Existing `wrap_html/1` in `emails.ex` | Already email-client-tested |
| Oban cron cleanup semantics | Custom GenServer loop | `Sigra.Workers` behaviour + optional Oban job | No-op fallback, consistent with Phase 15 convention |

**Key insight:** every primitive this phase needs is already in-tree. The
work is composition, not invention.

## Runtime State Inventory

> Phase 17 is a greenfield-add phase (no refactor or rename). Runtime
> state inventory is SKIPPED — no existing stored data, service config,
> OS-registered state, secrets, or build artifacts reference invitation
> semantics yet. Phase 16 left only code-level stubs (LV section id,
> library `list_pending_invitations_for_user/2` stub), which are explicit
> extension points.

## Common Pitfalls

### Pitfall 1: Server-side guard drift from documented invariant (Jetstream #907 class)

**What goes wrong:** Developer writes "we check `current_user.email ==
invitation.email` at accept time" in the docs, but a later refactor moves
the check or a different code path bypasses it (e.g., a new OAuth
auto-accept hook). Attacker steals an invite link, signs in as any
account, clicks accept → gets silently added.

**Why it happens:** Security depends on *continuous vigilance across
multiple code paths and time*. Every new feature that touches invitation
acceptance has to re-verify the check. Real-world incidents: Jetstream
#907 (Laravel), Keycloak CVE-2026-1529, SharePoint identity-confusion
class.

**How to avoid:** D-01 signs email into the HMAC itself. Tampering
breaks the HMAC and `Plug.Crypto.verify` returns `:invalid`. D-06 renders
zero accept form in the mismatch branch — even if a server guard
regresses, there's nothing to POST to. Defense-in-depth: BOTH the HMAC
binding AND the DOM-level absence.

**Warning signs:** Any PR that adds a new accept code path, any refactor
that touches `InvitationAcceptLive.mount/3`, any feature that
auto-accepts invites (SSO, social login, etc.) must prove the mismatch
branch is still unreachable.

**Regression test (hard deliverable from Success Criterion 3):**

```elixir
test "signed-in-as-different-email cannot accept invitation (Jetstream #907 regression)" do
  # Setup: org, inviter, pending invitation for target_email
  org = org_fixture()
  inviter = user_fixture(role: :owner, org: org)
  target_email = "target@example.com"
  {:ok, invitation} = Invitations.create(config, %{
    organization_id: org.id, email: target_email, role: :member, invited_by_id: inviter.id
  })

  # Attacker: a different existing user
  attacker = user_fixture(email: "attacker@example.com") |> confirm()
  conn = log_in_user(conn, attacker)

  # Act: mount the accept LV with the signed token
  {:ok, view, html} = live(conn, ~p"/invitations/#{invitation.signed_token}/accept")

  # Assert: mismatch branch rendered
  assert html =~ "This invitation is not for you"

  # Assert: ZERO accept form/button in rendered DOM
  refute html =~ "phx-click=\"accept_invitation\""
  refute html =~ "phx-submit=\"accept_with_signup\""
  refute html =~ "Accept &amp; join"

  # Assert: even if the attacker crafts the event (synthetic click),
  # the server-side handler is unreachable because the handler is
  # attached to a branch component that is never rendered → no handler
  # exists on the mount.
  assert_raise ArgumentError, fn ->
    view |> render_click("accept_invitation")
  end

  # Assert: zero DB mutation
  assert Repo.aggregate(OrganizationMembership, :count, :id) ==
           initial_membership_count
  assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
end
```

### Pitfall 2: Orphan-row after partial Multi failure (Pow #534 class)

**What goes wrong:** Multi-step accept creates user, creates membership,
but fails at the invitation-update step. If not in a transaction, the
user + membership rows persist but no invitation is marked accepted;
retry creates a duplicate membership.

**Why it happens:** Developer splits the flow across controller
callbacks or multiple `Repo.insert` calls, missing a transaction
boundary. Pow shipped this exact bug (issue #534).

**How to avoid:** D-07 uses a single `Ecto.Multi` composed via `append`,
run through `Repo.transact/2`. Any step failure rolls back all prior
steps.

**Warning signs:** Any `with` chain that calls `Repo.insert` twice
without a Multi; any split between "create user" and "add membership"
across different functions that own their own transactions.

**Regression test:**

```elixir
test "mid-Multi failure rolls back all steps (Pow #534 regression)" do
  # Inject a changeset error at the accept_invitation update step
  # by passing an already-accepted invitation.
  invitation = invitation_fixture() |> mark_accepted()

  initial_user_count = Repo.aggregate(User, :count, :id)
  initial_membership_count = Repo.aggregate(OrganizationMembership, :count, :id)

  assert {:error, :already_accepted} =
    Invitations.accept_with_signup(config, invitation.signed_token, %{
      email: invitation.email, password: "validpassword123"
    })

  # Zero writes across all three tables
  assert Repo.aggregate(User, :count, :id) == initial_user_count
  assert Repo.aggregate(OrganizationMembership, :count, :id) == initial_membership_count
end
```

### Pitfall 3: Replay-with-revoked-row wedge

**What goes wrong:** Admin revokes invitation. Attacker already had the
link. Accept path checks `accepted_at IS NULL` but not `revoked_at IS NULL`
→ revoked invitation still accepts.

**How to avoid:** Accept guard clause checks BOTH `accepted_at == nil`
AND `revoked_at == nil` AND `expires_at > now()`. All three in the same
pattern-match or `with` chain.

**Regression test:**

```elixir
test "revoked invitation cannot be accepted" do
  invitation = invitation_fixture(email: user.email)
  {:ok, _} = Invitations.revoke(config, invitation.id, owner)

  assert {:error, :revoked} =
    Invitations.accept(config, invitation.signed_token, user)
end
```

### Pitfall 4: Expired-predicate IMMUTABLE pitfall (Postgres partial index)

**What goes wrong:** Migration writes
`where: "expires_at > now() AND accepted_at IS NULL"`. Postgres rejects
because `now()` is not IMMUTABLE. The migration fails on Postgres
installs — the exact Phase 16 slug-alias bug STATE.md flags.

**How to avoid:** D-03 predicate is IS-NULL-only. Expiry is enforced at
query time, not at index predicate time. Partial-uniqueness is only on
*pending* rows; expired rows are functionally ignored via the on-read
filter.

**Validation:** Migration template at
priv/templates/sigra.install/organizations/migration.exs:52-55 is
ALREADY correct — Phase 17 does NOT re-emit this migration. Verify
during planning that no new partial index this phase adds contains a
function call.

### Pitfall 5: Rate-limiter fail-open hides abuse

**What goes wrong:** Hammer GenServer not running → `Sigra.RateLimiters.Hammer`
fails open (returns `{:allow, 0}` — see lib/sigra/rate_limiters/hammer.ex:37).
In production this silently disables the 20/day cap.

**How to avoid:** Fail-open is correct for Sigra's design (D-41 from
Phase 14 — never block legitimate traffic on rate-limiter infrastructure
failure), BUT the plan must include a startup-time assertion that when
Hammer is configured, the module is reachable. Add a telemetry event
(`[:sigra, :rate_limit, :fail_open]`) so host apps can alert on it in
production.

**Warning signs:** Production alert noise indicating fail-open events
on the invitation-create bucket.

### Pitfall 6: Rate limiter key collision across orgs

**What goes wrong:** Key is `"org_invite_create:#{user_id}"` without org
disambiguation in the per-user bucket. Admin of two orgs uses one bucket
across both — correct per D-09. But if a later refactor switches to
`"org_invite_create:#{org_id}:#{user_id}"` silently, per-user rate-limit
becomes per-(user,org) which is a DIFFERENT security policy.

**How to avoid:** Document the exact key format in `Sigra.Organizations.Invitations`
moduledoc with a test pinning the key literal.

### Pitfall 7: Email enumeration via invite creation

**What goes wrong:** Creating an invite for a user that already has an
account returns a different error ("already a member") than for a user
that doesn't ("invitation sent"), leaking membership status.

**How to avoid:** UI-SPEC §Error States already specifies `{email} is
already a member of this organization.` as an inline error. This is
NOT a leak in the invite-creation flow because the actor is ALREADY an
admin of the org — they can list members and see this info. Unlike
login/signup flows, the asymmetric error is acceptable here because
the actor is authorized to know. Document this in the `Invitations.create/2`
docstring so a future well-meaning refactor doesn't "fix" it.

### Pitfall 8: Forgetting to invalidate sessions on role change

**What goes wrong:** Admin re-invites pending invitee at a different
role (D-05 revoke+re-insert). The invitee hasn't accepted yet → no
active sessions → nothing to invalidate. Phase 17 has no session
concerns because membership doesn't exist yet. **Not a pitfall for this
phase** — force-logout on role change is Phase 16 concern (already
implemented for existing members).

## Code Examples

### Example 1: Extended `Sigra.Token` envelope helpers

```elixir
# lib/sigra/token.ex — ADD to existing module
# Source: CONTEXT.md D-01 + existing generate_hashed_token/0 pattern

@invite_purpose "sigra-org-invite-token"

@doc """
Generates a signed invitation envelope binding email into the HMAC payload.

Returns `{encoded_signed_token, hashed_token_for_storage}`.

## Why this diverges from `sigra-confirm-token`

Confirmation tokens sign the raw token only — the holder of the link IS
the user being confirmed, so identity is bound by convention at DB
compare time. Invitations are the exception: the holder of the link is
NOT yet the authenticated principal, so identity must be bound
cryptographically. This closes the Jetstream #907 / Keycloak CVE-2026-1529
class of invite-hijack bugs by construction.

Payload shape uses STRING keys (`"t"`, `"e"`) to avoid atom-table
growth on decode.
"""
@doc since: "0.4.0"
@spec generate_invite_envelope(String.t(), String.t()) :: {String.t(), binary()}
def generate_invite_envelope(secret_key_base, email)
    when is_binary(secret_key_base) and is_binary(email) do
  {raw, hashed} = generate_hashed_token()
  payload = %{"t" => raw, "e" => String.downcase(email)}
  signed = Plug.Crypto.sign(secret_key_base, @invite_purpose, payload)
  {Base.url_encode64(signed, padding: false), hashed}
end

@doc """
Verifies an invitation envelope and returns `{raw_token, bound_email, hashed_token}`.

Fails `{:error, :invalid}` if HMAC verify fails, base64 decode fails, or
the payload shape is wrong. Fails `{:error, :expired}` if the envelope
is older than `max_age_seconds`.
"""
@doc since: "0.4.0"
@spec verify_invite_envelope(String.t(), String.t(), pos_integer()) ::
        {:ok, %{raw_token: String.t(), bound_email: String.t(), hashed_token: binary()}}
        | {:error, :invalid | :expired}
def verify_invite_envelope(secret_key_base, encoded, max_age_seconds)
    when is_binary(secret_key_base) and is_binary(encoded) and is_integer(max_age_seconds) do
  with {:ok, signed} <- url_decode(encoded),
       {:ok, %{"t" => raw, "e" => email}} when is_binary(raw) and is_binary(email) <-
         Plug.Crypto.verify(secret_key_base, @invite_purpose, signed, max_age: max_age_seconds) do
    {:ok, %{raw_token: raw, bound_email: email, hashed_token: hash_token(raw)}}
  else
    {:ok, _other_shape} -> {:error, :invalid}
    {:error, :expired} -> {:error, :expired}
    _ -> {:error, :invalid}
  end
end

defp url_decode(encoded) do
  case Base.url_decode64(encoded, padding: false) do
    {:ok, bytes} -> {:ok, bytes}
    :error -> {:error, :invalid}
  end
end
```

### Example 2: `Sigra.Organizations.Invitations.create/2` skeleton

```elixir
# lib/sigra/organizations/invitations.ex — NEW
defmodule Sigra.Organizations.Invitations do
  @moduledoc """
  Invitation lifecycle: create, accept (signed-in match), accept_with_signup
  (anonymous), revoke, list_pending.

  All Multis owned here; generated LiveView is a thin event handler.
  """

  import Ecto.Query
  alias Ecto.Multi
  alias Sigra.{Token, Audit}

  @user_window_default {20, 24 * 60 * 60 * 1000}  # 20 per 24h
  @org_window_default {50, 24 * 60 * 60 * 1000}

  @spec create(map(), map()) ::
          {:ok, struct()}
          | {:error, :rate_limited_user | :rate_limited_org | :last_owner | Ecto.Changeset.t()}
  def create(config, attrs) do
    with :ok <- check_user_rate_limit(config, attrs.invited_by_id),
         :ok <- check_org_rate_limit(config, attrs.organization_id),
         {:ok, result} <- do_create(config, attrs) do
      # After-commit email delivery (D-12 planner discretion — recommended)
      deliver_invitation_email_async(config, result.invitation)
      {:ok, result.invitation}
    end
  end

  defp do_create(config, attrs) do
    ttl = config.invitation_ttl
    expires_at = DateTime.utc_now() |> DateTime.add(ttl, :millisecond)
    {encoded_token, hashed_token} =
      Token.generate_invite_envelope(config.secret_key_base, attrs.email)

    schema = config.schemas.invitation

    changeset =
      schema
      |> struct!()
      |> schema.changeset(Map.merge(attrs, %{
           hashed_token: hashed_token,
           expires_at: expires_at
         }))

    Multi.new()
    |> maybe_revoke_prior_pending(config, attrs)  # D-05 revoke-old-on-re-invite
    |> Multi.insert(:invitation, changeset)
    |> Multi.run(:attach_encoded_token, fn _repo, %{invitation: inv} ->
         # encoded token is ephemeral — never persisted, threaded through
         # changes map only so caller can deliver the email
         {:ok, Map.put(inv, :__encoded_token__, encoded_token)}
       end)
    |> Audit.log_multi_safe("organization.invitation.created", scope_for(attrs),
         metadata: %{email: attrs.email, role: to_string(attrs.role)})
    |> config.repo.transact()
    |> case do
         {:ok, changes} -> {:ok, changes}
         {:error, _step, reason, _} -> {:error, reason}
       end
  end

  defp check_user_rate_limit(config, user_id) do
    {limit, window_ms} = config.invitation_rate_limit_per_user
    key = "sigra:org_invite_create:user:#{user_id}"
    case config.rate_limiter.check_rate(key, limit, window_ms) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited_user}
    end
  end

  defp check_org_rate_limit(config, org_id) do
    {limit, window_ms} = config.invitation_rate_limit_per_org
    key = "sigra:org_invite_create:org:#{org_id}"
    case config.rate_limiter.check_rate(key, limit, window_ms) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited_org}
    end
  end

  # ... list_pending, accept, accept_with_signup, revoke below
end
```

### Example 3: `accept_with_signup/3` composed Multi

```elixir
@spec accept_with_signup(map(), String.t(), map()) ::
        {:ok, %{user: struct(), membership: struct(), invitation: struct()}}
        | {:error, :invalid | :expired | :revoked | :already_accepted | Ecto.Changeset.t()}
def accept_with_signup(config, signed_token, user_params) do
  with {:ok, envelope} <-
         Token.verify_invite_envelope(config.secret_key_base, signed_token, ttl_seconds(config)),
       {:ok, invitation} <- fetch_pending_by_hash(config, envelope.hashed_token),
       :ok <- assert_bound_email_matches(envelope.bound_email, invitation.email),
       :ok <- assert_signup_email_matches(user_params, invitation.email) do
    Multi.new()
    |> Multi.append(Sigra.Auth.register_user_multi(user_params, config_for_auth(config)))
    |> Multi.run(:confirm_user, fn repo, %{user: user} ->
         repo.update(
           Ecto.Changeset.change(user,
             confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
           )
         )
       end)
    |> Multi.append(
         Sigra.Organizations.add_member_multi(
           config,
           invitation.organization,
           {:changes_key, :confirm_user},
           invitation.role
         )
       )
    |> Multi.update(:accept_invitation, fn %{confirm_user: u} ->
         invitation_schema(config).accept_changeset(invitation, accepted_by_id: u.id)
       end)
    |> Audit.log_multi_safe("organization.invitation.accepted", Sigra.Scope.build(nil, nil),
         metadata: %{invitation_id: invitation.id})
    |> config.repo.transact()
    |> normalize_result()
  end
end
```

### Example 4: Generated email fragment `organization_invitation_email.ex`

```elixir
# priv/templates/sigra.install/core/organization_invitation_email.ex — NEW
# Fragment injected into generated Emails module, mirrors api_token_created_email.ex

  # -- Organization Invitation (Phase 17 D-12) --

  @doc "Builds the invitation email with HMAC-signed accept URL."
  def organization_invitation_email(invitation, org, inviter, accept_url) do
    inviter_display = inviter.name || inviter.email
    product = "<%= app_name %>"

    html_content = """
    <h1 style="margin: 0 0 16px 0; font-size: 24px; font-weight: 600; line-height: 1.2; color: #18181b; font-family: #{@font_family};">
      #{dgettext("sigra", "You're invited to join %{org}", org: html_escape(org.name))}
    </h1>
    <p style="margin: 0 0 16px 0; font-size: 16px; color: #3f3f46; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "%{inviter} invited you to join %{org} as %{role} on %{product}.",
        inviter: html_escape(inviter_display),
        org: html_escape(org.name),
        role: humanize_role(invitation.role),
        product: html_escape(product))}
    </p>
    <div style="margin: 24px 0; padding: 16px; background-color: #f4f4f5; border-radius: 8px;">
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Organization:")}</strong> #{html_escape(org.name)}
      </p>
      <p style="margin: 0 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Role:")}</strong> #{humanize_role(invitation.role)}
      </p>
      <p style="margin: 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
        <strong>#{dgettext("sigra", "Expires:")}</strong> #{Calendar.strftime(invitation.expires_at, "%B %d, %Y at %I:%M %p UTC")}
      </p>
    </div>
    #{cta_button(dgettext("sigra", "Accept invitation"), accept_url)}
    <p style="margin: 24px 0 8px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "Or copy and paste this link into your browser:")}
    </p>
    <p style="margin: 0 0 16px 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family}; word-break: break-all;">
      #{accept_url}
    </p>
    <p style="margin: 24px 0 0 0; font-size: 14px; color: #71717a; line-height: 1.5; font-family: #{@font_family};">
      #{dgettext("sigra", "If you weren't expecting this invitation, you can safely ignore this email. It will expire on %{date}.",
        date: Calendar.strftime(invitation.expires_at, "%B %d, %Y"))}
    </p>
    """

    text_content = """
    #{inviter_display} #{dgettext("sigra", "invited you to join")} #{org.name} #{dgettext("sigra", "as")} #{humanize_role(invitation.role)} #{dgettext("sigra", "on")} #{product}.

    #{dgettext("sigra", "Organization:")} #{org.name}
    #{dgettext("sigra", "Role:")} #{humanize_role(invitation.role)}
    #{dgettext("sigra", "Expires:")} #{Calendar.strftime(invitation.expires_at, "%B %d, %Y at %I:%M %p UTC")}

    #{dgettext("sigra", "Accept the invitation:")}
    #{accept_url}

    #{dgettext("sigra", "If you weren't expecting this invitation, you can safely ignore this email.")}
    #{dgettext("sigra", "It will expire on")} #{Calendar.strftime(invitation.expires_at, "%B %d, %Y")}.
    """

    base_email()
    |> to(invitation.email)
    |> subject(dgettext("sigra", "%{inviter} invited you to join %{org}",
         inviter: inviter_display, org: org.name))
    |> html_body(wrap_html(html_content))
    |> text_body(text_content)
  end

  defp humanize_role(role), do: role |> to_string() |> String.capitalize()
```

### Example 5: NimbleOptions schema extensions

```elixir
# lib/sigra/organizations.ex — ADD to @org_config_schema
invitation_ttl: [
  type: :pos_integer,
  default: :timer.hours(24 * 7),
  doc: """
  Lifetime of invitation tokens in milliseconds. Default 7 days. A dev-mode
  warning is logged on first use if configured > 30 days (phishing window).
  """
],
invitation_rate_limit_per_user: [
  type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
  default: {20, :timer.hours(24)},
  doc: """
  Per-user rate limit for invite creation as `{limit, window_ms}` or
  `:infinity` to disable. Default 20/day.
  """
],
invitation_rate_limit_per_org: [
  type: {:or, [{:tuple, [:pos_integer, :pos_integer]}, {:in, [:infinity]}]},
  default: {50, :timer.hours(24)},
  doc: """
  Per-organization rate limit for invite creation. Default 50/day.
  """
],
invitation_cleanup_retention_days: [
  type: :pos_integer,
  default: 30,
  doc: """
  Days to retain expired/accepted/revoked invitations past expires_at
  before the optional Oban cleanup worker hard-deletes them.
  """
],
emails_module: [
  type: {:or, [:atom, nil]},
  default: nil,
  doc: """
  Host app module containing the `organization_invitation_email/4` function.
  Required for Phase 17 invitation email delivery; nil disables email send
  (invitation row still commits, admin sees warning flash).
  """
]
```

### Example 6: Optional `Sigra.Workers.CleanupExpiredInvitations`

```elixir
# lib/sigra/workers/cleanup_expired_invitations.ex — NEW, optional
defmodule Sigra.Workers.CleanupExpiredInvitations do
  @moduledoc """
  Optional Oban worker that hard-deletes invitations more than
  `invitation_cleanup_retention_days` past their `expires_at`.

  Implements `Sigra.Workers` behaviour. No-op if Oban is not present in
  the host app — the module still compiles because `use Oban.Worker` is
  conditionally applied based on `Code.ensure_loaded?(Oban.Worker)`.
  """

  @behaviour Sigra.Workers

  if Code.ensure_loaded?(Oban.Worker) do
    use Oban.Worker, queue: :maintenance, max_attempts: 3
  end

  @impl Sigra.Workers
  def perform(_scope, args) do
    config = resolve_config(args)
    retention_days = config.invitation_cleanup_retention_days
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days, :day)

    from(i in config.schemas.invitation,
      where: i.expires_at < ^cutoff
    )
    |> config.repo.delete_all()
    |> then(fn {count, _} -> {:ok, %{deleted: count}} end)
  end
end
```

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `plug_crypto` | D-01 HMAC envelope | ✓ | transitive via Phoenix 1.8 | — |
| `ecto_sql` | D-07 Multi / Repo.transact | ✓ | ~> 3.13 (per mix.lock) | — |
| `hammer` | D-09 rate limiting | ✓ (optional dep) | ~> 7.3 | `Sigra.RateLimiters.Noop` bypasses (fail-open) |
| `swoosh` | D-12 email | ✓ | ~> 1.25 | — |
| `oban` | D-11 cleanup worker | Optional | ~> 2.17 | Worker is no-op if absent (CONTEXT D-11) |
| `nimble_options` | D-09/D-10/D-11 config | ✓ | ~> 1.1 | — |
| PostgreSQL 11+ | Partial index (D-03) | Assumed for primary adapter | — | MySQL branch is non-partial + Multi guard |
| Phoenix 1.8.5 `<.modal>`, `<.simple_form>`, `<.button>`, `<.flash>` | UI-SPEC all modals | ✓ | 1.8.5 | — |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** Hammer (Noop), Oban (no-op worker).

## Validation Architecture

> Enabled — `.planning/config.json` has `workflow.nyquist_validation: true`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir ~> 1.18 stdlib) + `Phoenix.LiveViewTest` |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/sigra/organizations/invitations_test.exs --max-failures 1` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INV-01 | Owner/admin invites a user by email with role | unit + live | `mix test test/sigra/organizations/invitations_test.exs::"create/2 inserts pending invitation"` | ❌ Wave 0 |
| INV-02 | HMAC token, SHA-256 hashed, never plaintext | unit | `mix test test/sigra/organizations/invitations_test.exs::"create/2 stores only hashed_token, raw in encoded URL"` | ❌ Wave 0 |
| INV-02 | Token envelope rejects tamper (email substitution) | unit | `mix test test/sigra/token_test.exs::"verify_invite_envelope rejects tampered email"` | ❌ Wave 0 |
| INV-03 | Email includes accept URL, org, inviter, expiry | unit (Swoosh Test adapter) | `mix test test/sigra/organizations/invitations_test.exs::"create/2 delivers organization_invitation_email after commit"` | ❌ Wave 0 |
| INV-04 | Default 7d expiry, NimbleOptions override works | unit | `mix test test/sigra/organizations/invitations_test.exs::"create/2 respects invitation_ttl config"` | ❌ Wave 0 |
| INV-04 | Dev warning > 30d TTL | unit | `mix test test/sigra/organizations_test.exs::"use Sigra.Organizations logs warning when invitation_ttl > 30 days"` | ❌ Wave 0 |
| INV-05 | Anonymous signup → Multi atomicity (user + confirm + membership + accept) | unit (Multi + DB) | `mix test test/sigra/organizations/invitations_test.exs::"accept_with_signup/3 commits user+membership+invitation atomically"` | ❌ Wave 0 |
| INV-05 | Signup branch rejects email mismatch (server-side) | unit | `mix test test/sigra/organizations/invitations_test.exs::"accept_with_signup/3 rejects when signup form posts different email"` | ❌ Wave 0 |
| INV-06 | **Jetstream #907 regression** — signed-in-as-different cannot accept | live | `mix test test/sigra_web/live/invitation_accept_live_test.exs::"mismatch branch has zero accept DOM"` | ❌ Wave 0 |
| INV-06 | Mismatch branch renders role="alert" warning card | live | same file, separate test | ❌ Wave 0 |
| INV-06 | Citext-insensitive match accepts (UPPERCASE@foo vs uppercase@foo) | unit | `mix test test/sigra/organizations/invitations_test.exs::"accept/3 treats email match as case-insensitive"` | ❌ Wave 0 |
| INV-07 | Accepted invitation cannot be replayed | unit | `mix test test/sigra/organizations/invitations_test.exs::"accept/3 rejects already-accepted invitation"` | ❌ Wave 0 |
| INV-07 | Accept writes `accepted_at` inside the Multi (rollback test) | unit | `mix test test/sigra/organizations/invitations_test.exs::"accept_with_signup/3 rolls back all changes if any step fails (Pow #534 regression)"` | ❌ Wave 0 |
| INV-08 | Revoke stamps `revoked_at`; subsequent accept returns `:revoked` | unit | `mix test test/sigra/organizations/invitations_test.exs::"revoke/3 marks revoked_at and blocks acceptance"` | ❌ Wave 0 |
| INV-08 | Revoke authorization — non-owner/admin rejected | unit | `mix test test/sigra/organizations/invitations_test.exs::"revoke/3 requires owner or admin role"` | ❌ Wave 0 |
| INV-09 | Per-user rate limit blocks 21st invite in 24h | unit (Mox rate limiter) | `mix test test/sigra/organizations/invitations_test.exs::"create/2 enforces 20/day per-user limit"` | ❌ Wave 0 |
| INV-09 | Per-org rate limit blocks 51st invite | unit | `mix test test/sigra/organizations/invitations_test.exs::"create/2 enforces 50/day per-org limit"` | ❌ Wave 0 |
| INV-09 | `:infinity` disables a layer | unit | `mix test test/sigra/organizations/invitations_test.exs::"create/2 honors :infinity to disable rate limit"` | ❌ Wave 0 |
| INV-10 | Pending list shows all 5 columns with correct labels | live | `mix test test/sigra_web/live/organization_members_live_test.exs::"pending invitations section renders email/role/invited-by/expires/revoke"` | ❌ Wave 0 |
| INV-10 | Revoke button transitions row (stream_delete) | live | `mix test test/sigra_web/live/organization_members_live_test.exs::"clicking revoke confirms modal and removes row"` | ❌ Wave 0 |
| D-03 | Partial-unique index rejects duplicate pending | unit (DB) | `mix test test/sigra/organizations/invitations_test.exs::"create/2 with duplicate pending email returns changeset error"` | ❌ Wave 0 |
| D-03 | Re-invite (D-05) revokes prior + inserts new in one Multi | unit | `mix test test/sigra/organizations/invitations_test.exs::"create/2 revokes pending duplicate and inserts new row"` | ❌ Wave 0 |
| D-11 | Cleanup worker is no-op without Oban | unit | `mix test test/sigra/workers/cleanup_expired_invitations_test.exs::"perform no-ops with :oban_disabled config"` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/organizations/invitations_test.exs test/sigra/token_test.exs test/sigra_web/live/invitation_accept_live_test.exs --max-failures 3` (< 30 s)
- **Per wave merge:** `mix test test/sigra test/sigra_web/live/organization_members_live_test.exs test/sigra_web/live/invitation_accept_live_test.exs`
- **Phase gate:** Full `mix test` green + `mix credo --strict` clean + `mix dialyzer` clean before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/sigra/organizations/invitations_test.exs` — new file covering INV-01..INV-10, D-03, D-05, D-07, D-09, D-11 assertions
- [ ] `test/sigra/token_test.exs` — extend (or create) with envelope generate/verify tamper tests
- [ ] `test/sigra_web/live/invitation_accept_live_test.exs` — new file covering all 7 render branches + Jetstream #907 regression
- [ ] `test/sigra_web/live/organization_members_live_test.exs` — extend Phase 16 test with invite modal + pending list + revoke modal flows
- [ ] `test/sigra/workers/cleanup_expired_invitations_test.exs` — new, optional-dep-aware
- [ ] `test/support/invitation_fixtures.ex` — `invitation_fixture/1`, `pending_invitation_for/2`, `accepted_invitation/1`, `revoked_invitation/1`
- [ ] Mox for `Sigra.RateLimiter` already exists (see lib/sigra/rate_limiter.ex:19); extend with invitation bucket fixtures

### Observability Hooks

- Telemetry: `[:sigra, :invitation, :create, :start | :stop | :exception]`,
  `[:sigra, :invitation, :accept, :start | :stop | :exception]`,
  `[:sigra, :invitation, :revoke, :start | :stop | :exception]`,
  `[:sigra, :invitation, :email_delivery_failed]` (for after-commit
  warning flash)
- Audit: `organization.invitation.created`, `organization.invitation.accepted`,
  `organization.invitation.revoked` (via existing `Sigra.Audit.log_multi_safe/3`)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Reuses `Sigra.Auth` for signup-branch; no new auth primitives |
| V3 Session Management | partial | Signup branch triggers session creation via existing `Sigra.Auth` pipeline |
| V4 Access Control | yes | `Invitations.create/2` and `revoke/3` require `scope.membership.role in [:owner, :admin]` — enforced in library, not just UI |
| V5 Input Validation | yes | Email validated via existing `Sigra.Auth.Email` format check; role must be member of `config.roles`; Ecto changeset handles the rest |
| V6 Cryptography | yes | `Plug.Crypto.sign/verify` + `:crypto.hash(:sha256, _)` + `:crypto.strong_rand_bytes/1` — no hand-rolled crypto |
| V9 Communications | yes | Accept URL must be absolute HTTPS; D-12 `accept_url` passed in by caller — planner should assert it starts with `https://` via changeset validation on the email template caller |

### Known Threat Patterns for Phase 17 Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invite hijack (Jetstream #907 / Keycloak CVE-2026-1529) | Spoofing + Elevation | D-01 email-bound HMAC + D-06 mismatch branch zero-accept DOM |
| Token replay (accept twice) | Tampering | `accepted_at IS NULL` guard inside the Multi; Pow #534 regression test |
| Orphan row on partial commit | Tampering (data integrity) | D-07 single `Repo.transact/2` + composed Multi |
| Mass invite spam | DoS / Repudiation | D-09 dual-key Hammer + Phase 15 audit trail |
| Timing attack on hashed_token lookup | Information Disclosure | `Sigra.Token.hash_token/1` + DB equality; no user-controlled string ops before DB touch |
| Email enumeration via distinct errors | Information Disclosure | Accept side: collapse `:invalid` branches to one generic error card (no leak). Create side: asymmetric error OK — actor is already an admin |
| Phishing via fake invite email | Spoofing | D-12 subject MUST include both inviter + org name; fallback URL visible in email body |
| Revoke authorization bypass | Elevation | `revoke/3` library function checks scope role; UI gates redundantly |
| `now()` in partial-unique predicate | Availability (migration crash) | D-03 IS-NULL-only predicate; Pitfall 4 in this doc |
| Mailer exception rolls back Multi | Availability | D-12 after-commit delivery; warning flash on failure |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Repo.transaction/2` | `Repo.transact/2` | Ecto 3.13 | Phase 17 uses `transact/2` throughout; `transaction/2` is deprecated |
| Invitation binds email by convention (phx.gen.auth confirmation style) | Invitation binds email cryptographically in HMAC payload | Jetstream #907 (2025) + Keycloak CVE-2026-1529 | D-01 |
| Atom-keyed signed payloads | String-keyed signed payloads | Elixir-specific atom-table concern | D-01 uses `"t"`/`"e"` |
| `Plug.Session` with in-process ETS | Database-backed `user_sessions` | v1.0 Sigra | Phase 17 doesn't touch sessions directly |
| Hammer 6.x with `count_hit_inc/3` | Hammer 7.x with `hit/3` | Hammer 7.0 (Mar 2025) | Already wrapped in `Sigra.RateLimiters.Hammer` |

**Deprecated/outdated:**

- `Repo.transaction/2` with function arg — deprecated in Ecto 3.13 in favor
  of `Repo.transact/2`. Phase 17 must use `transact/2`.
- `Ecto.Multi.run/3` with atom-only step keys inside composed Multis — use
  namespaced keys (e.g., `:accept_invitation` not `:accept`) to avoid
  collision across `Multi.append`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Sigra.Auth.register_user_multi/1` does NOT exist today and must be extracted from `Sigra.Auth.register/3` (lib/sigra/auth.ex:146). CONTEXT D-07 references it by name but the tree currently has only `register/3` which runs its own `repo.insert/1`. | Architecture §Pattern 1, Code Examples §3, Summary | HIGH — blocks D-07 composition. Planner must sequence the extraction in Wave 0 before Invitations module can depend on it. Verified via direct Grep of lib/sigra/auth.ex. |
| A2 | `Sigra.Organizations.add_member_multi/5` does NOT exist today and must be extracted from `add_member/5` (lib/sigra/organizations.ex:554-576) which currently runs its own `repo.transaction/1`. | Architecture §Pattern 1, Code Examples §3, Summary | HIGH — same as A1 but on the org side. Verified via direct Read of the function. Extraction is a ~10-line refactor: keep `add_member/5` as `add_member_multi/5 \|> config.repo.transact() \|> normalize_multi_result()`. |
| A3 | The existing `priv/templates/sigra.install/organizations/migration.exs` partial-unique index at lines 52-55 is already D-03-compliant (IS-NULL-only predicate), so Phase 17 does NOT need to re-emit or alter the migration. | Runtime State Inventory, Pitfalls §4 | LOW — verified by direct Read. If the planner discovers a drift, only the migration template needs a one-line edit. |
| A4 | The Phase 16 slug-alias migration at lines 75-78 of the same file ships `where: "expires_at > now()"` which is the Postgres IMMUTABLE pitfall STATE.md flags as pending follow-up. It is NOT yet fixed in the library template. | Summary (follow-up fold-in option) | MEDIUM — CONTEXT §Canonical Refs gives the planner explicit permission to fold this fix in as Plan 17-0X sidecar. Verified by Grep. |
| A5 | `hashed_token` column uses a non-unique index (`create index(:organization_invitations, [:hashed_token])` at migration line 57). | Architecture §Pattern 5 | LOW — recommendation is to make it unique. Change is zero-cost and adds defense-in-depth against a hypothetical token-generation bug. |
| A6 | `generated` `Sigra.Organizations` config currently does NOT have an `emails_module` key. It will need to be added alongside the other new NimbleOptions keys. | Code Examples §5 | LOW — Read of `@org_config_schema` confirms only `audit_schema` is configurable; other email integrations in v1.0 use a different config path. Planner must decide: reuse Sigra top-level `emails_module` if one exists, or add a new per-context key. |
| A7 | The Bytepack reference app uses HMAC-envelope binding for its invite flow. | Architecture §Pattern 2 | LOW — cited in CONTEXT.md discussion log as prior art; not re-verified in this session. The pattern is correct on its own security merits regardless of Bytepack. |
| A8 | `Sigra.Auth` has an email-format validation primitive reusable for the invitation-email changeset validation. | Security Domain §V5 | LOW — inferred from the `Sigra.Auth.Email` module name seen in the tree (not read directly). Planner should verify and either reuse or add a regex-level check to the invitation changeset. |

**Planner action required:** Confirm A1 + A2 + A6 before writing Wave 0.
These are the decisions most likely to reshape the task breakdown.

## Open Questions

1. **Should `hashed_token` be unique?**
   - What we know: Migration currently has non-unique index on
     `hashed_token` (line 57). SHA-256 collisions are cryptographically
     infeasible.
   - What's unclear: Whether there's a historical reason the library
     chose non-unique (e.g., to allow resend-same-token semantics deferred
     from CONTEXT §deferred).
   - Recommendation: Make it unique. If the library later adds
     resend-same-token, it becomes the natural invariant that each token
     belongs to exactly one invitation row. Cost: one-line migration
     change. If it proves wrong, the planner can revert before Wave 0
     merges.

2. **Where does `secret_key_base` come from inside `Sigra.Organizations.Invitations.create/2`?**
   - What we know: `Sigra.Token.generate/4` takes it as first argument;
     other call sites pass it in via `opts` (see lib/sigra/auth.ex:578).
   - What's unclear: Whether the Organizations config struct should
     carry `secret_key_base` directly or the caller should fetch it
     from endpoint config at each call.
   - Recommendation: Add `secret_key_base` as a required NimbleOptions
     key on `@org_config_schema` (matching how `Sigra.Auth` wires it).
     Generated `use Sigra.Organizations` wrapper reads it from
     `Application.fetch_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]`
     at compile time.

3. **Should the Oban cleanup worker implement `Sigra.Workers` behaviour
   or be a simpler `Sigra.Workers.AuditCleanup`-style tenant-agnostic worker?**
   - What we know: `Sigra.Workers` behaviour docstring (lib/sigra/workers.ex:22-27)
     says "`Sigra.Workers.AuditCleanup`, `TokenCleanup`, and `EmailDelivery`
     are genuinely tenant-agnostic and deliberately do NOT implement this
     behaviour."
   - What's unclear: Invitation cleanup hard-deletes rows that carry
     `organization_id`. If the cleanup run emits an audit, that audit has
     tenant context and DOES need `Sigra.Workers`.
   - Recommendation: Implement `Sigra.Workers`. The cleanup run emits
     one `organization.invitation.expired_pruned` audit per batch (or
     one per row) with `organization_id` populated. This earns the
     behaviour overhead.

4. **Does the planner fold the Phase 16 slug-alias migration fix into Phase 17?**
   - What we know: STATE.md flags it as pending follow-up; CONTEXT §Canonical
     Refs gives explicit permission to include it as a sidecar; it is the
     same bug class as D-03 (`now()` in IMMUTABLE context).
   - Recommendation: Fold in as Plan 17-0X sidecar. The fix is
     mechanical (drop `where: "expires_at > now()"` from the old-slug
     partial index; enforce expiry via query filter). Same reasoning as
     Phase 17 main path. Cost: one small plan, one small test, one
     migration template edit. Leaving it for later means a future host
     will trip the same Postgres error.

5. **Invitee-side decline action — include or defer?**
   - What we know: UI-SPEC §Pending Invitations List for
     `OrganizationsLive.Index` says "DEFERRED per CONTEXT deferred ideas".
   - Recommendation: Defer. Adds invitee-side UX decisions (does it
     email the inviter? does it emit an audit? does it free the
     partial-unique invariant slot?) that are not worth the scope.

6. **`:require_active_organization` router macro.**
   - What we know: Phase 16 D-23 deferred it to Phase 17 or 18; CONTEXT
     marks it as Claude discretion.
   - Recommendation: Defer to Phase 18. The accept LV at
     `/invitations/:token/accept` is UNscoped by design — it must NOT
     sit under a "require active org" pipeline. There is no Phase 17
     route that would benefit from the macro.

## Sources

### Primary (HIGH confidence — direct tree reads)

- `lib/sigra/token.ex` — full module read; confirmed `generate_hashed_token/0`,
  `hash_token/1`, `generate/4`, `verify/4`, `secure_compare/2`
- `lib/sigra/organizations.ex` — `@org_config_schema` (lines 38-103), `use`
  macro (lines 133-180), `add_member/5` (lines 554-576), `list_pending_invitations_for_user/2`
  stub (lines 724-734)
- `lib/sigra/auth.ex` — `register/3` (lines 146-203); confirmed no Multi
  seam currently exists; `generate_confirmation_token/3` (line 577) as
  the base64 envelope precedent
- `lib/sigra/rate_limiters/hammer.ex` — `check_rate/3` signature with
  string key; fail-open semantics
- `lib/sigra/workers.ex` — `Sigra.Workers` behaviour (lines 37-39); docstring
  noting tenant-agnostic workers do NOT implement it
- `lib/sigra/rate_limiter.ex` — behaviour callback shape
- `priv/templates/sigra.install/organizations/migration.exs` (lines 36-57,
  75-78, 117-133) — partial-unique index already correct at lines 52-55,
  slug-alias IMMUTABLE pitfall at lines 75-78
- `priv/templates/sigra.install/organizations/organization_invitation.ex` —
  existing schema with `hashed_token`, `email :string` (application-level,
  with citext at DB level), role enum, pending-index unique constraint
- `priv/templates/sigra.install/organizations/live/organization_members_live.ex` —
  the stub section at line 256 and disabled button at line 205 (Phase 16 seam)
- `priv/templates/sigra.install/core/api_token_created_email.ex` — exact
  fragment template precedent for D-12
- `priv/templates/sigra.install/core/emails.ex` — confirmed fragment
  injection pattern (functions added inline to module body)
- `.planning/phases/17-invitation-flow-email/17-CONTEXT.md` — locked
  decisions D-01 through D-14
- `.planning/phases/17-invitation-flow-email/17-UI-SPEC.md` — visual +
  structural contract
- `.planning/phases/17-invitation-flow-email/17-DISCUSSION-LOG.md` —
  alternatives considered
- `.planning/REQUIREMENTS.md` — INV-01 through INV-10 literal text
- `.planning/STATE.md` — Phase 16 follow-up notes (slug-alias migration)
- `.planning/ROADMAP.md` — Phase 17 goal, success criteria

### Secondary (MEDIUM confidence — external/cited)

- Ecto 3.13 `Repo.transact/2` — [CITED: hexdocs.pm/ecto/Ecto.Repo.html]
- `Ecto.Multi.append/2` — [CITED: hexdocs.pm/ecto/Ecto.Multi.html#append/2]
- Plug.Crypto `sign/4` / `verify/4` term serialization with Erlang term
  format — [CITED: hexdocs.pm/plug_crypto/Plug.Crypto.html]
- Hammer 7.x `hit/3` parameter order (`hit(key, scale_ms, limit)`) —
  [VERIFIED: lib/sigra/rate_limiters/hammer.ex:33]
- Swoosh Test adapter assertion API — [CITED: hexdocs.pm/swoosh/Swoosh.TestAssertions.html]

### Tertiary (LOW confidence — CONTEXT/discussion-log inherited)

- Dashbit Bytepack HMAC envelope precedent — [ASSUMED: cited in 17-DISCUSSION-LOG.md]
- Jetstream #907 / Keycloak CVE-2026-1529 bug class characterization —
  [ASSUMED: cited in CONTEXT.md, not re-verified this session]
- Pow #534 orphan-row bug — [ASSUMED: cited in CONTEXT.md]
- GitHub / Slack / Linear / Notion / Vercel UX precedent for single-route
  invite accept — [ASSUMED: cited in discussion log]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — every dependency is already vendored and verified
  in the tree
- Architecture: HIGH on library seams (direct Reads of auth.ex,
  organizations.ex, token.ex); MEDIUM on the Multi-builder extractions
  because the current `register/3` and `add_member/5` run their own
  transactions and must be refactored (A1, A2)
- Pitfalls: HIGH — five of the seven pitfalls have literal regression tests
  specified; the other two (rate-limit fail-open, key collision) are
  operational notes with clear avoidance
- Email template shape: HIGH — `api_token_created_email.ex` is a direct
  fragment precedent that Phase 17 mirrors line-for-line

**Research date:** 2026-04-13
**Valid until:** 2026-05-13 (30 days — stable stack, no fast-moving deps;
shortest window is Hammer 7.3 which is Mar 2026 stable)

---

## RESEARCH COMPLETE

**Phase:** 17 - invitation-flow-email
**Confidence:** HIGH

### Key Findings

- **Two Multi-builder extractions are the critical path.** `Sigra.Auth.register/3`
  and `Sigra.Organizations.add_member/5` both run their own transactions
  today. CONTEXT D-07 presumes composable Multi builders exist. Wave 0
  must extract `register_user_multi/1` and `add_member_multi/5`; this
  unblocks every later wave.
- **The invitation migration is already D-03-compliant** (partial-unique
  `IS NULL` predicate at priv/templates/sigra.install/organizations/migration.exs:52-55).
  Phase 17 does NOT modify this migration — it's already correct.
- **The Phase 16 slug-alias migration at lines 75-78 still has the Postgres
  IMMUTABLE pitfall** (`where: "expires_at > now()"`). Folding this fix
  into Phase 17 as a sidecar is recommended (CONTEXT §Canonical Refs grants
  explicit permission).
- **Email template is a fragment-file injection pattern**, not a standalone
  module. `api_token_created_email.ex` is the direct precedent —
  `organization_invitation_email.ex` mirrors its shape line-for-line and
  gets merged into the generated `emails.ex`.
- **`hashed_token` column is currently non-unique** (migration line 57).
  Recommend making it unique for zero cost and load-bearing invariant.
- **Rate-limiter key format is `"sigra:org_invite_create:user:#{id}"`**
  (string-keyed, not tuple-keyed), matching the existing
  `lib/sigra/auth.ex:747` and `:1477` call-site conventions. Tuple
  notation in CONTEXT.md is conceptual — the wire format is a string.
- **The mismatch branch structural invariant is a checker grep-target.**
  UI-SPEC §Structural Checker Invariants #1 and the research regression
  test both assert zero `phx-click="accept*"` or `phx-submit="accept*"`
  strings appear inside the `:mismatch` branch of
  `invitation_accept_live.ex`.

### File Created

`.planning/phases/17-invitation-flow-email/17-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard stack | HIGH | All deps already in-tree and verified |
| Architecture (library seams) | HIGH | Direct reads of auth.ex, organizations.ex, token.ex, rate_limiters |
| Architecture (Multi composition) | MEDIUM | Depends on the two extractions in A1/A2 — mechanically straightforward but requires refactor |
| Pitfalls | HIGH | Literal regression tests specified for 5 of 7; 2 are operational notes |
| UI integration | HIGH | UI-SPEC locks every surface + structural invariants |
| Email template shape | HIGH | Direct precedent in `api_token_created_email.ex` |
| Rate limiter wiring | HIGH | Noop fallback exists; Hammer wrapper contract verified in tree |
| Cleanup worker (D-11) | MEDIUM | `Sigra.Workers` behaviour fit is a judgment call (Open Question #3) |

### Open Questions

See §Open Questions above — 6 items. Highest priority for planner: Q1
(hashed_token uniqueness), Q2 (secret_key_base config plumbing), Q3
(Workers behaviour fit), Q4 (slug-alias fold-in decision).

### Ready for Planning

Research complete. Planner can now create plan files. Recommended wave
sequencing:

- **Wave 0 (foundations, must land first):** Multi-builder extractions (A1, A2),
  `Sigra.Token` envelope helpers, `@org_config_schema` extensions,
  `Sigra.Organizations.Invitations` module skeleton, invitation fixtures,
  test file scaffolds
- **Wave 1 (create + revoke + list):** `create/2` + `revoke/3` +
  `list_pending/2` + `list_pending_for_user/2`, rate-limit integration,
  email fragment, OrganizationMembersLive stub fill
- **Wave 2 (accept flows):** `accept/3` + `accept_with_signup/3`,
  `InvitationAcceptLive` with 7 branches, OrganizationsLive.Index branch fill
- **Wave 3 (regression + polish):** Jetstream #907 + Pow #534 regression
  tests, optional `CleanupExpiredInvitations` worker, optional slug-alias
  migration fold-in
- **Wave 4 (integration + gate):** Phase 17 VALIDATION.md sign-off,
  end-to-end test through the example app harness, human UI checkpoint
  per UI-SPEC checker invariants
