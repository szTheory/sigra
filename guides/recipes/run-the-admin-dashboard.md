# Run the admin dashboard locally

You want to *see* what Sigra's admin dashboard looks like before deciding what to customize. This recipe walks you through the example app's admin surface in five minutes.

> **Quick win, with a known gap:** the example app's seed data is currently empty, so the dashboard you see is an *unpopulated* admin. SEED-007 in `.planning/seeds/` tracks the realistic-data seeder; until then, you'll create a few users by hand to see the surface come alive.

---

## Prerequisites

- Elixir ~> 1.18, OTP 27+
- A running PostgreSQL on `localhost:5432` with `postgres`/`postgres` credentials
  - Disposable container: `docker run -d --name sigra-test-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16-alpine`

## Boot the example app

From the repo root:

```bash
cd test/example
mix deps.get
mix ecto.create && mix ecto.migrate
mix phx.server
```

The example app is a real Phoenix 1.8 app whose generated code is the executable contract for `mix sigra.install`. It starts on `http://localhost:4000`.

## Get an admin user

The seeds file is empty today (see SEED-007 for the realistic seeder). Two options:

1. **Register through the UI** — visit `http://localhost:4000/users/register` and create an account. By default new accounts aren't admins; promote yourself in IEx:

   ```bash
   iex -S mix phx.server
   ```

   ```elixir
   user = Example.Repo.get_by!(Example.Accounts.User, email: "you@example.com")
   user
   |> Ecto.Changeset.change(role: :admin)  # or whatever your admin gate uses
   |> Example.Repo.update!()
   ```

2. **Use a test fixture** — `test/example/test/support/fixtures/auth_fixtures.ex` has helpers you can call from IEx to seed a user with realistic state.

## Tour the admin surface

Once signed in as admin, the surface lives at `/admin`. Ten LiveViews:

| Path | What it shows |
|---|---|
| `/admin` | Dashboard landing — high-level health |
| `/admin/users` | Users index — search, filter, sort |
| `/admin/users/:id` | User detail — sessions, MFA, OAuth identities, audit timeline |
| `/admin/users/:id/audit` | Per-user audit explorer |
| `/admin/audit` | Global audit explorer — actor, action, resource, metadata |
| `/admin/webhooks` | Webhook subscriptions index |
| `/admin/webhooks/failures` | Failed/dead-lettered webhook deliveries (replay surface) |
| `/admin/organizations/:org` | Org-scoped admin landing |
| `/admin/organizations/:org/members` | Org membership management |
| `/admin/organizations/:org/audit` | Org-scoped audit |

### Things to actually try

- **Trigger an audit event** — sign out, sign back in, then watch the entry land in `/admin/audit` with full metadata.
- **Inspect a session** — visit `/admin/users/:id`; the Sessions panel shows device, IP, last-active, and a revoke button.
- **Impersonate** — start an impersonation from the user-detail page. The banner appears at the top of every page you visit. Stop and restore from the banner. Both events land in `/admin/audit` as a dual-actor pair.
- **Provoke a webhook failure** — register a webhook subscription pointed at `https://httpbin.org/status/500`. Trigger an event. Watch it land in `/admin/webhooks/failures` with retry/lineage state. Replay it.

## Preview the auth emails too

The admin walkthrough pairs naturally with the email preview. Visit `/dev/mailbox` (Plug.Swoosh.MailboxPreview) after triggering any flow — registration, password reset, magic link — to see the email Sigra sent. Full recipe: [Preview the auth emails](preview-auth-emails.html).

## Known gaps

- **Empty demo data** — the dashboard reads thin under no users. SEED-007 (`.planning/seeds/SEED-007-admin-demo-seeder.md`) tracks the planned `mix sigra.example.seed` task with realistic scenarios.
- **No URL for "log in as admin"** — until the seeder ships, you have to register + manually promote.

## Customizing

The admin LiveViews live under `lib/sigra/admin/live/` in the library — you don't generate or edit them in the host today. If you need divergence (different columns, different impersonation policy), the `Sigra.Authz` behaviour (see [RBAC recipe](role-based-access-control.html)) is the seam. For deeper changes, treat the admin surface as a starting point you can fork or layer over with your own LiveViews.
