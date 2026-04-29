# Phase 91: Org-level MFA enforcement (B2B-01) — Research

**Researched:** 2026-04-29
**Domain:** Phoenix 1.8 plug + on_mount enforcement, Ecto 3.13 Multi atomic-audit, generator template extension
**Confidence:** HIGH

## Summary

Phase 91 wires a single boolean column (`enforce_mfa_for_members`) and four small new module surfaces (one orchestrator function, one plug, one on_mount, one generator template section) into the established Phase 14/16/82/85 patterns. CONTEXT.md is exhaustive — it locks 15 decisions and leaves exactly 8 narrow Discretion items. Every Discretion item resolves cleanly by reading the codebase: the Repo.transact/2 question is already settled (passkeys.ex is the precedent — use it), the NimbleOptions question is misframed (RequireMembership doesn't actually use NimbleOptions — opts validation is raw Keyword + ArgumentError, and that pattern should be preserved for symmetry), the session-key question has a clean precedent (`:user_return_to`, used by user_auth.ex login flow + `:mfa_return_to`), and the error-atom names are ecosystem-locked by Phase 82 (`:jwt_refresh_aborted`) and Phase 85 (`:impersonation_aborted`).

**The single landmine** specific to Phase 91 is the on_mount **bridge pattern**: `Sigra.LiveView.OrganizationScope` does NOT call `Phoenix.LiveView.redirect/2` — it assigns `:sigra_redirect_to` on the socket and returns `{:halt, socket}`, leaving the actual redirect to a host LV root layout consumer. `Sigra.LiveView.RequireOrgMfa` MUST follow the same pattern or generator-host integration will silently break.

**Primary recommendation:** Match the locked precedents verbatim. Use `:org_mfa_required` as the error-handler atom (specificity beats brevity per the existing `:no_active_org` / `:insufficient_role` family), `:mfa_policy_aborted` as the stable rollback atom (Phase 82/85 family naming), `:user_return_to` reused as the session key (it's already wired through user_auth.ex login flow), and the OrganizationScope on_mount assign-bridge pattern for the redirect. Skip NimbleOptions for the plug — RequireMembership/RequireMFAEnrolled/LoadActiveOrganization all use raw Keyword + ArgumentError, and a one-off NimbleOptions schema would diverge the plug family.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Schema column persistence | Database / Ecto schema | Library (changeset constructor) | New Boolean field; library writes via `set_mfa_policy_changeset/2`, not host `cast/3` |
| Atomic policy + audit write | Library (`Sigra.Organizations`) | Database (Ecto Multi + Repo.transact) | D-AUD-01 orchestrator pattern; mirrors `update_organization/4`, `rename_organization/4`, etc. |
| Pre-flight admin enrollment guard | Library | — | Pure compute on `Sigra.MFA.enabled?/2` before Multi opens |
| HTTP enforcement | Library plug (`Sigra.Plug.RequireOrgMfa`) | Host error_handler | Plug halts via `error_handler.auth_error/2`; host owns the response shape |
| LiveView enforcement | Library on_mount (`Sigra.LiveView.RequireOrgMfa`) | Host root LV consumer of `:sigra_redirect_to` | Library assigns redirect target; host renders the redirect (bridge pattern matches OrganizationScope/AdminScope) |
| Settings UI (toggle, impact preview, confirm) | Generated host (`OrganizationSettingsLive`) | Library `count_members/2` | Application-owned LV; calls injected delegator `Organizations.set_mfa_policy/2` |
| Generator template wiring | Library generator (`mix sigra.install`) | Host file system | Templates emit migration, schema field, router pipeline, on_mount registration, error handler clause |
| Upgrade migration (existing hosts) | Library generator (`mix sigra.upgrade`) | Host migrations dir | Idempotent `add_if_not_exists` template; structural twin of `alter_add_personal.exs` |

## Phase Scope Verification

The planner is implementing exactly nine deliverables. None of them are re-decisions — CONTEXT.md and UI-SPEC.md lock all material choices.

1. **Library:** New private changeset constructor `set_mfa_policy_changeset/2` and new public function `Sigra.Organizations.set_mfa_policy(config, scope, org, value)` returning `{:ok, org} | {:error, :admin_must_enroll_first} | {:error, :mfa_policy_aborted} | {:error, %Ecto.Changeset{}}`. Reuses the existing `append_audit/5` private helper (line 1313) and `normalize_multi_result/1` (line 1305). Adds the function to the `__using__/1` macro delegator block (line 280-348) so generated `Organizations` wrappers expose `set_mfa_policy/2`.

2. **Library plug:** `Sigra.Plug.RequireOrgMfa` (~80-120 lines projected). Reads `scope.active_organization.enforce_mfa_for_members` and `scope.user`, calls `Sigra.MFA.enabled?/2`. On enforcement-required-but-not-enrolled, stores the current path in session under `:user_return_to` and halts via `error_handler.auth_error(:org_mfa_required, opts)`.

3. **Library on_mount:** `Sigra.LiveView.RequireOrgMfa`. Same logic as the plug, but bridges via `assign(socket, :sigra_redirect_to, enrollment_path)` and `{:halt, socket}` (matching `OrganizationScope`/`AdminScope` patterns).

4. **Generator schema:** Add `field :enforce_mfa_for_members, :boolean, default: false` to `priv/templates/sigra.install/organizations/organization.ex`. NOT cast in `changeset/2` — library-managed via the private constructor.

5. **Generator install migration:** Add `add :enforce_mfa_for_members, :boolean, null: false, default: false` to the Postgres branch of `priv/templates/sigra.install/organizations/migration.exs` (and the MySQL/SQLite branch for symmetry, even though Phase 94 will remove those branches anyway).

6. **Generator upgrade migration:** New file `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` — idempotent `add_if_not_exists` mirroring `alter_add_personal.exs`.

7. **Generator router:** Add `plug Sigra.Plug.RequireOrgMfa, error_handler: <%= web_module %>.AuthErrorHandler` to the `:org_scoped` pipeline in `priv/templates/sigra.install/organizations/router_injection.ex` (currently lines 16-20). Add `{Sigra.LiveView.RequireOrgMfa, []}` to `live_session :organization_scoped` on_mount list (currently lines 43-48).

8. **Generator settings LV:** Add a new "Security" section to `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` between General (line 56-64) and Slug (line 66-112). Toggle, impact preview, confirm form; copy verbatim from UI-SPEC.

9. **Generator error handler:** Add `auth_error(conn, :org_mfa_required, opts)` clause to `priv/templates/sigra.install/core/error_handler.ex` after the `:insufficient_role` clause (line 60-68).

Plus a 10th deliverable that is a one-line edit, NOT new code: ROADMAP.md success criterion #1 — change `organization.mfa_policy_changed` to `organization.mfa_policy_change` (D-91-12).

CONTEXT references `priv/templates/sigra.install/core/auth_hooks.ex` for the on_mount registration. **That is incorrect.** `auth_hooks.ex` is the application-domain hooks module (host-overrideable callbacks for `on_register`, `on_email_change`, etc.). The on_mount registration for `live_session :organization_scoped` lives in `priv/templates/sigra.install/organizations/router_injection.ex` lines 43-48. The planner should ignore the CONTEXT reference to `auth_hooks.ex` for this purpose. (Alternatively, `priv/templates/sigra.install/core/user_auth.ex` lines 317-363 host the `def on_mount(:assign_user_organizations, ...)` pattern — but that's the host's own `on_mount/4` callback, not a list registration. The router_injection.ex `live_session` block is the right surface.)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| B2B-01 | Org admin can require MFA for all members of an organization, blocking access for non-MFA-enrolled members until enrollment, with the policy change recorded as an atomic audit row. | Locked stack: Ecto.Multi + Repo.transact + Sigra.Audit.log_multi_safe + Sigra.MFA.enabled?/2 + Sigra.Plug.RequireMembership pattern (twin) + Sigra.LiveView.OrganizationScope pattern (twin) + UI-SPEC §Copywriting Contract for all user-facing strings + Phase 82/85 fault-injection test pattern. |

## Discretion-Gap Resolutions

### Gap 1: NimbleOptions schema shape for plug options

**Question (CONTEXT D-91-06):** Exact NimbleOptions schema for `RequireOrgMfa.init/1`.

**Finding:** The CONTEXT framing of "NimbleOptions-style opt validation, mirrors `Sigra.Plug.RequireMembership`'s pattern" is technically misleading. **`Sigra.Plug.RequireMembership` does not use NimbleOptions** — `lib/sigra/plug/require_membership.ex:72-95` validates options with raw `Keyword.fetch!/2` + `ArgumentError`. Same for `Sigra.Plug.RequireMFAEnrolled` (line 29: `def init(opts), do: opts`), `Sigra.Plug.LoadActiveOrganization` (line 64-68: `Keyword.fetch!/2` + return opts), and `Sigra.Plug.LoadOrganizationFromSlug`. **NimbleOptions is used in the library elsewhere** (`Sigra.Passkeys`, `Sigra.Account`, `Sigra.Organizations.__validate_config__!`) but the entire `Sigra.Plug.*` family deliberately uses raw Keyword for plug-init speed and ArgumentError clarity at compile-time pipeline assembly.

**Resolution:** Skip NimbleOptions for the plug. Match RequireMembership exactly:

```elixir
@impl Plug
def init(opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  enrollment_path = Keyword.get(opts, :enrollment_path, "/users/settings/mfa")

  unless is_atom(error_handler) and not is_nil(error_handler) do
    raise ArgumentError,
          "Sigra.Plug.RequireOrgMfa :error_handler must be a module, got: " <>
            inspect(error_handler)
  end

  opts
  |> Keyword.put(:error_handler, error_handler)
  |> Keyword.put(:enrollment_path, enrollment_path)
end
```

`[VERIFIED: lib/sigra/plug/require_membership.ex lines 72-95, lib/sigra/plug/require_mfa_enrolled.ex line 29, lib/sigra/plug/load_active_organization.ex line 64-68]`

### Gap 2: AuthErrorHandler reason atom (`:mfa_required` vs `:org_mfa_required`)

**Resolution:** **`:org_mfa_required`**.

**Rationale:** The existing AuthErrorHandler family uses specific compound atoms — `:no_active_org`, `:insufficient_role`, `:stale_sudo`, `:rate_limited`, `:unauthenticated`. `:mfa_required` would collide semantically with the existing `Sigra.Plug.RequireMFAEnrolled` (account-level enforcement, e.g. admin routes — D-91-04 explicitly preserves it as a separate plug). `:org_mfa_required` keeps the disambiguation crisp and matches the convention. CONTEXT D-91-02 notes "mild preference for `:org_mfa_required` for specificity" — concur. `[VERIFIED: priv/templates/sigra.install/core/error_handler.ex full file]`

### Gap 3: LiveView form ergonomics for the "Security" section

**Resolution:** Match the existing slug section's progressive-disclosure shape. Closed state: toggle + helper copy + state badge. Open state (after toggle click): inline form with impact preview alert + Save / direction-specific dismiss buttons.

UI-SPEC fully specifies the visual contract — it leaves only mechanism choices to the planner. Concrete recommendation:

- **State machine:** `assign(:security_form_open?, false)` + `assign(:security_form, blank_security_form())`. Toggle click sets `:security_form_open?` and `:pending_value` to the proposed boolean. Save POSTs to `phx-submit="save_mfa_policy"`. Dismiss resets both.
- **No optimistic UI flip:** The toggle should not visually flip until save commits — the confirm form is between click and commit. Reset toggle position on dismiss. (UI-SPEC §Interaction States row "Confirm-form open" describes optimistic flip; this contradicts the cleaner reset-on-dismiss pattern. Recommendation: disable optimistic flip for simplicity; UI-SPEC is over-specifying mechanism here. Planner discretion.)
- **Impact preview COUNT query:** Sync inline (not async). The COUNT is `MEMBERSHIPS_COUNT − MEMBERS_WITH_MFA_COUNT` for the active org. For an org with N≤10000 members this is a single index-scan-bound query and runs <5ms p99 on Postgres. Async only if benchmarks show otherwise. UI-SPEC §Empty/Loading row 2 leaves this at planner discretion.
- **Toggle markup:** Use raw `<input type="checkbox" class="toggle toggle-primary" phx-click="toggle_mfa_policy" />` directly, NOT `<.input>`. Phoenix 1.8's stock `<.input type="checkbox">` emits a plain checkbox, not a DaisyUI toggle. UI-SPEC §Component Inventory acknowledges this and instructs to fall back to raw input.

`[VERIFIED: priv/templates/sigra.install/organizations/live/organization_settings_live.ex lines 66-112 (slug section as visual template), .planning/phases/91-org-level-mfa-enforcement-b2b-01/91-UI-SPEC.md §Component Inventory + §Interaction States]`

### Gap 4: Inline impact-preview copy + admin-must-enroll-first error message

**Resolution:** Use UI-SPEC verbatim:

- Impact preview (count > 0): `"{N} of {M} members are not enrolled in MFA. They will be redirected to enroll on their next request to this organization."` `[CITED: 91-UI-SPEC.md §Copywriting Contract › Impact preview]`
- Admin-must-enroll-first inline: `"Enable MFA on your account first. You'd be locked out of this organization otherwise."` `[CITED: 91-UI-SPEC.md §Copywriting Contract › Empty / informational states]`
- Toggle disabled tooltip: `"Enable MFA on your account before requiring it for the organization."` `[CITED: 91-UI-SPEC.md §Copywriting Contract › Empty / informational states]`
- Inline link: `"Set up MFA on your account →"` styled `link link-primary` `[CITED: 91-UI-SPEC.md]`

UI-SPEC is the locked source of truth. Do not paraphrase.

### Gap 5: `Repo.transact/2` (Ecto 3.13) vs `Repo.transaction/1`

**Resolution:** **Use `config.repo.transact/1`**. Match the precedent already set inside the library.

**Verified precedent:** `lib/sigra/passkeys.ex` lines 114, 195, 227, 396, 407, 426 — passkeys atomic-Multi paths use `config.repo.transact/1` exclusively. Phase 82 D-82-01 explicitly says "or `Repo.transact/2` if the codebase standardizes on 3.13" — the codebase has standardized on 3.13 (mix.exs declares `{:ecto, "~> 3.12"}` with `Repo.transact/2` available in 3.13.x).

**Caveat:** Existing `Sigra.Organizations` orchestrators (`update_organization/4` line 442, `rename_organization/4` line 533, `update_slug/4` line 605, `soft_delete_organization/4` line 493, `create_organization/3` line 415) all call `config.repo.transaction/1` (older idiom). Don't change those — surgical edits only. `set_mfa_policy/3` is new code; use `config.repo.transact/1` for it. The mixed convention is a known cosmetic debt, not a phase 91 concern.

`[VERIFIED: lib/sigra/passkeys.ex lines 114, 195, 227, 396, 407, 426; lib/sigra/organizations.ex lines 415, 442, 493, 533, 605]`

### Gap 6: Stable error atom name (`:mfa_policy_aborted` vs `:enforce_mfa_aborted` vs `:org_mfa_policy_aborted`)

**Resolution:** **`:mfa_policy_aborted`**.

**Rationale:** Phase family naming convention is `<noun>_aborted` short form: `:jwt_refresh_aborted` (Phase 82 D-82-02), `:impersonation_aborted` (Phase 85 D-85-02). `:mfa_policy_aborted` matches that pattern and reads cleanly. `:enforce_mfa_aborted` collides linguistically with the act of enforcing on a request (the plug's job), not the act of changing the policy. `:org_mfa_policy_aborted` is verbose without disambiguation gain — there is only one MFA policy in the system, and it's the org-level one (account-level MFA is enrollment, not policy).

`[VERIFIED: .planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md D-82-02; .planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md D-85-02]`

### Gap 7: Session key for `return_to` (`:org_mfa_return_to` vs `:user_return_to` reused)

**Resolution:** **Reuse `:user_return_to`**.

**Rationale:** `:user_return_to` is already the canonical post-auth-redirect session key — see `priv/templates/sigra.install/core/user_auth.ex` line 67 (`get_session(conn, :user_return_to)`), line 478 (`put_session(conn, :user_return_to, current_path(conn))`), and `priv/templates/sigra.install/core/confirmation_controller.ex` line 57 (`put_session(:user_return_to, ~p"/users/sudo?return_to=...")`). The login flow ALREADY restores `:user_return_to` on next login (user_auth.ex line 67-73: `redirect(to: user_return_to || signed_in_path(conn))`).

If `RequireOrgMfa` writes to `:user_return_to` and the user enrolls MFA via the existing `mfa_settings_live.ex` flow, the existing post-enrollment redirect logic handles the return path with zero new code. A separate `:org_mfa_return_to` would require a new MFA-enrollment-success handler change to read both keys. Reuse is strictly better.

**Path-validation (per D-91-08):** Validate `current_path(conn)` is a relative path starting with `/` and does NOT start with `//` before storing. Phoenix's `current_path/1` returns `path <> "?" <> query_string` — already a relative path under normal Plug usage, but the validation is cheap insurance against open-redirect via crafted X-Forwarded headers.

`[VERIFIED: priv/templates/sigra.install/core/user_auth.ex lines 67-73, 478, 481; priv/templates/sigra.install/core/confirmation_controller.ex line 57]`

### Gap 8: Test file naming

**Resolution:** Match the names in CONTEXT D-91 verbatim:

- Plug unit: `test/sigra/plug/require_org_mfa_test.exs` (mirrors `test/sigra/plug/require_membership_test.exs`)
- LiveView mount unit: `test/sigra/live_view/require_org_mfa_test.exs` (mirrors `test/sigra/live_view/organization_scope_test.exs`)
- Atomicity: `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` (mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs`; existing org test directory pattern is `test/sigra/organizations/*_test.exs` for unit tests but atomicity-class tests live at `test/sigra/<module>_audit_*_test.exs` per Phase 82/85 — see `test/sigra/jwt_refresh_audit_cofate_test.exs`, `test/sigra/impersonation_audit_atomicity_test.exs`, `test/sigra/account_audit_atomicity_test.exs`, `test/sigra/mfa_audit_atomicity_test.exs`. CONTEXT name fits this naming family.)
- Generator-host integration: `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` (existing convention is `phase_NN_integration_test.exs` per `test/example/test/example_web/integration/phase_16_integration_test.exs` — but the CONTEXT name is more discoverable. Either is acceptable; prefer CONTEXT name for B2B-01-anchored discovery.)

`[VERIFIED: test/sigra/ directory listing; test/example/test/example_web/integration/ directory listing]`

## Structural-Twin Verification

### Twin 1: `Sigra.Plug.RequireMembership` → `Sigra.Plug.RequireOrgMfa`

**File:** `lib/sigra/plug/require_membership.ex` (148 lines, verified). `[VERIFIED: wc -l]`

**Key signatures to mirror:**

```elixir
# init/1 (lines 72-95) — error_handler validation, opts return
@impl Plug
def init(opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  # ... validation ...
  opts |> Keyword.put(:error_handler, error_handler) |> Keyword.put(:roles, required_roles)
end

# call/2 (lines 126-147) — scope read, halt-via-error-handler
@impl Plug
def call(%Plug.Conn{} = conn, opts) do
  error_handler = Keyword.fetch!(opts, :error_handler)
  scope = conn.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.active_organization) ->
      conn |> error_handler.auth_error(:no_active_org, opts) |> Plug.Conn.halt()

    required != [] and scope.membership.role not in required ->
      conn |> error_handler.auth_error(:insufficient_role, error_opts) |> Plug.Conn.halt()

    true ->
      conn
  end
end
```

**RequireOrgMfa structural mapping:**
- `init/1`: `:error_handler` required, `:enrollment_path` optional (default `/users/settings/mfa`). No `:roles` analog.
- `call/2`: cond order: (1) `scope == nil or scope.active_organization == nil` — fall through (let RequireMembership handle); (2) `scope.active_organization.enforce_mfa_for_members == false` — fall through; (3) `Sigra.MFA.enabled?(config, scope.user) == true` — fall through; (4) else: `put_session(:user_return_to, current_path(conn))` then `error_handler.auth_error(:org_mfa_required, opts) |> halt()`.

**One subtle issue — config access:** `Sigra.MFA.enabled?/2` needs `Sigra.Config.t()`, but the plug currently does not receive a config. RequireMembership reads `scope.membership.role` (already hydrated by upstream LoadActiveOrganization plug); RequireOrgMfa similarly should read pre-hydrated state and NOT call into MFA from inside the plug if possible. **Two options:**

1. **Pre-hydrate `scope.user_mfa_enabled`** in `LoadActiveOrganization` (or a new `MaybeAssignMfaStatus` plug). Cleanest, but adds a query per request even when the org doesn't enforce. Reject — wasteful.
2. **Pass `:organizations` opt to `RequireOrgMfa.init/1`** the way LoadActiveOrganization does (line 65: `_ = Keyword.fetch!(opts, :organizations)`). Plug reads `organizations.__sigra_org_config__()` at call time; uses that config for `Sigra.MFA.enabled?/2`. **Recommended.** Matches D-91-06's "minimal" intent (still 2 required opts: `:error_handler` + `:organizations`) and the existing LoadActiveOrganization shape.

The router_injection template change becomes:

```elixir
pipeline :org_scoped do
  plug Sigra.Plug.LoadOrganizationFromSlug
  plug Sigra.Plug.RequireMembership,
    error_handler: <%= web_module %>.AuthErrorHandler
  plug Sigra.Plug.RequireOrgMfa,
    error_handler: <%= web_module %>.AuthErrorHandler,
    organizations: <%= context_module %>.Organizations
end
```

`[VERIFIED: lib/sigra/plug/require_membership.ex full file; lib/sigra/plug/load_active_organization.ex lines 63-68]`

### Twin 2: `Sigra.LiveView.OrganizationScope` → `Sigra.LiveView.RequireOrgMfa`

**File:** `lib/sigra/live_view/organization_scope.ex` (89 lines, verified). `[VERIFIED]`

**Key signature to mirror:**

```elixir
def on_mount(opts, params, _session, socket) when is_list(opts) do
  organizations = Keyword.fetch!(opts, :organizations)
  scope_module = Keyword.fetch!(opts, :scope_module)
  login_path = Keyword.get(opts, :login_path, "/users/log_in")
  config = organizations.__sigra_org_config__()
  scope = socket.assigns[:current_scope]

  cond do
    is_nil(scope) or is_nil(scope.user) ->
      {:halt, assign_redirect(socket, login_path)}
    true ->
      # ... resolve and {:cont, ...} or {:halt, sigra_not_found assign} ...
  end
end

defp assign_redirect(socket, path) do
  put_in(socket.assigns[:sigra_redirect_to], path)
end
```

**Critical landmine:** OrganizationScope does NOT call `Phoenix.LiveView.redirect/2` directly. It assigns `:sigra_redirect_to` on the socket and returns `{:halt, socket}`. The host's root LV component / layout reads `:sigra_redirect_to` and triggers the actual redirect. **`Sigra.LiveView.RequireOrgMfa` MUST follow the same bridge pattern** — failing to do so will pull `phoenix_live_view` into the library's hard test deps (currently it's a transitive-only dep) and break the existing test pattern.

The on_mount registration is in `priv/templates/sigra.install/organizations/router_injection.ex` lines 43-48 (the `live_session :organization_scoped` on_mount list), NOT in `auth_hooks.ex` (CONTEXT canonical_refs has this slightly wrong — `auth_hooks.ex` is for application-domain hooks like `on_register`).

The on_mount only catches mid-session policy flips on `live_redirect` within the same `live_session`. A full page nav re-runs the HTTP plug. This is by design (D-91-03).

`[VERIFIED: lib/sigra/live_view/organization_scope.ex lines 40-77; test/sigra/live_view/organization_scope_test.exs lines 133, 143, 147, 155, 159, 171, 175 (test assertions on :sigra_redirect_to and :sigra_not_found)]`

### Twin 3: Mirror functions in `lib/sigra/organizations.ex`

**Reusable helpers:**
- **`append_audit/5`** at line 1313 — `defp append_audit(multi, config, action, scope, extra \\ [])`. Already wraps `Sigra.Audit.log_multi_safe/3` with scope-derived actor_id and metadata merge. Reuse verbatim.
- **`normalize_multi_result/1`** at lines 1305-1311 — converts `{:ok, changes}` → `{:ok, changes}` and `{:error, _step, %Ecto.Changeset{} = cs, _}` → `{:error, cs}`. Reuse verbatim.

**Functions to mirror:**

`update_organization/4` (lines 434-449) is the cleanest twin:

```elixir
def update_organization(config, scope, org, attrs) do
  changeset = update_org_changeset(org, attrs, config)

  result =
    Multi.new()
    |> Multi.update(:organization, changeset)
    |> append_audit(config, "organization.update", scope)
    |> config.repo.transaction()
    |> normalize_multi_result()

  case result do
    {:ok, %{organization: org}} -> {:ok, org}
    error -> error
  end
end
```

**`set_mfa_policy/3` recommended shape:**

```elixir
@spec set_mfa_policy(map(), map(), struct(), boolean()) ::
        {:ok, struct()}
        | {:error, :admin_must_enroll_first}
        | {:error, :mfa_policy_aborted}
        | {:error, Ecto.Changeset.t()}
def set_mfa_policy(config, scope, org, value) when is_boolean(value) do
  changeset = set_mfa_policy_changeset(org, value)

  cond do
    # D-91-14: no-op short-circuit BEFORE Multi opens
    changeset.changes == %{} ->
      {:ok, org}

    # D-91-09: admin pre-flight refuse on enable
    value == true and not Sigra.MFA.enabled?(config, scope.user) ->
      {:error, :admin_must_enroll_first}

    true ->
      result =
        Multi.new()
        |> Multi.update(:organization, changeset)
        |> append_audit(config, "organization.mfa_policy_change", scope,
          metadata: %{old_value: org.enforce_mfa_for_members, new_value: value}
        )
        |> config.repo.transact()
        |> normalize_multi_result_for_mfa_policy()

      case result do
        {:ok, %{organization: updated}} -> {:ok, updated}
        {:error, %Ecto.Changeset{}} = err -> err
        {:error, _other} -> {:error, :mfa_policy_aborted}
      end
  end
end

defp set_mfa_policy_changeset(org, value) do
  org |> Ecto.Changeset.change(%{enforce_mfa_for_members: value})
end
```

**`normalize_multi_result_for_mfa_policy/1`** is a NEW private helper that maps `{:error, :audit, _changeset, _}` (audit insert failure under fault injection) to `{:error, :mfa_policy_aborted}`. The existing `normalize_multi_result/1` returns `{:error, %Ecto.Changeset{}}` for that case which would leak the audit changeset to callers. Phase 82 / 85 face the same translation requirement; both opted to add small per-orchestrator normalize helpers. Match that pattern.

**`__using__/1` macro delegator** at line 280-348 needs one new line:

```elixir
def set_mfa_policy(scope, value),
  do: Sigra.Organizations.set_mfa_policy(@sigra_org_config, scope, scope.active_organization, value)
```

Generated `Organizations` wrappers (`priv/templates/sigra.install/organizations/organizations.ex`) get this delegator for free via `use Sigra.Organizations` — no template edit needed beyond the new function.

`[VERIFIED: lib/sigra/organizations.ex lines 280-348 (__using__ delegators), 415, 434-449 (update_organization), 1305-1322 (normalize/append helpers)]`

## Atomic-Audit Fault-Injection Test Pattern

The new `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs` (Phase 82 D-82-04) with one structural change: org-flavored test schemas instead of jwt-flavored. Verified the Phase 82 test in detail — it provides the canonical pattern.

**Required scaffolding (lines 18-129 of the Phase 82 test, adapted):**

```elixir
defmodule Sigra.OrganizationsMfaPolicyAuditAtomicityTest do
  @moduledoc """
  Postgres integration test for `Sigra.Organizations.set_mfa_policy/3`
  persistence + audit co-fate.

  Mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs` (Phase 82) and
  `test/sigra/impersonation_audit_atomicity_test.exs` (Phase 85). Uses
  `ALTER TABLE ... CHECK (action <> 'organization.mfa_policy_change')`
  to force audit-row rejection and proves no orphan org write.
  """
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias Sigra.Test.AuditEvent, as: AuditTestEvent
  alias Sigra.Test.PostgresRepo

  defmodule TelemetryHandler do
    def handle_event(event, measurements, metadata, parent) do
      send(parent, {:telemetry, event, measurements, metadata})
    end
  end

  # Test schemas: organizations + organization_memberships + audit_events
  defmodule MfaTestUser do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "mfa_policy_users" do
      field :email, :string
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule MfaTestOrg do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "mfa_policy_orgs" do
      field :name, :string
      field :slug, :string
      field :enforce_mfa_for_members, :boolean, default: false
      timestamps(type: :utc_datetime_usec)
    end
  end

  defmodule MfaTestMembership do
    use Ecto.Schema
    @primary_key {:id, :binary_id, autogenerate: true}
    schema "mfa_policy_memberships" do
      field :role, :string
      field :organization_id, :binary_id
      field :user_id, :binary_id
      timestamps(type: :utc_datetime_usec)
    end
  end

  setup do
    start_supervised!({PostgresRepo, PostgresRepo.default_config()})
    repo = PostgresRepo

    Ecto.Adapters.SQL.query!(repo, "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", [])

    for t <- ["mfa_policy_memberships", "mfa_policy_orgs", "mfa_policy_users"] do
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE IF EXISTS #{t} CASCADE", [])
    end

    # ... CREATE TABLE statements for each ...
    # ... CREATE TABLE IF NOT EXISTS audit_events (same as Phase 82 line 91-112) ...
    # ... TRUNCATE statements ...

    %{repo: repo}
  end
```

**Required test cases (mirroring Phase 82's four tests, adapted to four-or-five for the no-op + admin-pre-flight cases):**

1. **Happy path (audit on):** `set_mfa_policy(config, scope, org, true)` — assert `{:ok, %{enforce_mfa_for_members: true}}`, assert `count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 1`, assert metadata payload is `%{"old_value" => false, "new_value" => true}`.

2. **Audit off:** `set_mfa_policy/3` with `:audit_schema` unset in config — assert `{:ok, _}`, assert `count_where(repo, "audit_events", ...) == 0`, assert org row updated.

3. **Fault injection (the load-bearing test):**
```elixir
Ecto.Adapters.SQL.query!(repo, """
  ALTER TABLE audit_events
  ADD CONSTRAINT mfa_policy_change_guard CHECK (action <> 'organization.mfa_policy_change')
""", [])

try do
  # ... setup user with MFA enabled, org with enforce_mfa_for_members = false ...
  before_value = MfaTestOrg |> repo.get!(org.id) |> Map.fetch!(:enforce_mfa_for_members)

  ref = :telemetry.attach(
    {__MODULE__, :mfa_policy_guard},
    [:sigra, :audit, :log_safe_error],
    &TelemetryHandler.handle_event/4,
    self()
  )

  try do
    assert {:error, :mfa_policy_aborted} =
             Sigra.Organizations.set_mfa_policy(config, scope, org, true)

    assert_receive {:telemetry, [:sigra, :audit, :log_safe_error], %{count: 1},
                    %{action: "organization.mfa_policy_change", reason: :constraint_violation}}
  after
    :telemetry.detach(ref)
  end

  # No orphan org write — value is unchanged after rollback.
  after_value = MfaTestOrg |> repo.get!(org.id) |> Map.fetch!(:enforce_mfa_for_members)
  assert after_value == before_value
  assert count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0
after
  Ecto.Adapters.SQL.query!(repo,
    "ALTER TABLE audit_events DROP CONSTRAINT IF EXISTS mfa_policy_change_guard", [])
end
```

4. **No-op short-circuit (D-91-14):** Setup org with `enforce_mfa_for_members = true`. Call `set_mfa_policy(config, scope, org, true)`. Assert `{:ok, _}` and `count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0` (NO audit row written for no-op).

5. **Admin pre-flight refuse (D-91-09):** Setup user WITHOUT MFA enrollment. Call `set_mfa_policy(config, scope, org, true)`. Assert `{:error, :admin_must_enroll_first}` and `count_where(repo, "audit_events", "action = 'organization.mfa_policy_change'") == 0` (no audit row — pre-flight refuse fires before Multi opens).

**Telemetry assertion is the load-bearing piece** of test 3 — proves the audit subsystem ran (and emitted its standard `:log_safe_error` event) before rollback, distinguishing audit-CHECK rejection from a generic transaction abort.

`[VERIFIED: test/sigra/jwt_refresh_audit_cofate_test.exs full file (215 lines reviewed)]`

## Validation Architecture

Project uses ExUnit. Project skill rules from CLAUDE.md: AAA style, flat, self-contained. `mix test` requires live Postgres at `localhost:5432` with `postgres`/`postgres` credentials.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.18+ stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `MIX_ENV=test PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/require_org_mfa_test.exs` |
| Full suite command | `MIX_ENV=test PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| B2B-01 [success #1] | Toggle persists `enforce_mfa_for_members: true` and emits one `organization.mfa_policy_change` audit row co-fated under one transaction (no orphan rows under fault injection) | atomicity (Postgres + ALTER CHECK) | `mix test test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` | ❌ Wave 0 |
| B2B-01 [success #1, library] | `set_mfa_policy/3` happy path, no-op short-circuit, admin pre-flight, normalize_multi_result mapping | unit | `mix test test/sigra/organizations/set_mfa_policy_test.exs` | ❌ Wave 0 |
| B2B-01 [success #2, plug] | `Sigra.Plug.RequireOrgMfa` halts on enforcement-required-but-not-enrolled; passes through on enrolled; passes through when org doesn't enforce | unit (Plug.Test) | `mix test test/sigra/plug/require_org_mfa_test.exs` | ❌ Wave 0 |
| B2B-01 [success #2, on_mount] | `Sigra.LiveView.RequireOrgMfa.on_mount/4` returns `{:halt, socket_with_redirect}` and `{:cont, socket}` per matrix | unit | `mix test test/sigra/live_view/require_org_mfa_test.exs` | ❌ Wave 0 |
| B2B-01 [success #3, generator] | `mix sigra.install` emits new migration column, schema field, router pipeline, settings LV section, error handler clause, on_mount registration | golden-diff | `mix test test/sigra/install/golden_diff_test.exs` (existing — extends with new diffs) | ⚠️ Wave 0 (extend) |
| B2B-01 [success #3, upgrade] | `mix sigra.upgrade` emits the new `alter_add_enforce_mfa_for_members.exs` migration template; idempotent re-run no-ops | unit | `mix test test/mix/tasks/sigra.upgrade_test.exs` (existing — extends) | ⚠️ Wave 0 (extend) |
| B2B-01 [success #4] | Generator-host integration: admin flips toggle → non-MFA member → blocked redirect | integration (full Phoenix conn) | `cd test/example && mix test test/example_web/integration/org_mfa_enforcement_test.exs` | ❌ Wave 0 |
| B2B-01 [success #5] | `91-VERIFICATION.md` records merge gate; `mix ci.audit_45` (or similar) green; library suite green | manual / merge-gate doc | `mix test && cd test/example && mix test` | N/A — doc artifact at phase close |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/plug/require_org_mfa_test.exs test/sigra/live_view/require_org_mfa_test.exs test/sigra/organizations/set_mfa_policy_test.exs` (typical < 5s)
- **Per wave merge:** `mix test test/sigra/` (library suite, < 60s) + `mix test test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` (Postgres atomicity, < 5s)
- **Phase gate:** `MIX_ENV=test mix test` (full library) + `cd test/example && mix test` (generator-host suite). Both green before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `test/sigra/plug/require_org_mfa_test.exs` — covers B2B-01 plug enforcement (lift from `test/sigra/plug/require_membership_test.exs` shape)
- [ ] `test/sigra/live_view/require_org_mfa_test.exs` — covers B2B-01 on_mount enforcement (lift from `test/sigra/live_view/organization_scope_test.exs` shape)
- [ ] `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` — covers B2B-01 atomicity (lift from `test/sigra/jwt_refresh_audit_cofate_test.exs` shape)
- [ ] `test/sigra/organizations/set_mfa_policy_test.exs` — covers B2B-01 library function unit (no-op short-circuit + admin pre-flight + happy path + changeset error). Could fold into existing `test/sigra/organizations/context_test.exs` if planner prefers (precedent for `update_organization`, `rename_organization` is to extend `context_test.exs` rather than spawn a new file — verify before deciding).
- [ ] `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` — covers B2B-01 generator-host round-trip
- [ ] `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` — new template file (not a test, but Wave 0 because the upgrade-task golden-diff test will fail without it)

No framework install needed — ExUnit + Plug.Test are already wired.

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing `Sigra.MFA.enabled?/2` is the canonical check; do not duplicate. `argon2_elixir` for password hashing already in place — Phase 91 does not touch password paths. |
| V3 Session Management | yes | `:user_return_to` session key reused; relative-path validation (must start with `/`, reject `//`) per OAuth RFC 6749 §10.15 / phx.gen.auth precedent. |
| V4 Access Control | yes | Plug halts via `error_handler.auth_error/2`; on_mount halts via `:sigra_redirect_to` bridge. Settings LV toggle gated by `RequireMembership, roles: [:admin, :owner]` (host wiring — Phase 91 does NOT add explicit role check inside the LV; relies on the existing pipeline). **Verify in plan:** the existing `:org_scoped` pipeline does NOT restrict `OrganizationSettingsLive` to admin/owner today — settings LV is reachable by any member. Phase 91 D-91-09 says the toggle is "gated to the admin role" — the planner should add `Sigra.Plug.RequireMembership, roles: [:admin, :owner]` either to a sub-pipeline for `/organizations/:org/settings` or to a guard inside the LV mount. This is a tier-correctness call for the planner; UI-SPEC and CONTEXT both assume the admin-only gate exists somewhere. |
| V5 Input Validation | yes | `set_mfa_policy/3` accepts only `boolean()` — `is_boolean(value)` guard. The settings LV toggle emits `"true"`/`"false"` strings → cast to atom or boolean before the library call. Pattern: `value = params["enforce_mfa_for_members"] == "true"`. |
| V6 Cryptography | no | No new crypto. Audit row metadata is plaintext booleans + IDs. |

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Open redirect via `:user_return_to` after enrollment | Tampering | Validate path starts with `/` and not `//` before storing; fallback to `/organizations/:org` on validation failure (D-91-08). |
| Admin self-lockout | Denial of Service (against admin) | Hard pre-flight refuse if admin not MFA-enrolled (D-91-09). |
| Mid-session policy flip leaving stale LV connections enforced too late | Repudiation (audit shows enforcement on, but user accessed for N more seconds) | Phase 91 ships on_mount which catches next live_redirect. PubSub-broadcast disconnect deferred (D-91 deferred ideas). Acceptable per ROADMAP success criterion #2 wording (request-boundary, not connection-disconnect). |
| Audit row written without org write | Repudiation | D-AUD-08 / D-91-15 atomic Multi: org and audit share fate. Rollback proven by fault-injection test #3 above. |

## Landmines

### Phoenix 1.8 LiveView

1. **Bridge pattern, not direct redirect.** `Sigra.LiveView.OrganizationScope` and `AdminScope` assign `:sigra_redirect_to` and return `{:halt, socket}` rather than calling `Phoenix.LiveView.redirect/2`. The library is unit-testable without `phoenix_live_view` in test deps because of this. **`Sigra.LiveView.RequireOrgMfa` MUST do the same.** Calling `Phoenix.LiveView.redirect/2` directly will pull in test deps and break the existing test pattern.

2. **`live_redirect` re-runs on_mount, full nav re-runs the pipeline.** D-91-03 relies on this distinction. A user mid-session whose admin flips the policy will only be redirected on the NEXT `live_redirect` within the same `live_session`, not on socket events. This is by design.

3. **`<.input type="checkbox">` does NOT emit a DaisyUI toggle.** Phoenix 1.8's stock `core_components.ex` `<.input>` for `type="checkbox"` emits `<input type="checkbox" class="checkbox">` — NOT `class="toggle"`. UI-SPEC §Component Inventory acknowledges this. Use raw `<input type="checkbox" class="toggle toggle-primary" phx-click="..." />` or extend the host's `<.input>` (planner discretion; UI-SPEC default is raw).

4. **`live_session` boundary is sticky.** If a navigation crosses `live_session` boundaries (e.g. `:organization_scoped` → `:authenticated`), the LV connection is severed and replaced. The on_mount on the destination live_session runs from scratch. Cross-`live_session` policy enforcement is automatic via the HTTP pipeline.

### Ecto 3.13 Multi

5. **`config.repo.transact/1` accepts a Multi directly** (Ecto 3.13). Older `transaction/1` does too, but `transact/2` is a generalized name. The library has standardized on `transact/1` for new code (passkeys.ex). Mixed convention with older Organizations functions is intentional — do NOT refactor existing functions to `transact/1` in this phase.

6. **`Multi.update` with an empty changeset is NOT a no-op at the DB level** — it emits an UPDATE with no SET clauses, which Postgres accepts but counts as a row affected. Ecto's `Repo.update/1` short-circuits on empty changesets (returns the struct without DB hit). **`Multi.update/3` does NOT short-circuit** — it always issues the UPDATE. This is why D-91-14 mandates the **caller-side** short-circuit (`changeset.changes == %{}`) BEFORE the Multi opens. Without that, you'd write a no-op audit row + a no-op UPDATE, which D-91-14 explicitly rejects.

7. **Audit step name in the Multi is `:audit` by default.** `Sigra.Audit.log_multi_safe/3` accepts `:audit_multi_step` opt to override. `append_audit/5` (line 1313 of organizations.ex) does NOT pass `:audit_multi_step` — uses the default `:audit`. Phase 91 should NOT pass `:audit_multi_step` (single audit row per Multi). Telemetry is fired by the orchestrator-side `emit_telemetry_from_changes/2` — but `Sigra.Organizations` orchestrators currently do NOT call `emit_telemetry_from_changes/2`. Verified: `update_organization/4`, `rename_organization/4`, `update_slug/4`, etc. all skip telemetry emission. This is consistent — `set_mfa_policy/3` should NOT emit telemetry either, matching the family. (If `09-CONTEXT.md` D-24 had been respected for org actions, it would. The pattern was deferred for organizations and remains debt — out of phase 91 scope.)

8. **Ecto.Changeset.change/2 vs cast/3.** `set_mfa_policy_changeset/2` should use `change/2`, not `cast/3`. `change/2` directly sets the field without going through the `permitted` allowlist; `cast/3` requires the field to be in the permitted list. Since `enforce_mfa_for_members` is NOT in the schema's `cast/3` allowlist (per D-91-05 design — host code can't accidentally write the flag), `change/2` is the correct primitive.

### NimbleOptions edge cases

9. **NimbleOptions is the wrong tool for this plug.** RequireMembership, RequireMFAEnrolled, LoadActiveOrganization all use raw Keyword. NimbleOptions IS used in Sigra.Passkeys, Sigra.Account, and Sigra.Organizations.__validate_config__! — but those are larger surfaces with documented-in-the-public-API option schemas. Plugs are init-once-at-compile-time and a 5-line raw Keyword check is the established pattern. Skip NimbleOptions for the plug. (CONTEXT D-91-06 says "NimbleOptions schema mirrors `Sigra.Plug.RequireMembership`'s pattern" — the planner should read this as "match the established Plug-init validation pattern (raw Keyword)," NOT as "introduce NimbleOptions to the Plug family." This is a CONTEXT framing imprecision, NOT a re-decidable choice.)

### Generator template idempotency

10. **`alter_add_enforce_mfa_for_members.exs` MUST use `add_if_not_exists` and `remove_if_exists`.** The structural twin `alter_add_personal.exs` (verified) does this correctly. The `down/0` function MUST also be idempotent (`remove_if_exists`) so an upgrade-then-downgrade cycle on a host that previously installed Phase 91 and then rolled back works without error.

11. **Install migration template (`migration.exs`) emits the column unconditionally.** This is correct for greenfield installs — `mix sigra.install` runs once, the table is created with the column. The upgrade migration handles existing hosts. Both must be kept in sync — if the install column shape changes, the upgrade column shape must change too.

12. **Golden-diff test will fail until extended.** `test/sigra/install/golden_diff_test.exs` (existing — verify path before assuming) snapshots the install output. New schema field, new migration column, new router plug, new error handler clause, new settings LV section — all change the golden diff. Plan a Wave 0 task to regenerate the golden snapshot in lockstep with the template edits.

## Concrete File List

### NEW files (library code)

1. `lib/sigra/plug/require_org_mfa.ex` — new plug (~80-120 lines projected)
2. `lib/sigra/live_view/require_org_mfa.ex` — new on_mount (~50-70 lines projected)
3. `priv/templates/sigra.upgrade/alter_add_enforce_mfa_for_members.exs` — idempotent upgrade migration template

### MODIFIED files (library code)

4. `lib/sigra/organizations.ex` — add `set_mfa_policy/4` public function + `set_mfa_policy_changeset/2` private + new `normalize_multi_result_for_mfa_policy/1` helper + extend `__using__/1` macro at line ~280-348 to inject the 2-arity delegator

### MODIFIED files (generator templates)

5. `priv/templates/sigra.install/organizations/migration.exs` — add `enforce_mfa_for_members` column to both Postgres and MySQL/SQLite branches
6. `priv/templates/sigra.install/organizations/organization.ex` — add schema field; do NOT add to `cast/3`
7. `priv/templates/sigra.install/organizations/router_injection.ex` — extend `:org_scoped` pipeline (lines 16-20) with new plug; extend `live_session :organization_scoped` (lines 43-48) with new on_mount entry
8. `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` — add new "Security" section between General (line 64) and Slug (line 66); add event handlers `toggle_mfa_policy`, `save_mfa_policy`, `dismiss_mfa_policy`; add COUNT query in mount
9. `priv/templates/sigra.install/core/error_handler.ex` — add `auth_error(conn, :org_mfa_required, opts)` clause after `:insufficient_role` (line 60-68)

### NEW test files

10. `test/sigra/plug/require_org_mfa_test.exs` — plug unit
11. `test/sigra/live_view/require_org_mfa_test.exs` — on_mount unit
12. `test/sigra/organizations_mfa_policy_audit_atomicity_test.exs` — Postgres atomicity (mirrors `test/sigra/jwt_refresh_audit_cofate_test.exs`)
13. `test/sigra/organizations/set_mfa_policy_test.exs` — library function unit (or fold into `test/sigra/organizations/context_test.exs` if matching local convention; verify before deciding)
14. `test/example/test/example_web/integration/org_mfa_enforcement_test.exs` — generator-host integration

### MODIFIED test/planning files

15. `test/sigra/install/golden_diff_test.exs` — regenerate golden snapshot (this may be a separate test file path — verify; the existing convention for golden diffs against generator output)
16. `.planning/ROADMAP.md` — surgical edit to Phase 91 success criterion #1: `organization.mfa_policy_changed` → `organization.mfa_policy_change` (D-91-12)
17. `CHANGELOG.md` `[Unreleased]` — add B2B-01 trace bullet at phase commit
18. `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-VERIFICATION.md` — authored at phase close per ROADMAP success criterion #5

## Project Constraints (from CLAUDE.md)

- **Framework:** Phoenix 1.8+ / Ecto 3.x as blessed path. New plug + on_mount target Phoenix 1.8's stock.
- **Database:** PostgreSQL primary; the new column is plain boolean (no PG-specific features). MySQL/SQLite branches in install migration get the column too — Phase 94 will remove those branches anyway.
- **Security:** OWASP standards. Argon2id is unaffected (no password paths touched). Open-redirect prevention on `:user_return_to` per phx.gen.auth.
- **Dependencies:** Minimal transitive deps. `nimble_options` already in mix.exs (~> 1.1). `nimble_totp` already in mix.exs. No new deps for Phase 91.
- **LiveView:** Optional. New on_mount mirrors existing `OrganizationScope` bridge pattern (`:sigra_redirect_to` assign, no direct `Phoenix.LiveView.redirect/2` call) so the library stays test-loadable without LV.
- **Testing:** AAA, flat, self-contained. Phase 91 test files all match this style.
- **Project rule:** `mix test` requires live Postgres at `localhost:5432` with `postgres`/`postgres` credentials. Atomicity tests gracefully connect to existing `sigra-uat-postgres` or `sigra-test-postgres` containers.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Existing `:org_scoped` pipeline does NOT restrict `OrganizationSettingsLive` to admin/owner today; the toggle's "gated to admin" requirement (D-91-09 + ROADMAP success #1) needs a planner-added role guard | Security Domain V4 | Medium — without the guard, any member can flip the policy. Verify by reading the existing router scope wired to `OrganizationSettingsLive`. If a sub-pipeline already restricts to admin/owner, no extra work; if not, planner adds it. |
| A2 | The existing `mfa_settings_live.ex` post-enrollment-success flow already reads `:user_return_to` and redirects there | Discretion Gap 7 | Low — verified that login flow does this (user_auth.ex:67-73). Need to verify mfa_settings_live.ex enrollment-success branch does too. If not, planner adds it (one-line edit). |
| A3 | `test/sigra/install/golden_diff_test.exs` exists and is the canonical golden-diff test for generator output | Concrete File List #15 | Low — naming convention is consistent with `test/example/` pattern. Verify exact path. |
| A4 | The MySQL/SQLite branch of `migration.exs` accepts the same `add :enforce_mfa_for_members, :boolean` syntax | Concrete File List #5 | Low — basic boolean column is universal across adapters. Phase 94 will remove these branches anyway. |
| A5 | `Sigra.MFA.enabled?(config, scope.user)` returns `false` for nil/missing user gracefully (not raise) | Twin 1 (plug) | Low — verified at lib/sigra/mfa.ex:932 — guards on `%Sigra.Config{}` but accesses `user.id` without nil check. The plug call site MUST guard `is_nil(scope) or is_nil(scope.user)` before calling enabled?. Standard pattern; matches RequireMembership cond order. |
| A6 | The mixed `Repo.transaction/1` (older Organizations functions) vs `Repo.transact/1` (Passkeys, new code) convention is intentional and Phase 91 should use the new idiom for new code only | Discretion Gap 5 | Low — Phase 82 D-82-01 explicitly says "or `Repo.transact/2` if the codebase standardizes on 3.13" and Phase 85 D-85 leaves it at planner discretion. Passkeys.ex is the established new-code precedent. |

## Open Questions

1. **Should `set_mfa_policy/3` be a 4-arg public function (`config, scope, org, value`) following `update_organization/4` shape, or a 3-arg (`config, scope, value`) reading `scope.active_organization`?**
   - What we know: All existing org orchestrators take an explicit `org` argument (`update_organization/4`, `rename_organization/4`, `update_slug/4`, `soft_delete_organization/4`, `change_role/4`).
   - What's unclear: Whether the 3-arg shape would be cleaner for the LiveView call site since the LV always operates on `scope.active_organization`.
   - Recommendation: **Use 4-arg.** The generator-injected delegator (`def set_mfa_policy(scope, value), do: Sigra.Organizations.set_mfa_policy(@sigra_org_config, scope, scope.active_organization, value)`) hides the explicit `org` from host callers anyway, and keeping the public library function 4-arg matches the family.

2. **Should the LiveView call into `Organizations.set_mfa_policy(scope, value)` (the generator-injected 2-arg delegator) or via the host wrapper module pattern (`Example.Organizations.set_mfa_policy(scope, value)`)?**
   - What we know: `OrganizationSettingsLive` (the existing template) calls `Organizations.rename_organization(scope, params)` — i.e. it relies on the `use Sigra.Organizations` macro injecting the 2-arg delegator into `<%= app_module %>.Organizations`.
   - What's unclear: Nothing — the precedent is clear.
   - Recommendation: Match precedent — generator template calls `<%= app_module %>.Organizations.set_mfa_policy(scope, value)`, which delegates via the `use` macro to `Sigra.Organizations.set_mfa_policy/4` with `scope.active_organization` injected.

## Sources

### Primary (HIGH confidence — verified in this session)

- `lib/sigra/plug/require_membership.ex` (148 lines) — RequireOrgMfa structural twin, lines 72-95 (init), 126-147 (call)
- `lib/sigra/plug/require_mfa_enrolled.ex` (54 lines) — sibling plug to disambiguate from
- `lib/sigra/plug/load_active_organization.ex` (208 lines) — `:organizations` opt pattern, scope hydration source
- `lib/sigra/live_view/organization_scope.ex` (89 lines) — RequireOrgMfa on_mount structural twin, lines 40-77 + bridge pattern at line 75
- `lib/sigra/live_view/admin_scope.ex` line 25 — second confirmation of `:sigra_redirect_to` bridge pattern
- `lib/sigra/organizations.ex` lines 280-348 (`__using__` delegator block), 414-449 (update_organization), 517-542 (rename_organization), 568-612 (update_slug), 1305-1322 (normalize/append helpers)
- `lib/sigra/audit.ex` lines 222-261 (`log_multi_safe/3`), 286-302 (`emit_telemetry_from_changes/2`)
- `lib/sigra/mfa.ex` lines 921-948 (`Sigra.MFA.enabled?/2`)
- `lib/sigra/passkeys.ex` lines 13-32 (NimbleOptions schema example), 86, 114, 195, 227, 396, 407, 426 (`Repo.transact/1` precedent)
- `priv/templates/sigra.upgrade/alter_add_personal.exs` (35 lines) — idempotent upgrade migration twin
- `priv/templates/sigra.install/organizations/migration.exs` (205 lines) — install migration template
- `priv/templates/sigra.install/organizations/router_injection.ex` (53 lines) — `:org_scoped` pipeline + `live_session :organization_scoped` on_mount
- `priv/templates/sigra.install/organizations/live/organization_settings_live.ex` (339 lines) — settings LV pattern (slug section is the visual template)
- `priv/templates/sigra.install/organizations/organizations.ex` (97 lines) — wrapper module + delegator pattern
- `priv/templates/sigra.install/organizations/organization.ex` (50 lines) — schema with library-managed-not-cast field precedent (`personal` flag, line 23)
- `priv/templates/sigra.install/core/error_handler.ex` (69 lines) — error handler clause family
- `priv/templates/sigra.install/core/user_auth.ex` lines 67-73, 478, 481 — `:user_return_to` session-key precedent
- `test/sigra/jwt_refresh_audit_cofate_test.exs` (330 lines) — fault-injection test pattern (Phase 82)
- `test/sigra/plug/require_membership_test.exs` (lines 1-120 reviewed) — plug-test pattern with FakeErrorHandler
- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — D-AUD-01, D-AUD-08, D-AUD-11
- `.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-CONTEXT.md` D-82-01, D-82-02, D-82-04
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md` D-85-02
- `.planning/ROADMAP.md` lines 55-71 — Phase 91 goal + 5 success criteria
- `.planning/REQUIREMENTS.md` line 12 — B2B-01

### Secondary (HIGH confidence — verified in this session, used for context only)

- `mix.exs` — confirms `nimble_options ~> 1.1`, `nimble_totp ~> 1.0`, `argon2_elixir ~> 4.1` already declared
- `test/example/test/example_web/integration/phase_16_integration_test.exs` lines 1-100 — generator-host integration test pattern (`use ExampleWeb.ConnCase, async: false`, `register_and_log_in_user`, `create_org!` helper)

### Tertiary (LOW confidence — flagged for verification by planner)

- Existing `OrganizationSettingsLive` admin-only restriction (Assumption A1) — needs planner verification of the `:org_scoped` sub-pipeline configuration
- `mfa_settings_live.ex` post-enrollment redirect target (Assumption A2) — needs planner verification before relying on `:user_return_to` reuse

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in mix.exs and used elsewhere; no new transitive deps
- Architecture: HIGH — every pattern verified against the explicit structural-twin source files; CONTEXT.md is exhaustive
- Pitfalls: HIGH — all landmines verified by direct code reading (bridge pattern, transact/1 precedent, NimbleOptions absence in plugs, Multi.update vs Repo.update no-op semantics)

**Research date:** 2026-04-29
**Valid until:** 2026-05-29 (30 days — stack is stable; only risk is golden-diff test path drift)
