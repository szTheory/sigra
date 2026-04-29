# Phase 92: RBAC Seams (B2B-02) - Pattern Map

**Mapped:** 2026-04-29  
**Phase inputs found:** none under `.planning/phases/92-rbac-seams-b2b-02/` at mapping time  
**Scope basis:** inferred from the Phase 92 brief and current repo seams  
**Analogs found:** 11 strong matches

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/scope.ex` | utility | request-response transform | `lib/sigra/scope.ex` | exact |
| `priv/templates/sigra.install/core/scope.ex` | template/model | request-response transform | `priv/templates/sigra.install/core/scope.ex` | exact |
| `priv/templates/sigra.install/core/user_auth.ex` | template/hook | request-response + LiveView parity | `priv/templates/sigra.install/core/user_auth.ex` | exact |
| `lib/sigra/plug/put_active_organization.ex` or new RBAC hydration seam | plug/service seam | request-response | `lib/sigra/plug/put_active_organization.ex` | role-match |
| new library behaviour module for RBAC host policy | behaviour | request-response contract | `lib/sigra/admin/policy.ex` | exact |
| generated default host RBAC policy implementation | template/config | request-response contract | `priv/templates/sigra.install/admin/policy.ex` | exact |
| generated host wrapper exposing RBAC helpers | template/service | request-response wrapper | `priv/templates/sigra.install/organizations/organizations.ex` | exact |
| installer feature wiring for RBAC files/templates/migrations | feature/config | file-I/O + batch | `lib/sigra/install/feature.ex`, `lib/sigra/install/features/organizations.ex` | exact |
| installer runner coverage / golden proof | test | file-I/O + batch | `test/sigra/install/golden_diff_test.exs`, `test/sigra/install/idempotency_test.exs` | exact |
| scope template invariant coverage | test | transform | `test/sigra/install/scope_template_fields_test.exs`, `test/sigra/install/scope_template_invariants_test.exs` | exact |
| RBAC recipe / guide docs | docs | transform | `guides/recipes/multi-tenant.md`, `test/sigra/guides_dx02_test.exs`, `mix.exs` docs config | exact |

## Pattern Assignments

### `lib/sigra/scope.ex` and `priv/templates/sigra.install/core/scope.ex`

**Primary analogs:** `lib/sigra/scope.ex:16-25`, `:46-71`; `priv/templates/sigra.install/core/scope.ex:22-38`, `:58-83`

**Pattern to copy:** keep the library scope helper reflection-based and keep the host struct explicit.

```elixir
# lib/sigra/scope.ex
def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
  struct(scope_module,
    user: user,
    active_organization: Keyword.get(opts, :active_organization),
    membership: Keyword.get(opts, :membership),
    impersonating_from: Keyword.get(opts, :impersonating_from)
  )
end
```

```elixir
# priv/templates/sigra.install/core/scope.ex
defstruct user: nil,
          active_organization: nil,
          membership: nil,
          impersonating_from: nil
```

**Expected edit points:**
- Add any new RBAC seam field to the generated `%Scope{}` explicitly, not via hidden macro injection.
- If Phase 92 adds a new library-side helper, mirror `from_opts/2` / `from_config/2` in `lib/sigra/scope.ex:46-71`: tolerate absent config and return `nil` rather than raising.
- Preserve the current contract that worker/library-only scope reconstruction is minimal and not authoritative authz state (`lib/sigra/scope.ex:2-14`).

**Guard rails already enforced by tests:**
- `test/sigra/scope/build_test.exs:17-50` covers additive field propagation.
- `test/sigra/install/scope_template_fields_test.exs:14-59` and `test/sigra/install/scope_template_invariants_test.exs:9-62` grep and compile the template shape directly.

### Scope hydration and Plug/LiveView parity

**Primary analogs:** `test/sigra/scope/hydration_test.exs:65-239`, `test/sigra/scope/plug_liveview_parity_test.exs:73-280`, `priv/templates/sigra.install/core/user_auth.ex:231-254`

**Pattern to copy:** centralize request-time enrichment in one pure/hydrator path, then reuse it from both Plug and LiveView.

```elixir
# priv/templates/sigra.install/core/user_auth.ex
defp build_current_scope(user, session, admin_user) do
  user
  |> Scope.for_user()
  |> hydrate_scope(session)
  |> maybe_put_impersonating_from(admin_user)
