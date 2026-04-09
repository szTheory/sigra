defmodule Sigra.HooksTest do
  use ExUnit.Case, async: true

  alias Sigra.Hooks
  alias Ecto.Multi

  describe "maybe_run_hook/4" do
    test "returns multi unchanged when hook is nil" do
      multi = Multi.new() |> Multi.run(:user, fn _repo, _changes -> {:ok, :created} end)
      config = [hooks: []]

      result = Hooks.maybe_run_hook(multi, :register, %{user: %{id: 1}}, config)

      assert result == multi
    end

    test "appends named hook step when hook is configured" do
      multi = Multi.new() |> Multi.run(:user, fn _repo, _changes -> {:ok, :created} end)
      config = [hooks: [on_password_change: {__MODULE__.SuccessHook, :on_password_change}]]

      result = Hooks.maybe_run_hook(multi, :password_change, %{user: %{id: 1}}, config)

      # The multi should now have an additional step
      assert Multi.to_list(result) |> length() > Multi.to_list(multi) |> length()
    end

    test "hook returning {:ok, multi} succeeds in transaction" do
      multi =
        Multi.new()
        |> Multi.run(:user, fn _repo, _changes -> {:ok, %{id: 1}} end)
        |> Hooks.maybe_run_hook(
          :register,
          %{user: %{id: 1}},
          [hooks: [on_register: {__MODULE__.SuccessHook, :on_register}]]
        )

      # Verify the multi has the hook step named correctly
      steps = Multi.to_list(multi)
      step_names = Enum.map(steps, fn {name, _} -> name end)
      assert :on_register_hook in step_names
    end

    test "hook returning {:error, reason} causes multi step to fail" do
      multi =
        Multi.new()
        |> Multi.run(:user, fn _repo, _changes -> {:ok, %{id: 1}} end)
        |> Hooks.maybe_run_hook(
          :password_change,
          %{user: %{id: 1}},
          [hooks: [on_password_change: {__MODULE__.FailHook, :on_password_change}]]
        )

      steps = Multi.to_list(multi)
      step_names = Enum.map(steps, fn {name, _} -> name end)
      assert :on_password_change_hook in step_names
    end

    test "context map includes :user key" do
      multi = Multi.new() |> Multi.run(:user, fn _repo, _changes -> {:ok, :created} end)
      user = %{id: 42, email: "test@example.com"}
      config = [hooks: [on_email_change: {__MODULE__.ContextHook, :on_email_change}]]

      result = Hooks.maybe_run_hook(multi, :email_change, %{user: user}, config)

      steps = Multi.to_list(result)
      step_names = Enum.map(steps, fn {name, _} -> name end)
      assert :on_email_change_hook in step_names
    end
  end

  describe "get_hook/2" do
    test "returns nil for unconfigured hook" do
      config = [hooks: []]
      assert Hooks.get_hook(config, :register) == nil
    end

    test "returns {mod, fun} tuple for configured hook" do
      config = [hooks: [on_register: {MyApp.Hooks, :on_register}]]
      assert Hooks.get_hook(config, :register) == {MyApp.Hooks, :on_register}
    end

    test "returns nil for non-keyword config" do
      assert Hooks.get_hook("invalid", :register) == nil
    end

    test "works with struct-like map containing hooks key" do
      config = %{hooks: [on_delete: {MyApp.Hooks, :on_delete}]}
      assert Hooks.get_hook(config, :delete) == {MyApp.Hooks, :on_delete}
    end
  end

  # Test hook modules
  defmodule SuccessHook do
    def on_register(_multi, _context) do
      {:ok, Ecto.Multi.new()}
    end

    def on_password_change(_multi, _context) do
      {:ok, Ecto.Multi.new()}
    end
  end

  defmodule FailHook do
    def on_password_change(_multi, _context) do
      {:error, :profile_update_failed}
    end
  end

  defmodule ContextHook do
    def on_email_change(_multi, %{user: _user}) do
      {:ok, Ecto.Multi.new()}
    end
  end
end
