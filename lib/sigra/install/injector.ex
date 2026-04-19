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
  @passkeys_start_marker "// Sigra passkeys:start"
  @passkeys_end_marker "// Sigra passkeys:end"
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
          {before, rest} = byte_split_at!(file_contents, position)
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

  @doc """
  Injects the passkey hook import and merged hook registration into
  `assets/js/app.js` when the standard Phoenix hook shape is present.

  Marker detection is authoritative: once `// Sigra passkeys:start` exists,
  the file is treated as already injected on re-runs.
  """
  @spec inject_app_js_passkeys(String.t(), String.t()) ::
          {:ok, String.t()} | {:already_injected, String.t()} | {:manual_action, String.t()}
  def inject_app_js_passkeys(file_contents, injection_template) do
    if String.contains?(file_contents, @passkeys_start_marker) do
      {:already_injected, file_contents}
    else
      with {:ok, import_line, hooks_line} <- extract_passkey_injection_parts(injection_template),
           {:ok, import_anchor} <- find_colocated_hooks_import(file_contents),
           {:ok, hooks_anchor} <- find_colocated_hooks_line(file_contents) do
        import_block =
          Enum.join([@passkeys_start_marker, import_line, @passkeys_end_marker], "\n")

        injected_imports =
          String.replace(file_contents, import_anchor, import_anchor <> "\n" <> import_block,
            global: false
          )

        merged_hooks_line = hooks_line <> ","

        injected_hooks =
          String.replace(injected_imports, hooks_anchor, merged_hooks_line, global: false)

        {:ok, injected_hooks}
      else
        _ ->
          {:manual_action, passkey_manual_instructions()}
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

  # Byte offset of the host `import_config "#{config_env()}.exs"` line (start
  # of the `import_config` token). Phoenix may indent the line or use CRLF;
  # avoid `^import_config` / single-byte splits that can land inside the word.
  defp find_import_config(content) do
    case :binary.match(content, "\r\nimport_config ") do
      {pos, _} ->
        {:ok, pos + 2}

      :nomatch ->
        case :binary.match(content, "\nimport_config ") do
          {pos, _} ->
            {:ok, pos + 1}

          :nomatch ->
            if String.starts_with?(content, "import_config ") do
              {:ok, 0}
            else
              :error
            end
        end
    end
  end

  # `find_import_config/1` and `Regex.run(..., return: :index)` return byte
  # offsets, while `String.split_at/2` indexes graphemes. On CRLF
  # `config.exs` that mismatch splices inside `import_config` (orphan
  # `im` + `port_config`).
  defp byte_split_at!(binary, byte_offset) when is_binary(binary) and is_integer(byte_offset) do
    total = byte_size(binary)

    if byte_offset < 0 or byte_offset > total do
      raise ArgumentError,
            "byte_split_at!/2: offset #{byte_offset} out of range for binary of #{total} bytes"
    end

    {:binary.part(binary, 0, byte_offset), :binary.part(binary, byte_offset, total - byte_offset)}
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
          {before, rest} = byte_split_at!(file_contents, position)
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
          {before, rest} = byte_split_at!(file_contents, position)
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

    if String.contains?(file_contents, vault_module) do
      {:already_injected, file_contents}
    else
      # Find `children = [` and inject after it
      case Regex.run(~r/children\s*=\s*\[/m, file_contents, return: :index) do
        [{pos, len}] ->
          insert_at = pos + len
          vault_child = "\n      {#{vault_module}, []},"
          {before, rest} = byte_split_at!(file_contents, insert_at)
          {:ok, before <> vault_child <> rest}

        _ ->
          # Fallback: append a comment
          {:ok,
           file_contents <>
             "\n# Add #{vault_module} to your application supervision tree:\n# {#{vault_module}, []}\n"}
      end
    end
  end

  @doc """
  Applies a `%Sigra.Install.Injection{}` record, routing to the
  appropriate marker-based injection function based on the anchor.

  Returns `{:ok, :injected}` on first apply, `{:ok, :already_present}`
  on subsequent applies (idempotency primitive behind GEN-04).

  Features never call `Injector.inject_*` functions directly; they
  return `%Injection{}` records from the `injections/1` callback in
  `Sigra.Install.Feature` and the walker passes them here.

  This is a thin adapter layer added for Phase 11 Wave 1 primitives.
  The legacy `inject_router_plugs/2` / `inject_config/2` / ...
  functions above continue to serve the monolith until Wave 4 swaps
  the monolith for the walker.
  """
  @spec apply(Sigra.Install.Injection.t(), keyword()) ::
          {:ok, :injected | :already_present} | {:error, term()}
  def apply(injection, opts \\ [])

  def apply(%Sigra.Install.Injection{} = injection, opts) do
    case File.read(injection.target) do
      {:ok, content} ->
        if String.contains?(content, injection.marker) do
          {:ok, :already_present}
        else
          do_inject(injection, content, opts)
        end

      {:error, :enoent} ->
        {:error, {:target_missing, injection.target}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_inject(%Sigra.Install.Injection{} = inj, content, _opts) do
    case apply_anchor(inj.anchor, content, inj.content) do
      {:manual_action, message} ->
        {:error, {:manual_action, message}}

      new_content ->
        File.write!(inj.target, new_content)
        {:ok, :injected}
    end
  end

  defp apply_anchor(:before_last_end, content, payload) do
    # Standard Elixir-module injection (router.ex, conn_case.ex, etc.).
    # Delegate to the pre-existing inject_router_plugs/2 body so the
    # bytes match the v1.0 monolith exactly.
    case find_last_end(content) do
      {:ok, position} ->
        {before, rest} = String.split_at(content, position)
        before <> "\n" <> payload <> "\n" <> rest

      :error ->
        content <> "\n" <> payload <> "\n"
    end
  end

  # config.exs-style injection: insert before the `import_config` line if
  # present, otherwise append. Matches the v1.0 monolith's
  # `inject_config/2` byte semantics.
  defp apply_anchor(:elixir_config, content, payload) do
    case find_import_config(content) do
      {:ok, position} ->
        {before, rest} = byte_split_at!(content, position)
        before <> payload <> "\n" <> rest

      :error ->
        content <> payload
    end
  end

  # test.exs-style injection: append to the end of file. Matches the
  # v1.0 monolith's `inject_test_config/2`.
  defp apply_anchor(:append_eof, content, payload) do
    content <> payload
  end

  # conn_case.ex-style injection: find `import Phoenix.ConnTest` (or
  # `import Plug.Conn`) and insert the helper code on the line below.
  # Falls back to before_last_end if no anchor line present. Matches
  # the v1.0 monolith's `inject_conn_case/2`.
  defp apply_anchor(:conn_case_helpers, content, payload) do
    case find_conn_case_anchor(content) do
      {:ok, anchor_line} ->
        String.replace(content, anchor_line, anchor_line <> "\n" <> payload)

      :error ->
        apply_anchor(:before_last_end, content, payload)
    end
  end

  defp apply_anchor(:after_use_block, content, payload) do
    String.replace(content, ~r/(\n  use [A-Za-z.]+.*?\n)/s, "\\1\n  #{payload}\n", global: false)
  end

  defp apply_anchor(:browser_pipeline, content, payload) do
    if Regex.match?(~r/^\s*pipeline :browser do$/m, content) do
      Regex.replace(
        ~r/^(\s*pipeline :browser do\n)(.*?)(^\s*end$)/ms,
        content,
        "\\1\\2#{payload}\n\\3",
        global: false
      )
    else
      {:manual_action,
       "Could not find `pipeline :browser do` in router.ex. Add `plug :fetch_current_scope` to the browser pipeline manually."}
    end
  end

  defp apply_anchor(:vault_child, content, app_module) do
    case inject_vault_child(content, app_module) do
      {:ok, new_content} -> new_content
      {:already_injected, new_content} -> new_content
    end
  end

  defp apply_anchor(:app_js_passkeys, content, payload) do
    case inject_app_js_passkeys(content, payload) do
      {:ok, new_content} -> new_content
      {:already_injected, new_content} -> new_content
      {:manual_action, message} -> {:manual_action, message}
    end
  end

  defp apply_anchor(:mix_deps, content, payload) do
    case inject_mix_dependency(content, payload) do
      {:ok, new_content} -> new_content
      {:already_injected, new_content} -> new_content
      {:manual_action, message} -> {:manual_action, message}
    end
  end

  defp apply_anchor(:mix_assets_setup, content, payload) do
    case inject_assets_setup_command(content, payload) do
      {:ok, new_content} -> new_content
      {:already_injected, new_content} -> new_content
      {:manual_action, message} -> {:manual_action, message}
    end
  end

  defp apply_anchor(:package_json_dependencies, content, payload) do
    case inject_package_json_dependency(content, payload) do
      {:ok, new_content} -> new_content
      {:already_injected, new_content} -> new_content
      {:manual_action, message} -> {:manual_action, message}
    end
  end

  defp apply_anchor(:at_top, content, payload), do: payload <> "\n" <> content

  defp apply_anchor(other, _content, _payload),
    do: raise(ArgumentError, "unsupported injection anchor: #{inspect(other)}")

  defp extract_passkey_injection_parts(template) do
    lines =
      template
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)

    with import_line when is_binary(import_line) <-
           Enum.find(lines, &String.starts_with?(&1, "import ")),
         hooks_line when is_binary(hooks_line) <-
           Enum.find(
             lines,
             &String.starts_with?(&1, "hooks: { ...colocatedHooks, ...PasskeyHooks }")
           ) do
      {:ok, import_line, hooks_line}
    else
      _ -> :error
    end
  end

  defp find_colocated_hooks_import(content) do
    case Regex.run(
           ~r/^import\s+\{\s*hooks\s+as\s+colocatedHooks\s*\}\s+from\s+["'][^"']+["']\s*$/m,
           content
         ) do
      [line] -> {:ok, line}
      _ -> :error
    end
  end

  defp find_colocated_hooks_line(content) do
    case Regex.run(~r/^\s*hooks:\s*\{\s*\.\.\.colocatedHooks\s*\},?\s*$/m, content) do
      [line] -> {:ok, line}
      _ -> :error
    end
  end

  defp passkey_manual_instructions do
    """
    Passkeys generated `assets/js/passkey_hooks.js`, but Sigra could not safely edit `assets/js/app.js`.

    Add these lines manually to your LiveSocket setup:

      import { PasskeyHooks } from "./passkey_hooks"
      hooks: { ...colocatedHooks, ...PasskeyHooks }
    """
  end

  defp inject_mix_dependency(file_contents, dependency_source) do
    dependency_line = String.trim(dependency_source)

    cond do
      String.contains?(file_contents, dependency_line) ->
        {:already_injected, file_contents}

      true ->
        patched =
          Regex.replace(
            ~r/defp deps do\s*\n(\s*)\[/,
            file_contents,
            "defp deps do\n\\1[\n\\1  #{dependency_line}",
            global: false
          )

        if patched == file_contents do
          {:manual_action, mix_exs_manual_instructions(dependency_line)}
        else
          {:ok, patched}
        end
    end
  end

  defp inject_package_json_dependency(file_contents, dependency_source) do
    with {:ok, dependency_map} <- Jason.decode(dependency_source),
         {:ok, package_json} <- Jason.decode(file_contents),
         {:ok, patched} <- merge_package_dependencies(package_json, dependency_map) do
      if patched == package_json do
        {:already_injected, file_contents}
      else
        encoded = patched |> Jason.encode_to_iodata!(pretty: true) |> IO.iodata_to_binary()
        {:ok, encoded <> "\n"}
      end
    else
      _ ->
        {:manual_action, package_json_manual_instructions(dependency_source)}
    end
  end

  defp inject_assets_setup_command(file_contents, command) do
    trimmed = String.trim(command)

    cond do
      String.contains?(file_contents, trimmed) ->
        {:already_injected, file_contents}

      true ->
        patched =
          Regex.replace(
            ~r/"assets\.setup":\s*\[(.*?)\]/s,
            file_contents,
            fn _match, entries ->
              inner =
                entries
                |> String.trim()

              inserted =
                if inner == "" do
                  ~s("#{trimmed}")
                else
                  ~s(#{inner}, "#{trimmed}")
                end

              ~s("assets.setup": [#{inserted}])
            end,
            global: false
          )

        if patched == file_contents do
          {:manual_action, assets_setup_manual_instructions(trimmed)}
        else
          {:ok, patched}
        end
    end
  end

  defp merge_package_dependencies(%{"dependencies" => deps} = package_json, dependency_map)
       when is_map(deps) do
    {:ok, Map.put(package_json, "dependencies", Map.merge(deps, dependency_map))}
  end

  defp merge_package_dependencies(_package_json, _dependency_map), do: :error

  defp mix_exs_manual_instructions(dependency_line) do
    """
    Passkeys generated passkey routes and browser assets, but Sigra could not safely edit `mix.exs`.

    Add this dependency to your `deps/0` list manually:

      #{dependency_line}
    """
  end

  defp package_json_manual_instructions(dependency_source) do
    {:ok, dependency_map} = Jason.decode(dependency_source)
    [{package_name, version}] = Map.to_list(dependency_map)

    """
    Passkeys generated passkey routes and browser assets, but Sigra could not safely edit `assets/package.json`.

    Add this dependency under `"dependencies"` manually:

      "#{package_name}": "#{version}"
    """
  end

  defp assets_setup_manual_instructions(command) do
    """
    Passkeys generated browser assets, but Sigra could not safely edit `mix.exs` `assets.setup`.

    Add this step to your `"assets.setup"` alias manually:

      "#{command}"
    """
  end
end
