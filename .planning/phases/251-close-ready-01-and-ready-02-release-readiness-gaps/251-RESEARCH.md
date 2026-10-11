# Phase 251: Close READY-01 and READY-02 Release Readiness Gaps - Research

**Researched:** 2026-10-11
**Domain:** Source-bound release evidence and deterministic owner verification
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### READY-01 exact evidence and approval
- **D-01:** Evaluate READY-01 against a single complete candidate tuple: candidate SHA, reviewed base SHA, protected-main SHA, exact-source CI result, readiness record, and authenticated non-publishing dry-run. Bind every item to the same source identity; do not combine records from different candidate tuples. Evidence: `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json`, `247-10-REBIND-PROPOSAL.json`, and `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json` and `250-247-TUPLE-DECISION-PACKET.json` show mismatched identities and no eligible tuple. If this assumption is wrong, a mixed evidence set could falsely mark the 1.6.0 candidate ready.
- **D-02:** Preserve the original approval bar. Only a contemporaneous approval that names or cryptographically binds the exact candidate/source/CI/readiness/dry-run record can satisfy READY-01. The user confirmed this rule for Phase 251. A broad authorization, later approval, or this Phase 251 scope approval cannot be substituted for missing historical candidate approval. If the exact approval cannot be recovered, record `authorization_pending` and leave READY-01 unsatisfied. Evidence: `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json` and `250-247-TUPLE-DECISION-PACKET.json`; the existing reconciliation reports no eligible candidate. If this assumption is wrong, the phase would change the milestone's public readiness/truth contract.

### READY-02 current inventory and preservation
- **D-03:** Refresh the open-PR and inherited-work populations at evidence capture time. Give every observed item one explicit release-blocking, release-relevant, or separate-follow-up disposition. For inherited work, retain a recoverable preservation identity and record where it can be read back. Do not use an old inventory as proof of current completeness. Evidence: `.planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md`, `247-VALIDATION.md`, and the READY-02 blockers in `250-247-RECONCILIATION.json` report that fresh PR dispositions and preservation joins are missing. If this assumption is wrong, current work could be lost or silently included in release work.
- **D-04:** Keep original ownership and verdicts authoritative: Phase 247 owns READY-01/02. Phase 251 may refresh the owner evidence and verifier, but must not claim the requirements as newly implemented, mark unchecked requirements satisfied without their full acceptance evidence, or use Phase 250's phase-only exception as a pass. If proof remains unavailable, preserve `gaps_found` and the incomplete milestone status.

### Verification and scope
- **D-05:** Prefer read-only live inventory, exact-source artifact checks, and deterministic tests over manual UAT. Record capture time, exact identities, source paths, and hashes for evidence; label historical snapshots as historical. No new workflow dispatch, merge, publish, release, or candidate mutation is in scope, as confirmed by the user.
- **D-06:** Keep CI/CD timeout, reliability, and release-lane follow-up ideas outside Phase 251. The user's earlier instruction places that optimization work after the current milestone. Phase 251 only determines whether READY-01/02 can be proven from the required evidence.

### the agent's Discretion
- Choose the smallest deterministic verifier and evidence-ledger updates that preserve Phase 247 ownership and existing schemas.
- Refresh external read-only observations when planning/execution needs current facts; do not transplant live values into historical source records.
- If evidence is absent or a live read is unavailable, record the precise blocker and stop the affected requirement at unsatisfied.

### Deferred Ideas (OUT OF SCOPE)
- CI/CD timeout, reliability, and release-lane optimization after v1.49, as requested by the user.
- Any broad release workflow redesign, new canary, package publish, release, merge, or product change.
- **Reviewed Todos (not folded)**
- `.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` and `.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` — release-lane CI/CD improvements are deferred beyond this milestone per the user's instruction.
- Other broad keyword matches from `todo.match-phase 251` are unrelated or historical and were not folded into this evidence-only phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| READY-01 | One exact 1.6.0 candidate/source/base/main tuple proves package metadata, manifest, changelog, tag/source reference, adopter notes, exact-source CI, readiness, authenticated non-publishing dry-run, and contemporaneous approval. | Extend the source-bound tuple evaluator and approval predicate; preserve separate historical records; fail closed if approval or any tuple member is missing. |
| READY-02 | A fresh inventory accounts for every open PR and inherited checkout change, with explicit dispositions and recoverable preservation; release work proceeds from a clean source checkout. | Capture complete current PR identities and inherited commit/path populations; join each to disposition and readable preservation records; compare before/after snapshots. |
</phase_requirements>

