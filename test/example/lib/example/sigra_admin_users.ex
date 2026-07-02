defmodule Example.SigraAdminUsers do
  @moduledoc """
  Example host hooks for Sigra admin user surfaces.
  """

  @behaviour Sigra.Admin.Users.Hooks

  @impl true
  def display_name_field, do: :display_name

  @impl true
  def display_name(user) do
    user.display_name || user.email
  end

  @impl true
  def extra_search_fields, do: []

  @impl true
  def extra_list_badges(_user), do: ["Example badge"]

  @impl true
  def extra_list_columns, do: [%{label: "Region", value: "us-east"}]

  @impl true
  def extra_detail_sections(_user), do: []

  @impl true
  def copy_overrides, do: %{}
end
