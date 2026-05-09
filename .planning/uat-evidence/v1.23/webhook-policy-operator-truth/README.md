# Webhook Policy Operator Truth Proof

Blocked destination proof for the generated-host operator workflow.

- Run at: 2026-05-09T03:12:11.246Z
- blocked delivery id: 48a91128-6cc9-4c30-86d7-98804850872a
- endpoint url: http://localhost:4017/webhooks/sigra
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