## Summary

This phase is a repository-evidence workflow, not an application feature. The reusable core is already present: Phase 247 has a package/readiness ledger and validator, while the Phase 250 verification package has a tuple evaluator, exact-head CI receipt join, fresh-population join, preservation-reference read-back, deterministic blockers, and an owner-report renderer. Reuse those contracts and add only the missing Phase 251 capture/persistence boundary and focused regression coverage. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:7-27; .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:41-75,122-169,356-381]

The current recorded decision packet has no eligible candidate tuple: it records `"eligible_tuples": []` and `"status": "blocked"`. Its parent readiness/dry-run evidence is bound to one source, the corrected child has CI evidence but no matching readiness or dry-run receipt, and the later PR observation has no matching receipt/readiness/browser evidence. The owner report records both READY requirements unsatisfied and identifies pending approval, mismatched tuples, missing fresh PR dispositions, and missing inherited-work preservation joins. Treat this as a historical capture; refresh live facts separately and never rewrite those old identities as though they were captured now. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-TUPLE-DECISION-PACKET.json:282,289; .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md:6-16,22-40]

**Primary recommendation:** Produce an immutable Phase 251 evidence packet from read-only observations, then have the Phase 247 owner verifier consume it. Keep READY-01 blocked unless a contemporaneous approval binds the complete source/CI/readiness/dry-run record. Keep READY-02 blocked unless the refreshed PR and inherited-work identities exactly join to dispositions and preservation records that can be read back. [VERIFIED: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:9-11,18-32]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Capture live repository, PR, and CI observations | Verification runner (Node.js CLI) | GitHub CLI/API | Existing verifier captures local Git and read-only GitHub observations, then evaluates immutable source identities. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:116-167,279-295] |
| Join readiness, CI, dry-run, and approval evidence | Verification runner (Node.js CLI) | Evidence files | Tuple comparison and CI receipt validation are implemented in the verifier; approval must remain an exact historical input. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:37-48,103-119,122-157] |
| Inventory and disposition inherited work | Verification runner (Node.js CLI) | Git refs and evidence ledger | Population joins and ref read-back belong to the verifier; durable preservation lives in Git refs and hashed records. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:54-90] |
| Reconcile owner verdict and milestone traceability | Phase 247 owner report / source-derived audit | REQUIREMENTS.md and milestone audit | READY ownership is Phase 247; the traceability checker recomputes owner status and milestone state from source reports. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:7-34,301-329,471-504] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Node.js built-ins (`node:fs`, `node:path`, `node:crypto`, `node:child_process`, `node:test`) | Node v26.10.0 in this workspace | Evidence parsing, SHA-256, Git/CLI invocation, deterministic contract tests | Existing owner and audit verifiers use built-ins and no added package dependency. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:3-7; node --version output: v26.10.0] |
| Git | v2.41.0 in this workspace | Immutable commit/ref lookup and preservation-record read-back | Existing validation checks refs resolve to commits and hashes bytes obtained from the ref. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:77-90; git --version output: 2.41.0] |
| GitHub CLI (`gh`) | v2.101.0 in this workspace | Read-only PR, main, workflow-run, and job observations | Existing capture uses `gh api` and `gh pr list`; Phase 251 must keep these calls read-only. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:120-122,132-167; gh --version output: 2.101.0] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `node:test` | Node built-in | Unit/contract coverage for tuple joins, missing proof, race detection, and preservation read-back | Use for deterministic verifier changes; existing suites already cover these domains. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs:38-93,122-179,195-235] |

