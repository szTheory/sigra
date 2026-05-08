defmodule ExampleWeb.SigraWebhookController do
  use ExampleWeb, :controller

  alias Example.Accounts
  alias Sigra.Webhooks.Signature

  def create(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    with {:ok, secrets} <- signing_secrets(),
         {:ok, %{delivery_id: verified_delivery_id, timestamp: timestamp}} <-
         Signature.verify(
             conn.req_headers,
             raw_body,
             secrets,
             tolerance: signature_tolerance()
           ),
         {:ok, _receipt, _state} <- Accounts.record_webhook_receipt(verified_delivery_id, raw_body, timestamp) do
      if Accounts.webhook_receiver_fail_after_verify?() do
        send_resp(conn, 503, "receiver downstream unavailable")
      else
        send_resp(conn, 202, "")
      end
    else
      {:error, :missing_id} -> send_resp(conn, 400, "missing webhook id")
      {:error, :missing_timestamp} -> send_resp(conn, 400, "missing webhook timestamp")
      {:error, :missing_signature} -> send_resp(conn, 400, "missing webhook signature")
      {:error, :invalid_timestamp} -> send_resp(conn, 400, "invalid webhook timestamp")
      {:error, :stale_timestamp} -> send_resp(conn, 400, "stale webhook timestamp")
      {:error, :malformed_signature} -> send_resp(conn, 400, "malformed webhook signature")
      {:error, :invalid_signature} -> send_resp(conn, 401, "invalid webhook signature")
      {:error, :missing_secret_configuration} ->
        send_resp(conn, 500, "missing webhook secret configuration")

      {:error, _changeset} -> send_resp(conn, 422, "unable to persist webhook receipt")
    end
  end

  defp signing_secrets do
    case Accounts.webhook_receiver_secrets() do
      [] ->
        {:error, :missing_secret_configuration}

      secrets ->
        {:ok, secrets}
    end
  end

  defp signature_tolerance do
    Example.Accounts.sigra_config()
    |> Map.get(:webhooks, [])
    |> Keyword.get(:signature_tolerance, 300)
  end

end
