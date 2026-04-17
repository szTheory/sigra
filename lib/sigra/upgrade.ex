defmodule Sigra.Upgrade do
  @moduledoc """
  Orchestrator for `mix sigra.upgrade` (Phase 18 D-08).

  Responsibilities:

    * Refuse dirty git working trees unless `--allow-dirty`
    * Detect source/target schema versions; refuse downgrades;
      short-circuit when already at the target version
    * Compute the plan (files to create, injections to apply,
      migrations to emit)
    * Interactive confirmation when `--yes` is not set
    * Emit the three-section stdout summary
      (`Applied` / `Pending` / `Next steps`)
    * Inject/update the Sigra schema version sentinel in
      `config/config.exs`
    * Optionally emit the personal-orgs data migration shim when
      `--backfill-personal-orgs` is passed

  All file mutation flows through `Sigra.Install.Injector` and
  `EEx.eval_file/2` so upgrade output stays byte-compatible with the
  `Sigra.Install.Runner` walker.

  ## Zero-org installs (BLOCKER 1)

  An upgrade run against an app that installed with
  `--no-organizations` must NOT emit the `organizations` ALTER
  migrations — the table doesn't exist. Detection is cheap and
  pre-Ecto-connect: we scan `priv/repo/migrations/` for any file
  whose body contains `create table(:organizations`. No schema file
  → no ALTERs → no backfill.
  """

  alias Sigra.Install.Injection
  alias Sigra.Install.Injector

  @typedoc "Validated opts from Mix.Tasks.Sigra.Upgrade (after NimbleOptions)"
  @type opts :: keyword()

  @type plan :: %{
          source: String.t(),
          target: String.t(),
          files: [term()],
          injections: [Injection.t()],
          migrations: [{String.t(), String.t()}]
        }

  # Default source version when no :schema_version sentinel is
  # present in host app config. "0.0.0" keeps Version.compare/2
  # returning :gt against any real lib version (Phase 18 deviation
  # from CONTEXT's "1.0.0" default: Sigra's current vsn is 0.1.0,
  # so the "1.0.0" literal would always compare as downgrade).
  @default_source_version "0.0.0"

  @doc """
  Top-level entrypoint called from the `sigra.upgrade` mix task.

  Returns `:ok` on success, may halt via `System.halt/1` on user
  dissent at the interactive confirmation prompt, and raises via
  `Mix.raise/1` on fatal refusals (dirty tree, downgrade attempt).
  """
  @spec run(opts()) :: :ok | {:halt, term()}
  def run(opts) do
    with :ok <- check_git_dirty(opts),
         {:ok, source, target} <- detect_versions(opts),
         :ok <- ensure_upgrade_direction(source, target),
         plan <- build_plan(opts, source, target),
         :ok <- maybe_confirm(plan, opts) do
      apply_plan(plan, opts)
    end
  end

  # ── Git dirty tree check ──────────────────────────────────────────

  @doc false
  def check_git_dirty(opts) do
    if Keyword.get(opts, :allow_dirty, false) do
      :ok
    else
      case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
        {"", 0} ->
          :ok

        {output, 0} when byte_size(output) > 0 ->
          Mix.raise("""
          Refusing to run `mix sigra.upgrade` on a dirty working tree.

          Either commit/stash your changes, or pass --allow-dirty to
          override.

          #{output}
          """)

        {_, _} ->
          # Not a git repo (or git is unavailable) — allow the host
          # app may not use git.
          :ok
      end
    end
  end

  # ── Version detection ────────────────────────────────────────────

  @doc false
  def detect_versions(opts) do
    source =
      Keyword.get(opts, :from) ||
        Application.get_env(:sigra, :schema_version, @default_source_version)

    target =
      case :application.get_key(:sigra, :vsn) do
        {:ok, vsn} -> to_string(vsn)
        :undefined -> @default_source_version
      end

    {:ok, source, target}
  end

  defp ensure_upgrade_direction(source, target) do
    case Version.compare(target, source) do
      :gt ->
        :ok

      :eq ->
        Mix.shell().info("Sigra is already at schema version #{target}; nothing to do.")
        {:halt, :already_at_target}

      :lt ->
        Mix.raise("Refusing to downgrade Sigra schema from #{source} to #{target}.")
    end
  end

  # ── Plan ─────────────────────────────────────────────────────────

  @doc false
  def build_plan(opts, source, target) do
    vault_promotion = promote_vault(opts)

    %{
      source: source,
      target: target,
      files: files_to_emit(opts, vault_promotion),
      injections: injections_to_apply(target, vault_promotion),
      migrations: migrations_to_emit(opts),
      vault_promotion: vault_promotion
    }
  end

  defp files_to_emit(_opts, vault_promotion), do: vault_promotion.files

  defp injections_to_apply(target_version, vault_promotion) do
    base = [version_sentinel_injection(target_version)]

    if vault_promotion.enabled? do
      base ++ [vault_child_injection(vault_promotion.application_path, vault_promotion.app_module)]
    else
      base
    end
  end

  @doc false
  def migrations_to_emit(opts) do
    # BLOCKER 1: only emit the ALTER migrations when the host app
    # actually has an organizations table. Detected by introspecting
    # priv/repo/migrations/ for a create_organizations migration.
    base =
      if organizations_table_present?() do
        [
          {"alter_add_owner_user_id.exs", "add_owner_user_id_to_organizations.exs"},
          {"alter_add_personal.exs", "add_personal_to_organizations.exs"}
        ]
      else
        []
      end

    # Data migration shim: only when the backfill flag is passed AND
    # the organizations table is present. Backfilling a nonexistent
    # table would be a hard error.
    if Keyword.get(opts, :backfill_personal_orgs, false) and organizations_table_present?() do
      base ++ [{"data_migration.exs", "backfill_personal_orgs.exs"}]
    else
      base
    end
  end

  @doc false
  def organizations_table_present? do
    migrations_dir = Path.join(["priv", "repo", "migrations"])

    if File.dir?(migrations_dir) do
      migrations_dir
      |> File.ls!()
      |> Enum.any?(fn filename ->
        path = Path.join(migrations_dir, filename)

        File.regular?(path) and
          String.contains?(File.read!(path), "create table(:organizations")
      end)
    else
      false
    end
  end

  defp version_sentinel_injection(target_version) do
    %Injection{
      target: Path.join(["config", "config.exs"]),
      marker: "config :sigra, :schema_version",
      anchor: :elixir_config,
      content: """

      # Sigra schema version — managed by `mix sigra.upgrade`.
      # Do not edit manually.
      config :sigra, :schema_version, "#{target_version}"
      """
    }
  end

  defp vault_child_injection(application_path, app_module) do
    %Injection{
      target: application_path,
      marker: "#{app_module}.Vault",
      anchor: :vault_child,
      content: app_module
    }
  end

  # ── Interactive confirmation ─────────────────────────────────────

  defp maybe_confirm(plan, opts) do
    cond do
      Keyword.get(opts, :yes, false) ->
        :ok

      Keyword.get(opts, :dry_run, false) ->
        :ok

      true ->
        print_plan(plan)

        if Mix.shell().yes?("Proceed with upgrade?") do
          :ok
        else
          System.halt(0)
        end
    end
  end

  defp print_plan(plan) do
    Mix.shell().info("""
    Sigra upgrade plan (#{plan.source} → #{plan.target}):
      Files:      #{length(plan.files)}
      Migrations: #{length(plan.migrations)}
      Injections: #{length(plan.injections)}
    """)
  end

  # ── Apply ────────────────────────────────────────────────────────

  defp apply_plan(plan, opts) do
    if Keyword.get(opts, :dry_run, false) do
      Mix.shell().info("[DRY RUN] Would apply plan:")
      print_plan(plan)
      :ok
    else
      emit_files(plan.files)
      Enum.each(plan.injections, &apply_injection/1)
      emit_migrations(plan.migrations)
      print_summary(plan)
      :ok
    end
  end

  defp emit_files(files) do
    Enum.each(files, fn file ->
      content = EEx.eval_file(file.template_path, file.binding)
      File.mkdir_p!(Path.dirname(file.target))
      File.write!(file.target, content)
      Mix.shell().info("* creating #{file.target}")
    end)
  end

  defp apply_injection(injection) do
    case Injector.apply(injection, cwd: File.cwd!()) do
      {:ok, _} ->
        :ok

      {:error, {:target_missing, path}} ->
        Mix.shell().info("* skipping injection for #{path} (file not found in host app)")

      {:error, reason} ->
        Mix.raise("Injection failed: #{inspect(reason)}")
    end
  end

  defp emit_migrations(migrations) do
    migrations
    |> Enum.with_index()
    |> Enum.each(fn {{template, output_name}, counter} ->
      write_migration(template, output_name, counter)
    end)
  end

  defp write_migration(template, output_name, counter) do
    dest_dir =
      if template == "data_migration.exs" do
        Path.join(["priv", "repo", "data_migrations"])
      else
        Path.join(["priv", "repo", "migrations"])
      end

    File.mkdir_p!(dest_dir)

    # Scan priv/repo/migrations/ and bump past the highest extant
    # timestamp so that `mix sigra.install` followed immediately by
    # `mix sigra.upgrade` (same second) can't collide on version.
    # The counter threads across the per-run migration list so the
    # ALTER pair (and optional data-migration shim) get strictly
    # monotonic 14-digit prefixes. (Phase 25 Bug B fix.)
    migrations_dir = Path.join(["priv", "repo", "migrations"])
    timestamp = next_migration_timestamp(migrations_dir, counter)
    dest = Path.join(dest_dir, "#{timestamp}_#{output_name}")

    template_path =
      Path.join([:code.priv_dir(:sigra), "templates", "sigra.upgrade", template])

    binding = upgrade_binding()
    content = EEx.eval_file(template_path, binding)
    File.write!(dest, content)
    Mix.shell().info("* creating #{dest}")
  end

  defp upgrade_binding do
    base = Mix.Phoenix.base()
    otp_app = Mix.Phoenix.otp_app()
    repo = repo_module(otp_app)

    [
      otp_app: otp_app,
      app_module: inspect(Module.concat([base])),
      # Match `Mix.Tasks.Sigra.Install.build_binding/4` precedent
      # exactly: `inspect/1` on a module atom renders as the bare
      # `MyApp.Repo` identifier (EEx `<%= repo_module %>` would
      # otherwise produce `Elixir.MyApp.Repo` via `to_string/1`).
      repo_module: inspect(repo),
      context_module: inspect(Module.concat([base, "Accounts"])),
      schema_alias: "User",
      table_name: "users",
      binary_id: true
    ]
  end

  @doc false
  def promote_vault(_opts) do
    binding = upgrade_binding()
    otp_app = binding[:otp_app] |> to_string()
    app_module = binding[:app_module]
    encrypted_path = Path.join(["lib", otp_app, "accounts", "encrypted.ex"])
    vault_path = Path.join(["lib", otp_app, "vault.ex"])
    application_path = Path.join(["lib", otp_app, "application.ex"])

    enabled? =
      File.exists?(encrypted_path) and
        encrypted_stub?(File.read!(encrypted_path))

    files =
      if enabled? do
        [
          maybe_promoted_vault_file(vault_path, binding),
          %{
            target: encrypted_path,
            template_path: install_template_path("core/encrypted_binary.ex"),
            binding: binding
          }
        ]
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    %{
      enabled?: enabled?,
      files: files,
      application_path: application_path,
      app_module: app_module
    }
  end

  defp maybe_promoted_vault_file(vault_path, binding) do
    if File.exists?(vault_path) do
      nil
    else
      %{
        target: vault_path,
        template_path: install_template_path("core/vault.ex"),
        binding: binding
      }
    end
  end

  defp encrypted_stub?(content) do
    String.contains?(content, "PASSTHROUGH STUB") or
      String.contains?(content, "__sigra_encryption_mode__, do: :stub") or
      String.contains?(content, "use Ecto.Type")
  end

  defp install_template_path(template) do
    Path.join([:code.priv_dir(:sigra), "templates", "sigra.install", template])
  end

  defp repo_module(otp_app) do
    case Application.get_env(otp_app, :ecto_repos, []) do
      [repo | _] -> repo
      [] -> Module.concat([Mix.Phoenix.base(), "Repo"])
    end
  end

  # ── Migration timestamp generator (Phase 25 Bug B fix) ────────────

  @doc false
  @spec next_migration_timestamp(Path.t(), non_neg_integer()) :: String.t()
  def next_migration_timestamp(migrations_dir, counter)
      when is_binary(migrations_dir) and is_integer(counter) and counter >= 0 do
    now_stamp =
      DateTime.utc_now()
      |> Calendar.strftime("%Y%m%d%H%M%S")
      |> String.to_integer()

    highest_existing =
      if File.dir?(migrations_dir) do
        migrations_dir
        |> File.ls!()
        |> Enum.map(&extract_migration_version/1)
        |> Enum.reject(&is_nil/1)
        |> case do
          [] -> 0
          versions -> Enum.max(versions)
        end
      else
        0
      end

    next = max(now_stamp, highest_existing + 1) + counter

    next
    |> Integer.to_string()
    |> String.pad_leading(14, "0")
  end

  @spec extract_migration_version(String.t()) :: non_neg_integer() | nil
  defp extract_migration_version(filename) do
    case Regex.run(~r/^(\d{14})_/, filename) do
      [_, version] -> String.to_integer(version)
      _ -> nil
    end
  end

  defp print_summary(plan) do
    banner =
      if plan.vault_promotion.enabled? do
        """

          → Generate and export CLOAK_KEY before boot:
            iex> 32 |> :crypto.strong_rand_bytes() |> Base.encode64()
        """
      else
        ""
      end

    Mix.shell().info("""

    Applied:
      ✓ Created #{length(plan.files)} files
      ✓ Applied #{length(plan.injections)} injections
      ✓ Generated #{length(plan.migrations)} migrations

    Pending:
      → Run: mix ecto.migrate

    Next steps:
    #{banner}
      📖 See: https://hexdocs.pm/sigra/upgrade-v1.1.html
    """)
  end
end
