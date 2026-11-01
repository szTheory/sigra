# Phase 248: Exact-Source Release Gate - Context

**Gathered:** 2026-10-07 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Automate the Release Please candidate-to-publish path while proving that the exact tagged source passed the required CI, package, documentation, and authenticated Hex dry-run checks. Phase 248 owns source identity, guarded Release Please PR auto-merge, release-run safety, and machine-readable success/failure/cancellation receipts. Phase 249 owns live proof that Hex, HexDocs, protected main, and the final release receipt agree. There is no application UI or runtime Elixir API work in this phase.

The user explicitly approved adding guarded auto-merge to the original gate-and-receipts scope. Auto-merge must preserve branch protection and fail closed. It must not make the current Release Please PR eligible until its release-candidate preflight passes; PR #224 is currently green but its changelog has a duplicate entry and omits Phase 246.
</domain>

<decisions>
## Implementation Decisions

### Guarded release PR automation
- **D-01:** Add automatic squash-merge for the single valid Release Please PR after the release candidate preflight and required `ci-gate` both pass on the exact current head SHA. This removes the last manual merge transition before the existing release workflow.
- **D-02:** Run the privileged merge decision from trusted default-branch workflow code. Require the expected Release Please branch, `autorelease: pending` label, release title/base, exactly one open candidate, successful source CI run, successful `ci-gate` on its SHA, and the candidate-content preflight. Re-read PR state and head immediately before merging; merge with `--match-head-commit`. Never use `--admin`, bypass rules, or merge a stale head. GitHub branch protection remains authoritative.
- **D-03:** Use the already-configured `RELEASE_PLEASE_TOKEN` for the automated merge/event chain, with only the permissions needed to update/merge the release PR and trigger downstream workflows. Do not silently fall back to `GITHUB_TOKEN` for the merge: GitHub suppresses normal push-triggered workflows for events caused by that token. If token scope or event-chain behavior is insufficient, fail closed with an actionable run link and leave the PR open.

### Exact source and package validation
- **D-04:** Treat Release Please `tag_name` and `sha` as one provenance pair. Before package work, fetch/resolve the tag and require the resolved commit, checked-out `HEAD`, and Release Please `sha` to be identical. Version/tag/manifest string agreement remains a useful secondary check, not a substitute for commit identity.
- **D-05:** Keep verification stages in the existing trusted release lane: required CI gate, tests, warning-free docs, package inspection, authenticated Hex dry-run, then publish. Each stage must consume the same immutable tag/SHA; any mismatch or failed stage blocks publication. Do not create a speculative `v1.6.0` tag to test the lane.
- **D-06:** Use a dedicated read-only Hex credential for the authenticated dry-run (`HEX_DRY_RUN_API_KEY`) and reserve the existing write-capable `HEX_API_KEY` for the final publish step. Configure the read-only key once as a GitHub Actions secret; no per-release local authentication or operator command is part of the happy path. `mix hex.publish --dry-run --yes` still authenticates, but it does not submit the release to Hex. Prove the no-publish recovery path through the existing `hex-publish.yml` `dry_run: true` route; the real 1.6.0 lane must dry-run its exact tag before it publishes.

### Run safety and receipts
- **D-07:** A later main push must not cancel an active release evaluation. Use non-cancelling release concurrency and make any replacement/retry idempotent by release identity. A newer event must not erase the only pending release result.
- **D-08:** Retain linked, machine-readable stage receipts keyed by release run ID and carrying version, tag, source SHA, workflow/run identity and URLs, gate run, verdict, attempts, timestamps, and publish result. Preserve receipts for success and failure; add a trusted default-branch completion observer so manual or infrastructure cancellation still yields a terminal cancellation record. The observer must validate the source workflow/run and must not execute PR-branch code or trust unvalidated artifacts.
- **D-09:** Receipts are the primary durable proof. Human-facing failure issues/labels are supplementary and must never suppress or replace the machine-readable receipt. Keep the existing failure notification useful, but make the release result discoverable even if a GitHub label is missing.

