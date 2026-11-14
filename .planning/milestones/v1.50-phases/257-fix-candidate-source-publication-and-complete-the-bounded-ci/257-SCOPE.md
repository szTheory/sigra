# Phase 257 Scope: Fix candidate source publication and complete the bounded CI speed proof

## Goal

Complete the already approved 20-pair CI speed comparison without replaying the consumed Phase256 preparation. Fix the source-publication route so the exact candidate commit can be transferred from the verified local object store while updating only the existing PR368 branch, then run the unchanged bounded comparison and publish an honest report.

## Evidence and reason for this scope

Phase256 Plan03 consumed its single invocation claim and halted after 11 GET requests. It made zero mutations, started zero workloads, used zero runner minutes, and collected zero performance samples. Readiness had two local defects: it compared `main` with an absent source-identity field instead of the contract's `base_sha`, and it required the candidate branch/PR to have its post-update state before the planned update. Both defects are fixed and have six passing focused production-path tests plus an independent review.

The target commit `5effabe754c74fcd3086128ae9ce2e01ae07ab79` exists in `.planning/execution/256/objects.git`; its parent is the recorded current PR368 head `856c02bbd0dac83a29e388a0644d0fd51839b38f`. The saved GitHub commit lookup failed, but its exact HTTP cause was not captured, so remote availability remains unknown. A REST ref update changes a reference to a SHA; it does not send a local object pack. Git's push operation updates remote refs and sends objects not already on the remote. The recommended transport is one exact `git push` with an explicit expected-old-SHA lease and one branch refspec.

Primary references:

- Git push semantics, including object transfer and exact `--force-with-lease=<ref>:<expect>`: https://git-scm.com/docs/git-push
- GitHub's supported push workflow: https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository
- GitHub REST reference update and commit-object APIs, which are separate endpoints: https://docs.github.com/en/rest/git/refs and https://docs.github.com/en/rest/git/commits

## Scope

1. Add a bounded source-publication transport using only the contract-bound bare repository. Before transport, verify a complete local object closure, the exact candidate tree/commit, direct ancestry from the expected old PR head, the exact open PR368/head branch/base, and unchanged default-base SHA.
2. Publish through exactly one explicit `git push` refspec to the existing PR368 branch, with an exact expected-old-SHA lease. Disable ambient Git redirects and hooks or prove they cannot expand the refspec. Do not push tags, any other branch, or an alternative PR. Do not fall back to REST PATCH, force push, or a second transport. Reserve the one-use claim and charge the mutation before starting the push; an ambiguous outcome consumes the claim and stops for read-only reconciliation.
3. Verify the resulting remote commit/tree/ref/PR identity before treating the candidate workload as started. Keep the existing one-workload preparation cap, finite request budget, runner-job cap, first-request window, and process-group timeout. No preparation retry, rerun, or renewal is allowed in this scope.
4. If independent preparation verification passes, execute the existing fixed comparison: forty original families / twenty paired observations, seed `2551001`, balanced ten control-first and ten candidate-first sequence, same-family timing and cache rules, original thresholds, and original numerical method. Do not change treatment, source/base/merge identity, workflows, time gap, or statistical policy.
5. Preserve every actual attempt and cost. Missing or ambiguous proof stops new hosted work; local verification and reporting still complete. Close CISPEED-01/02 only if the existing independent verifier proves the fixed numerical and cost criteria. Never merge or release.

## Authorization and ceilings

The user authorized choosing a distinct recovery scope and authorized in-scope development and CI without per-run prompts, with finite timeouts. This phase is a new source-bound scope, not a retry or renewal of the consumed Phase256 claim.

- Candidate preparation: one invocation, at most 503 new API request attempts (the original Phase256 preparation ceiling was 514; its 11 recorded reads remain charged), exactly one existing-branch ref update, at most one candidate workload, at most 280 runner timeout-job minutes, 45 minutes from its first new request, and a 2,700-second outer process-group timeout.
- Preparation allows zero retries, reruns, renewals, or alternate publication methods. Stop on 403/429, drift, a non-fast-forward/lease failure, uncertain mutation, missing proof, timeout, or any ceiling.
- Keep the original combined comparison ceilings and measurement policy unchanged: 24,000 measurement request attempts, 82 measurement mutations, at most 41 measurement workflows, and the original 48-hour comparison window; with candidate preparation, the combined ceiling remains 24,514 requests, 83 mutations, and 42 workflows. Keep the existing single diagnosed infrastructure retry allowance only where the inherited measurement contract explicitly permits it.
- Use one CI watcher per run with 60-second polling. Inspect REST rate-limit headroom before a long watch; stop polling at 250 or fewer core requests and treat 403/429 as a hard stop until reset.

## Acceptance criteria

- Local tests prove the push sends the required object closure, updates exactly one leased ref, refuses changed old heads, and leaves all refs unchanged on local preflight failures. Captured platform responses exercise the production path.
- Phase-specific readiness accepts the exact pre-update PR368 state and stable base, then validates the post-push target state. A missing, changed, closed, duplicate, or wrong-base PR, incomplete local object closure, or old-head mismatch blocks before mutation.
- The one candidate-preparation result is independently verified, or the phase records a precise terminal stop and does not claim performance success.
- The fixed comparison is replayable from durable observations. The report distinguishes required CI results from preparation, warm-cache readiness, and measured performance. Requirements remain open unless the production evaluator and independent phase verifier pass.
- No merge, release, unrelated branch update, measurement-target change, retry of the Phase256 claim, or Phase255.1 resume occurs.

## Durable history

Phase255.1 and Phase256 remain halted historical scopes. Preserve their summaries, claims, ledgers, spend, and route snapshots byte-for-byte. Phase257 owns the new candidate publication path and any remaining CISPEED-01/02 proof.
