# Generated Host Proof

Canonical admin and receiver proof for the full `user.created` secret-rotation lifecycle.

- Run at: 2026-05-07T14:35:50.321Z
- Proof user prefix: generated-proof-user-1778164547471@example.test
- Subscription ID: 09acaf80-6ee1-41f1-89db-d216a9ebce04
- Admin endpoint: http://localhost:4000/webhooks/sigra
- Admin subscription screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-secret-rotation/screenshots/subscription-detail.png

## Lifecycle stages

### pre_rotation

- delivery_id: bd67036f-a0b5-4932-afac-9fa21d916194
- event_type: user.created
- event_id: 95f7c735-6ecb-403a-8a5c-c7f5de05353f
- delivery_status: delivered
- receiver verified_at: 2026-05-07T14:35:48.000000Z
- receiver signature timestamp: 1778164548
- receiver raw_body_sha256: 8546ecc1e747256a8dc4c443ea0df2b875c155622f5330af81e64f8483173197
- admin delivery screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-secret-rotation/screenshots/pre_rotation-delivery-detail.png

### overlap

- delivery_id: b88d80d1-2b14-4b9f-b4a2-2aac7c4195b7
- event_type: user.created
- event_id: cade413e-49c1-4183-8631-85ba04e1d960
- delivery_status: delivered
- receiver verified_at: 2026-05-07T14:35:49.000000Z
- receiver signature timestamp: 1778164549
- receiver raw_body_sha256: 15d985d76424bdcbd69d0d59b26cfefe62f4767e3eec359382a5a3dc43741052
- admin delivery screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-secret-rotation/screenshots/overlap-delivery-detail.png

### post_retirement

- delivery_id: 1abf957c-838f-4243-9f32-eb06652ea8b6
- event_type: user.created
- event_id: ded0f5ec-485f-44bd-a201-4b58293860b6
- delivery_status: delivered
- receiver verified_at: 2026-05-07T14:35:50.000000Z
- receiver signature timestamp: 1778164550
- receiver raw_body_sha256: 8045475ebe8b5f5be34810ee25c0b3acfb52c796ed06c1b96e7b22a5b88c2593
- admin delivery screenshot: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-secret-rotation/screenshots/post_retirement-delivery-detail.png

Artifacts:
- machine manifest: manifest.json

This evidence bundle correlates pre-rotation, overlap, and post-retirement deliveries across the admin and receiver lanes on stable delivery_id values.
