# Phase 257: Fix candidate source publication and complete the bounded CI speed proof - Context

**Gathered:** 2026-11-05
**Status:** Ready for planning
**Source:** PRD Express Path (`.planning/phases/257-fix-candidate-source-publication-and-complete-the-bounded-ci/257-SCOPE.md`)

<domain>
## Phase Boundary

This phase owns a distinct, bounded attempt to publish the already verified candidate source to the exact existing PR368 branch, independently verify the preparation, run the unchanged 20-pair CI comparison, and report whether CISPEED-01/02 pass. Phase255.1 and Phase256 remain halted history; neither consumed claim is reusable. The phase includes the local transport and readiness fixes, deterministic tests, source-bound proposal/authorization, one candidate-preparation invocation, measurement only after preparation passes, and offline result replay/reporting.

</domain>

<decisions>
## Implementation Decisions

### Source publication
- Use the verified `.planning/execution/256/objects.git` object store.
- Publish with exactly one `git push` refspec to the exact existing PR368 branch, using an explicit expected-old-SHA lease.
- Require complete local reachable object closure, exact target tree and commit, ancestry from the expected old PR head, and the expected live PR/base before the push.
- Use the recorded old head as the lease value. If the branch or PR changed, the push is rejected, or the outcome is ambiguous, stop and reconcile read-only; never retry or use another transport.
- Do not update `main`, create another PR, push tags or other refs, use REST PATCH as a fallback, merge, or release.

### Readiness and receipts
- Validate the pre-update PR368 state before publication and the post-update commit/tree/ref/PR state after publication.
- Compare the first and final `main` observations with `contract.base_sha`.
- Reserve the invocation claim and mutation budget before starting Git push. Record the exact command with credentials/redirections sanitized, process group, exit/signal/timeout, start/end, push output digest, and read-only postcondition checks.
- An uncertain push outcome consumes the one-use claim and terminates hosted work; no retry, rerun, alternate publication method, or renewal is permitted.

### CI comparison
- Keep the forty original families / twenty pairs, seed `2551001`, balanced ten control-first and ten candidate-first schedule, 3,600-second maximum pair-start gap, six-owner cache rules, source/base/merge/workflow/producer/rules/image identity, useful-work equivalence, ordinary median and nearest-rank p95 method, and original acceptance thresholds.
- Run measurement only after the independent actual preparation verifier passes.
- Preserve every failure, cancellation, retry and actual job cost. Report insufficient data or a threshold miss honestly; do not remove outliers, replace families, or change the measured treatment.
- Close CISPEED-01/02 only after the existing numerical evaluator and independent Phase257 verification both pass.

### Authorization and stop limits
- The user authorized a new recovery scope and in-scope development/CI without per-run prompts, with finite timeouts. This scope is distinct from the consumed Phase256 attempt.
- Preparation has one invocation, at most 503 new API request attempts (the prior 11 reads remain charged to the original 514 ceiling), one branch ref update, one candidate workload, 280 runner timeout-job minutes, a 45-minute first-request window, and a 2,700-second process-group timeout.
- Preparation permits zero retries, reruns, renewals and alternate transports. Stop on rate-limit 403/429, drift, lease refusal, timeout, ambiguous mutation, missing proof or exhausted budget.
- Keep the inherited comparison caps and 48-hour window unchanged: at most 24,000 measurement request attempts, 82 semantic mutations and 41 measurement workflows; the combined scope remains capped at 24,514 requests, 83 mutations and 42 workflows. The inherited single diagnosed infrastructure retry is allowed only within its original measurement family and budget.
- Use no more than one CI watcher per run at 60-second cadence. Check rate-limit headroom before a long watch, stop polling at 250 or fewer core requests, and do not immediately retry 403/429.

### the agent's Discretion
- Choose the smallest implementation that keeps the push command and all Git configuration/redirect inputs pinned and prevents hooks or implicit refspecs from expanding the one-ref operation.
- Use a local bare-remote fixture to prove object transfer and exact ref movement without contacting GitHub.
- Reuse existing production validators, comparison runner, report format and dependency-free test patterns.
- Keep phase code changes limited to source-publication/readiness correctness and evidence needed for the unchanged comparison.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current scope and safety rules
- `.planning/phases/257-fix-candidate-source-publication-and-complete-the-bounded-ci/257-SCOPE.md` — fixed scope, limits, acceptance criteria and user authorization.
- `AGENTS.md` — durable routing, preservation, CI, no-retry and communication rules.

