defmodule Sigra.DoctorTest do
  use ExUnit.Case, async: true
  @moduletag :threadline_guard

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
  # Test 4: configured_but_missing — assent false, providers configured →
  # :configured_but_missing, verdict :fail. Any configured feature missing its
  # required dependency is a failing first-run doctor contract.
  # ---------------------------------------------------------------------------

  test "assent false, oauth providers configured → configured_but_missing, verdict :fail" do
    host_sigra = [
      oauth: [providers: [google: [client_id: "x", client_secret: "y"]]]
    ]

    result = Doctor.diagnose(predicates: all_false_predicates(), host_sigra: host_sigra)

    oauth = find_row(result.rows, :oauth)
    assert oauth.state == :configured_but_missing
    assert result.verdict == :fail

    assert result.wiring == [
             "[oauth] OAuth providers are configured but Assent is missing. Add `{:assent, \"~> 0.3\"}` to mix.exs."
           ]
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
    result =
      Doctor.diagnose(
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

    result =
      Doctor.diagnose(
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

  test "passkeys enabled, user_schema configured, encryption_active false → verdict :fail, encryption :configured_but_missing" do
    predicates = %{all_false_predicates() | encryption_active: false}

    # user_schema must be set: encryption_configured? mirrors verify_vault!/1 which
    # short-circuits to :ok when no user_schema is present (no vault module to check).
    host_sigra = [
      user_schema: FakeApp.Accounts.User,
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

    result =
      Doctor.diagnose(
        predicates: predicates,
        host_sigra: host_sigra,
        oban_running: true
      )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # WR-02: oauth: [enabled: false] master switch suppresses oauth_configured?.

  test "oauth enabled: false master switch → oauth row :available (not :loaded_active), verdict :ok" do
    predicates = %{all_false_predicates() | assent: true}

    # OAuth intentionally disabled even though providers are configured.
    # Doctor should honor the master switch, not report oauth as active.
    host_sigra = [
      oauth: [enabled: false, providers: [google: [client_id: "x"]]]
    ]

    result = Doctor.diagnose(predicates: predicates, host_sigra: host_sigra)

    oauth = find_row(result.rows, :oauth)
    assert oauth.state == :available
    assert result.verdict == :ok
  end

  # WR-03: mfa: [enabled: false] master switch suppresses totp_configured?.

  test "mfa enabled: false master switch → totp_mfa row :available (not :loaded_active), verdict :ok" do
    predicates = %{all_false_predicates() | eqrcode: true}

    # MFA explicitly disabled even though non-empty mfa config is present.
    host_sigra = [
      mfa: [enabled: false, totp_drift_steps: 2]
    ]

    result = Doctor.diagnose(predicates: predicates, host_sigra: host_sigra)

    totp = find_row(result.rows, :totp_mfa)
    assert totp.state == :available
    assert result.verdict == :ok
  end

  # WR-04: malformed forwarder entry is flagged as misconfiguration without crashing.

  test "malformed forwarder entry (bare atom) produces hard-fail without crashing doctor" do
    predicates = %{all_false_predicates() | threadline: true, oban: true}

    # A bare atom (not a keyword list) as a forwarder entry is a misconfiguration.
    # Doctor must not crash with FunctionClauseError — it should flag the row as fail.
    host_sigra = [
      audit: [
        forwarders: [:bad_entry]
      ]
    ]

    result =
      Doctor.diagnose(
        predicates: predicates,
        host_sigra: host_sigra,
        oban_running: true
      )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :configured_but_missing
    assert result.verdict == :fail
  end

  # WR-06: module_loaded? injection seam — deterministic not-loaded check
  # without relying on a module name that happens not to be defined.

  test "module_loaded? injection seam: injected fn returns false → forwarder hard-fail fires deterministically" do
    predicates = %{all_false_predicates() | threadline: true, oban: true}

    # Use a module that IS loaded (Sigra.Doctor itself) so we know the test
    # is exercising the injected predicate, not the ambient runtime state.
    host_sigra = [
      audit: [
        forwarders: [
          [module: Sigra.Doctor, dispatch: :sync]
        ]
      ]
    ]

    # Inject a module_loaded? that always returns false — simulates any not-loaded module
    always_not_loaded = fn _module -> false end

    result =
      Doctor.diagnose(
        predicates: predicates,
        host_sigra: host_sigra,
        oban_running: true,
        module_loaded?: always_not_loaded
      )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :configured_but_missing
    assert result.verdict == :fail
  end

  test "module_loaded? injection seam: injected fn returns true → forwarder does not hard-fail (loaded + sync)" do
    predicates = %{all_false_predicates() | threadline: true, oban: true}

    host_sigra = [
      audit: [
        forwarders: [
          [module: Sigra.Doctor, dispatch: :sync]
        ]
      ]
    ]

    # Inject a module_loaded? that always returns true — simulates all modules loaded
    always_loaded = fn _module -> true end

    result =
      Doctor.diagnose(
        predicates: predicates,
        host_sigra: host_sigra,
        oban_running: true,
        module_loaded?: always_loaded
      )

    forwarding = find_row(result.rows, :audit_forwarding)
    assert forwarding.state == :loaded_active
    assert result.verdict == :ok
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

    expected_features =
      MapSet.new([
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

  # ---------------------------------------------------------------------------
  # WR-01 regression: absent :passkeys key defaults to enabled (mirrors Application)
  # ---------------------------------------------------------------------------

  test "absent :passkeys key in host_sigra → passkeys treated as enabled (matches Sigra.Application default)" do
    # host_sigra with no :passkeys key AND user_schema set → encryption_configured? true
    # encryption_active false → hard fail fires (same as verify_vault! behavior: passkeys
    # default-enabled when :passkeys absent, so vault must be real if user_schema is set).
    predicates = %{all_false_predicates() | encryption_active: false}

    host_sigra = [user_schema: FakeApp.Accounts.User]

    result = Doctor.diagnose(predicates: predicates, host_sigra: host_sigra)

    encryption = find_row(result.rows, :encryption)
    assert encryption.state == :configured_but_missing
    assert result.verdict == :fail
  end

  test "absent :passkeys key, no user_schema → encryption not required, verdict :ok (dep-off safe)" do
    # Without user_schema, verify_vault! short-circuits (no vault module to check).
    # Doctor must not over-report: passkeys default-enabled does not mean hard-fail
    # when there is no vault module at all.
    predicates = %{all_false_predicates() | encryption_active: false}

    result = Doctor.diagnose(predicates: predicates, host_sigra: [])

    encryption = find_row(result.rows, :encryption)
    assert encryption.state == :missing
    assert result.verdict == :ok
  end
end