No package installation is indicated by the current code or phase context. Package legitimacy audit: not applicable. [VERIFIED: .planning/config.json:1-34; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:70-87]

**Installation:** None.

## Architecture Patterns

### Recommended Project Structure

Keep the evaluator and its regression tests with the existing readiness verifier; put a new capture packet and execution summary in the Phase 251 directory; have the Phase 247 owner verification point to the new packet while retaining Phase 250's reconciliation as a historical record. The current capture implementation writes both its reconciliation and the Phase 247 owner report, so planning should make the output path explicit before reusing that writer. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:9-19,303-353,376-381]

### Pattern 1: Immutable source tuple with independent artifact joins

**What:** Compare candidate SHA, reviewed base SHA, protected-main SHA, CI run/attempt/head/job, readiness tuple, dry-run requested and checked-out SHA, and approval identity as a single tuple. Record every input file path and digest in a new capture packet. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:122-157,318-352]

**When to use:** READY-01 only. Do not reuse a successful parent receipt for a child SHA or substitute the current main value into a historical tuple. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-TUPLE-DECISION-PACKET.json; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:17-20]

**Approval constraint:** The current evaluator checks the proposal status, an immutable approval flag, and candidate/base/main equality, but does not compare an approval digest against the CI, readiness, and dry-run artifacts. Add that full binding or leave the proof blocked; do not infer it from current conversation authorization. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:37-39,140-142; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:18-20]

### Pattern 2: Fresh exact-identity population join

**What:** Capture complete PR identities and inherited commit/path identities, then require one disposition per observed item. Recheck the identity set after capture to detect movement. For preservation, verify that the ref resolves to the recorded commit and that the record bytes at the ref match the recorded SHA-256 and disposition identity. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:54-90,93-100]

**When to use:** READY-02. The phase contract explicitly requires a fresh inventory, all-item dispositions, and read-back identities for inherited work. [VERIFIED: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:21-27]

**Existing contract values:** The Phase 247 validator declares `const DISPOSITIONS = new Set(['release-blocking', 'release-relevant', 'separate-follow-up']);` and `const KINDS = new Set(['committed', 'dirty']);` [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:7-8]. Preserve these values verbatim when the phase ledger records disposition categories and inherited path kinds.

**Existing preservation shape:** A record includes `ref`, `commit_sha`, `record_path`, and `record_sha256`; the validator reads the commit and bytes through Git before accepting it. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:77-90]

### Anti-Patterns to Avoid

- Mixing the Phase 247 saved-readiness tuple, later proposed tuple, and later closed-PR observation into one passing evidence set. The existing packet records three different tuples and zero eligible tuples. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-TUPLE-DECISION-PACKET.json]
- Treating Phase 250's accepted-exception amendment as READY acceptance. The audit checker requires READY exceptions to remain owner-unsatisfied, unchecked, and limited to Phase 250 closeout. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:131-155,495-503]
- Running the existing `--capture` writer without adjusting its destination: it writes the Phase 250 reconciliation and Phase 247 owner report. Preserve the old capture and give Phase 251 its own evidence output. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:12-17,376-381]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SHA-256 and Git object identity | Custom hash or ref parser | Node `crypto` plus Git `rev-parse` / `show` calls already used by the verifier | The existing check proves both ref-to-commit and ref-to-bytes identity. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:25-27,77-90] |
| Readiness source and disposition validation | A parallel readiness ledger/schema | Extend `validate-release-readiness.mjs` and its fixtures | It already rejects incomplete arrays, duplicate IDs, invalid identities, missing dispositions, and population mismatches. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:43-113] |
| Milestone requirement status | Manual checkbox/report reconciliation | `verify-v149-traceability.mjs` and its generated audit | It recomputes owner status, requirements traceability, and phase/milestone integrity. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:471-568] |

**Key insight:** Freshness and identity are separate checks. A fresh observation can still be ineligible if its tuple lacks contemporaneous approval or does not match stored CI/readiness/dry-run evidence; an old complete inventory cannot prove the current population. [VERIFIED: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:9,18-27]

