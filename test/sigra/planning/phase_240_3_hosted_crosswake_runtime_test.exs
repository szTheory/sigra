defmodule Sigra.Planning.Phase2403HostedCrosswakeRuntimeTest do
  use ExUnit.Case, async: true

  @coverage ".planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/COVERAGE.md"
  @recipe "guides/recipes/b2c-alpha.md"
  @runner "scripts/ci/hosted-session-interop-proof.sh"
  @worktree_helper "scripts/ci/lib/exact-sha-worktree.sh"
  @evidence ".planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/240.3-HOSTED-RUNTIME-EVIDENCE.json"
  @release ".planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json"
  @root_mix "mix.exs"
  @example_mix "test/example/mix.exs"
  @migration "test/example/priv/repo/migrations/20260811170000_create_crosswake_continuations.exs"
  @continuation "test/example/lib/example/accounts/crosswake_continuation.ex"
  @continuations "test/example/lib/example/accounts/crosswake_continuations.ex"
  @adapter "test/example/lib/example/accounts/crosswake_session_adapter.ex"
  @controller "test/example/lib/example_web/controllers/crosswake_controller.ex"
  @router "test/example/lib/example_web/router.ex"
  @continuation_test "test/example/test/example/accounts/crosswake_continuations_test.exs"
  @controller_test "test/example/test/example_web/controllers/crosswake_controller_test.exs"
  @app_live "test/example/lib/example_web/live/app_live.ex"
  @browser_test "test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts"
  @playwright_config "test/example/priv/playwright/playwright.config.ts"
  @prohibition_guard "scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs"
  @prohibition_bad_fixture "test/fixtures/prohibitions/p14-crosswake-authority-secrets-bad.json"
  @prohibition_clean_fixture "test/fixtures/prohibitions/p14-crosswake-authority-secrets-clean.json"
  @plan ".planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/240.3-09-PLAN.md"
  @prohibition_command "node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs && ! GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p14-crosswake-authority-secrets-bad.json node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs && GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p14-crosswake-authority-secrets-clean.json node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs"

  @ordered_commands [
    "cd test/example && MIX_ENV=test mix ecto.migrate --quiet",
    "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs",
    "cd test/example && mix test test/example/accounts/crosswake_continuations_test.exs",
    "cd test/example && mix test test/example_web/controllers/crosswake_controller_test.exs --include example_app",
    "scripts/ci/hosted-session-interop-proof.sh --browser-only",
    @prohibition_command,
    "MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs"
  ]

  @main_ordered_markers [
    "run_bounded \"apply example test schema\"",
    "run_bounded \"validate immutable Crosswake release proof\"",
    "run_bounded \"complete database-backed adapter suite\"",
    "run_bounded \"continuation security suite\"",
    "run_bounded \"controller security suite\"",
    "run_bounded \"browser cookie-jar proof\"",
    "run_bounded \"Crosswake prohibition real/bad/clean enforcement\"",
    "run_bounded \"phase 240.3 recipe/source contract\""
  ]

  defp read!(path), do: File.read!(path)
  defp decode!(path), do: path |> read!() |> Jason.decode!()
  defp index!(source, marker), do: source |> :binary.match(marker) |> elem(0)

  defp with_disposable_repository(fun) do
    root = Path.join(System.tmp_dir!(), "sigra-phase-240-3-#{System.unique_integer([:positive])}")
    evidence = @evidence

    try do
      File.mkdir_p!(Path.dirname(Path.join(root, evidence)))
      File.write!(Path.join(root, "runtime.txt"), "clean\n")
      File.write!(Path.join(root, evidence), "receipt\n")

      for {command, args} <- [
            {"git", ["init", "--quiet", root]},
            {"git", ["-C", root, "config", "user.email", "phase2403@example.test"]},
            {"git", ["-C", root, "config", "user.name", "Phase 240.3"]},
            {"git", ["-C", root, "add", "runtime.txt", evidence]},
            {"git", ["-C", root, "commit", "--quiet", "-m", "fixture"]}
          ] do
        {_, 0} = System.cmd(command, args, stderr_to_stdout: true)
      end

      fun.(root, evidence)
    after
      File.rm_rf(root)
    end
  end

  defp helper_command(function, root, evidence, expected_sha \\ nil) do
    args =
      [
        "-c",
        "source \"$1\"; #{function} \"$2\" \"$3\"${4:+ \"$4\"}",
        "bash",
        @worktree_helper,
        root,
        evidence
      ] ++ if(expected_sha, do: [expected_sha], else: [])

    System.cmd("bash", args, stderr_to_stdout: true)
  end

  test "exact SHA worktree guard accepts only a clean tree plus the one receipt path" do
    with_disposable_repository(fn root, evidence ->
      {head, 0} = System.cmd("git", ["-C", root, "rev-parse", "HEAD"], stderr_to_stdout: true)
      sha = String.trim(head)

      {output, 0} = helper_command("bind_clean_worktree_sha", root, evidence)
      assert String.trim(output) == sha

      File.write!(Path.join(root, "runtime.txt"), "unstaged\n")
      {_, status} = helper_command("bind_clean_worktree_sha", root, evidence)
      assert status != 0

      {_, 0} = System.cmd("git", ["-C", root, "add", "runtime.txt"], stderr_to_stdout: true)
      {_, status} = helper_command("bind_clean_worktree_sha", root, evidence)
      assert status != 0

      {_, 0} =
        System.cmd("git", ["-C", root, "restore", "--staged", "runtime.txt"],
          stderr_to_stdout: true
        )

      {_, 0} = System.cmd("git", ["-C", root, "restore", "runtime.txt"], stderr_to_stdout: true)
      File.write!(Path.join(root, "untracked.txt"), "dirty\n")
      {_, status} = helper_command("bind_clean_worktree_sha", root, evidence)
      assert status != 0
      File.rm!(Path.join(root, "untracked.txt"))

      File.write!(Path.join(root, evidence), "rewritten receipt\n")
      {_, 0} = helper_command("bind_clean_worktree_sha", root, evidence)
      {_, 0} = helper_command("assert_same_clean_worktree_sha", root, evidence, sha)

      File.write!(Path.join(root, evidence <> ".bak"), "lookalike\n")
      {_, status} = helper_command("bind_clean_worktree_sha", root, evidence)
      assert status != 0
      File.rm!(Path.join(root, evidence <> ".bak"))

      {_, 0} = System.cmd("git", ["-C", root, "restore", evidence], stderr_to_stdout: true)

      {_, 0} =
        System.cmd("git", ["-C", root, "rm", "--cached", "--quiet", evidence],
          stderr_to_stdout: true
        )

      File.rm!(Path.join(root, evidence))

      {_, 0} =
        System.cmd("git", ["-C", root, "commit", "--quiet", "-m", "remove receipt fixture"],
          stderr_to_stdout: true
        )

      File.write!(Path.join(root, evidence), "new receipt\n")
      {_, 0} = helper_command("bind_clean_worktree_sha", root, evidence)

      {_, status} = helper_command("assert_same_clean_worktree_sha", root, evidence, sha)
      assert status != 0
    end)
  end

  test "runtime paths, route ownership, and released AuthReturn boundary stay host-owned" do
    for path <- [
          @migration,
          @continuation,
          @continuations,
          @controller,
          @router,
          @continuation_test,
          @controller_test,
          @browser_test,
          @playwright_config
        ] do
      assert File.regular?(path), "missing runtime artifact #{path}"
    end

    migration = read!(@migration)
    continuation = read!(@continuation)
    continuations = read!(@continuations)
    adapter = read!(@adapter)
    controller = read!(@controller)
    router = read!(@router)

    assert migration =~ "create table(:crosswake_continuations,"
    assert continuation =~ "schema \"crosswake_continuations\""

    for marker <- [
          "def issue(",
          "def complete(",
          "def cleanup_expired(",
          "AuthReturn.new_envelope(%{",
          "@route_id \"crosswake-hosted-account\"",
          "@return_route_id \"crosswake-hosted-return\""
        ] do
      assert continuations =~ marker, "continuation context is missing #{inspect(marker)}"
    end

    assert adapter =~ "org_id: nil"

    assert controller =~ "redirect(to: \"/crosswake/return?\" <> URI.encode_query(query))"
    assert controller =~ "redirect(to: CrosswakeContinuations.destination())"
    assert continuations =~ "@destination \"/app\""
    assert continuations =~ "def destination, do: @destination"
    assert router =~ "get \"/crosswake/return\", CrosswakeController, :return"
    assert router =~ "post \"/crosswake/start\", CrosswakeController, :start"
  end

  test "continuation, controller, browser, and serial project guards name the real security matrix" do
    continuation_test = read!(@continuation_test)
    controller_test = read!(@controller_test)
    app_live = read!(@app_live)
    browser_test = read!(@browser_test)
    playwright_config = read!(@playwright_config)

    for marker <- [
          "local AuthReturn rejects missing or mismatched state and PKCE before evaluation",
          "claims strictly before expiry, denies at equality, and consumes every terminal result",
          "refute_receive :crosswake_evaluator_called"
        ] do
      assert continuation_test =~ marker, "continuation test is missing #{inspect(marker)}"
    end

    for marker <- [
          "crosswake_runtime_tracer: local AuthReturn state and PKCE correlation permits one same-session return",
          "local AuthReturn rejects missing or mismatched state and PKCE before evaluation",
          "local AuthReturn ignores or rejects smuggled authority route and destination fields",
          "refute_receive {:crosswake_evaluator_called, _, _, _}"
        ] do
      assert controller_test =~ marker, "controller test is missing #{inspect(marker)}"
    end

    for marker <- [
          "data-testid=\"app-crosswake-start\"",
          "action={~p\"/crosswake/start\"}",
          "method=\"post\"",
          "class=\"vt-panel\"",
          "class=\"vt-kicker\"",
          "class=\"vt-panel__title\"",
          "class=\"vt-copy\"",
          "class=\"vt-btn vt-btn--primary\"",
          "type=\"submit\"",
          "Continue to Crosswake"
        ] do
      assert app_live =~ marker, "app account hub is missing #{inspect(marker)}"
    end

    refute Regex.match?(~r/phx-(?:submit|click|change)\s*=/, app_live),
           "Crosswake start must remain an ordinary controller POST"

    assert browser_test =~ "hosted Crosswake local return preserves the real cookie jar"
    assert browser_test =~ "page.waitForRequest"
    assert browser_test =~ "page.getByRole('button', { name: 'Continue to Crosswake' }).click()"

    assert browser_test =~
             "expect([...returnUrl.searchParams.keys()].sort()).toEqual(['continuation', 'state']);"

    assert browser_test =~ "expect(appNavigation.headers()['referer']).toBeUndefined();"
    assert browser_test =~ "await expect(page).toHaveURL(/\\/app$/);"
    assert browser_test =~ "pkce_verifier"
    refute browser_test =~ "page.evaluate"
    refute browser_test =~ "document.createElement"
    assert playwright_config =~ "name: 'crosswake-hosted-runtime'"
    assert playwright_config =~ "workers: 1"
    assert playwright_config =~ "retries: 0"
  end

  test "XW prohibition enforcement remains wired to its fail-first guard and fixtures" do
    for path <- [@prohibition_guard, @prohibition_bad_fixture, @prohibition_clean_fixture] do
      assert File.regular?(path), "missing prohibition enforcement artifact #{path}"
    end

    plan = read!(@plan)

    for marker <- [
          "check_kind: node-test",
          "check_target: scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs",
          "check_violation_fixture: test/fixtures/prohibitions/p14-crosswake-authority-secrets-bad.json",
          "check_clean_fixture: test/fixtures/prohibitions/p14-crosswake-authority-secrets-clean.json",
          "authority-integrity",
          "secret-boundary",
          "authority-smuggling"
        ] do
      assert plan =~ marker, "plan is missing prohibition descriptor #{inspect(marker)}"
    end

    guard = read!(@prohibition_guard)
    assert guard =~ "GSD_PROHIB_SUBJECT"
    assert guard =~ "authority-integrity"
    assert guard =~ "secret-boundary"
    assert guard =~ "authority-smuggling"
  end

  test "recipe and coverage preserve the exact host and no-external-API contract" do
    recipe = read!(@recipe)
    coverage = read!(@coverage)

    for marker <- [
          "Copyable example-host start and return",
          "example-host composition",
          "already-present in-process `crosswake_sigra` dependency",
          "POST /crosswake/start",
          "digest",
          "host-generated state and PKCE return transport",
          "released `AuthReturn` envelope",
          "fixed `GET /crosswake/return` route",
          "fixed `303 /app` navigation",
          "real Google authorization",
          "Crosswake network service",
          "iPhone/native launch behavior",
          "not a new\nSigra public abstraction, generated integration, or external API/service"
        ] do
      assert recipe =~ marker, "recipe is missing #{inspect(marker)}"
    end

    assert coverage =~ "No external API integration:"
    assert coverage =~ "crosswake_sigra` package only"
    assert coverage =~ "Re-run trigger:"

    assert coverage =~
             "Crosswake network endpoint, SDK client, webhook, hosted API, remote authentication"
  end

  test "scope remains an example host with no root dependency, public abstraction, or generator" do
    root_mix = read!(@root_mix)
    example_mix = read!(@example_mix)
    runtime_sources = Enum.map([@continuation, @continuations, @controller, @router], &read!/1)

    refute root_mix =~ "crosswake_sigra"
    assert example_mix =~ "{:crosswake_sigra, \"~> 0.1.3\""

    for source <- runtime_sources do
      refute Regex.match?(~r/defmodule Sigra\.(?:Crosswake|HostedCrosswake)/, source)
      refute source =~ "mix sigra.gen.crosswake"
      refute source =~ "http://"
      refute source =~ "https://"
    end
  end

  test "runner is schema-first, ordered, receipt-last, and fail-closed" do
    runner = read!(@runner)
    main_runner = runner |> String.split("main() {", parts: 2) |> List.last()

    for marker <- [
          "set -euo pipefail",
          "apply example test schema",
          "validate immutable Crosswake release proof",
          "continuation security suite",
          "controller security suite",
          "browser cookie-jar proof",
          "Crosswake prohibition real/bad/clean enforcement",
          "phase 240.3 recipe/source contract",
          "bind_clean_worktree_sha",
          "assert_same_clean_worktree_sha",
          "write_evidence",
          "sigra.phase240_3.hosted-crosswake-runtime-evidence.v1"
        ] do
      assert runner =~ marker, "runner is missing #{inspect(marker)}"
    end

    assert runner =~ "PY\n}\n"
    assert runner =~ "Path(os.environ[\"EVIDENCE_PATH\"]).write_text"
    assert runner =~ "SIGRA_SHA=\"${TESTED_SIGRA_SHA}\""
    refute runner =~ "verify_scoped_paths_are_committed()"
    refute runner =~ "sigra_sha=\"$(git -C \"${ROOT_DIR}\" rev-parse HEAD)\""

    positions = Enum.map(@main_ordered_markers, &index!(main_runner, &1))
    assert positions == Enum.sort(positions), "runner commands are not ordered"

    assert index!(main_runner, "TESTED_SIGRA_SHA=\"$(bind_clean_worktree_sha") <
             index!(main_runner, "run_bounded \"apply example test schema\"")

    assert index!(main_runner, "assert_same_clean_worktree_sha") <
             index!(main_runner, "write_evidence\n")

    assert index!(main_runner, "run_bounded \"browser cookie-jar proof\"") <
             index!(
               main_runner,
               "run_bounded \"Crosswake prohibition real/bad/clean enforcement\""
             )

    assert index!(main_runner, "run_bounded \"Crosswake prohibition real/bad/clean enforcement\"") <
             index!(main_runner, "run_bounded \"phase 240.3 recipe/source contract\"")

    assert runner =~ "node --test #{@prohibition_guard}"
    assert runner =~ "GSD_PROHIB_SUBJECT=#{@prohibition_bad_fixture}"
    assert runner =~ "GSD_PROHIB_SUBJECT=#{@prohibition_clean_fixture}"
    assert runner =~ "! GSD_PROHIB_SUBJECT=#{@prohibition_bad_fixture}"
    assert runner =~ "\"prohibitions\": ["
    refute runner =~ "flagged_unverified_prohibitions"

    refute Regex.match?(~r/\b(?:sleep|manual[ _-]?uat)\b/i, runner)
  end

  test "receipt keeps exact SHA, immutable coordinates, unresolved rows, and redacted allowlists" do
    assert File.regular?(@evidence), "missing hosted Crosswake runtime evidence: #{@evidence}"

    receipt = decode!(@evidence)
    release = decode!(@release)

    assert receipt["schema"] == "sigra.phase240_3.hosted-crosswake-runtime-evidence.v1"
    assert Regex.match?(~r/\A[0-9a-f]{40}\z/, receipt["sigra_git_sha"])

    assert receipt["crosswake_release"] ==
             Map.take(
               release,
               ~w(repository package version requirement git_tag git_sha hex_checksum)
             )

    expected_commands =
      if Map.has_key?(receipt, "prohibitions"),
        do: @ordered_commands,
        else: List.delete(@ordered_commands, @prohibition_command)

    assert Enum.map(receipt["local_commands"], & &1["command"]) == expected_commands

    assert Enum.all?(receipt["local_commands"], fn command ->
             command["exit_status"] == 0 and command["outcome"] == "passed"
           end)

    assert Enum.map(receipt["unresolved_assumptions"], & &1["requirement_id"]) == [
             "XW-01",
             "XW-02"
           ]

    if Map.has_key?(receipt, "prohibitions") do
      assert Enum.map(receipt["prohibitions"], & &1["category"]) == [
               "authority-integrity",
               "secret-boundary",
               "authority-smuggling"
             ]

      for prohibition <- receipt["prohibitions"] do
        assert prohibition["status"] == "resolved"
        assert prohibition["verification"] == "test"
        assert prohibition["check_kind"] == "node-test"
        assert prohibition["check_target"] == @prohibition_guard
        assert prohibition["check_violation_fixture"] == @prohibition_bad_fixture
        assert prohibition["check_clean_fixture"] == @prohibition_clean_fixture
        assert prohibition["repository_passed"] == true
        assert prohibition["fail_first_passed"] == true
        assert prohibition["clean_control_passed"] == true
      end

      refute Map.has_key?(receipt, "flagged_unverified_prohibitions")
    end

    assert receipt["api_detector"]["detected"] == false

    rendered = Jason.encode!(receipt)

    for forbidden <- ["token", "secret", "password", "credential", "session_ref", "subject_ref"] do
      refute rendered =~ "\"#{forbidden}\"", "receipt must not expose #{forbidden}"
    end
  end
end
