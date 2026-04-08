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

  #{NimbleOptions.docs([
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
    mailer: [
      type: :atom,
      doc: "The mailer module implementing `Sigra.Mailer` behaviour."
    ],
    email_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc: "The generated email template module implementing `Sigra.EmailTemplates` behaviour."
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
          doc: "Behavior for unconfirmed users. :allow_with_banner shows a reminder, :block prevents login."
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
    oauth: [
      type: :keyword_list,
      default: [],
      doc: "OAuth / social login options.",
      keys: [
        enabled: [
          type: :boolean,
          default: true,
          doc: "Master switch for OAuth. When false, OAuth routes are disabled and buttons hidden (D-63)."
        ],
        providers: [
          type: :keyword_list,
          default: [],
          doc: "Provider configurations. Each key is a provider atom, value is a keyword list with :client_id, :client_secret, :redirect_uri, and optional :strategy, :scopes."
        ],
        session_type: [
          type: {:in, [:standard, :remember_me]},
          default: :remember_me,
          doc: "Session type for OAuth logins. Default: :remember_me (D-43)."
        ],
        link_confirmation: [
          type: {:in, [:required, :auto]},
          default: :required,
          doc: "Account linking behavior when OAuth email matches existing account. Default: :required (D-01)."
        ],
        trust_provider_email: [
          type: :boolean,
          default: true,
          doc: "Whether to auto-confirm email based on provider verification. Set false for Facebook (D-42)."
        ]
      ]
    ]
  ])}
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
    mailer: [
      type: :atom,
      doc: "The mailer module implementing `Sigra.Mailer` behaviour."
    ],
    email_module: [
      type: {:or, [:atom, nil]},
      default: nil,
      doc: "The generated email template module implementing `Sigra.EmailTemplates` behaviour."
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
          doc:
            "Rate limit window for confirmation resend in seconds. Default: 900 (15 minutes)."
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
    ]
  ]

  @type t :: %__MODULE__{
          repo: module(),
          user_schema: module(),
          otp_app: atom() | nil,
          mailer: module() | nil,
          email_module: module() | nil,
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
          oauth: keyword(),
          mfa: keyword()
        }

  defstruct [
    :repo,
    :user_schema,
    :otp_app,
    :mailer,
    :email_module,
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
    oauth: [],
    mfa: []
  ]

  @doc """
  Creates a new `%Sigra.Config{}` struct from the given options.

  Validates all options via `NimbleOptions` and raises
  `NimbleOptions.ValidationError` for invalid or missing required options.

  ## Examples

      iex> Sigra.Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)
      %Sigra.Config{repo: MyApp.Repo, user_schema: MyApp.User, ...}

      iex> Sigra.Config.new!([])
      ** (NimbleOptions.ValidationError) ...

  """
  @doc since: "0.1.0"
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    validated = NimbleOptions.validate!(opts, @schema)
    struct!(__MODULE__, validated)
  end

  @doc """
  Returns whether OAuth is enabled in the given config.

  ## Examples

      iex> config = Sigra.Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, oauth: [enabled: true])
      iex> Sigra.Config.oauth_enabled?(config)
      true

  """
  @doc since: "0.1.0"
  @spec oauth_enabled?(t()) :: boolean()
  def oauth_enabled?(%__MODULE__{oauth: oauth}) do
    Keyword.get(oauth, :enabled, true)
  end

  @doc """
  Returns the list of configured OAuth providers from the given config.

  ## Examples

      iex> config = Sigra.Config.new!(repo: MyApp.Repo, user_schema: MyApp.User, oauth: [providers: [google: [client_id: "x"]]])
      iex> Sigra.Config.oauth_providers(config)
      [google: [client_id: "x"]]

  """
  @doc since: "0.1.0"
  @spec oauth_providers(t()) :: keyword()
  def oauth_providers(%__MODULE__{oauth: oauth}) do
    Keyword.get(oauth, :providers, [])
  end
end
