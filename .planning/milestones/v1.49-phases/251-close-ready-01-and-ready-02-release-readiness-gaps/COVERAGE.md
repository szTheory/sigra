# API Coverage — GitHub read-only release evidence

> Full coverage by default for the GitHub capability surface this phase consumes. Opt-outs are explicit. Existing `gh api` calls remain read-only; this matrix does not authorize release actions.

| capability | decision | reason |
|---|---|---|
| repository commit and tree lookup | INTEGRATE | |
| exact-commit file contents and blob lookup | INTEGRATE | |
| tag ref and published source lookup | INTEGRATE | |
| open pull requests with complete pagination | INTEGRATE | |
| pull request head, base ref, base SHA and state | INTEGRATE | |
| pull request changed-file and review evidence | INTEGRATE | |
| pull request review and timeline history with complete pagination | INTEGRATE | |
| exact-head workflow run, attempt, job and check conclusion lookup | INTEGRATE | |
| REST rate-limit inspection before sustained capture | INTEGRATE | |
| create, update or merge pull requests | OPT-OUT | Phase 251 is evidence-only and cannot change PRs. |
| dispatch or cancel workflows | OPT-OUT | Phase 251 only reads existing CI receipts. |
| create or change tags, releases or repository contents | OPT-OUT | Candidate and published identities are immutable evidence. |
| package publish or registry mutation | OPT-OUT | Original dry-run and publication receipts are read as history. |

This matrix covers the external service operations relevant to READY-01 and READY-02 evidence capture. Other GitHub REST features have no release-readiness role in Phase 251.
