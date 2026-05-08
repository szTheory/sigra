defmodule Sigra.Webhooks.EndpointPolicy do
  @moduledoc """
  Shared endpoint-policy evaluation for outbound webhooks.
  """

  import Bitwise

  @localhost_hosts MapSet.new(["127.0.0.1", "::1", "localhost"])

  @type result :: :ok | {:error, atom(), String.t()}

  @spec validate_subscription(Sigra.Config.t(), String.t(), map()) :: result()
  def validate_subscription(%Sigra.Config{} = config, endpoint_url, opts \\ %{}) do
    evaluate(config, endpoint_url, Map.put(opts, :stage, :subscription))
  end

  @spec validate_delivery(Sigra.Config.t(), String.t(), map()) :: result()
  def validate_delivery(%Sigra.Config{} = config, endpoint_url, opts \\ %{}) do
    evaluate(config, endpoint_url, Map.put(opts, :stage, :delivery))
  end

  @spec evaluate(Sigra.Config.t(), String.t(), map()) :: result()
  def evaluate(config, endpoint_url, opts \\ %{})

  def evaluate(%Sigra.Config{} = config, endpoint_url, opts) when is_binary(endpoint_url) do
    with {:ok, uri} <- parse_endpoint(endpoint_url),
         :ok <- validate_scheme(uri),
         :ok <- reject_embedded_credentials(uri),
         {:ok, resolved_ips} <- resolve_targets(config, uri),
         :ok <- validate_ips(uri, resolved_ips),
         :ok <- run_callback(config, uri, resolved_ips, opts) do
      :ok
    end
  end

  def evaluate(_config, _endpoint_url, _opts),
    do: {:error, :invalid_endpoint_url, "must be an absolute HTTP or HTTPS URL"}

  defp parse_endpoint(endpoint_url) do
    case URI.new(endpoint_url) do
      {:ok, %URI{scheme: scheme, host: host} = uri}
      when scheme in ["http", "https"] and is_binary(host) ->
        {:ok, uri}

      {:ok, %URI{scheme: scheme}} when scheme in ["http", "https"] ->
        {:error, :missing_host, "must include a host"}

      _other ->
        {:error, :invalid_endpoint_url, "must be an absolute HTTP or HTTPS URL"}
    end
  end

  defp validate_scheme(%URI{scheme: "https"}), do: :ok

  defp validate_scheme(%URI{scheme: "http", host: host}) do
    if localhost_host?(host) or loopback_literal_host?(host) do
      :ok
    else
      {:error, :http_requires_loopback, "must use HTTPS unless the host is localhost"}
    end
  end

  defp reject_embedded_credentials(%URI{userinfo: nil}), do: :ok

  defp reject_embedded_credentials(%URI{}),
    do: {:error, :embedded_credentials, "must not include embedded credentials"}

  defp resolve_targets(config, %URI{host: host}) do
    with {:ok, resolved_ips} <- resolve_host(config, host),
         true <- resolved_ips != [] do
      {:ok, resolved_ips}
    else
      false -> {:error, :dns_resolution_failed, "could not resolve host"}
      {:error, :dns_resolution_failed} -> {:error, :dns_resolution_failed, "could not resolve host"}
    end
  end

  defp resolve_host(config, host) do
    cond do
      is_binary(host) and String.downcase(host) == "localhost" ->
        {:ok, [{127, 0, 0, 1}, {0, 0, 0, 0, 0, 0, 0, 1}]}

      true ->
        case parse_ip(host) do
          {:ok, ip} ->
            {:ok, [ip]}

          :error ->
        resolver = Keyword.get(config.webhooks, :endpoint_resolver) || &default_resolver/1

            case resolver.(host) do
              {:ok, ips} when is_list(ips) -> {:ok, Enum.uniq(ips)}
              ips when is_list(ips) -> {:ok, Enum.uniq(ips)}
              {:error, _reason} -> {:error, :dns_resolution_failed}
              _other -> {:error, :dns_resolution_failed}
            end
        end
    end
  end

  defp validate_ips(uri, resolved_ips) do
    if Enum.all?(resolved_ips, &allowed_ip?(&1, uri)) do
      :ok
    else
      case Enum.find_value(resolved_ips, &blocked_reason/1) do
        {reason, detail} -> {:error, reason, detail}
        nil -> :ok
      end
    end
  end

  defp allowed_ip?(ip, %URI{scheme: "http"}), do: loopback_ip?(ip)
  defp allowed_ip?(ip, %URI{scheme: "https"}), do: is_nil(blocked_reason(ip))

  defp blocked_reason(ip) do
    cond do
      metadata_ip?(ip) -> {:blocked_metadata_ip, "resolved target points at a metadata address"}
      loopback_ip?(ip) -> {:blocked_private_ip, "resolved target points at a loopback address"}
      link_local_ip?(ip) -> {:blocked_link_local_ip, "resolved target points at a link-local address"}
      private_ip?(ip) -> {:blocked_private_ip, "resolved target points at a private address"}
      true -> nil
    end
  end

  defp run_callback(config, uri, resolved_ips, opts) do
    case Keyword.get(config.webhooks, :endpoint_policy) do
      callback when is_function(callback, 1) ->
        context = %{
          stage: Map.get(opts, :stage),
          uri: uri,
          resolved_ips: resolved_ips,
          subscription: Map.get(opts, :subscription),
          delivery: Map.get(opts, :delivery)
        }

        case callback.(context) do
          :ok -> :ok
          {:error, reason, detail} when is_atom(reason) and is_binary(detail) -> {:error, reason, detail}
          {:error, reason} when is_atom(reason) -> {:error, reason, Atom.to_string(reason)}
          _other -> {:error, :policy_denied, "endpoint policy callback denied the destination"}
        end

      _other ->
        :ok
    end
  end

  defp parse_ip(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _reason} -> :error
    end
  end

  defp default_resolver(host) do
    ipv4 =
      case :inet.getaddrs(String.to_charlist(host), :inet) do
        {:ok, ips} -> ips
        _other -> []
      end

    ipv6 =
      case :inet.getaddrs(String.to_charlist(host), :inet6) do
        {:ok, ips} -> ips
        _other -> []
      end

    ips = Enum.uniq(ipv4 ++ ipv6)
    if ips == [], do: {:error, :nxdomain}, else: {:ok, ips}
  end

  defp localhost_host?(host) when is_binary(host),
    do: MapSet.member?(@localhost_hosts, String.downcase(host))

  defp localhost_host?(_host), do: false

  defp loopback_literal_host?(host) when is_binary(host) do
    case parse_ip(host) do
      {:ok, ip} -> loopback_ip?(ip)
      :error -> false
    end
  end

  defp loopback_ip?({127, _, _, _}), do: true
  defp loopback_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback_ip?(_ip), do: false

  defp link_local_ip?({169, 254, _, _}), do: true

  defp link_local_ip?(ip) when tuple_size(ip) == 8 do
    first = elem(ip, 0)
    second = elem(ip, 1)
    first == 0xFE80 and second in 0x0000..0x03FF
  end

  defp link_local_ip?(_ip), do: false

  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({172, second, _, _}) when second in 16..31, do: true
  defp private_ip?({192, 168, _, _}), do: true

  defp private_ip?(ip) when tuple_size(ip) == 8 do
    first = elem(ip, 0)
    (first &&& 0xFE00) == 0xFC00
  end

  defp private_ip?(_ip), do: false

  defp metadata_ip?({169, 254, 169, 254}), do: true
  defp metadata_ip?(_ip), do: false
end
