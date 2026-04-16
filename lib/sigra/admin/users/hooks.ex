defmodule Sigra.Admin.Users.Hooks do
  @moduledoc """
  Host-owned customization hooks for admin user surfaces.

  The contract is intentionally read-only and data-oriented so library-owned
  admin runtime code can consume host extensions without delegating query
  mutation or authorization responsibilities outside Sigra.
  """

  @type user_like :: struct() | map()
  @type badge :: map()
  @type column :: map()
  @type detail_section :: map()
  @type copy_overrides :: map()

  # Callback surface: display_name_field/0, display_name/1,
  # extra_search_fields/0, extra_list_badges/1, extra_list_columns/0,
  # extra_detail_sections/1, copy_overrides/0.
  @callback display_name_field() :: atom() | nil
  @callback display_name(user_like()) :: String.t() | nil
  @callback extra_search_fields() :: [atom()]
  @callback extra_list_badges(user_like()) :: [badge()]
  @callback extra_list_columns() :: [column()]
  @callback extra_detail_sections(user_like()) :: [detail_section()]
  @callback copy_overrides() :: copy_overrides()

  @spec resolve(map() | keyword() | term()) :: module()
  def resolve(config) do
    config
    |> accounts_module()
    |> resolve_hook_module()
  end

  defp accounts_module(%{accounts_module: module}) when is_atom(module), do: module
  defp accounts_module(%{accounts: module}) when is_atom(module), do: module

  defp accounts_module(%{user_schema: module}) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.safe_concat()
  rescue
    ArgumentError -> nil
  end

  defp accounts_module(config) when is_list(config) do
    Keyword.get(config, :accounts_module) ||
      Keyword.get(config, :accounts) ||
      accounts_module_from_user_schema(Keyword.get(config, :user_schema))
  end

  defp accounts_module(_config), do: nil

  defp accounts_module_from_user_schema(module) when is_atom(module) do
    module
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.safe_concat()
  rescue
    ArgumentError -> nil
  end

  defp accounts_module_from_user_schema(_module), do: nil

  defp resolve_hook_module(module) when is_atom(module) do
    if function_exported?(module, :admin_user_hooks, 0) do
      module.admin_user_hooks()
    else
      Sigra.Admin.Users.DefaultHooks
    end
  end

  defp resolve_hook_module(_module), do: Sigra.Admin.Users.DefaultHooks
end
