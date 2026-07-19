# Sigra code walkthrough

This is the inside-out companion to [Sigra architecture](architecture.html). Keep one
value route in mind: **install inputs → generated host boundary → `%Sigra.Config{}` →
login params → user and typed auth result → raw browser token plus hashed session →
hydrated scope and committed audit evidence**.

> #### Reading contract {: .warning}
>
> Generated modules, reference-host examples, private functions, and internal modules
> appear here to explain the current implementation. They are not promised as Sigra's
> public API. For runtime code, begin at the documented module and use its HexDocs
> **View Source** link; for generated code, inspect the corresponding module in your
> own host application.

## 1. The installer hands one binding to a feature walker

The install task owns Phoenix-specific discovery: names, adapter, schema prefix, and
feature switches. Its feature list and handoff are intentionally small.

```elixir
@features [
  Sigra.Install.Features.Core,
  Sigra.Install.Features.Organizations,
  Sigra.Install.Features.Passkeys,
  Sigra.Install.Features.Admin
]

# ...

def run(args) do
  {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
  opts = Keyword.merge(@default_opts, opts)

  case parsed do
    [context_name, schema_name, table_name] ->
      validate_args!(context_name, schema_name, table_name)
      binding = build_binding(context_name, schema_name, opts[:table] || table_name, opts)
      {:ok, _report} = Runner.run(@features, binding, opts)
    # ...
  end
end
```

The binding is a generation-time value. It never becomes a hidden runtime container.

## 2. The runner applies only enabled features

`Sigra.Install.Runner.run/3` is feature-agnostic. It filters, allocates and overlays
migration timestamps, threads a report through three callbacks, and returns evidence
of what happened.

```elixir
def run(features, binding, opts) when is_list(features) and is_list(binding) do
  active = Enum.filter(features, fn f -> f.enabled?(opts) end)
  base_time = Keyword.get(opts, :base_time, DateTime.utc_now())
  allocated = MigrationTimestamps.allocate(active, base_time)
  resolved_ts = overlay_existing_migrations(active, allocated)

  report =
    Enum.reduce(active, Report.new(), fn feature, r ->
      feature_binding = Keyword.put(binding, :migration_timestamps, resolved_ts[feature] || %{})

      r
      |> run_files(feature, feature_binding)
      |> run_injections(feature, feature_binding)
      |> run_post_instructions(feature, feature_binding)
    end)

  {:ok, report}
end
```

`run_files/3` creates only absent files; injection code distinguishes newly injected
from already present content. The resulting source and migrations are now host-owned.

## 3. Runtime configuration is an explicit struct

The runtime does not rediscover a host Repo or schema on every call. `Sigra.Config`
validates options once and carries the application seam as a struct.

```elixir
defstruct [
  :repo,
  :user_schema,
  :otp_app,
  :secret_key_base,
  :scope_module,
  :organizations_module,
  :mailer,
  :email_module,
  # ...
  session: [],
  lockout: [],
  mfa: [],
  audit: []
]

def new!(opts) when is_list(opts) do
  validated = NimbleOptions.validate!(opts, @schema)
  struct!(__MODULE__, validated)
end
```

The required Repo and user schema establish persistence. The callbacks and nested
feature options tell generic code where host policy begins.

## 4. The generated context supplies those callbacks

The reference host demonstrates a fully wired configuration. A generated application
will have its own module names and may choose fewer integrations.

```elixir
def sigra_config do
  Sigra.Config.new!(
    repo: Example.Repo,
    user_schema: User,
    scope_module: Example.Accounts.Scope,
    organizations_module: Example.Organizations,
    branding: [
      product_name: "Tasklane",
      # ...
      theme: :system
    ],
    session: [
      store: Sigra.SessionStores.Ecto,
      session_schema: Example.Accounts.UserSession
    ],
    lockout: [
      threshold: 5,
      duration: 900
    ],
    audit: [
      audit_schema: Example.Accounts.AuditEvent,
      # ...
    ],
    passkeys: [
      # ...
      rp_id: passkey_rp_id(),
      # ...
      user_passkey_schema: Example.Accounts.UserPasskey
    ]
  )
end
```

This is the central host-to-runtime adapter. When tracing surprising behavior, compare
the value passed here with the defaults documented by `Sigra.Config`.

## 5. HTTP stays in the generated controller

The generated controller owns parameter shape, flash messages, redirects, and the
enumeration-safe public failure. It delegates credential policy to the host context.

