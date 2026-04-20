# Multi-Tenant Apps

Sigra now ships logical multi-tenancy through organizations. The model is row-based: one database, shared tables, explicit `organization_id` scoping, and a current scope that carries the active organization and membership for the signed-in user.

This guide is about the posture Sigra actually ships. It does not ask you to build PG schema-per-tenant around Sigra itself.

## The shipped model: logical multi-tenancy

The default install gives you:

- `organizations`
- `organization_memberships`
- `organization_invitations`
- `active_organization_id` on the session row
- `%Scope{active_organization: ..., membership: ...}`

The working rule is simple: data owned by an organization gets an `organization_id` column, and application queries must scope through the active organization before they hit the repo.

## Scope queries with `for_org/2`

`Sigra.Organizations.Query.for_org/2` is the primary query helper:

    def list_projects(scope) do
      Project
      |> Sigra.Organizations.Query.for_org(scope)
      |> Repo.all()
    end

It also accepts a raw organization ID:

    def list_projects_for(org_id) do
      Project
      |> Sigra.Organizations.Query.for_org(org_id)
      |> Repo.all()
    end

Use it on every org-owned schema. If a schema does not have an `organization_id` field, `for_org/2` raises immediately instead of silently pretending the query is safe.

## What "logical multi-tenancy" means in Sigra

Logical multi-tenancy means:

- one Postgres database
- one shared schema for Sigra's auth tables
- org ownership represented by rows and foreign keys
- per-request access controlled by membership plus scoped queries

That is the default and recommended posture for Sigra-powered SaaS apps. It keeps the generated auth system, audit trail, and sessions in one coherent runtime model.

## Why Sigra rejects PG schema-per-tenant for itself

PG schema-per-tenant can be a valid architecture for some products, but Sigra does not treat it as its own multi-tenant primitive.

Reasons:

- the generated auth surface assumes one shared auth schema
- per-tenant schema migration orchestration is operationally heavier
- cross-org membership, invitations, passkeys, and audit workflows are simpler in a shared-schema model
- a missed `search_path` or prefix edge can create confusing partial isolation

In other words: Sigra supports logical multi-tenancy directly. If your product later needs PG schema-per-tenant for app-specific data, layer that on deliberately in your own code instead of expecting Sigra to run that model for auth.

## Add `organization_id` to your own schemas

For app-owned tenant data, add an `organization_id` foreign key and index it:

    def change do
      create table(:projects, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :organization_id, references(:organizations, type: :binary_id), null: false
        add :name, :string, null: false

        timestamps(type: :utc_datetime)
      end

      create index(:projects, [:organization_id])
    end

Then keep repo access behind scope-aware functions:

    def create_project(scope, attrs) do
      %Project{}
      |> Project.changeset(Map.put(attrs, :organization_id, scope.active_organization.id))
      |> Repo.insert()
    end

    def list_projects(scope) do
      Project
      |> Sigra.Organizations.Query.for_org(scope)
      |> Repo.all()
    end

## Membership is authorization, `for_org/2` is data isolation

Keep those jobs separate:

- membership and role checks decide who is allowed to act
- `for_org/2` decides which rows a query can see

Do not rely on controller params, slugs, or UI state alone. The active organization in scope should drive both authorization and query scoping.

## Audit and session implications

Sigra's org-aware runtime can carry `active_organization_id` in the session and attach `organization_id` to audit metadata. That gives you a consistent tenant story across:

- browser sessions
- organization switching
- invitation acceptance
- org-scoped audit review

Keep your app-owned audit queries aligned with the same org boundary.

## Testing

Add direct regression around the scoping helper:

    test "for_org/2 only returns rows for the active organization" do
      org_a = organization_fixture()
      org_b = organization_fixture()
      scope = scope_fixture(active_organization: org_a)

      project_fixture(organization_id: org_a.id, name: "visible")
      project_fixture(organization_id: org_b.id, name: "hidden")

      projects =
        Project
        |> Sigra.Organizations.Query.for_org(scope)
        |> Repo.all()

      assert Enum.map(projects, & &1.name) == ["visible"]
    end

Also keep route-level tests for membership requirements. Query helpers make data isolation shorter to express; they do not replace full request coverage.

## Related

- [Getting Started](getting-started.html) — the default organizations and passkeys walkthrough.
- [Passkeys](passkeys.html) — passkey-primary login and recovery posture inside an org-aware app.
- [Testing Auth Flows](testing.html) — fixtures and helpers for auth-heavy integration tests.
