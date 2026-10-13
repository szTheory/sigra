## VERIFICATION PASSED

**Phase:** 253 — Fix Flaky CI and Preserve Required Checks (recovery plans 09–14)
**Plans verified:** 6 new recovery plans; original plans 01–08 remain frozen historical inputs
**Status:** All checks passed

### Coverage Summary

| Requirement | Plans | Status |
|-------------|-------|--------|
| CIREL-01 | 09, 10, 13, 14 | Covered: native registration diagnosis, controls, conditional repeats, five-seam PR integration, and an honest completion gate |
| CIREL-02 | 11–14 | Covered: bounded hosted canary, five required names, native producer records, normal PR, real docs-only PR, and source-bound completion |

### Plan Summary

| Plan | Tasks | Wave | Status |
|------|-------|------|--------|
| 09 | 2 | 1 | Valid |
| 10 | 2 | 2 | Valid |
| 11 | 2 | 1 | Valid |
| 12 | 2 | 2 | Valid |
| 13 | 3 | 3 | Valid |
| 14 | 2 | 4 | Valid |

### Review of prior blocker

The blocker in `253-RECOVERY-PLAN-CHECK-01.md` is resolved. Before any browser result, Plan 09 freezes one cumulative ledger for both Plans 09 and 10. The one selected registration signature runs three diagnostic commands and six control commands, each charged at up to two minutes: 9 D-19 launches / 18 minutes. A single independently diagnosed infrastructure retry is reserved across both stages. If used for reproduction, D-19 becomes 10 launches / 20 minutes; if needed during acceptance, it is charged to a four-minute D-20 slot instead.

D-20 separately authorizes three fresh post-fix runs per affected project, reserving the three-project maximum of 9 launches / 36 minutes. With a retry charged in that stage, it becomes 10 launches / 40 minutes. Thus the two allowed branches total at most 19 launches and 56 or 58 charged minutes, both within the 60-minute aggregate ceiling. Setup, browser, cleanup and failed-attempt time are charged to fixed slots; counters are monotonic and never reset; unused capacity expires; no extra command or borrowing across D-19/D-20 is allowed. If a launch cannot fit its pre-reserved slot and time, the plans stop and leave CIREL-01 open. This meets D-19's 10-launch/20-minute cap for the one selected signature and D-20's separately authorized repeat requirement without increasing either limit.

The six control bundles are each one native Playwright command with the exact cases and expected native failures frozen before the first browser run. The pinned config has 60-second test and 15-second assertion ceilings; these are not a guarantee every multi-case command will finish within its two-minute charge. The plan’s pre-launch fit check and fail-closed stop are the controlling behavior: if the frozen command cannot fit, it must not launch, and the control remains an explicit open gap. This is an execution feasibility constraint handled honestly by the plan rather than a budget extension or acceptance waiver.

### Additional verification notes

- All 24 locked decisions remain represented across the original completed plans and recovery plans. Deferred work (product/API, rules/default branch, releases, broad upgrades, Phase 254 optimization, and Phase 255 reporting) is excluded. The selected cause remains unknown until native evidence proves it; setup-only HTTP 200 evidence does not close CIREL-01.
- Plans 09–14 claim CIREL-01/02 in frontmatter and give tasks concrete files, actions, native or fixture checks, and failing directions. Their artifacts sections use the required heading. TDD behavior contracts and `read_first` inputs are present.
- Dependencies are acyclic and waves agree: 09/11 wave 1; 10/12 wave 2; 13 wave 3 after 10/12; 14 wave 4 after 13. Plan 10 leaves five-seam integration pending; Plan 13 independently checks the exact five frozen selections in its normal PR family; Plan 14 requires that receipt. There is no hidden cycle or premature acceptance.
- The canary and PR plans have distinct finite request budgets, one 60-second watcher per run, rate-limit hard stops, actual job accounting, digest/origin verification, and real PR classifier proof. The five required check names remain exact; no rules, default branch, release, dependency, or product contract changes are planned.
- Plan 14 only creates the Plan 08 supersession record after both requirements are accepted and original bytes are read back; it preserves Plan 08’s unrun tasks and the halted status of Plans 02/07.
- Probe outputs `/private/tmp/sigra-253-recovery-paths-probe-02.json` and `/private/tmp/sigra-253-recovery-failure-probe-02.json` were consumed: the path probe reports `status: not_applicable` for these Bash/Node/Python commands, while the failing-direction probe reports `status: ok`; both contain 30 commands with zero blockers and warnings. The path probe does not establish future file existence. Parent checks separately verify existing paths are tracked and review future creation dependencies.
- AGENTS.md and `test/example/AGENTS.md` constraints are respected. The existing `253-PATTERNS.md` was supplied as reusable phase context and remains unchanged; no new architectural responsibility map is introduced. The supplied edge-coverage artifact’s three probes remain explicitly unresolved, not silently claimed as decisions.
- No implementation, browser, hosted, application, or GitHub work is claimed by this plan review.

### Recommendation

No blockers, warnings, or advisories remain. The plans are ready for the authorized gaps-only execution route.
