defmodule Sigra.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/sztheory/sigra"

  def project do
    [
      app: :sigra,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Sigra",
      description: "Comprehensive authentication library for Phoenix 1.8+",
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

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
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
      {:eqrcode, "~> 0.2.1", optional: true},
      # Dev/test
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Sigra",
      source_ref: "v#{@version}",
      formatters: ["html"],
      extras: ["CHANGELOG.md"]
    ]
  end
end
