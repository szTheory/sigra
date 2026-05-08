# Webhook Receiver Setup

Sigra sends signed auth events. Your host app owns the receiver endpoint,
signature verification, duplicate suppression, and downstream automation.

## Receiver checklist

1. Add a JSON webhook route in your host app, for example `/webhooks/sigra`.
2. Configure `Plug.Parsers` with a `body_reader` so you can verify against the
   raw request body before you trust decoded JSON fields.
3. Verify `Sigra-Webhook-Id`, `Sigra-Webhook-Timestamp`, and
   `Sigra-Webhook-Signature` on every request.
4. Store `delivery_id` and ignore duplicate deliveries you have already
   processed.
5. Keep `SIGRA_WEBHOOK_SECRET_CURRENT` and `SIGRA_WEBHOOK_SECRET_PREVIOUS`
   locally on the receiver during overlap windows.
   Do not call back into Sigra to ask which secret matches a delivery.
6. Use Sigra's explicit flow: prepare the next secret, update the receiver,
   start overlap, verify a real overlap-window delivery, then complete
   rotation.
7. Trigger real Sigra events after setup and confirm deliveries in the
   generated admin webhook history.
8. If a delivery ever dead-letters, use the Sigra admin UI replay action as a
   recovery step. Replay creates a fresh child `delivery_id`; keep receiver
   dedupe keyed on `delivery_id` and keep the original failed source row in
   your own incident notes.

## Route and parser sketch

```elixir
scope "/webhooks", MyAppWeb do
  pipe_through :webhooks

  post "/sigra", SigraWebhookController, :create
end

pipeline :webhooks do
  plug :accepts, ["json"]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason,
    body_reader: {MyAppWeb.WebhookBodyReader, :read_body, []}
end
```

See `guides/recipes/webhook-verification.md` for the full raw request body,
candidate-secret verification, `body_reader`, and `delivery_id` verification
flow.