```elixir
defp create(conn, %{"user" => user_params}, info) do
  %{"email" => email, "password" => password} = user_params

  case Auth.authenticate_user(email, password) do
    {:ok, user} ->
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)

    {:error, :sso_required, %{organization_slug: slug}}
    when is_binary(slug) and slug != "" ->
      conn
      |> put_flash(:error, "Your organization requires enterprise sign-in.")
      |> redirect(to: ~p"/organizations/#{slug}/sso?#{%{routing_source: "local_policy"}}")

    _ ->
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
  end
end
```

Notice that the controller expects `{:ok, user}`, not the richer runtime success.

## 6. The generated context currently collapses session metadata

The next seam is easy to miss. `Sigra.Auth.authenticate/3` can return the user plus a
session map, but the generated wrapper currently reduces both success shapes to the
same two-tuple.

```elixir
def authenticate_user(email, password)
    when is_binary(email) and is_binary(password) do
  case SigraAuth.authenticate(sigra_config(), %{"email" => email, "password" => password}) do
    {:ok, user} -> {:ok, user}
    {:ok, user, _session_meta} -> {:ok, user}
    {:error, :sso_required} -> typed_local_auth_denial(email, :sso_required)
    {:error, reason} -> {:error, reason}
  end
end
```

That discarded value matters in step 10. It is documented current implementation
drift, not a public return-shape recommendation.

## 7. Lockout precedes password verification

The config path normalizes the identifier, loads the host user, derives audit context,
and checks lockout before invoking the password hasher. A missing user still reaches
`Crypto.verify_with_upgrade/2` with a nil hash so the public path does comparable work.

```elixir
defp authenticate_with_config(config, params) do
  # ...

  email =
    (params["email"] || params[:email] || "")
    |> Email.normalize()
  login_ip = params["ip"] || params[:ip]
  user = repo.get_by(config.user_schema, email: email)
  # ...

  case Sigra.Lockout.check(user, lockout_opts) do
    {:error, :account_locked, _remaining} ->
      # ...
      {:error, :account_locked}

    :ok ->
      password = params["password"] || params[:password] || ""
      hashed_password = user && Map.get(user, :hashed_password)

      case Crypto.verify_with_upgrade(password, hashed_password) do
        {:ok, :valid} ->
          handle_enterprise_password_login(
            config,
            repo,
            user,
            require_confirmation,
            audit_opts,
            login_ip,
            %{},
            %{method: "password"}
          )
        # ...
      end
  end
end
```

The full branch turns verification results into enterprise-policy decisions and typed
failures; it does not reveal whether an unknown email was the cause.

## 8. Successful login work and audit insertion share a Multi

When auditing is configured, lockout reset and any hash upgrade are composed with the
audit row. The caller owns the transaction and emits forwarding telemetry only from
the committed branch.

```elixir
defp login_success_repo_and_audit_multi(config, user, extra_changes, audit_opts, metadata) do
  base_audit =
    Keyword.merge(
      audit_opts,
      audit_scope_column_opts(Sigra.Scope.from_config(config, user))
    )

  Multi.new()
  |> Multi.run(:login_repo_work, fn r, _changes ->
    u = Sigra.Lockout.reset!(r, user)

    if map_size(extra_changes) > 0 do
      cs = Ecto.Changeset.change(u, extra_changes)

      case r.update(cs) do
        {:ok, u2} -> {:ok, u2}
        {:error, _} -> {:ok, u}
      end
    else
      {:ok, u}
    end
  end)
  |> Audit.log_multi_safe(
    "auth.login.success",
    Keyword.merge(base_audit,
      actor_resolver: fn %{login_repo_work: u} -> u.id end,
      target_resolver: fn %{login_repo_work: u} -> u.id end,
      metadata: metadata
    )
  )
end

# ...
Audit.emit_telemetry_from_changes(changes)
```

The cut separates Multi composition from the caller's successful transaction branch;
in source, the telemetry line runs only after `repo.transact/1` returns `{:ok,
changes}`. Standalone failed-login audit writes follow a different atomicity category
because the rejected business operation cannot commit.

## 9. MFA policy chooses the first session type

After confirmation, policy, and successful repository work, the runtime checks the
host MFA callback and creates either a standard or MFA-pending session.

