defmodule Sigra.OptionalDepsTest do
  use ExUnit.Case, async: true

  alias Sigra.OptionalDeps
  alias Sigra.OptionalDeps.MissingDependencyError

  describe "feature_specs/0" do
    test "returns staged metadata for enforced and advisory features" do
      specs = OptionalDeps.feature_specs()

      assert is_list(specs)

      features =
        specs
        |> Enum.map(& &1.feature)
        |> Enum.sort()

      assert [:async_email, :bcrypt_migration, :jwt, :oauth, :rate_limit, :swoosh, :totp_qr] =
               features

      assert %{dependency: :oban, enforced?: true, support_tier: :phase_95} =
               OptionalDeps.feature_spec!(:async_email)

      assert %{dependency: :joken, enforced?: true, support_tier: :phase_95} =
               OptionalDeps.feature_spec!(:jwt)

      assert %{dependency: :hammer, enforced?: false, support_tier: :advisory} =
               OptionalDeps.feature_spec!(:rate_limit)

      assert %{dependency: :assent, enforced?: false, support_tier: :advisory} =
               OptionalDeps.feature_spec!(:oauth)

      assert %{dependency: :swoosh, enforced?: false, support_tier: :advisory} =
               OptionalDeps.feature_spec!(:swoosh)
    end
  end

  describe "dependency_loaded?/1" do
    test "accepts a feature or a spec" do
      spec = OptionalDeps.feature_spec!(:jwt)

      assert OptionalDeps.dependency_loaded?(:jwt)
      assert OptionalDeps.dependency_loaded?(spec)
    end
  end

  describe "feature_enabled?/2" do
    test "proves jwt enablement from host config" do
      assert OptionalDeps.feature_enabled?(:jwt, config(jwt: [enabled: true]))
      refute OptionalDeps.feature_enabled?(:jwt, config(jwt: [enabled: false]))
    end

    test "proves async email enablement from runtime evidence" do
      assert OptionalDeps.feature_enabled?(:async_email, delivery_mode: :async)
      refute OptionalDeps.feature_enabled?(:async_email, delivery_mode: :sync)
    end
  end

  describe "ensure_available!/2" do
    test "returns :ok for an enabled enforced feature when dependency is loaded" do
      assert :ok = OptionalDeps.ensure_available!(:jwt, config(jwt: [enabled: true]))
    end

    test "raises a tagged error for an enabled enforced feature when dependency is missing" do
      assert_raise MissingDependencyError, fn ->
        OptionalDeps.ensure_available!(:jwt,
          config: config(jwt: [enabled: true]),
          dependency_loaded?: fn _spec -> false end
        )
      end
    end

    test "retains stable structured fields on the tagged error" do
      error =
        assert_raise MissingDependencyError, fn ->
          OptionalDeps.ensure_available!(:totp_qr,
            mfa_enrollment: :qr,
            dependency_loaded?: fn _spec -> false end
          )
        end

      assert error.feature == :totp_qr
      assert error.dependency == :eqrcode
      assert error.spec == "~> 0.2.1"
      assert error.evidence == "MFA enrollment requested QR rendering"
      assert error.remediation == ~s(Add {:eqrcode, "~> 0.2.1"} to your mix.exs deps and run mix deps.get.)
      assert Exception.message(error) =~ "[Sigra]"
    end

    test "does not block advisory rows when they are inactive" do
      assert :ok =
               OptionalDeps.ensure_available!(:rate_limit,
                 dependency_loaded?: fn _spec -> false end
               )
    end
  end

  describe "doctor_row/2" do
    test "proves jwt enablement from host config instead of speculation" do
      active_row = OptionalDeps.doctor_row(:jwt, config(jwt: [enabled: true]))
      inactive_row = OptionalDeps.doctor_row(:jwt, config(jwt: [enabled: false]))

      assert active_row.enabled? == true
      assert active_row.status == :ok
      assert active_row.evidence == "config.jwt[:enabled] == true"

      assert inactive_row.enabled? == false
      assert inactive_row.status == :inactive
      assert inactive_row.blocking? == false
    end

    test "returns informative non-blocking metadata for inactive advisory rows" do
      row =
        OptionalDeps.doctor_row(:rate_limit,
          dependency_loaded?: fn _spec -> false end
        )

      assert row.feature == :rate_limit
      assert row.dependency == :hammer
      assert row.enabled? == false
      assert row.loaded? == false
      assert row.blocking? == false
      assert row.status == :advisory
      assert row.evidence == "rate limiting not explicitly configured"
    end
  end

  defp config(overrides) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      secret_key_base: String.duplicate("a", 64),
      jwt: [enabled: false, algorithm: "HS256"],
      mfa: [enabled: true]
    ]

    merged =
      Keyword.merge(base, overrides, fn
        :jwt, left, right -> Keyword.merge(left, right)
        :mfa, left, right -> Keyword.merge(left, right)
        _key, _left, right -> right
      end)

    Sigra.Config.new!(merged)
  end
end
