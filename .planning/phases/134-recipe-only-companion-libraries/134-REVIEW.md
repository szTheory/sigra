---
phase: 134-recipe-only-companion-libraries
reviewed: 2026-05-28T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - guides/recipes/companion-libs/accrue.md
  - guides/recipes/companion-libs/lockspire.md
  - guides/recipes/companion-libs/relyra.md
  - guides/recipes/companion-libs/rulestead.md
  - mix.exs
findings:
  critical: 5
  warning: 5
  info: 1
  total: 11
status: resolved_partial
resolved_at: 2026-05-28
resolution: 7 verified Sigra-side findings fixed (commit 826e5a0); CR-01, WR-02, WR-05, IN-01 deferred to tracked todos
---

# Phase 134: Code Review Report

**Reviewed:** 2026-05-28
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

This phase adds four adopter-facing integration recipe guides (accrue, lockspire, relyra,
rulestead) and registers them in `mix.exs` extras. The `mix.exs` edit is syntactically
sound — no trailing-comma breakage, no lost suppression entries that needed to stay.

The prose framing, architecture separation of concerns, callback arities, and cross-links are
generally correct. However, five of the copy-paste code snippets contain incorrect API calls
that will produce runtime errors in adopter applications, plus one leaks a local developer
filesystem path into published documentation. These must be fixed before the recipes ship.

## Resolution (2026-05-28)

Reviewed and verified against the live Sigra source. **7 findings fixed** in commit `826e5a0`
(`mix docs --warnings-as-errors` re-run clean, D-20 grep zero, structural checks pass):

- CR-03 (relyra) — `Sigra.Plug.put_session/2` → `MyAppWeb.UserAuth.put_user_session_token/2`
- CR-04 (relyra) — `Application.fetch_env!` keyword list → `MyApp.Auth.sigra_config()` Config struct
- CR-02 (accrue) — hooks moved from ignored `config :sigra` app-env into `Sigra.Config.new!(hooks:)`
- CR-05 (accrue) — removed hardcoded `/Users/jon/...` absolute path
- WR-04 (relyra) — `Sigra.Session.Store.*` → `Sigra.SessionStores.Ecto`
- WR-01 (relyra) — `delete_session` pinned to `/3` with config-first arg
- WR-03 (lockspire) — URI-encode `return_to` (open-redirect/injection)

**4 findings deferred** (tracked in `.planning/todos/pending/`):

- CR-01 — `Sigra.Audit.log` config-first form is documented but unimplemented (library/cross-doc
  gap; `audit-logging.md` is also wrong). → `2026-05-28-audit-log-config-first-api-gap.md`
- WR-02, WR-05 — depend on Lockspire/Rulestead sister-repo contracts not checked out here.
  → `2026-05-28-phase-134-recipe-residual-findings.md`
- IN-01 — `~> 1.29` pin is a project-wide convention matching shipped siblings, not a phase bug.
  → same residual-findings todo.

---

## Critical Issues

### CR-01: `Sigra.Audit.log/1` called with a Map — wrong arity and wrong type

**File:** `guides/recipes/companion-libs/accrue.md:81`

**Issue:** The `log_audit/2` implementation in the `Accrue.Auth` behaviour snippet calls
`Sigra.Audit.log(event_map |> Map.put(:actor_id, user.id))`. `Sigra.Audit.log` is defined
as `log(action :: String.t(), opts :: keyword())` (two arguments, first must be a string).
There is no `log/1` clause. The call will raise `UndefinedFunctionError` at runtime.
Additionally, the pipe expression `event_map |> Map.put(:actor_id, user.id)` passes
`event_map` as the first argument to `Map.put/3`, yielding an `%{}` — then that map is
passed as the sole argument to `log/1`, which does not exist.

**Fix:** Replace the incorrect call with the correct two-argument form. Because adopter
code cannot use Sigra's `AuditEvent` schema directly without its repo, the correct pattern
is to use the host-generated `Accounts.log_audit/1` wrapper or call `Sigra.Audit.log/2`
with an explicit action string and keyword options:

