---
quick_id: 260926-gzb
phase: quick-260926-gzb
plan: 01
type: execute
wave: 1
depends_on: []
autonomous: true
date: 2026-09-26
status: planned
estimate:
  tokens: 20000
  raw_tokens: 40000
  tasks: 1
  confidence: high
files_modified:
  - test/sigra/planning/phase_232_playwright_economics_test.exs
  - scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
  - .planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-BLOCKED.md
  - .planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-PLAN.md
must_haves:
  truths:
    - "The Phase 232 cache-key contract matches the current keys already declared by the CI workflow."
    - "The Phase 235 authenticated verifier retains its fail-closed network-isolation behavior and its contract tests are not skipped or weakened."
    - "The exact full mix ci gate passes before any authorized source fix is committed; if the host prevents sandbox-exec, the quick task stays incomplete and uncommitted with durable diagnostics."
    - "The four Phase 242 deletions and prior quick evidence/state changes remain untouched and unstaged."
    - "No Phase 244 implementation or branch ref, remote ref, or PR #283 is changed."
  artifacts:
    - path: "test/sigra/planning/phase_232_playwright_economics_test.exs"
      provides: "Phase 232 assertion for current Playwright cache-key versions"
    - path: "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
      provides: "Fail-closed Phase 235 verifier, changed only if a reproducible in-repository defect is proven"
    - path: ".planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-BLOCKED.md"
      provides: "Exact remaining gate failure evidence and incomplete status when a blocker remains"
  key_links:
    - "The Phase 232 test reads the example_playwright_shard job from .github/workflows/ci.yml; its current declared Chromium and WebKit keys are 1.62.1-v3."
    - "The Phase 235 contract test launches scripts/ci/verify-fast-01-source-complete-attestation-offline.sh; that verifier's Darwin path invokes /usr/bin/sandbox-exec with network denial."
    - "MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci is the acceptance gate; no source fix is committed unless it exits successfully."
---

<objective>
Diagnose and resolve only the two Phase 235 sandbox-exec failures and the single Phase 232 Playwright cache-key assertion recorded in the prior blocker evidence, then establish the exact full `mix ci` gate result in the disposable clone.

Purpose: The Phase 242 deletion set is already in the clone, but the required full gate is red. This plan isolates those three named failures while preserving the Phase 242 changes and leaving Phase 244 delivery state alone.
Output: A passing full gate and a local commit containing only authorized Phase 235/Phase 232 source fixes, or a durable host-restriction diagnostic with all new source changes left uncommitted and the quick task incomplete.
</objective>

<execution_context>
@/Users/jon/.codex/gsd-core/workflows/execute-plan.md
</execution_context>

<context>
@/private/tmp/sigra-phase244-plan02-clone/.planning/STATE.md
@/private/tmp/sigra-phase244-plan02-clone/AGENTS.md
@/private/tmp/sigra-phase244-plan02-clone/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/MIX-CI-BLOCKED.md
@/private/tmp/sigra-phase244-plan02-clone/.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/MIX-CI-RETRY.log
@/private/tmp/sigra-phase244-plan02-clone/test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs
@/private/tmp/sigra-phase244-plan02-clone/scripts/ci/verify-fast-01-source-complete-attestation-offline.sh
@/private/tmp/sigra-phase244-plan02-clone/test/sigra/planning/phase_232_playwright_economics_test.exs
@/private/tmp/sigra-phase244-plan02-clone/.github/workflows/ci.yml

Planning-time scope in `/private/tmp/sigra-phase244-plan02-clone`: branch is `gsd-quick/260926-gzb-gate-fix`. The only pre-existing worktree changes are deletions of `.github/workflows/hex-remediate-phantom.yml`, `scripts/ci/prohibitions/p22-hex-remediation.test.mjs`, `test/fixtures/prohibitions/p22-hex-remediation-broadened.yml`, and `test/fixtures/prohibitions/p22-hex-remediation-unsafe-secret.yml`; `.planning/STATE.md` is modified and prior quick evidence is untracked under `.planning/quick/260926-dzu-reconcile-the-phase-242-hex-workflow-con/`. Preserve all of these exactly. The Phase 242 absence contract test is outside scope.

The blocker evidence names two Phase 235 `System.cmd("bash", [@verifier])` failures returning `sandbox-exec: sandbox_apply: Operation not permitted` with exit 71, plus a Phase 232 test that expects `1.59.1-v3` while the live CI workflow declares `1.62.1-v3`. There is no project `.codex/skills/` or `.agents/skills/` directory, no configured `gsd-planner` agent skill, no API integration, no schema work, and no singular/plural or required/optional identity transition in this scope.

Live preflight is required before edits: confirm the clone root and branch, then compare `git status --short` against the preserved set above. If any protected source path, prior evidence, or branch state differs, stop before editing and retain the new observation in this quick directory. Never edit or stage the four deletions, Phase 242 absence contract, `.planning/STATE.md`, the prior quick evidence, Phase 244 implementation files, or any remote/PR state.
</context>