### Candidate content and folded todos
- **D-10:** The auto-merge preflight must reject release notes left under `## Unreleased`, duplicate release-note entries, or a versioned changelog that omits source-backed adopter changes. Fix the current PR #224 candidate before the auto-merge lane may select it.
- **D-11:** Fold `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` into the candidate-content gate. Automatic merging removes the human review moment that previously caught stranded notes, so the durable guard belongs in this phase.
- **D-12:** Fold `.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` into receipt/failure reporting. A missing label must not make release failure appear successful or erase its durable diagnostics.
- **D-13:** The `gate-ci-green` timeout todo is reviewed but not folded as new work: the current workflow already uses a 120-attempt, 30-second poll budget and a 75-minute job timeout. Keep that ceiling covered by the release contract.

### the agent's Discretion
- Choose workflow/script boundaries, exact JSON property names, artifact retention, and deterministic fixture shape while preserving the decisions above.
- Prefer same-workflow `needs` for release state transitions. Use `workflow_run` only where its completion semantics are needed for cancellation receipts; correlate explicitly to the source run ID/SHA and run trusted default-branch code.
- Use the narrowest job permissions, keep third-party actions pinned, and avoid a new release framework or broad CI redesign.
- Keep the operator experience centered on one automatic path with a linked run and receipt; do not expose token, tag, or package internals as user-facing product concepts.

### Folded Todos
- `2026-07-28-release-please-orphans-unreleased-block.md` — make changelog placement/content a machine gate before auto-merge.
- `2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` — keep failure evidence durable even if issue-label reporting fails.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and project contract
- `.planning/ROADMAP.md` — Phase 248/249 scope and success criteria.
- `.planning/REQUIREMENTS.md` — AUTO-01, AUTO-02, REL-01, and REL-02.
- `.planning/PROJECT.md` — project direction and release target.
- `.planning/STATE.md` — current GSD position; refresh readiness before execution.
- `.planning/METHODOLOGY.md` — automation-first evidence, security/proof escalation, and decisive defaults.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-CONTEXT.md` — release candidate, changelog, and adopter constraints.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-RESEARCH.md` — candidate/package prior art.
- `.planning/phases/247-release-candidate-and-repository-readiness/247-04-PLAN.md` — source and package evidence boundary.

