defmodule Sigra.Auth do
  @moduledoc """
  Core authentication orchestrator.

  All security-critical auth operations live here. The generated
  `MyApp.Auth` context delegates to these functions for registration,
  authentication, session management, and magic link flows.

  ## Usage

      Sigra.Auth.register(MyApp.Repo, attrs, changeset_fn: &MyApp.User.registration_changeset/1)
      Sigra.Auth.authenticate(MyApp.Repo, params, user_schema: MyApp.User)

  ## Security Properties

  - User enumeration prevention: generic error messages, constant-time operations
  - Hash upgrade: transparent bcrypt-to-Argon2id migration on successful login
  - Failed attempt tracking: incremented on wrong password, reset on success
  - Magic link: single-use, 10-minute TTL, rate limited
  - Telemetry: all operations emit structured events
  """

  alias Ecto.Multi
  alias Sigra.{Audit, Crypto, Email, EnterpriseAuthPolicy, Telemetry, Token}

  # Email regex used by both valid_email?/1 and the registration changeset.
  # Matches a non-whitespace local part, an @, a non-whitespace domain, a dot,
  # and a non-whitespace TLD. Deliberately loose — full RFC 5322 validation
  # belongs in the DB (citext unique index) and at send-time, not at
  # pre-validation time.
  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc """
  Normalizes an email address for storage and lookup.

  Applies `String.trim/1` (leading/trailing whitespace) then
  `String.downcase/1`. Sigra stores emails in a `citext` column so
  case-insensitive matching is already enforced at the database level, but
  callers doing in-memory comparisons (login form pre-flight, fixture
  setup, audit queries) should normalize first.

  Returns a string on any binary input; passes through `nil` untouched so
  callers can pipe through without nil-guarding.

  ## Scope (RFC 5321 §2.3.4 caveat)

  This function does NOT strip interior whitespace from the local-part.
  Quoted local-parts with embedded whitespace (extremely rare, technically
  permitted by RFC 5321 §2.3.4) pass through unchanged. Callers MUST also
  run `valid_email?/1` — which rejects interior whitespace via regex —
  before persisting. Passing an unvalidated normalized value straight to a
  `citext` column is a caller error.

  ## Examples

      iex> Sigra.Auth.normalize_email("Alice@Example.COM")
      "alice@example.com"

      iex> Sigra.Auth.normalize_email("  bob@example.com  ")
      "bob@example.com"

      iex> Sigra.Auth.normalize_email("")
      ""

      iex> Sigra.Auth.normalize_email(nil)
      nil

      # Interior whitespace is retained — run valid_email?/1 to reject.
      iex> Sigra.Auth.normalize_email("Alice @example.com")
      "alice @example.com"

      iex> Sigra.Auth.valid_email?("alice @example.com")
      false

  """
  @doc since: "0.10.0"
  @spec normalize_email(String.t() | nil) :: String.t() | nil
  def normalize_email(nil), do: nil

  def normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  @doc """
  Returns true if the given string looks like a valid email address.

  Uses a deliberately loose regex — the goal is to catch obvious typos
  (`alice@`, `@example.com`, `not-an-email`) before hitting the database,
  not to enforce RFC 5322 compliance. Full validation happens when you
  actually attempt to deliver the message.

  Accepts only binaries. Non-binary input (including `nil`) returns
  `false` rather than raising, so the helper composes inside pipelines.

  ## Examples

      iex> Sigra.Auth.valid_email?("alice@example.com")
      true

      iex> Sigra.Auth.valid_email?("bob@example.co.uk")
      true

      iex> Sigra.Auth.valid_email?("not-an-email")
      false

      iex> Sigra.Auth.valid_email?("alice@")
      false

      iex> Sigra.Auth.valid_email?("@example.com")
      false

      iex> Sigra.Auth.valid_email?(nil)
      false

  """
  @doc since: "0.10.0"
  @spec valid_email?(term()) :: boolean()
  def valid_email?(email) when is_binary(email) do
    Regex.match?(@email_regex, email)
  end

  def valid_email?(_), do: false

  @doc """
  Registers a user.

  Takes a repo module, attributes map, and options. The `:changeset_fn`
  option must be a function that takes attrs and returns an `Ecto.Changeset`.

  Returns `{:ok, user}` on success, `{:error, changeset}` for validation
  errors, or `{:error, :email_taken}` when the email uniqueness constraint
  is violated (enumeration-safe -- callers should show a generic message).

  ## Options

  - `:changeset_fn` - Required. Function `(attrs -> Ecto.Changeset.t())`.

  ## Telemetry

  Emits `[:sigra, :auth, :register, :start | :stop | :exception]` span.
  On success, metadata includes `%{user_id: id}`.
  """
  @doc since: "0.2.0"
  @spec register(module(), map(), keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()} | {:error, :email_taken}
  def register(repo, attrs, opts \\ []) do
    Telemetry.span([:sigra, :auth, :register], %{}, fn ->
      # D-26: audit integration. When `:audit_schema` is present in opts,
      # `auth.register.success` is appended to `register_user_multi/2` via
      # `Audit.log_multi_safe/3` so the audit row shares the same transaction
      # as the `:user` insert. Failure paths remain standalone `log_safe/3`.
      audit_opts = Keyword.put(audit_opts_from_keyword(opts), :repo, repo)

      attrs
      |> register_user_multi(opts)
      |> repo.transact()
      |> case do
        {:ok, %{user: user} = changes} ->
          Audit.emit_telemetry_from_changes(changes)

          Telemetry.event([:sigra, :auth, :register, :stop], %{}, %{user_id: user.id})
          {:ok, user}

        {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
          if email_taken_error?(changeset) do
            # 15-02 Category 3: no user resolved — nil scope + target_id: nil.
            Audit.log_safe(
              "auth.register.failure",
              nil,
              Keyword.merge(audit_opts,
                actor_id: nil,
                target_id: nil,
                outcome: "failure",
                metadata: %{reason: "email_taken"}
              )
            )

            {:error, :email_taken}
          else
            Audit.log_safe(
              "auth.register.failure",
              nil,
              Keyword.merge(audit_opts,
                actor_id: nil,
                target_id: nil,
                outcome: "failure",
                metadata: %{reason: "validation"}
              )
            )

            {:error, changeset}
          end
      end
    end)
  end

  @doc """
  Pure `Ecto.Multi` builder for user registration.

  Returns a multi with a `:user` step that inserts the user via the
  configured `:changeset_fn`. When `:audit_schema` is set (see
  `audit_opts_from_keyword/1`), appends `auth.register.success` via
  `Audit.log_multi_safe/3` in the same Multi. Makes ZERO Repo calls during
  construction — composable via `Ecto.Multi.append/2`. Intended for use by
  `Sigra.Organizations.Invitations.accept_with_signup/3` (Phase 17 D-07)
  to atomically compose signup + confirm + membership + accept.

  ## Options

    * `:changeset_fn` — REQUIRED. 1-arity function producing a user
      changeset from `attrs`.

  ## Example

      Ecto.Multi.new()
      |> Ecto.Multi.append(
           Sigra.Auth.register_user_multi(attrs, changeset_fn: &User.registration_changeset/1)
         )
      |> MyApp.Repo.transact()

  """
  @doc since: "0.4.0"
  @spec register_user_multi(map(), keyword()) :: Ecto.Multi.t()
  def register_user_multi(attrs, opts) when is_map(attrs) and is_list(opts) do
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)
    audit_opts = audit_opts_from_keyword(opts)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:user, changeset_fn.(attrs))

    case Keyword.get(audit_opts, :audit_schema) do
      nil ->
        multi

      _ ->
        Audit.log_multi_safe(
          multi,
          "auth.register.success",
          Keyword.merge(audit_opts,
            actor_resolver: fn %{user: u} -> u.id end,
            target_resolver: fn %{user: u} -> u.id end,
            metadata: %{method: "password"}
          )
        )
    end
  end

  # --- Audit integration helpers (Plan 09-03) ---
  #
  # The audit layer is opt-in: if the host app has not configured an audit
  # schema, log_safe/2 no-ops. All integration sites pull opts from either
  # the per-call keyword list (non-config API) or from %Sigra.Config{} when
  # available. Reserved-prefix guard is bypassed for internal callers.
  #
  # D-26 dispatch table (auth.* operations in this module):
  #
  #   register success    -> Sigra.Audit.log_multi_safe (Multi) when :audit_schema set;
  #                          otherwise no success audit row from register/3
  #   register failure    -> Sigra.Audit.log_safe("auth.register.failure", nil, ...)
  #   login success       -> Sigra.Audit.log_multi_safe (Multi) when :audit_schema + confirmed;
  #                          else log_safe for unconfirmed pre-check path
  #                          Sigra.Audit.__log_internal__ (future Multi form)
  #   login failure       -> Sigra.Audit.log_safe("auth.login.failure", nil, ...)
  #                          (non-Multi, standalone per D-28)
  #   magic_link_request  -> Sigra.Audit.log_multi_safe (Multi) when :audit_schema set
  #   magic_link_verify   -> Sigra.Audit.log_multi_safe (Multi) when :audit_schema set
  #   password_reset_req  -> Sigra.Audit.log_multi_safe (Multi) when :audit_schema set
  #   password_reset done -> Sigra.Audit.__log_internal__ (Multi, atomic)
  #   confirmation link   -> Sigra.Audit.__log_internal__ (Multi, atomic)
  #   confirmation code   -> Sigra.Audit.__log_internal__ (Multi, atomic)

  @doc false
  def audit_opts_from_keyword(opts) when is_list(opts) do
    [
      repo: Keyword.get(opts, :repo) || Keyword.get(opts, :audit_repo),
      audit_schema: Keyword.get(opts, :audit_schema),
      ip_address: Keyword.get(opts, :ip_address) || Keyword.get(opts, :ip),
      user_agent: Keyword.get(opts, :user_agent)
    ]
  end

  @doc false
  def audit_opts_from_config(%Sigra.Config{} = config, extra \\ []) do
    audit_config = Map.get(config, :audit, [])

    [
      repo: config.repo,
      audit_schema: Keyword.get(audit_config, :audit_schema),
      ip_address: Keyword.get(extra, :ip_address) || Keyword.get(extra, :ip),
      user_agent: Keyword.get(extra, :user_agent)
    ]
  end

  defp audit_scope_column_opts(nil),
    do: [organization_id: nil, effective_user_id: nil, actor_id: nil]

  defp audit_scope_column_opts(%{user: user} = scope) do
    org = Map.get(scope, :active_organization)
    actor = Map.get(scope, :impersonating_from) || user

    [
      organization_id: org && org.id,
      effective_user_id: user && user.id,
      actor_id: actor && actor.id
    ]
  end

  defp audit_scope_column_opts(_), do: audit_scope_column_opts(nil)

  @doc """
  Authenticates a user by email and password.

  Normalizes the email, looks up the user, verifies the password with
  automatic hash upgrade support (bcrypt -> Argon2id), and tracks failed
  login attempts.

  Returns `{:ok, user}` on success with failed attempts reset to 0,
  `{:error, :invalid_credentials}` on failure, or `{:error, :unconfirmed}`
  when confirmation is required and the user has not confirmed their email.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:require_confirmation` - Whether to check `confirmed_at`. Default: `false`.

  ## Telemetry

  - `[:sigra, :auth, :login, :start | :stop | :exception]` span
  - `[:sigra, :auth, :hash_upgraded]` event when hash is upgraded
  """
  @doc since: "0.2.0"
  @spec authenticate(module() | Sigra.Config.t(), map(), keyword()) ::
          {:ok, struct()}
          | {:ok, struct(), map()}
          | {:error, :invalid_credentials | :unconfirmed | :account_locked}
  def authenticate(repo_or_config, params, opts \\ [])

  def authenticate(%Sigra.Config{} = config, params, _opts) do
    authenticate_with_config(config, params)
  end

  def authenticate(repo, params, opts) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    require_confirmation = Keyword.get(opts, :require_confirmation, false)

    email =
      (params["email"] || params[:email] || "")
      |> Email.normalize()

    user = repo.get_by(user_schema, email: email)
    password = params["password"] || params[:password] || ""
    hashed_password = user && Map.get(user, :hashed_password)

    case Crypto.verify_with_upgrade(password, hashed_password) do
      {:ok, :valid} ->
        with :allow <- EnterpriseAuthPolicy.password_login_allowed?(opts, user, opts) do
          handle_valid_login(repo, user, require_confirmation, %{}, opts)
        else
          {:deny, reason, _metadata} -> {:error, reason}
        end

      {:ok, :valid, new_hash} ->
        Telemetry.event([:sigra, :auth, :hash_upgraded], %{}, %{user_id: user.id})

        with :allow <- EnterpriseAuthPolicy.password_login_allowed?(opts, user, opts) do
          handle_valid_login(repo, user, require_confirmation, %{hashed_password: new_hash}, opts)
        else
          {:deny, reason, _metadata} -> {:error, reason}
        end

      {:error, :invalid} ->
        if user do
          # Increment failed login attempts for existing users
          increment_failed_attempts(repo, user)
        end

        {:error, :invalid_credentials}
    end
  end

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

  defp login_success_password_path(
         config,
         repo,
         user,
         require_confirmation,
         audit_opts,
         login_ip,
         extra_changes,
         metadata
       ) do
    maybe_unconfirmed =
      require_confirmation && is_nil(Map.get(user, :confirmed_at))

    cond do
      maybe_unconfirmed ->
        user_scope = Sigra.Scope.from_config(config, user)

        Audit.log_safe(
          "auth.login.success",
          user_scope,
          Keyword.merge(audit_opts,
            actor_id: user.id,
            target_id: user.id,
            metadata: metadata
          )
        )

        handle_valid_login_with_security(
          config,
          repo,
          user,
          require_confirmation,
          extra_changes,
          login_ip
        )

      Keyword.get(audit_opts, :audit_schema) ->
        multi =
          login_success_repo_and_audit_multi(config, user, extra_changes, audit_opts, metadata)

        case repo.transact(multi) do
          {:ok, %{login_repo_work: u_after} = ch} ->
            Audit.emit_telemetry_from_changes(ch)

            handle_valid_login_with_security(
              config,
              repo,
              u_after,
              require_confirmation,
              %{},
              login_ip,
              skip_lockout_reset: true,
              skip_extra_hash: true
            )

          {:error, failed, reason, _changes} ->
            raise "unexpected Ecto.Multi failure from Sigra.Auth login success path: " <>
                    "#{inspect(failed)} => #{inspect(reason)}"
        end

      true ->
        handle_valid_login_with_security(
          config,
          repo,
          user,
          require_confirmation,
          extra_changes,
          login_ip
        )
    end
  end

  defp authenticate_with_config(config, params) do
    repo = config.repo
    user_schema = config.user_schema
    require_confirmation = config.require_confirmation

    lockout_opts = [
      threshold: Keyword.get(config.lockout, :threshold, 5),
      duration: Keyword.get(config.lockout, :duration, 900)
    ]

    email =
      (params["email"] || params[:email] || "")
      |> Email.normalize()

    login_ip = params["ip"] || params[:ip]
    user_agent = params["user_agent"] || params[:user_agent]
    user = repo.get_by(user_schema, email: email)
    audit_opts = audit_opts_from_config(config, ip_address: login_ip, user_agent: user_agent)

    # Step 1: Check lockout BEFORE password verification (D-29)
    case Sigra.Lockout.check(user, lockout_opts) do
      {:error, :account_locked, _remaining} ->
        # D-26: security audit row (standalone, D-28).
        # D-28 Category 2: known-user pre-org-selection — build a user-only
        # scope (org intentionally nil) and set target_id: user.id.
        user_scope = Sigra.Scope.from_config(config, user)

        Audit.log_safe(
          "security.lockout",
          user_scope,
          Keyword.merge(audit_opts,
            actor_id: user && user.id,
            target_id: user && user.id,
            outcome: "failure",
            metadata: %{reason: "account_locked"}
          )
        )

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

          {:ok, :valid, new_hash} ->
            Telemetry.event([:sigra, :auth, :hash_upgraded], %{}, %{user_id: user.id})

            handle_enterprise_password_login(
              config,
              repo,
              user,
              require_confirmation,
              audit_opts,
              login_ip,
              %{hashed_password: new_hash},
              %{method: "password", hash_upgraded: true}
            )

          {:error, :invalid} ->
            if user do
              # D-26 + D-28: login failure is a standalone audit write.
              # 15-02 D-28 Category 2: known-user pre-org-selection — user-only
              # scope + target_id: user.id.
              user_scope = Sigra.Scope.from_config(config, user)

              Audit.log_safe(
                "auth.login.failure",
                user_scope,
                Keyword.merge(audit_opts,
                  actor_id: user.id,
                  target_id: user.id,
                  outcome: "failure",
                  metadata: %{reason: "invalid_password"}
                )
              )

              handle_failed_login_with_lockout(config, repo, user, login_ip, lockout_opts)
            else
              # 15-02 D-26/D-29 Category 3: truly-anonymous unknown-email
              # failed login — nil scope + target_id: nil. Metadata carries
              # only the reason label (no email, no email hash — OWASP ASVS
              # V7.1); IP / User-Agent are already in audit_opts as top-level
              # columns, not metadata.
              Audit.log_safe(
                "auth.login.failure",
                nil,
                Keyword.merge(audit_opts,
                  actor_id: nil,
                  target_id: nil,
                  outcome: "failure",
                  metadata: %{reason: "unknown_email"}
                )
              )

              {:error, :invalid_credentials}
            end
        end
    end
  end

  @doc """
  Requests a magic link for the given email.

  If the user exists and is not rate-limited, generates a token and returns
  `{:ok, {raw_token, url}}`. If the user does not exist, returns `{:ok, :sent}`
  to prevent email enumeration. If rate-limited, returns `{:error, :rate_limited}`.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens (e.g., `MyApp.Accounts.UserToken`).
  - `:url_fun` - Required. Function `(token -> url_string)`.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil` (no rate limiting).
  - `:max_requests` - Max magic link requests per window. Default: `3`.
  - `:window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.2.0"
  @spec request_magic_link(module(), String.t(), keyword()) ::
          {:ok, {String.t(), String.t()}} | {:ok, :sent} | {:error, :rate_limited}
  def request_magic_link(repo, email, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    url_fun = Keyword.fetch!(opts, :url_fun)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_requests = Keyword.get(opts, :max_requests, 3)
    window_ms = Keyword.get(opts, :window_ms, 900_000)

    normalized_email = Email.normalize(email)
    user = repo.get_by(user_schema, email: normalized_email)

    cond do
      is_nil(user) ->
        # Enumeration-safe: return generic response without DB write
        {:ok, :sent}

      rate_limiter &&
          rate_limited?(rate_limiter, "magic_link:#{normalized_email}", max_requests, window_ms) ->
        {:error, :rate_limited}

      true ->
        {raw_token, hashed_token} = Token.generate_hashed_token()

        token_struct =
          struct!(user_token_schema, %{
            token: hashed_token,
            context: "magic_link",
            sent_to: user.email,
            user_id: user.id
          })

        audit_opts =
          audit_opts_from_keyword(opts)
          |> Keyword.put(:repo, repo)
          |> Keyword.merge(audit_scope_column_opts(Sigra.Scope.from_opts(opts, user)))

        multi =
          Multi.new()
          |> Multi.insert(:magic_link_token, token_struct)

        multi =
          if Keyword.get(audit_opts, :audit_schema) do
            Audit.log_multi_safe(
              multi,
              "auth.magic_link_request",
              Keyword.merge(audit_opts,
                actor_resolver: fn %{magic_link_token: t} -> t.user_id end,
                target_resolver: fn %{magic_link_token: t} -> t.user_id end,
                metadata: %{}
              )
            )
          else
            multi
          end

        case repo.transact(multi) do
          {:ok, changes} ->
            Audit.emit_telemetry_from_changes(changes)
            url = url_fun.(raw_token)
            {:ok, {raw_token, url}}

          {:error, failed, reason, _changes} ->
            raise "unexpected Ecto.Multi failure from Sigra.Auth.request_magic_link/3: " <>
                    "#{inspect(failed)} => #{inspect(reason)}"
        end
    end
  end

  @doc """
  Verifies a magic link token. Confirms user if unconfirmed.

  The token is single-use: it is deleted from the database after successful
  verification. If the user has not confirmed their email, `confirmed_at`
  is set to the current time.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:magic_link_ttl` - Token TTL in seconds. Default: `600` (10 minutes).
  """
  @doc since: "0.2.0"
  @spec verify_magic_link(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :invalid | :expired}
  def verify_magic_link(repo, raw_token, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    magic_link_ttl = Keyword.get(opts, :magic_link_ttl, 600)

    # Decode and hash the token
    hashed_token =
      case Base.url_decode64(raw_token, padding: false) do
        {:ok, decoded} -> Token.hash_token(decoded)
        :error -> nil
      end

    if is_nil(hashed_token) do
      {:error, :invalid}
    else
      case repo.get_by(user_token_schema, token: hashed_token, context: "magic_link") do
        nil ->
          {:error, :invalid}

        token_record ->
          # Check TTL (DB adapters may return :utc_datetime or :naive_datetime)
          inserted_at =
            case token_record.inserted_at do
              %DateTime{} = dt -> dt
              %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
            end

          age_seconds = DateTime.diff(DateTime.utc_now(), inserted_at, :second)

          if age_seconds > magic_link_ttl do
            {:error, :expired}
          else
            scope_user = repo.get!(user_schema, token_record.user_id)

            audit_opts =
              audit_opts_from_keyword(opts)
              |> Keyword.put(:repo, repo)
              |> Keyword.merge(audit_scope_column_opts(Sigra.Scope.from_opts(opts, scope_user)))

            multi =
              Multi.new()
              |> Multi.run(:magic_link_user, fn r, _changes ->
                u = r.get!(user_schema, token_record.user_id)
                _ = r.delete!(token_record)
                u = maybe_confirm_user(r, u)
                {:ok, u}
              end)

            multi =
              if Keyword.get(audit_opts, :audit_schema) do
                Audit.log_multi_safe(
                  multi,
                  "auth.magic_link_verify.success",
                  Keyword.merge(audit_opts,
                    actor_resolver: fn %{magic_link_user: u} -> u.id end,
                    target_resolver: fn %{magic_link_user: u} -> u.id end,
                    metadata: %{}
                  )
                )
              else
                multi
              end

            case repo.transact(multi) do
              {:ok, %{magic_link_user: user} = changes} ->
                Audit.emit_telemetry_from_changes(changes)
                {:ok, user}

              {:error, failed, reason, _changes} ->
                raise "unexpected Ecto.Multi failure from Sigra.Auth.verify_magic_link/3: " <>
                        "#{inspect(failed)} => #{inspect(reason)}"
            end
          end
      end
    end
  end

  @doc """
  Generates a confirmation link token AND a 6-digit code for the given user.

  Returns `{encoded_token, code, link_token_struct, code_token_struct}`.
  The encoded_token is HMAC-signed for URL use. The code is a random 6-digit
  numeric string. Both are stored as SHA-256 hashes in the DB.

  Per D-01: link-first, code as fallback. Both generated together.

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @doc since: "0.3.0"
  @spec generate_confirmation_token(module(), struct(), keyword()) ::
          {String.t(), String.t(), struct(), struct()}
  def generate_confirmation_token(_repo, user, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    # The confirmation link transports the URL-safe token string, not the
    # original random bytes. Store the hash of that transported string so
    # confirm_user/3 can look it up after HMAC verification.
    {raw_token, _hashed_raw_bytes} = Token.generate_hashed_token()
    hashed_token = Token.hash_token(raw_token)
    signed = Plug.Crypto.sign(secret_key_base, "sigra-confirm-token", raw_token)
    encoded_token = Base.url_encode64(signed, padding: false)

    # Generate 6-digit code (100000-999999) using rejection sampling
    # to eliminate modulo bias from the 4-byte random integer.
    code =
      (uniform_random(900_000) + 100_000)
      |> Integer.to_string()

    hashed_code = Token.hash_token(code)

    # Build token structs
    link_struct =
      struct!(user_token_schema, %{
        token: hashed_token,
        context: "confirm",
        sent_to: user.email,
        user_id: user.id
      })

    code_struct =
      struct!(user_token_schema, %{
        token: hashed_code,
        context: "confirm_code",
        sent_to: user.email,
        user_id: user.id
      })

    {encoded_token, code, link_struct, code_struct}
  end

  @doc """
  Confirms a user by HMAC-signed link token.

  Verifies the HMAC signature, decodes the raw token, hashes it,
  looks up in DB. On success, sets confirmed_at and deletes all
  confirm/confirm_code tokens for the user in a single transaction.

  Returns `{:ok, user}`, `{:error, :token_expired}`, `{:error, :token_invalid}`,
  or `{:error, :already_confirmed}`.

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:confirmation_ttl` - Token TTL in seconds. Default: `172800` (48 hours).
  """
  @doc since: "0.3.0"
  @spec confirm_user(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :token_expired | :token_invalid | :already_confirmed}
  def confirm_user(repo, encoded_token, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    ttl = Keyword.get(opts, :confirmation_ttl, 48 * 60 * 60)

    # Decode base64, then verify HMAC
    with {:ok, signed} <- Base.url_decode64(encoded_token, padding: false),
         {:ok, raw_token} <-
           Plug.Crypto.verify(secret_key_base, "sigra-confirm-token", signed, max_age: ttl) do
      hashed_token = Token.hash_token(raw_token)

      # Look up token in DB
      case repo.get_by(user_token_schema, token: hashed_token, context: "confirm") do
        nil ->
          {:error, :token_invalid}

        token_record ->
          # Build atomic transaction: confirm user + delete all confirm tokens
          audit_opts = Keyword.put(audit_opts_from_keyword(opts), :repo, repo)

          multi =
            Multi.new()
            |> Multi.run(:confirm_user, fn _repo, _changes ->
              user = repo.get!(user_schema, token_record.user_id)

              if user.confirmed_at do
                {:error, :already_confirmed}
              else
                now = DateTime.utc_now() |> DateTime.truncate(:second)
                changeset = Ecto.Changeset.change(user, confirmed_at: now)

                case repo.update(changeset) do
                  {:ok, updated} -> {:ok, updated}
                  {:error, changeset} -> {:error, changeset}
                end
              end
            end)
            |> Multi.run(:delete_tokens, fn _repo, _changes ->
              import Ecto.Query

              query =
                from(t in user_token_schema,
                  where: t.user_id == ^token_record.user_id,
                  where: t.context in ["confirm", "confirm_code"]
                )

              repo.delete_all(query)
              {:ok, :deleted}
            end)

          # D-26: atomic audit row for confirmation verify success.
          # __log_internal__/3 is guarded by audit_schema presence so apps
          # that have not configured audit skip the extra step entirely.
          multi =
            if Keyword.get(audit_opts, :audit_schema) do
              Sigra.Audit.__log_internal__(
                multi,
                "auth.confirmation_verify.success",
                Keyword.merge(audit_opts,
                  actor_resolver: fn %{confirm_user: u} -> u.id end,
                  metadata: %{method: "link"}
                )
              )
            else
              multi
            end

          case repo.transaction(multi) do
            {:ok, %{confirm_user: user} = changes} ->
              Audit.emit_telemetry_from_changes(changes)
              Telemetry.event([:sigra, :confirmation, :verify, :stop], %{}, %{user_id: user.id})
              {:ok, user}

            {:error, :confirm_user, :already_confirmed, _changes} ->
              {:error, :already_confirmed}

            {:error, _step, reason, _changes} ->
              {:error, reason}
          end
      end
    else
      {:error, :expired} -> {:error, :token_expired}
      {:error, _} -> {:error, :token_invalid}
      :error -> {:error, :token_invalid}
    end
  end

  @doc """
  Confirms a user by 6-digit code.

  SHA-256 hashes the submitted code, looks up in DB with context "confirm_code".
  Rate-limited to 5 attempts per user per 15 minutes.

  ## Options

  - `:user_id` - Required. The user ID to confirm.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:secret_key_base` - Required. The host app's secret key base.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil`.
  - `:max_code_attempts` - Max code verification attempts per window. Default: `5`.
  - `:code_window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.3.0"
  @spec verify_confirmation_code(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :invalid_code | :rate_limited | :already_confirmed}
  def verify_confirmation_code(repo, code, opts \\ []) do
    user_id = Keyword.fetch!(opts, :user_id)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_attempts = Keyword.get(opts, :max_code_attempts, 5)
    window_ms = Keyword.get(opts, :code_window_ms, 900_000)

    # Check rate limit first
    if rate_limiter do
      case rate_limiter.check_rate("sigra:confirm_code:#{user_id}", max_attempts, window_ms) do
        {:allow, _count} -> :ok
        {:deny, _retry_after} -> {:error, :rate_limited}
      end
    else
      :ok
    end
    |> case do
      {:error, :rate_limited} = err ->
        err

      :ok ->
        hashed_code = Token.hash_token(code)

        case repo.get_by(user_token_schema, token: hashed_code, context: "confirm_code") do
          nil ->
            {:error, :invalid_code}

          token_record ->
            # Build atomic transaction: confirm user + delete all confirm tokens
            multi =
              Multi.new()
              |> Multi.run(:confirm_user, fn _repo, _changes ->
                user = repo.get!(user_schema, token_record.user_id)

                if user.confirmed_at do
                  {:error, :already_confirmed}
                else
                  now = DateTime.utc_now() |> DateTime.truncate(:second)
                  changeset = Ecto.Changeset.change(user, confirmed_at: now)

                  case repo.update(changeset) do
                    {:ok, updated} -> {:ok, updated}
                    {:error, changeset} -> {:error, changeset}
                  end
                end
              end)
              |> Multi.run(:delete_tokens, fn _repo, _changes ->
                import Ecto.Query

                query =
                  from(t in user_token_schema,
                    where: t.user_id == ^token_record.user_id,
                    where: t.context in ["confirm", "confirm_code"]
                  )

                repo.delete_all(query)
                {:ok, :deleted}
              end)

            # D-26: audit row for confirmation-code verify success (atomic)
            audit_opts_cc = Keyword.put(audit_opts_from_keyword(opts), :repo, repo)

            multi =
              if Keyword.get(audit_opts_cc, :audit_schema) do
                Sigra.Audit.__log_internal__(
                  multi,
                  "auth.confirmation_verify.success",
                  Keyword.merge(audit_opts_cc,
                    actor_resolver: fn %{confirm_user: u} -> u.id end,
                    metadata: %{method: "code"}
                  )
                )
              else
                multi
              end

            case repo.transaction(multi) do
              {:ok, %{confirm_user: user} = changes} ->
                Audit.emit_telemetry_from_changes(changes)
                Telemetry.event([:sigra, :confirmation, :verify, :stop], %{}, %{user_id: user.id})
                {:ok, user}

              {:error, :confirm_user, :already_confirmed, _changes} ->
                {:error, :already_confirmed}

              {:error, _step, reason, _changes} ->
                {:error, reason}
            end
        end
    end
  end

  @doc """
  Requests a password reset for the given email.

  Enumeration-safe: always returns `{:ok, :sent}` for non-existent emails
  with a dummy hash operation to match timing (per D-38).

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens (e.g., `MyApp.Accounts.UserToken`).
  - `:secret_key_base` - Required. The host app's secret key base.
  - `:url_fun` - Required. Function `(token -> url_string)`.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil`.
  - `:max_requests` - Max reset requests per window. Default: `3`.
  - `:window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.3.0"
  @spec request_password_reset(module(), String.t(), keyword()) ::
          {:ok, {String.t(), String.t()}} | {:ok, :sent} | {:error, :rate_limited}
  def request_password_reset(repo, email, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    url_fun = Keyword.fetch!(opts, :url_fun)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_requests = Keyword.get(opts, :max_requests, 3)
    window_ms = Keyword.get(opts, :window_ms, 900_000)

    normalized_email = Email.normalize(email)
    user = repo.get_by(user_schema, email: normalized_email)

    cond do
      is_nil(user) ->
        # Enumeration-safe: dummy hash to match timing
        Crypto.hash_password("dummy_password_for_timing")
        {:ok, :sent}

      rate_limiter &&
          rate_limited?(rate_limiter, "sigra:reset:#{normalized_email}", max_requests, window_ms) ->
        {:error, :rate_limited}

      match?({:deny, _, _}, EnterpriseAuthPolicy.password_reset_allowed?(opts, user, opts)) ->
        {:ok, :sent}

      true ->
        {raw_token, hashed_token} = Token.generate_hashed_token()
        signed = Plug.Crypto.sign(secret_key_base, "sigra-reset-token", raw_token)
        encoded_token = Base.url_encode64(signed, padding: false)

        token_struct =
          struct!(user_token_schema, %{
            token: hashed_token,
            context: "reset_password",
            sent_to: user.email,
            user_id: user.id
          })

        audit_opts =
          audit_opts_from_keyword(opts)
          |> Keyword.put(:repo, repo)
          |> Keyword.merge(audit_scope_column_opts(Sigra.Scope.from_opts(opts, user)))

        multi =
          Multi.new()
          |> Multi.insert(:password_reset_token, token_struct)

        multi =
          if Keyword.get(audit_opts, :audit_schema) do
            Audit.log_multi_safe(
              multi,
              "auth.password_reset_request",
              Keyword.merge(audit_opts,
                actor_resolver: fn %{password_reset_token: t} -> t.user_id end,
                target_resolver: fn %{password_reset_token: t} -> t.user_id end,
                metadata: %{}
              )
            )
          else
            multi
          end

        case repo.transact(multi) do
          {:ok, changes} ->
            Audit.emit_telemetry_from_changes(changes)
            Telemetry.event([:sigra, :reset, :requested], %{}, %{user_id: user.id})
            url = url_fun.(encoded_token)
            {:ok, {encoded_token, url}}

          {:error, failed, reason, _changes} ->
            raise "unexpected Ecto.Multi failure from Sigra.Auth.request_password_reset/3: " <>
                    "#{inspect(failed)} => #{inspect(reason)}"
        end
    end
  end

  @doc """
  Resets a user's password using a valid reset token.

  Verifies HMAC signature, looks up token in DB, changes password,
  and invalidates ALL tokens (including sessions) in a single transaction.
  Per D-29: auto-login after reset (caller creates new session).

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:changeset_fn` - Required. Function `(user, attrs -> Ecto.Changeset.t())`.
  - `:reset_ttl` - Token TTL in seconds. Default: `3600` (1 hour).
  """
  @doc since: "0.3.0"
  @spec reset_password(module(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, :token_expired | :token_invalid | Ecto.Changeset.t()}
  def reset_password(repo, encoded_token, password_attrs, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)
    ttl = Keyword.get(opts, :reset_ttl, 60 * 60)

    # Decode base64, then verify HMAC
    with {:ok, signed} <- Base.url_decode64(encoded_token, padding: false),
         {:ok, raw_token} <-
           Plug.Crypto.verify(secret_key_base, "sigra-reset-token", signed, max_age: ttl) do
      hashed_token = Token.hash_token(raw_token)

      case repo.get_by(user_token_schema, token: hashed_token, context: "reset_password") do
        nil ->
          {:error, :token_invalid}

        token_record ->
          user = repo.get!(user_schema, token_record.user_id)

          case EnterpriseAuthPolicy.password_reset_allowed?(opts, user, opts) do
            {:deny, reason, _metadata} ->
              {:error, reason}

            :allow ->
              multi =
                Multi.new()
                |> Multi.run(:reset_password, fn _repo, _changes ->
                  changeset = changeset_fn.(user, password_attrs)

                  case repo.update(changeset) do
                    {:ok, updated} -> {:ok, updated}
                    {:error, changeset} -> {:error, changeset}
                  end
                end)
                |> Multi.run(:delete_all_tokens, fn _repo, _changes ->
                  import Ecto.Query

                  query =
                    from(t in user_token_schema,
                      where: t.user_id == ^token_record.user_id
                    )

                  repo.delete_all(query)
                  {:ok, :deleted}
                end)

              # D-26: atomic audit row for password_reset_complete
              audit_opts = Keyword.put(audit_opts_from_keyword(opts), :repo, repo)

              multi =
                if Keyword.get(audit_opts, :audit_schema) do
                  Sigra.Audit.__log_internal__(
                    multi,
                    "auth.password_reset_complete",
                    Keyword.merge(audit_opts,
                      actor_resolver: fn %{reset_password: u} -> u.id end,
                      metadata: %{}
                    )
                  )
                else
                  multi
                end

              case repo.transaction(multi) do
                {:ok, %{reset_password: user} = changes} ->
                  Audit.emit_telemetry_from_changes(changes)
                  Telemetry.event([:sigra, :reset, :completed], %{}, %{user_id: user.id})
                  {:ok, user}

                {:error, :reset_password, %Ecto.Changeset{} = changeset, _changes} ->
                  {:error, changeset}

                {:error, _step, reason, _changes} ->
                  {:error, reason}
              end
          end
      end
    else
      {:error, :expired} -> {:error, :token_expired}
      {:error, _} -> {:error, :token_invalid}
      :error -> {:error, :token_invalid}
    end
  end

  # -- Session Management (Phase 4 Plan 02) --

  @doc """
  Create a new session for the user with connection metadata.

  Creates a session via the configured SessionStore and emits a
  `[:sigra, :session, :create]` telemetry span.

  ## Phase 14: organization selector (D-12, D-26, ORG-SCOPE-06)

  When `config.organizations_module` is set, the function runs the
  `Sigra.Organizations.select_active_organization/3` selector once per
  login and writes the result (or `nil`) into the newly-created session
  row via `SessionStore.update_active_organization/3`. The selector
  call is wrapped in a `try/rescue` block and MUST NOT fail the login
  — selector failures fall back to `active_organization_id: nil` and
  the user sees the picker on their next `RequireMembership` hit
  (T-14-13 mitigation).

  ## Options

  - `:session_store` - Override the session store from config.
  - `:previous_active_organization_id` - Resume pointer passed to
    `Sigra.Organizations.select_active_organization/3`. When a user
    with 2+ memberships logs in, the selector uses this to pick up
    where the user left off (D-12).
  """
  @doc since: "0.4.0"
  @spec create_session(Sigra.Config.t(), struct(), map(), keyword()) ::
          {:ok, Sigra.Session.t()} | {:error, term()}
  def create_session(config, user, metadata, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    result =
      Telemetry.span(
        [:sigra, :session, :create],
        %{user_id: user.id, type: Map.get(metadata, :type, :standard)},
        fn ->
          session_store.create(user.id, metadata, store_opts)
        end
      )

    # D-26/D-27 (15-02): the `session.create` audit emission is deliberately
    # NOT fired here — it now fires inside `maybe_assign_active_organization/6`
    # AFTER the active organization has been selected, so the first audit row
    # of a successful login carries the real `organization_id`. This is the
    # v1.2 impersonation anchor. See plan 15-02 Task 1 §1 for the reorder.
    result =
      case result do
        {:ok, session} ->
          # Phase 14: wire the 0/1/2+ organization selector (D-12).
          # Fail-open on selector errors — login MUST NOT die if the
          # selector raises (T-14-13). Hydration is fail-closed (D-01),
          # but the login-time selector is fail-open by design.
          maybe_assign_active_organization(
            config,
            user,
            session,
            session_store,
            store_opts,
            opts,
            metadata
          )

        other ->
          other
      end

    result
  end

  @doc false
  defp maybe_assign_active_organization(
         config,
         user,
         session,
         session_store,
         store_opts,
         opts,
         metadata
       ) do
    # D-27 (15-02): resolve active org first, then emit `session.create` AFTER
    # org selection so the first audit row of a successful login carries the
    # real `organization_id`. This is the v1.2 impersonation anchor.
    {final_session, active_org} =
      case Map.get(metadata, :active_organization_id) do
        org_id when not is_nil(org_id) ->
          assign_explicit_active_organization(config, session, session_store, store_opts, org_id)

        _ ->
          case config.organizations_module do
            nil ->
              {session, nil}

            om ->
              resolve_and_assign_org(config, om, user, session, session_store, store_opts, opts)
          end
      end

    scope =
      case config.scope_module do
        nil -> nil
        mod -> Sigra.Scope.build(mod, user, active_organization: active_org)
      end

    audit_opts =
      audit_opts_from_config(config,
        ip_address: Map.get(metadata, :ip),
        user_agent: Map.get(metadata, :user_agent)
      )

    Sigra.Audit.log_safe(
      "session.create",
      scope,
      Keyword.merge(audit_opts,
        actor_id: user.id,
        metadata: session_create_audit_metadata(metadata, final_session)
      )
    )

    {:ok, final_session}
  end

  defp assign_explicit_active_organization(config, session, session_store, store_opts, org_id) do
    updated_session =
      case session_store.update_active_organization(session, org_id, store_opts) do
        {:ok, updated_session} -> updated_session
        {:error, _reason} -> session
      end

    {updated_session, load_explicit_active_organization(config, org_id)}
  end

  defp resolve_and_assign_org(
         _config,
         organizations_module,
         user,
         session,
         session_store,
         store_opts,
         opts
       ) do
    active_org =
      try do
        org_config = organizations_module.__sigra_org_config__()

        selector_opts = [
          previous_active_organization_id: Keyword.get(opts, :previous_active_organization_id)
        ]

        case Sigra.Organizations.select_active_organization(org_config, user, selector_opts) do
          {:ok, org} -> org
          _ -> nil
        end
      rescue
        error ->
          # WR-04: login is fail-open on selector errors (T-14-13), but it
          # MUST leave a breadcrumb — otherwise a broken host selector
          # silently degrades every login to "no active org" with no
          # operator signal beyond user reports.
          Telemetry.event(
            [:sigra, :auth, :selector_error],
            %{},
            %{
              user_id: user.id,
              kind: :error,
              reason: inspect(error)
            }
          )

          nil
      catch
        kind, reason ->
          Telemetry.event(
            [:sigra, :auth, :selector_error],
            %{},
            %{
              user_id: user.id,
              kind: kind,
              reason: inspect(reason)
            }
          )

          nil
      end

    case active_org do
      nil ->
        {session, nil}

      %{id: id} = org ->
        case session_store.update_active_organization(session, id, store_opts) do
          {:ok, updated_session} -> {updated_session, org}
          # Failure to write the active_organization_id is non-fatal — login
          # still succeeds; user sees the picker on next request.
          {:error, _reason} -> {session, org}
        end
    end
  end

  defp load_explicit_active_organization(config, org_id) do
    with organizations_module when not is_nil(organizations_module) <- config.organizations_module,
         org_config <- organizations_module.__sigra_org_config__(),
         organization_schema when not is_nil(organization_schema) <-
           get_in(org_config, [:schemas, :organization]) do
      config.repo.get(organization_schema, org_id)
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp session_create_audit_metadata(metadata, final_session) do
    %{
      type: Map.get(metadata, :type, :standard),
      session_id: final_session.id,
      active_organization_id:
        Map.get(final_session, :active_organization_id) ||
          Map.get(metadata, :active_organization_id)
    }
    |> maybe_put_metadata(:enterprise_connection_id, Map.get(metadata, :enterprise_connection_id))
    |> maybe_put_metadata(
      :enterprise_routing_source,
      Map.get(metadata, :enterprise_routing_source)
    )
    |> maybe_put_metadata(
      :enterprise_reconciliation_outcome,
      Map.get(metadata, :enterprise_reconciliation_outcome)
    )
  end

  defp maybe_put_metadata(map, _key, nil), do: map
  defp maybe_put_metadata(map, key, value), do: Map.put(map, key, value)

  @doc """
  Delete a specific session by its hashed token.

  Emits a `[:sigra, :session, :delete]` telemetry span.
  """
  @doc since: "0.4.0"
  @spec delete_session(Sigra.Config.t(), binary(), keyword()) :: :ok
  def delete_session(config, hashed_token, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    result =
      Telemetry.span([:sigra, :session, :delete], %{}, fn ->
        session_store.delete(hashed_token, store_opts)
      end)

    # D-26: session.delete audit row (standalone, D-28).
    # actor_id is resolved from the opts :user_id if provided; otherwise nil.
    audit_opts = audit_opts_from_config(config)

    user_id = Keyword.get(opts, :user_id)
    actor_id = Keyword.get(opts, :actor_id, user_id)
    target_id = Keyword.get(opts, :target_id, user_id)
    effective_user_id = Keyword.get(opts, :effective_user_id, user_id)
    scope = audit_scope_from_opts(config, opts, effective_user_id)

    Sigra.Audit.log_safe(
      "session.delete",
      scope,
      Keyword.merge(audit_opts,
        actor_id: actor_id,
        target_id: target_id,
        effective_user_id: effective_user_id,
        metadata: %{}
      )
    )

    result
  end

  @doc """
  Delete all sessions for a user. Broadcasts PubSub disconnect per D-16.

  Returns `{count, nil}` where count is the number of deleted sessions.

  ## Options

  - `:except_token` - Hashed token to exclude (current session).
  - `:pubsub` - Phoenix.PubSub module name for LiveView disconnect broadcasts.
  """
  @doc since: "0.4.0"
  @spec delete_all_sessions(Sigra.Config.t(), term(), keyword()) :: {non_neg_integer(), nil}
  def delete_all_sessions(config, user_id, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    # Get all sessions BEFORE deleting (need tokens for PubSub broadcast)
    sessions = session_store.list_by_user(user_id, store_opts)

    except_token = Keyword.get(opts, :except_token)

    delete_opts =
      if except_token,
        do: Keyword.put(store_opts, :except_token, except_token),
        else: store_opts

    {count, _} = session_store.delete_all_for_user(user_id, delete_opts)

    # Broadcast disconnect to LiveView sockets per D-16
    pubsub = Keyword.get(opts, :pubsub)

    if pubsub do
      sessions
      |> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
      |> Enum.each(fn session ->
        live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
        Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
      end)
    end

    Telemetry.event([:sigra, :session, :revoke_all, :stop], %{count: count}, %{user_id: user_id})

    # D-26: session.revoke_all audit row (standalone)
    audit_opts = audit_opts_from_config(config)

    actor_id = Keyword.get(opts, :actor_id, user_id)
    target_id = Keyword.get(opts, :target_id, user_id)
    effective_user_id = Keyword.get(opts, :effective_user_id, user_id)
    scope = audit_scope_from_opts(config, opts, effective_user_id)

    Sigra.Audit.log_safe(
      "session.revoke_all",
      scope,
      Keyword.merge(audit_opts,
        actor_id: actor_id,
        target_id: target_id,
        effective_user_id: effective_user_id,
        metadata: %{count: count}
      )
    )

    {count, nil}
  end

  @doc """
  List all active sessions for a user.

  Excludes `:mfa_pending` sessions from the listing since they represent
  incomplete authentication attempts, not active sessions (D-29).
  """
  @doc since: "0.4.0"
  @spec list_sessions(Sigra.Config.t(), term(), keyword()) :: [Sigra.Session.t()]
  def list_sessions(config, user_id, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    session_store.list_by_user(user_id, store_opts)
    |> Enum.reject(fn session -> session.type == :mfa_pending end)
  end

  @doc """
  Revoke a specific session by hashed_token.

  Delegates to `delete_session/3`.
  """
  @doc since: "0.4.0"
  @spec revoke_session(Sigra.Config.t(), binary(), keyword()) :: :ok
  def revoke_session(config, hashed_token, opts \\ []) do
    delete_session(config, hashed_token, opts)
  end

  defp audit_scope_from_opts(config, opts, effective_user_id) do
    case Keyword.get(opts, :audit_scope) do
      nil -> effective_user_id && Sigra.Scope.from_config(config, %{id: effective_user_id})
      scope -> scope
    end
  end

  @doc """
  Confirm sudo mode by updating sudo_at timestamp.

  Emits a `[:sigra, :session, :sudo]` telemetry span.
  """
  @doc since: "0.4.0"
  @spec confirm_sudo(Sigra.Config.t(), binary(), keyword()) :: :ok | {:error, :not_found}
  def confirm_sudo(config, hashed_token, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    result =
      Telemetry.span([:sigra, :session, :sudo], %{}, fn ->
        session_store.update_sudo(hashed_token, DateTime.utc_now(), store_opts)
      end)

    # D-26 + RESEARCH Q2: split session.sudo_enter / session.sudo_expire by
    # result. :ok or {:ok, _} = entered; any error response = expired/failed.
    action =
      case result do
        :ok -> "session.sudo_enter"
        {:ok, _} -> "session.sudo_enter"
        _ -> "session.sudo_expire"
      end

    audit_opts = audit_opts_from_config(config)

    outcome = if action == "session.sudo_enter", do: "success", else: "failure"

    user_id = Keyword.get(opts, :user_id)
    scope = user_id && Sigra.Scope.from_config(config, %{id: user_id})

    Sigra.Audit.log_safe(
      action,
      scope,
      Keyword.merge(audit_opts,
        actor_id: user_id,
        target_id: user_id,
        outcome: outcome,
        metadata: %{}
      )
    )

    result
  end

  # -- OAuth Integration (Phase 5 Plan 02) --

  @doc """
  Registers a new user via OAuth provider callback data.

  Creates user + identity in a transaction. Sets confirmed_at if provider
  email is trusted. Creates a session with auth_method: :oauth metadata.

  Delegates to `Sigra.OAuth.Callback.process_callback/4` for the full
  account routing logic (register/login/link-confirm).
  """
  @doc since: "0.5.0"
  @spec register_oauth(Sigra.Config.t() | map(), atom(), map(), map()) ::
          {:ok, :registered, map(), map()} | {:error, term()}
  def register_oauth(config, provider, user_info, token) do
    Sigra.OAuth.Callback.process_callback(config, provider, user_info, token)
  end

  @doc """
  Logs in an existing user via OAuth identity match.

  Looks up identity by (provider, provider_uid), updates identity fields,
  creates session with auth_method: :oauth metadata.

  Delegates to `Sigra.OAuth.Callback.process_callback/4`.
  """
  @doc since: "0.5.0"
  @spec login_oauth(Sigra.Config.t() | map(), atom(), map(), map()) ::
          {:ok, :logged_in, map(), map()}
          | {:link_confirmation_required, map()}
          | {:error, term()}
  def login_oauth(config, provider, user_info, token) do
    Sigra.OAuth.Callback.process_callback(config, provider, user_info, token)
  end

  @doc """
  Links an OAuth provider to an existing authenticated user.

  Requires sudo mode active. Creates identity record, sends notification email.

  Returns `{:ok, identity}` or `{:error, reason}`.
  """
  @doc since: "0.5.0"
  @spec link_provider(Sigra.Config.t() | map(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def link_provider(config, user, provider_info, opts \\ []) do
    Sigra.OAuth.link_provider(config, user, provider_info, opts)
  end

  @doc """
  Unlinks an OAuth provider from a user.

  Blocks if last auth method and no password set (D-03).
  Sends notification email. Returns `{:ok, :unlinked}` or `{:error, reason}`.
  """
  @doc since: "0.5.0"
  @spec unlink_provider(Sigra.Config.t() | map(), map(), atom() | String.t(), keyword()) ::
          {:ok, :unlinked} | {:error, :last_provider | :not_found}
  def unlink_provider(config, user, provider, opts \\ []) do
    Sigra.OAuth.unlink_provider(config, user, provider, opts)
  end

  # -- MFA Session Management (Phase 6 Plan 02) --

  @doc """
  Completes MFA verification by rotating the session token and upgrading
  the session type from :mfa_pending to :standard or :remember_me.

  Called after successful TOTP or backup code verification. The old
  mfa_pending session token is invalidated and a new token is issued,
  preventing session fixation attacks.

  ## Options

    * `:remember_me` - If `true`, upgrades to `:remember_me` session. Default: `false`.
    * `:trust_browser` - If `true`, includes trust_browser flag in result for
      "trust this browser" cookie. Default: `false`.

  ## Returns

    * `{:ok, %{session: session, trust_browser: boolean}}` on success
    * `{:error, reason}` if session creation fails
  """
  @doc since: "0.6.0"
  @spec complete_mfa_verification(Sigra.Config.t(), struct(), Sigra.Session.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def complete_mfa_verification(config, user, old_session, opts \\ []) do
    remember_me = Keyword.get(opts, :remember_me, false)
    trust_browser = Keyword.get(opts, :trust_browser, false)
    target_type = if remember_me, do: :remember_me, else: :standard

    {session_store, store_opts} = session_store_and_opts(config, opts)

    # Delete old mfa_pending session (invalidate old token)
    session_store.delete(old_session.hashed_token, store_opts)

    # Create new session with upgraded type
    metadata = %{type: target_type}

    case create_session(config, user, metadata) do
      {:ok, new_session} ->
        Telemetry.event([:sigra, :mfa, :verification_complete], %{}, %{
          user_id: user.id,
          target_type: target_type,
          trust_browser: trust_browser
        })

        {:ok, %{session: new_session, trust_browser: trust_browser}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- Private helpers --

  defp session_store_and_opts(config, opts) do
    session_config = config.session
    session_store = Keyword.get(opts, :session_store) || Keyword.get(session_config, :store)
    store_opts = [repo: config.repo, session_schema: Keyword.get(session_config, :session_schema)]
    {session_store, store_opts}
  end

  defp email_taken_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:email, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  defp handle_valid_login(repo, user, require_confirmation, extra_changes, _opts) do
    if require_confirmation and is_nil(Map.get(user, :confirmed_at)) do
      {:error, :unconfirmed}
    else
      failed_before = Map.get(user, :failed_login_attempts, 0)

      # Reset failed attempts + apply any extra changes (hash upgrade)
      changes = Map.merge(%{failed_login_attempts: 0}, extra_changes)
      changeset = Ecto.Changeset.change(user, changes)

      case repo.update(changeset) do
        {:ok, updated_user} ->
          Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
            user_id: updated_user.id,
            failed_attempts_before: failed_before
          })

          {:ok, updated_user}

        {:error, _changeset} ->
          # Best-effort update -- still return success for auth
          Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
            user_id: user.id,
            failed_attempts_before: failed_before
          })

          {:ok, user}
      end
    end
  end

  defp increment_failed_attempts(repo, user) do
    current = Map.get(user, :failed_login_attempts, 0)
    changeset = Ecto.Changeset.change(user, failed_login_attempts: current + 1)

    # Best-effort update
    repo.update(changeset)
  end

  defp rate_limited?(rate_limiter, key, max_requests, window_ms) do
    case rate_limiter.check_rate(key, max_requests, window_ms) do
      {:allow, _count} -> false
      {:deny, _retry_after} -> true
    end
  end

  defp maybe_confirm_user(repo, user) do
    if is_nil(Map.get(user, :confirmed_at)) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      changeset = Ecto.Changeset.change(user, confirmed_at: now)

      case repo.update(changeset) do
        {:ok, updated} -> updated
        {:error, _} -> user
      end
    else
      user
    end
  end

  # -- Config-based authenticate helpers (Phase 4 Plan 04) --

  defp handle_valid_login_with_security(
         config,
         repo,
         user,
         require_confirmation,
         extra_changes,
         login_ip,
         opts \\ []
       ) do
    skip_reset = Keyword.get(opts, :skip_lockout_reset, false)
    skip_extra = Keyword.get(opts, :skip_extra_hash, false)

    if require_confirmation and is_nil(Map.get(user, :confirmed_at)) do
      {:error, :unconfirmed}
    else
      # Reset lockout state on successful login (D-26), unless a caller
      # Multi already applied it (AUD-05 B3 / config-based authenticate).
      updated_user =
        if skip_reset do
          user
        else
          Sigra.Lockout.reset!(repo, user)
        end

      # Apply any extra changes (hash upgrade), unless already applied upstream.
      updated_user =
        cond do
          skip_extra ->
            updated_user

          map_size(extra_changes) > 0 ->
            changeset = Ecto.Changeset.change(updated_user, extra_changes)

            case repo.update(changeset) do
              {:ok, u} -> u
              {:error, _} -> updated_user
            end

          true ->
            updated_user
        end

      Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
        user_id: updated_user.id,
        failed_attempts_before: Map.get(user, :failed_login_attempts, 0)
      })

      # Check suspicious login (D-44)
      suspicious_details =
        case Sigra.SuspiciousLogin.detect(config, updated_user.id, login_ip || "") do
          {:suspicious, details} ->
            maybe_deliver_suspicious_login_email(config, updated_user, details)
            %{suspicious_login: details}

          :ok ->
            %{}
        end

      # Check MFA enrollment and create appropriate session (D-22, D-27, D-30)
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
    end
  end

  defp handle_enterprise_password_login(
         config,
         repo,
         user,
         require_confirmation,
         audit_opts,
         login_ip,
         extra_changes,
         metadata
       ) do
    case EnterpriseAuthPolicy.password_login_allowed?(config, user) do
      :allow ->
        login_success_password_path(
          config,
          repo,
          user,
          require_confirmation,
          audit_opts,
          login_ip,
          extra_changes,
          metadata
        )

      {:deny, reason, denial_metadata} ->
        user_scope = Sigra.Scope.from_config(config, user)

        Audit.log_safe(
          "auth.login.failure",
          user_scope,
          Keyword.merge(audit_opts,
            actor_id: user.id,
            target_id: user.id,
            outcome: "failure",
            metadata: Map.put(denial_metadata, :reason, reason)
          )
        )

        {:error, reason}
    end
  end

  defp handle_failed_login_with_lockout(config, repo, user, login_ip, lockout_opts) do
    threshold = Keyword.get(lockout_opts, :threshold, 5)
    new_count = (user.failed_login_attempts || 0) + 1
    lockout_step? = new_count >= threshold && is_nil(user.locked_at)

    changes =
      if lockout_step? do
        %{
          failed_login_attempts: new_count,
          locked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      else
        %{failed_login_attempts: new_count}
      end

    user_cs = Ecto.Changeset.change(user, changes)
    audit_opts = audit_opts_from_config(config, ip_address: login_ip)

    if Keyword.get(audit_opts, :audit_schema) do
      multi =
        Multi.new()
        |> Multi.update(:user, user_cs)
        |> Audit.log_multi_safe(
          "security.invalid_credentials",
          Keyword.merge(audit_opts,
            audit_multi_step: :audit_failed_invalid_credentials,
            actor_resolver: fn %{user: u} -> u.id end,
            target_resolver: fn _ -> nil end,
            outcome: "failure",
            metadata_resolver: fn %{user: u} ->
              %{attempts: u.failed_login_attempts}
            end
          )
        )

      multi =
        if lockout_step? do
          Audit.log_multi_safe(
            multi,
            "security.lockout",
            Keyword.merge(audit_opts,
              audit_multi_step: :audit_failed_security_lockout,
              actor_resolver: fn %{user: u} -> u.id end,
              target_resolver: fn %{user: u} -> u.id end,
              effective_user_id_resolver: fn %{user: u} -> u.id end,
              outcome: "failure",
              metadata_resolver: fn %{user: u} ->
                %{reason: "threshold_reached", attempts: u.failed_login_attempts}
              end
            )
          )
        else
          multi
        end

      case repo.transaction(multi) do
        {:ok, %{user: updated_user} = ch} ->
          telemetry_steps =
            if lockout_step? do
              [:audit_failed_invalid_credentials, :audit_failed_security_lockout]
            else
              [:audit_failed_invalid_credentials]
            end

          Audit.emit_telemetry_from_changes(ch, telemetry_steps)

          cond do
            lockout_step? ->
              Telemetry.event([:sigra, :security, :lockout], %{}, %{
                user_id: user.id,
                ip: login_ip,
                reason: :threshold_reached
              })

              maybe_deliver_lockout_email(config, updated_user, %{ip: login_ip})
              {:error, :account_locked}

            true ->
              {:error, :invalid_credentials}
          end

        {:error, _step, reason, _} ->
          {:error, reason}
      end
    else
      updated_user = Sigra.Lockout.increment!(repo, user, lockout_opts)
      new_count = updated_user.failed_login_attempts
      audit_opts = audit_opts_from_config(config, ip_address: login_ip)

      Sigra.Audit.log_safe(
        "security.invalid_credentials",
        nil,
        Keyword.merge(audit_opts,
          actor_id: user.id,
          target_id: nil,
          outcome: "failure",
          metadata: %{attempts: new_count}
        )
      )

      if new_count >= threshold do
        Telemetry.event([:sigra, :security, :lockout], %{}, %{
          user_id: user.id,
          ip: login_ip,
          reason: :threshold_reached
        })

        Sigra.Audit.log_safe(
          "security.lockout",
          Sigra.Scope.from_config(config, user),
          Keyword.merge(audit_opts,
            actor_id: user.id,
            target_id: user.id,
            outcome: "failure",
            metadata: %{reason: "threshold_reached", attempts: new_count}
          )
        )

        maybe_deliver_lockout_email(config, user, %{ip: login_ip})
        {:error, :account_locked}
      else
        {:error, :invalid_credentials}
      end
    end
  end

  defp maybe_deliver_suspicious_login_email(config, user, details) do
    notify? = Keyword.get(config.suspicious_login, :notify, true)
    email_module = config.email_module
    mailer = config.mailer

    if notify? && email_module && mailer do
      email = email_module.suspicious_login_email(user, details)
      mailer.deliver(email.to, email.subject, email.body)
    end
  end

  defp maybe_deliver_lockout_email(config, user, details) do
    notify? = Keyword.get(config.lockout, :notify, true)
    email_module = config.email_module
    mailer = config.mailer

    if notify? && email_module && mailer do
      email = email_module.lockout_notification_email(user, details)
      mailer.deliver(email.to, email.subject, email.body)
    end
  end

  # -- API Token Management (Phase 7 Plan 03) --

  @doc """
  Creates an API token for the user.

  Returns `{:ok, raw_key, token}` on success. Sends a notification email
  on successful creation if the email module is configured (D-62).

  ## Parameters

  - `config` - A `%Sigra.Config{}` struct
  - `user` - The user struct (must have an `:id` field)
  - `attrs` - A map with `:name`, `:scopes`, and optional `:expires_at`
  """
  @doc since: "0.7.0"
  @spec create_api_token(Sigra.Config.t(), struct(), map()) ::
          {:ok, String.t(), struct()} | {:error, term()}
  def create_api_token(config, user, attrs) do
    result = Sigra.APIToken.create(config, user, attrs)

    case result do
      {:ok, _raw_key, token} ->
        maybe_send_api_token_email(config, user, token)
        result

      _ ->
        result
    end
  end

  @doc """
  Revokes an API token by ID.
  """
  @doc since: "0.7.0"
  @spec revoke_api_token(Sigra.Config.t(), term()) :: {:ok, struct()} | {:error, :not_found}
  def revoke_api_token(config, token_id) do
    Sigra.APIToken.revoke(config, token_id)
  end

  @doc """
  Revokes all active API tokens for a user.
  """
  @doc since: "0.7.0"
  @spec revoke_all_api_tokens(Sigra.Config.t(), struct()) :: {:ok, non_neg_integer()}
  def revoke_all_api_tokens(config, user) do
    Sigra.APIToken.revoke_all(config, user)
  end

  @doc """
  Lists active API tokens for a user with cursor pagination.
  """
  @doc since: "0.7.0"
  @spec list_api_tokens(Sigra.Config.t(), term(), keyword()) :: {[struct()], String.t() | nil}
  def list_api_tokens(config, user_id, opts \\ []) do
    Sigra.APIToken.list_active(config, user_id, opts)
  end

  @doc """
  Returns all registered API token scopes.
  """
  @doc since: "0.7.0"
  @spec list_api_scopes(Sigra.Config.t()) :: [String.t()]
  def list_api_scopes(config) do
    Sigra.APIToken.list_scopes(config)
  end

  # -- JWT (Phase 7 Plan 03) --

  @doc """
  Generates JWT access + refresh tokens for a user.
  """
  @doc since: "0.7.0"
  @spec generate_jwt_tokens(Sigra.Config.t(), struct(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def generate_jwt_tokens(config, user, scopes) do
    Sigra.JWT.generate_tokens(config, user, scopes)
  end

  @doc """
  Refreshes JWT tokens using a refresh token.

  When **`:audit_schema`** is set, persistence and JWT audit share one
  transaction; failures there return **`{:error, :jwt_refresh_aborted}`** (see
  **`Sigra.JWT.refresh/3`**).
  """
  @doc since: "0.7.0"
  @spec refresh_jwt(Sigra.Config.t(), String.t()) ::
          {:ok, map()}
          | {:error,
             :invalid_token
             | :token_expired
             | :reuse_detected
             | :jwt_refresh_aborted}
  def refresh_jwt(config, raw_refresh_token) do
    Sigra.JWT.refresh(config, raw_refresh_token)
  end

  @doc """
  Revokes a JWT refresh token.
  """
  @doc since: "0.7.0"
  @spec revoke_jwt_refresh(Sigra.Config.t(), String.t()) :: :ok | {:error, :invalid_token}
  def revoke_jwt_refresh(config, raw_refresh_token) do
    Sigra.JWT.revoke_refresh(config, raw_refresh_token)
  end

  defp maybe_send_api_token_email(config, user, token) do
    if config.email_module && config.mailer do
      try do
        email = config.email_module.api_token_created_email(user, token)
        config.mailer.deliver(email.to, email.subject, email.body)
      rescue
        UndefinedFunctionError -> :ok
      end
    end
  end

  # -- Account Lifecycle (Phase 8 Plan 03) --

  @doc """
  Request an email change for the user.

  Generates a verification token for the new email address and returns
  it for delivery. The email is not changed until confirmed via
  `confirm_email_change/3`.
  """
  @doc since: "0.8.0"
  @spec request_email_change(Sigra.Config.t(), struct(), String.t(), keyword()) ::
          {:ok, struct(), String.t()} | {:error, term()}
  def request_email_change(config, user, new_email, opts \\ []) do
    repo = config.repo
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          user_token_schema: user_token_schema,
          secret_key_base: config.secret_key_base,
          config: config,
          build_email_token_fn: fn user, context ->
            user_token_schema.build_email_token(user, context)
          end,
          token_query_fn: fn user, contexts ->
            user_token_schema.by_user_and_contexts_query(user, contexts)
          end,
          email_taken_fn: fn repo, email ->
            repo.get_by(config.user_schema, email: email) != nil
          end
        ],
        opts
      )

    Sigra.Account.request_email_change(repo, user, new_email, merged_opts)
  end

  @doc """
  Confirm an email change via token.

  Verifies the HMAC-signed token, updates the user's email, and
  invalidates all existing sessions (forcing re-authentication).
  """
  @doc since: "0.8.0"
  @spec confirm_email_change(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def confirm_email_change(config, encoded_token, opts \\ []) do
    repo = config.repo
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    {session_store, session_store_opts} = session_store_and_opts(config, opts)

    merged_opts =
      Keyword.merge(
        [
          user_token_schema: user_token_schema,
          user_schema: config.user_schema,
          session_store: session_store,
          session_store_opts: session_store_opts,
          config: config,
          find_user_by_token_fn: fn repo, token ->
            context_prefix = "change:"

            case user_token_schema.verify_email_token_query(token, context_prefix) do
              {:ok, query} -> repo.one(query)
              :error -> nil
            end
          end,
          changeset_fn:
            Keyword.get_lazy(opts, :changeset_fn, fn ->
              fn user, attrs -> Ecto.Changeset.change(user, attrs) end
            end),
          token_query_fn: fn user, contexts ->
            user_token_schema.by_user_and_contexts_query(user, contexts)
          end
        ],
        opts
      )

    Sigra.Account.confirm_email_change(repo, encoded_token, merged_opts)
  end

  @doc """
  Cancel a pending email change.

  Clears the `pending_email` field and deletes the email change token.
  """
  @doc since: "0.8.0"
  @spec cancel_email_change(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def cancel_email_change(config, user, opts \\ []) do
    repo = config.repo
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          user_token_schema: user_token_schema,
          token_query_fn: fn user, contexts ->
            user_token_schema.by_user_and_contexts_query(user, contexts)
          end
        ],
        opts
      )

    Sigra.Account.cancel_email_change(repo, user, merged_opts)
  end

  @doc """
  Change password with current password verification.

  Verifies the current password, updates to the new password, and
  invalidates all sessions except the current one.
  """
  @doc since: "0.8.0"
  @spec change_password(Sigra.Config.t(), struct(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def change_password(config, user, current_password, attrs, opts \\ []) do
    repo = config.repo
    {session_store, session_store_opts} = session_store_and_opts(config, opts)

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          session_store: session_store,
          session_store_opts: session_store_opts,
          config: config,
          validate_password_fn: fn user, password ->
            config.user_schema.valid_password?(user, password)
          end
        ],
        opts
      )

    Sigra.Account.change_password(repo, user, current_password, attrs, merged_opts)
  end

  @doc """
  Set password for OAuth-only user.

  Allows users who registered via OAuth (no password set) to add a
  password to their account. Requires sudo mode.
  """
  @doc since: "0.8.0"
  @spec set_password(Sigra.Config.t(), struct(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def set_password(config, user, attrs, opts \\ []) do
    repo = config.repo

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          config: config
        ],
        opts
      )

    Sigra.Account.set_password(repo, user, attrs, merged_opts)
  end

  @doc """
  Schedule account deletion with grace period.

  Immediately deactivates the account (revokes sessions/tokens) and
  schedules final deletion after the configured grace period.
  """
  @doc since: "0.8.0"
  @spec schedule_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct(), DateTime.t()} | {:error, term()}
  def schedule_deletion(config, user, opts \\ []) do
    repo = config.repo
    {session_store, session_store_opts} = session_store_and_opts(config, opts)

    merged_opts =
      Keyword.merge(
        [
          config: config,
          repo: repo,
          user_schema: config.user_schema,
          scope_module: Map.get(config, :scope_module),
          audit_schema: get_in(config, [:audit, :audit_schema]),
          session_store: session_store,
          session_store_opts: session_store_opts,
          session_schema: get_in(config, [:session, :session_schema]),
          user_token_schema: Keyword.fetch!(opts, :user_token_schema)
        ],
        opts
      )

    Sigra.Account.schedule_deletion(repo, user, merged_opts)
  end

  @doc """
  Cancel scheduled account deletion.

  Clears deletion timestamps and reactivates the account. The user
  must re-authenticate (all sessions were revoked on scheduling).
  """
  @doc since: "0.8.0"
  @spec cancel_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def cancel_deletion(config, user, opts \\ []) do
    merged_opts =
      Keyword.merge(
        [
          repo: config.repo,
          user_schema: config.user_schema,
          scope_module: Map.get(config, :scope_module),
          audit_schema: get_in(config, [:audit, :audit_schema])
        ],
        opts
      )

    Sigra.Account.cancel_deletion(config.repo, user, merged_opts)
  end

  @doc """
  Execute account deletion (called by Oban worker).

  Applies the configured deletion strategy (soft_delete, hard_delete,
  or anonymize) to finalize the account removal.
  """
  @doc since: "0.8.0"
  @spec execute_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, atom()} | {:error, term()}
  def execute_deletion(config, user, opts \\ []) do
    merged_opts =
      Keyword.merge(
        [
          repo: config.repo,
          user_schema: config.user_schema,
          scope_module: Map.get(config, :scope_module),
          audit_schema: get_in(config, [:audit, :audit_schema])
        ],
        opts
      )

    Sigra.Account.execute_deletion(config.repo, user, merged_opts)
  end

  # -- Private helpers --

  # Rejection sampling to eliminate modulo bias. A 4-byte unsigned integer
  # has max value 4,294,967,295. Values >= floor(2^32 / range) * range are
  # rejected to ensure uniform distribution across [0, range).
  @max_uint32 4_294_967_296
  defp uniform_random(range) when range > 0 do
    limit = div(@max_uint32, range) * range

    n =
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()

    if n >= limit do
      uniform_random(range)
    else
      rem(n, range)
    end
  end
end
