# Phase 240 — External API Coverage Matrix

**External API:** GitHub REST API v3, accessed exclusively through `gh` (2.95.0).
**Produced:** 2026-09-18 at plan time (detector `api-coverage.cjs --json` → `detected: true`).

`INTEGRATE` is the default for every capability. This matrix is the **subtraction record**: every
`OPT-OUT` row carries a one-line reason, because an opt-out without a reason is the un-decided hole
this gate exists to close.

| capability | decision | reason |
|---|---|---|
| `GET /rate_limit` | INTEGRATE | Single fail-closed preflight in `capture-green-04-evidence.sh` (`rate_limit_too_low` under 250 remaining). |
| `GET /repos/{repo}/actions/runs/{id}` | INTEGRATE | Supplies `head_sha` for the D-13 final-committed-HEAD assertion. |
| `GET /repos/{repo}/actions/runs/{id}/jobs` | INTEGRATE | The SC-1 and SC-2 evidence surface. D-08: the verdict is read at the **job** level, never the run level. Paginated at `per_page=100` with an explicit `filter=latest` and a `total_count`-vs-length assertion (D-11). |
| `GET /repos/{repo}/actions/workflows/{file}/runs` | INTEGRATE | Enumerates the `main` window for SC-2 (`branch=main`, `created=<start>..<end>`). |
| `POST /repos/{repo}/actions/workflows/{file}/dispatches` | INTEGRATE | The n≥20 evidence run, invoked by the operator as `gh workflow run green-04-evidence.yml --ref main` (Plan 04). |
| `GET /repos/{repo}/pages` | INTEGRATE | Site-1 of the honest Pages script; `200 → inspect`, `404 → create`, anything else → `exit 1` (D-15/D-16). |
| `POST /repos/{repo}/pages` | INTEGRATE | The create arm, now reachable **only** on a genuine 404 rather than on any error. |
| `PUT /repos/{repo}/pages` | INTEGRATE | Site-2; `204|200 → ok`, `403 → the single documented tolerable case` (D-19), `* → exit 1` (D-17/D-18). |
| `POST /repos/{repo}/pages/builds` | INTEGRATE | The three build triggers, deliberately kept lenient with `\|\| true` and a reason comment each (D-22). |
| `GET /repos/{repo}/issues/{n}` | INTEGRATE | `gh issue view 231 --json state` is the SC-4 verification artifact — the close is proven by re-reading, never by the close command's exit code (D-24). |
| `POST /repos/{repo}/issues/{n}/comments` | INTEGRATE | The #231 closure comment carrying the run ids, the live Pages payload and the explicit evidence window. |
| `PATCH /repos/{repo}/issues/{n}` | INTEGRATE | `gh issue close 231`. |
| `GET /repos/{repo}/actions/runs/{id}/artifacts` | OPT-OUT | The receipt's evidence is run ids and job conclusions; artifact blobs add bytes, not provenance, and the matrix legs' artifacts are retention-limited. |
| `GET /repos/{repo}/actions/jobs/{id}/logs` · `GET /repos/{repo}/actions/runs/{id}/logs` | OPT-OUT | Both log-download endpoints, one row. Log text is not the evidence surface — a job conclusion is; the collector calls neither, and quoting log bodies into a public issue also widens the disclosure surface for no evidentiary gain. |
| `POST /repos/{repo}/actions/runs/{id}/rerun` (and `rerun-failed-jobs`) | OPT-OUT | A rerun would manufacture the n≥20 window rather than measure it; explicitly prohibited in `240-04-PLAN.md`. |
| `POST /repos/{repo}/actions/runs/{id}/cancel` | OPT-OUT | Cancelling a leg produces exactly the null conclusion the collector is built to reject (`leg_without_conclusion`). |
| `DELETE /repos/{repo}/actions/runs/{id}` | OPT-OUT | Deleting a run destroys the evidence this phase exists to produce. |
| `GET /repos/{repo}/actions/workflows/{file}` (workflow metadata) | OPT-OUT | The collector pins the workflow by filename as a fixed constant; resolving it by id adds a steerable parameter for no benefit. |
| `PUT /repos/{repo}/actions/workflows/{file}/enable` · `/disable` | OPT-OUT | Toggling a workflow's enabled state is an outward-facing repo mutation with no role in producing or reading evidence. |
| `DELETE /repos/{repo}/pages` | OPT-OUT | Destructive and outward-facing on a public repo; D-20 forbids mutating live Pages configuration at all in this phase. |
| `GET /repos/{repo}/pages/builds` · `/builds/latest` | OPT-OUT | Build status is deliberately *not* gated — D-22 keeps the three build triggers lenient, so reading build status would imply an assertion the phase has chosen not to make. |
| `GET /repos/{repo}/pages/health` | OPT-OUT | A custom-domain/DNS health check; this repo serves from `github.io` with no custom domain, so the endpoint answers a question nobody asked. |
| `GET /repos/{repo}/actions/permissions` · `/actions/permissions/workflow` | OPT-OUT | Repo-admin scope the caller does not hold; the phase's least-privilege posture is asserted by the workflow's declared `permissions:` block, not by querying settings. |
| `POST /repos/{repo}/issues` (create) · `/labels` | OPT-OUT | The missing `release-lane-rot` label is a named-not-fixed adjacent defect owned by its own pending todo (D-28, ROADMAP standing constraint 4). |
| `GET /repos/{repo}/actions/runs/{id}/attempts/{n}` | OPT-OUT | `filter` is set explicitly to `latest`; superseded attempts are out of the declared window by construction, and reading them would blur which attempt the verdict describes. |

## Reconciliation against the implemented collector (plan 240-03, Task 3)

Re-read after `scripts/ci/capture-green-04-evidence.sh` was authored (commit `6b2064f6`) and its
self-test landed (commit `941d679d`). The collector issues exactly four distinct external reads,
enumerated from the script rather than from this table:

| endpoint as called | call site |
|---|---|
| `GET /rate_limit` | `gh api rate_limit --jq '.resources.core.remaining'` — the single fail-closed preflight (`rate_limit_too_low`). |
| `GET /repos/szTheory/sigra/actions/runs/{RUN_ID}` | the D-13 `head_sha` read. |
| `GET /repos/szTheory/sigra/actions/runs/{id}/jobs?filter=latest` | twice — once for the SC-1 dispatch legs, once per `main` run for SC-2. |
| `GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs?branch=main&created=<start>..<end>` | the SC-2 `main` window. |

All four already carried an `INTEGRATE` row above; **no row was added and no row moved to
`OPT-OUT`** as a result of this reconciliation. Every `OPT-OUT` row above still carries its reason.

Two endpoints listed as `INTEGRATE` are deliberately **not** called by this collector because they
belong to other plans in this phase, not because they were subtracted:
`POST /repos/{repo}/actions/workflows/{file}/dispatches` (operator, plan 240-04) and the four
Pages endpoints plus the three issue endpoints (plan 240-01 / 240-04). `INTEGRATE` is a phase-level
decision, not a per-script one.
