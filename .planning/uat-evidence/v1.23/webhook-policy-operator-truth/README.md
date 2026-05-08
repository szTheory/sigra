# Webhook Policy Operator Truth Proof

Blocked destination proof for the generated-host operator workflow.

- Run at: 2026-05-08T01:24:24.836Z
- blocked delivery id: f030c39b-eb31-4b9d-b9ce-fe8ff6c1cda0
- endpoint url: http://localhost:4000/webhooks/sigra
- delivery status: dead_lettered
- policy reason: policy_denied
- policy detail: blocked by deployment callback

## Operator surfaces

- Failures inbox row shows `Blocked by local policy`
- Delivery detail shows `Endpoint policy result`

## Screenshots

- failures row: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-policy-operator-truth/screenshots/blocked-failures-row.png
- delivery detail: /Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-policy-operator-truth/screenshots/blocked-delivery-detail.png

Artifacts:
- machine manifest: manifest.json
