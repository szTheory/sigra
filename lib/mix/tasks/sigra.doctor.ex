defmodule Mix.Tasks.Sigra.Doctor do
  @shortdoc "Validates Sigra optional dependencies for the current host"
  @moduledoc """
  Reports Sigra's optional dependency contract for the current host and exits
  non-zero only when an enabled enforced feature is missing its dependency.
  """

  use Mix.Task

  alias Sigra.OptionalDeps

  @switches [
    jwt_enabled: :boolean,
    oauth_enabled: :boolean,
    delivery_mode: :string,
    rate_limit: :string,
    mailer: :string,
    missing: :keep
  ]

  @features [:async_email, :bcrypt_migration, :totp_qr, :jwt, :rate_limit, :oauth, :swoosh]

  @impl Mix.Task
  def run(argv) do
    {opts, _args, invalid} = OptionParser.parse(argv, strict: @switches)

    if invalid != [] do
      Mix.raise("sigra.doctor received unsupported arguments: #{Enum.map_join(invalid, ", ", &elem(&1, 0))}")
    end

    context = context_from_opts(opts)
    rows = Enum.map(@features, &OptionalDeps.doctor_row(&1, context))
    blocking_rows = Enum.filter(rows, & &1.blocking?)

    Mix.shell().info("==> sigra.doctor: #{length(rows)} optional dependency row(s)")
    Enum.each(rows, &print_row/1)

    if blocking_rows == [] do
      Mix.shell().info("OK: all enforced optional dependency rows are currently valid.")
    else
      Mix.shell().error(
        "FAIL: #{length(blocking_rows)} enforced optional dependency row(s) are currently invalid."
      )

      halt!(2)
    end
  end

  defp print_row(row) do
    level = row_level(row)
    tier = if row.enforced?, do: "enforced", else: "advisory"
    line = "#{level} #{tier} #{row.feature} -> #{row.dependency} because #{row.evidence}"

    if row.blocking? do
      Mix.shell().error(line)
      Mix.shell().error("  Remediation: #{row.remediation}")
    else
      Mix.shell().info(line)

      if row.loaded? == false do
        Mix.shell().info("  Remediation: #{row.remediation}")
      end
    end
  end

  defp row_level(%{blocking?: true}), do: "FAIL"
  defp row_level(%{loaded?: true}), do: "OK"
  defp row_level(%{enabled?: true}), do: "INFO"
  defp row_level(_row), do: "INFO"

  defp context_from_opts(opts) do
    missing =
      opts
      |> Keyword.get_values(:missing)
      |> Enum.map(&normalize_dependency/1)
      |> MapSet.new()

    [
      config: host_config(opts),
      jwt: [enabled: Keyword.get(opts, :jwt_enabled, false)],
      oauth_enabled?: Keyword.get(opts, :oauth_enabled, false),
      delivery_mode: parse_delivery_mode(Keyword.get(opts, :delivery_mode)),
      rate_limiter: parse_rate_limiter(Keyword.get(opts, :rate_limit)),
      mailer_backend: parse_mailer(Keyword.get(opts, :mailer)),
      dependency_loaded?: fn spec -> not MapSet.member?(missing, spec.dependency) end
    ]
  end

  defp host_config(opts) do
    Sigra.Config.new!(
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      secret_key_base: String.duplicate("a", 64),
      jwt: [enabled: Keyword.get(opts, :jwt_enabled, false), algorithm: "HS256"],
      mfa: [enabled: true]
    )
  end

  defp normalize_dependency(value) when is_atom(value), do: value

  defp normalize_dependency(value) when is_binary(value) do
    value
    |> String.trim_leading(":")
    |> String.to_existing_atom()
  rescue
    ArgumentError -> String.to_atom(value)
  end

  defp parse_delivery_mode(nil), do: host_delivery_mode()
  defp parse_delivery_mode("async"), do: :async
  defp parse_delivery_mode("sync"), do: :sync
  defp parse_delivery_mode("auto"), do: :auto
  defp parse_delivery_mode(_other), do: host_delivery_mode()

  defp parse_rate_limiter("hammer"), do: Sigra.RateLimiters.Hammer
  defp parse_rate_limiter(_other), do: nil

  defp parse_mailer("swoosh"), do: :swoosh
  defp parse_mailer(_other), do: nil

  defp host_delivery_mode do
    case Application.get_env(:sigra, :email, []) do
      opts when is_list(opts) -> Keyword.get(opts, :delivery_mode)
      _ -> nil
    end
  end

  defp halt!(status) do
    case Application.get_env(:sigra, :doctor_halt) do
      nil -> default_halt(status)
      halt_fun -> halt_fun.(status)
    end
  end

  defp default_halt(2), do: System.halt(2)
  defp default_halt(status), do: System.halt(status)
end