```elixir
@impl Accrue.Auth
def log_audit(user, event_map) do
  # Forward to Sigra's audit pipeline with the correct two-argument API.
  # event_map[:action] should be a string in "resource.verb" format.
  action = Map.get(event_map, :action) || "accrue.event"

  Sigra.Audit.log(action,
    repo: MyApp.Repo,
    audit_schema: MyApp.Accounts.AuditEvent,
    actor_id: user.id,
    metadata: Map.drop(event_map, [:action])
  )
end
```

Alternatively, delegate to the host-generated `Accounts.log_audit/2` if the host app
exposes it.

---

### CR-02: Hook configured via `config :sigra, hooks:` — not read by production deletion code

**File:** `guides/recipes/companion-libs/accrue.md:140-143`

**Issue:** The snippet instructs adopters to wire the `on_delete` hook via:

```elixir
config :sigra,
  hooks: [
    on_delete: {MyApp.AccrueHooks, :on_user_delete}
  ]
```

This sets Application environment under `:sigra` → `:hooks`. However, `Sigra.Hooks.get_hook/2`
reads from the `Sigra.Config` struct passed through `opts[:config]`, not from Application
environment. The Application env path for `:hooks` exists only in `Sigra.Testing.with_hook/3`
(test helper). In production, `Sigra.Account.schedule_deletion/3` calls
`Hooks.maybe_run_hook(:delete, ..., config)` where `config` is the `%Sigra.Config{}` struct
built by `sigra_config()`. The `config :sigra, hooks:` stanza has no effect on the production
hook dispatch path. Adopters following this snippet will silently see `on_user_delete` never
called.

**Fix:** Instruct adopters to add `hooks:` to their `sigra_config()` in the generated
`auth.ex`:

```elixir
def sigra_config do
  Sigra.Config.new!(
    repo: MyApp.Repo,
    user_schema: MyApp.Accounts.User,
    # ... existing options ...
    hooks: [
      on_delete: {MyApp.AccrueHooks, :on_user_delete}
    ]
  )
end
```

Remove the `config :sigra, hooks:` snippet entirely from the recipe.

---

### CR-03: `Sigra.Plug.put_session/2` does not exist

**File:** `guides/recipes/companion-libs/relyra.md:88`

**Issue:** The ACS callback snippet ends with:

```elixir
|> Sigra.Plug.put_session(session)
```

There is no `Sigra.Plug` top-level module, and no `put_session/2` function anywhere in the
Sigra library. This call raises `UndefinedFunctionError` at runtime. The correct pattern,
as shown in the generated `user_auth.ex` template, is to call the host-owned `UserAuth.put_user_session_token/2`
with the raw token from the session struct, or call `Plug.Conn.put_session(conn, :user_token, session.token)`
directly:

**Fix:**

```elixir
def acs(conn, %{"SAMLResponse" => saml_response} = params) do
  with {:ok, login_result} <- Relyra.consume_response(saml_response, params),
       {:ok, user} <- MyApp.Accounts.find_or_create_from_saml(login_result),
       {:ok, session} <- Sigra.Auth.create_session(MyApp.Accounts.sigra_config(), user, %{type: :saml}) do
    conn
    |> MyAppWeb.UserAuth.put_user_session_token(session.token)
    |> redirect(to: "/dashboard")
  else
    {:error, reason} ->
      conn
      |> put_flash(:error, "SSO login failed: #{inspect(reason)}")
      |> redirect(to: "/users/log-in")
  end
end
```

Note: `session.token` is the raw token (populated only at create time per `Sigra.Session`
docs). Store it with `:user_token` in the Plug session, not the session struct itself.

---

### CR-04: `Application.fetch_env!(:my_app, :sigra)` passed directly to `create_session/4` — type mismatch

**File:** `guides/recipes/companion-libs/relyra.md:82`

**Issue:** The ACS snippet fetches config as:

```elixir
sigra_config = Application.fetch_env!(:my_app, :sigra)
```

and passes it directly to `Sigra.Auth.create_session(sigra_config, user, %{type: :saml})`.
`create_session/4` is typed `(Sigra.Config.t(), struct(), map(), keyword())`. Application
environment typically stores a raw keyword list, not a `%Sigra.Config{}` struct. Passing
a keyword list where a struct is expected will cause either a `FunctionClauseError` or
silent failures when `create_session/4` calls `config.repo` (struct field access on a
keyword list raises `KeyError`).

