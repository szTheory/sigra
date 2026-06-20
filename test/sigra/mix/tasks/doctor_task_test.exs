defmodule Mix.Tasks.Sigra.DoctorTest do
  use ExUnit.Case
  @moduletag :threadline_guard

  import ExUnit.CaptureIO

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # All predicates false, no config — the minimal-install baseline (dep-off).
  defp dep_off_opts do
    [
      predicates: %{
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
      },
      host_sigra: []
    ]
  end

  # Options that produce a :fail verdict (async email without Oban supervised).
  defp misconfig_opts do
    [
      predicates: %{
        oban: false,
        bcrypt: false,
        eqrcode: false,
        threadline: false,
        assent: false,
        swoosh: true,
        joken: false,
        hammer: false,
        req: false,
        encryption_active: false
      },
      host_sigra: [email: [delivery_mode: :async]],
      oban_running: false
    ]
  end

  # ---------------------------------------------------------------------------
  # Test 1: smoke — ok verdict, no exit exception
  # ---------------------------------------------------------------------------

  test "smoke: dep-off run produces non-empty output and does not exit" do
    output =
      capture_io(fn ->
        Mix.Tasks.Sigra.Doctor.run_with_opts(dep_off_opts())
      end)

    assert output != ""

    # Verify at least one state label is present
    assert output =~ "missing" or output =~ "available" or output =~ "loaded"
  end

  # ---------------------------------------------------------------------------
  # Test 2: output contains all nine feature names
  # ---------------------------------------------------------------------------

  test "output from run_with_opts/1 includes all nine feature names" do
    output =
      capture_io(fn ->
        Mix.Tasks.Sigra.Doctor.run_with_opts(dep_off_opts())
      end)

    # The nine D-05 features — check for the labels used in output formatting
    assert output =~ "totp"
    assert output =~ "password"
    assert output =~ "oauth"
    assert output =~ "rate"
    assert output =~ "jwt"
    assert output =~ "email"
    assert output =~ "audit"
    assert output =~ "encryption"
    assert output =~ "enterprise"
  end

  # ---------------------------------------------------------------------------
  # Test 3: shortdoc visible
  # ---------------------------------------------------------------------------

  test "Mix.Tasks.Sigra.Doctor has a non-empty @shortdoc" do
    # @shortdoc is stored as @moduledoc by the Mix.Task machinery
    # but accessible via Mix.Task.shortdoc/1
    shortdoc = Mix.Task.shortdoc(Mix.Tasks.Sigra.Doctor)
    assert is_binary(shortdoc)
    assert String.length(shortdoc) > 0
  end

  # ---------------------------------------------------------------------------
  # Test 4: --quiet flag parses without error; hints suppressed but verdict appears
  # ---------------------------------------------------------------------------

  test "--quiet flag parses without error and verdict still appears" do
    output =
      capture_io(fn ->
        Mix.Tasks.Sigra.Doctor.run_with_opts(dep_off_opts() ++ [quiet: true])
      end)

    # Verdict line must still appear even when --quiet
    assert output =~ "OK"
  end

  # ---------------------------------------------------------------------------
  # Test 5: bad flag raises Mix.Error
  # ---------------------------------------------------------------------------

  test "unknown flag raises Mix.Error" do
    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Sigra.Doctor.run(["--not-a-real-flag"])
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Test 6: misconfig exit — exit({:shutdown, 1}) is catchable
  # ---------------------------------------------------------------------------

  test "misconfig opts produce exit({:shutdown, 1}) on :fail verdict" do
    assert catch_exit(
             capture_io(:stderr, fn ->
               capture_io(fn ->
                 Mix.Tasks.Sigra.Doctor.run_with_opts(misconfig_opts())
               end)
             end)
           ) == {:shutdown, 1}
  end

  # ---------------------------------------------------------------------------
  # Test 7: full report before exit — output non-empty when :fail exits
  # ---------------------------------------------------------------------------

  test "on :fail verdict, output is non-empty before exit({:shutdown, 1}) is called" do
    stdout = capture_io(fn ->
      catch_exit(
        capture_io(:stderr, fn ->
          Mix.Tasks.Sigra.Doctor.run_with_opts(misconfig_opts())
        end)
      )
    end)

    assert stdout != "", "expected non-empty stdout output before the exit call"
  end

end
