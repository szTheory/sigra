# Sigra Methodology

This file defines repo-level decision lenses that discussion, research, and planning agents should apply before escalating questions.

## Automation-First Verification

Make deterministic verification the default across planning, implementation, and closeout. For each changed behavior, identify the narrowest durable seam that proves it: unit or contract tests for local rules, integration tests for connected modules, generated-host or end-to-end tests for user workflows, and smoke checks for startup and deployment boundaries. Add coverage at more than one layer when the layers catch distinct failure modes.

Prefer checks that run automatically on every relevant change when they provide recurring value. Put merge-critical checks in CI; keep fast feedback local when CI would add cost or delay without improving coverage. Keep external-service checks deterministic through recorded fixtures, read-only live probes, or explicit environment-gated lanes, and require evidence that the intended job actually ran rather than trusting an aggregate green status.

Treat human verification as the last resort: use it only for outcomes that cannot be established reliably by automation, such as subjective judgment or an unavailable external authority. When a human checkpoint remains necessary, state the exact uncertainty and preserve machine-readable evidence for every other criterion. Do not ask the operator to repeat checks already established by reproducible automated evidence.

## Validation Source Identity

Bind every build, generated-artifact comparison, and CI claim to the exact source identity it tested. Before interpreting a result, record the checkout's commit SHA, branch or trusted ref, product version, dirty/clean state, and language/runtime toolchain. Refresh the trusted target ref before using it as a baseline; a stale local tracking ref is not authoritative.

When the active GSD worktree predates the candidate or release under test, treat version and generated-file mismatches there as a checkout-scope diagnostic, not a product failure. Preserve the first result, then reproduce the relevant check in an isolated clean checkout of the exact candidate or trusted target SHA using the supported CI toolchain. Keep both identities and outcomes in the validation record. Do not label the product gate blocked, request human UAT, or change product code until the exact-source reproduction establishes a real failure. Run change-specific checks on the exact PR head and use its hosted exact-head CI as the merge gate.

## External Mutations And Evidence Writes

Before a merge, publish, deploy, tag, or other external state change, preflight the local durable evidence path that must record its result. Confirm object creation and expected-old ref updates work in the repository that will hold the evidence; a writable checkout does not imply a writable Git object database. If evidence persistence is unavailable, stop before the external mutation. If a tool reports failure after the external action may have completed, re-read the external state first, preserve any captured dirty evidence by exact-byte read-back, and resume from observed state rather than replaying the mutation.

For high-fan-out CI service containers, avoid making many concurrent anonymous pulls from a rate-limited registry. Prefer an official public mirror of the same upstream image when available, and pin the image source in a workflow contract test. Diagnose correlated infrastructure failures before changing application code; retry a transient failure once, then retain the causal log and make the stable fix part of CI.

## Terminal Evidence Closeout

Design the terminal evidence writer and its failure tests before beginning a multi-step release closeout. Commit implementation, summaries, and source evidence before refreshing the final inventory. Capture the final acceptance artifact to an ignored task-local path, commit its exact bytes to the scoped evidence ref, and verify that read-back before sealing; do not generate a tracked proof file after the clean-tree snapshot.

The terminal seal should use compare-and-swap ref updates without checking out the evidence ref. Record the exact raw `git status --porcelain=v1 -z --untracked-files=all` bytes for every registered worktree after a checkpoint ref write, then re-read all worktrees after the terminal record ref write. Require an unchanged worktree set and byte-identical empty statuses, and bind the record to the canonical acceptance blob/commit and summary/evidence commits. A dirty status, missing record, failed read, or changed set blocks completion and requires a fresh closeout pass; never hide generated outputs behind an allowlist.

Run the terminal proof as the final repository mutation. If a later state, handoff, summary, or evidence edit is needed, commit it first, refresh the inventory and acceptance evidence, and replay the seal rather than reporting from an older terminal record.

Before calling a phase complete, query `init.execute-phase` and require every plan to have a committed summary. Record blocked attempts when they happen, including the exact blocker and recoverable evidence; when later work resolves the goal, record that downstream disposition without rewriting the original attempt as green. Run the phase's code-review, security, Nyquist, and prior-phase regression gates before final acceptance. Commit their reports and any resulting repairs, then refresh and replay release acceptance and the terminal seal so those gates are inside the final evidence boundary.

For proofs that follow HTTP redirects, parse the effective URL and allow only HTTPS destinations on the exact trusted domain or a dot-delimited subdomain, with the expected endpoint path. Reject user-info, non-default ports, queries, and fragments by checking both parsed components and raw delimiter presence; add fixtures for lookalike hosts and empty delimiters.

## GSD Milestone Tags

GSD milestone identifiers such as `v1.48` are planning labels, not Hex releases. Keep
`git.create_tag` disabled for this repository's milestone closeouts; only the release workflow
may create three-component SemVer tags. This preserves Phase 238's live rule that reserves the
`v*` tag namespace for real releases.

