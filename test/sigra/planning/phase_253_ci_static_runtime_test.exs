defmodule Sigra.Planning.Phase253CIStaticRuntimeTest do
  use ExUnit.Case, async: false

  @dev_config Path.expand("../../example/config/dev.exs", __DIR__)
  @env_keys ~w(CI PORT PGPORT SIGRA_EXAMPLE_BIND)

  setup do
    previous = Map.new(@env_keys, &{&1, System.get_env(&1)})
    System.put_env(%{"PORT" => "4011", "PGPORT" => "5432", "SIGRA_EXAMPLE_BIND" => "127.0.0.1"})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    :ok
  end

  test "fixed-source CI servers disable hot code reloading and retain development routes" do
    for flag <- ["true", "1"] do
      config = read_config(flag)
      assert config[:example][ExampleWeb.Endpoint][:code_reloader] == false
      assert config[:example][:dev_routes] == true
      assert config[:example][ExampleWeb.Endpoint][:http][:port] == 4011
    end
  end

  test "ordinary development retains hot code reloading" do
    for flag <- [nil, "", "false", "0"] do
      assert read_config(flag)[:example][ExampleWeb.Endpoint][:code_reloader] == true
    end
  end

  test "the CI setting changes only the reloader configuration" do
    local = read_config(nil)
    ci = read_config("true")

    only_reloader_changed? =
      put_in(local, [:example, ExampleWeb.Endpoint, :code_reloader], false) == ci

    assert only_reloader_changed?, "CI must retain the remaining development configuration"
  end

  defp read_config(nil) do
    System.delete_env("CI")
    Config.Reader.read!(@dev_config)
  end

  defp read_config(flag) do
    System.put_env("CI", flag)
    Config.Reader.read!(@dev_config)
  end
end
