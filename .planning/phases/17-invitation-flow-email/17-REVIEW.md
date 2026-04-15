---
phase: 17-invitation-flow-email
reviewed: 2026-04-14T00:00:00Z
depth: standard
files_reviewed: 30
files_reviewed_list:
  - config/test.exs
  - lib/sigra/auth.ex
  - lib/sigra/install/features/organizations.ex
  - lib/sigra/organizations.ex
  - lib/sigra/organizations/invitations.ex
  - lib/sigra/token.ex
  - lib/sigra/workers/cleanup_expired_invitations.ex
  - priv/templates/sigra.install/core/emails.ex
  - priv/templates/sigra.install/core/organization_invitation_email.ex
  - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - priv/templates/sigra.install/organizations/migration.exs
  - priv/templates/sigra.install/organizations/organization_invitation.ex
  - priv/templates/sigra.install/organizations/router_injection.ex
  - test/example/lib/example/accounts/emails.ex
  - test/example/lib/example/accounts/organization_invitation.ex
  - test/example/lib/example/organizations.ex
  - test/example/lib/example_web/live/invitation_accept_live.ex
  - test/example/lib/example_web/live/organization_members_live.ex
  - test/example/lib/example_web/router.ex
  - test/example/mix.exs
  - test/example/priv/repo/migrations/20260414000000_add_revoked_by_id_to_organization_invitations.exs
  - test/example/test/example_web/emails/organization_invitation_email_test.exs
  - test/example/test/example_web/live/invitation_accept_live_test.exs
  - test/example/test/example_web/live/organization_members_live_test.exs
  - test/sigra/auth_test.exs
  - test/sigra/install/features/organizations_test.exs
  - test/sigra/organizations/config_test.exs
  - test/sigra/organizations/context_test.exs
  - test/sigra/organizations/invitations_test.exs
  - test/sigra/token_test.exs
  - test/sigra/workers/cleanup_expired_invitations_test.exs
  - test/support/fixtures/invitations_fixtures.ex
  - test/support/fixtures/organizations_fixtures.ex
  - test/support/mock_repo_behaviour.ex
findings:
  critical: 1
  warning: 5
  info: 4
  total: 10
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-04-14
**Depth:** standard
**Files Reviewed:** 35 (all listed files)
**Status:** issues_found

## Summary

Phase 17 ships a solid invitation flow with strong security foundations: the HMAC invitation envelope (`Sigra.Token.generate_invite_envelope/2`) correctly binds email to the token payload and prevents the Jetstream #907 / CVE-2026-1529 hijack class by construction; the `InvitationAcceptLive` render branching is disciplined (the `:mismatch` branch renders zero accept controls and event handlers have explicit raising fallbacks); `accept_with_signup/3` composes a single `Ecto.Multi` with server-side email lock-down; and rate limiting is dual-keyed per-user and per-org with configurable fail-open semantics.

However, review surfaced **one critical cross-tenant IDOR** in `Sigra.Organizations.Invitations.revoke/3`, plus a handful of correctness and code-quality warnings around scope enforcement, pagination ceilings, and dead error branches. The critical finding (CR-01) is reachable today from the generated members LiveView and should block the phase VERIFY.

## Critical Issues

### CR-01: `Invitations.revoke/3` is missing an organization-scope check (cross-tenant IDOR)

**File:** `lib/sigra/organizations/invitations.ex:663-677`
**Issue:**
`revoke/3` authorizes the actor purely by matching `%{membership: %{role: role}} when role in @auth_roles` against `actor_scope`, then looks the invitation up by primary key alone:

```elixir
def revoke(config, invitation_id, %{membership: %{role: role}} = actor_scope)
    when role in @auth_roles do
  schema = config.schemas.invitation

  case config.repo.get(schema, invitation_id) do
    nil -> {:error, :not_found}
    %{accepted_at: nil, revoked_at: nil} = inv ->
      do_revoke(config, inv, actor_scope)
    ...
```