end

defp hydrate_scope(scope, session) do
  org_config = <%= app_module %>.Organizations.__sigra_org_config__()

  case Sigra.Scope.Hydration.hydrate(scope, org_config, session) do
    {:ok, hydrated} -> hydrated
    {:error, _reason} -> scope
  end
end
```

**Expected edit points:**
- If Phase 92 introduces RBAC seam hydration, hook it into the same `build_current_scope/3` path rather than adding separate Plug-only or LiveView-only enrichment.
- Reuse the Phase 14 parity test shape: happy path, nil pointer path, stale/rejected path.
- Keep stale-pointer recovery boundaries explicit: parity at the hydrator/result layer, recovery only where a `conn` exists (`test/sigra/scope/plug_liveview_parity_test.exs:240-280`).

### Single authoritative write / mutation seam

**Primary analog:** `lib/sigra/plug/put_active_organization.ex:1-127`

**Pattern to copy:** one library choke point owns a mutable authz-adjacent transition; host wrappers call into it; no ad-hoc writes elsewhere.

```elixir
case Organizations.get_membership(config, scope.user, org) do
  nil ->
    {:error, :not_a_member}

  membership ->
    with {:ok, refreshed} <- session_store.update_active_organization(session, org.id, store_opts) do
      new_scope = scope_module.put_active_organization(scope, org, membership)
      {:ok, conn |> Plug.Conn.put_private(:sigra_session, refreshed) |> Plug.Conn.assign(:current_scope, new_scope)}
    end
end
```

**Expected edit points:**
- If Phase 92 adds a “set current role / permissions / authz seam” operation, model it after this file: validate first, write once, update `conn.private` and `assigns` together.
- Keep the seam as a function-call contract, not necessarily a Plug callback (`put_active_organization.ex:12-15`).
- Document explicitly what the seam does **not** do, mirroring `:26-31`.

### Behaviour module + generated host implementation

**Primary analogs:** `lib/sigra/admin/policy.ex:1-50`, `priv/templates/sigra.install/admin/policy.ex:1-27`

**Pattern to copy:** library defines a tiny explicit behaviour; generator emits a host-owned stub that implements it with safe defaults and TODOs.

```elixir
# lib/sigra/admin/policy.ex
@callback platform_admin?(scope :: term()) :: boolean()
@callback admin_org_ids(scope :: term()) :: [term()]
```

```elixir
# priv/templates/sigra.install/admin/policy.ex
@behaviour Sigra.Admin.Policy

def platform_admin?(scope) do
  _ = scope
  false
end

def admin_org_ids(scope) do
  _ = scope
  []
end
```

**Expected edit points:**
- New RBAC library seam should follow this contract shape: minimal callbacks, explicit defaults, zero hidden role inference.
- Generated host default must compile as-is and refuse by default.
- If the library offers helper functions, copy the `admin_org_ids_from_memberships/2` posture from `lib/sigra/admin/policy.ex:23-50`: helpers are opt-in and never run automatically.

### Generated host wrapper over library RBAC functions

**Primary analog:** `priv/templates/sigra.install/organizations/organizations.ex:27-118`

**Pattern to copy:** generated wrapper uses the library macro/config once, then exposes thin, host-readable helper functions.

```elixir
use Sigra.Organizations,
  repo: <%= repo_module %>,
  schemas: [...],
  audit_schema: <%= context_module %>.AuditEvent

