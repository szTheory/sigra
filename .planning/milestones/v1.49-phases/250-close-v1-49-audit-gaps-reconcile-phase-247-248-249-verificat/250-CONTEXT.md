# Phase 250: Close v1.49 audit gaps - Context

**Gathered:** 2026-10-09 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Reconcile the missing and stale verification records for existing v1.49 Phases 247, 248, and 249; prove hosted failed and cancelled receipt delivery with an automated, non-publishing canary; then refresh requirements traceability and the v1.49 milestone audit to a consistent 9/9 result. This phase closes evidence and release-automation gaps. It does not change Sigra authentication behavior, reassign the original requirement owners, publish or merge another release, or reopen the accepted historical HANDOFF loss.
</domain>

<decisions>
## Implementation Decisions

### Verifier freshness and exact evidence identity
- **D-01:** Treat each canonical phase verification as a snapshot bound to its source and evidence identity, with a captured-at time and references to the exact commits, refs, workflow runs, and artifacts it evaluated. Refresh a stale report from current authoritative evidence; preserve its prior result as history where useful, and never silently substitute a later passing artifact into an older report.
- **D-02:** Phase 247 must be independently verified against one reconciled, approved candidate tuple and its matching readiness ledger, exact-head CI, dry-run, and disposition evidence. The current artifacts disagree: `247-RELEASE-READINESS.json` and `247-VALIDATION.md` bind to candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`, while the later `247-10-REBIND-PROPOSAL.json` and Roadmap refer to `0e773d3614a242e4fbcdd34c418ecb8a307703d6`. Reconcile that tuple from immutable evidence before marking READY-01/02 satisfied; if it cannot be proved, leave the requirements unsatisfied. Plan 05's checkpointed recovery path is superseded only where later exact-source evidence proves the same acceptance criteria.
- **D-03:** Refresh Phase 248 verification from the current protected-environment names/policies and hosted exact-source success evidence. Never read or record credential values. AUTO-01 may pass only when the canonical verifier accepts the intended environment scope and exact-source gate; AUTO-02 stays open until both hosted failure and cancellation artifacts have been retained, retrieved, and validated. Local fixtures and the success artifact alone do not prove hosted terminal delivery.
- **D-04:** Refresh Phase 249 verification from the passing `refs/heads/evidence/phase-249-final-acceptance` record, current exact-main CI, public 1.6.0 proof, and clean inventory. Keep package-source SHA `9e80cb78d6374b1ed4074d5fef6b613fee879dca` distinct from final protected-main SHA `08300af1740fea8b77d5928a182688acbf103edc`. Keep the historical HANDOFF loss classified as explicitly accepted with recorded loss; never call the bytes recovered or preserved.

### Safe hosted failure/cancellation canary
- **D-05:** Use a dedicated, explicitly allowlisted canary source workflow on `main` to exercise hosted failure and cancellation receipts without invoking production release/publish jobs. The canary receives no Hex credential, no publishing environment, and no authority to create a release, tag, or merge a PR. Its artifacts must be visibly namespaced as canary evidence and cannot overwrite or masquerade as a production release receipt.
- **D-06:** Exercise the production receipt contract through the same sanitized receipt builder/validator and hosted artifact delivery/retrieval path. The controlled failure run must retain a source-bound failure receipt; an automated controller must cancel only the exact canary run ID for the cancellation case, after which trusted observer code retains a source-bound cancellation receipt. Retrieve both artifacts automatically and validate source workflow identity, run ID/attempt, SHA, conclusion/verdict, observer identity where applicable, required timestamps, and absence of credential-like fields.
- **D-07:** Keep the observer on trusted default-branch code with least-privilege permissions. `workflow_run` workflows can access tokens and secrets even when the source workflow cannot, so the source must not check out, execute, or trust untrusted PR code or artifacts. If the observer accepts a canary source, require its exact workflow identity/path and allowed event/ref; do not weaken the production Release Please identity checks or cancel a real release to manufacture evidence.
- **D-08:** Run the hosted canary and artifact retrieval without human UAT. Keep the hosted trigger/action bounded and reusable on demand; do not add a periodic canary unless planning shows recurring signal is worth its runner cost and operational noise.

### Traceability and closeout
- **D-09:** Keep READY-01/02 assigned to Phase 247, AUTO-01/02 to Phase 248, and REL-01/02 to Phase 249. Phase 250 contributes verification evidence only; it must not claim these requirements as newly implemented or conceal an owner-phase gap with duplicate claims.
- **D-10:** Update phase verification, summary requirement frontmatter, `REQUIREMENTS.md`, and the milestone audit only after the source verifications and hosted canary artifacts agree. Run the strict milestone audit last; 9/9 requires all three source-verification reports to pass and no orphaned or contradictory traceability rows.

### the agent's Discretion
- Choose the smallest canary/controller workflow structure that isolates the production path, uses only the GitHub permissions needed to dispatch/cancel the canary, and never receives Hex publish credentials.
- Choose canary artifact names, test-only receipt markers, and the deterministic download/validator command while preserving the established receipt schema and production artifact identity.
- Choose the exact verification refresh order and the smallest regression check that prevents these reports from drifting again. Keep any reusable audit-tool redesign or unrelated maintenance outside this phase.
- Use one CI watcher per run, 60-second polling, and structured artifact/run summaries; retrieve failed logs only for failed runs and honor the GitHub API rate-limit stop rule.

### Folded Todos
None. The phase-matcher produced broad heuristic matches; the directly related Release Please note-placement and release-label items are already handled in Phases 247/248, and the other canary/verifier items describe separate or historical work. Do not expand Phase 250 with unrelated backlog items.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and project contract
- `.planning/ROADMAP.md` — v1.49 Phase 250 goal, criteria, and original Phase 247–249 ownership.
- `.planning/REQUIREMENTS.md` — READY-01/02, AUTO-01/02, REL-01/02 and their original assignments.
- `.planning/PROJECT.md` — Sigra's release goal, verification defaults, and project boundaries.
- `.planning/METHODOLOGY.md` — automation-first proof, immutable source identity, safe terminal-outcome canary, and stale-verifier policy.
- `.planning/VERIFICATION-POLICY.md` — deterministic evidence and exact-SHA requirements.
- `.planning/STATE.md` — current milestone route; refresh before execution.
- `.planning/v1.49-MILESTONE-AUDIT.md` — complete gap inventory, strict 3/9 baseline, and evidence-ref references.

### Phase 247 candidate/readiness evidence
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json`.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-VALIDATION.md`.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-10-REBIND-PROPOSAL.json` — later candidate identity that must be reconciled with the readiness snapshot.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-HEX-DRY-RUN-RECEIPT.json` and plan summaries — candidate-bound dry-run and disposition evidence.

### Phase 248 release gate and receipt paths
- `.planning/phases/248-exact-source-release-gate/248-USER-SETUP.md`, `248-VALIDATION.md`, `248-VERIFICATION.md`, and `COVERAGE.md`.
- `.github/workflows/release-please.yml` — terminal failure receipt builder and upload path.
- `.github/workflows/release-run-observer.yml` — trusted cancellation observer and hosted cancellation artifact path.
- `.github/workflows/hex-publish.yml` — manual recovery receipt path; must remain separate from the no-publish canary.
- `scripts/ci/release-observer.sh`, `scripts/ci/release-receipt.sh`, `scripts/ci/release-observer.test.sh`, and `scripts/ci/release-receipt.test.sh`.
- `.planning/phases/248-exact-source-release-gate/248-CONTEXT.md` — locked source, permission, cancellation, and receipt decisions.

### Phase 249 public release and terminal acceptance
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-VERIFICATION.md` and `249-12-SUMMARY.md`.
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PRESERVATION.json`, `249-RELEASE-RECEIPT.json`, `249-FINAL-MAIN-PROOF.json`, and `249-VALIDATION.md`.
- `refs/heads/evidence/phase-249-final-acceptance:.planning/phases/249-publish-and-prove-sigra-1-6-0/249-FINAL-ACCEPTANCE.json` — authoritative passing acceptance; the checked-in JSON is stale.
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.mjs` and `validate-closeout.test.mjs` — exact-identity and terminal-evidence patterns.

