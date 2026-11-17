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

  defp doctor_output_with_css(css_contents) do
    css_path =
      Path.join(
        System.tmp_dir!(),
        "sigra-doctor-css-#{System.unique_integer([:positive])}.css"
      )

    if css_contents, do: File.write!(css_path, css_contents)
    on_exit(fn -> File.rm(css_path) end)

    stdout =
      capture_io(fn ->
        stderr =
          capture_io(:stderr, fn ->
            Mix.Tasks.Sigra.Doctor.run_with_opts(dep_off_opts() ++ [admin_css_path: css_path])
          end)

        send(self(), {:doctor_stderr, stderr})
      end)

    stderr =
      receive do
        {:doctor_stderr, captured} -> captured
      after
        0 -> ""
      end

    {stdout, stderr}
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
    stdout =
      capture_io(fn ->
        catch_exit(
          capture_io(:stderr, fn ->
            Mix.Tasks.Sigra.Doctor.run_with_opts(misconfig_opts())
          end)
        )
      end)

    assert stdout != "", "expected non-empty stdout output before the exit call"
  end

  test "current and newer generated CSS contracts do not warn" do
    for level <- [2, 3] do
      {stdout, stderr} = doctor_output_with_css("/* sigra-admin-css: #{level} */\n")

      assert stdout =~ "OK: all configured features are properly wired."
      refute stderr =~ "WARNING: generated admin CSS"
    end
  end

  test "older generated CSS warns without changing the doctor verdict" do
    {stdout, stderr} = doctor_output_with_css("/* sigra-admin-css: 1 */\n")

    assert stderr =~ "WARNING: generated admin CSS is stale"
    assert stderr =~ "contract level 1"
    assert stdout =~ "OK: all configured features are properly wired."
  end

  test "missing and malformed generated CSS stamps warn without changing the doctor verdict" do
    {missing_stdout, missing_stderr} = doctor_output_with_css(nil)
    {malformed_stdout, malformed_stderr} = doctor_output_with_css("/* sigra-admin-css: x */\n")

    assert missing_stderr =~
             "WARNING: generated admin CSS is missing or has no valid contract stamp"

    assert malformed_stderr =~
             "WARNING: generated admin CSS has a missing or malformed contract stamp"

    assert missing_stdout =~ "OK: all configured features are properly wired."
    assert malformed_stdout =~ "OK: all configured features are properly wired."
  end

  test "the pure doctor result keeps its existing shape" do
    result = Sigra.Doctor.run(dep_off_opts())

    assert Map.keys(result) |> Enum.sort() == [:rows, :verdict, :wiring]
    assert result.verdict == :ok
  end
end
