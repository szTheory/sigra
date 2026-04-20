defmodule Sigra.OAuth.AssentOidcContractTest do
  @moduledoc """
  SEED-4 / OIDC stub path: Assent ships `Assent.Strategy.OIDC` so host apps can
  wire a local or dockerized OIDC issuer (Keycloak, Zitadel, etc.) without Google.
  """
  use ExUnit.Case, async: true

  test "Assent.Strategy.OIDC is present for stand-in IdP configuration" do
    assert {:module, Assent.Strategy.OIDC} = Code.ensure_loaded(Assent.Strategy.OIDC)
    assert function_exported?(Assent.Strategy.OIDC, :authorize_url, 1)
  end
end
