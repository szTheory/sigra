# API Coverage — GitHub Reads for Phase 245

> GitHub access in this phase is limited to reading the actor, repository permissions, exact commit availability, and pull request state needed for branch safety. No API mutation is in scope.

| capability | decision | reason |
|---|---|---|
| Read authenticated actor identity with `gh api user` | INTEGRATE | Used to bind access preflight evidence to the authenticated account without recording credentials. |
| Enumerate open PR head/base names with `gh pr list` | INTEGRATE | The prune guard needs the complete current open-PR exclusion set in both directions. |
| Read GitHub API rate-limit state with `gh api rate_limit` | INTEGRATE | The evidence capture stops before requests when the REST core budget is 250 or fewer, and honors 403/429 reset or retry times. |
| Read repository identity and push permission with `gh api repos/szTheory/sigra` | INTEGRATE | Remote access preflight verifies repository identity and permission without mutating it. |
| Read an exact commit by immutable SHA with `gh api repos/szTheory/sigra/commits/{sha}` | INTEGRATE | The D-06 recovery preflight confirms that GitHub serves the same `gh-pages` commit that the live origin ref names before any separately approved local object-database write. |
| Enumerate open pull requests with paginated REST GET requests | INTEGRATE | The PR identity audit requires complete page enumeration and stable number sets. |
| Read each historical PR with a REST GET request | INTEGRATE | The strict identity audit corroborates each of the 11 historical records independently. |
| Create, update, merge, or close pull requests through the API | OPT-OUT | Phase 245 preserves PR state; no GitHub pull-request mutation is authorized by its scope. |
| Create, update, or delete refs through the GitHub API | OPT-OUT | Ref changes use the guarded Git operator with exact refs and expected OIDs; API ref mutation is outside this phase. |
| Issues, comments, labels, checks, releases, and repository settings APIs | OPT-OUT | These capabilities are unrelated to branch pruning and PR head/base protection. |

## Read Contract

| operation | endpoint or command | credential handling | pagination / limit | fields consumed | error, empty, and null behavior | consumer | evidence |
|---|---|---|---|---|---|---|---|
| Authenticated actor | `GET /user` via `gh api user` | Use the configured `gh` credential; retain actor identity only, never token material. | Single response. | `.login` | Authentication or parse failure blocks the preflight; missing login is not an identity. | `prune-stale-branches.sh` access preflight | `245-ORIGIN-ACCESS-PREFLIGHT.json` |
| Open PR exclusion set | `gh pr list --repo szTheory/sigra --state open --limit 1000 --json number,state,headRefName,baseRefName,headRefOid,baseRefOid` | Use the configured `gh` credential; do not persist secrets. | Limit 1000; a full limit, truncated output, or failed query is incomplete. | Number, state, head/base ref names, head/base OIDs. | Empty is valid only when the command succeeds and returns a complete empty array; missing/null identity fields or parse errors block pruning. | Prune readiness and post-prune PR verification | `245-OPEN-PR-STATE.json` and related before/after PR receipts |
| Rate-limit preflight | `GET /rate_limit` via `gh api rate_limit` | Use the configured `gh` credential; do not persist response headers containing secrets. | Single response before the API sequence. | REST core remaining and reset time. | At 250 or fewer remaining, stop until reset; on 403/429, honor the reported retry/reset time without immediate retry. | Plan 245-14 live identity capture | `245-14-PR-IDENTITY-AUDIT.json` |
| Repository access | `GET /repos/szTheory/sigra` via `gh api repos/szTheory/sigra` | Use the configured `gh` credential; persist repository/account facts only. | Single response. | Repository identity and `permissions.push`. | Failed, null, or mismatched repository identity blocks remote apply; absent permission is not permission. | Remote origin access preflight | `245-ORIGIN-ACCESS-PREFLIGHT.json` |
| Complete open PR inventory | `GET /repos/szTheory/sigra/pulls?state=open&per_page=100&page=N` | Use the configured `gh` credential; responses contain public PR data and no credentials are written. | Follow pagination until the final page; compare page counts and unordered PR number sets. | Number, state, head/base refs and OIDs. | Any missing page, failed request, inconsistent count/set, or null identity blocks the audit; a complete empty set is distinct from failure. | `prune-stale-branches-pr-audit.mjs` | `245-14-PR-IDENTITY-AUDIT.json` |
| Historical PR detail | `GET /repos/szTheory/sigra/pulls/{number}` | Use the configured `gh` credential; responses contain public PR data and no credentials are written. | One request for each of the 11 historical PR numbers. | State, head/base repository, ref names, and OIDs. | Missing PRs, failed requests, null fields, or identities inconsistent with the inventory remain blocked with per-PR reasons. | `prune-stale-branches-pr-audit.mjs` | `245-14-PR-IDENTITY-AUDIT.json` |

| Exact commit availability | `GET /repos/szTheory/sigra/commits/{sha}` via `gh api repos/szTheory/sigra/commits/{sha}` | Use the configured `gh` credential; retain only the requested SHA and returned commit/tree identity. | Single response for the exact immutable SHA. | Commit SHA and tree SHA. | API failure or a returned SHA mismatch blocks recovery; no substitute SHA is accepted. | D-06 planning/execution preflight for the exact `gh-pages` object | `245-33-PLANNING-PREFLIGHT.json` and the later execution receipt |

The helper records request times, endpoint names, page completeness, and sanitized errors. It does not record authorization headers or token values. Git transport reads such as `git ls-remote origin` are separate from the GitHub API surface and are recorded in the corresponding ref evidence.
