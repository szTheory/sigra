# Feature Research — v1.22 Webhooks

## Core event-delivery features

### Table stakes

- subscription registry with endpoint URL, secret, enabled/disabled status
- event type selection per subscription
- signed payload delivery over HTTPS
- stable delivery identifier for replay and correlation
- durable delivery log with status

### Differentiators for Sigra

- auth-native event catalog tied to Sigra concepts: user lifecycle, MFA, org membership, API tokens, service accounts, suspicious-login/security flows
- generator-owned host UX instead of "wire it yourself"
- alignment with Sigra audit semantics so emitted events and stored audit records tell a coherent story

## Reliability features

### Table stakes

- async dispatch
- bounded retries
- dead-letter state after exhaustion
- per-attempt error visibility

### Useful v1.22 scope line

- enough operational history to debug failures
- not a full external event bus or generalized workflow engine

## Admin UX features

### Table stakes

- create/edit/disable subscription
- rotate secret
- inspect recent deliveries
- filter by status or event type

### Defer

- full replay tooling
- tenant-wide analytics dashboards
- public self-service subscriber portal
