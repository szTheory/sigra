defmodule Sigra.SuspiciousLogin do
  @moduledoc """
  Suspicious login detection. Compares login IP against all active session IPs
  for the user. Triggers on new IP during explicit login only.

  Does NOT trigger on:
  - Remember-me rehydration (D-45)
  - User's first login ever (no prior sessions to compare against)

  ## Configuration

      suspicious_login: [
        enabled: true,   # Enable/disable detection
        notify: true     # Send email notification on detection
      ]

  ## Telemetry

  Emits `[:sigra, :security, :suspicious_login]` with metadata:
  `%{user_id, ip, geo_city, geo_country_code}` per D-57.
  """

  @doc """
  Detect if a login is from a suspicious (new) IP.

  Returns `:ok` if the login IP is known or detection is disabled.
  Returns `{:suspicious, details}` if the IP is new and user has prior sessions.

  ## Parameters

    - `config` - `%Sigra.Config{}` struct
    - `user_id` - the user's ID
    - `login_ip` - the IP address of the current login (string)
    - `opts` - keyword list with `:session_store` (resolved from config if absent)
  """
  @doc since: "0.4.0"
  @spec detect(Sigra.Config.t(), term(), String.t(), keyword()) ::
          :ok | {:suspicious, map()}
  def detect(config, user_id, login_ip, opts \\ []) do
    suspicious_config = config.suspicious_login
    enabled = Keyword.get(suspicious_config, :enabled, true)

    if enabled do
      do_detect(config, user_id, login_ip, opts)
    else
      :ok
    end
  end

  defp do_detect(config, user_id, login_ip, opts) do
    session_store = Keyword.get(opts, :session_store) || Keyword.get(config.session, :store)
    store_opts = [repo: config.repo, session_schema: Keyword.get(config.session, :session_schema)]

    sessions = session_store.list_by_user(user_id, store_opts)
    known_ips = sessions |> Enum.map(& &1.ip) |> Enum.reject(&is_nil/1) |> MapSet.new()

    cond do
      MapSet.size(known_ips) == 0 ->
        # First login ever -- no sessions to compare against
        :ok

      login_ip in known_ips ->
        :ok

      true ->
        geo = resolve_geo(config, login_ip)

        details = %{
          ip: login_ip,
          geo_city: geo[:city],
          geo_country_code: geo[:country_code]
        }

        Sigra.Telemetry.event(
          [:sigra, :security, :suspicious_login],
          %{},
          %{
            user_id: user_id,
            ip: login_ip,
            geo_city: geo[:city],
            geo_country_code: geo[:country_code]
          }
        )

        # D-26: audit row for suspicious login detection (standalone, D-28).
        # Uses Sigra.Audit.log_safe which no-ops when audit_schema not
        # configured. Metadata never contains tokens/secrets (D-23).
        audit_config = Map.get(config, :audit, [])

        Sigra.Audit.log_safe("security.suspicious_login",
          repo: config.repo,
          audit_schema: Keyword.get(audit_config, :audit_schema),
          actor_id: user_id,
          outcome: "failure",
          ip_address: login_ip,
          metadata: %{geo_city: geo[:city], geo_country_code: geo[:country_code]}
        )

        {:suspicious, details}
    end
  end

  defp resolve_geo(config, ip) do
    geo_module = Keyword.get(config.geo_ip, :module)

    if geo_module do
      case geo_module.lookup(ip) do
        {:ok, geo} -> geo
        {:error, _} -> %{city: nil, country_code: nil}
      end
    else
      %{city: nil, country_code: nil}
    end
  end
end
