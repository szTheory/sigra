# Sigra Methodology

This file defines repo-level decision lenses that discussion, research, and planning agents should apply before escalating questions.

## Automation-First Verification

Make deterministic verification the default across planning, implementation, and closeout. For each changed behavior, identify the narrowest durable seam that proves it: unit or contract tests for local rules, integration tests for connected modules, generated-host or end-to-end tests for user workflows, and smoke checks for startup and deployment boundaries. Add coverage at more than one layer when the layers catch distinct failure modes.

Prefer checks that run automatically on every relevant change when they provide recurring value. Put merge-critical checks in CI; keep fast feedback local when CI would add cost or delay without improving coverage. Keep external-service checks deterministic through recorded fixtures, read-only live probes, or explicit environment-gated lanes, and require evidence that the intended job actually ran rather than trusting an aggregate green status.

Treat human verification as the last resort: use it only for outcomes that cannot be established reliably by automation, such as subjective judgment or an unavailable external authority. When a human checkpoint remains necessary, state the exact uncertainty and preserve machine-readable evidence for every other criterion. Do not ask the operator to repeat checks already established by reproducible automated evidence.

## GSD Milestone Tags

GSD milestone identifiers such as `v1.48` are planning labels, not Hex releases. Keep
`git.create_tag` disabled for this repository's milestone closeouts; only the release workflow
may create three-component SemVer tags. This preserves Phase 238's live rule that reserves the
`v*` tag namespace for real releases.

## Evidence Feasibility Before Planning

Before a plan depends on an immutable baseline, exact object identities, an external authority, or a historical absence claim, define and run a deterministic preflight. It must resolve the full baseline commit and every cited blob from the active checkout and named trusted source, and confirm the required evidence producer, complete time window, boundaries, and independent trust material are available. Record a machine-readable `ready` or `blocked` result as the first plan artifact; do not begin implementation or mutation while it is blocked.

Historical negative claims cannot be reconstructed by starting a recorder after the interval. If no independently trusted source covers the full requested window, keep the claim unknown and resolve the scope or acceptance contract before creating implementation or gap-closure plans. Do not spend repeated plans probing for evidence that could not have been recorded retroactively.

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