<scope_audit>
GOAL: The stated quick-task goal (resolve only the three named failures and require the full gate) is covered by Task 1.
REQ: No ROADMAP phase requirement IDs apply to this quick task.
RESEARCH: No phase RESEARCH/DISCOVERY artifact applies; live observations of the two tests, CI workflow, verifier, and blocker logs bound Task 1.
CONTEXT: Preserve the four Phase 242 deletions and prior quick state/evidence, avoid Phase 244 and PR #283, and stop uncommitted on a host blocker; these constraints are enforced in Task 1.
</scope_audit>

<tasks>

<task type="auto">
  <name>Task 1: Diagnose the sandbox boundary, repair only the named contracts, and gate before committing</name>
  <files>test/sigra/planning/phase_232_playwright_economics_test.exs, scripts/ci/verify-fast-01-source-complete-attestation-offline.sh, .planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-BLOCKED.md</files>
  <action>
Begin with the live clone preflight: confirm `/private/tmp/sigra-phase244-plan02-clone` is the root on `gsd-quick/260926-gzb-gate-fix`; confirm tracked changes are the four protected Phase 242 deletions plus `.planning/STATE.md`; and confirm the only untracked directories are the prior quick evidence directory named in `<context>` and this active quick directory containing `260926-gzb-PLAN.md`. If any differ, stop without editing. Diagnose Phase 235 by running the named focused contract test and the no-op host probe `/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)' /usr/bin/env true`. Inspect the result against `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh`. In this task only, update the stale Phase 232 test expectations to the live Chromium/WebKit `1.62.1-v3` keys from `.github/workflows/ci.yml`; repair the Phase 235 verifier only if an in-repository defect is independently proven. Preserve the Phase 235 tests and fail-closed network denial, empty HOME, cleared credentials/proxies, and signer/source identity checks.

Run the focused Phase 232 test and the unchanged Phase 235 contract test, then run exactly `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci`. If a diagnosed transient failure occurs, retry the full gate exactly once. Repair only deterministic failures within the three authorized defects and listed source paths. If the host denies sandbox creation or any deterministic gate failure remains, capture the exact commands, exit codes, terminal failure summary, and diagnosis in `.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/MIX-CI-BLOCKED.md`; leave every new source change uncommitted, claim no gate pass, and leave the quick task incomplete. Only after the full gate exits zero may you recheck status and commit the Phase 232 test and any independently proven Phase 235 verifier fix, staging those authorized source paths only. Do not modify or stage the four protected deletions, Phase 242 absence test, prior quick evidence, `.planning/STATE.md`, Phase 244 implementation, remote refs, or PR #283.
  </action>
  <verify>
    <automated>cd /private/tmp/sigra-phase244-plan02-clone &amp;&amp; MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci</automated>
  </verify>
  <done>The task completes only when the exact full gate exits zero and a clone-local commit contains only authorized Phase 232/Phase 235 source fixes; otherwise the complete blocker evidence is recorded, no new source change is committed, and the quick task remains incomplete. The four Phase 242 deletions and prior quick evidence remain untouched and unstaged.</done>
</task>

</tasks>

<threat_model>
## Security Context

Configured enforcement: OWASP ASVS L1; block on high-severity findings. This repair adds no new runtime security surface. Phase 235 validation crosses an ExUnit-to-shell subprocess boundary and must keep the verifier's network isolation and authenticated evidence checks fail-closed.

## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ExUnit → Bash verifier → `sandbox-exec`/`gh` | Test input and process environment reach a shell verifier that must deny network access and validate retained attestation evidence. |
| Authorized quick diff → shared disposable clone | New changes coexist with protected Phase 242 deletions and previous quick evidence that must remain unstaged. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260926-GZB-01 | Tampering | Phase 235 verifier subprocess boundary | high | mitigate | Preserve fail-closed network isolation, credential clearing, and signer/source checks; if the host rejects sandbox creation, record the failure and stop without bypassing the boundary. |
| T-260926-GZB-02 | Tampering | Clone-local staging and commit | medium | mitigate | Recheck live status and stage only the exact authorized Phase 232/Phase 235 source paths after the full gate passes; leave all pre-existing deletions and evidence unstaged. |
</threat_model>

<verification>
Run the two focused test files as scoped diagnostics, then execute the exact `MIX_ENV=test HEX_HOME=/private/tmp/sigra-phase244-hex-cache mix ci` gate, retrying once only for a diagnosed transient failure. A zero exit is required for any source commit. A repeated host `sandbox-exec` operation-not-permitted error is a blocker, not a green result: preserve the exact command and error in `MIX-CI-BLOCKED.md`, leave all new source changes uncommitted, and leave the quick task incomplete. Confirm no protected Phase 242 path, previous evidence/state, Phase 244 implementation, branch ref, remote ref, or PR #283 changed.
</verification>

<success_criteria>
The only source changes are the named Phase 232 expectation correction and, only if independently proven necessary, a Phase 235 verifier fix that preserves its security contract. The full gate passes before those source paths are committed locally. If the host restriction persists, the quick directory contains exact failure diagnostics and no new source commit exists. The four Phase 242 deletions and prior quick evidence remain untouched and unstaged; no Phase 244 branch or PR action occurs.
</success_criteria>

<output>
The quick plan is `.planning/quick/260926-gzb-diagnose-and-resolve-only-the-phase-235-/260926-gzb-PLAN.md`. If blocked, retain `MIX-CI-BLOCKED.md` beside this plan and leave the quick task incomplete and its source fixes uncommitted.
</output>
