# Migrating from phx.gen.auth

This guide is boundary-first. It is not a drop-in migration promise and not an automated conversion path. Use it to decide ownership boundaries, risk, and whether migration is actually needed.

## Who should migrate now

Migrate now if most of the following are true:

- You want Sigra's library-owned auth substrate while still owning generated host code.
- You need one package surface covering sessions, token flows, magic links, MFA/passkeys, and audit seams.
- You are ready to review generated-host diffs intentionally rather than expecting full automation.
- Your team wants explicit upgrade paths (`mix sigra.upgrade`) and contract framing from `contract` docs.

## Who should not migrate yet

Do not migrate yet if any of the following are true:

- Your current `phx.gen.auth` host-owned flows are already sufficient and low-risk.
- You cannot allocate time for generated-host review and cutover testing.
- You expect a zero-touch drop-in swap with no route/session/template implications.
- Your release window cannot tolerate migration risk right now.

Migrating is not required. Staying on `phx.gen.auth` is safer when host-owned auth flows are already sufficient for your product and risk posture.

## Model mapping

| Concern | phx.gen.auth posture | Sigra posture | Boundary to review |
| --- | --- | --- | --- |
| `current_scope` | Phoenix 1.8 auth generator centers request/user scope | Sigra generated host also uses `current_scope` patterns | Ensure your scope assumptions and assigns usage remain consistent |
| Sessions | Session/token flow is host generated and host maintained | Session behavior comes from Sigra + generated host integration | Review session create/delete hooks and remember-me/cookie behavior |
| Tokens | Host handles reset/confirm token behavior from generated code | Sigra provides library token primitives plus generated host wiring | Validate token lifecycle assumptions and host callback seams |
| Email confirmation posture | Host owns generator-confirm flow | Shared: Sigra surfaces + host mail/config wiring | Verify delivery and confirmation routes in your host app |
| magic links | Phoenix 1.8 generator supports magic-link patterns | Sigra also supports magic link flows in its generated surface | Confirm route/copy/policy expectations for magic-link auth |
| sudo mode | Phoenix 1.8 includes sudo mode boundaries | Sigra includes sudo mode surfaces in generated host paths | Re-check privileged action gates and timeout policies |

## Adoption sequence

1. Baseline your app: compile, test, and document current auth behavior.
2. Move dependency posture to Sigra target line and fetch deps.
3. Generate/apply Sigra upgrade output in a branch.
4. Run DB migrations and compile with warnings-as-errors.
5. Compare auth routes, session behavior, token flows, magic-link paths, and sudo mode behavior.
6. Run focused regression tests plus manual login/logout/privileged-flow smoke.
7. Promote only after rollback plan is validated.

## Generated-host review checklist

- Confirm router and pipeline boundaries still match your desired auth posture.
- Confirm `current_scope` assignments are used consistently across controllers and LiveViews.
- Confirm sessions and remember-me behavior are intentional.
- Confirm reset/confirm/token flows match your existing policy and UX.
- Confirm magic-link and sudo mode boundaries are not silently widened.
- Confirm host-owned callbacks/integration seams are still wired.

## Rollback posture

Keep the first production cutover narrow: migrate one deployable auth surface at a time, then observe sessions, token emails, and privileged-action gates before widening scope.
If a route or token behavior is ambiguous, keep the `phx.gen.auth` path live until Sigra behavior is proven equivalent for that app.

If migration validation fails:

1. Revert to pre-migration commit and dependency line.
2. Roll back DB only per your migration safety policy.
3. Restore pre-migration host routes/templates if needed.
4. Retry in a narrower slice (sessions first, then token/email, then privileged gates).

## Related

- [Contract](contract.html)
- [Login and logout](../flows/login-and-logout.html)
- [Upgrading to v1.0](upgrading-to-v1.0.html)
