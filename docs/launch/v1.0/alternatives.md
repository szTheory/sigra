# Sigra 1.32 Alternatives Comparison

This page compares Sigra's hybrid library-plus-generator model with common Phoenix authentication choices. It is a selection aid, not a claim that Sigra is universally better.

## Comparison axes

Use these axes before choosing or migrating:

- Ownership model: who owns runtime behavior, generated code, provider wiring, and later edits.
- Scope coverage: which auth surfaces are covered by the chosen stack.
- Migration or cutover risk: how much route, schema, template, session, token, and policy review is needed.
- Operational burden: which parts your team must run, observe, patch, and support.
- Upgrade ergonomics: whether fixes arrive by dependency update, local generator changes, hosted-provider rollout, or app-specific edits.

## Ownership boundary table

| Option | Best fit | Ownership model | Scope coverage | Migration or cutover risk | Operational burden | Upgrade ergonomics |
| --- | --- | --- | --- | --- | --- | --- |
| `phx.gen.auth` | Teams that want the official minimal generated baseline and can own auth locally | Host-owned generated Phoenix code | Focused Phoenix auth baseline | Low when starting greenfield; higher when replacing established custom flows | Host owns ongoing security, UX, policy, and patch review | Generator output is copied into the app; later changes are host-managed |
| Pow plus Guardian plus Ueberauth-style composition | Existing stable apps whose composed stack already satisfies requirements | Multiple package seams plus host glue | Pow session flows, Guardian token-toolkit concerns, Ueberauth provider challenge/callback concerns | Varies by how much the app has customized each library seam | Host operates composition, compatibility, provider behavior, and local policy | Updates happen per dependency and host integration layer |
| Hosted auth | Teams that prefer managed operations over in-repo control | Provider-owned service with host integration | Depends on provider and plan | Cutover can be high, especially for data, sessions, and provider lock-in | Provider handles much of the platform; host owns integration and product policy | Provider rollout plus SDK/config updates |
| Sigra's hybrid model | Phoenix 1.8+ teams that want updateable library-owned auth primitives and inspectable generated host code | Library-owned sensitive core plus generated-host-owned application code | Sessions, passwords, email flows, OAuth, MFA, passkeys, optional organizations/admin/audit seams according to installed slices | Requires intentional generated-host review; not an automated conversion path | Host owns deployment, UX, policy, authz, and local modifications; Sigra owns versioned library behavior | Security-sensitive fixes can ride `mix deps.update`; generated code remains reviewable in the host |

## Boundary reminders

- `phx.gen.auth` is the official minimal generated baseline. Staying there is a valid choice when host-owned auth flows are already sufficient.
- Guardian is token-toolkit oriented. It can remain a good fit when token issuance/verification is the main concern and the surrounding auth system is already stable.
- Ueberauth is provider-challenge oriented. It remains useful when provider-specific OAuth challenge/callback plumbing is the scoped problem.
- Pow-style stacks may still fit stable existing apps, especially where migration risk outweighs the value of a new contract.
- Hosted auth is valid when managed operations matter more than in-repo control; in this page, "hosted auth" means an external managed identity provider rather than repo-owned Phoenix auth code.
- Sigra's hybrid model is strongest when the team wants Phoenix-native code ownership plus an updateable auth library core.

For migration detail, use [Migrating from phx.gen.auth](../../../guides/introduction/migrating-from-phx-gen-auth.md) and [Migrating from Pow, Guardian, and Ueberauth](../../../guides/introduction/migrating-from-pow-guardian-ueberauth.md).

## When not to choose Sigra

Do not choose Sigra yet if:

- Your current auth stack is stable, sufficient, and low-risk.
- You need a hosted identity product or managed control plane.
- You cannot review generated-host code before rollout.
- You need compatibility shims that exactly preserve another stack's route, token, provider, or database behavior.
- You need compliance certification, live provider certification, SCIM, or a general authorization engine as part of the auth package.
- Your team expects migration to be fully automatic.

## What this comparison does not claim

This comparison does not claim ecosystem equivalence, automatic migration, hosted-auth replacement, provider certification, compliance certification, or universal superiority over other Phoenix authentication choices. It narrows the decision to ownership, scope, risk, operations, and upgrade posture.

Use the [Sigra 1.0 contract](../../../guides/introduction/contract.md) for package guarantees and non-goals.