## Evidence Feasibility Before Planning

Before a plan depends on an immutable baseline, exact object identities, an external authority, or a historical absence claim, define and run a deterministic preflight. It must resolve the full baseline commit and every cited blob from the active checkout and named trusted source, and confirm the required evidence producer, complete time window, boundaries, and independent trust material are available. Record a machine-readable `ready` or `blocked` result as the first plan artifact; do not begin implementation or mutation while it is blocked.

Historical negative claims cannot be reconstructed by starting a recorder after the interval. If no independently trusted source covers the full requested window, keep the claim unknown and resolve the scope or acceptance contract before creating implementation or gap-closure plans. Do not spend repeated plans probing for evidence that could not have been recorded retroactively.

## Planning Artifact Write-Ahead Preservation

Treat durable planning state as user work. Before a GSD operation rewrites or cleans an already-dirty `.planning/` path—including `HANDOFF.json`, `STATE.md`, `state.json`, closeout ledgers, plans, and evidence—commit it or create a path-scoped immutable preservation ref and verify the exact path, status, and bytes by read-back. A recorded hash is an identity, not a backup. If the prior bytes cannot be read back from the preservation target, do not perform the overwrite; capture the blocker in a separate clean artifact. After preservation, recheck the source path and hash before writing its replacement, and carry the preservation reference forward through later inventory refreshes.

At closeout, list execution commit IDs only when `git cat-file` resolves them and their integration branch or containing ref is recorded. Mark a requirement complete only when its complete acceptance evidence passes; a valid blocked audit can complete the bounded audit attempt while leaving the parent requirement open.

## Decisive Defaulting

Use researched, repo-consistent defaults unless a choice materially changes security posture, public contract, generated-host contract, or proof/truth claims.

Diagnosis cues:
- Multiple implementation options are all technically viable.
- One option is clearly more idiomatic for Phoenix/Plug/Ecto or more consistent with Sigra's prior decisions.
- The choice mostly affects implementation detail, not product boundary.

Recommendation rule:
- Choose the strongest default and explain why.
- Do not reopen broad option menus for implementation-level forks.

## Escalation Threshold

Escalate only when the choice would reasonably matter to a staff-level architect reviewing platform risk or product contract.

Escalate when a decision:
- changes the security model or takeover posture
- changes the public or semver-facing API/behavior contract
- changes generated-host output or the host/library responsibility split
- changes what Sigra can honestly claim in docs, verification, or operator truth

Do not escalate when a decision is mostly about:
- code structure inside an already chosen boundary
- default UX copy/layout within an already chosen flow
- test shape, helper naming, or internal modularization

## Research Depth Calibration

Before asking the user anything:
1. Read ROADMAP, REQUIREMENTS, PROJECT, STATE, prior phase CONTEXT/RESEARCH where relevant.
2. Scout the codebase for existing seams, invariants, and reusable patterns.
3. Read prompt and research documents that encode repo philosophy and prior-art lessons.
4. When the decision touches auth/product contract, also check relevant official docs or strong primary-source prior art outside the repo.
5. Narrow to one recommended path plus at most one serious runner-up.

Question only when:
- the winner is not clear after repo-grounded research, or
- the decision is above the escalation threshold.

## Discuss-Phase Default

Default discuss-phase behavior should be recommendation-first, not option-menu-first.

Expected workflow:
1. Do the repo and prompt research above before presenting choices.
2. Form a cohesive recommendation set, not isolated per-question answers.
3. Prefer the path that keeps Sigra's product contract, generated-host contract, and audit/operator truth coherent together.
4. Present the recommended winner with concise rationale and concrete tradeoffs already analyzed.
5. Ask the user only if a decision is still genuinely ambiguous after narrowing, and only when that ambiguity would matter to a staff-level architect reviewing platform risk or contract shape.

Do not ask the user broad implementation menus when a clear winner exists.
Do not preserve large undecided matrices in CONTEXT.md when the repo, prompts, and primary-source prior art already point to one path.

## Prompt And Prior-Art Weighting

When repo prompts, prior phases, and primary-source prior art align, treat that as enough authority to decide without reopening the question.

Prefer recommendations that are:
- idiomatic for Elixir, Plug, Ecto, and Phoenix
- least surprising for adopters coming from mature auth products
- explicit about security boundaries and recovery posture
- easy for generated hosts to adopt without bespoke controller logic
- honest about what Sigra does not claim yet

## User Experience Bias

Prefer the path that is:
- least surprising for Phoenix adopters
- truthful on failure
- low-friction on the happy path
- explicit at security boundaries
- supportive of generated-host DX without hiding library-owned correctness

## Phase Context Expectation

Phase context files should capture:
- the chosen default
- why it won
- the main hard-fail boundaries
- what remains at the agent's discretion

They should not preserve large undecided menus unless the decision truly exceeded the escalation threshold.
