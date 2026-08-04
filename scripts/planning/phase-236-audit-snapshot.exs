#!/usr/bin/env elixir

defmodule Phase236AuditSnapshot do
  @root Path.expand("../..", __DIR__)
  @phase_numbers 230..235

  def main(args) do
    case args do
      ["compare", snapshot_path] ->
        compare!(snapshot_path)

      ["historical-verify", input_path, output_path, freeze_commit, audit_commit] ->
        historical_verify!(input_path, output_path, freeze_commit, audit_commit)

      [] ->
        IO.write(snapshot!() |> :json.encode() |> IO.iodata_to_binary())

      _ ->
        raise ArgumentError,
              "usage: phase-236-audit-snapshot.exs [compare SNAPSHOT.json | historical-verify INPUT.json OUTPUT.json FREEZE_COMMIT AUDIT_COMMIT]"
    end
  end

  def snapshot! do
    %{
      "schema_version" => 1,
      "claim_limits" => [
        "This artifact snapshots deterministic repository and resolver inputs.",
        "It does not invoke an audit or cryptographically authenticate an LLM or skill invocation."
      ],
      "starting_commit" => git!("rev-parse", ["HEAD"]),
      "members" => members!(),
      "files" => files!(),
      "resolvers" => resolvers!()
    }
    |> with_manifest_sha()
  end

  def compare!(snapshot_path) do
    expected = snapshot_path |> absolute() |> File.read!() |> :json.decode()
    actual = snapshot!()

    # Commit identity is context, rather than an audit input: Task 1 necessarily creates
    # a new commit after it freezes the input manifest.
    if expected["manifest_sha256"] != actual["manifest_sha256"] do
      raise ArgumentError,
            "audit input snapshot differs: expected #{expected["manifest_sha256"]}, got #{actual["manifest_sha256"]}"
    end

    IO.puts("audit input snapshot matches #{expected["manifest_sha256"]}")
  end

  def historical_verify!(input_path, output_path, freeze_commit, audit_commit) do
    input = input_path |> absolute() |> File.read!() |> :json.decode()
    output = output_path |> absolute() |> File.read!() |> :json.decode()
    starting_commit = input["starting_commit"]
    freeze_commit = git!("rev-parse", [freeze_commit])
    audit_commit = git!("rev-parse", [audit_commit])

    assert_equal!(input["manifest_sha256"], manifest_sha(input), "input manifest")
    assert_equal!(starting_commit, git!("rev-parse", ["#{freeze_commit}^"]), "freeze parent")
    assert_equal!(freeze_commit, git!("rev-parse", ["#{audit_commit}^"]), "audit parent")

    assert_equal!(
      [
        "A\t.planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-INPUT-SNAPSHOT.json",
        "A\tscripts/planning/phase-236-audit-snapshot-test.exs",
        "A\tscripts/planning/phase-236-audit-snapshot.exs",
        "M\ttest/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs"
      ],
      changed_paths!(freeze_commit),
      "freeze scope"
    )

    assert_equal!(
      [
        "A\t.planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-OUTPUT-SNAPSHOT.json",
        "M\t.planning/v1.47-v1.47-MILESTONE-AUDIT.md",
        "M\ttest/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs"
      ],
      changed_paths!(audit_commit),
      "audit scope"
    )

    Enum.each(input["files"], fn %{"path" => path, "sha256" => digest} ->
      contents =
        if Path.type(path) == :absolute,
          do: File.read!(path),
          else: git_show!(starting_commit, path)

      assert_equal!(digest, sha256(contents), "source digest for #{path}")
    end)

    input_paths =
      Enum.map(input["files"], & &1["path"]) |> Enum.reject(&(Path.type(&1) == :absolute))

    assert_equal!(
      [],
      changed_between!(starting_commit, audit_commit, input_paths),
      "historical source mutations"
    )

    assert_equal!(
      input["manifest_sha256"],
      output["input_manifest_sha256"],
      "output input manifest"
    )

    assert_equal!(
      input["manifest_sha256"],
      output["post_audit_manifest_sha256"],
      "output post-audit manifest"
    )

    assert_equal!(
      output["audit_sha256"],
      sha256(git_show!(audit_commit, output["audit_path"])),
      "audit digest"
    )

    unless is_list(input["resolvers"]) and
             Enum.all?(
               input["resolvers"],
               &(is_map(&1) and is_binary(&1["command"]) and is_integer(&1["exit_status"]) and
                   is_binary(&1["stdout_sha256"]))
             ) do
      raise ArgumentError, "snapshot resolvers are structurally invalid"
    end

    unless "It does not invoke an audit or cryptographically authenticate an LLM or skill invocation." in input[
             "claim_limits"
           ] and
             String.contains?(
               output["claim_limit"],
               "cannot cryptographically establish LLM identity"
             ) do
      raise ArgumentError, "snapshot provenance claim limit is missing"
    end

    IO.puts("historical audit boundary verified #{input["manifest_sha256"]}")
  end

  defp with_manifest_sha(snapshot) do
    manifest = snapshot |> Map.drop(["starting_commit"]) |> canonical_json()
    Map.put(snapshot, "manifest_sha256", sha256(manifest))
  end

  defp manifest_sha(snapshot),
    do:
      snapshot |> Map.drop(["starting_commit", "manifest_sha256"]) |> canonical_json() |> sha256()

  defp assert_equal!(expected, actual, label) do
    unless expected == actual,
      do:
        raise(
          ArgumentError,
          "#{label} differs: expected #{inspect(expected)}, got #{inspect(actual)}"
        )
  end

  defp changed_paths!(commit),
    do: git_lines!("diff-tree", ["--no-commit-id", "--name-status", "-r", commit])

  defp changed_between!(from, to, paths) do
    git_lines!("diff", ["--name-only", "#{from}..#{to}", "--" | paths])
  end

  defp git_show!(commit, path) do
    {contents, 0} = System.cmd("git", ["show", "#{commit}:#{path}"], cd: @root)
    contents
  end

  defp git_lines!(command, args) do
    git!(command, args) |> String.split("\n", trim: true)
  end

  defp members! do
    roadmap = read!(".planning/ROADMAP.md")

    listed =
      resolver!("phases.list", ["--raw"])["resolved_value"] |> String.split("\n", trim: true)

    @phase_numbers
    |> Enum.map(fn phase ->
      path = resolver!("find-phase", [Integer.to_string(phase), "--raw"])["resolved_value"]

      unless String.contains?(roadmap, "Phase #{phase}:"),
        do: raise("ROADMAP is missing Phase #{phase}")

      unless Path.basename(path) in listed, do: raise("phases.list is missing #{path}")
      %{"phase" => phase, "directory" => path}
    end)
  end

  defp files! do
    base = [
      "AGENTS.md",
      ".planning/PROJECT.md",
      ".planning/STATE.md",
      ".planning/ROADMAP.md",
      ".planning/REQUIREMENTS.md",
      ".planning/config.json",
      "/Users/jon/.codex/gsd-core/workflows/" <> "audit" <> "-milestone.md",
      ".planning/phases/236-closeout-evidence-reconciliation/236-VALIDATION-REPLAY-BASELINE.json",
      ".planning/phases/236-closeout-evidence-reconciliation/236-04-SUMMARY.md"
    ]

    phase_files =
      members!()
      |> Enum.flat_map(fn %{"directory" => directory} ->
        Path.wildcard(Path.join(directory, "*-{VERIFICATION,VALIDATION,SUMMARY}.md"),
          match_dot: true
        )
      end)

    (base ++ phase_files)
    |> Enum.map(&relative_path/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn path ->
      full_path = absolute(path)
      unless File.regular?(full_path), do: raise("required audit input missing: #{path}")
      %{"path" => path, "sha256" => full_path |> File.read!() |> sha256()}
    end)
  end

  defp resolvers! do
    ([
       {"init.milestone-op", []},
       {"phases.list", ["--raw"]}
     ] ++
       Enum.map(@phase_numbers, &{"find-phase", [Integer.to_string(&1), "--raw"]}) ++
       [
         {"loop", ["render-hooks", "verify:post", "--raw"]},
         {"agent-skills", ["gsd-integration-checker"]},
         {"resolve-model", ["gsd-integration-checker", "--raw"]}
       ])
    |> Enum.map(fn {command, args} -> resolver!(command, args) end)
  end

  defp resolver!(command, args) do
    {stdout, status} =
      System.cmd("node", [gsd_tools(), "query", command | args],
        cd: @root,
        stderr_to_stdout: false
      )

    normalized = normalize(stdout)

    %{
      "command" => Enum.join([command | args], " "),
      "exit_status" => status,
      "present" => normalized != "",
      "stdout_sha256" => sha256(normalized),
      "resolved_value" => normalized
    }
  end

  defp normalize(output) do
    value = String.trim(output)

    try do
      value |> :json.decode() |> canonical_json()
    rescue
      _ -> value
    end
  end

  defp canonical_json(value) when is_map(value) do
    value
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {key, item} -> [:json.encode(key), ":", canonical_json(item)] end)
    |> IO.iodata_to_binary()
    |> then(&("{" <> &1 <> "}"))
  end

  defp canonical_json(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical_json/1) <> "]"

  defp canonical_json(value), do: value |> :json.encode() |> IO.iodata_to_binary()

  defp gsd_tools, do: "/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs"
  defp read!(path), do: path |> absolute() |> File.read!()

  defp absolute(path),
    do: if(String.starts_with?(path, "/"), do: path, else: Path.join(@root, path))

  defp relative_path(path),
    do: if(String.starts_with?(path, @root), do: Path.relative_to(path, @root), else: path)

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp git!(command, args) do
    case System.cmd("git", [command | args], cd: @root) do
      {output, 0} ->
        String.trim(output)

      {output, status} ->
        raise ArgumentError, "git #{command} failed (#{status}): #{String.trim(output)}"
    end
  end
end

Phase236AuditSnapshot.main(System.argv())
