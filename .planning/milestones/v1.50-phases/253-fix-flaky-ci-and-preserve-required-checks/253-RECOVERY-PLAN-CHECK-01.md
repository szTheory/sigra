## ISSUES FOUND

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks (recovery plans 09–14)
**Plans checked:** 6 new recovery plans; original plans 01–08 reviewed for historical status and non-rewrite constraints
**Issues:** 1 blocker, 0 warnings, 0 info

### Blockers — these properties must hold

**1. [scope_sanity] All registration reproduction, control, and acceptance runs fit within one predeclared cumulative budget.**
- Plan: 253-09, 253-10
- Task: 253-10 Task 1 (and acceptance work in Task 2)
- Evidence: Plan 09 freezes and charges its own diagnostics (up to ten invocations or twenty minutes per signature, sixty minutes total), but Plan 10 Task 1 adds actual delayed/missing-readiness, broken-wait, collision, trace-failure, and passing controls without stating that these consume the same frozen invocation and time budgets, or allocating a separate pre-result control budget. Plan 10 Task 2 then freezes acceptance repeats, while its listed readiness/isolation controls and earlier run receipts may also be needed for acceptance. The roadmap/context explicitly caps reproduction at ten invocations or twenty minutes per signature and sixty minutes total, with only one diagnosed infrastructure retry; the plan set does not establish that all required native runs, including controls, are countable and possible inside those ceilings. As written, an executor can perform all 09 runs and still be required to run the full 10 control suite outside that budget, or exhaust the cap before controls and acceptance are complete.
- Example fix (non-binding): Make the registration freeze and verifier account for Plan 09 diagnostics plus every Plan 10 control and acceptance invocation in one cumulative ledger, with explicit allocations and a stop rule that keeps mandatory controls/repeats feasible within the approved limits.

### Warnings — these properties should hold

None.

### Advisories (info)

None.

### Structured Issues

```yaml
issues:
  - plan: "253-09/253-10"
    dimension: "scope_sanity"
    severity: "blocker"
    required_property: "All registration reproduction, control, and acceptance runs fit within one predeclared cumulative budget."
    description: "Plan 09 imposes the D-19 invocation/time ceilings on its diagnostics, but Plan 10 Task 1 requires additional real readiness, collision, broken-wait, trace-failure and passing-control runs without requiring them to debit the same freeze or specifying a separately approved allocation. Plan 10 Task 2 then requires post-fix repeats and controls under another acceptance freeze. The plan set does not demonstrate that these mandatory runs can all be performed within the approved ten invocations or twenty minutes per signature and sixty minutes total, including the single infrastructure retry."
    task: 1
    fix_hint: "Use one cumulative registration run ledger across Plans 09–10, explicitly reserving capacity for required controls and acceptance runs before the first browser action, and stop if that allocation cannot fit the approved cap."
```

### Additional verification notes

- Phase goal and requirement coverage: CIREL-01 is claimed by Plans 09, 10, and 14; CIREL-02 by Plans 11–14. Task actions cover the selected registration cause/control path, exact five required names, five browser seams, six hosted canary scenarios, independent verifier, normal PR, and real docs-only PR.
- Context compliance: new plans preserve locked decisions D-01–D-24; they do not assert that the unknown registration cause is fixed, keep the old Task 2 RED-byte loss explicit, and exclude deferred product/API, rules/default-branch, release, broad-upgrade, Phase 254 and Phase 255 work.
- Dependencies are acyclic and waves are consistent: 09/11 in Wave 1; 10/12 in Wave 2; 13 in Wave 3 after 10/12; 14 in Wave 4 after 13. Same-wave plans do not name a specific shared mutable resource requiring an undeclared ordering edge.
- Scope: the six plans contain 13 tasks, with no plan above three tasks. Their estimates are all low-confidence and do not substitute for the missing registration run allocation; the estimates report 35k, 43k, 35k, 42k, 45k and 27k tokens respectively.
- Key artifact wiring is stated for the runner/verifier/receipts, canary fixture/verifier, PR collector/verifier, and completion/reconciliation path. Plan 14 only creates the old Plan 08 disposition after both requirements are accepted and byte read-back succeeds.
- Deterministic probes supplied for command paths and failing directions both report 0 blockers and 0 warnings across 30 commands; their verdicts were consumed without rerunning or re-deriving. The edge coverage artifact retains its three unresolved probes (CIREL-01 unclassified; CIREL-02 empty and encoding) without claiming resolution.
- The new threat IDs T-253-17 through T-253-28 are unique and high severity; no new API/schema/dependency work is planned. Historical Plans 02/07 remain halted, Plan 08 blocked, and no current evidence indicates whole-phase verification has started.
- `253-11` owns the canary request/job/time ceiling and preflight; `253-12` consumes it. `253-13` predeclares a separate shared 120-request/60-minute budget for both PR families. The ambiguity identified above is limited to the registration control runs crossing Plans 09 and 10.

### Recommendation

1 blocker requires revision before execution. Return the registration budget allocation to the planner; leave all original plans and evidence unchanged. Once revised, re-check only the changed recovery plans and their cumulative run ledger.
