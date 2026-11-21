defmodule Sigra.Test.PhxNewArchive do
  @moduledoc false

  @required_archive "phx_new-1.8.8"

  @doc """
  Checks the pinned Phoenix generator archive using Mix's supported `archive` task.

  The pure resolver is public so test controls can exercise the exact policy without
  modifying the developer's installed archives or environment.
  """
  def discover do
    result =
      try do
        System.cmd("mix", ["archive"], stderr_to_stdout: true)
      rescue
        error in ErlangError -> {Exception.message(error), 127}
      end

    resolve(result, System.get_env("SIGRA_CI_REQUIRED") == "1")
  end

  @doc "Resolves `{command_output, exit_status}` to available, local skip, or required error."
  def resolve({output, 0}, required?) do
    if archive_present?(output), do: :available, else: unavailable(:missing, output, required?)
  end

  def resolve({output, status}, required?) do
    unavailable({:command_failed, status}, output, required?)
  end

  defp archive_present?(output) do
    Enum.any?(String.split(output, "\n"), fn line ->
      Regex.match?(~r/^\s*\*?\s*#{Regex.escape(@required_archive)}\s*$/, line)
    end)
  end

  defp unavailable(cause, output, required?) do
    detail =
      case cause do
        :missing -> "the pinned archive was not listed by `mix archive`"
        {:command_failed, status} -> "the `mix archive` command failed with exit status #{status}"
      end

    diagnostic = String.trim(output)
    diagnostic = if diagnostic == "", do: "(no command output)", else: diagnostic

    message =
      "#{detail}: #{@required_archive}. Install it with `mix archive.install --force hex phx_new 1.8.8`.\n" <>
        "Archive command output: #{diagnostic}"

    if required? do
      {:error, "SIGRA_CI_REQUIRED=1: #{message}"}
    else
      {:skip, message}
    end
  end
end