## Code Examples

### Fail-closed population join

Use the existing population join for each captured set, and surface its blockers without converting an incomplete result into a pass. The implementation returns `status: blockers.length ? 'blocked' : 'passed'` and sorts blocker IDs. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:67-74]

```js
const result = joinPopulation({ observedIds, dispositions, label: 'inherited_work' });
if (result.status !== 'passed') blockers.push(...result.blockers);
```

For READY-02, make `observedIds` represent the full identity key, including each PR number/head/base tuple or each inherited commit/path identity; the current sample uses only numeric PR IDs and needs this strengthening. The existing call passes `label: 'inherited_work'`. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:54-73,93-100,168]

## Common Pitfalls

### Pitfall 1: Approval appears present but binds too little

**What goes wrong:** A boolean `immutable` approval and equal candidate/base/main tuple can pass while approval does not bind exact CI, readiness, and dry-run records. **Why it happens:** `sameTuple` currently compares only those three SHA fields. **How to avoid:** Require the historical approval record to bind the complete evidence tuple or keep `authorization_pending`. **Warning signs:** Approval has no digest/identifiers for CI run+attempt, readiness record digest, or dry-run receipt digest. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:37-39,140-142; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:18-20]

### Pitfall 2: PR population is fresh by number but stale by identity

**What goes wrong:** A PR head or base moves without changing the open PR number set, so a number-only stability comparison misses it. **Why it happens:** `liveSnapshotStable` compares PR #224's head/base and the open PR number set; the generic `captureLive` list contains only numbers. **How to avoid:** Capture every open PR's number, head SHA, and base before and after inventory; compare the full sorted identity set and bind each disposition to that identity. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:93-100,279-295]

### Pitfall 3: Existing capture command overwrites historical evidence

**What goes wrong:** A Phase 251 capture replaces the Phase 250 reconciliation and the Phase 247 report's prior bytes. **Why it happens:** The current `--capture` entry point calls `writeCapture`, which writes both paths. **How to avoid:** Add a Phase 251 destination and preserve dirty planning artifacts before any rewrite; reread source status/hash and verify preservation read-back first. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:376-390; AGENTS.md: planning artifact write-ahead preservation]

### Pitfall 4: Partial population treated as complete

**What goes wrong:** A capped/paginated PR response or omitted inherited paths gets interpreted as a complete inventory. **How to avoid:** Record read status, pagination/count, full identity arrays (including explicit empty arrays), and a stable before/after fingerprint; any unreadable or changed set blocks READY-02. Existing Phase 247 validation requires array snapshots and compares observed versus recorded sets. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:43-49,92-113; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:21-32]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rely on Phase 247's saved inventory and dry-run/readiness narrative | Capture fresh external populations and verify immutable IDs, per-artifact hashes, and read-back preservation | Phase 250 established source-derived reconciliation; Phase 251 context now requires fresh joins | Historical evidence remains useful as history but cannot be promoted to a current pass. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:18-32] |
| Treat phase-level accepted exceptions as milestone closure | Keep exception provenance separate from canonical Phase 247 owner verdict and milestone acceptance | Phase 250 amendment | READY stays unchecked/unsatisfied until Phase 247's complete acceptance evidence passes. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-ACCEPTANCE-AMENDMENT.json:13-23,69-74; verify-v149-traceability.mjs:495-503] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub CLI authentication and read access will be available when Phase 251 executes; it was not probed during this read-only research pass. | Environment Availability | Live evidence capture cannot complete; verifier must record the unavailable read as a blocker. |
| A2 | Phase 251 should preserve Phase 250's reconciliation packet as historical evidence and add a new Phase 251 packet. | Architecture Patterns | Reusing the old output path would destroy the distinction between historical and refreshed observations. |
| A3 | If refreshed owner evidence changes, the milestone audit needs a compatible historical-exception treatment while retaining Phase 250's amendment bytes. | Common Pitfalls | Existing audit binds exception rows to the current owner report hash and rejects an accepted exception once the owner status changes. |

