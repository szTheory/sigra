# Generated Host Replay Proof

Canonical admin and receiver proof for the fail -> inspect -> repair -> replay recovery flow.

- Run at: 2026-05-08T01:24:22.208Z
- Proof user prefix: generated-replay-proof-user-1778203456551@example.test
- Subscription ID: 1fc8f661-cf46-45ca-aaf3-fad2c36f39cb
- Admin endpoint: http://localhost:4000/webhooks/sigra
- Admin subscription screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/subscription-detail.png

## Delivery lineage

- source delivery id: c388bb94-7e5c-4587-adee-3f9c33100685
- replay delivery id: 389bb1d8-b94d-4f04-b2f2-b85217832edc
- root delivery id: c388bb94-7e5c-4587-adee-3f9c33100685
- source delivery status: dead_lettered
- replay delivery status: delivered

## Receiver verification

- source delivery receiver verification: verified_at=2026-05-08T01:24:19.000000Z, signature_timestamp=1778203459, raw_body_sha256=01128230807efc4ef54b5eace874085ad7b49d51b41dceda21670a7b9f46ebc8
- replay delivery receiver verification: verified_at=2026-05-08T01:24:21.000000Z, signature_timestamp=1778203461, raw_body_sha256=01128230807efc4ef54b5eace874085ad7b49d51b41dceda21670a7b9f46ebc8

## Screenshots

- failed source row: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/failed-source-row.png
- source delivery detail: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/source-delivery-detail.png
- replay delivery detail: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/screenshots/replay-delivery-detail.png

Artifacts:
- machine manifest: manifest.json

This evidence bundle correlates the original failed source row and the replay child row across admin history and receiver verification while keeping `delivery_id` dedupe truthful.
