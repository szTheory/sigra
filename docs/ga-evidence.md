# Release evidence router

This page routes maintainers and reviewers to the canonical release-evidence surfaces for the Sigra 1.32 path.
It does not duplicate the release gate matrix.

## Canonical sources

- [Release runbook v1.32](release-runbook-v1-0.html) — canonical release gate matrix, release-ref evidence checklist, dry-run/package inspection, publish paths, recovery decision tree, post-publish visibility checks, and first-14-day hotfix policy.
- [UAT ↔ CI coverage](uat-ci-coverage.html) — machine-vs-human coverage mapping for proof posture.
- [Maintaining](maintaining.html) — stable maintainer entry point and release automation index.

## Upgrade and migration proof

- [Upgrading to v1.0](upgrading-to-v1.0.html)
- [Migrating from phx.gen.auth](migrating-from-phx-gen-auth.html)
- [Migrating from Pow, Guardian, and Ueberauth](migrating-from-pow-guardian-ueberauth.html)
- Canonical machine proof for published-consumer upgrade posture: `CI` / `upgrade_smoke` plus `scripts/ci/upgrade-smoke.sh`. The harness defaults to the latest published 1.x source series and can be retargeted with `SIGRA_UPGRADE_SOURCE_SERIES` when live Hex package truth has moved on.

## GitHub-hosted proof links policy

For release proof hosted outside the Hex package tarball (for example `.planning/` artifacts on GitHub), use pinned `v<version>` links.
Do not use `main` blob URLs for release evidence.

Examples:

- Good: `https://github.com/szTheory/sigra/blob/v1.32.0/.planning/...`
- Not allowed for release proof: `https://github.com/szTheory/sigra/blob/main/.planning/...`

## Related docs

- [Contributing](contributing.html)
- [Security policy](security.html)
- [Audit semantics](audit-semantics.html)
