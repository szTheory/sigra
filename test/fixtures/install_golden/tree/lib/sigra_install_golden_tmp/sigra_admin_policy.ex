defmodule SigraInstallGoldenTmp.SigraAdminPolicy do
  @moduledoc """
  Host-owned admin policy contract for Sigra's admin surface.

  Platform-admin access delegates to the generated host-owned persisted
  grant seam. Sigra never infers access from signup order, email domain,
  or any other hidden fallback. Keep organization-admin access explicit.
  """

  @behaviour Sigra.Admin.Policy

  @impl true
  def platform_admin?(scope), do: SigraInstallGoldenTmp.SigraAdminAccess.platform_admin?(scope)

  @impl true
  def admin_org_ids(scope) do
    # TODO: Return organization ids this scope may administer.
    # Keep org-admin access explicit; do not infer or expand it implicitly.
    _ = scope
    []
  end
end
