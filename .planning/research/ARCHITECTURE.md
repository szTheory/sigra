# Architecture Research — Sigra v1.1 Foundations Integration Plan

**Confidence:** HIGH (grounded in read of v1.0 code at `/Users/jon/projects/sigra/`). Every recommendation references concrete v1.0 file:line.
**Researched:** 2026-04-11

---

## Part A — Organizations

### A1. `organization_id` travel through the request lifecycle

**v1.0 baseline (grounded):**
- `Sigra.Plug.FetchSession` (`lib/sigra/plug/fetch_session.ex:62-98`) reads `:user_token` from Plug session, fetches `%Sigra.Session{}`, assigns `current_scope` (built via `scope_module.new/1`), stashes session at `conn.private[:sigra_session]`.
- Example's `fetch_current_scope/2` (`test/example/lib/example_web/user_auth.ex:128-142`) does equivalent directly against `Example.Accounts.get_user_and_session_by_token/1`.
- LiveView `on_mount` (`user_auth.ex:193-231`) reconstructs scope from serialized `session["user_token"]` in `mount_current_scope/2`.
- `Sigra.Plug.RequireSudo` (`lib/sigra/plug/require_sudo.ex:57-85`) reads `conn.private[:sigra_session]`, NOT the assign — canonical pattern for downstream plugs.

**v1.1 extension — concrete changes:**

**1. Scope struct extension** (`test/example/lib/example/accounts/scope.ex:15-38`):

```elixir
defstruct user: nil,
          active_organization: nil,  # NEW v1.1
          membership: nil,           # NEW v1.1 (role/status for active_organization)
          impersonating_from: nil    # RESERVED for v1.2 — DO NOT populate in v1.1
```

Adding `impersonating_from: nil` in v1.1 makes v1.2 purely additive on pattern matches. Generator template at `priv/templates/sigra.install/scope.ex` must emit all three fields.

**2. `Sigra.Session` schema extension** (`lib/sigra/session.ex:64-78`):

Add ONE field: `field :active_organization_id, :binary_id  # nullable`

New migration via install-injected `alter table(:user_sessions)`. See A4 for rationale.

**3. New plug `Sigra.Plug.LoadActiveOrganization`** (library, new):

```elixir
def call(conn, opts) do
  case conn.assigns[:current_scope] do
    nil -> conn
    scope ->
      session = conn.private[:sigra_session]
      scope = Organizations.hydrate_scope(scope, session, opts)
      assign(conn, :current_scope, scope)
  end
end
```

Runs AFTER `fetch_current_scope`. Loads `active_organization` from `session.active_organization_id`, loads membership row, falls back to "first membership" if session pointer is stale. No DB hit if user has zero memberships.

**4. `on_mount` hydration** — add to generated `user_auth.ex`. Store `active_organization_id` in the **Plug session** on org switch (mirrors how `:mfa_pending` is mirrored at `fetch_session.ex:90-94`) so LiveView mount receives it in serialized `session` map.

**5. Audit auto-attach** — modify `Sigra.Audit.build_attrs/4` (`lib/sigra/audit.ex:384-404`). Add scope-aware helper:

```elixir
def metadata_from_scope(scope, extra \\ %{}) do
  base = %{}
  base = if scope && scope.active_organization,
    do: Map.put(base, :organization_id, scope.active_organization.id),
    else: base
  # RESERVED for v1.2:
  # base = if scope && scope.impersonating_from,
  #   do: Map.put(base, :effective_user_id, scope.user.id),
  #   else: base
  Map.merge(base, extra)
end
```

**Better long-term:** promote `organization_id` to a real column on `audit_events` in v1.1. Makes filtering index-friendly and v1.2 per-org audit views trivial. Recommend: **add `organization_id :binary_id` column + index**, populate from `metadata_from_scope`. Leave room for v1.2's `effective_user_id` column alongside.

**6. Oban job args — org context preservation:** Pattern: every library-emitted worker accepts `args["organization_id"]` and `args["actor_id"]`. Enqueuer passes `metadata_from_scope(scope)` flattened. Workers reconstruct minimal `%Scope{}` (user + active_organization loaded from DB) for audit calls. **Explicit is better than automatic middleware.** Document as D-v1.1: Oban workers carry `organization_id` in args; reconstruct scope on perform.

