# B2C Alpha readiness

This is the single launch checklist for a provider-neutral, personal-account
Phoenix product using email/password, magic-link, and the generated Google
OAuth flow. It separates what the Sigra repository can prove from what the
host operator must configure and rehearse. Complete the tiers in order; a
later tier is not satisfied by an earlier one.

Start a canonical B2C host with:

```bash
mix sigra.install --yes Accounts User users \
  --no-admin --no-organizations --no-passkeys
```

OAuth token storage is deliberately host-owned. Before generating the Google
flow, add the required direct dependency to the host application's `deps/0` in
`mix.exs`:

```elixir
{:cloak_ecto, "~> 1.3"}
```

Then fetch it and generate OAuth:

```bash
mix deps.get
mix sigra.gen.oauth --providers google
```

The generated login page retains email/password and magic-link sign-in. Google
OAuth uses the generated controller flow; do not add `--live` unless the host
intentionally owns that UI variation.

## Library CI proof

### Credential-free generated-host proof

**Owner:** Sigra repository CI.

**Action:** Run `scripts/ci/passkeys-opt-out-smoke.sh` and the generated-auth
runtime proof. They create a disposable canonical B2C host, generate the
Google flow, compile, build assets, migrate, boot, and exercise local auth
behavior without live provider or mail credentials.

**Expected result:** The fresh-host and local OIDC-double suites pass with
inherited Google credentials unset. This proves generator shape, local
state/PKCE/callback behavior, rendered B2C auth behavior, and bounded local
rate-limit behavior.

**Must not claim:** A real Google Console registration, provider tenant,
transactional mail provider, DNS/TLS deployment, reverse proxy, or physical
device works. Disposable `CLOAK_KEY` and local OIDC client-secret fixtures are
not deployment credentials.

**Recovery:** Treat a failure as generator or local-runtime drift. Repair and
re-run CI; do not add host secrets or provider payloads to CI output.

### Limiter boundary proof

**Owner:** Sigra repository CI.

**Action:** Exercise the generated Hammer limiter with a host-injected test
bound. The generated login route defaults to three requests per 60 seconds and
hosts may override both the request ceiling and millisecond window through
their `:sigra` configuration.

**Expected result:** The probe permits one below, at, and denies one above the
configured bound without waiting across a window. A route-owned denial is a
generic `429` with positive, ceiling-rounded whole-second `Retry-After`;
1,000ms becomes 1 second and 1,001ms becomes 2 seconds.

**Must not claim:** The default is an adopter traffic policy, client IP has
been normalized by a real proxy, or a provider's sub-second timing has been
measured. The repository proves only the configured local boundary and
millisecond-to-whole-second rounding contract.

**Recovery:** Tune the host's configured limit and window for expected traffic,
then repeat the host rehearsal below. Never hide a throttle failure by removing
the explicit generated limiter.

## Host pre-deploy

### Canonical origin and secure session tuple

**Owner:** Host operator.

**Action:** Record one literal tuple before deployment:

```text
Public origin: https://<canonical-host>
Endpoint.url: https://<canonical-host>:443
Trusted proxy policy: accept forwarded scheme and client-IP only from trusted proxies
Cookie Domain attribute: absent (host-only)
Cookie flags: Secure; HttpOnly; SameSite=Lax
```

Use exactly one canonical HTTPS public origin and make `Endpoint.url` match it.
Configure the reverse proxy to normalize forwarded scheme and client-IP only
from its trusted peer; never trust arbitrary client-supplied forwarding headers.
Keep the Phoenix session host-only by leaving the Domain attribute absent.
Shared cookie domains or `SameSite=None` are host deviations that need a
documented architecture rationale before use.

**Expected result:** A clean browser reaches the canonical HTTPS URL, retains a
host-only secure session through the intended sign-in flow, and observes the
configured throttling behavior from the trusted-proxy path.

**Must not claim:** Local tests or `Endpoint.url` configuration prove public
TLS, proxy correctness, forwarding-header trust, or a deployed cookie posture.

**Recovery:** For redirect loops, recheck HTTPS termination and the canonical
origin. For lost sessions, return to a host-only cookie first; broaden Domain
or SameSite only after recording the host-specific reason.

### Runtime wiring and boot

**Owner:** Host operator.

