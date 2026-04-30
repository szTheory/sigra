defmodule Example.InstallCompileTest do
  @moduledoc """
  Plan 10-06 smoke test: verifies that `mix sigra.install` generated code loads
  cleanly and the core public API surface is present.

  This test is the "did the installer work" gate for D-17 #1. If this test
  fails, downstream smoke tests cannot run.
  """
  use ExUnit.Case, async: true
  @compile {:no_warn_undefined, Example.Accounts}
  @moduletag :example_app

  setup_all do
    example_build = Path.expand("../../../_build/test/lib", __DIR__)

    example_build
    |> Path.join("*/ebin")
    |> Path.wildcard()
    |> Enum.each(&Code.prepend_path/1)

    if :ets.whereis(ExampleWeb.Endpoint) == :undefined do
      :ets.new(ExampleWeb.Endpoint, [:named_table, :public, :set])
    end

    :ets.insert(ExampleWeb.Endpoint, {:secret_key_base, String.duplicate("a", 64)})

    base_url = "http://localhost"

    :persistent_term.put(
      {Phoenix.Endpoint, ExampleWeb.Endpoint},
      %{
        url: base_url,
        static_url: base_url,
        struct_url: URI.parse(base_url),
        host: "localhost"
      }
    )

    :ok
  end

  test "Sigra-generated core modules are loaded" do
    assert Code.ensure_loaded?(Example.Accounts)
    assert Code.ensure_loaded?(Example.Accounts.User)
    assert Code.ensure_loaded?(Example.Accounts.UserToken)
    assert Code.ensure_loaded?(Example.Accounts.UserSession)
    assert Code.ensure_loaded?(Example.Accounts.UserMFACredential)
    assert Code.ensure_loaded?(Example.Accounts.UserBackupCode)
    assert Code.ensure_loaded?(Example.Accounts.AuditEvent)
    assert Code.ensure_loaded?(ExampleWeb.UserAuth)
    assert Code.ensure_loaded?(ExampleWeb.ConnCaseHelpers)
    assert Code.ensure_loaded?(Example.AccountsFixtures)
  end

  test "Accounts context exposes canonical Sigra public API" do
    # ExUnit may run this before other tests in the module; `function_exported?/3`
    # returns false until the module is actually loaded (see Kernel docs).
    {:module, _} = Code.ensure_loaded(Example.Accounts)

    assert function_exported?(Example.Accounts, :register_user, 1)
    assert function_exported?(Example.Accounts, :get_user_by_email, 1)
    assert function_exported?(Example.Accounts, :generate_user_session_token, 1)
    assert function_exported?(Example.Accounts, :sigra_config, 0)
    assert function_exported?(Example.Accounts, :reset_user_password, 2)
  end

  test "Sigra config struct has cookie_domain key (Phase 10 D-08)" do
    config = Example.Accounts.sigra_config()
    assert Map.has_key?(config, :cookie_domain)
  end

  test "Sigra library modules used by generated code are loaded" do
    assert Code.ensure_loaded?(Sigra.Auth)
    assert Code.ensure_loaded?(Sigra.Testing)
    assert Code.ensure_loaded?(Sigra.Config)
    assert Code.ensure_loaded?(Sigra.MFA)
  end

  test "generated-host jwt/api compile contract emits a Joken warning only when JWT is enabled" do
    module_name = Module.concat(__MODULE__, "JwtWarning#{System.unique_integer([:positive])}")

    warning =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule #{inspect(module_name)} do
          require Sigra.Application

          Sigra.Application.warn_for_enabled_optional_deps!(
            jwt: [enabled: true],
            dependency_loaded?: fn spec -> spec.dependency != :joken end
          )

          def ready?, do: true
        end
        """)
      end)

    assert warning =~ "compile-time optional dependency warning for jwt"
    assert warning =~ "Dependency: joken (~> 2.6)"
    assert warning =~ "Evidence: jwt[:enabled] == true"
  end
end
