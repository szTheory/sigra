defmodule Sigra.DoctorTest do
  use ExUnit.Case, async: true

  alias Sigra.Doctor

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # All predicates false, no config — the minimal-install baseline.
  defp all_false_predicates do
    %{
      oban: false,
      bcrypt: false,
      eqrcode: false,
      threadline: false,
      assent: false,
      swoosh: false,
      joken: false,
      hammer: false,
      req: false,
      encryption_active: false
    }
  end

  defp find_row(rows, feature) do
    Enum.find(rows, fn r -> r.feature == feature end)
  end

  # ---------------------------------------------------------------------------
  # Test 1: missing state — all predicates false, empty config → nine rows, all
  # :missing, verdict :ok.
  # ---------------------------------------------------------------------------

  test "all predicates false, empty host_sigra produces nine :missing rows with verdict :ok" do
    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: [])

    assert result.verdict == :ok
    assert length(result.rows) == 9
    assert Enum.all?(result.rows, fn r -> r.state == :missing end)
  end

  # ---------------------------------------------------------------------------
  # Test 2: available state — assent true, no providers configured → :available.
  # ---------------------------------------------------------------------------

  test "assent predicate true, no oauth providers configured → oauth row :available, verdict :ok" do
    predicates = %{all_false_predicates() | assent: true}
    result = Doctor.diagnose(predicates: predicates, host_sigra: [])

    oauth = find_row(result.rows, :oauth)
    assert oauth.state == :available
    assert result.verdict == :ok
  end

  # ---------------------------------------------------------------------------
  # Test 3: loaded_active state — assent true, providers configured, no forwarder.
  # ---------------------------------------------------------------------------

  test "assent true, oauth providers configured → oauth row :loaded_active, verdict :ok" do
    predicates = %{all_false_predicates() | assent: true}

    host_sigra = [
      oauth: [providers: [google: [client_id: "x", client_secret: "y"]]]
    ]

    result = Doctor.diagnose(predicates: predicates, host_sigra: host_sigra)

    oauth = find_row(result.rows, :oauth)
    assert oauth.state == :loaded_active
    assert result.verdict == :ok
  end

  # ---------------------------------------------------------------------------
  # Test 4: configured_but_missing (non-hard-fail) — assent false, providers
  # configured → :configured_but_missing, verdict :ok (dep-absent on configured
  # feature is NOT a D-09 hard-fail).
  # ---------------------------------------------------------------------------

  test "assent false, oauth providers configured → configured_but_missing, verdict :ok" do
    host_sigra = [
      oauth: [providers: [google: [client_id: "x", client_secret: "y"]]]
    ]

    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: host_sigra)

    oauth = find_row(result.rows, :oauth)
    assert oauth.state == :configured_but_missing
    assert result.verdict == :ok
  end

  # ---------------------------------------------------------------------------
  # Test 5: D-09 hard-fail #1 — async forwarder, Oban not supervised.
  # ---------------------------------------------------------------------------

  test "audit forwarder configured dispatch :async, oban not running → verdict :fail, audit_forwarding :configured_but_missing" do
    predicates = %{all_false_predicates() | threadline: true, oban: true}

    # Use a known-loaded module (Sigra.Doctor itself) so the module-loaded check passes;
    # only the Oban supervision check should trigger the fail.
    host_sigra = [
      audit: [
        forwarders: [
          [module: Sigra.Doctor, dispatch: :async]
        ]
      ]
    ]

    # oban_running: false overrides the supervision check
    result = Doctor.diagnose(
      predicates: predicates,
      host_sigra: host_sigra,
      oban_running: false
    )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # ---------------------------------------------------------------------------
  # Test 6: D-09 hard-fail #2 — async email, Oban not supervised.
  # ---------------------------------------------------------------------------

  test "email delivery_mode :async, oban not running → verdict :fail, async_email :configured_but_missing" do
    predicates = %{all_false_predicates() | swoosh: true, oban: true}

    host_sigra = [
      email: [delivery_mode: :async]
    ]

    result = Doctor.diagnose(
      predicates: predicates,
      host_sigra: host_sigra,
      oban_running: false
    )

    async_email = find_row(result.rows, :async_email)
    assert async_email.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # ---------------------------------------------------------------------------
  # Test 7: D-09 hard-fail #3 — encryption stub, passkeys enabled.
  # ---------------------------------------------------------------------------

  test "passkeys enabled, encryption_active false → verdict :fail, encryption :configured_but_missing" do
    predicates = %{all_false_predicates() | encryption_active: false}

    host_sigra = [
      passkeys: [enabled: true]
    ]

    result = Doctor.diagnose(predicates: predicates, host_sigra: host_sigra)

    encryption = find_row(result.rows, :encryption)
    assert encryption.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # ---------------------------------------------------------------------------
  # Test 8: D-09 hard-fail #4 — forwarder module not loaded.
  # ---------------------------------------------------------------------------

  test "configured forwarder module not loaded → verdict :fail, audit_forwarding :configured_but_missing" do
    predicates = %{all_false_predicates() | threadline: true, oban: true}

    host_sigra = [
      audit: [
        forwarders: [
          [module: VeryDefinitelyNotALoadedModule12345, dispatch: :sync]
        ]
      ]
    ]

    result = Doctor.diagnose(
      predicates: predicates,
      host_sigra: host_sigra,
      oban_running: true
    )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # ---------------------------------------------------------------------------
  # Test 9: dep-off CI-gate-green invariant — all false, no config → :ok.
  # ---------------------------------------------------------------------------

  test "dep-off CI-gate-green: all predicates false, empty config → verdict :ok" do
    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: [])
    assert result.verdict == :ok
  end

  # ---------------------------------------------------------------------------
  # Test 10: all nine feature rows present.
  # ---------------------------------------------------------------------------

  test "result has exactly 9 rows covering all D-05 features" do
    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: [])

    expected_features = MapSet.new([
      :totp_mfa,
      :password_migration,
      :oauth,
      :rate_limiting,
      :jwt,
      :async_email,
      :audit_forwarding,
      :encryption,
      :enterprise_connections
    ])

    actual_features = result.rows |> Enum.map(& &1.feature) |> MapSet.new()

    assert actual_features == expected_features
    assert length(result.rows) == 9
  end

  # ---------------------------------------------------------------------------
  # Test 11: hint populated for every row.
  # ---------------------------------------------------------------------------

  test "every row has a non-empty hint string" do
    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: [])

    Enum.each(result.rows, fn row ->
      assert is_binary(row.hint), "hint for #{row.feature} should be a binary"
      assert String.length(row.hint) > 0, "hint for #{row.feature} should not be empty"
    end)
  end

  # ---------------------------------------------------------------------------
  # Test 12: conjunction — async_email, both swoosh and oban false → :missing.
  # ---------------------------------------------------------------------------

  test "async_email: swoosh false, oban false, no config → state :missing" do
    predicates = %{all_false_predicates() | swoosh: false, oban: false}
    result = Doctor.diagnose(predicates: predicates, host_sigra: [])

    row = find_row(result.rows, :async_email)
    assert row.state == :missing
  end

  # ---------------------------------------------------------------------------
  # Test 13: conjunction — async_email, swoosh true, oban false → :available.
  # ---------------------------------------------------------------------------

  test "async_email: swoosh true, oban false, no config → state :available (partial dep present)" do
    predicates = %{all_false_predicates() | swoosh: true, oban: false}
    result = Doctor.diagnose(predicates: predicates, host_sigra: [])

    row = find_row(result.rows, :async_email)
    assert row.state == :available
  end

  # ---------------------------------------------------------------------------
  # Extra: verify :deps key present on each row.
  # ---------------------------------------------------------------------------

  test "every row has a :deps key with a list" do
    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: [])

    Enum.each(result.rows, fn row ->
      assert is_list(row.deps), "deps for #{row.feature} should be a list"
    end)
  end

  # ---------------------------------------------------------------------------
  # Extra: run/1 returns the same structured map as diagnose/1.
  # ---------------------------------------------------------------------------

  test "run/1 returns same structured map as diagnose/1" do
    opts = [predicates: all_false_predicates(), host_sigra: []]
    diagnose_result = Doctor.diagnose(opts)
    run_result = Doctor.run(opts)

    assert run_result.verdict == diagnose_result.verdict
    assert length(run_result.rows) == length(diagnose_result.rows)
    assert is_list(run_result.wiring)
  end
end
