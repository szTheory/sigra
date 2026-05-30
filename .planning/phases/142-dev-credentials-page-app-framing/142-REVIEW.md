---
phase: 142-dev-credentials-page-app-framing
reviewed: 2026-05-30T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - test/example/lib/example_web/live/demo/credentials_live.ex
  - test/example/lib/example/demo/personas.ex
  - test/example/lib/example_web/router.ex
  - test/example/lib/example_web/components/layouts/root.html.heex
  - test/example/lib/example_web/components/layouts.ex
  - test/example/test/example_web/live/demo/credentials_live_test.exs
  - test/example/lib/example/demo/seeds.ex
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 142: Code Review Report

**Reviewed:** 2026-05-30T00:00:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Seven files reviewed covering the demo credentials LiveView, persona data module, router, layouts, and seeds orchestrator. No critical security vulnerabilities or data-loss bugs found. The compile-env gate correctly excludes `/demo/credentials` from test and prod builds. Three warnings surfaced: the test bypasses the LiveView mount lifecycle in a way that leaves mount logic untested; the `carol` persona has incorrect `org_member: nil` metadata that contradicts actual seeded state; and the `upsert_organization` helper uses a check-then-insert pattern without a conflict-safe fallback, leaving a narrow crash window on concurrent re-seeds. Four info items cover naming and documentation accuracy.

## Warnings

### WR-01: Test bypasses LiveView mount — mount logic is untested

**File:** `test/example/test/example_web/live/demo/credentials_live_test.exs:23-29`

**Issue:** The "rendered HTML contract" test calls `CredentialsLive.render/1` directly with a hand-crafted map, manually replicating the credential-building logic from `mount/3` (lines 17-22 duplicate lines from `credentials_live.ex` lines 18-22). This has two consequences: (1) any bug introduced into `mount/3` — wrong `Personas.all()` call, wrong field merging, wrong assign key — will never be caught by this test; (2) the test stays green even if mount crashes. The `async: false` marker also suggests intent to do something stateful, but the test never actually mounts the LiveView.

**Fix:** Replace the direct `render/1` call with a proper LiveView mount using `Phoenix.LiveViewTest.live/2`. Because the route is compiled out in test env, use an isolated test that bypasses the router and connects directly to the LiveView:

```elixir
import Phoenix.LiveViewTest

test "contains required testids and branding" do
  {:ok, view, html} = live_isolated(build_conn(), ExampleWeb.Demo.CredentialsLive)
  assert html =~ ~s(data-testid="demo-credentials-table")
  assert html =~ ~s(data-testid="demo-persona-row-admin")
  # ... remaining assertions ...
  assert render(view) =~ "Vaultr"
end
```

This exercises `mount/3` and exercises the real credential-building path, not a duplicated copy of it.

---

### WR-02: `carol` persona `org_member` field contradicts seeded state

**File:** `test/example/lib/example/demo/personas.ex:88-89`

**Issue:** The `carol` persona declares `org_owner: nil, org_member: nil`. However, `seeds.ex` line 215 unconditionally inserts Carol as an `:member` of Acme Corp. The `org_member`/`org_owner` fields in `Personas.all()` are documented as the "single source of truth" consumed by both the seed orchestrator and the credentials LiveView, yet `seed_memberships/3` never reads these fields — it hardcodes membership logic independently. The result is that Carol's persona metadata is wrong (states no org membership, but she is an Acme member in the actual seeded DB). If any future consumer reads `persona.org_member` to determine Carol's membership, it will get the wrong answer.

**Fix:** Either correct the persona map to reflect actual seeded state:

```elixir
# personas.ex, carol entry
org_owner: nil,
org_member: :acme   # Carol is seeded as Acme Corp member (see Seeds.seed_memberships/3)
```

Or, if these fields are intended to drive `seed_memberships/3` (making `Personas` the true SSOT), update `seed_memberships/3` to read `persona.org_member` and `persona.org_owner` instead of hardcoding the membership matrix. Either approach is acceptable; the current state creates a silent divergence.

---

### WR-03: `upsert_organization` check-then-insert has no conflict fallback

**File:** `test/example/lib/example/demo/seeds.ex:189-201`

**Issue:** `upsert_organization/2` does a `Repo.get_by/2` followed by `Repo.insert!/1` with no `on_conflict` option. If two processes call `Seeds.run/0` concurrently (or if a concurrent test setup triggers a race), the window between the `get_by` returning `nil` and the `insert!` executing allows a duplicate-key constraint violation that raises an uncaught `Postgrex.Error`, crashing the seed process. The module docstring explicitly claims idempotency ("Calling `run/0` twice is safe"), and all other upsert helpers use `on_conflict: :nothing` — this one is the odd one out.

**Fix:** Add `on_conflict: :nothing` and follow with a fetch on conflict, matching the pattern used elsewhere:

```elixir
defp upsert_organization(name, slug) do
  case Repo.get_by(Organization, slug: slug) do
    %Organization{} = org ->
      org

    nil ->
      %Organization{}
      |> Organization.changeset(%{name: name, slug: slug})
      |> Repo.insert!(on_conflict: :nothing, conflict_target: [:slug])
      |> case do
        %Organization{id: nil} -> Repo.get_by!(Organization, slug: slug)
        org -> org
      end
  end
end
```