def set_active_organization(conn, org) do
  Sigra.Plug.PutActiveOrganization.call(conn, org, [])
end
```

**Expected edit points:**
- If Phase 92 generates a host policy/context wrapper, keep it in the host app and keep functions thin and explicit.
- Prefer real functions over fragile `defdelegate` when the target arity/options do not line up; this exact regression is called out in `test/sigra/install/features/organizations_test.exs:127-138`.

### Installer feature ownership and isolation

**Primary analogs:** `lib/sigra/install/feature.ex:1-64`, `lib/sigra/install/features/organizations.ex:24-30`, `:148-260`

**Pattern to copy:** treat RBAC as an additive feature/template owner with strict boundary discipline.

**Copy these rules:**
- Feature module implements `Sigra.Install.Feature`.
- `files/1` owns emitted templates.
- `migrations/1` owns migration slots.
- injection-only templates are read from disk and evaluated before splicing.
- feature source does not reference sibling features.

**Expected edit points:**
- Put any new host templates under one RBAC-owned subtree.
- If a template is reference-only and should not compile standalone, document the non-registration rationale as explicitly as `organizations.ex:134-145`.
- If injection content contains EEx placeholders, evaluate it before injection, matching `organizations.ex:216-239`.

### Generator golden-diff and idempotency coverage

**Primary analogs:** `test/sigra/install/golden_diff_test.exs:1-188`, `test/sigra/install/idempotency_test.exs:1-130`, `mix.exs:130-136`

**Pattern to copy:** any install-surface RBAC change must preserve both byte-level fixture parity and second-run idempotency.

**Planner should reuse:**
- Golden tree + `STDOUT.txt` diff assertions from `golden_diff_test.exs:53-80`.
- File-set/content mismatch diagnostics from `golden_diff_test.exs:148-188`.
- Second-run zero-write / zero-new-file / stable-mtime assertions from `idempotency_test.exs:37-90`.
- Alias coverage through `mix.exs:134-136` (`mix ci.install_golden`).

### Template ownership / drift lint

**Primary analogs:** `test/sigra/install/features/coverage_test.exs:1-209`, `test/sigra/install/features/organizations_test.exs:13-23`, `:58-145`

**Pattern to copy:** template additions need an ownership test, not just render tests.

**Planner should reuse:**
- “every file under subtree is owned” assertion from `coverage_test.exs:159-203`.
- explicit injection-template existence assertions from `organizations_test.exs:13-23`.
- direct source grep tests for new template functions/copy from `organizations_test.exs:102-138`.

### Docs / recipe structure that compiles under docs checks

**Primary analogs:** `mix.exs:152-223`, `test/sigra/guides_dx02_test.exs:20-299`, `guides/recipes/multi-tenant.md:1-139`

**Pattern to copy:** docs changes are part of the contract. A new recipe/guide must be wired into ExDoc extras and structural tests.

**Copy these rules:**
- Add the file to `mix.exs` `extras` and keep it grouped consistently (`mix.exs:160-213`).
- Keep guide references resolvable by real `Sigra.*` APIs or template-backed helpers (`guides_dx02_test.exs:149-212`).
- Follow the existing recipe posture: direct statement of shipped model, explicit non-goals, concrete code snippets, testing section, related links (`guides/recipes/multi-tenant.md:7-139`).

**Expected edit points:**
- If Phase 92 adds `guides/recipes/rbac-*.md` or similar, extend `GuidesDx02Test` expectations if it becomes part of the measured set.
- Do not add docs that mention non-existent APIs unless the test allow-list is deliberately updated with justification.

## Shared Patterns

### Scope field evolution must be additive and explicit

**Sources:** `lib/sigra/scope.ex:16-25`, `priv/templates/sigra.install/core/scope.ex:22-38`, `test/sigra/install/scope_template_fields_test.exs:14-59`

Apply to any new scope field or helper:
- library helper populates known keys only
- generated struct declares the field explicitly
- tests grep the template source and, when needed, compile the rendered module

### Plug and LiveView must share the same authz enrichment logic

**Sources:** `priv/templates/sigra.install/core/user_auth.ex:231-254`, `test/sigra/scope/plug_liveview_parity_test.exs:180-280`

Apply to any RBAC hydration:
- one central hydrate/build path
- parity tests compare Plug and LiveView outputs for the same session state
- recovery differences are documented as boundary differences, not silent divergences

### Behaviour seams must be explicit and host-owned by default

**Sources:** `lib/sigra/admin/policy.ex:3-16`, `priv/templates/sigra.install/admin/policy.ex:3-26`

Apply to any new RBAC policy/role behaviour:
- no inferred admin/platform role from email, signup order, or hidden fallback
- generated default returns deny/empty values
- library helper functions remain opt-in

## Role Patterns That Must NOT Leak Into The New Library Seam

### Organization membership roles are a tenant-membership concern, not a generic RBAC primitive

**Sources:** `lib/sigra/plug/require_membership.ex:16-40`, `:56-117`; `test/sigra/plug/require_membership_test.exs:23-37`, `:115-139`, `:188-225`

Do **not** copy these semantics into a generic RBAC seam:
- the canonical org role universe `[:owner, :admin, :member]`
- host-extended org role lists via `organizations.__sigra_org_config__().roles`
- “admin does NOT imply owner” as a global RBAC hierarchy rule
- direct dependence on `scope.membership.role` as the only role carrier

These belong to organization membership authorization specifically.

### Admin access policy is explicit and separate from organization membership

**Sources:** `lib/sigra/admin/policy.ex:5-16`, `priv/templates/sigra.install/admin/router_injection.ex:1-78`

Do **not** let a new generic RBAC seam automatically absorb:
- platform-admin checks
- org-admin path routing
- admin route topology

The admin surface already models a separate policy seam and should stay decoupled from generic request scope hydration.

### Multi-tenant data isolation is separate from RBAC

**Source:** `guides/recipes/multi-tenant.md:93-133`

Do **not** conflate:
- membership/role checks
- query scoping via `Sigra.Organizations.Query.for_org/2`

The new seam should preserve that split: authz decides who may act; query helpers decide which rows are visible.

## No Exact Analog / Planner Notes

| Target | Closest starting point | Why no exact analog exists |
|---|---|---|
| new generic RBAC behaviour + generated host stub | `Sigra.Admin.Policy` + `priv/templates/sigra.install/admin/policy.ex` | current repo has admin-policy and org-membership seams, but no generic RBAC library seam yet |
| new RBAC scope field beyond `membership` / `active_organization` | `lib/sigra/scope.ex` + `priv/templates/sigra.install/core/scope.ex` | current scope is org-aware and impersonation-aware only |
| dedicated RBAC guide/recipe | `guides/recipes/multi-tenant.md` | no RBAC-specific guide exists yet |

## Metadata

**Analog search scope:** `lib/`, `priv/templates/sigra.install/`, `guides/`, `test/sigra/`, prior `.planning/phases/` artifacts  
**High-value prior artifacts:** `91-PATTERNS.md`, `30-PATTERNS.md`, `41-PATTERNS.md`, `91-VERIFICATION.md`  
**Recommended verification surfaces for Phase 92 planner:**  
- `test/sigra/scope/build_test.exs`  
- `test/sigra/scope/hydration_test.exs`  
- `test/sigra/scope/plug_liveview_parity_test.exs`  
- `test/sigra/install/scope_template_fields_test.exs`  
- `test/sigra/install/scope_template_invariants_test.exs`  
- `test/sigra/install/features/coverage_test.exs`  
- `test/sigra/install/features/organizations_test.exs`  
- `test/sigra/install/golden_diff_test.exs`  
- `test/sigra/install/idempotency_test.exs`  
- `test/sigra/guides_dx02_test.exs`
