defmodule Mix.Tasks.Sigra.DoctorTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Sigra.Doctor

  setup do
    previous_halt = Application.get_env(:sigra, :doctor_halt)

    Application.put_env(:sigra, :doctor_halt, fn status ->
      throw({:doctor_halt, status})
    end)

    Mix.Task.reenable("sigra.doctor")

    on_exit(fn ->
      if is_nil(previous_halt) do
        Application.delete_env(:sigra, :doctor_halt)
      else
        Application.put_env(:sigra, :doctor_halt, previous_halt)
      end
    end)

    :ok
  end

  test "prints enforced and advisory rows with host evidence" do
    stderr =
      capture_io(:stderr, fn ->
        stdout =
          capture_io(fn ->
            assert catch_throw(
                     Doctor.run([
                       "--jwt-enabled",
                       "--oauth-enabled",
                       "--rate-limit=hammer",
                       "--mailer=swoosh",
                       "--missing=joken",
                       "--missing=assent",
                       "--missing=hammer"
                     ])
                   ) == {:doctor_halt, 2}
          end)

        send(self(), {:doctor_stdout, stdout})
      end)

    assert_received {:doctor_stdout, stdout}
    output = stdout <> stderr

    assert output =~ "==> sigra.doctor: 7 optional dependency row(s)"
    assert output =~ "FAIL enforced jwt -> joken"
    assert output =~ "because jwt[:enabled] == true"
    assert output =~ "INFO advisory oauth -> assent"
    assert output =~ "because OAuth providers are configured"
    assert output =~ "INFO advisory rate_limit -> hammer"
    assert output =~ "because rate limiting explicitly configured with Sigra.RateLimiters.Hammer"
    assert output =~ "OK advisory swoosh -> swoosh"
    assert output =~ "because Swoosh-backed delivery is configured"
    assert output =~ "FAIL: 1 enforced optional dependency row(s) are currently invalid."
  end

  test "halts with status 2 only when an enabled enforced feature is missing" do
    assert catch_throw(Doctor.run(["--jwt-enabled", "--missing=joken"])) == {:doctor_halt, 2}
  end

  test "does not halt for inactive enforced rows or advisory rows" do
    output =
      capture_io(fn ->
        Doctor.run([
          "--missing=joken",
          "--oauth-enabled",
          "--missing=assent"
        ])
      end)

    assert output =~ "INFO enforced jwt -> joken"
    assert output =~ "because jwt[:enabled] != true"
    assert output =~ "INFO advisory oauth -> assent"
    assert output =~ "OK: all enforced optional dependency rows are currently valid."
  end
end