There is no assertion that `inv.organization_id == actor_scope.active_organization.id`. An admin of Organization A who learns (or guesses — binary UUIDs mitigate guessing, but integer IDs are routinely exposed in URLs and logs) an `invitation_id` belonging to Organization B can call `Organizations.revoke_invitation(other_org_invitation_id, my_scope)` and silently revoke B's pending invite. The generated `OrganizationMembersLive.handle_event("confirm_revoke", %{"id" => id}, ...)` (`priv/templates/sigra.install/organizations/live/organization_members_live.ex:273`) passes the client-supplied `id` straight through, and `find_pending_invitation/2` is only consulted by the `open_revoke_modal` path — the `confirm_revoke` path does not re-validate the id against the current org's pending list.

The audit row emitted by `do_revoke/3` would be tagged with the attacker's org via `actor_scope`, making this class of abuse hard to trace in post-incident review.

**Fix:**
Add an organization-scope assertion inside `revoke/3` before `do_revoke/3` runs. Either derive the expected org id from `actor_scope.active_organization.id` and compare, or scope the `repo.get` itself with a where-clause. Preferred: tighten the query and collapse the mismatch onto the existing `:not_found` error to avoid leaking existence across tenants.

```elixir
def revoke(config, invitation_id, %{membership: %{role: role}, active_organization: %{id: org_id}} = actor_scope)
    when role in @auth_roles do
  schema = config.schemas.invitation

  query =
    from i in schema,
      where: i.id == ^invitation_id and i.organization_id == ^org_id

  case config.repo.one(query) do
    nil ->
      {:error, :not_found}

    %{accepted_at: nil, revoked_at: nil} = inv ->
      do_revoke(config, inv, actor_scope)

    _inv ->
      {:error, :not_pending}
  end
end
```

Add a regression test in `test/sigra/organizations/invitations_test.exs` that creates an invitation in Org B, then calls `revoke/3` with an admin scope for Org A, and asserts `{:error, :not_found}` (the row in Org B must remain `accepted_at: nil, revoked_at: nil`).

## Warnings

### WR-01: `OrganizationMembersLive.find_streamed_member/2` has a hard-coded 1,000-row ceiling

**File:** `priv/templates/sigra.install/organizations/live/organization_members_live.ex:617-628`
**Issue:**
`find_streamed_member/2` refetches the membership list with `limit: 1_000, offset: 0` and linear-searches by stringified id. For organizations with more than 1,000 members, the `:role_modal` and `:remove_modal` open handlers silently return `{:noreply, socket}` without any user-visible error — admins cannot change roles or remove anyone past the first 1,000 rows, and there is no indication why. The paginator `load_more` handler above can stream members in beyond the first 1,000, so the stream can contain rows that this helper cannot locate.

**Fix:**
Look up the membership directly by id and scope it to `scope.active_organization.id`, then decorate the single row. This is both correct and O(1) on the DB side:

```elixir
defp find_streamed_member(socket, id) do
  scope = socket.assigns.current_scope
  Organizations.get_membership_for_active_org!(scope, id)
  |> decorate_single_row()
rescue
  Ecto.NoResultsError -> nil
end
```

If adding a new context function is out of scope for Phase 17, at minimum raise the 1,000-row limit to something like 10,000 and add a `Logger.warning/1` when the stream overflows so the pagination ceiling is observable.

The same pattern applies to `find_pending_invitation/2` (line 641-647), which also reloads the full pending list per click.

### WR-02: `accept_with_signup` redirects to `/users/log_in` after creating and auto-confirming a user

**File:** `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:165-170` (and `test/example/lib/example_web/live/invitation_accept_live.ex:164-170`)
**Issue:**
The signup path atomically creates the user, confirms them, inserts membership, and stamps the invitation. On success the LV redirects to `~p"/users/log_in"`, forcing the freshly registered invitee to immediately type the password they just set. This is a significant DX regression compared to the sign-in-then-accept happy path (which redirects into the org). It also risks confusing users who just submitted a form and wonder why their signup didn't "take."