## Open Questions

1. **Can the contemporaneous exact-source approval artifact be recovered? (RESOLVED for planning; factual result is execution-time.)**
   - What we know: the captured owner report says approval was pending and no immutable approval was present; the Phase 251 context forbids substituting current scope authorization. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/247-VERIFICATION.md:11,29-40; .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:18-20]
   - What's unclear: whether an authoritative historical approval record exists outside the checked-in evidence.
   - Planning resolution: no planning decision depends on the artifact existing now. During execution, search only authoritative read-only historical sources and bind any recovered approval to the complete exact tuple; if unavailable or mismatched, retain `authorization_pending` and leave READY-01 unsatisfied. Do not request or accept a new approval.
2. **Will current open PR identities and local inherited checkout populations be stable during capture? (RESOLVED for planning; factual result is execution-time.)**
   - What we know: the captured historical inventory differs from its stored population, and the current verifier's generic stability check does not compare every PR head/base. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-TUPLE-DECISION-PACKET.json; .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:93-100,279-295]
   - What's unclear: current execution-time population and preservation refs.
   - Planning resolution: execution must capture complete PR and inherited-work identities before and after preparation, including PR number/head/base, and require exact population equality and preservation read-back. API/local read failure, cap ambiguity, identity movement, or unreadable preservation remains a named READY-02 blocker; no manual assumption can fill the gap.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Evaluator and `node:test` suites | ✓ | 26.10.0 | — |
| Git | Current checkout and preservation ref read-back | ✓ | 2.41.0 | — |
| GitHub CLI | Read-only live PR/main/workflow observations | ✓ | 2.101.0 | No evidence fallback; mark affected join blocked if read access is unavailable. |

GitHub authentication was not checked, and no external API reads were made during research. [VERIFIED: environment version probes; execution boundary in 251-CONTEXT.md:9-11]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Node.js built-in `node:test` (workspace Node 26.10.0) |
| Config file | None required for these direct Node test files |
| Quick run command | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` |
| Existing readiness command | `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` |
| Audit contract tests | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` |
| Read-only audit source check | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-sources` |
| Generated audit consistency check | `node .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs --check-audit` |

These suites are source-listed and their recent recorded results are present in validation/reconciliation artifacts; they were not run during this research pass. [VERIFIED: .planning/phases/247-release-candidate-and-repository-readiness/247-VALIDATION.md:15-26; .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-247-RECONCILIATION.json]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| READY-01 | Approval binds exact candidate/source/base/main plus CI, readiness, and dry-run identities; mixed/stale joins remain unsatisfied. | Unit/contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs` | Yes; extend for full approval digest binding and preserved historical report path. |
| READY-02 | Every fresh PR identity and inherited commit/path has one explicit disposition; each inherited preservation ref reads back matching bytes; changed population blocks. | Unit/contract | Same verifier suite plus `node --test .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs` | Yes; extend for per-PR head/base population race and full identity joins. |
| READY-01/02 → milestone | Requirements and audit agree with the Phase 247 owner result; accepted Phase 250 exceptions remain phase-only. | Audit contract | `node --test .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs` | Yes; extend for a refreshed Phase 247 report and historical amendment handling. |

### Sampling Rate

- **Per task commit:** run the focused verifier test suite.
- **Per wave merge:** run all three commands above.
- **Phase gate:** run the strict source-derived milestone audit after owner evidence and any requirement traceability update.

### Wave 0 Gaps

