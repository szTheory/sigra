# Pitfalls Research — v1.22 Webhooks

## Main failure modes

- **Blocking auth on remote delivery**
  - webhook endpoints are unreliable; auth operations must not depend on synchronous receiver success
- **Publishing unstable internal shapes**
  - raw audit-row or changeset internals make a poor long-term webhook contract
- **Weak signing or ambiguous verification**
  - signature format must be explicit, deterministic, and documented
- **No idempotency story**
  - receivers need a stable delivery or event identifier to deduplicate retries
- **Silent failure**
  - if retries exhaust without durable history, adopters cannot trust the system

## Sigra-specific pitfalls

- tying webhook delivery too tightly to optional-dep behavior without clear first-use errors
- leaking host-specific business assumptions into the event catalog
- treating webhooks like email notifications instead of systems integration
- burying webhook management in custom host code instead of using the generated admin surface

## Prevention strategy

- outbox-style persistence before remote delivery
- explicit signed payload contract
- per-attempt history and dead-letter visibility
- minimal v1.22 event catalog focused on auth and identity facts
- generator-backed admin UX so adopters can discover and operate the feature
