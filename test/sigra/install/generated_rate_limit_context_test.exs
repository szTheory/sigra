defmodule Sigra.Install.GeneratedRateLimitContextTest do
  use ExUnit.Case, async: true

  @core_feature "lib/sigra/install/features/core.ex"
  @auth_template "priv/templates/sigra.install/core/auth.ex"
  @sigra_auth "lib/sigra/auth.ex"
  @session_controller "priv/templates/sigra.install/core/session_controller.ex"
  @reset_password_live "priv/templates/sigra.install/core/reset_password_live.ex"

  defp read!(path), do: File.read!(path)

  defp assert_contains!(source, marker, context) do
    assert String.contains?(source, marker), "#{context} is missing #{inspect(marker)}"
  end

  test "every mutating generated controller boundary owns a distinct Hammer key" do
    core = read!(@core_feature)
    auth = read!(@auth_template)

    for prefix <- [
          "login",
          "sudo",
          "registration",
          "confirmation-request",
          "confirmation-resend",
          "reset-request",
          "reset-update",
          "mfa"
        ] do
      assert_contains!(
        core,
        inspect(prefix),
        "generated #{prefix} route limiter"
      )
    end

    for marker <- [
          "SigraAuth.request_magic_link(Repo, email,",
          "def deliver_user_reset_password_instructions(email, reset_password_url_fun)",
          "rate_limiter: Sigra.RateLimiters.Hammer",
          "max_requests: runtime_positive_integer(:magic_link_rate_limit, 3)",
          "window_ms: runtime_positive_integer(:magic_link_rate_limit_window, 60_000)",
          "max_requests: runtime_positive_integer(:reset_rate_limit, 3)",
          "window_ms: runtime_positive_integer(:reset_rate_limit_window, 60_000)"
        ] do
      assert_contains!(auth, marker, "generated mail-request limiter")
    end

    sigra_auth = read!(@sigra_auth)

    assert_contains!(sigra_auth, "magic_link:", "magic-link normalized email key contract")

    assert_contains!(
      sigra_auth,
      "sigra:reset:",
      "password-reset normalized email key contract"
    )
  end

  test "generated mail-request runtime overrides reject invalid values before Hammer" do
    auth = read!(@auth_template)

    assert Regex.match?(
             ~r/defp runtime_positive_integer\(key, default\) do\s+case Application\.get_env\(:sigra, key, default\) do\s+value when is_integer\(value\) and value > 0 -> value\s+_ -> default\s+end\s+end/s,
             auth
           ),
           "generated context must share a positive-integer fallback resolver"

    for {override, expected} <- [{0, 3}, {-1, 3}, {"3", 3}, {3, 3}] do
      assert generated_positive_integer(override, 3) == expected,
             "override #{inspect(override)} must resolve before Hammer is invoked"
    end

    for {override, expected} <- [{0, 60_000}, {-1, 60_000}, {"60000", 60_000}, {60_000, 60_000}] do
      assert generated_positive_integer(override, 60_000) == expected,
             "window override #{inspect(override)} must resolve before Hammer is invoked"
    end
  end

  defp generated_positive_integer(value, _default) when is_integer(value) and value > 0,
    do: value

  defp generated_positive_integer(_value, default), do: default

  test "exhaustion is deterministic and independent across route and context keys" do
    core = read!(@core_feature)
    auth = read!(@auth_template)
    sigra_auth = read!(@sigra_auth)

    for marker <- ["N-1/N/N+1", "login", "magic_link:", "sigra:reset:"] do
      assert String.contains?(core <> auth <> sigra_auth, marker),
             "generated limiter contract must preserve independent key material #{inspect(marker)}"
    end

    refute Regex.match?(~r/\bsleep\b|Process\.sleep|waitForTimeout/, core <> auth),
           "independence proof must not cross a limiter window"
  end

  test "mail-request outcomes remain generic when a context limit is reached" do
    session = read!(@session_controller)
    reset = read!(@reset_password_live)

    assert_contains!(
      session,
      "If your email is registered, you will receive a magic link shortly.",
      "magic-link generic outcome"
    )

    assert_contains!(
      reset,
      "If your email is in our system, you will receive reset instructions shortly.",
      "reset generic outcome"
    )

    refute String.contains?(session <> reset, "RateLimiters.Hammer"),
           "generated outward mail-request copy must not expose limiter implementation"
  end
end
