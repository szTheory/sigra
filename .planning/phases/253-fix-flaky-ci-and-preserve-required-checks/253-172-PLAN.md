---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "172"
type: execute
gap_closure: true
wave: 8
depends_on: ["253-169"]
autonomous: false
requirements: ["CIREL-01", "CIREL-02"]
files_modified:
  - .planning/execution/253-proof-bundle-a6838a8f9/live-approval.json
  - .planning/execution/253-proof-bundle-a6838a8f9/canary-approval.json
  - .planning/execution/253-proof-bundle-a6838a8f9/prs-approval.json
  - .planning/execution/253-proof-bundle-a6838a8f9/run-state.json
  - .planning/execution/253-proof-bundle-a6838a8f9/attempt-result.json
  - .planning/execution/253-proof-bundle-a6838a8f9/canary-evidence.json
  - .planning/execution/253-proof-bundle-a6838a8f9/normal-evidence.json
  - .planning/execution/253-proof-bundle-a6838a8f9/docs-only-evidence.json
  - .planning/execution/253-proof-bundle-a6838a8f9/requirements-result.json
must_haves:
  truths:
    - "No hosted action before new explicit source-specific approval. Prior yes responses and closed budgets confer no permission."
    - "Plan171 remains halted and its19 requests unchanged. Repaired-source evidence is a separate attempt."
    - "Sourcea6838a8f9 and all fresh refs/objects/action digests are exact; zero reruns."
    - "The original selected flaky failure remains not_reproduced unless new evidence actually proves it; normal PR success alone cannot satisfy that clause."
    - "Phase verification follows actual retained results; no task or phase is marked complete from offline or synthetic evidence."
---

<current_execution_update>
Four prior attempts remain closed. The latest is preserved at dc1e552aa in .planning/execution/253-proof-bundle-4734916ee/: all six canaries and independent verifier passed; PR340 CI failed in the library suite; the verifier correctly rejected the missing fresh preflight; docs-only PR was never created. It used93 canary and30 PR requests,37 canary jobs,7 dispatches and1 draft PR, with0 reruns. Do not run any old operator.

The repaired product is pinned at a6838a8f9e107a49e11ea47ef34e3171fe15eed0. This plan uses .planning/execution/253-proof-bundle-a6838a8f9. The collector now distinguishes the operator's two shared reads from the required full preflight. Its local HTTPS regression runs actual transport, both PR families and the independent verifier. The Elixir guard reads and checks the same source-pinned fixture as the Node guard. The full exported-candidate library suite and full local collector suite must pass. The generated startup regression must reach the real generated collector preflight. Keep prior receipt, namespace, source, approval and closed-window controls.

Continue the same unfinished Plan172. No new quick or numbered plan. New exact approval is required for this changed-source bundle; old approvals cannot be reused. Both requirements remain open; Phase253 verification has not started.
</current_execution_update>


<objective>
Resume normal phase execution using the verified repaired-source bundle. Obtain the one necessary hosted approval, then execute its fresh canary and normal/docs-only PR proof. Preserve every earlier outcome; do not create another numbered repair plan or quick task.
</objective>

<context>
Only completed169 is a scheduling predecessor. Actual readiness still requires this bundle's new approval and unchanged source/window guards.

Earlier preserved history (the fourth attempt is recorded above): first32 requests/no dispatch (e93140048); second41 requests/one full-pass run rejected by the namespace check (0da925d9f); third93 canary plus34 PR requests, all six cases and separate verifier passed, actual PR339 failed, no docs-only PR (a4ad7101f). Prior approvals are consumed. Source16800f431,171/PR338 halt,179 receipt,180 history and all29 historical halts remain unchanged.

Product repairs are pinned toa6838a8f9. The exact candidate inherits main's older planning layout; offline tests must run against that candidate rather than the developer checkout. No historical claim is upgraded by the explicit source-pinned fixture. The original selected flaky failure remains not reproduced.

Required reading:
- `.planning/execution/253-proof-bundle-a6838a8f9/README.md`
- `.planning/execution/253-proof-bundle-a6838a8f9/bundle.json`
- `.planning/execution/253-proof-bundle-a6838a8f9/approval-request.json`
- `.planning/execution/253-proof-bundle-a6838a8f9/APPROVAL.md`
- `.planning/execution/253-172-pr340-maintenance/diagnosis.json`
- `.planning/execution/253-proof-bundle-a6838a8f9/plan172-prior.json` (exact prior instructions recoverable ata6838a8f9)
</context>