**Action:** In the platform secret store, supply runtime-only `SECRET_KEY_BASE`,
`CLOAK_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and mailer
configuration. Configure the generated Vault, boot the application, then run:

```bash
mix sigra.doctor --quiet
```

Register exactly this Google callback in the Google Console:

```text
https://<canonical-host>/auth/google/callback
```

**Expected result:** The application and Vault boot, and Doctor exits 0 for
configured dependency wiring (or exits 1 for configured-but-broken wiring).
Doctor is configuration/dependency evidence only.

**Must not claim:** Doctor establishes external credential acceptance, provider availability,
public TLS/proxy correctness, key validity or rotation readiness,
transactional delivery, or device behavior. Do not place secret values,
token-bearing URLs, mail bodies, or provider payloads in logs.

**Recovery:** Correct the missing or mismatched runtime configuration, restart
the host, and re-run Doctor. Keep values in the platform secret store rather
than the repository or receipt.

### Host mail and limiter readiness

**Owner:** Host operator.

**Action:** Select and configure the host mailer, then set the generated
limiter's request ceilings and millisecond windows for launch traffic. Each key
is read at request time, so place the following values in `config/runtime.exs`
when the release's policy differs from the conservative `3` per `60_000ms`
default: `:login_rate_limit`, `:login_rate_limit_window`,
`:sudo_rate_limit`, `:sudo_rate_limit_window`, `:registration_rate_limit`,
`:registration_rate_limit_window`, `:confirmation_request_rate_limit`,
`:confirmation_request_rate_limit_window`, `:confirmation_resend_rate_limit`,
`:confirmation_resend_rate_limit_window`, `:reset_request_rate_limit`,
`:reset_request_rate_limit_window`, `:reset_update_rate_limit`,
`:reset_update_rate_limit_window`, `:mfa_rate_limit`, `:mfa_rate_limit_window`,
`:magic_link_rate_limit`, `:magic_link_rate_limit_window`, `:reset_rate_limit`,
and `:reset_rate_limit_window`. Preserve the generated defaults unless an
explicit host policy replaces them.

**Expected result:** The host can boot with its selected mailer and explicit
rate-limit configuration; the configuration fingerprint is ready to record
without exposing values.

**Must not claim:** A successful boot proves mail delivery, recipient access,
provider acceptance, or effective client-IP handling through a real proxy.

**Recovery:** Correct configuration references and re-run Doctor. Delivery and
proxy behavior remain staging work, not a repository-pass condition.

## Staging launch gate

### Real provider and controlled mail rehearsal

**Owner:** Host operator.

**Action:** Against the canonical HTTPS staging host, complete real Google
authorization using the registered
`https://<canonical-host>/auth/google/callback`. Deliver confirmation, reset,
and magic-link messages to a controlled-recipient, controlled recipient mailbox and consume every
message in a clean browser.

**Expected result:** Each controlled user-visible flow completes at the staging
origin and the operator records an outcome-only receipt.

**Must not claim:** repository CI cannot mark this passed. A local OIDC double,
Doctor, or a generated-host test is not real Google authorization or controlled
mail delivery evidence.

**Recovery:** Check the exact callback registration, recipient routing, and
canonical origin; repeat only the failed staging flow after correction.

### Physical-device hosted return

**Owner:** Host operator.

**Action:** On a physical iPhone, complete sign-in in the HTTPS hosted-browser
session and verify the hosted-browser return reaches the canonical origin.

**Expected result:** The server-owned session remains authoritative after the
physical iPhone HTTPS hosted-browser return; no OAuth token, credential, or
custom deep-link becomes an application session.

**Must not claim:** Repository CI cannot mark this passed, and browser emulation
does not prove a physical iPhone, deployed HTTPS, or native/deep-link behavior.

**Recovery:** Recheck the deployed HTTPS origin and hosted-browser navigation.
Keep session resolution on the server; do not work around a failed return by
passing credentials to a device.

### Trusted-proxy and clean-browser session rehearsal

**Owner:** Host operator.

**Action:** From a clean browser through the real trusted proxy, repeat the
canonical sign-in path and intentionally observe one configured throttle
boundary without recording request contents.

**Expected result:** The canonical URL, host-only `Secure`/`HttpOnly`/
`SameSite=Lax` session, and generic throttle behavior match the recorded tuple.

**Must not claim:** This proves all future traffic patterns or provides a reason
to accept untrusted forwarded headers.

**Recovery:** Correct the trusted-proxy allow-list, canonical URL, or session
tuple and rerun the clean-browser rehearsal.

## Redacted staging receipt

One receipt is required for each staging-gate row. It records outcomes, not
operational material:

```text
Outcome: pass | fail | blocked
Timestamp: 2026-08-10T00:00:00Z
Environment: staging-alpha
Configuration fingerprint: non-sensitive version/config identifier
Operator sign-off: initials or approved operator identifier
```

The receipt must exclude secret values, token-bearing URLs, mail bodies,
provider payloads, raw request/response bodies, credentials, and full internal
host configuration. A receipt is host evidence, not a repository-pass marker.

## Detailed mechanics

[Deployment](deployment.md) explains the supporting environment, cookie,
mailer, rate-limit, and Doctor mechanics. It is not a second B2C launch
checklist: use this recipe for readiness decisions.

## Crosswake hosted-session boundary

When the host uses the released `crosswake_sigra` `~> 0.1.3` companion,
project a freshly validated SIGRA session into its `SessionAuthorityLane`. For
this profile use `org_id: nil`: it means a personal account, not a fabricated
organization. Keep opaque `session_ref`, `subject_ref`, and session version
server-owned; do not send a raw session credential, stored digest, provider
payload, or OAuth credential to Crosswake.

Every projection and replay repeats canonical database resolution of the
current SIGRA session and user, validates currentness/time, and compares the
server-owned binding before it constructs Crosswake facts. Missing, revoked,
expired, mismatched, or account-switched state denies. A released
`AuthReturn` envelope can carry approved hosted-return evidence/navigation, but
it cannot select a session, replace fresh host resolution, grant authority, or
admit a route on its own. The adapter returns that approved evidence only in
its `evidence` result field; it never merges it into the lane, context,
evaluator options, or route decision.

The executable host contract is covered by:

```bash
cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs
```