The generated `auth.ex` template never reads Sigra config from Application env — it builds
the struct explicitly via `Sigra.Config.new!()` in `sigra_config()`.

**Fix:** Replace the Application env fetch with a call to the host-generated config builder:

```elixir
def acs(conn, %{"SAMLResponse" => saml_response} = params) do
  with {:ok, login_result} <- Relyra.consume_response(saml_response, params),
       {:ok, user} <- MyApp.Accounts.find_or_create_from_saml(login_result),
       {:ok, session} <- Sigra.Auth.create_session(MyApp.Accounts.sigra_config(), user, %{type: :saml}) do
    ...
```

---

### CR-05: Hardcoded local developer filesystem path in published documentation

**File:** `guides/recipes/companion-libs/accrue.md:47`

**Issue:** The following absolute path is embedded in the published adopter guide:

```
(`/Users/jon/projects/accrue/accrue/lib/accrue/auth.ex:41-49`)
```

This is a developer artifact from a local checkout. It will render in hexdocs as a
meaningless absolute path that does not exist on any adopter's machine. It also reveals
the local development environment layout.

**Fix:** Replace with a relative reference or a description of the canonical Accrue source
location:

```markdown
(see `Accrue.Auth` in the Accrue source — `lib/accrue/auth.ex` lines 41–49).
```

Or if an external link is appropriate:

```markdown
(see [`Accrue.Auth` on GitHub](https://github.com/sztheory/accrue/blob/main/lib/accrue/auth.ex#L41-L49)).
```

---

## Warnings

### WR-01: `Sigra.Auth.delete_session/2` — wrong arity reference

**File:** `guides/recipes/companion-libs/relyra.md:130`

**Issue:** The SLO failure-mode section says:

> invalidate the Sigra session by calling `Sigra.Auth.delete_session/2` with the session token

The actual function signature is:

```elixir
@spec delete_session(Sigra.Config.t(), binary(), keyword()) :: :ok
def delete_session(config, hashed_token, opts \\ []) do
```

This is a 3-argument function (`/3`) with an optional third arg. The minimum call requires
two positional arguments — `config` and `hashed_token` — making `/2` an incorrect reference.
Adopters who call `Sigra.Auth.delete_session/2` by looking up the function by arity
will fail to find it.

**Fix:** Change to `Sigra.Auth.delete_session/3` and add a code example:

```elixir
Sigra.Auth.delete_session(MyApp.Accounts.sigra_config(), hashed_token)
```

---

### WR-02: `resolve_account/2` returns bare user or `nil` — likely violates callback contract

**File:** `guides/recipes/companion-libs/lockspire.md:93-95`

**Issue:** The `AccountResolver` snippet implements `resolve_account/2` as:

```elixir
def resolve_account(account_reference, _context) do
  MyApp.Accounts.get_user(account_reference)
end
```

The generated `MyApp.Accounts.get_user/1` returns a `%User{}` struct or `nil`. Lockspire's
`AccountResolver` behaviour (described as pinned to `lockspire/lib/lockspire/host/account_resolver.ex:14-39`)
almost certainly expects `{:ok, user} | {:error, :not_found}` as the return value for
resolution callbacks, matching standard Elixir callback contracts for failable lookups.
Returning `nil` from a callback that Lockspire pattern-matches on `{:ok, _}` will cause
a `FunctionClauseError` or `MatchError` at runtime when a token exchange references a user
who exists.

Since Lockspire source is not available in this repo for verification, this is flagged as a
high-probability runtime error.

**Fix:**

```elixir
@impl Lockspire.Host.AccountResolver
def resolve_account(account_reference, _context) do
  case MyApp.Accounts.get_user(account_reference) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end
```

---

### WR-03: Unvalidated `context.return_to` in open redirect

**File:** `guides/recipes/companion-libs/lockspire.md:107-109`

**Issue:** The `redirect_for_login/2` implementation interpolates `context.return_to` directly
into a URL:

