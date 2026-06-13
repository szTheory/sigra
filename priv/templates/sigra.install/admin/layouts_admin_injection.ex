  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :current_scope, :map, default: nil
  attr :admin_scope, :map, default: nil
  attr :page_title, :string, default: nil
  attr :admin_breadcrumbs, :list, default: nil
  attr :inner_content, :any, default: nil

  def admin(assigns) do
    ~H"""
    <.admin_shell
      admin_scope={@admin_scope}
      current_scope={@current_scope}
      page_title={@page_title}
      admin_breadcrumbs={@admin_breadcrumbs}
    >
      {@inner_content}
    </.admin_shell>

    <.flash_group flash={@flash} />
    """
  end