<tasks>
<task type="checkpoint:decision" gate="blocking">
  <name>Approve the concrete repaired-source hosted attempt</name>
  <decision>Whether to authorize the exact committed bundle, both action sections, fresh create-only refs, one main fetch and the separate117-request/60-minute/45-job canary and120-request/60-minute draft-PR windows, with zero reruns.</decision>
  <context>All four prior attempts are closed. The last canary matrix passed, but PR340 failed and its collector skipped required preflight reads. The repaired sourcea6838a8f9 bundle is new and has not been approved. Show its concrete approval request and stop unless the user has explicitly approved that exact request. Invoking execute-phase does not authorize hosted work.</context>
  <resume-signal>Explicit approval for the committed bundle hash and both sections. Record and commit the three new approval files exactly as APPROVAL.md describes. Never fabricate the user's approval.</resume-signal>
</task>
<task type="auto">
  <name>Execute once, retain actual results and reconcile the two CI requirements</name>
  <action>
After the explicit approval is committed, run the offline self-check, then the single operator command from approval-request.json. It publishes/dispatches/collects only the new bundle. The operator handles all six canary cases, independent verifier and two draft PRs, and stops on any unexpected failure, cap, stale parent, occupied ref or rate-limit response. Never invoke the old R13 scripts.

If run-state.json or attempt-result.json already exists, inspect it; do not rerun the operator. A halted attempt stays halted. Diagnose ordinary deterministic defects inline with saved output, without replenishing or reusing its window and without a new quick/numbered repair plan. Any additional hosted attempt needs another concrete approval; do not hide that as retry.

On successful hosted results, independently reopen the saved canary sources/matrix and both PR families with runtime/ci-hosted-gate-verify.py. Save requirements-result.json with exact source, evidence paths/hashes and literal CIREL-01/CIREL-02 conclusions. CIREL-01 remains partial_not_reproduced under the preserved disposition unless its original selected failure is actually reproduced and fixed. CIREL-02 may be accepted only when the actual new canary/verifier and normal/docs-only checks all verify. Preserve the old171 halt and all29 halted plans, and keep historical budgets literal.

Do not run the original R13 reconciliation script blindly: it assumes the old source/refs and28 halts. Use the actual current result and independent verifier; make any needed additive local consumer correction inline under normal execution, test its rejection of historical substitutes, and preserve all original records. Do not write71 fake successful summaries or mark unexecuted responsibilities as executed.

Write the actual172 summary only after its real result exists, commit machine-readable outputs and update current state. Then follow normal unfiltered execute-phase/phase-goal verification. Requirement gaps remain open when evidence is missing; phase completion is separate from implementation completion. Before routing beyond253, identify the next roadmap phase and run its readiness initializer as AGENTS.md requires.
  </action>
  <verify>
    <automated>python3 .planning/execution/253-proof-bundle-a6838a8f9/operator.py --self-check</automated>
    <automated>python3 .planning/execution/253-proof-bundle-a6838a8f9/runtime/ci-hosted-gate-verify.py --mode canary --scenario matrix --evidence .planning/execution/253-proof-bundle-a6838a8f9/canary-evidence.json</automated>
    <automated>python3 .planning/execution/253-proof-bundle-a6838a8f9/runtime/ci-hosted-gate-verify.py --mode pr --family both --evidence .planning/execution/253-proof-bundle-a6838a8f9/normal-evidence.json --docs-evidence .planning/execution/253-proof-bundle-a6838a8f9/docs-only-evidence.json</automated>
  </verify>
  <done>Actual current hosted evidence independently verified and literal requirements result retained, or an honest durable halt. No old window reset or false phase-completion claim.</done>
</task>
</tasks>

<success_criteria>
New explicit approval exists before external work. The exact pinned source/fresh refs and caps are enforced. Old171 and all other historical records remain unchanged. Actual hosted outcomes and requirements are reported separately from phase verification. Continue through normal GSD execution; do not route to another quick merely to select the obvious next task.
</success_criteria>
