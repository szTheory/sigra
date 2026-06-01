# Sigra Hex 1.0.0 Launch Evidence Bundle

This bundle is the compact attachable evidence page for the Sigra Hex 1.0.0 launch. It routes to canonical proof and states proof boundaries; it does not duplicate the full release runbook, UAT matrix, or demo walkthrough.

## What this bundle covers

- Release gate status and waiver rules.
- Docs warnings-as-errors posture.
- UAT-to-CI coverage boundaries.
- Published-consumer upgrade smoke posture.
- Demo screenshot and evaluator proof.
- Known limitations and proof boundaries.
- Post-publish facts that cannot exist before the real Hex release.
- HexDocs and source-link truth.

## Evidence table

| Evidence area | Canonical source | Status before publish | Post-publish action |
| --- | --- | --- | --- |
| Release gate matrix | [Release runbook v1.0](../../release-runbook-v1-0.md#release-gate-matrix) (`docs/release-runbook-v1-0.md`) | Gate list, ref rules, required evidence, and waiver fields are defined | Fill release-ref run URLs and waiver rows, if any |
| Existing evidence router | [GA evidence and audit posture](../../ga-evidence.md) (`docs/ga-evidence.md`) | Existing router defines canonical release-evidence surfaces and pinned-link policy | Keep this launch bundle aligned with the existing evidence router |
| Docs warnings-as-errors | [Release runbook dry-run and package inspection](../../release-runbook-v1-0.md#dry-run-and-package-inspection) (`docs/release-runbook-v1-0.md`) | `mix docs --warnings-as-errors` is a required publish blocker | Attach release-ref command or CI log |
| UAT-to-CI mapping | [UAT versus CI coverage](../../uat-ci-coverage.md) (`docs/uat-ci-coverage.md`) | Machine-vs-human proof boundaries are documented | Link final release-ref CI jobs where applicable |
| Upgrade smoke | [Upgrading to v1.0](../../../guides/introduction/upgrading-to-v1.0.md) (`guides/introduction/upgrading-to-v1.0.md`) and [upgrade proof](../../uat-ci-coverage.md#v132-upgrade-and-migration-proof) | `CI` / `upgrade_smoke` plus `scripts/ci/upgrade-smoke.sh` define the published-consumer lane | Attach release-ref `upgrade_smoke` run URL |
| Demo screenshot proof | [Demo Showcase](../../../guides/introduction/demo-showcase.md) (`guides/introduction/demo-showcase.md`) | Committed screenshots and seeded personas document evaluator proof and limitations | Keep screenshots tied to the release tag |
| Known limitations | [Sigra 1.0 contract](../../../guides/introduction/contract.md#non-goals), [Demo proof boundary](../../../guides/introduction/demo-showcase.md#proof-boundary-and-limitations), and this page | Non-goals and residual proof boundaries are explicit | Re-check launch copy did not add unsupported claims |
| Hex visibility | [Release runbook post-publish visibility](../../release-runbook-v1-0.md#post-publish-visibility) | Placeholder only | Replace `POST_PUBLISH_HEX_VISIBILITY_URL` after Hex shows `1.0.0` |
| HexDocs/source-link truth | [Release runbook post-publish visibility](../../release-runbook-v1-0.md#post-publish-visibility) and `mix.exs` `source_ref: "v#{@version}"` | Placeholder only | Replace `POST_PUBLISH_HEXDOCS_VERSION_URL` after docs and source links resolve |
| GitHub Release | [Release runbook evidence commands](../../release-runbook-v1-0.md#release-evidence-checklist) | Placeholder only | Replace `POST_PUBLISH_GITHUB_RELEASE_URL` after the release exists |
| Release-ref CI URLs | [Release runbook evidence checklist](../../release-runbook-v1-0.md#release-evidence-checklist) | Placeholder only | Replace `POST_PUBLISH_RELEASE_REF_CI_URLS` with final run URLs |
| Waivers | [Release runbook gate matrix](../../release-runbook-v1-0.md#release-gate-matrix) | No waiver is assumed by this bundle | Any waiver must record gate, reason, approver, evidence URL, and expiry |

## Post-publish placeholders

These tokens are intentionally exact. Do not replace them until the real public release fact exists:

- `POST_PUBLISH_HEX_VISIBILITY_URL`
- `POST_PUBLISH_HEXDOCS_VERSION_URL`
- `POST_PUBLISH_GITHUB_RELEASE_URL`
- `POST_PUBLISH_RELEASE_REF_CI_URLS`

## Pinned release-link policy

For release proof hosted outside the Hex package tarball, use pinned `v1.0.0` links instead of `main` blob URLs. This applies to GitHub-hosted planning artifacts, run logs, screenshots, and any release evidence that would otherwise drift after the release.

Hex package contents and HexDocs pages can use their own package-version URLs once published. GitHub source proof should point at the release tag.

## What this does not prove

This launch evidence does not prove:

- Compliance certification.
- Live provider certification.
- Host deployment warranty.
- Hosted control plane behavior.
- A guarantee over generated-host local modifications after an application changes emitted code.
- Exhaustive behavior of real mail clients, live OAuth providers, tenant-specific policy, or every host deployment topology.

Those boundaries are compatible with the Sigra 1.0 release. They keep the evidence bundle honest about what is machine-proven, what is release-proven, and what remains host-owned.
