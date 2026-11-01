# Ready for one source-specific approval

The executable bundle is `bundle.json`. Its SHA-256 is recorded in `approval-request.json`. No live approval or allocation exists. Nothing was published during preparation.

The proposed action publishes the exact repaired source `5e13621e50e646c63e135035080d2e6e46fbc955` under three new, create-only refs, then opens two draft PRs: one normal PR to main and one documentation-only PR to the scoped docs base. This should trigger two automatic CI runs. It dispatches no workflow, repeats no canary, reruns no job, and merges nothing.

The new publication ceiling is 24 measured HTTP requests; the exact prepared publication sequence uses 15. Both PRs share one separate 120-request ceiling. Each window lasts at most 60 minutes. These are proposed new windows; every prior window stays closed. A current API rate-budget read and exact main/ref checks precede publication. Changed main or an occupied ref stops before any write. One collector polls each run at 60-second intervals. Rate-limit responses or 250 remaining core requests stop the window.

After approval, record its literal answer, exact bundle hash and an expiry no more than 24 hours from approval in new `live-approval.json` and `prs-approval.json`; commit both before running. The latter also needs the existing outward-action approval schema, `docs_and_prs` section and its digest from `actions.json`. Templates are in `approval-request.json`. Old approval files fail this protocol. Run `python3 -B .planning/execution/253-plan172-repaired-source/run_pair.py --run` only once. Any existing `run-state.json` means inspect the recorded attempt; never restart it.

The independent checker requires both actual PRs to use the identical new source freeze, verifies the real API responses and browser artifacts, then checks the retained canary results with their original source/run identities. It rechecks that the gate inputs did not change. It creates a requirements result only after the actual new pair verifies. No hosted result exists yet.

Even a successful pair leaves the original selected registration failure unreproduced. It cannot complete CIREL-01 or Phase 253. The 29 historical halts, Plan 179 receipt, Plan 180 history and all old budgets remain unchanged.

The approval checkpoint comes from Plan 172's requirement for fresh, source-specific approval and the invoked [gsd-execute-phase skill](/Users/jon/.agents/skills/gsd-execute-phase/SKILL.md): “Preserve all workflow gates (wave execution, checkpoint handling, verification, state updates, routing).” Earlier approvals authorized closed attempts on other source revisions; they do not activate these new windows.
