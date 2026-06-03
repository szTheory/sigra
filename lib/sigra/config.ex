defmodule Sigra.Config do
  @moduledoc """
  Configuration for Sigra authentication.

  Sigra uses `NimbleOptions` for compile-time validated configuration with
  auto-generated documentation. Only `:repo` and `:user_schema` are required;
  all other options have secure, OWASP-grade defaults.

  ## Usage

      config = Sigra.Config.new!(
        repo: MyApp.Repo,
        user_schema: MyApp.Accounts.User
      )

  ## Options

  #{NimbleOptions.docs(repo: [type: :atom, required: true, doc: "The Ecto Repo module for database operations."],
  user_schema: [type: :atom, required: true, doc: "The Ecto schema module for users."],
  otp_app: [type: :atom, doc: "The OTP application name. Used for config.exs convenience layer."],
  secret_key_base: [type: {:or, [:string, nil]}, default: nil, doc: "The host app's secret key base. Required for JWT HS256 signing and token operations."],
  mailer: [type: :atom, doc: "The mailer module implementing `Sigra.Mailer` behaviour."],
  email_module: [type: {:or, [:atom, nil]}, default: nil, doc: "The generated email template module implementing `Sigra.EmailTemplates` behaviour."],
  password: [type: :keyword_list, default: [], doc: "Password hashing and validation options.", keys: [min_length: [type: :pos_integer, default: 8, doc: "Minimum password length. NIST SP 800-63B recommends at least 8."], max_length: [type: :pos_integer, default: 72, doc: "Maximum password length. Set to 72 to match bcrypt's limit for migration compatibility."], hasher: [type: :atom, default: Sigra.Hashers.Argon2, doc: "Module implementing the `Sigra.Hasher` behaviour."], notify_on_change: [type: :boolean, default: true, doc: "Send notification email when password is changed. Default: true."], invalidate_sessions_on_change: [type: :boolean, default: true, doc: "Invalidate all other sessions on password change. Default: true."]]],
  password_policy: [type: :keyword_list, default: [], doc: "Password validation policy options for `Sigra.PasswordPolicy`.", keys: [min_length: [type: :pos_integer, default: 8, doc: "Minimum password length. Default: 8 (NIST SP 800-63B)."], max_bytes: [type: :pos_integer, default: 72, doc: "Maximum password byte size. Default: 72 (bcrypt compatibility)."], require_uppercase: [type: :boolean, default: false, doc: "Require at least one uppercase letter. Default: false."], require_digit: [type: :boolean, default: false, doc: "Require at least one digit. Default: false."], require_special: [type: :boolean, default: false, doc: "Require at least one special character. Default: false."], check_common: [type: :boolean, default: true, doc: "Check against the embedded common passwords list. Default: true."], check_breached: [type: :boolean, default: false, doc: "Check against the HIBP breached passwords API. Default: false."], password_max_age: [type: {:or, [:pos_integer, nil]}, default: nil, doc: "Maximum password age in seconds before forced rotation. Default: nil (disabled)."]]],
  magic_link: [type: :keyword_list, default: [], doc: "Magic link authentication options.", keys: [ttl: [type: :pos_integer, default: 600, doc: "Magic link token TTL in seconds. Default: 600 (10 minutes)."], max_requests: [type: :pos_integer, default: 3, doc: "Maximum magic link requests within the rate limit window. Default: 3."], window_seconds: [type: :pos_integer, default: 900, doc: "Rate limit window for magic link requests in seconds. Default: 900 (15 minutes)."]]],
  require_confirmation: [type: :boolean, default: false, doc: "Whether email confirmation is required before login. Default: false."],
  session_ttl: [type: :pos_integer, default: 5_184_000, doc: "Session time-to-live in seconds. Default: 5,184,000 (60 days)."],
  session: [type: :keyword_list, default: [], doc: "Session management options.", keys: [remember_me_max_age: [type: :pos_integer, default: 60 * 24 * 60 * 60, doc: "Max age for remember-me cookies in seconds. Default: 60 days (5,184,000s)."], reissue_age: [type: :pos_integer, default: 7 * 24 * 60 * 60, doc: "Age after which session tokens are reissued. Default: 7 days."], store: [type: :atom, default: Sigra.SessionStores.Ecto, doc: "Module implementing the `Sigra.SessionStore` behaviour."], idle_timeout: [type: :pos_integer, default: 1_800, doc: "Idle timeout in seconds. Default: 1800 (30 minutes)."], absolute_timeout: [type: :pos_integer, default: 86_400, doc: "Absolute session timeout in seconds. Default: 86400 (24 hours)."], activity_update_threshold: [type: :pos_integer, default: 300, doc: "Minimum seconds between last_active_at DB writes. Default: 300 (5 minutes)."], sudo_timeout: [type: :pos_integer, default: 300, doc: "Sudo mode window in seconds. Default: 300 (5 minutes)."], session_schema: [type: :atom, doc: "The generated UserSession Ecto schema module."]]],
  token_ttl: [type: :keyword_list, default: [], doc: "Token time-to-live values in seconds.", keys: [confirm: [type: :pos_integer, default: 48 * 60 * 60, doc: "Email confirmation token TTL. Default: 48 hours."], reset_password: [type: :pos_integer, default: 60 * 60, doc: "Password reset token TTL. Default: 1 hour."], magic_link: [type: :pos_integer, default: 15 * 60, doc: "Magic link token TTL. Default: 15 minutes."], email_change: [type: :pos_integer, default: 24 * 60 * 60, doc: "Email change token TTL in seconds. Default: 24 hours."]]],
  rate_limiting: [type: :keyword_list, default: [], doc: "Rate limiting options.", keys: [limiter: [type: {:or, [:atom, nil]}, default: nil, doc: "Module implementing the `Sigra.RateLimiter` behaviour. Nil disables rate limiting."], ip_limit: [type: :pos_integer, default: 10, doc: "Maximum requests per IP within the window. Default: 10."], ip_window_ms: [type: :pos_integer, default: 60_000, doc: "IP rate limiting window in milliseconds. Default: 60 seconds."], account_limit: [type: :pos_integer, default: 5, doc: "Maximum failed attempts per account before lockout. Default: 5."]]],
  confirmation: [type: :keyword_list, default: [], doc: "Email confirmation options.", keys: [unconfirmed_access: [type: {:in, [:allow_with_banner, :block]}, default: :allow_with_banner, doc: "Behavior for unconfirmed users. :allow_with_banner shows a reminder, :block prevents login."], code_length: [type: :pos_integer, default: 6, doc: "Length of the numeric confirmation code. Default: 6."], max_resends: [type: :pos_integer, default: 3, doc: "Maximum confirmation resend requests per window. Default: 3."], resend_window_seconds: [type: :pos_integer, default: 900, doc: "Rate limit window for confirmation resend in seconds. Default: 900 (15 minutes)."], code_max_attempts: [type: :pos_integer, default: 5, doc: "Maximum code entry attempts per window. Default: 5."], code_window_seconds: [type: :pos_integer, default: 900, doc: "Rate limit window for code entry in seconds. Default: 900 (15 minutes)."]]],
  reset: [type: :keyword_list, default: [], doc: "Password reset options.", keys: [max_requests: [type: :pos_integer, default: 3, doc: "Maximum reset requests per email per window. Default: 3."], window_seconds: [type: :pos_integer, default: 900, doc: "Rate limit window for reset requests in seconds. Default: 900 (15 minutes)."]]],
  email: [type: :keyword_list, default: [], doc: "Email delivery options.", keys: [from_address: [type: :string, doc: "From address for transactional emails. Default derived from endpoint config."], delivery_mode: [type: {:in, [:auto, :async, :sync]}, default: :auto, doc: "Email delivery mode. :auto detects Oban presence. Default: :auto."], oban_queue: [type: :string, default: "sigra_mailer", doc: "Oban queue name for async email delivery. Default: \"sigra_mailer\"."], oban_concurrency: [type: :pos_integer, default: 10, doc: "Maximum concurrent email delivery workers. Default: 10."]]],
  lockout: [type: :keyword_list, default: [], doc: "Account lockout options.", keys: [threshold: [type: :pos_integer, default: 5, doc: "Failed attempts before lockout. Default: 5."], duration: [type: :pos_integer, default: 900, doc: "Lockout duration in seconds. Default: 900 (15 minutes)."], notify: [type: :boolean, default: true, doc: "Send lockout notification email. Default: true."]]],
  geo_ip: [type: :keyword_list, default: [], doc: "GeoIP lookup options.", keys: [module: [type: {:or, [:atom, nil]}, default: nil, doc: "Module implementing Sigra.GeoIP behaviour. Default: nil (disabled)."]]],
  suspicious_login: [type: :keyword_list, default: [], doc: "Suspicious login detection options.", keys: [enabled: [type: :boolean, default: true, doc: "Enable suspicious login detection. Default: true."], notify: [type: :boolean, default: true, doc: "Send suspicious login notification email. Default: true."]]],
  mfa: [type: :keyword_list, default: [], doc: "Multi-factor authentication options.", keys: [enabled: [type: :boolean, default: true, doc: "Enable MFA support. Default: true."], totp_issuer: [type: {:or, [:string, nil]}, default: nil, doc: "TOTP issuer name for authenticator apps. Falls back to humanized otp_app. Default: nil."], totp_drift_steps: [type: :non_neg_integer, default: 1, doc: "TOTP drift window in 30-second steps. Default: 1."], backup_code_count: [type: :pos_integer, default: 8, doc: "Number of backup codes generated per enrollment. Default: 8."], trust_enabled: [type: :boolean, default: true, doc: "Enable trust-this-browser cookies. Default: true."], trust_ttl: [type: :pos_integer, default: 2_592_000, doc: "Trust cookie TTL in seconds (default 30 days). Default: 2,592,000."], lockout_threshold: [type: :pos_integer, default: 5, doc: "Failed MFA attempts before lockout. Default: 5."], lockout_duration: [type: :pos_integer, default: 900, doc: "MFA lockout duration in seconds (default 15 min). Default: 900."], pending_timeout: [type: :pos_integer, default: 300, doc: "MFA pending session timeout in seconds (default 5 min). Default: 300."], show_trust_option: [type: :boolean, default: true, doc: "Show trust-this-browser checkbox on MFA challenge. Default: true."]]],
  passkeys: [type: :keyword_list, default: [], doc: "Passkey (WebAuthn) options.", keys: [enabled: [type: :boolean, default: true, doc: "Enable passkey support. Default: true."], passkey_primary_enabled: [type: :boolean, default: false, doc: "Enable passkey-primary login. Passkey MFA and enrollment are still controlled by :enabled. Default: false."], sign_count_policy: [type: {:in, [:warn, :require_reauth, :revoke]}, default: :warn, doc: "Sign-count regression policy. Default: :warn to accommodate synced passkeys."], max_per_user: [type: :pos_integer, default: 10, doc: "Maximum passkeys per user. Enforced atomically. Default: 10."], rp_id: [type: {:or, [:string, nil]}, default: nil, doc: "Relying party ID. Default: nil."], rp_name: [type: :string, default: "Sigra", doc: "Relying party display name. Default: \"Sigra\"."], origin: [type: {:or, [:string, nil]}, default: nil, doc: "Relying party origin (https://...). Default: nil."], attestation: [type: {:in, [:none, :indirect, :direct]}, default: :none, doc: "Attestation conveyance preference. Default: :none."], user_verification: [type: {:in, [:preferred, :required, :discouraged]}, default: :preferred, doc: "User verification requirement. Default: :preferred."], timeout_ms: [type: :pos_integer, default: 60_000, doc: "Passkey ceremony timeout in milliseconds. Default: 60_000."], ceremony_rate_limit: [type: :keyword_list, default: [], doc: "Per-user ceremony initiation rate limit. Default: 5 per 60_000ms.", keys: [limit: [type: :pos_integer, default: 5, doc: "Maximum ceremony initiations per user within the window. Default: 5."], window_ms: [type: :pos_integer, default: 60_000, doc: "Ceremony initiation window in milliseconds. Default: 60_000."]]], user_passkey_schema: [type: {:or, [:atom, nil]}, default: nil, doc: "Generated host UserPasskey schema module. Default: nil."]]],
  oauth: [type: :keyword_list, default: [], doc: "OAuth / social login options.", keys: [enabled: [type: :boolean, default: true, doc: "Master switch for OAuth. When false, OAuth routes are disabled and buttons hidden (D-63)."], providers: [type: :keyword_list, default: [], doc: "Provider configurations. Each key is a provider atom, value is a keyword list with :client_id, :client_secret, :redirect_uri, and optional :strategy, :scopes."], session_type: [type: {:in, [:standard, :remember_me]}, default: :remember_me, doc: "Session type for OAuth logins. Default: :remember_me (D-43)."], link_confirmation: [type: {:in, [:required, :auto]}, default: :required, doc: "Account linking behavior when OAuth email matches existing account. Default: :required (D-01)."], trust_provider_email: [type: :boolean, default: true, doc: "Whether to auto-confirm email based on provider verification. Set false for Facebook (D-42)."]]],
  api_token: [type: :keyword_list, default: [], doc: "API token options.", keys: [prefix: [type: {:or, [:string, nil]}, default: nil, doc: "Token prefix. Nil derives from otp_app: {otp_app}_sk_. Must match ^[a-z0-9_]+$ and not start with eyJ."], custom_scopes: [type: {:list, :string}, default: [], doc: "Custom scope strings in resource:action format."], write_implies_read: [type: :boolean, default: false, doc: "Whether write scope implies read. Default: false."], require_expiry: [type: :boolean, default: false, doc: "Whether expiration is required. Default: false."], max_ttl: [type: {:or, [:pos_integer, nil]}, default: nil, doc: "Maximum TTL in seconds. Nil = no limit."], cleanup_retention: [type: :pos_integer, default: 90 * 24 * 60 * 60, doc: "Retention period for revoked/expired tokens in seconds. Default: 90 days."], activity_update_threshold: [type: :pos_integer, default: 300, doc: "Minimum seconds between last_used_at writes. Default: 300."], default_page_size: [type: :pos_integer, default: 50, doc: "Default page size for token listing. Default: 50."], max_page_size: [type: :pos_integer, default: 200, doc: "Maximum page size. Default: 200."], api_token_schema: [type: {:or, [:atom, nil]}, default: nil, doc: "The generated UserAPIToken schema module."]]],
  jwt: [type: :keyword_list, default: [], doc: "JWT options (requires Joken ~> 2.6 as optional dependency).", keys: [enabled: [type: :boolean, default: false, doc: "Enable JWT support. Default: false."], algorithm: [type: {:in, ["HS256", "RS256", "ES256"]}, default: "HS256", doc: "Signing algorithm. Default: HS256."], issuer: [type: {:or, [:string, nil]}, default: nil, doc: "JWT issuer claim. Nil = otp_app name."], access_ttl: [type: :pos_integer, default: 900, doc: "Access token TTL in seconds. Default: 900 (15 min)."], refresh_ttl: [type: :pos_integer, default: 30 * 24 * 60 * 60, doc: "Refresh token TTL in seconds. Default: 30 days."], refresh: [type: :boolean, default: true, doc: "Enable refresh tokens. Default: true."], claims_builder: [type: {:or, [:atom, nil]}, default: nil, doc: "Module implementing Sigra.JWT.ClaimsBuilder behaviour."], verify_epoch: [type: :boolean, default: true, doc: "Verify user token_epoch on every JWT request. Default: true."], private_key: [type: {:or, [:string, nil]}, default: nil, doc: "PEM private key for RS256/ES256."]]],
  deletion: [type: :keyword_list, default: [], doc: "Account deletion options.", keys: [strategy: [type: {:in, [:soft_delete, :hard_delete, :anonymize]}, default: :soft_delete, doc: "Deletion strategy. :soft_delete preserves row with deleted_at, :hard_delete removes row, :anonymize strips PII. Default: :soft_delete."], grace_period_days: [type: {:or, [:non_neg_integer, nil]}, default: 14, doc: "Days before scheduled deletion executes. 0 or nil for immediate. Default: 14."], cooldown_hours: [type: :pos_integer, default: 24, doc: "Hours after cancelling deletion before re-requesting is allowed. Default: 24."], notify: [type: :boolean, default: true, doc: "Send email notifications for deletion events. Default: true."]]],
  hooks: [type: :keyword_list, default: [], doc: "Lifecycle hook callbacks. Each is a {module, function} tuple or nil.", keys: [on_register: [type: {:or, [{:tuple, [:atom, :atom]}, nil]}, default: nil, doc: "Called after user registration. Receives (multi, context_map). Default: nil."], on_email_change: [type: {:or, [{:tuple, [:atom, :atom]}, nil]}, default: nil, doc: "Called after email change confirmation. Receives (multi, context_map). Default: nil."], on_password_change: [type: {:or, [{:tuple, [:atom, :atom]}, nil]}, default: nil, doc: "Called after password change. Receives (multi, context_map). Default: nil."], on_delete: [type: {:or, [{:tuple, [:atom, :atom]}, nil]}, default: nil, doc: "Called when deletion is scheduled. Receives (multi, context_map). Default: nil."]]],
  audit: [type: :keyword_list, default: [], doc: "Structured audit logging options (Phase 9). See `Sigra.Audit`.", keys: [audit_schema: [type: {:or, [:atom, nil]}, default: nil, doc: "The generated AuditEvent schema module. Default: nil."], retention_days: [type: {:or, [:pos_integer, nil]}, default: nil, doc: "Days to retain audit events. nil = keep forever (D-09). Default: nil."], max_metadata_bytes: [type: :pos_integer, default: 8_192, doc: "Cap on JSON-encoded metadata byte size (D-20). Default: 8192."], reserved_prefixes: [type: {:list, :string}, default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.), doc: "Reserved action prefixes developers cannot use (D-17, D-18)."]]])}
  """

  @schema [
    repo: [
      type: :atom,
      required: true,
      doc: "The Ecto Repo module for database operations."
    ],
    user_schema: [
      type: :atom,
      required: true,
      doc: "The Ecto schema module for users."
    ],
    otp_app: [
      type: :atom,
      doc: "The OTP application name. Used for config.exs convenience layer."
    ],
    secret_key_base: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "The host app's secret key base. Required for JWT HS256 signing and token operations."
    ],
    scope_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc:
        "The host app's generated Scope module (e.g. `MyApp.Accounts.Scope`). Required by Phase 14 organization plugs (`Sigra.Plug.PutActiveOrganization`) so the library can resolve the host's `put_active_organization/3` callback. Default: nil (legacy installs without organizations)."
    ],
    organizations_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc:
        "The host app's generated Organizations wrapper module (e.g. `MyApp.Organizations`), built via `use Sigra.Organizations`. Required by Phase 14 login-time selector wiring in `Sigra.Auth.create_session/4`. Default: nil (legacy installs without organizations)."
    ],
    mailer: [
      type: :atom,
      doc: "The mailer module implementing `Sigra.Mailer` behaviour."
    ],
    email_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc: "The generated email template module implementing `Sigra.EmailTemplates` behaviour."
    ],
    cookie_domain: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: """
      The cookie domain applied to Sigra-managed cookies (remember-me, MFA trust).

      Set to `nil` (the default) for host-only cookies — suitable for dev, test, and
      single-domain prod deployments. Set to a string like `".example.com"` for
      subdomain auth (recognized by `app.example.com`, `api.example.com`, etc.).

      Recommended prod pattern:

          config :my_app, MyApp.Auth.Config,
            cookie_domain: System.get_env("COOKIE_DOMAIN")

      A `Logger.warning` is emitted at application boot in the `:prod` environment
      if this value is nil. See `guides/recipes/subdomain-auth.md`.
      """
    ],
    mfa: [
      type: :keyword_list,
      default: [],
      doc: "Multi-factor authentication options.",
      keys: [
        enabled: [
          type: :boolean,
          default: true,
          doc: "Enable MFA support. Default: true."
        ],
        totp_issuer: [
          type: {:or, [:string, nil]},
          default: nil,
          doc:
            "TOTP issuer name for authenticator apps. Falls back to humanized otp_app. Default: nil."
        ],
        totp_drift_steps: [
          type: :non_neg_integer,
          default: 1,
          doc: "TOTP drift window in 30-second steps. Default: 1."
        ],
        backup_code_count: [
          type: :pos_integer,
          default: 8,
          doc: "Number of backup codes generated per enrollment. Default: 8."
        ],
        trust_enabled: [
          type: :boolean,
          default: true,
          doc: "Enable trust-this-browser cookies. Default: true."
        ],
        trust_ttl: [
          type: :pos_integer,
          default: 2_592_000,
          doc: "Trust cookie TTL in seconds (default 30 days). Default: 2,592,000."
        ],
        lockout_threshold: [
          type: :pos_integer,
          default: 5,
          doc: "Failed MFA attempts before lockout. Default: 5."
        ],
        lockout_duration: [
          type: :pos_integer,
          default: 900,
          doc: "MFA lockout duration in seconds (default 15 min). Default: 900."
        ],
        pending_timeout: [
          type: :pos_integer,
          default: 300,
          doc: "MFA pending session timeout in seconds (default 5 min). Default: 300."
        ],
        show_trust_option: [
          type: :boolean,
          default: true,
          doc: "Show trust-this-browser checkbox on MFA challenge. Default: true."
        ]
      ]
    ],
    password: [
      type: :keyword_list,
      default: [],
      doc: "Password hashing and validation options.",
      keys: [
        min_length: [
          type: :pos_integer,
          default: 8,
          doc: "Minimum password length. NIST SP 800-63B recommends at least 8."
        ],
        max_length: [
          type: :pos_integer,
          default: 72,
          doc:
            "Maximum password length. Set to 72 to match bcrypt's limit for migration compatibility."
        ],
        hasher: [
          type: :atom,
          default: Sigra.Hashers.Argon2,
          doc: "Module implementing the `Sigra.Hasher` behaviour."
        ],
        notify_on_change: [
          type: :boolean,
          default: true,
          doc: "Send notification email when password is changed. Default: true."
        ],
        invalidate_sessions_on_change: [
          type: :boolean,
          default: true,
          doc: "Invalidate all other sessions on password change. Default: true."
        ]
      ]
    ],
    password_policy: [
      type: :keyword_list,
      default: [],
      doc: "Password validation policy options for `Sigra.PasswordPolicy`.",
      keys: [
        min_length: [
          type: :pos_integer,
          default: 8,
          doc: "Minimum password length. Default: 8 (NIST SP 800-63B)."
        ],
        max_bytes: [
          type: :pos_integer,
          default: 72,
          doc: "Maximum password byte size. Default: 72 (bcrypt compatibility)."
        ],
        require_uppercase: [
          type: :boolean,
          default: false,
          doc: "Require at least one uppercase letter. Default: false."
        ],
        require_digit: [
          type: :boolean,
          default: false,
          doc: "Require at least one digit. Default: false."
        ],
        require_special: [
          type: :boolean,
          default: false,
          doc: "Require at least one special character. Default: false."
        ],
        check_common: [
          type: :boolean,
          default: true,
          doc: "Check against the embedded common passwords list. Default: true."
        ],
        check_breached: [
          type: :boolean,
          default: false,
          doc: "Check against the HIBP breached passwords API. Default: false."
        ],
        password_max_age: [
          type: {:or, [:pos_integer, nil]},
          default: nil,
          doc: "Maximum password age in seconds before forced rotation. Default: nil (disabled)."
        ]
      ]
    ],
    magic_link: [
      type: :keyword_list,
      default: [],
      doc: "Magic link authentication options.",
      keys: [
        ttl: [
          type: :pos_integer,
          default: 600,
          doc: "Magic link token TTL in seconds. Default: 600 (10 minutes)."
        ],
        max_requests: [
          type: :pos_integer,
          default: 3,
          doc: "Maximum magic link requests within the rate limit window. Default: 3."
        ],
        window_seconds: [
          type: :pos_integer,
          default: 900,
          doc: "Rate limit window for magic link requests in seconds. Default: 900 (15 minutes)."
        ]
      ]
    ],
    require_confirmation: [
      type: :boolean,
      default: false,
      doc: "Whether email confirmation is required before login. Default: false."
    ],
    session_ttl: [
      type: :pos_integer,
      default: 5_184_000,
      doc: "Session time-to-live in seconds. Default: 5,184,000 (60 days)."
    ],
    session: [
      type: :keyword_list,
      default: [],
      doc: "Session management options.",
      keys: [
        remember_me_max_age: [
          type: :pos_integer,
          default: 60 * 24 * 60 * 60,
          doc: "Max age for remember-me cookies in seconds. Default: 60 days (5,184,000s)."
        ],
        reissue_age: [
          type: :pos_integer,
          default: 7 * 24 * 60 * 60,
          doc: "Age after which session tokens are reissued. Default: 7 days."
        ],
        store: [
          type: :atom,
          default: Sigra.SessionStores.Ecto,
          doc: "Module implementing the `Sigra.SessionStore` behaviour."
        ],
        idle_timeout: [
          type: :pos_integer,
          default: 1_800,
          doc: "Idle timeout in seconds. Default: 1800 (30 minutes)."
        ],
        absolute_timeout: [
          type: :pos_integer,
          default: 86_400,
          doc: "Absolute session timeout in seconds. Default: 86400 (24 hours)."
        ],
        activity_update_threshold: [
          type: :pos_integer,
          default: 300,
          doc: "Minimum seconds between last_active_at DB writes. Default: 300 (5 minutes)."
        ],
        sudo_timeout: [
          type: :pos_integer,
          default: 300,
          doc: "Sudo mode window in seconds. Default: 300 (5 minutes)."
        ],
        session_schema: [
          type: :atom,
          doc: "The generated UserSession Ecto schema module."
        ]
      ]
    ],
    token_ttl: [
      type: :keyword_list,
      default: [],
      doc: "Token time-to-live values in seconds.",
      keys: [
        confirm: [
          type: :pos_integer,
          default: 48 * 60 * 60,
          doc: "Email confirmation token TTL. Default: 48 hours."
        ],
        reset_password: [
          type: :pos_integer,
          default: 60 * 60,
          doc: "Password reset token TTL. Default: 1 hour."
        ],
        magic_link: [
          type: :pos_integer,
          default: 15 * 60,
          doc: "Magic link token TTL. Default: 15 minutes."
        ],
        email_change: [
          type: :pos_integer,
          default: 24 * 60 * 60,
          doc: "Email change token TTL in seconds. Default: 24 hours."
        ]
      ]
    ],
    rate_limiting: [
      type: :keyword_list,
      default: [],
      doc: "Rate limiting options.",
      keys: [
        limiter: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc:
            "Module implementing the `Sigra.RateLimiter` behaviour. Nil disables rate limiting."
        ],
        ip_limit: [
          type: :pos_integer,
          default: 10,
          doc: "Maximum requests per IP within the window. Default: 10."
        ],
        ip_window_ms: [
          type: :pos_integer,
          default: 60_000,
          doc: "IP rate limiting window in milliseconds. Default: 60 seconds."
        ],
        account_limit: [
          type: :pos_integer,
          default: 5,
          doc: "Maximum failed attempts per account before lockout. Default: 5."
        ]
      ]
    ],
    confirmation: [
      type: :keyword_list,
      default: [],
      doc: "Email confirmation options.",
      keys: [
        unconfirmed_access: [
          type: {:in, [:allow_with_banner, :block]},
          default: :allow_with_banner,
          doc:
            "Behavior for unconfirmed users. :allow_with_banner shows a reminder, :block prevents login."
        ],
        code_length: [
          type: :pos_integer,
          default: 6,
          doc: "Length of the numeric confirmation code. Default: 6."
        ],
        max_resends: [
          type: :pos_integer,
          default: 3,
          doc: "Maximum confirmation resend requests per window. Default: 3."
        ],
        resend_window_seconds: [
          type: :pos_integer,
          default: 900,
          doc: "Rate limit window for confirmation resend in seconds. Default: 900 (15 minutes)."
        ],
        code_max_attempts: [
          type: :pos_integer,
          default: 5,
          doc: "Maximum code entry attempts per window. Default: 5."
        ],
        code_window_seconds: [
          type: :pos_integer,
          default: 900,
          doc: "Rate limit window for code entry in seconds. Default: 900 (15 minutes)."
        ]
      ]
    ],
    reset: [
      type: :keyword_list,
      default: [],
      doc: "Password reset options.",
      keys: [
        max_requests: [
          type: :pos_integer,
          default: 3,
          doc: "Maximum reset requests per email per window. Default: 3."
        ],
        window_seconds: [
          type: :pos_integer,
          default: 900,
          doc: "Rate limit window for reset requests in seconds. Default: 900 (15 minutes)."
        ]
      ]
    ],
    email: [
      type: :keyword_list,
      default: [],
      doc: "Email delivery options.",
      keys: [
        from_address: [
          type: :string,
          doc: "From address for transactional emails. Default derived from endpoint config."
        ],
        delivery_mode: [
          type: {:in, [:auto, :async, :sync]},
          default: :auto,
          doc: "Email delivery mode. :auto detects Oban presence. Default: :auto."
        ],
        oban_queue: [
          type: :string,
          default: "sigra_mailer",
          doc: "Oban queue name for async email delivery. Default: \"sigra_mailer\"."
        ],
        oban_concurrency: [
          type: :pos_integer,
          default: 10,
          doc: "Maximum concurrent email delivery workers. Default: 10."
        ]
      ]
    ],
    lockout: [
      type: :keyword_list,
      default: [],
      doc: "Account lockout options.",
      keys: [
        threshold: [
          type: :pos_integer,
          default: 5,
          doc: "Failed attempts before lockout. Default: 5."
        ],
        duration: [
          type: :pos_integer,
          default: 900,
          doc: "Lockout duration in seconds. Default: 900 (15 minutes)."
        ],
        notify: [
          type: :boolean,
          default: true,
          doc: "Send lockout notification email. Default: true."
        ]
      ]
    ],
    geo_ip: [
      type: :keyword_list,
      default: [],
      doc: "GeoIP lookup options.",
      keys: [
        module: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "Module implementing Sigra.GeoIP behaviour. Default: nil (disabled)."
        ]
      ]
    ],
    suspicious_login: [
      type: :keyword_list,
      default: [],
      doc: "Suspicious login detection options.",
      keys: [
        enabled: [
          type: :boolean,
          default: true,
          doc: "Enable suspicious login detection. Default: true."
        ],
        notify: [
          type: :boolean,
          default: true,
          doc: "Send suspicious login notification email. Default: true."
        ]
      ]
    ],
    passkeys: [
      type: :keyword_list,
      default: [],
      doc: "Passkey (WebAuthn) options.",
      keys: [
        enabled: [
          type: :boolean,
          default: true,
          doc: "Enable passkey support. Default: true."
        ],
        passkey_primary_enabled: [
          type: :boolean,
          default: false,
          doc:
            "Enable passkey-primary login. Passkey MFA and enrollment are still controlled by :enabled. Default: false."
        ],
        sign_count_policy: [
          type: {:in, [:warn, :require_reauth, :revoke]},
          default: :warn,
          doc: "Sign-count regression policy. Default: :warn to accommodate synced passkeys."
        ],
        max_per_user: [
          type: :pos_integer,
          default: 10,
          doc: "Maximum passkeys per user. Enforced atomically. Default: 10."
        ],
        rp_id: [
          type: {:or, [:string, nil]},
          default: nil,
          doc: "Relying party ID. Default: nil."
        ],
        rp_name: [
          type: :string,
          default: "Sigra",
          doc: "Relying party display name. Default: \"Sigra\"."
        ],
        origin: [
          type: {:or, [:string, nil]},
          default: nil,
          doc: "Relying party origin (https://...). Default: nil."
        ],
        attestation: [
          type: {:in, [:none, :indirect, :direct]},
          default: :none,
          doc: "Attestation conveyance preference. Default: :none."
        ],
        user_verification: [
          type: {:in, [:preferred, :required, :discouraged]},
          default: :preferred,
          doc: "User verification requirement. Default: :preferred."
        ],
        timeout_ms: [
          type: :pos_integer,
          default: 60_000,
          doc: "Passkey ceremony timeout in milliseconds. Default: 60_000."
        ],
        ceremony_rate_limit: [
          type: :keyword_list,
          default: [],
          doc: "Per-user ceremony initiation rate limit. Default: 5 per 60_000ms.",
          keys: [
            limit: [
              type: :pos_integer,
              default: 5,
              doc: "Maximum ceremony initiations per user within the window. Default: 5."
            ],
            window_ms: [
              type: :pos_integer,
              default: 60_000,
              doc: "Ceremony initiation window in milliseconds. Default: 60_000."
            ]
          ]
        ],
        user_passkey_schema: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "Generated host UserPasskey schema module. Default: nil."
        ]
      ]
    ],
    oauth: [
      type: :keyword_list,
      default: [],
      doc: "OAuth / social login options.",
      keys: [
        enabled: [
          type: :boolean,
          default: true,
          doc:
            "Master switch for OAuth. When false, OAuth routes are disabled and buttons hidden (D-63)."
        ],
        providers: [
          type: :keyword_list,
          default: [],
          doc:
            "Provider configurations. Each key is a provider atom, value is a keyword list with :client_id, :client_secret, :redirect_uri, and optional :strategy, :scopes."
        ],
        session_type: [
          type: {:in, [:standard, :remember_me]},
          default: :remember_me,
          doc: "Session type for OAuth logins. Default: :remember_me (D-43)."
        ],
        link_confirmation: [
          type: {:in, [:required, :auto]},
          default: :required,
          doc:
            "Account linking behavior when OAuth email matches existing account. Default: :required (D-01)."
        ],
        trust_provider_email: [
          type: :boolean,
          default: true,
          doc:
            "Whether to auto-confirm email based on provider verification. Set false for Facebook (D-42)."
        ]
      ]
    ],
    api_token: [
      type: :keyword_list,
      default: [],
      doc: "API token options.",
      keys: [
        prefix: [
          type: {:or, [:string, nil]},
          default: nil,
          doc:
            "Token prefix. Nil derives from otp_app: {otp_app}_sk_. Must match ^[a-z0-9_]+$ and not start with eyJ."
        ],
        custom_scopes: [
          type: {:list, :string},
          default: [],
          doc: "Custom scope strings in resource:action format."
        ],
        write_implies_read: [
          type: :boolean,
          default: false,
          doc: "Whether write scope implies read. Default: false."
        ],
        require_expiry: [
          type: :boolean,
          default: false,
          doc: "Whether expiration is required. Default: false."
        ],
        max_ttl: [
          type: {:or, [:pos_integer, nil]},
          default: nil,
          doc: "Maximum TTL in seconds. Nil = no limit."
        ],
        cleanup_retention: [
          type: :pos_integer,
          default: 90 * 24 * 60 * 60,
          doc: "Retention period for revoked/expired tokens in seconds. Default: 90 days."
        ],
        activity_update_threshold: [
          type: :pos_integer,
          default: 300,
          doc: "Minimum seconds between last_used_at writes. Default: 300."
        ],
        default_page_size: [
          type: :pos_integer,
          default: 50,
          doc: "Default page size for token listing. Default: 50."
        ],
        max_page_size: [
          type: :pos_integer,
          default: 200,
          doc: "Maximum page size. Default: 200."
        ],
        api_token_schema: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "The generated UserAPIToken schema module."
        ]
      ]
    ],
    jwt: [
      type: :keyword_list,
      default: [],
      doc: "JWT options (requires Joken ~> 2.6 as optional dependency).",
      keys: [
        enabled: [
          type: :boolean,
          default: false,
          doc: "Enable JWT support. Default: false."
        ],
        algorithm: [
          type: {:in, ["HS256", "RS256", "ES256"]},
          default: "HS256",
          doc: "Signing algorithm. Default: HS256."
        ],
        issuer: [
          type: {:or, [:string, nil]},
          default: nil,
          doc: "JWT issuer claim. Nil = otp_app name."
        ],
        access_ttl: [
          type: :pos_integer,
          default: 900,
          doc: "Access token TTL in seconds. Default: 900 (15 min)."
        ],
        refresh_ttl: [
          type: :pos_integer,
          default: 30 * 24 * 60 * 60,
          doc: "Refresh token TTL in seconds. Default: 30 days."
        ],
        refresh: [
          type: :boolean,
          default: true,
          doc: "Enable refresh tokens. Default: true."
        ],
        claims_builder: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "Module implementing Sigra.JWT.ClaimsBuilder behaviour."
        ],
        verify_epoch: [
          type: :boolean,
          default: true,
          doc: "Verify user token_epoch on every JWT request. Default: true."
        ],
        private_key: [
          type: {:or, [:string, nil]},
          default: nil,
          doc: "PEM private key for RS256/ES256."
        ]
      ]
    ],
    deletion: [
      type: :keyword_list,
      default: [],
      doc: "Account deletion options.",
      keys: [
        strategy: [
          type: {:in, [:soft_delete, :hard_delete, :anonymize]},
          default: :soft_delete,
          doc:
            "Deletion strategy. :soft_delete preserves row with deleted_at, :hard_delete removes row, :anonymize strips PII. Default: :soft_delete."
        ],
        grace_period_days: [
          type: {:or, [:non_neg_integer, nil]},
          default: 14,
          doc: "Days before scheduled deletion executes. 0 or nil for immediate. Default: 14."
        ],
        cooldown_hours: [
          type: :pos_integer,
          default: 24,
          doc: "Hours after cancelling deletion before re-requesting is allowed. Default: 24."
        ],
        notify: [
          type: :boolean,
          default: true,
          doc: "Send email notifications for deletion events. Default: true."
        ]
      ]
    ],
    hooks: [
      type: :keyword_list,
      default: [],
      doc: "Lifecycle hook callbacks. Each is a {module, function} tuple or nil.",
      keys: [
        on_register: [
          type: {:or, [{:tuple, [:atom, :atom]}, nil]},
          default: nil,
          doc: "Called after user registration. Receives (multi, context_map). Default: nil."
        ],
        on_email_change: [
          type: {:or, [{:tuple, [:atom, :atom]}, nil]},
          default: nil,
          doc:
            "Called after email change confirmation. Receives (multi, context_map). Default: nil."
        ],
        on_password_change: [
          type: {:or, [{:tuple, [:atom, :atom]}, nil]},
          default: nil,
          doc: "Called after password change. Receives (multi, context_map). Default: nil."
        ],
        on_delete: [
          type: {:or, [{:tuple, [:atom, :atom]}, nil]},
          default: nil,
          doc: "Called when deletion is scheduled. Receives (multi, context_map). Default: nil."
        ]
      ]
    ],
    audit: [
      type: :keyword_list,
      default: [],
      doc: "Structured audit logging options (Phase 9). See `Sigra.Audit`.",
      keys: [
        audit_schema: [
          type: {:or, [:atom, nil]},
          default: nil,
          doc: "The generated AuditEvent schema module. Default: nil."
        ],
        retention_days: [
          type: {:or, [:pos_integer, nil]},
          default: nil,
          doc: "Days to retain audit events. nil = keep forever (D-09). Default: nil."
        ],
        max_metadata_bytes: [
          type: :pos_integer,
          default: 8_192,
          doc: "Cap on JSON-encoded metadata byte size (D-20). Default: 8192."
        ],
        reserved_prefixes: [
          type: {:list, :string},
          default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.),
          doc:
            "Reserved action prefixes developers cannot use (D-17, D-18). Default: ~w(auth. session. mfa. oauth. api. account. sigra. passkey.)."
        ],
        forwarders: [
          type: {:custom, Sigra.Config, :validate_forwarders, []},
          default: [],
          doc:
            "Audit forwarders (Phase 131, v1.29 SUITE-INTEGRATION). Each entry is a keyword list " <>
              "with :module (required, atom), :dispatch (:auto | :async | :sync, default :auto), " <>
              ":id (atom, default :default), and arbitrary impl-specific keys (e.g. Threadline " <>
              "carries :endpoint and :api_key — these are validated inside each impl's attach/1). " <>
              "Per-forwarder :dispatch knob mirrors email[:delivery_mode] (D-07). Default: []."
        ]
      ]
    ]
  ]

  @type t :: %__MODULE__{
          repo: module(),
          user_schema: module(),
          otp_app: atom() | nil,
          secret_key_base: String.t() | nil,
          scope_module: module() | nil,
          organizations_module: module() | nil,
          mailer: module() | nil,
          email_module: module() | nil,
          cookie_domain: String.t() | nil,
          password: keyword(),
          password_policy: keyword(),
          magic_link: keyword(),
          require_confirmation: boolean(),
          session_ttl: pos_integer(),
          session: keyword(),
          token_ttl: keyword(),
          rate_limiting: keyword(),
          confirmation: keyword(),
          reset: keyword(),
          email: keyword(),
          lockout: keyword(),
          geo_ip: keyword(),
          suspicious_login: keyword(),
          mfa: keyword(),
          passkeys: keyword(),
          oauth: keyword(),
          api_token: keyword(),
          jwt: keyword(),
          deletion: keyword(),
          hooks: keyword(),
          audit: keyword()
        }

  defstruct [
    :repo,
    :user_schema,
    :otp_app,
    :secret_key_base,
    :scope_module,
    :organizations_module,
    :mailer,
    :email_module,
    cookie_domain: nil,
    password: [],
    password_policy: [],
    magic_link: [],
    require_confirmation: false,
    session_ttl: 5_184_000,
    session: [],
    token_ttl: [],
    rate_limiting: [],
    confirmation: [],
    reset: [],
    email: [],
    lockout: [],
    geo_ip: [],
    suspicious_login: [],
    mfa: [],
    passkeys: [],
    oauth: [],
    api_token: [],
    jwt: [],
    deletion: [],
    hooks: [],
    audit: []
  ]

  @doc """
  Creates a new `%Sigra.Config{}` struct from the given options.

  Validates all options via `NimbleOptions` and raises
  `NimbleOptions.ValidationError` for invalid or missing required options.
  Only `:repo` and `:user_schema` are required; all other options have
  secure defaults.

  ## Examples

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User)
      iex> config.repo
      Fake.Repo

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User)
      iex> config.cookie_domain
      nil

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User, cookie_domain: ".example.com")
      iex> config.cookie_domain
      ".example.com"

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User, cookie_domain: nil)
      iex> config.cookie_domain
      nil

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User, require_confirmation: true)
      iex> config.require_confirmation
      true

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User, session_ttl: 86_400)
      iex> config.session_ttl
      86_400

  """
  @doc since: "0.1.0"
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    struct!(__MODULE__, validated)
  end

  @doc false
  # NimbleOptions custom validator for the audit[:forwarders] list (D-06, Phase 131).
  # Called by NimbleOptions at config validation time via {:custom, Sigra.Config, :validate_forwarders, []}.
  #
  # Validates the canonical keys (:module required, :dispatch enum, :id atom) while
  # allowing arbitrary impl-specific keys to pass through unvalidated (D-08).
  # This matches the oauth[:providers] precedent at lib/sigra/config.ex:40 where
  # impl-specific keys (provider credentials, etc.) are validated inside each impl.
  #
  # Returns {:ok, list} on success; {:error, message} on first invalid entry.
  # NimbleOptions wraps the message in NimbleOptions.ValidationError automatically.
  @spec validate_forwarders(list()) :: {:ok, list()} | {:error, String.t()}
  def validate_forwarders(list) when is_list(list) do
    # Accumulates a normalized list (with :dispatch and :id defaults injected) rather
    # than returning the original input. Downstream consumers that call
    # Keyword.fetch!(entry, :dispatch) (rather than Keyword.get with a default) will
    # work correctly after validation. WR-07: returning raw input was a maintenance
    # landmine — any new consumer that assumed "validation already normalized this"
    # would silently break on missing default keys.
    result =
      Enum.reduce_while(list, {:ok, []}, fn entry, {:ok, acc} ->
        cond do
          not is_list(entry) ->
            {:halt,
             {:error,
              "forwarder entry must be a keyword list, got unexpected type"}}

          not Keyword.has_key?(entry, :module) ->
            {:halt,
             {:error,
              "required :module option not found in forwarder entry, received options: #{inspect(Keyword.keys(entry))}"}}

          not is_atom(Keyword.get(entry, :module)) ->
            {:halt, {:error, ":module must be an atom"}}

          (dispatch = Keyword.get(entry, :dispatch, :auto)) not in [:auto, :async, :sync] ->
            {:halt,
             {:error,
              "invalid :dispatch value #{inspect(dispatch)} in forwarder entry, expected one of: :auto, :async, :sync"}}

          not is_atom(Keyword.get(entry, :id, :default)) ->
            {:halt, {:error, ":id must be an atom in forwarder entry"}}

          true ->
            normalized =
              entry
              |> Keyword.put_new(:dispatch, :auto)
              |> Keyword.put_new(:id, :default)

            {:cont, {:ok, acc ++ [normalized]}}
        end
      end)

    result
  end

  def validate_forwarders(_other) do
    {:error, "forwarders must be a list"}
  end

  @doc """
  Returns whether OAuth is enabled AND has at least one configured provider.

  Returns `true` only when `oauth[:enabled]` is not explicitly `false`
  AND `oauth[:providers]` contains at least one entry. This prevents
  callers from rendering an empty "Sign in with..." row on the default
  config (which has no providers configured).

  ## Examples

      iex> config = Sigra.Config.new!(
      ...>   repo: Fake.Repo,
      ...>   user_schema: Fake.User,
      ...>   oauth: [enabled: true, providers: [google: [client_id: "x"]]]
      ...> )
      iex> Sigra.Config.oauth_enabled?(config)
      true

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User)
      iex> Sigra.Config.oauth_enabled?(config)
      false

      iex> config = Sigra.Config.new!(
      ...>   repo: Fake.Repo,
      ...>   user_schema: Fake.User,
      ...>   oauth: [enabled: false, providers: [google: [client_id: "x"]]]
      ...> )
      iex> Sigra.Config.oauth_enabled?(config)
      false

  """
  @doc since: "0.1.0"
  @spec oauth_enabled?(t()) :: boolean()
  def oauth_enabled?(%__MODULE__{oauth: oauth}) do
    Keyword.get(oauth, :enabled, true) and Keyword.get(oauth, :providers, []) != []
  end

  @doc """
  Returns the list of configured OAuth providers from the given config.

  ## Examples

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User, oauth: [providers: [google: [client_id: "x"]]])
      iex> Sigra.Config.oauth_providers(config)
      [google: [client_id: "x"]]

      iex> config = Sigra.Config.new!(repo: Fake.Repo, user_schema: Fake.User)
      iex> Sigra.Config.oauth_providers(config)
      []

  """
  @doc since: "0.1.0"
  @spec oauth_providers(t()) :: keyword()
  def oauth_providers(%__MODULE__{oauth: oauth}) do
    Keyword.get(oauth, :providers, [])
  end
end
