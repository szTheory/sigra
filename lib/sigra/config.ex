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
    password: [
      type: :keyword_list,
      default: [],
      doc: "Password hashing and validation options.",
      keys: [
        min_length: [
          type: :pos_integer,
          default: 12,
          doc: "Minimum password length. OWASP recommends at least 8; Sigra defaults to 12."
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
    session: [
      type: :keyword_list,
      default: [],
      doc: "Session management options.",
      keys: [
        remember_me_max_age: [
          type: :pos_integer,
          default: 14 * 24 * 60 * 60,
          doc: "Max age for remember-me cookies in seconds. Default: 14 days (1,209,600s)."
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
    password: [
      type: :keyword_list,
      default: [],
      doc: "Password hashing and validation options.",
      keys: [
        min_length: [
          type: :pos_integer,
          default: 12,
          doc: "Minimum password length. OWASP recommends at least 8; Sigra defaults to 12."
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
    session: [
      type: :keyword_list,
      default: [],
      doc: "Session management options.",
      keys: [
        remember_me_max_age: [
          type: :pos_integer,
          default: 14 * 24 * 60 * 60,
          doc: "Max age for remember-me cookies in seconds. Default: 14 days (1,209,600s)."
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
    ]
  ]

  @type t :: %__MODULE__{
          repo: module(),
          user_schema: module(),
          otp_app: atom() | nil,
          mailer: module() | nil,
          password: keyword(),
          session: keyword(),
          token_ttl: keyword(),
          rate_limiting: keyword()
        }

  defstruct [
    :repo,
    :user_schema,
    :otp_app,
    :mailer,
    password: [],
    session: [],
    token_ttl: [],
    rate_limiting: []
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
end
