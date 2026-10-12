# API Coverage — GitHub read-only CI evidence

> Full coverage by default for the GitHub REST capability surface this measurement integrates. Opt-outs are explicit. The existing `gh` CLI supplies authentication; no new SDK or service is added.

| capability | decision | reason |
|---|---|---|
| GET REST core rate limit and reset time | INTEGRATE | |
| GET current effective branch protection and active rulesets for enforced required contexts | INTEGRATE | Derive the endpoint from current enforcement; retain observed ruleset IDs, including historical 14941512 when present, as provenance only. |
| GET `ci.yml` workflow runs by event, branch, created window and page | INTEGRATE | |
| GET exact workflow run, source SHA, event and attempt count | INTEGRATE | |
| GET all attempts for each selected run | INTEGRATE | |
| GET attempt-scoped jobs, steps, timestamps and runner labels | INTEGRATE | |
| GET check runs/statuses for enforced required contexts | INTEGRATE | |
| GET PR changed paths and saved docs-only/skip evidence | INTEGRATE | |
| GET producing-run artifact metadata, ID, digest and expiry | INTEGRATE | |
| GET selected producing-run artifact bytes through validated download redirects | INTEGRATE | Disable automatic following; allow HTTPS redirects only to exact `pipelines.actions.githubusercontent.com` or a full host with first label `productionresultssa` plus digits and literal suffix `.blob.core.windows.net`; require a nonempty path and no user-info, fragment or non-default port. Count every hop and never persist signed query URLs. |
| GET selected failed-family logs within the shared request budget | INTEGRATE | Apply the same redirect checks and signed-URL handling as artifact downloads. |
| POST workflow dispatch or rerun | OPT-OUT | Real PR CI is triggered by a scoped draft PR; manual dispatch does not measure the required PR wait. |
| POST/PUT check runs, statuses or required rules | OPT-OUT | This phase measures effective checks; Phase 253 owns gate repairs and no rule mutation is authorized here. |
| POST/DELETE run cancellation or deletion | OPT-OUT | Literal cancellations are retained as data; changing historical runs would corrupt the snapshot. |
| PUT/DELETE artifacts or release assets | OPT-OUT | The collector reads bounded evidence; release and publishing changes are outside this milestone. |
| GitHub GraphQL mutation or webhook subscription | OPT-OUT | The bounded snapshot uses existing read-only REST endpoints and needs no persistent integration. |

The shared bounded GET guard applies before the first live preflight request and through tracer collection, pages, retries, metadata, redirect hops and downloads. Acquisition uses `gh api --method GET` for parameterized requests. Each request counts toward 600 requests/60 minutes; a core budget of 250 or fewer and HTTP 403/429 stop collection until the reported reset/retry time. A blocked hosted input remains unknown while independent offline development continues; final baseline acceptance stays nonzero until required hosted evidence exists. The draft PR creation in Plan 06 is a scoped GitHub workflow action to produce a real PR event, not a new measurement API capability; it never merges or publishes.