**Fix:**
Either (a) auto-sign-in the new user by posting to the session controller and redirect to `~p"/organizations/#{org.slug}/members"`, or (b) if auto-sign-in is intentionally out of scope, put a clear flash explaining the next step ("Account created — please sign in to continue to #{org.name}"). The plan context should be checked to confirm which path was intended — the current behavior looks like a placeholder.

### WR-03: `verify_and_load/2` has dead error branches for `:revoked` and `:already_accepted`

**File:** `lib/sigra/organizations/invitations.ex:484-503`
**Issue:**
The `else` clause in `verify_and_load/2` lists:

```elixir
{:error, :revoked} -> {:error, :revoked}
{:error, :already_accepted} -> {:error, :already_accepted}
```

but these tuples only originate from `assert_pending_state/1`, which is already inside the `with` chain and whose returns pass through the `else` unchanged. These are reachable — not dead. However, `Token.verify_invite_envelope/3` cannot return `:revoked` or `:already_accepted`; the corresponding comment block in `accept/3`'s docstring lists `:revoked` and `:already_accepted` as top-level returns from `accept/3` which is correct. This is cosmetic but the `@spec` on `verify_and_load/2` (line 481-483) omits `:email_mismatch` even though `{:error, :email_mismatch}` is an internal possibility from `assert_bound_email/2` — it is then collapsed to `:invalid`, so the spec is technically accurate for external observers, but the internal mismatch is not spelled out anywhere.

