## ISSUES FOUND

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks  
**Plans checked:** 10 (253-26 through 253-35)  
**Issues:** 0 blocker(s), 0 warning(s), 1 info

### Coverage and plan summary

| Requirement | Plans | Status |
|-------------|-------|--------|
| CIREL-01 | 26–30, 34–35 | Covered; strict native cause/repeat acceptance remains required |
| CIREL-02 | 30–35 | Covered; strict hosted canary, verifier, and real PR acceptance remain required |

| Plan | Tasks | Wave | Status |
|------|-------|------|--------|
| 26 | 2 | 1 | Structurally valid; prior Node 20 shared-implementation blocker addressed |
| 27 | 2 | 2 | Valid |
| 28 | 2 | 3 | Valid |
| 29 | 3 | 4 | Valid |
| 30 | 2 | 5 | Valid |
| 31 | 2 | 6 | Valid |
| 32 | 2 | 6 | Valid |
| 33 | 3 | 7 | Valid |
| 34 | 2 | 8 | Valid |
| 35 | 2 | 9 | Valid |

The revised Plan 26 places the control logic in one plain JavaScript ESM module. Its offline Node 20 test imports and invokes the same exports dynamically imported by the opt-in Playwright callbacks. The task requires behavioral RED assertions against the original sequencing/account behavior; loader failures and source-text checks do not count. This satisfies the previous blocker’s required property without adding a runtime dependency or changing the Node version.

The dependency graph is acyclic and wave assignments follow dependencies. Plans 31 and 32 share Wave 6 but have disjoint file ownership and do not name a shared mutable resource. All 22 tasks have files, action, verification, completion criteria, and a stated failing direction; the supplied direction probe reports `ok` for all covered commands. Structural probes pass for all ten plans. Requirements, locked decisions D-01 through D-24, threat IDs T-253-51 through T-253-70, and the stated scope boundaries are represented in executable task contracts. The plans preserve the failed 121,252 ms command and unknown historical registration cause/order. Plan 29 blocks accepted target proof without demonstrated cause/repair and fresh repeats or an adequately reviewed no-flake path; plans 33–35 require real hosted evidence and accepted-only disposition. Whole-phase verification remains explicitly pending.

Budget arithmetic preserves the prior charges and zero available retry: five regular native commands, nine conditional acceptance commands, and at most three applicable seed checks remain within the stated ceilings. Canary accounting remains 117 new measured requests plus three known historical command reservations, with 45 jobs/60 minutes; both production PR families share 120 requests/60 minutes. No additional native launch or hosted request is authorized by these plans.

### Advisories

**1. [verify_command_path_resolvability] Automated command target resolution was not established by the supplied probe**
- Plans: 253-26 through 253-35
- Evidence: `paths.result.status` in `253-CONTROL-RECOVERY-PARENT-REVISION-PROBES-01.json` is `not_applicable`; the probe reports no target verdict for the new commands. Some targets are planned outputs created by earlier tasks, so this is not evidence that a target is missing, but it also does not prove command-path resolution.
- Example follow-up (non-binding): Preserve the probe result as unresolved until the workflow’s applicable path check can evaluate these commands and their planned-output dependencies.

### Structured Issues

```yaml
issues:
  - plan: null
    dimension: verify_command_path_resolvability
    severity: info
    required_property: "Each automated command targets a resolvable executable or an output produced before that command runs"
    description: "The supplied path probe reports not_applicable and supplies no target-resolution verdict for plans 253-26 through 253-35; planned-output dependencies are expected, but resolution is not proven by this probe."
    fix_hint: "Retain this as unresolved until the applicable path probe can evaluate existing command targets and planned-output dependencies."
```

### Recommendation

Advisory only — no revision required. The only unresolved check is command-path resolution, which the supplied probe did not evaluate; it does not establish a broken path.