### Terminal evidence and source proof
- `.planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-03-SUMMARY.md` — terminal outcome of the consumed preparation.
- `.planning/execution/256/CANDIDATE-DIAGNOSTIC.json` — exact readiness blockers, spend and source-transport finding.
- `.planning/execution/256/source-recovery-01/SOURCE-CHECK.json` — passed source proof and existing PR368 identity.
- `.planning/execution/256/objects.git/OBJECT-CLOSURE.json` — bound local reachable object closure.
- `.planning/debug/phase256-prep-readiness-local-20261105/LOCAL-RESULT.json` — corrected readiness code evidence and transport comparison.

### Fixed comparison contract
- `.planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-04-PLAN.md` — exact collection protocol and caps.
- `.planning/phases/256-repair-ci-diagnostics-and-complete-bounded-speed-comparison/256-05-PLAN.md` — exact replay, thresholds, reporting and verification requirements.
- `.planning/execution/256/PREP-CONTRACT.json` — source identities, 20-pair schedule and combined ceilings.
- `.planning/REQUIREMENTS.md` — authoritative CISPEED-01/02 outcomes and wording.

### Primary transport references
- `https://git-scm.com/docs/git-push` — object transfer, exact refspec, and expected-old-SHA lease semantics.
- `https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository` — Git push to GitHub.
- `https://docs.github.com/en/rest/git/refs` and `https://docs.github.com/en/rest/git/commits` — separate REST endpoints for moving a ref and creating a commit object.

</canonical_refs>

<specifics>
## Specific Ideas

The candidate commit is `5effabe754c74fcd3086128ae9ce2e01ae07ab79`; its local parent is the recorded PR368 head `856c02bbd0dac83a29e388a0644d0fd51839b38f`. The failed GitHub commit lookup retained return code 1 without its exact HTTP cause, so remote availability is unknown. The new route must work whether the remote already has the commit or needs its objects.

### Recovery update after Plan06 halted (2026-11-05)

- Plan257-06 is terminally halted. Do not rerun Plan03 or Plan06. The generation01 invocation remains consumed, and its workload remains `null` until an independent proof resolves it.
- Read-only GitHub checks now establish that commit `5effabe754c74fcd3086128ae9ce2e01ae07ab79` does not resolve, the open PR368 currently reports head `856c02bbd0dac83a29e388a0644d0fd51839b38f`, and Actions reports zero runs for the expected candidate SHA. The source file at the current PR head hashes to `92f1b17856e8e2ea739b71383d4d7f8f4ef74805e4f0284043750e961788e935`, not the contract-pinned source hash `b9f9beafdf88023067b93e60ee247c14ed9bab1f99fdddf43a2dff8b170756f6`.
- The durable query details are in `.planning/debug/phase257-local/REMOTE-CANDIDATE-RECONCILIATION-20261105.json`. These remote facts do not by themselves prove zero historical workload; Plan06's blocked reconciliation remains unchanged.
- The user authorized choosing a distinct recovery scope and authorized in-scope development and bounded CI without per-run prompts, with finite timeouts. Continue by adding one narrowly scoped local plan to decide whether immutable invocation receipts plus the remote facts can prove the old workload and support a fresh exact candidate from the current source. Preserve all original ceilings, the combined deadline, and the consumed claim. Do not create another claim or perform hosted work unless local accounting, source identity, and all existing bounds pass independently.
- The immediate command is `$gsd-plan-phase 257 --skip-research`. Choose the additive-plan route so halted plans remain immutable. Do not run `$gsd-execute-phase 257` while `phase-plan-index 257.ready_plans` is empty.

</specifics>

<deferred>
## Deferred Ideas

No changes to CI performance targets, source treatment, workflow checks, cache policy, PR base, sample count, statistics, or release/merge state. These require a separate user decision.

</deferred>

---

*Phase: 257-fix-candidate-source-publication-and-complete-the-bounded-ci*
*Context gathered: 2026-11-05 via PRD Express Path*
