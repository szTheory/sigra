defmodule ExampleWeb.WebhookBodyReader do
  @moduledoc false

  import Plug.Conn

  def read_body(conn, opts) do
    read_body(conn, opts, [])
  end

  defp read_body(conn, opts, acc) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        raw_body = IO.iodata_to_binary(Enum.reverse([body | acc]))
        conn = assign(conn, :raw_body, raw_body)
        {:ok, raw_body, conn}

      {:more, body, conn} ->
        read_body(conn, opts, [body | acc])
    end
  end
end