```elixir
# ...
mfa_config = Map.get(config, :mfa, [])
mfa_check_fn = Keyword.get(mfa_config, :check_fn)
mfa_enabled = mfa_check_fn && mfa_check_fn.(updated_user.id)

session_type = if mfa_enabled, do: :mfa_pending, else: :standard
metadata = %{type: session_type, ip: login_ip}

case create_session(config, updated_user, metadata) do
  {:ok, session} ->
    result = Map.merge(suspicious_details, %{session: session})
    result = if mfa_enabled, do: Map.put(result, :mfa_required, true), else: result
    {:ok, updated_user, result}

  {:error, reason} ->
    {:error, reason}
end
```

This is the session returned in the metadata collapsed by step 6.

## 10. Generated login currently creates a second session

Back in the generated web helper, the user-only success causes another call to the
host context's session creator. Its raw token—not the first session's token—is the one
written to Plug.

```elixir
def log_in_user(conn, user, params \\ %{}) do
  ip = conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))
  user_agent = conn |> get_req_header("user-agent") |> List.first() || ""

  token =
    Example.Accounts.generate_user_session_token(user, ip: ip, user_agent: user_agent)

  user_return_to = get_session(conn, :user_return_to)

  conn
  |> renew_session()
  |> put_token_in_session(token)
  |> maybe_write_remember_me_cookie(token, params)
  |> redirect(to: user_return_to || signed_in_path(conn))
end
```

Together, steps 6, 9, and 10 prove the current duplicate-session seam. A future fix
must preserve the typed denial, MFA, fixation, remember-cookie, and audit behavior
rather than merely deleting one call.

## 11. The Ecto store splits raw transport from durable lookup

The `Sigra.SessionStores.Ecto` store's `create/3` callback asks `Sigra.Token` for a
pair, persists the hash, then returns a `Sigra.Session` containing the raw Base64url
token.

```elixir
def create(user_id, metadata, opts) do
  repo = Keyword.fetch!(opts, :repo)
  schema = Keyword.fetch!(opts, :session_schema)
  {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()

  now = DateTime.utc_now()

  attrs = %{
    user_id: user_id,
    hashed_token: hashed_token,
    type: to_string(Map.get(metadata, :type, :standard)),
    ip: Map.get(metadata, :ip),
    user_agent: Map.get(metadata, :user_agent),
    geo_city: Map.get(metadata, :geo_city),
    geo_country_code: Map.get(metadata, :geo_country_code),
    active_organization_id: Map.get(metadata, :active_organization_id),
    last_active_at: now,
    inserted_at: now
  }

  case repo.insert(struct(schema, attrs)) do
    {:ok, record} ->
      session = to_session(record)
      {:ok, %{session | token: raw_token}}

    {:error, _} = error ->
      error
  end
end
```

The raw bytes are never persisted. The visible cookie value is an encoding of those
bytes, so lookup must decode before hashing.

## 12. Plug renewal happens before token storage

The generated helper deletes the CSRF token, renews the Plug session identifier,
clears old data, and then writes the session token plus LiveView disconnect topic.

```elixir
defp renew_session(conn) do
  delete_csrf_token()

  conn
  |> configure_session(renew: true)
  |> clear_session()
end

# ...

defp put_token_in_session(conn, token) do
  conn
  |> put_session(:user_token, token)
  |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(token)}")
end
```

Remember-me stores the same raw token in a signed, HTTP-only cookie. The database
comparison is still against the hash.

## 13. A later request reconstructs identity and scope

The generated context decodes and hashes the cookie value before the Ecto store fetch.
The generated web helper consumes `{user, session}` and then hydrates the host scope;
organization membership is authorization input, not display metadata.

```elixir
def get_user_and_session_by_token(raw_token) when is_binary(raw_token) do
  with {:ok, raw_bytes} <- Base.url_decode64(raw_token, padding: false) do
    hashed = Sigra.Token.hash_token(raw_bytes)
    config = sigra_config()
    session_config = config.session
    store = Keyword.fetch!(session_config, :store)

    store_opts = [
      repo: config.repo,
      session_schema: Keyword.fetch!(session_config, :session_schema)
    ]

    case store.fetch(hashed, store_opts) do
      {:ok, session} ->
        case Repo.get(User, session.user_id) do
          nil -> nil
          user -> {user, session}
        end

      {:error, :not_found} ->
        nil
    end
  else
    _ -> nil
  end
end

# ...

defp load_current_scope(conn, user_token) when is_binary(user_token) do
  case Example.Accounts.get_user_and_session_by_token(user_token) do
    {user, session} -> maybe_handle_impersonation(conn, user, session)
    _ -> {conn, nil, nil, nil}
  end
end
```

