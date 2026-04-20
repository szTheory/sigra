defmodule Sigra.Passkeys.DeviceName do
  @moduledoc """
  Resolves friendly labels for stored passkey credentials.

  The bundled AAGUID snapshot is presentation-only. It should not be used
  for security policy or authenticator trust decisions.
  """

  @snapshot_path "priv/sigra/passkey_aaguids.json"

  @doc "Returns a display label for a passkey-like map or struct."
  @spec label(map() | nil) :: String.t()
  def label(nil), do: "Passkey"

  def label(passkey) when is_map(passkey) do
    label(
      Map.get(passkey, :nickname) || Map.get(passkey, "nickname"),
      Map.get(passkey, :aaguid) || Map.get(passkey, "aaguid"),
      Map.get(passkey, :device_hint) || Map.get(passkey, "device_hint")
    )
  end

  @doc "Returns the first friendly label in nickname, registry, hint, fallback order."
  @spec label(term(), term(), term()) :: String.t()
  def label(nickname, aaguid, device_hint) do
    [
      normalize_blank(nickname),
      friendly_aaguid_name(aaguid),
      normalize_blank(device_hint),
      "Passkey"
    ]
    |> Enum.find(& &1)
  end

  defp friendly_aaguid_name(aaguid) do
    with normalized when not is_nil(normalized) <- normalize_aaguid(aaguid),
         %{} = entry <- Map.get(registry(), normalized) do
      normalize_blank(entry["name"] || entry["label"] || entry["device"] || entry["provider"])
    else
      _ -> nil
    end
  end

  defp registry do
    @snapshot_path
    |> snapshot_file()
    |> File.read()
    |> case do
      {:ok, json} ->
        case JSON.decode(json) do
          {:ok, %{"aaguids" => aaguids}} when is_map(aaguids) -> aaguids
          _ -> %{}
        end

      {:error, _reason} ->
        %{}
    end
  end

  defp snapshot_file(relative_path) do
    candidates = [
      case :code.priv_dir(:sigra) do
        path when is_list(path) -> Path.join(List.to_string(path), "sigra/passkey_aaguids.json")
        _ -> nil
      end,
      Application.app_dir(:sigra, relative_path),
      Path.expand(relative_path, File.cwd!())
    ]

    Enum.find(candidates, &(&1 && File.exists?(&1))) || Path.expand(relative_path, File.cwd!())
  end

  defp normalize_aaguid(nil), do: nil

  defp normalize_aaguid(aaguid) when is_binary(aaguid) do
    aaguid
    |> String.trim()
    |> String.downcase()
    |> String.replace("-", "")
    |> case do
      <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
        e::binary-size(12)>> ->
        Enum.join([a, b, c, d, e], "-")

      _ ->
        nil
    end
  end

  defp normalize_aaguid(_aaguid), do: nil

  defp normalize_blank(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_blank(_value), do: nil
end
