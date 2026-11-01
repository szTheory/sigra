## ISSUES FOUND

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks
**Plans checked:** 11 (253-15 through 253-25)
**Issues:** 1 blocker, 0 warnings, 0 info

### Coverage summary

| Requirement | Plans | Status |
|---|---|---|
| CIREL-01 | 253-15–17, 253-21, 253-24–25 | Covered, conditional on native reproduction/fix or the documented adequate no-flake path |
| CIREL-02 | 253-18–25; retained 253-03–06 | Covered, conditional on hosted and production-PR evidence |

The new plans preserve the failed 253-09/12 history, order shared source edits before freezes and hosted proof, and keep the locked five required checks, five browser seams, six canary outcomes, independent verifier, registration slot accounting, source/object provenance, and accepted-only closeout in scope. The new plan dependency graph is acyclic and places shared-file owners in ordered waves. The new plans do not claim that implementation or phase verification has already succeeded.

### Blockers — these properties must hold

**1. [scope_sanity] Every production HTTP operation is included in a correctly summed named reservation within the shared 120-request ceiling.**
- Plan: 253-24
- Evidence: The task freezes these production reservations: preflight 8, docs object/ref publication 14, PR creation 2, PR/source/diff identity 8, discovery 4, pre-watch rate reads 2, terminal polls 27, job pages 4, check pages 4, artifact pages 4, report ZIP hops 20, failed-log hops 2, and one retry 21. These add to **116**, while the same action states that the reservation categories total **120**. The associated budget record likewise labels the table's “Combined maximum” as 120. The plan gives no four-request category or rule for that remaining capacity, despite requiring the freeze and verifier to reconcile exact reservation totals. This leaves the production freeze's allowed request set internally inconsistent.
- Example fix (non-binding): Make the accounted total explicit and consistent: either define the unused four requests as unavailable headroom and have the freeze/verifier enforce 116 reserved requests under the 120 hard cap, or identify and bound the specific operations assigned to the remaining four.

### Structured Issues

```yaml
issues:
  - plan: "253-24"
    dimension: "scope_sanity"
    severity: "blocker"
    required_property: "Every production HTTP operation is included in a correctly summed named reservation within the shared 120-request ceiling"
    description: "The listed production reservations sum to 116 (8+14+2+8+4+2+27+4+4+20+2+21), but the plan and 253-REPLAN-BUDGETS.md call their total 120. No rule accounts for the remaining four requests, although the freeze and verifier are required to reconcile exact reservations."
    task: 1
    fix_hint: "State that only 116 requests are reserved and four are unusable headroom under the 120 cap, or name and bound the four additional request operations."
```

### Recommendation

1 blocker requires revision. The other plan coverage checks passed; correct the production request accounting before execution so the freeze cannot authorize an unbudgeted request.
