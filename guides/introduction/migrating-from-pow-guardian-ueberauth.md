# Migrating from Pow, Guardian, and Ueberauth

This lane is comparative and boundary-first. It is not a drop-in compatibility layer and not an automated migration engine.

## Who should migrate now

Migrate now if you need to converge scattered auth ownership into one explicit Sigra contract while keeping generated-host code review in your control.

Good fit signals:

- Pow session/Plug ownership is becoming hard to evolve with your host app.
- Guardian token-auth posture is only one part of your needed auth surface.
- Ueberauth provider flows need to be aligned with a broader auth/session/audit contract.
- Your team can run staged cutover and rollback drills.

## When not to migrate

Do not migrate yet if:

- Current Pow/Guardian/Ueberauth composition is stable and satisfies your requirements.
- You need immediate zero-risk continuity and cannot absorb generated-host review.
- You expect automatic endpoint-to-endpoint equivalence without policy review.

Migration is optional. If your current stack is already sufficient, deferring migration is a valid and often safer choice.

## Cutover patterns

1. Session-first replacement
2. API-token-first replacement
3. Provider-by-provider OAuth cutover

Recommended order:

- Stabilize session behavior first.
- Migrate token surfaces next.
- Migrate OAuth providers one at a time with clear rollback checkpoints.

## Ownership boundary table

| Ecosystem | Typical ownership center | Sigra comparison boundary |
| --- | --- | --- |
| Pow | Plug/Phoenix session and host-managed auth flow ownership | Sigra keeps core auth in library + generated-host integration responsibilities |
| Guardian | Token-auth issuance/verification focus | Sigra token surfaces are broader-auth context, not a blanket drop-in for every Guardian topology |
| Ueberauth | Provider challenge/callback scope | Sigra uses Assent-backed OAuth while the host still owns provider rollout and policy decisions |

Boundary reminders:

- Pow migration is mainly session/host-flow ownership realignment.
- Guardian migration is token contract and policy realignment.
- Ueberauth migration is provider-by-provider challenge/callback ownership realignment.
- Sigra's generated host files remain host-owned after generation.

## Generated-host review checklist

- Review route and plug pipeline changes for session behavior.
- Review token issuance/verification assumptions where Guardian equivalents existed.
- Review OAuth callback and linking policy where Ueberauth equivalents existed.
- Review mailer/Oban/optional-dependency seams.
- Review audit and privileged-flow boundaries before production cutover.

## Non-goals

Phase 147 does not add compatibility shims, new auth primitives, or a library-owned migration engine.

Also out of scope:

- Automatic Pow-to-Sigra code translation.
- Automatic Guardian claim/policy translation.
- Automatic provider-wide Ueberauth-to-Sigra conversion.

## Rollback posture

If any migration step fails validation:

1. Revert to the pre-cutover commit and dependency posture.
2. Re-apply previous route/token/provider wiring.
3. Roll back DB only according to your migration rollback policy.
4. Resume with smaller slices (one surface at a time).

## Related

- [Contract](contract.html)
- [OAuth, OIDC, and Enterprise Sign-In](../flows/oauth.html)
- [Upgrading to v1.0](upgrading-to-v1.0.html)