**Fix:**
Add a short comment in the `else` block pointing out which error originates from which step, and update the `@spec` to mention that bound-email mismatches are deliberately collapsed to `:invalid` (there is already a comment to that effect, but the spec doesn't reflect it). Low priority, no functional bug.

### WR-04: `run_accept_with_signup_multi` calls `register_user_multi` which inserts with step key `:user`, overlapping with the audit actor scope

**File:** `lib/sigra/organizations/invitations.ex:595-649`
**Issue:**
The multi composition is:

```
register_user_multi (:user)
  |> :confirm_user
  |> add_member_multi (:add_member_resolve_user, :membership, audit step)
  |> :accept_invitation
  |> audit step
```

`signup_scope` is pre-built as `%{user: nil, ...}` and threaded into both `add_member_multi` and `append_audit`. `add_member_multi` handles the `{:changes_key, :confirm_user}` reference correctly. But the audit steps emitted by `append_audit` derive `actor_id` from `scope.user.id` via `get_in_scope/3`, which sees `nil` — meaning the "organization.member_add" and "organization.invitation.accepted" audit rows for the signup path record `actor_id: nil` (system action) even though the user was created and confirmed in the same transaction and their id is available as `%{confirm_user: user}`.

For a signed-up invitee accepting their own invite, the audit trail should record `actor_id = new_user.id`, not `nil`. This is a minor forensic regression, not a correctness bug.

**Fix:**
Either (a) rewrite `append_audit/5` to accept a lazy `actor_id_fn` that resolves from multi changes, or (b) emit an additional audit step after `:confirm_user` lands, passing `%{user: user}` explicitly. The plan may have intentionally deferred this to Phase 17 follow-up — if so, add an `Info` TODO in the module.

### WR-05: `deliver_invitation_email_async/2` swallows `config.repo.get!/2` crashes as "email delivery failed"

**File:** `lib/sigra/organizations/invitations.ex:216-242`
**Issue:**
The function calls `config.repo.get!(config.schemas.organization, inv.organization_id)` and `config.repo.get!(config.schemas.user, inv.invited_by_id)` before invoking the emails module. These are `get!` calls that raise `Ecto.NoResultsError` if the referenced row was concurrently deleted (edge case, but not impossible — invitation row committed, then org soft-deleted before the async email assembles). The `rescue e ->` clause at line 231 catches these as generic "invitation email delivery failed" and emits `:email_delivery_failed` telemetry. Operationally, a missing-org or missing-inviter crash is NOT an email delivery failure — it's a data integrity signal that the caller should see.

**Fix:**
Either (a) narrow the `rescue` to the specific exceptions the mailer module is expected to raise (e.g., `Swoosh.DeliveryError`, `Mailgun.Error`, etc.), or (b) short-circuit on missing org/inviter before the rescue scope with a dedicated `:email_skipped` telemetry event and a clearer log message. Option (b) is simpler:

```elixir
with {:ok, org} <- fetch_org_for_email(config, inv.organization_id),
     {:ok, inviter} <- fetch_inviter_for_email(config, inv.invited_by_id) do
  try do
    apply(config.emails_module, :organization_invitation, [inv, org, inviter, accept_url])
    emit(:email_sent, inv)
  rescue
    e -> emit(:email_delivery_failed, inv, e)
  end
else
  :not_found -> emit(:email_skipped, inv, :missing_references)
end
```

## Info

### IN-01: `list_pending/2` has no pagination

**File:** `lib/sigra/organizations/invitations.ex:712-728`
**Issue:**
`list_pending/2` returns every pending invitation for an organization via `repo.all`. For very high-volume SaaS orgs with hundreds of outstanding invites, this is unbounded. The generated members LiveView re-uses this result as the backing for the pending-invitations stream, which is fine at small scale but would benefit from a `limit:` option.

**Fix:**
Add an optional 3rd argument `opts \\ []` and honor `:limit` / `:offset`. Default limit of 100 mirrors the members table pagination ceiling already used in `OrganizationMembersLive`. Non-blocking for Phase 17.

### IN-02: `CleanupExpiredInvitations` docstring says "only deletes `accepted_at IS NULL`" but deletes revoked expired rows

**File:** `lib/sigra/workers/cleanup_expired_invitations.ex:8-12,118-128`
**Issue:**
The moduledoc says "Only deletes `accepted_at IS NULL` rows. Accepted invitations are preserved indefinitely." That is correct — but revoked (still `accepted_at IS NULL`) expired invitations are ALSO deleted by the query at line 125. The docstring does not mention revoked rows. If the intent was to preserve revoked invitations for forensics (mirroring the accepted-row preservation rationale), the query is wrong. If the intent was to cascade-delete both, the docstring should say so explicitly.

**Fix:**
Clarify the docstring to explicitly state that revoked+expired rows are also hard-deleted, OR add `and is_nil(i.revoked_at)` to the where-clause if revoked rows should be retained for forensics. The decision belongs to the plan author, not the reviewer — flagging only.

### IN-03: `assign_signup_email_matches/2` accepts both `"email"` and `:email` keys, but `run_accept_with_signup_multi` only checks `"email"` after stringification

**File:** `lib/sigra/organizations/invitations.ex:534-543,600-604`
**Issue:**
`assert_signup_email_matches/2` (line 534) is defensive about atom-vs-string keys, but `run_accept_with_signup_multi/4` later does:

```elixir
params_with_locked_email =
  user_params
  |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  |> Map.put("email", invitation.email)
```

which already normalizes all keys to strings and then forces `"email"`. The defensive fallback in `assert_signup_email_matches/2` is therefore only exercised by the initial guard, not the force-overwrite. This is correct but suggests the guard could be simplified to string-only. Low priority.

**Fix:**
Either simplify `assert_signup_email_matches/2` to only check the string key, or document why both are accepted (e.g., if some callers pre-normalize keys).

### IN-04: `Invitations.create/2` has asymmetric error exposure documented as acceptable, but no test enforces it

**File:** `lib/sigra/organizations/invitations.ex:34-39`
**Issue:**
The moduledoc states that `create/2` returns `:already_member` for existing-member emails and `{:ok, _}` for non-existent accounts, and argues this is acceptable because the admin already has membership visibility. That reasoning is sound. However, there is no dedicated test enforcing that `{:error, :already_member}` is distinct from the `{:ok, _}` anonymous path — if a future refactor collapses both to `{:ok, _}` (or leaks a different error), the invariant would regress silently.

**Fix:**
Add a test in `test/sigra/organizations/invitations_test.exs` that explicitly asserts both return shapes, with a comment pointing back to Pitfall 7 in the moduledoc.

---

_Reviewed: 2026-04-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
