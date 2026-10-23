# PR343 artifact and docs-run continuation

This directory prepares the remaining evidence with the repository’s existing bounded HTTPS transport, docs-only PR collector, and independent PR verifier. The normal command is read-only and offline:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B .planning/execution/253-pr343-remaining-evidence/run.py
```

It validates the retained successful PR343 run and its real artifact metadata, then prints the five exact artifact identities and the actual missing evidence. It does not request network access, create refs or PRs, dispatch CI, or report phase acceptance. The runnable live continuation is `run.py --run`; it refuses to start unless `approval.json` is a fresh approval for the exact proposal bytes and is committed at `HEAD`. Approval must be supplied after this directory is committed and reviewed; this preparation does not create one. The runner preserves the once-only window before its first HTTP request, pre-debits every request into one shared ledger, closes on failure, and never retries a failed request.

The proposal pins existing normal PR 343, run `39815188159`, attempt 1, head `c8443e2bd9576bb0284d6c78a7212659a5af85fd`, base `09df342a82e03c3d5d40173c912b70e827f7eadc`, and the five artifact IDs, names, sizes and SHA-256 digests retained in the successful run’s artifact inventory. Each ZIP is fetched through the copied production transport, with a maximum of two redirects per GET. The 20-request artifact-download ceiling is shared across the five existing PR343 artifacts and any five artifacts from the new docs run; redirects count as separate requests, so there is one shared allowance for all ten downloads, not two guaranteed redirects per artifact. The GitHub bearer token is sent only to `api.github.com`; the redirect host receives no GitHub authorization header. The runner compares downloaded bytes with both recorded size and digest, validates ZIP members through the independent verifier, and passes the five records to `ci-browser-records.mjs` with the actual PR merge identity: `source_sha` and `workflow_sha` are `d6024255ed139f7c19bd44e68c10a85cc9ecca3b`, `event` is `pull_request`, `workflow_ref` is `szTheory/sigra/.github/workflows/ci.yml@refs/pull/343/merge`, classifier result is `success`, and `docs_only` is `false`. The embedded file is `execution-record.json`; its exact schema and fields come from `scripts/ci/ci-browser-records.mjs`.

The docs-only continuation uses the recorded freeze, not a recomputed candidate: head ref `gsd/253-replan-proof-5e13621e5-docs-head` at `a4c2b64119fa89ada8a6dbbe1f729a24fb6bfc21`, based on `gsd/253-replan-proof-5e13621e5-docs-base` at `4524f17e1b791dd4d2c2ae597c053a8e37e8095e`. The retained docs workflow and one-file proof source are checked against their frozen Git blob IDs. After approval, the existing collector publishes those frozen objects, creates one draft docs-only PR, and gathers the actual pull-request run, required checks, jobs, artifacts and source blobs. The independent `ci-hosted-gate-verify.py --mode pr --family docs-only` must accept the complete measured response ledger. A failed, incomplete, identity-mismatched, or rate-limited response closes the window and stays a failure.

The collector requires the production allocation’s exact 120-request category table. This is the repository’s transport/verifier contract, not a renewed old budget. This proposal narrows the routes and category ceilings further: the permitted per-category maxima sum to 70 requests; unused capacity cannot be spent on another workflow or action.

| Category | Maximum | Scope |
| --- | ---: | --- |
| preflight | 6 | Rate limit, branch rules/protection, and workflow identity reads |
| docs_publication | 14 | Exact two frozen docs commits/refs and readbacks |
| pr_create | 1 | One draft docs-only PR |
| pr_identity | 5 | PR read, two compares, and two frozen source reads |
| run_discovery | 2 | One workflow listing, then one exact commit-check hint read if empty |
| pre_watch_rate | 1 | One rate-limit read before polling |
| terminal_polls | 12 | Frozen docs-run terminal-poll ceiling |
| attempt_jobs | 4 | Docs-run attempt job pages |
| native_checks | 1 | Required native check page |
| artifact_metadata | 4 | Docs-run artifact inventory pages |
| artifact_downloads | 20 | One shared allowance for ten artifact downloads; each can use up to two redirects, but no artifact gets a reserved redirect quota |
| failure_logs | 0 | Forbidden |
| infrastructure_rerun | 0 | Forbidden |

The actual request ceiling is 120 because the canonical production transport requires that exact allocation. `request_budget.permitted_request_maxima` in `proposal.json` imposes the 70-request narrower ceiling above. The window expires after 3,600 seconds, stops before further work when GitHub core allowance is 250 or lower, and permits zero retries, normal-PR mutations/reruns, workflow dispatches, merges, auto-merges, or ref deletions. HTTP 401/403/429, transport errors, digest/identity failures, or exhausted category limits end the one window.

Run the offline tests with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B -m unittest discover -s .planning/execution/253-pr343-remaining-evidence -p 'test_*.py' -v
```

They include synthetic HTTP response fixtures through the actual transport (successful redirect, auth stripping, 403/429 stop and no retry, and exhausted request ceiling), exact-approval/hash checks, strict frozen tree/commit/ref bodies, wrong artifact identity/digest rejection, synthetic ZIP archives passed through the actual archive and browser-policy verifiers, and an isolated approved `activate()` path with mocked HTTPS and collector/verifier boundaries. That path is explicitly synthetic and never counts as acceptance. The suite also checks the actual approval-section reader and rejects retained failed docs-run evidence. A separate no-network `ci-pr-proof.sh --check-only` check validates the copied freeze and generated 120-request allocation. These tests prove the local continuation behavior only; they do not replace any missing hosted evidence.

The actual evidence still missing is the five original PR343 ZIPs with their embedded records, and a new docs-only PR’s real identity plus its exact required checks completing successfully. Neither is present in the saved records. The normal workflow file is copied into this directory and checked against the frozen Git blob before any request. There is no approval for the final proposal yet, so do not run `--run`.

The docs collector now handles the saved empty-list discovery failure: after one workflow listing it can read commit checks, then directly validate the hinted run against the exact PR/head/base and first attempt. Both discovery reads remain inside the two-request ceiling. Ambiguous hints, incomplete checks and unrelated app/repository/source identities are rejected. The independent verifier reads the original measured responses; no workflow listing is rewritten.
