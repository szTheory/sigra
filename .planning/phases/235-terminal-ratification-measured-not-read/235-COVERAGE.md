# Phase 235 external evidence coverage

## Capability declaration

- `frontend=false`
- `schema=false`
- `product_api=false`
- `external_evidence_api=true`

This closure adds a protected GitHub Actions evidence path, not a product API or a `ci.yml` required-check edge.

## GitHub capability inventory

| Capability | Actor and request | Retained sanitized evidence | Deterministic seam | Blocking failure / operational rule |
| --- | --- | --- | --- | --- |
| Core budget preflight | Main-only workflow token; `gh api rate_limit --jq .resources.core.remaining` | Integer remaining budget only | Fake `gh` records exactly one preflight | Remaining `<=250`, malformed result, 403, or 429 stops immediately; no retry. |
| Workflow-run pages | `GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs?created=2026-08-01T02:06:30Z..2026-08-02T18:07:04Z&per_page=100&page=N` | Page number, total count, public run IDs/events/times/conclusions | Production collector via fake `gh` | Missing/duplicate page, changed total, duplicate ID, incomplete population, cap hit, or inverted time fails closed. |
| Per-run job pages | `GET /repos/szTheory/sigra/actions/runs/{id}/jobs?per_page=100&page=N` | Public job IDs/names/times/conclusions and page proof | Same production pagination/validator seam | Empty conclusion, malformed identity, incomplete pages, or inverted job interval blocks emission. |
| Evidence dispatch | Maintainer dispatches separate main-only workflow | Workflow identity and canonical JSON subject | ExUnit workflow contract | Non-main ref is skipped; no PR trigger, input, watcher, or CI coupling exists. |
| Artifact provenance | GitHub attestation service; exact JSON subject | Attestation bundle, signer workflow, source ref, artifact digest | Workflow contract | Failed attestation, signer mismatch, ref mismatch, or altered bytes blocks evidence. |
| Artifact/attestation retrieval (Plan 08) | Authenticated API/CLI download | Artifact, bundle, trusted root | Plan 08 retained-file verifier | 403/429 and missing/download-failed evidence stop without retry. |
| Offline attestation (Plan 08) | `gh attestation verify ARTIFACT -R szTheory/sigra --bundle BUNDLE --custom-trusted-root TRUSTED_ROOT --signer-workflow github.com/szTheory/sigra/.github/workflows/terminal-ratification-evidence.yml --source-ref refs/heads/main --format json` | Verification JSON only | Plan 08 contract | Any verifier or signer/ref mismatch blocks ratification. |
| Workflow summary/logs (Plan 08) | Authenticated maintainer CLI | One structured summary; failed logs only | Plan 08 automation evidence | Plan 08 owns the one watcher: `gh run watch <id> --repo szTheory/sigra --compact --interval 60 --exit-status`. |

## Security and rate-limit contract

The collector makes one rate-limit read before finite REST collection. It does not poll CI, create a watcher, fetch a summary, or fetch logs. HTTP 403/429 is a hard stop with no immediate retry. The receipt excludes tokens, authorization headers, cookies, and raw authenticated state. Plan 08 alone may watch a workflow run, using the one 60-second watcher required by `AGENTS.md`.

## Source audit and gap contract

| Source | Coverage decision |
| --- | --- |
| GOAL / FAST-01 | Complete bounded population and chronology protect the unchanged 19-run, 772-second miss; strict p50 remains `< 720`. |
| REQUIREMENTS / GATE-05 | The receipt preserves source and job pages for direct-owner execution proof. |
| CONTEXT D-01–D-03 | Fixed interval, wall-clock semantics, all conclusions, and explicit exhaustion are retained. |
| CONTEXT D-04–D-05 | Plan 07 captures source jobs; Plan 08 reconciles all ownership rows from protected receipts. |
| CONTEXT D-06–D-07 | Contributor and closeout truth remain Plan 08 work. |
| CONTEXT D-08 | No re-audit, new gate, product/UI/release work, test deletion, timeout change, retry masking, schema change, or unrelated todo is included. |
| VERIFICATION CR-02–CR-04 | Hermetic fake API covers pagination and chronology; workflow contract covers provenance topology. |

Resolved-but-flagged probes remain visible: strict `p50_seconds < 720` (720 is a miss); empty/null population fails closed; one through nine eligible runs cannot pass the count gate; duration ordering is stable by `{wall_seconds, run_id}`. The descriptor-less prohibitions remain flagged-unverified without invented descriptors: do not claim FAST-01 from fewer than ten runs/a p50 at or above 720, and do not claim GATE-05 while omitting an affected spec, suite, receiver, or execution receipt.

Implementation references are GitHub's workflow-runs REST pagination API and the offline `gh attestation verify` command. Repository scripts, workflow pins, and planning contracts remain authoritative for Sigra semantics.
