defmodule Sigra.JWT.ClaimsBuilder do
  @moduledoc """
  Behaviour for adding custom claims to JWT access tokens.

  Implement this behaviour to embed application-specific data in JWTs.
  Called during token generation after standard claims are built.

  ## Example

      defmodule MyApp.JWTClaimsBuilder do
        @behaviour Sigra.JWT.ClaimsBuilder

        @impl true
        def extra_claims(user) do
          %{"role" => user.role, "org_id" => user.org_id}
        end
      end
  """

  @doc "Returns a map of custom claims to merge into the JWT payload."
  @callback extra_claims(user :: struct()) :: map()
end
