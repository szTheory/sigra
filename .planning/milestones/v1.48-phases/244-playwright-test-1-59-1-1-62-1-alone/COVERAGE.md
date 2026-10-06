# API Coverage — Phase 244 GitHub evidence and disposition

> Full coverage of the GitHub API operations needed by this phase. Other repository management capabilities are outside QUEUE-02.

| capability | decision | reason |
|---|---|---|
| Read PR #213 state, head and mergeability | INTEGRATE | |
| Read current main ref and SHA | INTEGRATE | |
| Read CI workflow run and paginated jobs | INTEGRATE | |
| Read GitHub REST rate limit | INTEGRATE | |
| Dispatch CI workflow on an authorized ref | INTEGRATE | |
| Read workflow artifacts and logs | INTEGRATE | |
| Merge PR #213 after all decision gates | INTEGRATE | |
| Close or comment on PR #213 with measured defer reason | INTEGRATE | |
| Reopen PR #213 or restore its deleted head ref | OPT-OUT | The closed PR has no live head; restoration requires an explicit live-candidate checkpoint and authorization. |
| Modify unrelated branches, issues, releases or repository settings | OPT-OUT | Outside QUEUE-02 and unrelated to measurement or disposition. |