The next call builds `Scope.for_user/1` and invokes `Sigra.Scope.Hydration.hydrate/3`
when organizations are enabled. That host scope becomes `conn.assigns.current_scope`.

## 14. Audit composition belongs to the caller

`Sigra.Audit.log_multi_safe/3` is a no-op when no audit schema is configured. When it
is configured, it appends an insert to the existing Multi. It does not run the
transaction or emit forwarding telemetry itself.

```elixir
def log_multi_safe(%Ecto.Multi{} = multi, action, opts)
    when is_binary(action) and is_list(opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> multi
    _ -> do_log_multi(multi, action, opts, true)
  end
end

defp do_log_multi(multi, action, opts, allow_reserved?) do
  audit_schema = Keyword.fetch!(opts, :audit_schema)
  resolver = Keyword.get(opts, :actor_resolver)
  cs_opts = changeset_opts(opts, allow_reserved?)
  step = Keyword.get(opts, :audit_multi_step, :audit)

  Ecto.Multi.insert(multi, step, fn changes ->
    attrs = build_attrs(action, opts, resolver, changes)
    Changeset.changeset(struct(audit_schema), attrs, cs_opts)
  end)
end

# ...
Audit.emit_telemetry_from_changes(changes)
```

Callers must invoke telemetry from their successful transaction branch. That ordering
keeps a rolled-back row from being forwarded as if it were durable.

## 15. Optional async work depends on supervision, not compilation

An Oban module can be loaded while no Oban process is running. The forwarding path
therefore asks `Sigra.OptionalDeps.oban_running?/0`; `:auto` uses async only when the
host actually supervises Oban and otherwise selects sync.

```elixir
def oban_running?(opts) do
  case Keyword.fetch(opts, :oban) do
    {:ok, oban_override} ->
      Process.whereis(oban_override) != nil

    :error ->
      Sigra.OptionalDeps.oban_running?()
  end
end

defp dispatch_mode(opts) do
  case Keyword.get(opts, :dispatch, :auto) do
    :auto -> if oban_running?(opts), do: :async, else: :sync
    mode -> mode
  end
end
```

Explicit async without supervised Oban is rejected at boot. The same ownership rule
appears in email delivery: the host owns the Oban process; Sigra owns the decision not
to enqueue into a process that is merely compile-time available.

## Tests that pin the journey

The source path is guarded from two directions. The login atomicity test asserts a
rich `{:ok, logged_in, %{session: _}}` result, a reset failed-attempt count, and an
`auth.login.success` audit row with password metadata. Its SSO-only case asserts that
neither `auth.login.success` nor `session.create` appears after policy denial.

The installer golden test compares the generated tree and captured output against a
normalized committed fixture. The idempotency test runs installation twice and
requires the second pass to report `already exists` or `already injected`. Together
these tests protect runtime transaction ordering and the host-ownership boundary;
they do not currently count sessions across the full generated password-controller
path, which is why the double-session seam remains explicitly disclosed.

## Continue reading by question

- **How does installation stay additive?** Read `Mix.Tasks.Sigra.Install`, then
  `Sigra.Install.Runner`, `Sigra.Install.Feature`, and one feature module. Follow the
  binding and ask which callback owns each output.
- **How does a password become a request identity?** Read the generated controller and
  context in your host, then `Sigra.Auth`, `Sigra.SessionStores.Ecto`, `Sigra.Token`,
  and generated `UserAuth`. Track raw versus hashed token at every step.
- **How is MFA promoted?** Continue from `Sigra.Auth` into `Sigra.MFA` and
  `Sigra.Auth.complete_mfa_verification/4`. Ask when the MFA-pending session is
  replaced and what evidence commits with verification.
- **How does OAuth reconcile identity?** Start at `Sigra.OAuth.Callback`, continue
  through enterprise policy and the host identity schema, and ask where provider data
  becomes a local user or a denial.
- **How do lifecycle operations preserve evidence?** Read `Sigra.Account` beside
  `Sigra.Audit`. Compare success Multis with standalone failure audit writes.
- **How is committed evidence forwarded?** Read `Sigra.Audit.log_multi_safe/3`,
  `Sigra.Audit.emit_telemetry_from_changes/2`, then `Sigra.Audit.Forwarders`. Ask what
  remains durable when a downstream integration is absent.

Return to [Sigra architecture](architecture.html) whenever you need the outside-in
system map rather than the value-level path.