**7. Email delivery — org context:** Generated `emails.ex` template grows one optional parameter per builder: `build_password_reset_email(user, url, opts)` where `opts[:organization]` is optional. Template renders "Password reset for [email] in [org.name]" only when non-nil. Absent `:organization` renders v1.0 body verbatim. **No breaking change.**

---

### A2. Correct Ecto query pattern — `organization_id` does NOT live on `users`

**WRONG (tempting, broken):**

```elixir
# DO NOT DO THIS
schema "users" do
  field :organization_id, :binary_id  # WRONG — users are shared across orgs
end
```

Forces one-user-per-org, makes "same email at two companies" impossible — table-stakes B2B requirement.

**RIGHT — many-to-many via memberships:**

```elixir
schema "organizations" do
  field :name, :string
  field :slug, :string          # unique
  field :settings, :map         # jsonb
  field :deleted_at, :utc_datetime
  has_many :memberships, OrganizationMembership
  many_to_many :users, User, join_through: OrganizationMembership
  timestamps()
end

schema "organization_memberships" do
  belongs_to :user, User
  belongs_to :organization, Organization
  field :role, Ecto.Enum, values: [:owner, :admin, :member]
  field :status, Ecto.Enum, values: [:active, :invited, :suspended]
  field :joined_at, :utc_datetime
  belongs_to :invited_by, User, foreign_key: :invited_by_id
  timestamps()
end
```

Unique index on `(user_id, organization_id)`. Last-owner guard is **application-level** in `Sigra.Organizations.remove_membership/2`, not DB constraint.

**Example queries:**

```elixir
# Users in an org
from u in User,
  join: m in OrganizationMembership, on: m.user_id == u.id,
  where: m.organization_id == ^org_id and m.status == :active

# Orgs for a user (for switcher)
from o in Organization,
  join: m in OrganizationMembership, on: m.organization_id == o.id,
  where: m.user_id == ^user_id and m.status == :active and is_nil(o.deleted_at),
  order_by: [asc: o.name]

# Canonical scope-aware query: app resources embed organization_id
from p in Post,
  where: p.organization_id == ^scope.active_organization.id
```

---

### A3. Org switcher placement in Phoenix 1.8 layouts

**Current layout** (`test/example/lib/example_web/components/layouts.ex:36-70`) is `<header class="navbar">` with flex-1 brand + flex-none action list. Standard Phoenix 1.8 scaffold.

**Insertion point:** Inside `<div class="flex-none">`, before existing `<ul>`, add a LiveComponent org switcher (daisyUI `dropdown`, already in use in v1.0 MFA pages).

