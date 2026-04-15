# Sigra Conventions

Project-wide conventions for Sigra contributors. These are not rules the
compiler enforces — they are the discipline that keeps the library's
security guarantees real.

## Organization Scoping (DX-09)

Sigra's multi-tenancy model rests on one invariant: **every query that
touches an `organization_id`-bearing schema must be scoped to the caller's
active organization**. Violations cause cross-tenant data leaks (Pitfall
O-1 in the v1.1 research).

Sigra enforces this with two layers.

### Layer 1 — `for_org/2` (primary)

Every context function that reads an org-scoped resource must pass the
query through `Sigra.Organizations.Query.for_org/2` before handing it to
the Repo:

```elixir
# Good
Post
|> Sigra.Organizations.Query.for_org(scope)
|> Repo.all()

# Bad — reads every org's posts
Repo.all(Post)
```

`for_org/2` accepts either a `%Scope{}` (reads `scope.active_organization.id`)
or a raw binary organization ID. It raises `ArgumentError` if the schema
does not have an `:organization_id` field, so bugs surface at the call
site instead of leaking data.

This is the layer contributors see. Discipline here is what keeps the
library correct.

### Layer 2 — `prepare_query/3` (defense-in-depth)

If a contributor forgets Layer 1, `Sigra.Organizations.Query.maybe_enforce_org_scope/4`
catches the omission at Repo time via the host app's generated
`prepare_query/3` callback. It inspects the query's WHERE expressions for
an `organization_id` filter and raises `ArgumentError` if the schema is in
the enforced list and no filter is present.

This layer is load-bearing: it makes cross-tenant leaks loud in
development and test even when Layer 1 is forgotten. Do not rely on it as
the primary guard — the error message at a missing `for_org/2` call is
much clearer than an error at the Repo.

### Escape hatch — `skip_org_check: true`

Some queries are legitimately unscoped: admin dashboards, cross-tenant
analytics, the installer's schema inspection. Pass `skip_org_check: true`
in Repo opts to bypass Layer 2:

```elixir
# Legitimate: admin dashboard listing all orgs
Repo.all(Organization, skip_org_check: true)
```

Every `skip_org_check: true` call site is a documented exception.
Reviewers should push back on new usages that are not admin-scoped,
installer-scoped, or audit-scoped.

### WHERE-clause heuristic (T-13-08)

Layer 2's filter detection walks the query's WHERE expression AST looking
for references to an `:organization_id` field. This is a heuristic, not a
prover:

- It recognizes direct comparisons (`r.organization_id == ^org_id`) and
  references nested inside compound boolean expressions.
- It can **false-positive** on cross-tenant joins
  (`r.organization_id == r2.organization_id`) and on `is_nil(r.organization_id)`.
  Neither of these constrains the query to a specific tenant, but the
  heuristic will pass them through.
- On inspection failure (malformed AST, future Ecto version changes), it
  logs a warning and passes the query through to avoid false positives.

The heuristic's limitations are accepted per the Phase 13 threat model
(T-13-08, disposition: accept) because Layer 1 is the primary enforcement
and Layer 2 is defense-in-depth. If a tighter check becomes feasible
(e.g., pinned-literal matching), revisit the threat model before
tightening — false positives on valid queries would be worse than the
current accepted false-positive-on-join gap.

---

**References:**
- `lib/sigra/organizations/query.ex` — `for_org/2` + `maybe_enforce_org_scope/4`
- `.planning/phases/13-organizations-schemas-context/13-03-PLAN.md` — D-24 decision
- Phase 13 threat model (T-13-08)
