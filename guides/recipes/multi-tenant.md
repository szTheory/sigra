# Multi-Tenant Apps

Sigra does not ship multi-tenancy as a first-class feature, but the hybrid lib+generator architecture makes it easy to add. This recipe covers the two common models — **row-based tenancy** (everything in one database, `tenant_id` column) and **schema-based tenancy** (one Postgres schema per tenant, using `Ecto.Adapters.SQL.query/4` with a dynamic `search_path`) — and where Sigra's sessions, tokens, and audit events plug in.

> **Roadmap note:** true multi-tenant org membership (one user in many organizations with distinct roles per org) is planned for a future Sigra release. This recipe covers what you can build today with primitives.

## Model 1: Row-based tenancy

Every row carries a `tenant_id`. Queries filter by it. Simple, flexible, good for SaaS apps where users belong to exactly one tenant.

### Step 1: Add tenant_id to users

    mix ecto.gen.migration add_tenant_id_to_users

    defmodule MyApp.Repo.Migrations.AddTenantIdToUsers do
      use Ecto.Migration

      def change do
        alter table(:users) do
          add :tenant_id, references(:tenants, type: :binary_id), null: false
        end

        create index(:users, [:tenant_id])
        create unique_index(:users, [:email, :tenant_id])
        drop unique_index(:users, [:email])
      end
    end

Note the composite unique index: the same email can now exist in two tenants. Drop the old single-column unique index if it exists.

### Step 2: Add tenant_id to the User schema

    schema "users" do
      field :email, :string
      field :tenant_id, Ecto.UUID
      # ...
    end

    def registration_changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :password, :tenant_id])
      |> validate_required([:tenant_id])
      |> Sigra.User.registration_changeset(attrs)
    end

### Step 3: Propagate through session tokens

Session tokens reference the user by ID, so they naturally carry the tenant. But when you look up a token, you must also filter by tenant to prevent cross-tenant token reuse (if an attacker gets a token from tenant A, it must not validate in tenant B).

Extend `get_user_by_session_token/1` in the generated `Accounts` context:

    def get_user_by_session_token(token, tenant_id) do
      {:ok, query} = UserToken.verify_session_token_query(token)
      query
      |> where([t, u], u.tenant_id == ^tenant_id)
      |> Repo.one()
    end

And thread `tenant_id` through `UserAuth.fetch_current_scope/2`:

    def fetch_current_scope(conn, _opts) do
      tenant_id = get_tenant_from_host(conn)
      {user_token, conn} = ensure_user_token(conn)
      user = user_token && Accounts.get_user_by_session_token(user_token, tenant_id)

      assign(conn, :current_scope, %Scope{user: user, tenant_id: tenant_id})
    end

### Step 4: Resolve tenant from the request

Common patterns:

- **Subdomain:** `acme.myapp.com` → `tenant_slug = "acme"`
- **Path prefix:** `/t/acme/...`
- **Custom domain:** `app.acme.com` → lookup by host

    defp get_tenant_from_host(conn) do
      [subdomain | _] = String.split(conn.host, ".")
      Repo.get_by!(Tenant, slug: subdomain).id
    end

### Step 5: Scope all queries

Use `Sigra.Scope` (or a plain Ecto query helper) to scope every subsequent query:

    defmodule MyApp.Scope do
      def for_tenant(query, tenant_id) do
        from x in query, where: x.tenant_id == ^tenant_id
      end
    end

    Project
    |> MyApp.Scope.for_tenant(current_scope.tenant_id)
    |> Repo.all()

Forgetting the scope is a data leak. Consider using Ecto's `prepare_query` callback to inject the scope automatically — but be careful: the auto-scope must not break Sigra's own queries against `users`, `users_tokens`, and `audit_events` (those already filter by `user_id`).

### Step 6: Audit events

Add `tenant_id` to your generated `AuditEvent` schema so audit queries can be scoped:

    def audit_for_tenant(tenant_id, opts) do
      Sigra.Audit.query(config(), opts)
      |> where([e], e.tenant_id == ^tenant_id)
    end

Pass `tenant_id` through `metadata` in `Sigra.Audit.log/2` calls (or extend the schema with a first-class column).

## Model 2: Schema-based tenancy

One Postgres schema per tenant. The connection's `search_path` determines which schema queries hit. Strong isolation, good for compliance-heavy apps, harder to operate (schema migrations must run per tenant).

### The Ecto setup

Use a prefix-aware repo:

    defmodule MyApp.Repo do
      use Ecto.Repo, otp_app: :my_app, adapter: Ecto.Adapters.Postgres

      @impl true
      def default_options(_operation) do
        [prefix: Process.get(:tenant_schema) || "public"]
      end
    end

Then in a plug before `fetch_current_scope`:

    defp set_tenant_schema(conn, _opts) do
      tenant = Tenants.resolve(conn.host)
      Process.put(:tenant_schema, "tenant_#{tenant.id}")
      conn
    end

Every query (including Sigra's `users`, `users_tokens`, `audit_events`) now hits the tenant's schema. Run migrations per tenant with `Ecto.Migrator.run/4` and `:prefix`.

### Caveats

- Sigra's `:repo` config option is a module, not a repo+prefix pair. If you need per-request prefix override, set it via `Process.put(:tenant_schema, ...)` before the plug chain reaches Sigra, or run a custom repo wrapper.
- Cross-tenant queries (admin dashboards, aggregate metrics) require explicit `prefix: "tenant_..."` on every call.
- `mix sigra.install` generates a single migration for the `public` schema. For N tenants, you must replay the migration against each schema.

## Which model to choose

| Criterion | Row-based | Schema-based |
|-----------|-----------|--------------|
| Operational simplicity | Simple (one schema, one migration) | Complex (N schemas, N migrations) |
| Query ergonomics | Must scope every query | Automatic via `search_path` |
| Isolation strength | Weaker — one missed scope leaks data | Stronger — schema boundary is hard |
| Backup / restore per tenant | Hard | Easy (`pg_dump -n tenant_42`) |
| Good fit | Most SaaS apps | Compliance-heavy, per-tenant backups |

Start with row-based unless you have a specific compliance or backup requirement. You can always migrate later.

## Testing

    test "users from tenant A cannot log in to tenant B" do
      tenant_a = tenant_fixture(slug: "alpha")
      tenant_b = tenant_fixture(slug: "beta")
      user = user_fixture(tenant_id: tenant_a.id)

      conn =
        build_conn()
        |> Map.put(:host, "beta.myapp.test")
        |> post(~p"/users/log-in", %{"user" => %{"email" => user.email, "password" => "password1234"}})

      assert get_flash(conn, :error) =~ "Invalid"
    end

## Related

- [Custom User Fields](custom-user-fields.html) — adding `tenant_id` is a custom-field workflow.
- [Subdomain Authentication](subdomain-auth.html) — subdomain-based tenant resolution needs `cookie_domain`.
- [Audit Logging](audit-logging.html) — scoping audit queries by tenant.
