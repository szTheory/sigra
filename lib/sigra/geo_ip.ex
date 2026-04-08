defmodule Sigra.GeoIP do
  @moduledoc """
  Behaviour for IP geolocation lookups.

  Sigra does not ship a default GeoIP implementation. To enable geolocation
  on sessions (city and country tracking for suspicious login detection),
  implement this behaviour with your preferred GeoIP provider (e.g., Geolix,
  MaxMind, IP2Location) and configure it:

      config = Sigra.Config.new!(
        repo: MyApp.Repo,
        user_schema: MyApp.User,
        geo_ip: [module: MyApp.GeoIP]
      )

  ## Example Implementation

      defmodule MyApp.GeoIP do
        @behaviour Sigra.GeoIP

        @impl true
        def lookup(ip) do
          case Geolix.lookup(ip, where: :city) do
            %{city: %{name: city}, country: %{iso_code: code}} ->
              {:ok, %{city: city, country_code: code}}

            _ ->
              {:error, :not_found}
          end
        end
      end
  """

  @doc "Looks up geographic information for an IP address."
  @doc since: "0.1.0"
  @callback lookup(ip :: String.t()) ::
              {:ok, %{city: String.t() | nil, country_code: String.t() | nil}} | {:error, term()}
end