- Add regression fixtures for approval binding to CI/readiness/dry-run digests, all-PR full identity stability, and non-overwriting Phase 251 capture output. Existing tests cover pending approval, stale dry-run, incomplete populations, preservation read-back, and deterministic blocker ordering. [VERIFIED: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs:38-93,122-179,195-235]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Validation and Business Logic | Yes | Validate evidence inputs and reject mixed identities or incomplete populations. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x11-V2-Validation-and-Business-Logic.md] |
| V6 Authentication | Yes | Require authoritative read evidence and the contemporaneous candidate approval. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x15-V6-Authentication.md] |
| V7 Session Management | No | No application user session is in scope. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x16-V7-Session-Management.md] |
| V8 Authorization | Yes | Keep observations read-only; do not dispatch, merge, publish, release, or mutate candidate state. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x17-V8-Authorization.md] |
| V11 Cryptography | Yes | Use SHA-256 for integrity checks and Git object identity; do not introduce custom cryptography. [CITED: https://github.com/OWASP/ASVS/blob/master/5.0/en/0x20-V11-Cryptography.md] |

The current OWASP ASVS stable release is 5.0.0, whose category numbering differs from older ASVS 4.x labels; the table uses the current 5.0.0 category names. Applicability is mapped to this phase's repository/API evidence boundary. [CITED: https://github.com/OWASP/ASVS; VERIFIED: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:9-11,18-32; .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:25-27,77-90,116-167]

### Known Threat Patterns for Evidence Verification

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale or cross-candidate artifact substituted into a tuple | Tampering | Exact SHA/run/attempt and record-digest equality; reject mixed tuple. |
| PR changes during inventory | Tampering / repudiation | Capture full identity set before and after; stop on mismatch. |
| Approval record absent or bound to only partial identities | Repudiation | Require contemporaneous approval for complete evidence tuple; preserve `authorization_pending` if unavailable. |
| Preservation ref points to altered or unreadable bytes | Tampering | Resolve ref to commit and recompute digest from the record bytes read from that ref. |

## Project Constraints (from AGENTS.md)

- Admin UI directives (brand assets, theme modes, and UI selectors) do not apply because this phase has no product UI. [VERIFIED: AGENTS.md:3-10; 251-CONTEXT.md:67]
- Automation-first verification: use deterministic tests and machine-readable evidence for in-scope work; never waive or mark missing proof passed. [VERIFIED: AGENTS.md:12-17]
- Before rewriting dirty `.planning/` records, preserve exact path/status/bytes under a durable scoped ref, verify read-back, then re-read source status and hash before writing. [VERIFIED: AGENTS.md:19-23]
- Limit CI watching to one watcher per run at 60-second intervals; fetch structured summaries once, inspect failed logs only on failures, and stop polling at the stated rate-limit thresholds. Phase 251 does not dispatch workflows. [VERIFIED: AGENTS.md:47-53; 251-CONTEXT.md:9-11]
- At a GSD stopping point, report the exact next command and check the next phase readiness/context before choosing that route. [VERIFIED: AGENTS.md:25-45]
- The task scope is evidence-only and read-only for external observations; no workflow dispatch, merge, publish, release, or candidate mutation. [VERIFIED: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md:9-11,25-32]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-CONTEXT.md` — locked decisions, phase boundary, evidence rules, and deferments.
- `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs` and `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs` — existing source/disposition schema and owner evidence checks.
- `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs` — current source-derived milestone/exception logic.
- `.planning/VERIFICATION-POLICY.md`, `.planning/METHODOLOGY.md`, and `AGENTS.md` — deterministic evidence and preservation requirements.
- OWASP ASVS 5.0.0 official repository and versioned category documents — current category names and scope reference: `https://github.com/OWASP/ASVS`.

### Secondary (MEDIUM confidence)

- Phase 247 and Phase 250 reports and tuple packet — historical evidence snapshots and recorded blockers; not current live observations.
- Phase 249 preservation ledger and validator — recoverable ref/read-back example; not a current Phase 251 inventory.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — direct source inspection plus local runtime/CLI version probes.
- Architecture: MEDIUM — existing verifier paths are clear, but Phase 251 capture/output shape is a planning recommendation.
- Pitfalls: HIGH — gaps follow from current verifier predicates and recorded Phase 247/250 evidence.

**Research date:** 2026-10-11
**Valid until:** 2026-11-10 (stable local verifier contracts; live repository observations must be refreshed at execution time)
