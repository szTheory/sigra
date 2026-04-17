defmodule SigraInstallGoldenTmp.SigraAdminPolicy do
  @moduledoc """
  Host-owned admin policy contract for Sigra's admin surface.

  Keep this module explicit. Sigra does not infer platform-admin or
  org-admin access from signup order, email domain, or any other
  hidden fallback.
  """

  @behaviour Sigra.Admin.Policy

  @impl true
  def platform_admin?(scope) do
    # TODO: Return true only when this scope should have global admin access.
    # Example: match on a host-owned role flag or query a trusted policy source.
    _ = scope
    false
  end

  @impl true
  def admin_org_ids(scope) do
    # TODO: Return organization ids this scope may administer.
    # Keep org-admin access explicit; do not infer or expand it implicitly.
    _ = scope
    []
  end
end
