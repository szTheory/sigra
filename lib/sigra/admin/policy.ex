defmodule Sigra.Admin.Policy do
  @moduledoc """
  Behaviour for host-owned admin access decisions.

  Host apps must answer two questions explicitly:

  * does this scope have platform-wide admin access?
  * which organization ids may this scope administer?

  Sigra does not infer either answer from signup order, email domain,
  or any other hidden default.
  """

  @callback platform_admin?(scope :: term()) :: boolean()
  @callback admin_org_ids(scope :: term()) :: [term()]
end
