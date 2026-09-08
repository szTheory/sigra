# Phase 235 external evidence coverage

## Capability declaration

- `frontend=false`
- `schema=false`
- `product_api=false`
- `external_evidence_api=true`

This closure adds a protected GitHub Actions evidence path, not a product API or a `ci.yml` required-check edge.

## GitHub capability inventory

| capability | decision | reason |
| --- | --- | --- |
| Core budget preflight | INTEGRATE | Read remaining REST core budget once before collection; malformed data, 403/429, or remaining at/below 250 stops without immediate retry. |
| Workflow-run page collection | INTEGRATE | Plan 16 retains every bounded workflow-run page through an empty terminal page and passes it to `scripts/ci/ci-run-metrics.sh`; missing, duplicate, non-contiguous, or malformed pages fail closed. |
| Per-run job page collection | INTEGRATE | Plans 16–17 preserve exhaustive raw job pages and ordered steps for the instrument-selected median and maximum when the strict FAST-01 result misses, then verify run/job/step linkage offline; Plan 18 consumes only the validated poles. |
| Main-only evidence dispatch | INTEGRATE | Retain and validate protected-main identity/blob, readiness, REST-budget, workflow-identity, UTC-boundary, and bounded pre-projection facts before the blocking decision; after authorization, dispatch the isolated workflow as the first external mutation. It has no PR trigger and creates no qualifying CI rows. |
| Artifact provenance attestation | INTEGRATE | Attest the exact JSON subject and bind repository, signer workflow, main ref, workflow SHA, and subject digest. |
| Artifact, bundle, and trusted-root retrieval | INTEGRATE | Retain all three exact inputs required for repeatable network-denied verification; missing downloads block reconciliation. |
| Offline attestation verification | INTEGRATE | Verify the retained subject with the bundle and trusted root under network denial before reading its source population or verdict. |
| Workflow run summary and failure logs | INTEGRATE | Use one 60-second watcher, fetch one structured summary, and retrieve logs only after a failure. |
| Historical FAST-01 remeasurement | INTEGRATE | Preserve the earlier attested populations and measured misses as immutable, disjoint comparison history. |
| Source-complete FAST-01 remeasurement | INTEGRATE | Sign raw timestamps, full page identities/counts, and terminal exhaustion so membership, duration, completeness, ordering, p50, and verdict can be independently replayed. |
| Authoritative terminal statistic | INTEGRATE | `scripts/ci/ci-run-metrics.sh` wall mode alone decides membership/statistics/poles; the signed raw source supports a comparison oracle, not a competing terminal calculator. |
| Dispatch correlation receipt | INTEGRATE | Plan 17 validates a reversible preflight-stage receipt before authorization, preserves those presented facts across the checkpoint, then adds the bounded post set, selected singleton ID/URL, and cardinality before the sole watcher starts. |

## Security and rate-limit contract

The reversible preflight makes one rate-limit read, retains the reset/retry facts and bounded pre-dispatch projection, and stops before authorization when core remaining is at or below 250 or GitHub returns HTTP 403/429. The receipt excludes tokens, authorization headers, cookies, and raw authenticated state. Once the checkpoint authorizes exactly one protected workflow dispatch, that dispatch is the next external mutation. Automation then correlates it to one run, uses one 60-second watcher (`gh run watch <run-id> --repo szTheory/sigra --compact --interval 60 --exit-status`), fetches one structured summary, fetches logs only after failure, and retrieves the artifact, provenance bundle, and trusted root for offline verification. The new collector/workflow is independent of `ci.yml`, cannot create qualifying rows, and preserves the existing GATE-05 ownership proof.

## Source audit and gap contract

| Source | Coverage decision |
| --- | --- |
| GOAL / FAST-01 | Plans 16–17 capture one newly authorized source-complete population; the mandated metrics script supplies the strict terminal result and signed source permits independent comparison. Plan 18 reconciles the exact result across closeout records. |
| REQUIREMENTS / GATE-05 | Plans 16–18 run byte-exact non-regression checks against the completed protected receipt, 93-row ledger, verifier, contributor topology, and requirement records. |
| CONTEXT D-01–D-03 | Plan 16 extends the authoritative wall-mode instrument/source contract and signed miss-pole job/step schema; Plan 17 retains and verifies the exact protected evidence. |
| CONTEXT D-04–D-05 | Plans 16–18 preserve the original protected GATE-05 artifacts and exact 93-row ownership proof without reopening it. |
| CONTEXT D-06–D-07 | Plan 17 produces the authenticated handoff; Plan 18 reconciles closeout only from that metrics-script result after source comparison, while contributor topology remains unchanged. |
| CONTEXT D-08 | No re-audit, new gate, product/UI/release work, test deletion, timeout change, retry masking, schema change, or unrelated todo is included. |
| VERIFICATION CR-02 | Plans 16–17 close the evidence gap with signed raw timestamps, contiguous pages/exhaustion, authoritative metrics-script output, and source-first offline comparison; Plan 18 applies the verified disposition without reopening evidence. |

Resolved-but-flagged probes remain visible: strict `p50_seconds < 720` (720 is a miss); empty/null population fails closed; one through nine eligible runs cannot pass the count gate; duration ordering is stable by `{wall_seconds, run_id}`. The descriptor-less prohibitions remain flagged-unverified without invented descriptors: do not claim FAST-01 from fewer than ten runs/a p50 at or above 720, and do not claim GATE-05 while omitting an affected spec, suite, receiver, or execution receipt.

Implementation references are GitHub's workflow-runs REST pagination API and the offline `gh attestation verify` command. Repository scripts, workflow pins, and planning contracts remain authoritative for Sigra semantics.