### Release implementation and evidence
- `.github/workflows/release-please.yml` — Release Please outputs, exact-SHA gate, package checks, dry-run/publish, and failure notification.
- `.github/workflows/hex-publish.yml` — tag/ref validation and dry-run-only recovery route.
- `.github/workflows/ci.yml` — required `ci-gate` definition and CI run identity.
- `scripts/ci/wait-for-ci-gate.sh` and `scripts/ci/wait-for-ci-gate.test.sh` — release-SHA gate polling and existing test seam.
- `scripts/ci/release-post-publish-verify.sh` — current post-publish evidence schema.
- `scripts/ci/notify-failure-issue.sh` — current release failure reporting behavior.
- `release-please-config.json`, `.release-please-manifest.json`, `mix.exs`, and `CHANGELOG.md` — release version and candidate content truth.
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` — folded.
- `.planning/todos/pending/2026-07-28-release-lane-rot-label-missing-breaks-hard-02-signal.md` — folded.
- `.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` — reviewed; current workflow already addresses the timeout ceiling.

### Repo prompts and prior art
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — Release Please, scoped Hex credentials, and hands-off OSS releases.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — Hex package inspection and release DX.
- `/Users/jon/projects/lattice_stripe/.github/workflows/release-pr-automerge.yml` — exact-head guarded auto-merge precedent; do not copy its repository-specific implementation blindly.
- [Release Please action documentation](https://github.com/googleapis/release-please-action) — release lifecycle, outputs, and token behavior.
- [GitHub token-trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) and [workflow_run event/security semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run).
- [Hex `mix hex.publish` task](https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html) and [Hex v2.5.1 publish-task source](https://raw.githubusercontent.com/hexpm/hex/v2.5.1/lib/mix/tasks/hex.publish.ex) — authenticated dry-run behavior and publish boundary.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `release-please.yml` already exposes `release_created`, `tag_name`, `version`, and `sha`; `gate-ci-green` waits for `ci-gate` on the output SHA.
- The publish lane already tests, builds warning-free docs, inspects the Hex package, dry-runs, publishes, and verifies the published version. It currently checks out by tag but does not directly assert checked-out `HEAD` equals Release Please's `sha`.
- `hex-publish.yml` already validates tag/ref provenance and has a `dry_run` input that skips the write steps.
- `wait-for-ci-gate.sh` is a hermetic-testable polling seam. Its success JSON and failure text need to be reconciled with the complete receipt contract.
- `release-post-publish-verify.sh` is a reusable starting point for structured publication evidence; `notify-failure-issue.sh` is the current human-facing alert seam.
- The repository secret names `HEX_API_KEY` and `RELEASE_PLEASE_TOKEN` are already configured. Secret contents were not read.

### Established Patterns and Risks
- The current release workflow has workflow-wide write permissions and `cancel-in-progress: true`; a newer push can cancel the in-flight release. Scope permissions by job and prevent ordinary main updates from discarding release evaluation.
- `HEX_API_KEY` is currently exposed to both dry-run and publish steps. The read-only dry-run credential keeps publish authority out of the preflight step.
- GitHub suppresses push-triggered workflows caused by `GITHUB_TOKEN`; the existing `RELEASE_PLEASE_TOKEN` is the preferred event-chain seam. A `workflow_run` consumer must use the original run's SHA/ID, not its own default-branch `GITHUB_SHA`.
- The current release failure issue depends on `release-lane-rot`; a notification-label failure must not undermine artifact receipts.
- `lattice_stripe` validates trusted Release Please candidates, exact CI head, and merge-time head identity before squash merging. Its `--match-head-commit` pattern and no-bypass posture fit; repository-specific scripts and follow-on workflow names do not.
- Live PR #224 is green at its observed head, but the changelog review found a duplicate commit entry and missing Phase 246 notes. This is an active candidate blocker for auto-merge.

### Integration Points
- Auto-merge consumes the release PR's completed required CI run, then starts the existing main-push → Release Please → exact-source gate → package/dry-run/publish chain.
- Stage receipts must join by release run ID, tag, and source SHA across the gate, package evaluation, publish, and cancellation observer.
- Phase 249 consumes Phase 248's exact source and receipts to prove the public Hex package, versioned HexDocs, source link, and protected-main evidence.
</code_context>

<specifics>
## Specific Ideas

- Maintainer JTBD: merge ordinary project work; let Release Please prepare a reviewable candidate; let automation merge only the exact reviewed, green candidate; publish from the verified tag; retrieve one linked success/failure/cancellation record without local Hex authentication.
- The pleasant path is a single automatic chain. Recovery remains explicit and source-bound through the existing dry-run/publish recovery workflow.
- **Methodology applied:** automation-first verification (contract + live read-only probe + receipts), evidence feasibility before publication, decisive repo-consistent defaults, least privilege, branch-protection preservation, and truthful failure reporting. No front-end design contract applies.
</specifics>

<deferred>
## Deferred Ideas

- Broad CI restructuring, adopting a generic multi-repository release platform, and redesigning release automation beyond this repository's existing Release Please/Hex path.
- Hex resolver ranking / retired-version cleanup and unrelated pending CI or generated-auth work.
- Phase 249's public package, HexDocs, protected-main, and clean-worktree proof.

### Reviewed Todos (not folded)
- `.planning/todos/pending/2026-07-28-gate-ci-green-timeout-too-tight-for-push-to-main.md` — already mitigated by the current 120 × 30-second poll and 75-minute job timeout; retain regression coverage without reopening the old fix.
- `.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md` — Hex version-ranking cleanup is outside the selected 1.6.0 release gate.
- `.planning/todos/pending/2026-07-30-recapture-job-transient-hexpm-mirror-failure.md` — unrelated transient recapture lane.
- Other `todo.match-phase 248` matches were lexical false positives from generic CI/source/gate terms and remain outside scope.
</deferred>
