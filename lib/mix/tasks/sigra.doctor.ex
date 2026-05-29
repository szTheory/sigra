defmodule Mix.Tasks.Sigra.Doctor do
  @shortdoc "Diagnoses optional-dependency wiring and prints a per-feature status matrix"

  @moduledoc """
  Diagnoses Sigra's optional-dependency wiring and prints a per-feature status
  matrix showing which optional features are missing, available (loaded but
  unconfigured), loaded and active, or configured-but-broken.

  ## Usage

      mix sigra.doctor [--quiet]

  ## Flags

    * `--quiet` — suppress per-row hints. The verdict line and the misconfig
      error report are **always** printed regardless of `--quiet`. The exit
      gate fires on misconfiguration regardless of this flag.

  ## Examples

      # Standard run:
      mix sigra.doctor

      # Suppress per-row hints (useful when the matrix itself is enough):
      mix sigra.doctor --quiet

      # CI usage — non-zero exit on misconfiguration, zero on clean:
      mix sigra.doctor && echo "wiring OK" || echo "misconfigured — see above"

  ## Behavior

  Delegates to `Sigra.Doctor.run/1` after parsing flags and starting the
  application. All diagnostic logic (matrix build, wiring checks, verdict)
  lives in the versioned library so fixes ship via `mix deps.update`.

  On a clean install (no configured features, no optional deps loaded), the
  command exits 0 — making it safe to run unconditionally in dep-off CI lanes.

  On detected misconfiguration (a configured feature has broken wiring), the
  command prints the full matrix and error report, then exits with code 1 —
  functioning as a CI / pre-deploy gate.

  ## Exit Codes

    * 0 — all configured features are properly wired (or no features are
      configured). Absent optional deps are not an error.
    * 1 — at least one configured feature has broken wiring (e.g. async email
      enabled but Oban not supervised).
  """

  use Mix.Task

  @options_schema [
    quiet: [
      type: :boolean,
      default: false,
      doc:
        "Suppress per-row hints; print only the summary verdict. " <>
          "Does not suppress the error report on misconfiguration."
    ]
  ]

  @switches [quiet: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _parsed, invalid} = OptionParser.parse(args, strict: @switches)

    unless invalid == [] do
      flags = Enum.map_join(invalid, ", ", fn {flag, _val} -> flag end)
      Mix.raise("Unknown flag(s): #{flags}. Run `mix help sigra.doctor` for usage.")
    end

    validated = NimbleOptions.validate!(opts, @options_schema)

    Mix.Task.run("app.start")

    result = Sigra.Doctor.run(validated)
    format_and_exit(result, validated)
  end

  @doc false
  # run_with_opts/1 is a test seam that bypasses arg parsing and app.start,
  # accepting pre-validated opts (including injection keys for Sigra.Doctor).
  # This allows CaptureIO tests to exercise formatting and exit logic without
  # spawning subprocesses or toggling the ambient dep tree.
  def run_with_opts(opts) when is_list(opts) do
    result = Sigra.Doctor.run(opts)
    format_and_exit(result, opts)
  end

  # ---------------------------------------------------------------------------
  # Output formatting
  # ---------------------------------------------------------------------------

  defp format_and_exit(result, opts) do
    quiet = Keyword.get(opts, :quiet, false)

    Mix.shell().info([:bright, "==> sigra.doctor", :reset])
    Mix.shell().info("")

    Enum.each(result.rows, fn row ->
      print_row(row, quiet)
    end)

    Mix.shell().info("")

    case result.verdict do
      :ok ->
        Mix.shell().info([:green, "OK: all configured features are properly wired.", :reset])

      :fail ->
        if result.wiring != [] do
          Mix.shell().error("Misconfigured features:")

          Enum.each(result.wiring, fn msg ->
            Mix.shell().error("  " <> msg)
          end)
        end

        Mix.shell().error(
          "ERROR: misconfigured features detected (see above). Fix the issues above before deploying."
        )

        exit({:shutdown, 1})
    end
  end

  defp print_row(row, quiet) do
    case row.state do
      :missing ->
        if quiet do
          Mix.shell().info([:faint, "  [ ] missing   ", :reset, feature_label(row.feature)])
        else
          Mix.shell().info([
            :faint,
            "  [ ] missing   ",
            :reset,
            feature_label(row.feature),
            " — ",
            :faint,
            row.hint,
            :reset
          ])
        end

      :available ->
        if quiet do
          Mix.shell().info([
            :yellow,
            "  [~] available ",
            :reset,
            feature_label(row.feature),
            " (not configured)"
          ])
        else
          Mix.shell().info([
            :yellow,
            "  [~] available ",
            :reset,
            feature_label(row.feature),
            " (not configured) — ",
            row.hint
          ])
        end

      :loaded_active ->
        Mix.shell().info([:green, "  [✓] loaded     ", :reset, feature_label(row.feature)])

      :configured_but_missing ->
        Mix.shell().info([
          :red,
          "  [!] misconfigured ",
          :reset,
          feature_label(row.feature),
          " — ",
          :red,
          row.hint,
          :reset
        ])
    end
  end

  defp feature_label(:totp_mfa), do: "totp_mfa (TOTP/MFA)"
  defp feature_label(:password_migration), do: "password_migration (bcrypt → argon2id)"
  defp feature_label(:oauth), do: "oauth (OAuth/OIDC)"
  defp feature_label(:rate_limiting), do: "rate_limiting (Hammer)"
  defp feature_label(:jwt), do: "jwt (JWT signing)"
  defp feature_label(:async_email), do: "async_email (Swoosh + Oban)"
  defp feature_label(:audit_forwarding), do: "audit_forwarding (Threadline + Oban)"
  defp feature_label(:encryption), do: "encryption (cloak_ecto vault)"
  defp feature_label(:enterprise_connections), do: "enterprise_connections (Req)"
  defp feature_label(other), do: to_string(other)
end
