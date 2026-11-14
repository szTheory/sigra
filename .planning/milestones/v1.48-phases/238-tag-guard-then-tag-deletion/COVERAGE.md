# Phase 238 — API Coverage Decision

**Detector:** no `api-coverage` verb exists in this runtime (`gsd_run query api-coverage detect 238`
→ `Unknown command`). Decision made by hand and recorded here rather than skipped.

**Does this phase integrate an external API?** Yes, honestly: it drives the **GitHub REST API**
via `gh api` (rulesets, rule-suites, releases, git refs). It is operator/CI tooling rather than
product code, but the gate asks whether an external API is being integrated — it is, and the
phase deliberately covers some routes and deliberately declines others. Matrix below.

| capability | decision | reason |
|------------|----------|--------|
| `GET /repos/{o}/{r}/rulesets` (list) | INTEGRATE | D-11/D-17 two-step read; the id-discovery half |
| `GET /repos/{o}/{r}/rulesets/{id}` (by id) | INTEGRATE | `conditions`/`rules`/`bypass_actors` are by-id-only; the committed snapshot's source |
| `POST /repos/{o}/{r}/rulesets` | INTEGRATE | D-01/Tier-2 probes and the real guard creation |
| `DELETE /repos/{o}/{r}/rulesets/{id}` | INTEGRATE | probe teardown |
| `PUT /repos/{o}/{r}/rulesets/{id}` (enforcement flip) | INTEGRATE | D-06's `disabled` flip window, only if the delete probe is rejected |
| `GET /repos/{o}/{r}/rulesets/rule-suites` + `/{id}` | INTEGRATE | D-18's citable RED proof; `rule_evaluations[]` is by-id-only |
| `GET /repos/{o}/{r}/releases` (REST, paginated) | INTEGRATE | SC-4's before/after count and draft count; the REST route keeps SC-4's literal jq satisfiable |
| `GET /repos/{o}/{r}/tags` | OPT-OUT | `git ls-remote --tags origin` is the authoritative remote ref oracle and is already the phase's idiom |
| `DELETE /repos/{o}/{r}/git/refs/tags/{tag}` | OPT-OUT | D-06: the API delete route is ruleset-evaluated too, so it is not a workaround; the phase deletes over git |
| `GET /repos/{o}/{r}/rules/branches/{branch}` | OPT-OUT | branch-target rules are out of scope; this phase adds a sibling tag ruleset only |
| Org-level rulesets (`/orgs/{org}/rulesets`) | OPT-OUT | `szTheory/sigra` is User-owned; no org exists |
| Rule Insights / `enforcement: "evaluate"` | OPT-OUT | enterprise-gated by `repo-rules-enterprise`; unavailable on this repo's plan |
| Classic tag protection (`/repos/{o}/{r}/tags/protection`) | OPT-OUT | has implicit admin bypass, which defeats D-05 |
