defmodule Sigra.Install.Injector do
  @moduledoc """
  Idempotent code injection for Sigra install generator.

  This module handles injecting authentication-related code into
  existing files in the host application (router, config, test support).
  All injection functions check for a marker comment before injecting
  to ensure idempotency.
  """

  @marker "# Sigra authentication"
  @oauth_marker "# Sigra OAuth"
  @api_marker "# Sigra API"
  @jwt_marker "# Sigra JWT"
  @vault_marker "Vault"

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

  # -- OAuth-specific injection functions --

  @doc """
  Injects OAuth routes into the router file.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the OAuth marker is already present.
  """
  @spec inject_oauth_routes(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_oauth_routes(file_contents, route_code) do
    if String.contains?(file_contents, @oauth_marker) do
      {:already_injected, file_contents}
    else
      # Find the last `end` in the router and inject before it
      case find_last_end(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> "\n" <> route_code <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> "\n" <> route_code <> "\n"}
      end
    end
  end

  @doc """
  Injects OAuth provider configuration into config.exs.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the OAuth marker is already present.
  """
  @spec inject_oauth_config(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_oauth_config(file_contents, config_block) do
    if String.contains?(file_contents, "Sigra OAuth") do
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

  # -- API-specific injection functions --

  @doc """
  Injects API pipeline and routes into the router file.

  Adds an `:api_authenticated` pipeline with FetchBearer and
  RequireAuthenticated plugs, plus API token CRUD routes.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the API marker is already present.
  """
  @spec inject_api_routes(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_api_routes(file_contents, route_code) do
    if String.contains?(file_contents, @api_marker) do
      {:already_injected, file_contents}
    else
      case find_last_end(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> "\n" <> route_code <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> "\n" <> route_code <> "\n"}
      end
    end
  end

  @doc """
  Injects JWT authentication routes into the router file.

  Adds unauthenticated `/api/auth` scope with token create, refresh,
  MFA, and revoke endpoints. Only used with `--jwt` flag.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the JWT marker is already present.
  """
  @spec inject_jwt_routes(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_jwt_routes(file_contents, route_code) do
    if String.contains?(file_contents, @jwt_marker) do
      {:already_injected, file_contents}
    else
      case find_last_end(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> "\n" <> route_code <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> "\n" <> route_code <> "\n"}
      end
    end
  end

  @doc """
  Injects API token configuration into config.exs.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the API marker is already present.
  """
  @spec inject_api_config(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_api_config(file_contents, config_block) do
    if String.contains?(file_contents, "api_token:") do
      {:already_injected, file_contents}
    else
      case find_import_config(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> config_block <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> config_block}
      end
    end
  end

  # -- Account Lifecycle injection functions (Phase 8) --

  @lifecycle_marker "# Sigra account lifecycle"

  @doc """
  Injects account lifecycle routes into the router file.

  Adds settings, email confirmation, and reactivation routes to the
  authenticated scope. Also includes the auth_hooks.ex file in the
  generator output list.

  Routes injected:
  - `live "/users/settings", SettingsLive, :index`
  - `live "/users/settings/confirm-email/:token", SettingsLive, :confirm_email`
  - `live "/users/reactivation", ReactivationLive, :index`

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the lifecycle marker is already present.
  """
  @spec inject_lifecycle_routes(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_lifecycle_routes(file_contents, route_code) do
    if String.contains?(file_contents, @lifecycle_marker) do
      {:already_injected, file_contents}
    else
      case find_last_end(file_contents) do
        {:ok, position} ->
          {before, rest} = String.split_at(file_contents, position)
          {:ok, before <> "\n" <> route_code <> "\n" <> rest}

        :error ->
          {:ok, file_contents <> "\n" <> route_code <> "\n"}
      end
    end
  end

  @doc """
  Injects the `:sigra_lifecycle` queue into Oban configuration.

  Adds the lifecycle queue alongside the existing mailer queue.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if the queue is already present.
  """
  @spec inject_oban_lifecycle_queue(String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_oban_lifecycle_queue(file_contents) do
    if String.contains?(file_contents, "sigra_lifecycle") do
      {:already_injected, file_contents}
    else
      case Regex.run(~r/sigra_mailer:\s*\d+/, file_contents) do
        [match] ->
          new_contents =
            String.replace(file_contents, match, match <> ", sigra_lifecycle: 5")

          {:ok, new_contents}

        nil ->
          # No existing Oban config, append lifecycle queue config
          {:ok, file_contents}
      end
    end
  end

  @doc """
  Returns the list of files that the generator should include for
  account lifecycle features, including auth_hooks.ex.
  """
  @spec lifecycle_template_files() :: [String.t()]
  def lifecycle_template_files do
    [
      "settings_live.ex",
      "reactivation_live.ex",
      "auth_hooks.ex"
    ]
  end

  @doc """
  Injects Vault child spec into the application supervision tree.

  Finds the `children = [` list in application.ex and adds
  `{MyApp.Vault, []}` to it.

  Returns `{:ok, new_contents}` if injection succeeds, or
  `{:already_injected, contents}` if Vault is already present.
  """
  @spec inject_vault_child(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()}
  def inject_vault_child(file_contents, app_module) do
    vault_module = "#{app_module}.Vault"

    if String.contains?(file_contents, @vault_marker) do
      {:already_injected, file_contents}
    else
      # Find `children = [` and inject after it
      case Regex.run(~r/children\s*=\s*\[/m, file_contents, return: :index) do
        [{pos, len}] ->
          insert_at = pos + len
          vault_child = "\n      {#{vault_module}, []},"
          {before, rest} = String.split_at(file_contents, insert_at)
          {:ok, before <> vault_child <> rest}

        _ ->
          # Fallback: append a comment
          {:ok,
           file_contents <>
             "\n# Add #{vault_module} to your application supervision tree:\n# {#{vault_module}, []}\n"}
      end
    end
  end
end
