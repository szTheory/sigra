# B2C Alpha readiness

This recipe is the supported starting point for a single-user Phoenix product
that needs email/password, magic-link, and Google sign-in without Sigra's
organizations, passkeys, or admin surface.

```bash
mix sigra.install --yes Accounts User users \
  --no-admin --no-organizations --no-passkeys
mix sigra.gen.oauth --providers google
```

The generated login page retains email/password and magic-link sign-in. Google
OAuth is configured as the generated controller flow; do not add `--live`
unless the host intentionally owns that UI variation.

## Pre-production rehearsal

Before inviting an alpha user, run all of these against a staging origin that
matches the intended public host:

1. Set `PHX_HOST`, TLS/proxy settings, `Endpoint.url`, and Phoenix session
   cookie settings consistently. Use a host-only cookie unless the product
   deliberately needs subdomain sharing.
2. Configure `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and register the
   exact `https://<host>/auth/google/callback` redirect URI. Keep secrets out
   of source control and test output.
3. Configure a host-owned Swoosh adapter. Deliver confirmation, reset, and
   magic-link messages to a controlled recipient; test the links on a clean
   browser session.
4. Set `CLOAK_KEY`, run `mix sigra.doctor --quiet`, and confirm the configured
   rate limits for login, reset, and magic-link requests are appropriate for
   the launch environment.
5. On iPhone, complete sign-in in the hosted Phoenix browser/session and
   return through HTTPS. The server session remains the authority; no OAuth
   token, credential, or custom deep-link is an application session.

## Crosswake hosted-session boundary

When the host uses `crosswake_sigra`, project a validated SIGRA session into
the companion's `SessionAuthorityLane`. For this profile use `org_id: nil`: it
means a personal account, not a fabricated organization. Keep `session_ref`
and `subject_ref` opaque and server-owned. Crosswake can use the projection to
admit a route or replay, but it must deny missing, expired, revoked, or
account-switched sessions. OAuth callback data remains evidence for the
server-owned session attempt; it never becomes shell authority.

For the broader deployment checklist, see [Deployment](deployment.md).

## Automated boundary

`scripts/ci/passkeys-opt-out-smoke.sh` includes the `sigra_b2c_alpha` fresh
Phoenix leg. It proves the exact generator shape, Google OAuth generation,
compile, assets build, migration, and application boot without credentials.
Real Google and transactional-email delivery remain staging launch gates.