Alternatively, replace the entire function with a single `Repo.insert!(..., on_conflict: :nothing, conflict_target: [:slug])` and then fetch the row.

---

## Info

### IN-01: `maybe_schedule_deletion/2` name does not match its Dave-specific clause behavior

**File:** `test/example/lib/example/demo/seeds.ex:152-161`

**Issue:** The first clause of `maybe_schedule_deletion/2` matches `dave@demo.sigra.dev` specifically and clears `hashed_password` via `User.deletion_changeset/2`. This has nothing to do with scheduling deletion — Dave's persona has `scheduled_deletion: false`. The function is named for its second clause's concern, while the first clause handles an unrelated lifecycle operation (password wipe for a locked/unconfirmed account). A future maintainer reading the call site `maybe_schedule_deletion(user, persona)` will not expect it to also clear passwords.

**Fix:** Extract the Dave-specific operation into its own private function and call it explicitly from `patch_user_state/2`:

```elixir
defp patch_user_state(user, persona) do
  user = maybe_confirm(user, persona)
  user = maybe_lock(user, persona)
  user = maybe_wipe_password_for_locked_unconfirmed(user, persona)
  user = maybe_schedule_deletion(user, persona)
  user
end

defp maybe_wipe_password_for_locked_unconfirmed(user, %{email: "dave@demo.sigra.dev"}) do
  # Dave is seeded locked + unconfirmed with no usable password
  if is_nil(user.hashed_password) do
    user
  else
    user |> User.deletion_changeset(%{hashed_password: nil}) |> Repo.update!()
  end
end

defp maybe_wipe_password_for_locked_unconfirmed(user, _persona), do: user
```

---

### IN-02: TOTP secret attribute name encodes "admin" but secret is shared with bob

**File:** `test/example/lib/example/demo/personas.ex:18`

**Issue:** The module attribute is named `@demo_totp_secret` and its derivation key is `"sigra-demo-admin-totp-v1"`, but the docstring (line 142) correctly states it is used for both admin and bob. The key string `"sigra-demo-admin-totp-v1"` permanently bakes "admin" into the derived secret bytes even though the secret is shared. If a future maintainer reads the attribute name or the key string in isolation, they will incorrectly assume this is admin-only.

**Fix:** Either rename the derivation key to `"sigra-demo-totp-v1"` (dropping "admin") and update the docstring, or give bob his own derived secret with key `"sigra-demo-bob-totp-v1"`. Changing the key string will change the derived bytes, so any existing seeded TOTP credentials would need to be re-seeded.

---

### IN-03: `CredentialsLive` does not have a `live_session` wrapper with `on_mount`

**File:** `test/example/lib/example_web/router.ex:178-181`

**Issue:** The `/demo/credentials` route is a bare `live "/credentials", Demo.CredentialsLive` inside a plain `scope` block. It has no `live_session` wrapper and no `on_mount` hook to run `mount_current_scope`. The `:browser` pipeline's `fetch_current_scope` plug assigns `current_scope` on the conn, but that assignment does not automatically propagate into the LiveView socket's assigns. As a result, `@current_scope` in `Layouts.app` will always be `nil` for this route, regardless of whether the user is logged in.

This is currently harmless because `Layouts.app` handles `current_scope: nil` gracefully (the nav shows "Sign In" and the impersonation banner is hidden), and the page is read-only dev-only content. But if the layout ever starts gating more functionality on `@current_scope`, this route will silently misbehave.

**Fix:** Wrap the route in a `live_session` with `on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}]` for consistency with other unauthenticated public routes in the project:

```elixir
scope "/demo", ExampleWeb do
  pipe_through :browser

  live_session :demo_public,
    on_mount: [{ExampleWeb.UserAuth, :mount_current_scope}] do
    live "/credentials", Demo.CredentialsLive
  end
end
```

---

### IN-04: Audit batch count-threshold guard is outside the transaction

**File:** `test/example/lib/example/demo/seeds.ex:387-396`

**Issue:** `seed_audit_events/1` reads `admin_tied_count` outside the transaction, then conditionally calls `insert_audit_batch/1` which wraps the inserts in a transaction. The count check is a TOCTOU: if two concurrent seed runs both observe `count < 15`, both will proceed to insert a full batch, doubling the audit rows. The inline comment acknowledges the all-or-nothing need but does not address the race on the count check itself.

In practice, seeds are single-process (called from `mix run priv/repo/seeds.exs`), so this race is theoretical. But the idempotency guarantee claimed by the module doc would be violated in concurrent tooling.

**Fix:** Move the count check inside the transaction to make the guard atomic:

```elixir
defp seed_audit_events(users) do
  admin = users["admin@demo.sigra.dev"]

  Repo.transaction(fn ->
    admin_tied_count =
      Repo.aggregate(
        from(a in AuditEvent, where: a.effective_user_id == ^admin.id),
        :count
      )

    if admin_tied_count < 15 do
      Enum.each(@audit_actions, fn {action, outcome, offset_days} ->
        # ... insert logic ...
      end)
    end
  end)
end
```

---

_Reviewed: 2026-05-30T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
