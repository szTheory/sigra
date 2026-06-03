# Sigra Methodology

This file defines repo-level decision lenses that discussion, research, and planning agents should apply before escalating questions.

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
