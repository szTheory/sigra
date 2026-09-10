defmodule Sigra.Planning.Phase2351EvidenceStateContract do
  @moduledoc false

  @negative_ids [
    34_466_384_009,
    34_466_384_470,
    34_467_186_749,
    34_467_189_602,
    34_468_109_536,
    34_468_110_161,
    34_493_873_867,
    34_493_911_924,
    34_520_992_740,
    34_520_986_751
  ]
  @receiver_paths ~w(
    test/sigra/install/features/passkeys_js_test.exs
    test/sigra/install/generator_passkeys_opt_out_test.exs
    test/sigra/install/golden_diff_test.exs
    test/sigra/install/idempotency_test.exs
    test/sigra/install/vault_promotion_test.exs
    test/upgrade_test.exs
  )
  @complete_ids ~w(TEST-01 TEST-02 TEST-03 DX-01 DX-02 DX-03 DX-04 DX-06)

  def fixture do
    sha = hex(40, 11)
    evidence_sha = hex(40, 12)
    negative = Enum.map(@negative_ids, &%{"id" => &1})

    pr = %{
      "schema_version" => "sigra.library-partitions-evidence/v1",
      "repository" => "szTheory/sigra",
      "pr" => %{"number" => 234},
      "run" => run(90_000_000_001, "pull_request", sha),
      "owner" => job(91_000_000_001, "Library tests shard"),
      "aggregate" => job(91_000_000_002, "Library tests"),
      "artifacts" => [
        artifact(
          92_000_000_001,
          "library-partitions-90000000001-1",
          "sigra-library-partitions.json",
          21
        ),
        artifact(
          92_000_000_002,
          "library-partition-1-timings-90000000001-1",
          "sigra-library-1-timings.json",
          22
        ),
        artifact(
          92_000_000_003,
          "library-partition-2-timings-90000000001-1",
          "sigra-library-2-timings.json",
          23
        )
      ],
      "partitions" => %{
        "execution_mode" => "sequential",
        "ordinary_universe_count" => 225,
        "manifest_counts" => [112, 113],
        "test_counts" => [1200, 1201],
        "durations_ms" => [30_001, 31_002],
        "conclusions" => ["success", "success"],
        "exit_statuses" => [0, 0]
      },
      "protected_invariants" => %{
        "library_tests_aggregate_sha256" => hex(64, 24),
        "sole_pr_owner" => "MIX_ENV=test mix ci",
        "fast_01_verifier" => "source_complete_offline_attestation_verified",
        "gate_05_verifier" => "offline_attestation_verified"
      },
      "commands" => %{},
      "supersession" => %{},
      "negative_runs" => negative
    }

    scaffold = %{
      "schema_version" => "sigra.library-install-golden-evidence/v1",
      "repository" => "szTheory/sigra",
      "run" => run(90_000_000_002, "workflow_dispatch", sha),
      "job" => job(91_000_000_003, "Library install golden (non-PR)"),
      "artifacts" => [
        artifact(
          92_000_000_004,
          "library-install-golden-90000000002-1",
          "sigra-library-install-golden.json",
          25
        ),
        artifact(
          92_000_000_005,
          "library-install-diagnostics-90000000002-1",
          "sigra-install-golden-diagnostics.json",
          26
        )
      ],
      "receivers" => %{
        "paths" => @receiver_paths,
        "count" => 6,
        "duration_ms" => 44_003,
        "exit_status" => 0,
        "conclusion" => "success",
        "prepared_fixture" => true,
        "worker_ceiling" => 2
      },
      "diagnostics" => %{
        "schema_version" => "sigra.install-fixture-diagnostics/v1",
        "variant_count" => 6,
        "worker_count" => 2,
        "failed_paths" => [],
        "raw_install_duration_ms" => 44_003
      },
      "protected_invariants" => %{},
      "commands" => %{},
      "supersession" => %{},
      "negative_runs" => negative
    }

    validation = %{
      "schema_version" => "sigra.library-routing-validation/v1",
      "repository" => "szTheory/sigra",
      "evidence_commit_sha" => evidence_sha,
      "capture_run_ids" => [90_000_000_001, 90_000_000_002],
      "negative_run_ids" => @negative_ids,
      "negative_runs_sha256" => digest(canonical(negative)),
      "validations" => [
        %{
          "route" => "pr",
          "run" => run(90_000_000_003, "pull_request", evidence_sha),
          "selected_jobs" => [
            job(91_000_000_004, "Library tests shard"),
            job(91_000_000_005, "Library tests")
          ]
        },
        %{
          "route" => "dispatch",
          "run" => run(90_000_000_004, "workflow_dispatch", evidence_sha),
          "selected_jobs" => [job(91_000_000_006, "Library install golden (non-PR)")]
        }
      ],
      "commands" => %{}
    }

    receipts = %{pr: pr, scaffold: scaffold, validation: validation}
    {:post, facts} = validate_state(receipts)

    %{
      pre_state: {:pre, %{present_capture_receipts: []}},
      pr: pr,
      scaffold: scaffold,
      validation: validation,
      receipts: receipts,
      facts: facts,
      pre_documents: pre_document_fixture(),
      post_documents: post_document_fixture(facts)
    }
  end

  def validate_state(receipts) when is_map(receipts) do
    exact_subset!(Map.keys(receipts), MapSet.new([:pr, :scaffold, :validation]), "receipt set")
    pr = Map.get(receipts, :pr)
    scaffold = Map.get(receipts, :scaffold)
    validation = Map.get(receipts, :validation)
    if pr, do: validate_pr!(pr)
    if scaffold, do: validate_scaffold!(scaffold)

    if validation do
      require!(
        not is_nil(pr) and not is_nil(scaffold),
        "validation requires both capture receipts"
      )

      validate_validation!(validation, pr, scaffold)
      {:post, facts(pr, scaffold, validation)}
    else
      present = [:pr, :scaffold] |> Enum.filter(&Map.has_key?(receipts, &1))
      {:pre, %{present_capture_receipts: present}}
    end
  end

  def repository_state(root \\ File.cwd!()) do
    phase =
      Path.join(
        root,
        ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test"
      )

    [
      pr: "235.1-PR-EVIDENCE.json",
      scaffold: "235.1-SCAFFOLD-EVIDENCE.json",
      validation: "235.1-VALIDATION-RUN.json"
    ]
    |> Enum.reduce(%{}, fn {key, name}, receipts ->
      path = Path.join(phase, name)

      if File.regular?(path),
        do: Map.put(receipts, key, path |> File.read!() |> JSON.decode!()),
        else: receipts
    end)
    |> validate_state()
  end

  def validate_documents({:pre, _}, documents) when is_map(documents) do
    joined = Enum.map_join(documents, "\n", fn {path, bytes} -> path <> "\n" <> bytes end)
    refute_tokens!(joined, ["VALIDATION-RUN.json` proves", "24/24 satisfied"])

    if Map.has_key?(documents, ".planning/REQUIREMENTS.md") do
      requirements = documents[".planning/REQUIREMENTS.md"]

      Enum.each(
        @complete_ids,
        &require!(
          Regex.match?(~r/\| #{&1} \|[^\n]*\| Gaps Found \|/, requirements),
          "pre requirements gaps"
        )
      )
    end

    if Map.has_key?(documents, ".planning/v1.47-MILESTONE-AUDIT.md") do
      audit = documents[".planning/v1.47-MILESTONE-AUDIT.md"]

      Enum.each(
        ["status: gaps_found", "requirements: 21/24", "integration: 7/10", "flows: 5/6"],
        &require!(audit =~ &1, "pre audit #{&1}")
      )
    end

    if Map.has_key?(
         documents,
         ".planning/phases/235-terminal-ratification-measured-not-read/235-VERIFICATION.md"
       ) do
      terminal =
        documents[
          ".planning/phases/235-terminal-ratification-measured-not-read/235-VERIFICATION.md"
        ]

      Enum.each(
        [
          "status: passed",
          "score: 11/11 must-haves verified",
          "**Status:** human_needed",
          "11/11 truths verified (0 present, behavior-unverified)",
          "flagged judgment-tier"
        ],
        &require!(terminal =~ &1, "pre terminal #{&1}")
      )
    end

    if Map.has_key?(
         documents,
         ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION.md"
       ) do
      require!(
        documents[
          ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION.md"
        ] =~ "⬜ pending",
        "pre validation non-green"
      )
    end

    :ok
  end

  def validate_documents({:post, facts}, documents) when is_map(documents) do
    joined = Enum.map_join(documents, "\n", fn {path, bytes} -> path <> "\n" <> bytes end)

    required =
      ["Complete", "passed", "11/11", "24/24", "10/10", "6/6", "Phase 234 route evolution"] ++
        Enum.map(@complete_ids, &"#{&1}: Complete") ++ fact_tokens(facts)

    Enum.each(required, &require!(joined =~ &1, "post document citation #{&1}"))

    Enum.each(
      ["FAST-01", "GATE-05", "469 seconds", "30782184713"],
      &require!(joined =~ &1, "protected citation #{&1}")
    )

    refute_tokens!(joined, [
      "Gaps Found",
      "status: gaps_found",
      "human_needed",
      "behavior-unverified"
    ])

    :ok
  end

  def fact_tokens(facts) do
    [
      Integer.to_string(facts.pr_run_id),
      Integer.to_string(facts.scaffold_run_id),
      Integer.to_string(facts.validation_pr_run_id),
      Integer.to_string(facts.validation_dispatch_run_id),
      facts.capture_sha,
      facts.evidence_sha,
      facts.pr_receipt_sha256,
      facts.scaffold_receipt_sha256,
      Integer.to_string(facts.partition_1_ms),
      Integer.to_string(facts.partition_2_ms),
      Integer.to_string(facts.scaffold_ms),
      facts.ratio
    ]
  end

  defp facts(pr, scaffold, validation) do
    [first, second] = validation["validations"]
    [p1, p2] = pr["partitions"]["durations_ms"]

    %{
      pr_run_id: pr["run"]["id"],
      scaffold_run_id: scaffold["run"]["id"],
      validation_pr_run_id: first["run"]["id"],
      validation_dispatch_run_id: second["run"]["id"],
      capture_sha: pr["run"]["head_sha"],
      evidence_sha: validation["evidence_commit_sha"],
      pr_job_id: pr["owner"]["id"],
      scaffold_job_id: scaffold["job"]["id"],
      pr_artifact_ids: Enum.map(pr["artifacts"], & &1["id"]),
      scaffold_artifact_ids: Enum.map(scaffold["artifacts"], & &1["id"]),
      pr_artifact_sha256: Enum.map(pr["artifacts"], & &1["sha256"]),
      scaffold_artifact_sha256: Enum.map(scaffold["artifacts"], & &1["sha256"]),
      pr_receipt_sha256: digest(canonical(pr)),
      scaffold_receipt_sha256: digest(canonical(scaffold)),
      partition_1_ms: p1,
      partition_2_ms: p2,
      scaffold_ms: scaffold["receivers"]["duration_ms"],
      ratio: :erlang.float_to_binary(max(p1, p2) / min(p1, p2), decimals: 3)
    }
  end

  defp validate_pr!(value) do
    exact!(
      value,
      ~w(schema_version repository pr run owner aggregate artifacts partitions protected_invariants commands supersession negative_runs),
      "PR"
    )

    require!(
      value["schema_version"] == "sigra.library-partitions-evidence/v1" &&
        value["repository"] == "szTheory/sigra",
      "PR identity"
    )

    exact!(value["pr"], ["number"], "PR number")
    positive_int!(value["pr"]["number"], "PR number")
    validate_run!(value["run"], "pull_request", "PR")
    validate_job!(value["owner"], "Library tests shard", "PR owner")
    validate_job!(value["aggregate"], "Library tests", "PR aggregate")
    require!(value["owner"]["id"] != value["aggregate"]["id"], "PR job IDs distinct")
    validate_artifacts!(value["artifacts"], 3, "PR")

    exact!(
      value["partitions"],
      ~w(execution_mode ordinary_universe_count manifest_counts test_counts durations_ms conclusions exit_statuses),
      "PR partitions"
    )

    parts = value["partitions"]
    require!(parts["execution_mode"] == "sequential", "PR execution mode")
    positive_int!(parts["ordinary_universe_count"], "ordinary count")
    Enum.each(~w(manifest_counts test_counts durations_ms), &positive_pair!(parts[&1], &1))

    require!(
      Enum.sum(parts["manifest_counts"]) == parts["ordinary_universe_count"],
      "ordinary exact set"
    )

    require!(
      parts["conclusions"] == ["success", "success"] && parts["exit_statuses"] == [0, 0],
      "partition result"
    )

    [a, b] = parts["durations_ms"]
    require!(max(a, b) <= min(a, b) * 2, "partition ratio")
    validate_negative!(value["negative_runs"])
  end

  defp validate_scaffold!(value) do
    exact!(
      value,
      ~w(schema_version repository run job artifacts receivers diagnostics protected_invariants commands supersession negative_runs),
      "scaffold"
    )

    require!(
      value["schema_version"] == "sigra.library-install-golden-evidence/v1" &&
        value["repository"] == "szTheory/sigra",
      "scaffold identity"
    )

    validate_run!(value["run"], "workflow_dispatch", "scaffold")
    validate_job!(value["job"], "Library install golden (non-PR)", "scaffold job")
    validate_artifacts!(value["artifacts"], 2, "scaffold")

    exact!(
      value["receivers"],
      ~w(paths count duration_ms exit_status conclusion prepared_fixture worker_ceiling),
      "receivers"
    )

    receivers = value["receivers"]

    require!(
      receivers["paths"] == @receiver_paths && receivers["count"] == 6,
      "receiver exact paths"
    )

    positive_int!(receivers["duration_ms"], "receiver duration")

    require!(
      receivers["exit_status"] == 0 && receivers["conclusion"] == "success" &&
        receivers["prepared_fixture"] == true && receivers["worker_ceiling"] == 2,
      "receiver result"
    )

    exact!(
      value["diagnostics"],
      ~w(schema_version variant_count worker_count failed_paths raw_install_duration_ms),
      "diagnostics"
    )

    diagnostics = value["diagnostics"]

    require!(
      diagnostics["schema_version"] == "sigra.install-fixture-diagnostics/v1" &&
        diagnostics["variant_count"] == 6 && diagnostics["worker_count"] == 2 &&
        diagnostics["failed_paths"] == [] &&
        diagnostics["raw_install_duration_ms"] == receivers["duration_ms"],
      "diagnostics facts"
    )

    validate_negative!(value["negative_runs"])
  end

  defp validate_validation!(value, pr, scaffold) do
    exact!(
      value,
      ~w(schema_version repository evidence_commit_sha capture_run_ids negative_run_ids negative_runs_sha256 validations commands),
      "validation"
    )

    require!(
      value["schema_version"] == "sigra.library-routing-validation/v1" &&
        value["repository"] == "szTheory/sigra",
      "validation identity"
    )

    digest!(value["evidence_commit_sha"], 40, "evidence SHA")
    require!(pr["run"]["head_sha"] == scaffold["run"]["head_sha"], "capture SHA equality")

    require!(
      value["capture_run_ids"] == [pr["run"]["id"], scaffold["run"]["id"]],
      "capture links"
    )

    require!(pr["negative_runs"] == scaffold["negative_runs"], "ten-ledger equality")
    negative_ids = Enum.map(pr["negative_runs"], & &1["id"])
    require!(value["negative_run_ids"] == negative_ids, "negative IDs")

    require!(
      value["negative_runs_sha256"] == digest(canonical(pr["negative_runs"])),
      "negative digest"
    )

    require!(
      is_list(value["validations"]) && length(value["validations"]) == 2,
      "two validations"
    )

    [pr_validation, dispatch_validation] = value["validations"]

    validate_validation_route!(
      pr_validation,
      "pr",
      "pull_request",
      ["Library tests shard", "Library tests"],
      value["evidence_commit_sha"]
    )

    validate_validation_route!(
      dispatch_validation,
      "dispatch",
      "workflow_dispatch",
      ["Library install golden (non-PR)"],
      value["evidence_commit_sha"]
    )

    ids =
      [
        pr["run"]["id"],
        scaffold["run"]["id"],
        pr_validation["run"]["id"],
        dispatch_validation["run"]["id"]
      ] ++ negative_ids

    require!(length(ids) == MapSet.size(MapSet.new(ids)), "all run IDs distinct")
  end

  defp validate_validation_route!(value, route, event, jobs, sha) do
    exact!(value, ~w(route run selected_jobs), "validation route")
    require!(value["route"] == route, "validation route order")
    validate_run!(value["run"], event, "validation #{route}")
    require!(value["run"]["head_sha"] == sha, "validation SHA")

    require!(
      is_list(value["selected_jobs"]) && Enum.map(value["selected_jobs"], & &1["name"]) == jobs,
      "validation job names"
    )

    Enum.each(Enum.zip(value["selected_jobs"], jobs), fn {job, name} ->
      validate_job!(job, name, "validation job")
    end)
  end

  defp validate_run!(value, event, label) do
    exact!(value, ~w(id url event attempt head_sha conclusion), "#{label} run")
    positive_int!(value["id"], "#{label} run ID")

    require!(
      value["url"] == "https://github.com/szTheory/sigra/actions/runs/#{value["id"]}",
      "#{label} URL"
    )

    require!(
      value["event"] == event && value["attempt"] == 1 && value["conclusion"] == "success",
      "#{label} result"
    )

    digest!(value["head_sha"], 40, "#{label} SHA")
  end

  defp validate_job!(value, name, label) do
    exact!(value, ~w(id name status conclusion skipped), label)
    positive_int!(value["id"], "#{label} ID")

    require!(
      value["name"] == name && value["status"] == "completed" && value["conclusion"] == "success" &&
        value["skipped"] == false,
      "#{label} result"
    )
  end

  defp validate_artifacts!(values, count, label) do
    require!(is_list(values) && length(values) == count, "#{label} artifact cardinality")

    Enum.each(values, fn value ->
      exact!(value, ~w(id name file sha256), "#{label} artifact")
      positive_int!(value["id"], "#{label} artifact ID")
      require!(is_binary(value["name"]) && is_binary(value["file"]), "#{label} artifact identity")
      digest!(value["sha256"], 64, "#{label} artifact digest")
    end)

    ids = Enum.map(values, & &1["id"])
    require!(length(ids) == MapSet.size(MapSet.new(ids)), "#{label} artifact IDs distinct")
  end

  defp validate_negative!(values) do
    require!(is_list(values) && length(values) == 10, "ten-run ledger")
    require!(Enum.map(values, & &1["id"]) == @negative_ids, "ten-run ledger IDs")
  end

  defp pre_document_fixture do
    %{
      ".planning/REQUIREMENTS.md" =>
        Enum.map_join(@complete_ids, "\n", &"| #{&1} | Phase | Gaps Found |"),
      ".planning/v1.47-MILESTONE-AUDIT.md" =>
        "status: gaps_found\nrequirements: 21/24\nintegration: 7/10\nflows: 5/6",
      ".planning/phases/235-terminal-ratification-measured-not-read/235-VERIFICATION.md" =>
        "status: passed\nscore: 11/11 must-haves verified\n**Status:** human_needed\n11/11 truths verified (0 present, behavior-unverified)\nflagged judgment-tier",
      ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION.md" =>
        "⬜ pending"
    }
  end

  defp post_document_fixture(facts) do
    body =
      ([
         "Complete",
         "passed",
         "11/11",
         "24/24",
         "10/10",
         "6/6",
         "Phase 234 route evolution",
         "FAST-01",
         "GATE-05",
         "469 seconds",
         "30782184713"
       ] ++ Enum.map(@complete_ids, &"#{&1}: Complete") ++ fact_tokens(facts))
      |> Enum.join("\n")

    %{"post.md" => body}
  end

  defp run(id, event, sha),
    do: %{
      "id" => id,
      "url" => "https://github.com/szTheory/sigra/actions/runs/#{id}",
      "event" => event,
      "attempt" => 1,
      "head_sha" => sha,
      "conclusion" => "success"
    }

  defp job(id, name),
    do: %{
      "id" => id,
      "name" => name,
      "status" => "completed",
      "conclusion" => "success",
      "skipped" => false
    }

  defp artifact(id, name, file, seed),
    do: %{"id" => id, "name" => name, "file" => file, "sha256" => hex(64, seed)}

  defp canonical(value), do: JSON.encode!(value) <> "\n"
  defp digest(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp hex(length, seed),
    do:
      seed
      |> Integer.to_string(16)
      |> String.downcase()
      |> String.pad_leading(length, "0")
      |> String.slice(-length, length)

  defp exact!(value, keys, label),
    do:
      require!(
        is_map(value) && MapSet.new(Map.keys(value)) == MapSet.new(keys),
        "#{label} exact keys"
      )

  defp exact_subset!(keys, allowed, label),
    do: require!(MapSet.subset?(MapSet.new(keys), allowed), "#{label} exact keys")

  defp positive_int!(value, label), do: require!(is_integer(value) && value > 0, label)

  defp positive_pair!(value, label),
    do:
      require!(
        is_list(value) && length(value) == 2 && Enum.all?(value, &(is_integer(&1) && &1 > 0)),
        label
      )

  defp digest!(value, length, label),
    do: require!(is_binary(value) && Regex.match?(~r/\A[0-9a-f]{#{length}}\z/, value), label)

  defp require!(true, _message), do: :ok
  defp require!(false, message), do: raise(ArgumentError, message)

  defp refute_tokens!(bytes, tokens),
    do: Enum.each(tokens, &require!(not (bytes =~ &1), "forbidden document token #{&1}"))
end
