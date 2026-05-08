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
7. Customize `webhook_endpoint_policy/1` in your generated accounts module if
   your deployment needs an app-layer allowlist or extra deny rules.
8. Pair that callback with platform egress controls such as Kubernetes
   `NetworkPolicy`, Fly.io egress IP allowlisting, or Fly.io network policies.
9. Trigger real Sigra events after setup and confirm deliveries in the
   generated admin webhook history.
10. If a blocked delivery ever dead-letters, confirm admin history shows
    `local_policy_error` plus the stable reason/detail you expect.
11. If a delivery ever dead-letters for another reason, use the Sigra admin UI replay action as a
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

For deployment-specific outbound controls, edit `webhook_endpoint_policy/1` in
your generated accounts module and keep it aligned with your infrastructure
allowlist story.
