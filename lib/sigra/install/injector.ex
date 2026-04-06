defmodule Sigra.Install.Injector do
  @moduledoc """
  Idempotent code injection for Sigra install generator.

  This module handles injecting authentication-related code into
  existing files in the host application (router, config, test support).
  All injection functions check for a marker comment before injecting
  to ensure idempotency.
  """

  @marker "# Sigra authentication"

  @doc """
  Injects authentication pipeline and routes into the router file.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the marker is already present.
  """
  @spec inject_router_plugs(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_router_plugs(file_contents, plug_code) do
    if String.contains?(file_contents, @marker) do
      {:already_injected, file_contents}
    else
      # Find the last `end` in the router and inject before it
      case find_last_end(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> "\n" <> plug_code <> "\n" <> rest}

        :error ->
          # Fallback: append to end of file
          {:ok, file_contents <> "\n" <> plug_code <> "\n"}
      end
    end
  end

  @doc """
  Injects Sigra configuration into config.exs.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the marker is already present.
  """
  @spec inject_config(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_config(file_contents, config_block) do
    if String.contains?(file_contents, @marker) do
      {:already_injected, file_contents}
    else
      # Insert before import_config if present, otherwise append
      case find_import_config(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> config_block <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> config_block}
      end
    end
  end

  @doc """
  Injects Argon2 test speedup configuration into test.exs.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the marker is already present.
  """
  @spec inject_test_config(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_test_config(file_contents, test_config_block) do
    if String.contains?(file_contents, @marker) do
      {:already_injected, file_contents}
    else
      {:ok, file_contents <> test_config_block}
    end
  end

  @doc """
  Injects auth test helper import into conn_case.ex.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the helper import is already present.
  """
  @spec inject_conn_case(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_conn_case(file_contents, helper_code) do
    helper_module = String.trim(helper_code)

    if String.contains?(file_contents, helper_module) do
      {:already_injected, file_contents}
    else
      # Find "import Phoenix.ConnTest" or "import Plug.Conn" and inject after
      anchor = find_conn_case_anchor(file_contents)

      case anchor do
        {:ok, anchor_line} ->
          new_contents =
            String.replace(
              file_contents,
              anchor_line,
              anchor_line <> "\n" <> helper_code
            )

          {:ok, new_contents}

        :error ->
          # Fallback: inject before the last `end`
          case find_last_end(file_contents) do
            {:ok, position} ->
              {before, rest} = String.split_at(file_contents, position)
              {:ok, before <> "\n" <> helper_code <> "\n" <> rest}

            :error ->
              {:ok, file_contents <> "\n" <> helper_code}
          end
      end
    end
  end

  # Find the position of the last `end` on its own line
  defp find_last_end(content) do
    lines = String.split(content, "\n")

    end_indices =
      lines
      |> Enum.with_index()
      |> Enum.filter(fn {line, _idx} -> String.trim(line) == "end" end)
      |> Enum.map(fn {_line, idx} -> idx end)

    case end_indices do
      [] ->
        :error

      indices ->
        last_idx = List.last(indices)

        position =
          lines
          |> Enum.take(last_idx)
          |> Enum.join("\n")
          |> String.length()
          # Add 1 for the newline
          |> Kernel.+(1)

        {:ok, position}
    end
  end

  # Find the position of `import_config` line
  defp find_import_config(content) do
    case Regex.run(~r/^import_config\s/m, content, return: :index) do
      [{pos, _len}] -> {:ok, pos}
      _ -> :error
    end
  end

  # Find an anchor line to inject after in ConnCase
  defp find_conn_case_anchor(content) do
    cond do
      line = find_line(content, "import Phoenix.ConnTest") -> {:ok, line}
      line = find_line(content, "import Plug.Conn") -> {:ok, line}
      true -> :error
    end
  end

  defp find_line(content, pattern) do
    content
    |> String.split("\n")
    |> Enum.find(fn line -> String.contains?(line, pattern) end)
  end
end
