# Generated Host Replay Proof

Canonical admin and receiver proof for the fail -> inspect -> repair -> replay recovery flow.

- Run at: 2026-05-09T03:12:08.134Z
- Proof user prefix: generated-replay-proof-user-1778296322718@example.test
- Subscription ID: b5af797a-c902-4d0e-83b9-6de6afb7783e
- Admin endpoint: http://localhost:4017/webhooks/sigra
- Admin subscription screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png

## Delivery lineage

- source delivery id: 2d81f944-b7a6-4cb3-a212-08f16b98ede5
- replay delivery id: f41f3fe5-f62f-476e-b48c-5b5ee76ae749
- root delivery id: 2d81f944-b7a6-4cb3-a212-08f16b98ede5
- source delivery status: dead_lettered
- replay delivery status: delivered

## Receiver verification

- source delivery receiver verification: verified_at=2026-05-09T03:12:05.000000Z, signature_timestamp=1778296325, raw_body_sha256=1c59c74acaffddb6595274450ff2cae7f11a71d510d4f12ecb80189ea7ed0ee9
- replay delivery receiver verification: verified_at=2026-05-09T03:12:07.000000Z, signature_timestamp=1778296327, raw_body_sha256=1c59c74acaffddb6595274450ff2cae7f11a71d510d4f12ecb80189ea7ed0ee9

## Screenshots

- failed source row: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/failed-source-row.png
- source delivery detail: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/source-delivery-detail.png
- replay delivery detail: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/replay-delivery-detail.png

Artifacts:
- machine manifest: manifest.json

This evidence bundle correlates the original failed source row and the replay child row across admin history and receiver verification while keeping `delivery_id` dedupe truthful.
