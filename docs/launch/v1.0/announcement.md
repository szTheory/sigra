# Sigra Hex 1.0.0 Announcement

Sigra Hex 1.0.0 is the stability and trust release for Phoenix 1.8+ authentication teams that want normal Phoenix code in their application and an updateable security core from Hex.

This page is the canonical repo-owned launch narrative. External release notes, GitHub Release copy, blog posts, and maintainer announcements should link here instead of inventing a separate product story.

## Problem framing

Phoenix teams have good generated-code ergonomics, but authentication does not stay static after the first scaffold. Password hashing, sessions, token flows, magic links, MFA, OAuth, passkeys, audit hooks, optional background work, and deployment boundaries keep changing after the host app has already customized its user experience.

Sigra 1.0 targets that gap for Phoenix 1.8+ applications. The package gives teams a Phoenix-native auth substrate while keeping generated host modules reviewable and editable in the application repository. For the exact package, stack, ownership, SemVer, security, and non-goal boundaries, use the [Sigra 1.0 contract](../../../guides/introduction/contract.md).

## Why Sigra's hybrid model

Sigra is a library plus generators:

- Library-owned security-sensitive behavior can receive fixes through `mix deps.update`.
- Generated host code remains ordinary Phoenix code in your app, including schemas, routes, LiveViews, templates, mailers, product policy, and local UX.
- Shared seams such as mail delivery, OAuth providers, Oban/background work, audit forwarding, and host policy hooks stay explicit instead of hidden behind a hosted control plane.

That hybrid model is meant to reduce the long-term cost of "copy a scaffold once, then own every auth edge forever" without replacing the host application's responsibility for integration, authorization, deployment, and local modifications.

## What changed at Hex 1.0.0

The public 1.0 line locks Sigra's package contract around Phoenix 1.8+, generated-host ownership, security invariants, SemVer/deprecation policy, upgrade guidance, migration lanes, demo proof, release gates, and evidence routing.

For teams upgrading from earlier Sigra lines, follow [Upgrading to v1.0](../../../guides/introduction/upgrading-to-v1.0.md) for the historical major-line cutover guidance, then apply the current release notes. For teams evaluating a move from another Phoenix auth posture, start with [Migrating from phx.gen.auth](../../../guides/introduction/migrating-from-phx-gen-auth.md) or [Migrating from Pow, Guardian, and Ueberauth](../../../guides/introduction/migrating-from-pow-guardian-ueberauth.md).

## Explicit non-goals

Sigra Hex 1.0.0 does not claim to provide:

- A hosted control plane or managed identity product.
- Compliance certification, live provider certification, or a host deployment warranty.
- A general authorization engine, RBAC system, or Zanzibar-style policy layer.
- SCIM support in the 1.0 release.
- A public RC train by default.
- Automatic migration from other auth stacks.
- Coverage for arbitrary generated-host local modifications after your app changes emitted code.

Those boundaries are part of the release, not omissions from the announcement.

## Proof links

Use these proof surfaces when evaluating or announcing the release:

- [Launch evidence bundle](evidence.md) - compact evidence router for release gates, docs proof, UAT-to-CI mapping, upgrade smoke, demo proof, post-publish placeholders, and proof boundaries. Repo path: `docs/launch/v1.0/evidence.md`.
- [Release runbook v1.0](release-runbook-v1-0.html) - maintainer release gate matrix, publish checks, recovery path, and first-14-day hotfix policy. Repo path: `docs/release-runbook-v1-0.md`.
- [Demo Showcase](../../../guides/introduction/demo-showcase.md) - runnable evaluator-first Vaultr example app with committed screenshots and explicit proof limitations. Repo path: `guides/introduction/demo-showcase.md`.
- [Sigra 1.0 contract](../../../guides/introduction/contract.md) - installable package truth, ownership boundaries, SemVer policy, security invariants, and non-goals. Repo path: `guides/introduction/contract.md`.

## Who should upgrade now

Upgrade now if most of these are true:

- You are already on an earlier Sigra line and can run the [v1.0 upgrade guide](../../../guides/introduction/upgrading-to-v1.0.md) plus current release notes in a branch. Repo path: `guides/introduction/upgrading-to-v1.0.md`.
- You want the selected Hex `1.0.0` contract line for Phoenix 1.8+ auth.
- Your team is ready to review generated-host diffs intentionally before deployment.
- Your release process can run compile, docs, focused tests, upgrade smoke, and a minimal manual boot smoke.
- You value library-owned security-sensitive behavior while keeping application policy and UX in the host.

## Who should wait

Wait or stay on your current stack if any of these are true:

- Your current `phx.gen.auth`, Pow/Guardian/Ueberauth, or hosted-auth posture is stable and sufficient.
- You need a zero-touch swap with no route, session, template, schema, mailer, OAuth, or deployment review.
- You need a hosted identity product, compliance attestation, live provider certification, or SCIM as a release blocker.
- Your release window cannot absorb generated-host review and rollback planning.

For tradeoffs, use the [alternatives comparison](alternatives.md). It is deliberately boundary-first and includes cases where Sigra is not the right choice. Related migration lanes live at `guides/introduction/migrating-from-phx-gen-auth.md` and `guides/introduction/migrating-from-pow-guardian-ueberauth.md`.

## First-14-day adopter triage

The release runbook defines the first-14-day hotfix policy for Hex `1.0.0`: P0/P1 issues are same-business-day triage, P2 issues are reviewed within 24 hours, and P3 polish is batched into planned patch work. Every intake needs a repro command/ref, failing run URL or log, affected version, and workaround status.

See the [Release runbook v1.0](release-runbook-v1-0.html#first-14-days-hotfix-policy) for the canonical severity and patch decision boundaries.
