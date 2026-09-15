defmodule Sigra.Test.PlanningPaths do
  @moduledoc """
  Resolves planning artifacts that milestone close-out relocates.

  `/gsd-complete-milestone` moves `.planning/phases/<phase>/` into
  `.planning/milestones/v<X.Y>-phases/<phase>/` and archives
  `.planning/REQUIREMENTS.md` alongside it. Phase contract tests assert against
  that evidence, so without this they break at exactly the moment their subject
  becomes immutable history — see the archive-aware resolvers in
  `scripts/ci/_phase-dir-resolve.sh` and `scripts/ci/prohibitions/_lib.mjs`.

  Every function returns a **repo-relative** path so callers can use it directly
  or join it onto their own root. When nothing resolves, the declared live path
  is returned unchanged, so a genuinely missing artifact still fails loudly
  against the path the test names rather than a surprising archive location.
  """

  @root Path.expand("../..", __DIR__)

  @doc "Absolute path to the repository root."
  def root, do: @root

  @doc "Repo-relative path to a phase directory, live or archived."
  def phase_dir(slug) do
    live = Path.join(".planning/phases", slug)

    if File.dir?(Path.join(@root, live)) do
      live
    else
      archived_phase_dir(slug) || live
    end
  end

  @doc "Repo-relative path to a file inside a phase directory, live or archived."
  def phase_file(slug, name), do: Path.join(phase_dir(slug), name)

  @doc "Repo-relative path to REQUIREMENTS.md, live or archived."
  def requirements do
    live = ".planning/REQUIREMENTS.md"

    if File.regular?(Path.join(@root, live)) do
      live
    else
      newest_archived("REQUIREMENTS.md") || live
    end
  end

  @doc """
  Resolves a declared repo-relative path to where the file actually lives.

  Use this where a path literal is itself part of the assertion (a pinned digest
  key, a value recorded inside an evidence receipt) and so must stay written as
  the phase declared it, while the read still has to find the archived copy.
  Paths outside `.planning/` are returned unchanged.
  """
  def resolve(".planning/phases/" <> rest = declared) do
    case String.split(rest, "/", parts: 2) do
      [slug, name] -> phase_file(slug, name)
      _ -> declared
    end
  end

  def resolve(".planning/REQUIREMENTS.md"), do: requirements()
  def resolve(declared), do: declared

  defp archived_phase_dir(slug) do
    @root
    |> Path.join(".planning/milestones/v*-phases")
    |> Path.wildcard()
    |> sort_by_version_desc()
    |> Enum.find_value(fn bucket ->
      candidate = Path.join(bucket, slug)
      if File.dir?(candidate), do: Path.relative_to(candidate, @root)
    end)
  end

  defp newest_archived(name) do
    @root
    |> Path.join(".planning/milestones/v*-#{name}")
    |> Path.wildcard()
    |> sort_by_version_desc()
    |> List.first()
    |> case do
      nil -> nil
      path -> Path.relative_to(path, @root)
    end
  end

  # Sort newest milestone first. Lexical order is wrong here (v1.5 would beat
  # v1.47), so compare the numeric segments of the version.
  defp sort_by_version_desc(paths) do
    Enum.sort_by(paths, &version_key/1, :desc)
  end

  defp version_key(path) do
    case Regex.run(~r/\bv(\d+(?:\.\d+)*)/, Path.basename(path)) do
      [_, version] -> version |> String.split(".") |> Enum.map(&String.to_integer/1)
      _ -> []
    end
  end
end
