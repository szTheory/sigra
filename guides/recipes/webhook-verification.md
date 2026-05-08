# Webhook Verification

This recipe shows how a Plug or Phoenix receiver verifies Sigra's outbound
webhooks without re-reading Sigra internals.

## The contract to verify

Sigra signs every delivery with:

- `Sigra-Webhook-Id`
- `Sigra-Webhook-Timestamp`
- `Sigra-Webhook-Signature`

The HMAC input is the exact string:

```text
delivery_id.timestamp.raw_body
```

`raw_body` means the exact bytes received on the wire. Do not verify against a
decoded map, re-encoded JSON, or pretty-printed JSON.

Sender-side endpoint policy does not change this HMAC contract. If Sigra blocks
an endpoint with `local_policy_error`, the receiver sees nothing because the
request is never attempted.

## Step 1: Capture the raw body with `body_reader`

Configure `Plug.Parsers` to preserve the raw body before JSON decoding:

```elixir
pipeline :webhooks do
  plug :accepts, ["json"]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    body_reader: {MyAppWeb.WebhookBodyReader, :read_body, []}
end
```

Add a small `body_reader` module:

```elixir
defmodule MyAppWeb.WebhookBodyReader do
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:more, body, conn}
    end
  end
end
```

If your payloads can exceed a single `read_body/2` call, accumulate chunks
instead of overwriting `:raw_body`.

## Step 2: Verify the signature before trusting JSON fields

`Sigra.Webhooks.Signature.verify/4` already applies constant-time digest
comparison through `Sigra.Token.secure_compare/2`.

```elixir
defmodule MyAppWeb.SigraWebhookController do
  use MyAppWeb, :controller

  alias Sigra.Webhooks.Signature

  def create(conn, _params) do
    raw_body = conn.assigns.raw_body || ""
    secrets = webhook_secrets()

    with {:ok, %{delivery_id: delivery_id, timestamp: timestamp}} <-
           Signature.verify(conn.req_headers, raw_body, secrets, tolerance: 300) do
      payload = Jason.decode!(raw_body)
      :ok = MyApp.Webhooks.process(delivery_id, payload, timestamp)
      send_resp(conn, 202, "")
    else
      {:error, :missing_id} -> send_resp(conn, 400, "missing webhook id")
      {:error, :missing_timestamp} -> send_resp(conn, 400, "missing webhook timestamp")
      {:error, :missing_signature} -> send_resp(conn, 400, "missing webhook signature")
      {:error, :invalid_timestamp} -> send_resp(conn, 400, "invalid webhook timestamp")
      {:error, :stale_timestamp} -> send_resp(conn, 400, "stale webhook timestamp")
      {:error, :malformed_signature} -> send_resp(conn, 400, "malformed webhook signature")
      {:error, :invalid_signature} -> send_resp(conn, 401, "invalid webhook signature")
    end
  end

  defp webhook_secrets do
    [
      System.fetch_env!("SIGRA_WEBHOOK_SECRET_CURRENT"),
      System.get_env("SIGRA_WEBHOOK_SECRET_PREVIOUS")
    ]
    |> Enum.filter(&is_binary/1)
  end
end
```

If you implement verification outside Elixir, keep the same rules:

- split `Sigra-Webhook-Signature` on commas
- accept `v1=...` entries only
- compute HMAC-SHA256 over `delivery_id.timestamp.raw_body`
- compare digests in constant time

## Step 3: Dedupe by `delivery_id`

`event_id` and `delivery_id` are not interchangeable.

- `event_id` identifies the shared public event payload.
- `delivery_id` identifies one subscription-specific delivery attempt.

Store `delivery_id` in your receiver database and ignore duplicates you have
already processed. Phase 98 keeps the same `delivery_id` across retries, so
dedupe should stay keyed on `delivery_id` even when you see multiple signed
attempts for the same logical delivery.

Phase 104 does not change that rule. Manual replay creates a new child
delivery with a fresh `delivery_id`, so receivers should treat the replay as a
new logical delivery while still ignoring duplicates for the original failed
source row.

## Step 4: Keep a bounded timestamp tolerance

Sigra's default tolerance is 300 seconds. Your receiver can choose a tighter
value, but it should stay long enough to tolerate real queue and clock skew.

Each retry attempt gets a fresh `Sigra-Webhook-Timestamp` and a fresh HMAC
signature over the same `delivery_id` plus the exact body bytes. Do not assume
retries reuse the original timestamp or signature.

Reject stale timestamps even when the signature digest matches.

## Step 5: Support overlap-safe secret rotation on the receiver side

`Signature.verify/4` accepts one secret or a list of candidate secrets:

```elixir
Signature.verify(conn.req_headers, raw_body, [
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_CURRENT"),
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_PREVIOUS")
])
```

That lets your receiver accept both secrets during Sigra's overlap window.
Sigra signs overlap-window deliveries with two `v1=` values over one shared
timestamp and one stable `delivery_id`.

Those candidate secrets stay receiver-owned. Do not ask Sigra which secret
matches a specific `delivery_id`, and do not depend on sender-side secret
lookup as part of your verification contract.

Generated hosts should mirror this in their own deployment checklist:
prepare the next sender secret, update the receiver to hold both current and
previous secrets, start overlap, verify at least one real overlap-window
delivery, then complete rotation and verify one post-retirement delivery.

## Delivery retries and dead-letter semantics

Phase 98 sends at most six total attempts per `delivery_id` on this nominal
schedule:

- first retry after 1 minute
- then 5 minutes
- then 15 minutes
- then 1 hour
- then 3 hours

If the receiver returns `Retry-After`, Sigra may delay the next scheduled
attempt beyond the nominal slot, but it does not expand the attempt budget.

When the final attempt still fails, or when Sigra hits a terminal local
invariant failure, Sigra moves the parent delivery row into `dead_lettered`
state.

Phase 104 adds one operator recovery path from that state:

- replay is triggered from Sigra's admin UI, not from the receiver
- the original dead-lettered source row remains visible
- the replay child gets a fresh `delivery_id`
- receiver dedupe still stays keyed on `delivery_id`

Receivers should not special-case replay beyond handling the fresh
`delivery_id` exactly the same way they would handle any other first-time
delivery.

## Common mistakes

- Verifying `conn.body_params` instead of the raw body bytes.
- Parsing JSON and then re-encoding it before verification.
- Treating `event_id` as the dedupe key instead of `delivery_id`.
- Accepting stale `Sigra-Webhook-Timestamp` values forever.
- Comparing HMAC digests with normal string equality instead of a constant-time
  comparison.
- Expecting a `kid` or other secret-selection header from the sender.
