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

    # The real Application.start has already populated this persistent_term with the full
    # Phoenix.Endpoint config (~30 keys including :script_name). Snapshot it so we can
    # restore on exit — the slim 4-key replacement below is fine for this module's tests
    # but breaks every other test that uses `Phoenix.ConnTest.dispatch/5` against the
    # endpoint, which expects keys like :script_name. Without restoration, this module's
    # `setup_all` corrupts the global term for the rest of the test run.
    endpoint_term_key = {Phoenix.Endpoint, ExampleWeb.Endpoint}

    original_term =
      try do
        {:ok, :persistent_term.get(endpoint_term_key)}
      rescue
        ArgumentError -> :missing
      end

    base_url = "http://localhost"

    :persistent_term.put(
      endpoint_term_key,
      %{
        url: base_url,
        static_url: base_url,
        struct_url: URI.parse(base_url),
        host: "localhost"
      }
    )

    on_exit(fn ->
      case original_term do
        {:ok, term} -> :persistent_term.put(endpoint_term_key, term)
        :missing -> :persistent_term.erase(endpoint_term_key)
      end
    end)

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
    source_path = Path.expand("../../../lib/example/accounts.ex", __DIR__)
    current_sigra_ebin = Path.expand("../../../../../_build/test/lib/sigra/ebin", __DIR__)
    module_name = Module.concat(__MODULE__, "JwtWarning#{System.unique_integer([:positive])}")
    original_source = File.read!(source_path)

    compiled_source =
      Regex.replace(
        ~r/^defmodule Example\.Accounts do/m,
        original_source,
        "defmodule #{inspect(module_name)} do",
        global: false
      )

    previous_override = Application.get_env(:sigra, :compile_dependency_loaded_override)

    Application.put_env(:sigra, :compile_dependency_loaded_override, fn spec ->
      spec.dependency != :joken
    end)

    Code.prepend_path(current_sigra_ebin)

    warning =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string(compiled_source, source_path)
      end)

    if is_nil(previous_override) do
      Application.delete_env(:sigra, :compile_dependency_loaded_override)
    else
      Application.put_env(:sigra, :compile_dependency_loaded_override, previous_override)
    end

    assert warning =~ "compile-time optional dependency warning for jwt"
    assert warning =~ "Dependency: joken (~> 2.6)"
    assert warning =~ "Evidence: jwt[:enabled] == true"
    assert warning =~ "test/example/lib/example/accounts.ex"
  end
end