```elixir
def redirect_for_login(conn, context) do
  Phoenix.Controller.redirect(conn, to: "/users/log-in?return_to=#{context.return_to}")
end
```

`Phoenix.Controller.redirect(conn, to: path)` does not validate or restrict the value of
`path`. If `context.return_to` contains an absolute URL such as `https://evil.com` or a
`javascript:` URI, and if Lockspire builds `context.return_to` from a user-supplied
`redirect_uri` or query parameter, this becomes an open redirect. The snippet provides no
validation, and adopters copying it verbatim inherit the risk. Even if Lockspire sanitizes
this internally today, the recipe should model defensive practice.

Additionally, the raw string interpolation does not URI-encode `return_to`, so values
containing `&`, `=`, or `#` will silently corrupt the query string.

**Fix:**

```elixir
@impl Lockspire.Host.AccountResolver
def redirect_for_login(conn, context) do
  # Validate return_to is a relative path before embedding in the URL.
  return_to =
    case context.return_to do
      "/" <> _ = path -> URI.encode(path)
      _ -> "/dashboard"
    end

  Phoenix.Controller.redirect(conn, to: "/users/log-in?return_to=#{return_to}")
end
```

---

### WR-04: `Sigra.Session.Store.*` — wrong namespace reference

**File:** `guides/recipes/companion-libs/relyra.md:125`

**Issue:** The failure-mode section instructs adopters to:

> confirm the Sigra session store (`Sigra.Session.Store.*`) is configured

The correct module namespace is `Sigra.SessionStores.*` (plural, flat). The only concrete
implementation is `Sigra.SessionStores.Ecto`. There is no `Sigra.Session.Store` module.
Adopters searching for `Sigra.Session.Store` in hexdocs will find nothing.

**Fix:** Change to `Sigra.SessionStores.Ecto` (or `Sigra.SessionStores.*` if referring to
the namespace generically):

```markdown
confirm the Sigra session store (`Sigra.SessionStores.Ecto` is the default) is
configured via the `session: [store: ...]` key in `Sigra.Config.new!/1`.
```

---

### WR-05: `RulesteadPolicy` missing `@behaviour` declaration

**File:** `guides/recipes/companion-libs/rulestead.md:140-153`

**Issue:** The `RulesteadPolicy` module snippet has no `@behaviour Rulestead.Policy` (or
equivalent) declaration. Without it, adopters get no compile-time callback verification.
If Rulestead adds, renames, or changes the arity of the `can?/4` callback in a future
version, the mismatch will not surface until runtime.

The pattern established in `accrue.md` (which correctly uses `@behaviour Accrue.Auth`) and
`lockspire.md` (which uses `@behaviour Lockspire.Host.AccountResolver`) should be followed
here for consistency and safety.

**Fix:**

```elixir
defmodule MyApp.RulesteadPolicy do
  @behaviour Rulestead.Policy  # or whatever the correct behaviour module name is

  @impl Rulestead.Policy
  def can?(%{roles: roles}, action, _resource, _environment_key) do
    ...
  end
end
```

---

## Info

### IN-01: Recipe `mix.exs` dep snippets pin `sigra ~> 1.29` but library is at `0.3.0`

**File:** `guides/recipes/companion-libs/accrue.md:30`, `lockspire.md:38`,
`relyra.md:47`, `rulestead.md:38`

**Issue:** All four recipe `mix.exs` snippets show `{:sigra, "~> 1.29"}`, but the
library's current published version (per `mix.exs` `@version`) is `0.3.0`. The `~> 1.29`
version does not exist on Hex. Adopters copying the snippet will receive a dependency
resolution error immediately.

This appears intentional (the recipes are written for a future stable version), but the
current mismatch means the recipes cannot be used today without manual correction. At
minimum, a note should clarify that the version shown is the target minimum, and adopters
should use the latest published version.

**Fix:** Either update the pinned version to the current published version, or add a note:

```markdown
> **Version note:** Replace `~> 1.29` with the latest Sigra version on
> [hex.pm/packages/sigra](https://hex.pm/packages/sigra).
```

---

_Reviewed: 2026-05-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
