defmodule Sigra.Audit.Cursor do
  @moduledoc """
  Base64URL cursor encoding for audit log pagination (D-13).

  Format: `Base64URL("<inserted_at_usec>|<uuid>")` — no padding, no signing.
  Cursors carry only timestamp + id, so tampering only shifts the pagination
  window; no sensitive data is disclosed.
  """

  @spec encode(DateTime.t(), binary()) :: String.t()
  def encode(%DateTime{} = dt, id) when is_binary(id) do
    ts = DateTime.to_unix(dt, :microsecond)
    Base.url_encode64("#{ts}|#{id}", padding: false)
  end

  @spec decode(binary() | nil) ::
          {:ok, {DateTime.t(), binary()}} | {:error, :invalid_cursor}
  def decode(cursor) when is_binary(cursor) and cursor != "" do
    with {:ok, raw} <- Base.url_decode64(cursor, padding: false),
         [ts_str, id] when id != "" <- String.split(raw, "|", parts: 2),
         {ts_int, ""} <- Integer.parse(ts_str),
         {:ok, dt} <- DateTime.from_unix(ts_int, :microsecond) do
      {:ok, {dt, id}}
    else
      _ -> {:error, :invalid_cursor}
    end
  end

  def decode(_), do: {:error, :invalid_cursor}
end
