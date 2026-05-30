defmodule Sigra.MixProject do
  use Mix.Project

  @version "0.3.0"
  @source_url "https://github.com/sztheory/sigra"

  def project do
    [
      app: :sigra,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      # test_load_filters: tells `mix test` which files to load via require.
      # We use a negative lookahead to keep root `mix test` out of:
      #   - test/example/ — the example app subproject (plan 10-06), its own Mix project
      #   - test/fixtures/ — golden-diff snapshot trees (plan 11-01) that reference
      #     ephemeral project modules like SigraInstallGoldenTmpWeb which don't exist
      #     in the library compile env. Mix 1.19 auto-discovers .ex/.exs files under
      #     test/ for compilation unless filtered out.
      #
      # Matches:   test/sigra/auth_test.exs, test/support/data_case.ex
      # Excludes:  test/example/**, test/fixtures/install_golden/**
      test_load_filters: [~r"^test/(?!example/|fixtures/)"],
      # Mix 1.19 warns on every `*.{ex,exs}` under `test/` that is neither
      # loaded nor explicitly ignored. The example subproject and fixture trees
      # contain compiled copies under `test/example/_build/` etc.; ignore the
      # whole subtrees so `mix test` at the library root stays warning-clean.
      test_ignore_filters: [
        &String.starts_with?(&1, "test/example/"),
        &String.starts_with?(&1, "test/fixtures/")
      ],
      name: "Sigra",
      description:
        "Authentication for Phoenix 1.8+ and Ecto. Mix generators emit host-owned auth " <>
          "(sessions, Argon2id, TOTP, passkeys, encryption, audit). OAuth, mailers, Oban, and more " <>
          "are optional host deps. See https://hexdocs.pm/sigra and the README for details.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Sigra.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Silence undefined-function warnings for optional deps and for internal
  # modules that are conditionally compiled behind optional-dep guards. When
  # Sigra is pulled in by a consumer that doesn't add these deps to its own
  # mix.exs, the compiler would otherwise warn on every reference and break
  # `mix compile --warnings-as-errors` downstream.
  defp elixirc_options do
    [
      no_warn_undefined: [
        # Optional deps (mix.exs: optional: true)
        Bcrypt,
        Hammer,
        Swoosh.Email,
        Threadline,
        Threadline.ActorRef,
        Threadline.AuditChange,
        Threadline.AuditTransaction,
        Oban,
        Oban.Worker,
        Oban.Job,
        Assent.Strategy.Apple,
        Assent.Strategy.Facebook,
        Assent.Strategy.Github,
        Assent.Strategy.Google,
        Joken,
        Joken.Signer,
        Joken.Config,
        EQRCode,
        Chimeway,
        Chimeway.Notifier,
        # Internal modules defined only when an optional dep is loaded
        Sigra.Integrations.Chimeway,
        Sigra.Workers.AccountDeletion,
        Sigra.Workers.AuditCleanup,
        Sigra.Workers.AuditForward,
        Sigra.Workers.EmailDelivery,
        Sigra.Workers.TokenCleanup
      ]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:flop, "~> 0.26.3"},
      {:flop_phoenix, "~> 0.26.0"},
      {:nimble_options, "~> 1.1"},
      {:argon2_elixir, "~> 4.1"},
      {:comeonin, "~> 5.3"},
      # Optional deps
      {:bcrypt_elixir, "~> 3.3", optional: true},
      {:hammer, "~> 7.3", optional: true},
      {:swoosh, "~> 1.5", optional: true},
      {:oban, "~> 2.17", optional: true},
      {:assent, "~> 0.3", optional: true},
      {:joken, "~> 2.6", optional: true},
      {:nimble_totp, "~> 1.0"},
      {:cloak_ecto, "~> 1.3"},
      {:wax_, "~> 0.7"},
      {:threadline, "~> 0.5", optional: true},
      # Optional Chimeway bridge — host adds `{:chimeway, "~> 1.0"}`; local dev may use CHIMEWAY_PATH path dep.
      {:chimeway, "~> 1.0", optional: true},
      {:eqrcode, "~> 0.2.1", optional: true},
      # Dev/test
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      # Postgres driver. Required at runtime when threadline (optional) is used;
      # also used by opt-in `:postgres` tagged tests (e.g. `test/sigra/audit/query_index_test.exs`)
      # that assert Query plans against a live Postgres repo. Excluded from default test runs
      # via `ExUnit.start(exclude: [:postgres])` in test/test_helper.exs.
      {:postgrex, "~> 0.17"}
    ]
  end

  # ci: audit_45 — single scoped `mix test …` bundle (matches 45-06-SUMMARY; no bare root `mix test`).
  defp aliases do
    [
      "ci.audit_45": [
        "test test/sigra/oauth/ test/sigra/workers/account_deletion_test.exs test/sigra/account/deletion_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs test/sigra/impersonation_test.exs test/sigra/suspicious_login_test.exs test/sigra/lockout_test.exs test/sigra/mfa_audit_atomicity_test.exs test/sigra/api_token_audit_atomic_test.exs"
      ],
      "ci.install_golden": [
        "test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Documentation" => "https://hexdocs.pm/sigra",
        "GitHub" => @source_url
      },
      files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      # ExDoc only autolinks extras by basename; maintainer paths under `.planning/`
      # are intentionally relative from this guide for repo navigation.
      skip_undefined_reference_warnings_on: [
        "guides/introduction/upgrading-to-v1.10.md",
        "guides/introduction/upgrading-to-v1.11.md",
        # Phase 131: hidden Application helpers referenced in moduledocs; suppressed pending
        # a @doc false / @moduledoc false strategy alignment in a future phase.
        "lib/sigra/audit/forwarder.ex",
        "lib/sigra/audit/forwarders.ex",
        "lib/sigra/audit/forwarders/noop.ex",
        "lib/sigra/audit/forwarders/threadline.ex",
        "lib/sigra/workers/audit_forward.ex",
        # Phase 132: recipe files reference hidden Application helpers and the Sigra.Mailer
        # behaviour callback (which is a @callback, not a @doc function).
        "guides/recipes/companion-libs/threadline.md",
        "guides/recipes/companion-libs/mailglass.md"
      ],
      main: "getting-started",
      # Hex/ExDoc: before mix hex.publish, ensure git tag v#{@version} exists or "View source" on hexdocs returns 404.
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html", "markdown"],
      assets: %{"guides/assets" => "assets"},
      extras: [
        "README.md",
        "CONTRIBUTING.md",
        "SECURITY.md",
        "MAINTAINING.md",
        "LICENSE",
        "CHANGELOG.md",
        "guides/introduction/installation.md",
        "guides/introduction/getting-started.md",
        "guides/introduction/first-hour.md",
        "guides/introduction/intermediate-production-path.md",
        "guides/reference/generator-options.md",
        "guides/introduction/troubleshooting-install.md",
        "guides/introduction/upgrading-to-v1.7.md",
        "guides/introduction/upgrading-to-v1.8.md",
        "guides/introduction/upgrading-to-v1.10.md",
        "guides/introduction/upgrading-to-v1.11.md",
        "guides/introduction/upgrading-to-v1.12.md",
        "guides/introduction/upgrading-to-v1.1.md",
        "guides/introduction/suite-integration.md",
        "guides/introduction/demo-showcase.md",
        "guides/flows/registration.md",
        "guides/flows/login-and-logout.md",
        "guides/flows/password-reset.md",
        "guides/flows/mfa.md",
        "guides/flows/oauth.md",
        "guides/flows/api-authentication.md",
        "guides/flows/account-lifecycle.md",
        "guides/flows/audit-logging.md",
        "docs/audit-semantics.md",
        "docs/uat-ci-coverage.md",
        "docs/ga-evidence.md",
        "docs/nyquist-posture-matrix.md",
        "docs/NEXT-STEPS-MANUAL.md",
        "guides/recipes/testing.md",
        "guides/recipes/subdomain-auth.md",
        "guides/recipes/custom-user-fields.md",
        "guides/recipes/multi-tenant.md",
        "guides/recipes/passkeys.md",
        "guides/recipes/deployment.md",
        "guides/recipes/companion-oauth-provider.md",
        "guides/recipes/companion-libs/threadline.md",
        "guides/recipes/companion-libs/mailglass.md",
        "guides/recipes/companion-libs/accrue.md",
        "guides/recipes/companion-libs/lockspire.md",
        "guides/recipes/companion-libs/relyra.md",
        "guides/recipes/companion-libs/rulestead.md"
      ],
      groups_for_extras: [
        Introduction: ~r{guides/introduction/.?},
        Reference: ~r{guides/reference/.?},
        Flows: ~r{guides/flows/.?},
        "Companion Libraries": ~r{guides/recipes/companion-libs/.?},
        Recipes: ~r{guides/recipes/[^/]+\.md$},
        Docs: ~r{^docs/|^SECURITY\.md$}
      ],
      groups_for_modules: [
        Core: [Sigra, Sigra.Auth, Sigra.Config, Sigra.Crypto],
        Plugs: ~r{Sigra.Plug.*},
        MFA: ~r{Sigra.MFA.*},
        Audit: ~r{Sigra.Audit.*},
        Testing: [Sigra.Testing]
      ]
    ]
  end
end
