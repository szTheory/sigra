defmodule Sigra.Install.Runner do
  @moduledoc """
  Generic walker over a `[Sigra.Install.Feature]` list. Feature-agnostic:
  adding `Features.Organizations`, `Features.Passkeys`, or `Features.Admin`
  in a later phase requires ZERO edits to this module — only a new entry
  in the caller's feature list.

  See Phase 11 CONTEXT.md D-03 (full decomposition) and the "purely
  additive" invariant V-PA-01.

  ## Byte-identity contract with the v1.0 monolith

  The runner reproduces the exact stdout the pre-refactor monolith
  emitted (see `test/fixtures/install_golden/STDOUT.txt`):

    * `Mix.Generator.create_file/2` for every rendered file (and for
      migrations, since migration entries are inlined in `files/1`
      with their target already resolved from the allocated timestamp).
    * `Mix.shell().info([:green, "* injecting ", :reset, path])` for
      successful injections, `[:yellow, "* already injected ", ...]`
      for idempotent no-ops.
    * `Mix.shell().info/1` once per logical chunk returned by
      `feature.post_instructions/2` — features return a list of chunks
      where each chunk represents ONE monolith `info` call, so the
      trailing newlines Mix.shell().info appends match the monolith.

  The `%Sigra.Install.Report{}` is threaded through and populated for
  every decision, but is NOT rendered to stdout on the default run
  (that would diverge from the monolith's format). Host tooling (CI
  smoke runners, the idempotency test) can inspect the returned report
  directly.
  """

  alias Sigra.Install.{Injection, Injector, MigrationTimestamps, Report}

  @type run_result :: {:ok, Report.t()}

  @doc """
  Walks `features`, runs each enabled feature's callbacks, and returns
  the populated `%Report{}`.

  Steps:

    1. Filter `features` through `enabled?/1`.
    2. Allocate migration timestamps for all active features via
       `MigrationTimestamps.allocate/2`, then overlay any pre-existing
       migration files on disk (re-run idempotency, GEN-04).
    3. For each active feature, render files, apply injections, then
       print the feature's post-install instruction chunks.
  """
  @spec run([module()], keyword(), keyword()) :: run_result()
  def run(features, binding, opts) when is_list(features) and is_list(binding) do
    active = Enum.filter(features, fn f -> f.enabled?(opts) end)
    base_time = Keyword.get(opts, :base_time, DateTime.utc_now())
    allocated = MigrationTimestamps.allocate(active, base_time)
    resolved_ts = overlay_existing_migrations(active, allocated)

    report =
      Enum.reduce(active, Report.new(), fn feature, r ->
        feature_binding = Keyword.put(binding, :migration_timestamps, resolved_ts[feature] || %{})

        r
        |> run_files(feature, feature_binding)
        |> run_injections(feature, feature_binding)
        |> run_post_instructions(feature, feature_binding)
      end)

    {:ok, report}
  end

  # -- file rendering --------------------------------------------------------

  defp run_files(report, feature, binding) do
    feature.files(binding)
    |> Enum.reduce(report, fn {:eex, source, target}, r ->
      if File.exists?(target) do
        Mix.shell().info([:yellow, "* skipping ", :reset, target, " (already exists)"])
        Report.record_skipped(r, target, "already exists")
      else
        template_path = find_template(source)
        content = EEx.eval_file(template_path, binding)
        Mix.Generator.create_file(target, content)
        Report.record_generated(r, target)
      end
    end)
  end

  # -- injection application -------------------------------------------------

  defp run_injections(report, feature, binding) do
    feature.injections(binding)
    |> Enum.reduce(report, fn %Injection{} = injection, r ->
      case File.exists?(injection.target) do
        false ->
          # Target file absent — monolith skips silently, no output.
          r

        true ->
          case Injector.apply(injection) do
            {:ok, :injected} ->
              Mix.shell().info([:green, "* injecting ", :reset, injection.target])
              Report.record_modified(r, injection.target)

            {:ok, :already_present} ->
              Mix.shell().info([:yellow, "* already injected ", :reset, injection.target])
              Report.record_skipped(r, injection.target, "already injected")

            {:error, {:manual_action, instruction}} ->
              Report.record_manual_action(r, instruction)

            {:error, reason} ->
              Report.record_manual_action(
                r,
                "Injection into #{injection.target} failed: #{inspect(reason)}"
              )
          end
      end
    end)
  end

  # -- post-install instructions --------------------------------------------

  defp run_post_instructions(report, feature, binding) do
    chunks = feature.post_instructions(binding, report)

    Enum.each(chunks, fn chunk ->
      Mix.shell().info(chunk)
    end)

    report
  end

  # -- migration re-run idempotency -----------------------------------------

  # For each feature's migration slots, check whether a migration file with
  # a matching basename already exists on disk. If so, replace the allocated
  # timestamp with the existing file's 14-digit prefix so the walker's file
  # writes skip it (rather than writing a duplicate with a new timestamp).
  defp overlay_existing_migrations(features, allocated) do
    migrations_dir = Path.join(["priv", "repo", "migrations"])

    existing =
      case File.ls(migrations_dir) do
        {:ok, files} -> files
        _ -> []
      end

    Enum.reduce(features, allocated, fn feature, acc ->
      slots = feature.migrations([])
      feature_ts = Map.get(acc, feature, %{})

      new_ts =
        Enum.reduce(slots, feature_ts, fn {slot_key, _source, basename}, slot_acc ->
          case Enum.find(existing, fn f -> strip_timestamp(f) == basename end) do
            nil ->
              slot_acc

            filename ->
              case String.split(filename, "_", parts: 2) do
                [prefix, _] when byte_size(prefix) == 14 ->
                  Map.put(slot_acc, slot_key, prefix)

                _ ->
                  slot_acc
              end
          end
        end)

      Map.put(acc, feature, new_ts)
    end)
  end

  defp strip_timestamp(filename) do
    String.replace(filename, ~r/^\d{14}_/, "")
  end

  # -- template resolution --------------------------------------------------

  defp find_template(source) do
    # Host-app override first (per D-09; templates under `core/` subdir
    # since Phase 11-03 CD-01).
    override = Path.join([File.cwd!(), "priv", "templates", "sigra.install", source])

    if File.exists?(override) do
      override
    else
      Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", source]))
    end
  end
end
