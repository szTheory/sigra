# Plan 250-07 Preflight Delivery Repair Evidence

Status: the controller delivery blocker is repaired and merged. Plan 250-07 remains open; AUTO-02 remains unsatisfied. No hosted controller, canary source, or cancellation run was dispatched.

## Blocker and repair

The controller workflow checks out `refs/heads/main`, then the shared validator rejects committed preflight JSON older than 900 seconds. A newly captured preflight on the execution branch could not be committed to main without advancing past the exact SHA bound to the prior authority packet. That packet-bound authority remains unusable for the new main SHA.

The controller now accepts the exact sanitized preflight JSON and its lowercase SHA-256 digest as required `workflow_dispatch` inputs. It passes them through environment variables, validates the digest and JSON data without shell evaluation, enforces a 32,768-byte limit and rejects credential-shaped keys before writing under `RUNNER_TEMP`. The resulting file is passed through `CANARY_PREFLIGHT_FILE` to the existing shared validator. The validator still enforces the 900-second freshness window, repository/default branch, live workflow IDs and names, current-main checkout, target ancestry, and the exact nine source/helper blobs. No source check was bypassed and no fetched branch code is executed.

## Protected delivery

- PR: [#319](https://github.com/szTheory/sigra/pull/319)
- Reviewed PR head: `2965fc27a5e65954fe54b39f0be45ffcb856e9da`
- Required CI: [run 38082645367](https://github.com/szTheory/sigra/actions/runs/38082645367), conclusion `success`, including `ci-gate`
- Protected main before merge: `34f7fd8e47c4b356ef97656f3213a2e749017f2a`
- Protected main after merge: `33fccd8b3afe8ad093a0e379578fdc29c8a44e95`
- Merge method: ordinary protected squash merge

The merged main blobs are:

| File | Main blob |
| --- | --- |
| `.github/workflows/release-receipt-canary-controller.yml` | `56f8f86fa1f2343a40106a743f99f9bbdcb2c2b1` |
| `scripts/ci/release-canary.sh` | `6a96988de51febbe06ccba9d83c6b32e66605c98` |
| `scripts/ci/release-canary.test.sh` | `fa08d151735b1842a2ee744cf8e2740197826e56` |
| `test/sigra/planning/phase_250_canary_contract_test.exs` | `2a5fb3092113bfec22f74c0c75010346bf1ed159` |

## Deterministic evidence

- `bash scripts/ci/release-canary.test.sh` — 58 passed on the execution branch; 56 passed on the main-based PR branch. Both include a mocked 204 dispatch and exact retrieved artifacts.
- `bash scripts/ci/release-receipt.test.sh` — 15 passed on the execution branch; 16 passed on the PR branch.
- `bash scripts/ci/release-observer.test.sh` — 22 passed.
- Standalone canary contract ExUnit — 8 tests, 0 failures.
- `actionlint` on the canary source, controller, and observer workflows — passed.
- `bash scripts/ci/release-canary.sh --self-test` and `mix format --check-formatted test/sigra/planning/phase_250_canary_contract_test.exs` — passed.

Fixtures prove a stale committed preflight remains blocked while a fresh supplied payload reaches the shared live-workflow, target-ancestry, and exact-source checks. They reject mismatched digest, stale and future timestamps, wrong repository, unrelated target SHA, wrong live canary workflow ID, tampered bytes, oversized input, malformed JSON, and credential-shaped fields before persistence. The successful integration fixture uses only mocked Actions responses and performs no network dispatch.

## Safe preparation for a new packet and authority request

The old packet authorized source `34f7fd8e47c4b356ef97656f3213a2e749017f2a`; it cannot authorize the merged source. Before asking for any new live action:

1. On the then-current protected main, run the read-only preflight and require `status: ready` with `target_sha` equal to that exact main SHA:

   ```sh
   bash scripts/ci/release-canary.sh --preflight --output /tmp/250-CANARY-PREFLIGHT.json
   jq -e --arg sha "$(git rev-parse origin/main)" '.status == "ready" and .target_sha == $sha and .dispatch_attempted == false and .credential_values_recorded == false' /tmp/250-CANARY-PREFLIGHT.json
   ```

2. Form the exact one-line workflow input and digest. The digest covers the bytes without a trailing newline; use this same string for the `preflight_json` input:

   ```sh
   PREFLIGHT_JSON="$(jq -c . /tmp/250-CANARY-PREFLIGHT.json)"
   PREFLIGHT_SHA256="$(printf '%s' "$PREFLIGHT_JSON" | shasum -a 256 | awk '{print $1}')"
   ```

3. Create a new packet bound to the new main SHA, the merged workflow/helper blobs, the preflight digest, the exact controller workflow ID, one bounded dispatch and its self-owned cancellation probe, the 35-minute bound, retained artifact identities, and the no-publish boundary. Obtain explicit authority for that exact packet before any controller dispatch. The prior authorization is not reusable.

After that decision only, pass `PREFLIGHT_JSON` as `preflight_json` and `PREFLIGHT_SHA256` as `preflight_sha256` to the named `workflow_dispatch`. No dispatch command was run while preparing this repair evidence.

## Remaining state

- `dispatch_attempted`: `false`
- `canary_child_dispatch_attempted`: `false`
- `cancellation_attempted`: `false`
- `hosted_proof_updated`: `false`
- `AUTO-02`: `unsatisfied`
- `250-07-SUMMARY.md`: intentionally not created
