# Phase253 recovery reset

The user requested lessons and an end to the repeated repair loop after Plan183. This instruction supersedes the old immediate `plan-phase253 --gaps` route. It does not change historical results or close a requirement.

## Current position

- The original target is still CIREL-01 (reproduce/fix selected current CI failures) and CIREL-02 (preserve required work and prove failed/missing work cannot go green).
- Plan183 remains halted. Quick261020-swa reconnects179 to a separately verified maintenance prerequisite;180 still waits for an actual179 receipt. Its historical count/owner simulation must account for halted183 before execution.
- Local maintenance is recorded separately in253-MAINTENANCE-RESULT.json. Read its actual test result; do not assume a pass.
- Current model:183plans,75completed implementation plans,28halted,80without summaries. No new numbered plan was created.

## Resume without restarting the loop

1. Read253-LEARNINGS.md and253-MAINTENANCE-RESULT.json. Inspect the current source diff/commits and the two original requirement descriptions.
2. Do not add another repair plan or increment183/27/73 merely to correct a development test. Keep historical fixtures frozen. Do not alter requirements to fit a passing local result.
3. Keep the existing acceptance/reproduction/request limits and old stopped attempts intact. No183 test replay becomes a new183 result. No local maintenance pass creates a real179 receipt or authorizes its once-only command.
4. Before any future acceptance, identify the smallest actual requirement still missing, its existing proof owner, and a lawful execution path from current state. The explicit quick261020-swa recovery decision replaces the183-dependent acceptance prerequisite with253-MAINTENANCE-PREREQUISITE.json. Read-only verify-prerequisite must pass. No completed183 summary is manufactured.
5. Concentrate subsequent work on the original requirements: the unresolved registration reproduction and the remaining real hosted required-gate cases. Preserve the selected-source/tool identities, independent evidence checks and already-spent limits. If a required item cannot be proven within them, report that exact item as blocked.
6. Report separate outcomes: local checker tests; actual CI behavior; phase verification. Stop counting plan/review volume as progress.

Next scoped command: `$gsd-execute-phase 253 --gaps-only --wave 1`. This selects only179 offline acceptance. No acceptance was run or budget renewed by the quick task. After179, use `$gsd-progress` to inspect actual remaining gaps; do not automatically continue into180 or hosted CI.

Phase254 remains pending, without context/research/plans. After actual253completion, recheck its readiness; the default forward command is `$gsd-discuss-phase 254`. This reset does not start254 or waive253.