**NOT a modal** (wrong for frequent action). **NOT a sidebar** (doesn't exist; adding one clashes with v1.2 admin dashboard layout).

**Dropdown shows:** active org name + role badge, separator, other orgs (click = switch), separator, "Create organization", "Organization settings" (owner/admin only).

**Why LiveComponent not function component:** switching orgs needs to POST to a controller action (not LV event) to rotate the Plug session. Use `<.form action={~p"/orgs/switch"}>` inside the dropdown.

---

### A4. Active-org storage — recommendation: **session column**

| Option | Pros | Cons |
|---|---|---|
| **`active_organization_id` on `user_sessions`** | Session-lifetime scope. Survives reloads. Atomic with rotation. One row write on switch. | One column per session row. |
| `user_active_orgs` table (one per user) | Persists across logins. | Single global active org — wrong model. Race conditions. Extra table. |
| Signed cookie | Zero DB writes. | Lost on logout. Tab-desynced. Cookie bloat. Can't invalidate remotely. |

**Recommend: session column.** Matches v1.0 session-centric model (`lib/sigra/session.ex` already carries per-session state: `sudo_at`, `ip`, `geo_*`). Multi-tab: each tab has own Plug session. Aligns with v1.2 impersonation (also per-session).

**Multi-tab nuance:** v1.1 scope is single active org per session. Per-tab isolation via LiveView `connect_params` — document as v1.2+ enhancement.

---

### A5. Route scoping — recommendation: **session-only, no URL prefix**

| Option | Pros | Cons |
|---|---|---|
| **Session-only** | No route explosion. Zero changes to v1.0 routes. Bookmarks work. | URLs don't disclose active org. |
| `/orgs/:slug/...` prefix | Shareable per-org links. Multi-tab coherent via URL. | Every v1.0 route needs sibling. LiveView plumbing. Conflicts with non-org resources. |

**Recommend: session-only for v1.1.** Every v1.0 route stays byte-identical. `Sigra.Plug.RequireMembership` asserts session active org matches expected. v1.2's admin dashboard can introduce `/admin/orgs/:slug/...` as separate scope without disruption. Revisit v1.3 if users demand shareable org-scoped URLs.

---

### A6. v1.0 email templates — what changes

| Email | v1.1 change |
|---|---|
| Password reset | Subject unchanged. Body adds `<p :if={@organization}>Account: [email] — member of [@organization.name]</p>` above reset link. |
| Email confirmation | No change (user-identity, not org-bound). |
| Suspicious login | Add active org to body. |
| Account deletion | No change. |
| **NEW** org invitation | New template `organization_invitation_email.ex` — invite link with HMAC token, org name, inviter name, expiry. |

All additive via optional `opts[:organization]`. v1.0 call sites that don't pass it render unchanged.

---

### A7. Migration path — recommendation: **auto-backfill personal orgs**

| Option | Pros | Cons |
|---|---|---|
| **Auto-backfill personal org per user** | Zero-friction upgrade. `scope.active_organization` never nil post-migration. Simplifies downstream code. | Users who didn't want MT get vestigial org. |
| Require explicit create/join | Clean slate. | Breaking: v1.0 users log in post-upgrade with `nil` active org. Every LV needs "no org" branch. |

**Recommend: auto-backfill, opt-out via `--no-backfill-personal-orgs`.** Generator emits idempotent migration. Adapter-branch for MySQL/SQLite per existing `sigra.install.ex:89` pattern. Users can rename/delete personal orgs post-backfill.

**Backfill slug edge case:** users sharing email casing under citext. Slugify on lowercased email + 8-char hash for uniqueness.

---

## Part B — Passkeys

### B1. Passkey challenge storage — recommendation: **signed+encrypted Plug session**

| Option | Pros | Cons |
|---|---|---|
| **Plug session (signed+encrypted)** | Zero new infra. Uses `Plug.Crypto` (already in `Sigra.Token`). Auto-cleanup on session end. No TTL worker. Multi-node safe. | Cookie size (~50 bytes b64). |
| ETS with TTL | Fast, no cookie. | Single-node only — breaks multi-node. Needs supervisor + cleanup timer. |
| DB table with TTL | Multi-node safe. | Extra migration + schema + cleanup Oban job. Overkill for 60s ephemeral state. |

**Recommend: Plug session under `:passkey_challenge`.** Phoenix's Plug session is already signed; wrap via `Sigra.Token.generate/4` with purpose `"sigra-passkey-challenge"`, `max_age: 60`. Matches how v1.0 stashes `:mfa_pending` (`fetch_session.ex:90`).

**Store shape:** `%{challenge: binary, user_id: id | nil, mode: :registration | :authentication, inserted_at: iso8601}`.

---

### B2. RP ID + origin — **runtime configuration is mandatory**

Compile-time forces separate build per environment (dev/staging/prod/PR-review apps). **Runtime is non-negotiable.** Follow v1.0 pattern at `user_auth.ex:36-45` which resolves `cookie_domain` at runtime.

```elixir
# config/runtime.exs
config :sigra, :passkeys,
  rp_id: System.get_env("PASSKEY_RP_ID", "localhost"),
  rp_name: System.get_env("PASSKEY_RP_NAME", "MyApp"),
  origin: System.get_env("PASSKEY_ORIGIN", "http://localhost:4000"),
  attestation: :none,  # default per spec/OWASP
  timeout_ms: 60_000
```

Validate via `NimbleOptions` inside `Sigra.Passkeys.config/0` for fast-fail at first use.

---

### B3. Passkey credentials — schema + ceremony trace

**New generated schema** `user_passkeys`:

```elixir
schema "user_passkeys" do
  belongs_to :user, User
  field :credential_id, :binary           # unique — raw credential id bytes
  field :public_key, MyApp.Accounts.Encrypted.Binary  # cloak_ecto encrypted
  field :sign_count, :integer, default: 0
  field :aaguid, :binary                  # authenticator model
  field :nickname, :string                # user-facing name
  field :device_hint, :string             # UA-derived
  field :transports, {:array, :string}    # ["internal", "usb", "nfc"]
  field :last_used_at, :utc_datetime
  timestamps()
end
```

Unique index on `credential_id`. `public_key` reuses existing Cloak vault at `priv/templates/sigra.install/encrypted.ex` (wired for OAuth tokens in v1.0 — zero-new-infra reuse).

**End-to-end registration ceremony:**

1. Client loads `PasskeyEnrollmentLive` → pushes `"init_registration"` event
2. LiveView calls `Sigra.Passkeys.Registration.new_challenge(user, opts)`:
   - `Wax.new_registration_challenge/1` produces `%Wax.Challenge{}`
   - Signed via `Sigra.Token.generate/4` (`max_age: 60`), written to Plug session
   - Client options map returned to JS hook
3. JS hook invokes `navigator.credentials.create({publicKey: options})` → returns credential
4. JS hook pushes `"complete_registration"` with credential JSON
5. LiveView reads challenge from Plug session, calls `Sigra.Passkeys.Registration.verify/4`:
   - `Wax.register/3` verifies attestation
   - On success, `Sigra.Audit.log_multi_safe/3` with action `"passkey.register"` inside an `Ecto.Multi` that inserts the `UserPasskey` row (mirrors atomic-multi pattern at `Sigra.Auth.create_session/4`)
6. Email notification via `emails.ex` "New passkey added" (reuses suspicious-login shape)

**Authentication** mirrors steps with `Wax.authenticate_new_challenge/1` + `Wax.authenticate/5`, then delegates to `Example.Accounts.generate_user_session_token/2` path. Login remains POST per D-29 (never LiveView event) — see B5.

---

### B4. `Sigra.Plug.PasskeyChallenge` placement

**After `fetch_current_scope`**, before route handler. Registration requires authenticated user; authentication uses `current_scope == nil` to decide passkey-as-primary vs passkey-as-2FA branches.

**Better: scoped plug**, only in `/users/passkeys/*` scope, not pipeline-wide. Keeps cost zero for non-passkey requests.

---

### B5. JS hooks pattern — first in Sigra, propose the convention

**v1.0 has zero JS hooks** (confirmed by `ls test/example/assets/js`). Propose:

**Template layout (new):**

```
priv/templates/sigra.install/passkeys/assets/js/
  passkey_hooks.js          # exports { PasskeyRegister, PasskeyAuthenticate }
```

Generator installs to `assets/js/passkey_hooks.js` and **injects into** `assets/js/app.js`:

```javascript
import { PasskeyRegister, PasskeyAuthenticate } from "./passkey_hooks"
let Hooks = { PasskeyRegister, PasskeyAuthenticate }
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, ... })
```

Injection uses same `inject_into_files/2` pattern already proven at `sigra.install.ex:332+` (router injection). Guard with marker comment for idempotent re-runs.

**Hook shape (enrollment):**

```javascript
export const PasskeyRegister = {
  mounted() {
    this.handleEvent("passkey:create", async ({ options }) => {
      try {
        const publicKey = decodePublicKeyOptions(options)
        const credential = await navigator.credentials.create({ publicKey })
        this.pushEvent("passkey:registered", encodeCredential(credential))
      } catch (err) {
        this.pushEvent("passkey:error", { message: err.message })
      }
    })
  }
}
```

**Critical — D-29 (login via POST, not LV event):** authentication hook **cannot** complete login via `push_event` because logging in requires rotating the Plug session, which LV events cannot do (they run over the socket, not HTTP). Pattern: LiveView collects assertion, posts it to plain controller (`POST /users/passkeys/authenticate`) via hidden form auto-submitted from JS. Mirrors v1.0's "login is plain controller" (`sigra.install.ex:254-263`, `router.ex:53`). Document as **D-v1.1-passkey-login-post**.

---

## Part C — Cross-Cutting

### C1. Conditional generator template pattern — **subdirectory + feature manifest hybrid**

**Recommend: subdirectory convention + small Elixir feature manifest module.**

```
priv/templates/sigra.install/
  core/           # always generated (v1.0 files move here)
    user.ex
    auth.ex
    ...
  organizations/  # generated when :organizations opt true
    organization.ex
    organization_membership.ex
    organization_invitation.ex
    organization_switcher_live.ex
    ...
  passkeys/       # generated when :passkeys opt true
    user_passkey.ex
    passkey_enrollment_live.ex
    passkey_hooks.js
    ...
```

Each subdir has tiny manifest module implementing shared behaviour:

```elixir
defmodule Sigra.Install.Features.Organizations do
  @behaviour Sigra.Install.Feature

  def enabled?(opts), do: Keyword.get(opts, :organizations, true)

  def files(binding) do
    otp = binding[:otp_app]
    ctx = binding[:context_underscore]
    [
      {:eex, "organizations/organization.ex",
       Path.join(["lib", otp, ctx, "organization.ex"])},
      # ...
    ]
  end

  def injections(binding), do: [...]
end
```

`sigra.install.ex` walks `[Features.Core, Features.Organizations, Features.Passkeys, Features.Admin]`, collects files where `enabled?/1` true. Main `generate/4` (`sigra.install.ex:83-319`) shrinks — less duplication, clearer feature boundaries.

**Why this unblocks v1.2:** adding `--no-admin` = add `Features.Admin` module + `admin/` subdir. No rework. **Load-bearing for v1.2.**

**Migration plan for v1.1:** introduce feature behaviour + subdirs, move v1.0 flat templates into `core/` in one mechanical PR (paths only, no content changes). Then add organizations/passkeys as features on top.

---

### C2. New test helpers needed

| Helper | Signature | Where |
|---|---|---|
| `create_organization/1` | `(attrs \\ %{}) :: %Organization{}` | `organization_fixtures.ex` (new) |
| `create_membership/3` | `(user, org, attrs \\ %{role: :member}) :: %OrganizationMembership{}` | `organization_fixtures.ex` |
| `log_in_user_with_org/3` | `(conn, user, org) :: conn` — wraps `log_in_user/2` + sets session `active_organization_id` | `conn_case_helpers.ex` |
| `register_passkey/2` | `(user, opts \\ []) :: %UserPasskey{}` — inserts fake passkey via Wax test vectors | `passkey_fixtures.ex` (new) |
| `authenticate_with_passkey/2` | `(conn, user) :: conn` — mimics POST-authenticate without browser | `conn_case_helpers.ex` |
| `assert_scope_has_org/2` | `(conn_or_socket, org_or_id)` | `Sigra.Testing` library module |
| `assert_membership/3` | `(user, org, role)` | `Sigra.Testing` |
| `assert_audit_logged_for_org/2` | filters on metadata.organization_id | `Sigra.Testing` |

---

## Part D — Build Order (Dependency-Respecting)

Hard deps:

1. **Phase 1 — Generator feature system** (C1 subdirs + behaviour). Blocks everything. Skeleton + routing layer, no templates moved yet.
2. **Phase 2 — Scope struct + session column extension**. `:active_organization`, `:membership`, `:impersonating_from` fields + `user_sessions.active_organization_id` column. Mechanical, no business logic. Unblocks all org-aware plugs/LVs.
3. **Phase 3 — Organizations schemas + context** (`Organization`, `OrganizationMembership`, `OrganizationInvitation`, `Sigra.Organizations`). Pure data layer.
4. **Phase 4 — Org plugs + scope hydration** (`LoadActiveOrganization`, `RequireMembership`, `on_mount` hydration). Needs 2 + 3.
5. **Phase 5 — Audit integration** (`metadata_from_scope`, `organization_id` column, `:organization_id` query filter). Needs 4.
6. **Phase 6 — Org LiveViews + switcher** (Switcher, Settings, Members, InvitationAccept). Needs 3, 4, 5.
7. **Phase 7 — Org invitation flow + email template**. Uses `Sigra.Token.generate_hashed_token/0` unchanged. Needs 6.
8. **Phase 8 — Backfill migration + generator wiring for `--organizations`**. Needs 7.
9. **Phase 9 — Passkey schema + `Sigra.Passkeys.*` contexts**. Independent of orgs. Can start any time after phase 1. Depends on `wax_` dep addition.
10. **Phase 10 — `PasskeyChallenge` plug + runtime config + JS hooks infra**. Needs 9.
11. **Phase 11 — Passkey LiveViews + POST-auth controller**. Needs 10.
12. **Phase 12 — Generator wiring for `--passkeys`**. Needs 11.
13. **Phase 13 — Docs, CI smoke extension, guides**.

**Parallelizable:** phases 9-11 (passkey track) can run in parallel with phases 3-7 (org track) once phase 1 + 2 land. Phases 8 and 12 are serialization points.

---

## Part E — v1.2 Forward-Compatibility Checklist

Every recommendation checked against v1.2:

| v1.1 decision | v1.2 impact | Forward-compatible? |
|---|---|---|
| `Scope.impersonating_from: nil` reserved | v1.2 populates in new `Sigra.Plug.Impersonate` | YES (additive) |
| `audit_events.organization_id` as real column | v1.2 adds `effective_user_id` alongside | YES (additive migration) |
| Active org on `user_sessions` | v1.2 impersonation also per-session; co-locates | YES |
| Session-only routes (no `/orgs/:slug`) | v1.2 admin UI introduces `/admin/*` cleanly | YES |
| Subdirectory generator feature pattern | v1.2 adds `admin/` feature module trivially | YES — **load-bearing** |
| Dropdown org switcher in header | v1.2 admin UI can add second dropdown | YES |
| `Sigra.Audit.Query` org filter via column | v1.2 audit views filter on real indexed columns | YES |

**Zero v1.1 decisions require v1.2 to revisit.**

---

## Part F — Confidence & Open Questions

**HIGH confidence** (grounded in read):
- v1.0 plug ordering and scope mechanics (`fetch_session.ex`, `user_auth.ex`, `require_sudo.ex`)
- Generator mechanics (`sigra.install.ex`, `priv/templates/sigra.install/`)
- Audit composability (`audit.ex`, `audit/query.ex`)
- Layout insertion point (`layouts.ex:36-70`)
- Session struct extension site (`session.ex:64-78`)
- Token + HMAC patterns (`token.ex`)

**MEDIUM confidence** (ecosystem knowledge, not verified against wax_ 0.7 docs in this session):
- Exact `Wax.Challenge` struct shape and API in 0.7 — phase 9 kickoff should include 30-min Context7 verify of `Wax.register/3`, `Wax.authenticate/5`, attestation options before writing `Sigra.Passkeys.Registration`
- `aaguid` field type — `:binary` correct per WebAuthn spec; wax_ may return UUID string — verify at phase 9 start

**Open questions for the planner:**
1. **Phase 5 audit:** should `organization_id` on `audit_events` be `NOT NULL` or nullable? Library-emitted events with no active org (password reset from logged-out state) need nullable.
2. **Phase 10 JS hooks:** does host app's `assets/js/app.js` always exist at known path? Phoenix 1.8 default yes, but esbuild vs Webpack vs Vite affects injection target. Propose: only inject if marker present; otherwise print manual instructions.
3. **Phase 11 passkey-as-primary:** is usernameless resident-key flow worth the UX complexity for v1.1, or defer to v1.2? Discovery credentials need `residentKey: required` and different `allowCredentials` handling.
4. **Backfill migration idempotency:** slug collision handling for users sharing email casing under citext — slugify on lowercased email + 8-char hash.

---

## Files referenced

- `/Users/jon/projects/sigra/.planning/PROJECT.md`
- `/Users/jon/projects/sigra/test/example/lib/example/accounts/scope.ex`
- `/Users/jon/projects/sigra/test/example/lib/example_web/user_auth.ex`
- `/Users/jon/projects/sigra/test/example/lib/example_web/router.ex`
- `/Users/jon/projects/sigra/test/example/lib/example_web/components/layouts.ex`
- `/Users/jon/projects/sigra/lib/sigra/session.ex`
- `/Users/jon/projects/sigra/lib/sigra/audit.ex`
- `/Users/jon/projects/sigra/lib/sigra/audit/query.ex`
- `/Users/jon/projects/sigra/lib/sigra/plug/fetch_session.ex`
- `/Users/jon/projects/sigra/lib/sigra/plug/require_sudo.ex`
- `/Users/jon/projects/sigra/lib/sigra/token.ex`
- `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex`
- `/Users/jon/projects/sigra/priv/templates/sigra.install/` (44 files — to be restructured in Phase 1)