### Project research and GitHub's hosted-workflow contract
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — Release Please/Hex automation, least privilege, and receipt lessons.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Elixir OSS package/release DX principles.
- [GitHub Actions events, including `workflow_run`](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) — default-branch workflow requirement and completion regardless of source conclusion.
- [GitHub Actions secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use) — privileged `workflow_run` boundaries and untrusted-code precautions.
- [GitHub workflow artifact storage and retrieval](https://docs.github.com/en/actions/tutorials/store-and-share-data) — cross-run artifact access and `retention-days` limits.

No product UI, application API, or brandbook contract applies to this release-evidence phase.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/ci/release-receipt.sh` validates and persists sanitized success/failure/cancellation receipt inputs; its credential-key rejection and source-identity checks should remain the shared contract.
- `.github/workflows/release-please.yml` has an `always()` terminal release-result job that uploads the source-bound release artifact; use its builder/validator contract for the controlled failure case without running release or publish jobs.
- `.github/workflows/release-run-observer.yml` runs trusted main code after Release Please completes and uploads a 90-day cancellation artifact; `scripts/ci/release-observer.sh` independently queries the authoritative source run and workflow before writing it.
- Existing shell fixture suites cover receipt schemas and observer rejection cases; the hosted canary complements them by proving event delivery, retention, retrieval, and run binding.
- Phase 247's readiness validator and Phase 249's terminal validator provide examples of fail-closed source/evidence ledgers and explicit accepted-loss records.

### Established Patterns
- Bind release claims to full commit SHAs, workflow IDs, run IDs/attempts, immutable refs, timestamps, and retrieved artifacts; version/tag strings alone are insufficient.
- Keep GitHub workflow permissions minimal and job-scoped, pin third-party actions to full SHAs, isolate publishing credentials to the production publish step, and make each run's receipt discoverable without issue-label success.
- Treat local fixtures as proof of local contracts only; hosted event delivery and artifact retrieval require hosted evidence.
- A trusted observer must treat the source workflow as data: validate its identity and outcome through GitHub's API, and never execute its code or unpack/run its artifact.
- Phase 248's environment setup evidence lists secret names and policies only; never copy secret values into repository evidence.

### Integration Points
- Phase 247's reconciled candidate/readiness proof feeds READY-01/02 verification.
- Phase 248's protected environment, exact-source gate, failure receipt, cancellation observer, canary artifacts, and retrieval validator feed AUTO-01/02 verification.
- Phase 249's evidence ref, release receipt, final-main proof, preservation disposition, and current inventory feed REL-01/02 verification.
- The three canonical verifier reports and matching summary frontmatter feed `.planning/REQUIREMENTS.md` and the final v1.49 milestone audit.
</code_context>

<specifics>
## Specific Ideas

- Make the canary a single automated proof workflow: produce one controlled failure, dispatch and cancel only its own cancellation probe, let the trusted observer write the terminal receipt, then retrieve and validate both artifacts by source run ID. The workflow must stop before any Hex or release operation.
- Keep test and production receipts unmistakably separate in name and metadata. A passing canary proves the receipt/event machinery, not that a real release failed or that a release should be retried.
- Resolve the Phase 247 candidate-SHA disagreement from the immutable approved source tuple before writing a passing verifier; do not infer it from the newest-looking markdown line.
- No human visual review or UAT is needed. CI/run metadata and validated artifacts are the acceptance evidence.
</specifics>

<deferred>
## Deferred Ideas

- A generalized cross-milestone verification freshness service or redesign of GSD audit tooling is outside the fixed Phase 250 boundary; add only a narrow regression check needed to protect this closeout.
- Weekly/scheduled release-receipt canaries are deferred unless the plan demonstrates durable recurring value beyond on-demand automated proof.
- Any new auth, Phoenix UI, documentation, or release features remain outside this audit-closure phase.

### Reviewed Todos (not folded)
- Heuristic matches about Release Please orphaned notes and missing `release-lane-rot` labels are already handled by Phase 247/248 decisions and implementation.
- The canary recapture-lane todo concerns unrelated Playwright artifact capture.
- The Phase 235 gap-closure verifier EXIT-trap todo is historical and has not been observed in this Phase 250 path.
</deferred>
