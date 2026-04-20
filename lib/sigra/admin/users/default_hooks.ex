defmodule Sigra.Admin.Users.DefaultHooks do
  @moduledoc """
  Default no-op implementation for `Sigra.Admin.Users.Hooks`.
  """

  @behaviour Sigra.Admin.Users.Hooks

  @impl true
  def display_name_field, do: nil

  @impl true
  def display_name(_user), do: nil

  @impl true
  def extra_search_fields, do: []

  @impl true
  def extra_list_badges(_user), do: []

  @impl true
  def extra_list_columns, do: []

  @impl true
  def extra_detail_sections(_user), do: []

  @impl true
  def copy_overrides, do: %{}
end
