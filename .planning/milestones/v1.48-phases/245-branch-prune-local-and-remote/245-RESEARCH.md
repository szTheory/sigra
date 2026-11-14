# Phase 245: Branch Prune — Local and Remote - Research

**Researched:** 2026-10-01  
**Domain:** Git ref lifecycle, recoverability, GitHub pull-request safety  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Prune Readiness
- **D-01:** Phase 245 may be planned while Phase 244 is unfinished, but no branch deletion may occur until Phase 244 is complete and its ref-dependent work is resolved. The Phase 242 contract blocker and draft PR #283 remain Phase 244 work; do not fix or absorb them here.

#### Object Recoverability
- **D-02:** Commit a pre-prune `git for-each-ref` snapshot, then prove after pruning that every recorded SHA remains resolvable with `git cat-file -e`, checking against that committed snapshot. Record explicitly in the phase summary that no `git gc`, `git reflog expire`, or `--prune=now` ran anywhere in the milestone. Leave stashes untouched, consistent with Phase 237 D-09.

#### Open PR Exclusions
- **D-03:** Derive the exclusion set from the live `gh pr list --json headRefName,baseRefName` result, protecting both head and base refs. Recheck open PR state and base-ref integrity after pruning. Keep `gsd/238-generated-auth-runtime-proof-evidence` while PR #219 still uses it as its head; prior inventory is not a substitute for the live execution-time check.

#### Safety Refs on Origin
- **D-04:** Preserve these named refs on `origin`: `ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-*`, and `archive/local-main-pre-235-recovery`. Preserve each existing ref's type and object identity. Publish a required local-only ref when its name is absent remotely; if the remote already has that name at a different object, stop and reconcile rather than force-update it. Preserve `archive/local-main-pre-235-recovery` as its existing tag.

### the agent's Discretion
- Choose the snapshot and machine-readable evidence formats, plus the exact prune command sequence, provided the roadmap criteria remain directly reproducible and every remote mutation is preceded by a verified allowlist and current PR exclusion set.

### Deferred Ideas (OUT OF SCOPE)
- Resolve `.planning/todos/pending/2026-09-26-phase-244-mix-ci-blocked-by-phase-242-hex-contract.md` within Phase 244's separately scoped recovery work before branch deletion can proceed.
- Any newly discovered cleanup work is recorded as a new todo rather than fixed during branch pruning.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REPO-04 | Stale local and remote branches are pruned, with every pre-prune SHA still `git cat-file -e`-resolvable, the documented safety refs kept (`ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-*`), and no open PR's head or base branch deleted. | Full committed ref/object snapshot; explicit local and remote deletion allowlists; live open-PR head/base exclusion and post-prune state checks; safety-ref identity comparison; object-existence checks against the committed snapshot. [VERIFIED: `.planning/REQUIREMENTS.md:91-96`] |
</phase_requirements>

## Summary

This phase is a one-time destructive Git maintenance operation. Plan it as a gated sequence: first establish that Phase 244 and all ref-dependent work are complete; then capture and commit a complete local ref/object inventory and a separate live `origin` ref inventory; then freeze candidate names and the live open-PR exclusion set; finally prune only reviewed exact names in distinct local and remote passes and independently verify the resulting state. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:7-14,20-36`; `.planning/ROADMAP.md:395-405`]

The existing precedents are directly reusable for evidence discipline, not as ready-made branch inventories. Phase 237 committed a sanitized worktree/stash snapshot before mutation; Phase 238 used literal allowlist rows, a reporting default, separate local/remote passes, and separate set-equality checks; Phase 243 recorded exact historical PR head/base names and SHAs while intentionally preserving all eight branches. Phase 245 must add a full ref inventory, refresh PR data live, and retain existing ref types and object identities for its safety anchors. [VERIFIED: `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md:1-5`; `scripts/maintainers/delete-planning-tags.sh:7-30,33-50`; `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json:17-29,67-78,119-130`]

**Primary recommendation:** Plan a no-mutation readiness/evidence stage, a committed pre-prune snapshot stage, separate local and remote apply stages behind exact-name allowlists and refreshed PR exclusions, and post-mutation identity/reachability/PR-state verification. Any prerequisite, enumeration, parsing, or identity conflict must stop before the affected deletion. [VERIFIED: `.planning/ROADMAP.md:398-405`; `scripts/maintainers/delete-planning-tags.sh:18-30,121-144,161-168,198-235`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Local branch inventory and deletion | Local Git repository | — | Branch refs and object database are local Git state. [CITED: git-scm.com/docs/git-for-each-ref; git-scm.com/docs/git-branch] |
| Remote branch inventory, safety refs, and deletion | `origin` Git server | Local Git client | Remote refs are read with live remote queries and changed by explicit push deletions. [CITED: git-scm.com/docs/git-push] |
| Open PR head/base exclusions and PR state | GitHub repository API | `gh` CLI | The protected branch names and open/closed status are live GitHub state. [CITED: cli.github.com/manual/gh_pr_list] |
| Snapshot, allowlist, and execution evidence | Committed repository artifacts | Local Git object database / GitHub API | Committed inputs make the operation auditable and checks reproducible after the mutation. [VERIFIED: `.planning/ROADMAP.md:400-405`; `.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md:147-177`] |

## Standard Stack

### Core

| Tool | Version observed | Purpose | Why standard |
|------|------------------|---------|--------------|
| Git | `git version 2.41.0` | Enumerate refs, inspect object IDs/types, delete reviewed local refs, read remote refs, and verify object existence. [VERIFIED: environment probe; `.planning/ROADMAP.md:402-404`] | Git is the repository's ref and object store; its official porcelain/plumbing commands expose exact refs and object IDs. [CITED: git-scm.com/docs/git-for-each-ref; git-scm.com/docs/git-cat-file; git-scm.com/docs/git-branch; git-scm.com/docs/git-push] |
| GitHub CLI (`gh`) | `gh version 2.101.0 (2026-09-15)` | Query open PR heads/bases and read back live PR state. [VERIFIED: environment probe] | The locked procedure explicitly uses `gh pr list`; `--json` exposes the required head/base names and state fields. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-27`; CITED: cli.github.com/manual/gh_pr_list] |

### Supporting

No external packages are required by the phase scope. Use the committed machine-readable snapshot and allowlist as data inputs; use Git and `gh` for live observations. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:7-36`]

## Architecture Patterns

### Recommended operation flow

```text
Phase 244 completion + resolved ref dependencies
                    │
                    ▼
Capture complete local refs and live origin refs ──► commit snapshot
                    │
                    ▼
Query all live open PR heads + bases ───────────────► commit evidence
                    │
                    ▼
Review exact deletion candidates; assert no overlap with PR/safety refs
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
Local exact-name pass    Remote exact-name pass
          │                    │
          └─────────┬──────────┘
                    ▼
Verify safety ref type/OID, every snapshot object, open PR state/base integrity
                    │
                    ▼
Commit execution evidence and summary prohibition statement
```

The diagram describes the gated evidence flow; local and remote inventories must stay distinct because local-only refs and live `origin` refs are not interchangeable. The tag deletion precedent explicitly learned this from local-only tags causing remote deletion errors. [VERIFIED: `.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md:168-177`; `scripts/maintainers/delete-planning-tags.sh:198-223`]

### Pattern 1: Full ref/object snapshot before mutation

**What:** Record each full ref name, direct object ID and object type; also record the peeled target ID/type for annotated tags and symbolic-ref target where present. Capture all refs returned by an unfiltered `git for-each-ref`, then query `origin` separately with `git ls-remote origin` (without `--refs`, which suppresses peeled tags) because local remote-tracking refs are not proof of current server state. The default `ls-remote` output includes a second `^{}` row for an annotated tag's target. Commit these inventories before deleting anything. Phase 237's snapshot proves the project already commits sanitized inventories before ref-related mutation, but that artifact is only a worktree/stash inventory, not a full branch-ref list. [VERIFIED: `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md:1-5,15-22`; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:80-91`; CITED: git-scm.com/docs/git-ls-remote]

Git's official `for-each-ref` format supports `%(refname)`, `%(objectname)`, `%(objecttype)`, `%(symref)`, and dereferenced `*` fields; `cat-file -e` exits zero when the object exists and is valid. Use full object IDs, preserve the direct tag object and its peeled target separately, and verify all IDs recorded in the committed snapshot after pruning. [CITED: git-scm.com/docs/git-for-each-ref; git-scm.com/docs/git-cat-file]

**Suggested capture shape (format choice is discretionary):**

```bash
git for-each-ref --format='%(refname)%09%(objectname)%09%(objecttype)%09%(*objectname)%09%(*objecttype)%09%(symref)'
git ls-remote origin
```

The format fields above are documented Git atoms. Keep local refs and remote refs in separately identified records; `git ls-remote` produces remote refs and includes peeled annotated-tag targets, while `git for-each-ref` reads the local ref database. [CITED: git-scm.com/docs/git-for-each-ref; git-scm.com/docs/git-ls-remote]

**When to use:** Always, before any local or remote branch deletion. [VERIFIED: `.planning/ROADMAP.md:400-402`]

### Pattern 2: Explicit, fail-closed allowlists and independent passes

**What:** Reuse the deletion script's useful safety shape: reporting is default, mutation needs an explicit apply flag, one pass runs per invocation, one literal ref name reaches each delete command, malformed/empty inputs fail closed, and remote transport failure is not treated as an empty remote. Its exact current accepted selectors are `local`, `verify-local`, `remote`, and `verify-remote`; those are tag-specific and should inform the design without being reused as-is for branch pruning. [VERIFIED: `scripts/maintainers/delete-planning-tags.sh:33-50,90-116,121-144,161-168,171-235`]

Run local candidate deletion and local verification separately from remote candidate deletion and remote verification. Compare observed ref sets with exact expected sets; do not use broad commands such as `git push --prune`, `--mirror`, or an unreviewed wildcard because Git documents that those can remove multiple remote refs. [VERIFIED: `scripts/maintainers/delete-planning-tags.sh:18-21,238-277`; CITED: git-scm.com/docs/git-push]

**Why this matters here:** Context D-04 requires absent local-only safety refs to be published at their exact identity, but a same-name remote ref at a different object is a stop-and-reconcile conflict, never a force-update. The branch `ci/phase-235-16-source-complete` also has divergent local and origin tips by explicit phase context; preserve and report both identities independently. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:29-30,40-45`]

### Pattern 3: Live PR exclusions, refreshed immediately before mutation

**What:** Capture `gh pr list --state open --limit 1000 --json number,state,headRefName,baseRefName,headRefOid,baseRefOid` (or an equivalent fully paginated query) immediately before each remote mutation window. Derive a protected-name set from both head and base fields; assert that neither local nor remote deletion candidates intersect it. Read back all open PRs after mutation, verify each recorded PR remains open, and confirm the named base ref still exists and resolves to the captured base object. Record OIDs to detect branch movement during the window. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-27,40-45`; CITED: cli.github.com/manual/gh_pr_list]

`gh pr list` defaults to open PRs and documents a default limit of 30; a query that silently returns only the default page cannot prove a complete exclusion set if there are more results. Use an explicit sufficient limit/pagination and fail closed if the query errors or completeness cannot be demonstrated. The JSON field allowlist includes `headRefName`, `baseRefName`, `headRefOid`, `baseRefOid`, `number`, and `state`. [CITED: cli.github.com/manual/gh_pr_list]

**Historical PR evidence:** Phase 243's committed `243-STALE-PR-EVIDENCE.json` records PR #219 as open at capture time, with head `gsd/238-generated-auth-runtime-proof-evidence` and head SHA `78e08d09135d4d0ae0d3e5636ef166d60d1d82f3`; it records PR #211's base as that same branch and SHA `fc3fbacfe19a2747c6889e37e2ceaa478d241895`. Phase 243's summary explicitly says all eight branches were retained. These are historical baselines only. [VERIFIED: `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json:17-29,67-78,119-130`; `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-03-SUMMARY.md:57-63`]

### Pattern 4: Safety-ref identity, not just name presence

Before and after the operation, compare each required remote safety ref by full ref name, ref type, and object ID. Context requires exact quoted names/patterns: `ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-*`, and `archive/local-main-pre-235-recovery`. The last must remain its existing tag. Where a safety ref is local-only, push only when the remote name is absent; if present with a different object, stop. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:29-30`]

Phase 237's research documented that `ci/phase-235-16-source-complete` and the named archive/safety refs were not all present on `origin` at that earlier capture. Treat that as a warning that preflight must enumerate current state rather than assume the remote safety set already matches the local one. [VERIFIED: `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RESEARCH.md:359-369`]

### Post-prune object proof

After each deletion pass, read the committed snapshot itself and run `git cat-file -e <full-object-id>` for every direct or peeled object ID it records. Do not regenerate the input snapshot after pruning: that would exclude the very objects whose continued existence must be proven. In evidence, retain the exact source snapshot revision/path, check command, number checked, and failures (which must be zero); the zero count is meaningful only alongside the non-empty committed inventory. [VERIFIED: `.planning/ROADMAP.md:400-402`; `.planning/phases/238-tag-guard-then-tag-deletion/238-VERIFICATION.md:154,187`]

The record must also state explicitly that no `git gc`, `git reflog expire`, or `--prune=now` ran anywhere in the milestone. Stashes remain untouched. This is not optional cleanup hygiene: Phase 237 explains that its unarchived stash objects rely on their refs/reflogs and the milestone prohibitions to remain recoverable. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:23-24`; `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md:80-112`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ref/object enumeration | A short branch-name list or counts-only report | `git for-each-ref` with full refname, object ID/type, and peeled tag fields | Git exposes ref identity and object type in one structured stream. [CITED: git-scm.com/docs/git-for-each-ref] |
| Object existence proof | A prose assertion, `git branch -a` output, or a regenerated post-prune list | `git cat-file -e` over every recorded full object ID from the committed snapshot | `-e` checks valid object existence independently of whether a ref still names it. [CITED: git-scm.com/docs/git-cat-file] |
| PR branch protection | A frozen Phase 243 list or a manual recollection of open PRs | A fresh, fully paginated `gh pr list` result with head/base names and OIDs | GitHub PR state and refs can change after historical evidence was captured. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-27,40-45`; CITED: cli.github.com/manual/gh_pr_list] |
| Destructive selection | Prefix deletion, globbing, `--prune`, or mirroring | A committed exact-name allowlist with separate local and remote membership flags | The tag script's proven safety pattern prevents local-only items from reaching remote deletion and separates observation from mutation. [VERIFIED: `scripts/maintainers/delete-planning-tags.sh:13-30,198-235`] |

**Key insight:** Deleting a branch ref and collecting its object are distinct actions. Removing a branch does not itself prove its tip is still retained; the committed pre-prune OID snapshot plus `cat-file -e` makes recoverability observable, while the explicit ban on garbage collection/reflog expiry protects the stash and unreachable-object boundary. [VERIFIED: `.planning/ROADMAP.md:400-405`; `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md:105-112`; CITED: git-scm.com/docs/git-cat-file]

## Common Pitfalls

### Pitfall 1: Planning is mistaken for execution readiness

**What goes wrong:** Branches are deleted while Phase 244 or its ref-dependent work is incomplete.  
**Why it happens:** The phase can be planned before its execution prerequisite is met.  
**How to avoid:** Make the execution-time readiness check a hard gate before any deletion command. The current state records Phase 244 as the most recently completed phase before Phase 245 began; the separate Phase 242 Hex workflow issue remains historical context and does not expand Phase 245's scope. The phase context still requires Phase 244 completion before deletion. [VERIFIED: `.planning/STATE.md:29-37`; `.planning/ROADMAP.md:80-81`; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:20-21,35-36`]
**Warning signs:** An apply command appears before a captured readiness result, or the plan proposes fixing Phase 242's blocker inside Phase 245.

### Pitfall 2: Ref name is preserved but its identity or type changes

**What goes wrong:** A same-named safety ref is force-aligned, recreated as the wrong ref type, or moved to another object.  
**Why it happens:** Verification checks only that a name appears in `git branch`/`git tag`.  
**How to avoid:** Compare refname + object type + full object ID against the committed preflight capture and locked D-04. Treat divergent same-name local/origin identities as separate required survivors; preserve the archive ref as a tag. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:29-30,40-45`]  
**Warning signs:** `git push --force`, `git branch -M`, or name-only assertions appear in the plan.

### Pitfall 3: PR inventory is truncated or stale

**What goes wrong:** A head or base branch is pruned because the exclusion result omitted a PR or came from Phase 243's historical file. Deleting an open PR's base can close the PR.  
**Why it happens:** `gh pr list` defaults to open but returns at most 30 by default; historical results are mistaken for live state.  
**How to avoid:** Set a sufficient limit or paginate, capture before mutation, combine both head and base names into the protected set, and read back PR state plus base integrity afterward. [CITED: cli.github.com/manual/gh_pr_list; VERIFIED: `.planning/ROADMAP.md:67-68,402-404`; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-27,40-45`]  
**Warning signs:** No `--limit`/pagination strategy, only head refs protected, no post-prune query, or #219's old record is the sole protection.

### Pitfall 4: Remote read failure is parsed as an empty set

**What goes wrong:** A failed network call or malformed response makes every remote ref look absent or makes a destructive pass look clean.  
**Why it happens:** A pipeline masks the status of `git ls-remote` or converts parsing errors to empty success.  
**How to avoid:** Follow `delete-planning-tags.sh`: run the transport command separately, fail on nonzero status, distinguish an empty response from a failed request, and reject an empty/unparsed inventory before mutation. [VERIFIED: `scripts/maintainers/delete-planning-tags.sh:161-168,198-208`]  
**Warning signs:** `|| true` covers the network command, candidates are silently skipped on parse errors, or output reports success with no observed refs.

### Pitfall 5: Object proof is vacuous or checks the wrong set

**What goes wrong:** The post-prune check regenerates the ref list, tests only branch tips that survived, checks only commits when a ref pointed at an annotated tag object, or reports zero failures over zero rows.  
**Why it happens:** The committed input and direct/peeled object IDs are not explicit.  
**How to avoid:** Commit a non-empty pre-prune snapshot first; retain direct ref target IDs and peeled targets/types; after pruning iterate the committed artifact and fail if it is missing, malformed, or empty. `git cat-file -e` accepts valid Git object IDs independent of type. [CITED: git-scm.com/docs/git-for-each-ref; git-scm.com/docs/git-cat-file; VERIFIED: `.planning/ROADMAP.md:400-402`]  
**Warning signs:** The script's source list is the current ref inventory, or a hard-coded count substitutes for object checks.

## Code Examples

### Live PR exclusion capture

```bash
gh pr list --state open --limit 1000 \
  --json number,state,headRefName,baseRefName,headRefOid,baseRefOid
```

`headRefName`, `baseRefName`, `headRefOid`, `baseRefOid`, `number`, and `state` are documented `gh pr list` JSON fields; `--state` and `--limit` are documented options. Check the full output for completeness before deriving exclusions. [CITED: cli.github.com/manual/gh_pr_list]

### Snapshot object proof against the committed artifact

```bash
while IFS=$'\t' read -r refname objectname objecttype peeled peeled_type symref; do
  [[ -n "$objectname" ]] && git cat-file -e "$objectname"
  [[ -z "$peeled" ]] || git cat-file -e "$peeled"
done < "$COMMITTED_REF_SNAPSHOT"
```

This is a structural example; the actual artifact parser should validate schema/header, non-empty rows, and OID format before the loop. A missing or malformed committed snapshot must fail rather than count as a pass. `git cat-file -e` behavior is documented by Git. [CITED: git-scm.com/docs/git-cat-file]

### Safe local and remote mutations

```bash
# One reviewed local branch name per call; verify local pass separately.
git branch -d "$branch"

# One reviewed remote branch name per call; verify remote state separately.
git push origin --delete "$branch"
```

The candidate values must come from the committed exact-name allowlist after readiness, PR exclusion, and safety-ref checks. `git branch -d` requires a fully merged branch; `-D` bypasses that protection. Remote deletion has no equivalent merged-status safety check, so the remote allowlist and PR/safety identity checks must be complete before issuing it. [CITED: git-scm.com/docs/git-branch; git-scm.com/docs/git-push; VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-36`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Git | Local refs, object database, origin enumeration/deletion | ✓ | `git version 2.41.0` | None for this phase |
| GitHub CLI | Live PR exclusion and post-prune state readback | ✓ | `gh version 2.101.0 (2026-09-15)` | None for proving the locked `gh pr list` criterion |
| GitHub API access/authentication | Live PR and remote ref observations | Unknown in this research run | — | Stop before mutation if live reads fail; do not substitute Phase 243 history |

The project context identified Git and GitHub CLI as the relevant execution tools; both CLIs are installed in this environment. Authentication and remote connectivity were not probed, so they remain execution-time readiness checks. [VERIFIED: environment probe; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:26-36`]

## Validation Architecture

Nyquist validation is enabled by `.planning/config.json` (`workflow.nyquist_validation: true`), but this phase's acceptance is operational evidence rather than application unit tests. No new package/framework install is indicated. [VERIFIED: `.planning/config.json:16-34`; `.planning/ROADMAP.md:400-405`]

| Req ID | Behavior | Test Type | Automated Evidence / Command | File Exists? |
|--------|----------|-----------|------------------------------|--------------|
| REPO-04 | Pre-prune ref/object set was committed; every recorded object remains valid after pruning | Integration / object-store check | Parse the committed snapshot, reject zero rows, run `git cat-file -e` for every full object ID and peeled ID | No Phase 245 snapshot yet; create as phase evidence |
| REPO-04 | No required safety ref was removed, moved, or changed type | Live remote integration | Compare live `git ls-remote` records with preflight name/type/OID evidence; verify required local-only ref publication only when absent remotely | No Phase 245 evidence yet |
| REPO-04 | Every open PR head/base was excluded and every open PR remains open with base intact | Live GitHub integration | Pre/post `gh pr list --state open --limit 1000 --json number,state,headRefName,baseRefName,headRefOid,baseRefOid`; compare PR identities and verify base ref OIDs | `243-STALE-PR-EVIDENCE.json` exists as historical precedent only |
| REPO-04 | Prohibited cleanup did not run | Committed phase record | Explicit statement in Phase 245 summary that no `git gc`, `git reflog expire`, or `--prune=now` ran anywhere in the milestone | No Phase 245 summary yet |

**Wave 0 gaps:** No code test harness is required for this operations-only phase. The plan must create its committed snapshot, exact-name allowlist, and machine-readable before/after evidence before the destructive step; use positive non-empty assertions so a failed query cannot pass vacuously. [VERIFIED: `.planning/ROADMAP.md:400-405`; `scripts/maintainers/delete-planning-tags.sh:202-208,248-261`]

## Security Domain

This is a repository-operations security surface, not an application authentication/session feature. No application-level V2/V3/V5/V6 implementation is in scope. Main threat patterns are accidental destructive selection (tampering/data loss), spoofed or stale remote identity (tampering), truncated PR enumeration (availability and integrity), and premature object collection (loss of recoverability). Use a verified `origin` URL, fail-closed live reads, exact-name allowlists, independent local/remote passes, identity comparisons, and the committed object-resolution proof. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:7-36`; `.planning/ROADMAP.md:400-405`; `scripts/maintainers/delete-planning-tags.sh:109-116,161-168,198-235`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The example parser's six tab-separated fields are a recommended Phase 245 schema, not an already approved schema. | Code Examples | Planner must choose/validate the actual schema; an incorrect field order could invalidate evidence parsing. |
| A2 | A sufficient `gh pr list --limit` plus saved output is an acceptable complete enumeration method for the current repository. | Architecture Patterns | If the CLI/API truncates or imposes a lower cap, exclusions could be incomplete; verify result completeness before applying. |
| A3 | The proposed synchronized gate-holder and injected-`mkdir` disposable-fixture cases are sufficient to distinguish transient contention from other create failures. | Coordinator Admission Failure — Plan 245-28 | If the fixtures do not capture gate lifetime or OS failure details, the original cause will remain unknown. |

## Execution-Time Preconditions — Dispositioned

1. **Exact branch deletion candidate set — RESOLVED BY EXECUTION-TIME INVENTORY GATE.** Names are deliberately unknown during planning because Phase 244 is incomplete and ref/PR state can change. After D-01 readiness passes, capture complete local and live origin refs plus a complete current open-PR head/base result; classify every branch, commit only literal full-name candidates with side, expected OID/type, and reason, then verify the committed allowlist and refresh PR exclusions immediately before each mutation window. Empty, truncated, conflicting, or changed inputs stop before deletion. Phase 243's historical inventory cannot answer this live question. [VERIFIED: `.planning/REQUIREMENTS.md:91-96`; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:20-33`]

2. **GitHub read and origin write capability — RESOLVED BY NON-MUTATING ACCESS PREFLIGHT.** The installed `gh` binary alone proves no access. After D-01 readiness and before any origin push, verify `origin` targets `szTheory/sigra`, `gh auth status` succeeds for the host, a complete `gh pr list --repo szTheory/sigra --state open --limit 1000 --json number,state,headRefName,baseRefName,headRefOid,baseRefOid` succeeds with fewer than 1000 valid rows, `git ls-remote --symref origin` succeeds with non-empty parsed refs, and authenticated `gh api repos/szTheory/sigra` reports `permissions.push == true`. Perform `git push --dry-run origin --delete <one exact allowlisted branch>` before the remote deletion pass to corroborate Git transport access without changing a ref; a dry run is not a guarantee that a later server policy will accept the real deletion. Record each command's status and identity without credentials. Any auth, permission, read, dry-run, rate-limit, or ambiguity failure stops before mutation with diagnostics; a 403/429 is held until the reported retry/reset time. Recheck immediately before the remote mutation window because permission may change. No live access value is asserted by this research. [VERIFIED: `AGENTS.md`; `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md:20-33`]

## Coordinator Admission Failure — Plan 245-28

Plan 245-28's sole authorized coordinator invocation failed before Task 1's child command ran: the recorded stderr is `repo-mutation-coordinator: FAIL: coordinator_admission_gate_busy_or_stale`, while the receipt records verified coordinator state, a free lock, zero transaction leases, and no gate directory before and after the attempt. The staged paths and their exact combined binary-diff digest remained unchanged; Task 2 did not start and production ref operations remained zero. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json:5-16,18-40,42-63`]

### Admission path and what the error proves

The shared root is derived from Git's common directory, with the literal name `sigra-branch-worktree-coordinator`; the gate path is `<root>/gate`. [VERIFIED: `scripts/maintainers/repo-mutation-coordinator.sh:7-8,49-65`; verbatim values: `SIGRA_COORDINATOR_DIR_NAME="sigra-branch-worktree-coordinator"`, `SIGRA_COORDINATOR_GATE_DIR="${SIGRA_COORDINATOR_ROOT}/gate"`]

`run` pins Git, calls `sigra_coordinator_acquire`, and does not invoke the requested child command unless acquisition succeeds. Acquisition verifies installed hooks/worktrees, then enters the gate before checking the lock and transaction leases and creating `lock/owner.json`. The observed `coordinator_admission_gate_busy_or_stale` is set only when the coordinator's gate-entry `mkdir` returns nonzero. Its implementation does not inspect the failing `mkdir`'s cause; the same error therefore covers an already-existing gate and other failures to create the directory. [VERIFIED: `scripts/maintainers/repo-mutation-coordinator.sh:145-157,352-403,475-490`; verbatim error: `coordinator_admission_gate_busy_or_stale`]

The reference-transaction hook uses the same common-root gate for prepared ref transactions and for lease release. Its distinct error text is `admission_gate_busy_or_stale`; its prepared phase either validates the coordinator token when a lock exists or records a transaction lease, and its committed/aborted phases release the lease. The Plan 28 receipt's `coordinator_admission_gate_busy_or_stale` spelling identifies the coordinator shell's own acquisition gate path, before the commit command could trigger a reference transaction. [VERIFIED: `scripts/maintainers/repo-mutation-reference-transaction:8-11,29-40,47-82,84-102,110-125`; verbatim hook error: `admission_gate_busy_or_stale`; `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json:10-16`]

### Failure distinctions and present uncertainty

| Candidate explanation | Can fit the evidence? | Distinguishing evidence |
|---|---|---|
| A short-lived coordinator or hook process created `gate` after the pre-check and removed it before the post-check. | Yes. The checks bracket the command but do not observe every instant; a process can own the atomic directory briefly. [VERIFIED: `245-28-RECOVERY.json:34-54`; `repo-mutation-coordinator.sh:145-157`] | A synchronized disposable-fixture race capture records the owner PID and gate lifetime while the contender attempts admission. |
| A gate directory was left present (stale or actively owned) at the exact `mkdir`. | Yes. The gate-entry code treats any failed `mkdir` as busy/stale and does not inspect its owner or age. [VERIFIED: `repo-mutation-coordinator.sh:145-157`] | Read-only `lstat`/directory listing and owner PID capture at the failure boundary; never infer staleness from a later absent path. |
| A non-directory object, permissions/parent state, or filesystem error prevented creation. | Also yes. `mkdir` failure causes collapse into the same error; the returned status does not establish `EEXIST`. [VERIFIED: `repo-mutation-coordinator.sh:145-149`] | Record `lstat` for the exact gate path and root, parent permissions/ownership, filesystem/mount status, and the command's OS-level errno in a disposable diagnostic harness. |
| A persistent defect in the helper's calculated path or gate-entry logic. | Not ruled out by one failed production admission and later clean snapshots. The recovery receipt identifies the verified root and later absent gate, but contains no instant-of-failure owner/errno. [VERIFIED: `repo-mutation-coordinator.sh:49-65,145-157`; `245-28-RECOVERY.json:34-54`] | Reproduce in a disposable repository with explicit path assertions and injected `mkdir` outcomes; compare with a clean acquire/release fixture. |

**Root cause remains unknown.** The recovery receipt explicitly says OS process enumeration was denied, and its ownership observation covers only the collaboration roster. Later free-lock/zero-lease/absent-gate observations cannot identify which process, if any, caused the failed create at the admission instant. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json:34-54`]

### Safe read-only diagnostics and fixture coverage

For any separately authorized future diagnosis, capture one time-stamped read-only snapshot of the resolved common directory and coordinator root; use `lstat` (including symlinks and non-directory objects) on `gate`, `lock`, and `transactions`; record lock owner fields without exposing the token; enumerate lease owner metadata; and record `ps`/open-file evidence only where permitted. Save before/after observations and command status. A denied process query remains unknown. Do not remove, rename, repair, or recreate production gate/lock state. Under Plan 245-28 specifically, retain the single-admission rule: no retry, gate repair, or lock repair is authorized by this research. [VERIFIED: `.planning/phases/245-branch-prune-local-and-remote/245-28-PLAN.md:104-107,136-144`; `.planning/phases/245-branch-prune-local-and-remote/245-28-RECOVERY.json:10-16`]

Existing coordinator coverage in `repo-mutation-coordinator.test.sh` already uses disposable repositories to prove that a prepared ref transaction lease blocks acquisition and that an unresolved lease fails closed. It also proves coordinator lock contention, but that assertion expects `coordinator_busy_or_stale_lock_present`; it does not deterministically contend for the short-lived admission gate itself. [VERIFIED: `scripts/maintainers/repo-mutation-coordinator.test.sh:154-180,182-207`; verbatim existing lock error: `coordinator_busy_or_stale_lock_present`]

If a future scoped test is approved, add disposable-fixture cases (not a production retry): (1) a synchronized gate holder pauses after creating `gate`, a contender receives the gate error, then the fixture observes the holder release and confirms normal admission; (2) a targeted fake `mkdir` fails only for the fixture gate while the path is absent, proving the current error also masks non-contention failures; and (3) a clean uncontended acquisition succeeds. Each case should assert child-command non-execution on rejection, exact pre/post path state, owner/errno capture where available, and zero mutation outside the disposable common directory. This would separate transient ownership from path/OS failures without touching this repository's production gate. [ASSUMED: proposed test design derived from the coordinator source and current fixture style; no such test was run or added.]

## Sources

### Primary (HIGH confidence)

- `.planning/phases/245-branch-prune-local-and-remote/245-CONTEXT.md` — locked decisions, scope gate, exact protected refs, live PR requirement.
- `.planning/ROADMAP.md` — Phase 245 dependencies and success criteria.
- `.planning/REQUIREMENTS.md` — REPO-04 acceptance text.
- `.planning/STATE.md` — Phase 244 current execution/blocker status.
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md` and `237-RESEARCH.md` — committed pre-mutation inventory and stash/object recoverability hazards.
- `.planning/phases/238-tag-guard-then-tag-deletion/238-CONTEXT.md`, `238-EVIDENCE.md`, `238-VERIFICATION.md` — literal allowlist execution, distinct local/remote passes, object reachability verification.
- `scripts/maintainers/delete-planning-tags.sh` — current implementation of dry-run-first exact-name deletion, failure handling, and separate verification.
- `scripts/maintainers/repo-mutation-coordinator.sh`, `scripts/maintainers/repo-mutation-reference-transaction`, and `scripts/maintainers/repo-mutation-coordinator.test.sh` — gate acquisition, Git reference-transaction lease lifecycle, and existing disposable-fixture coverage.
- `.planning/phases/245-branch-prune-local-and-remote/245-28-PLAN.md` and `245-28-RECOVERY.json` — the one-admission requirement, observed failure, unchanged staged identities, and blocked task disposition.
- `.planning/phases/243-drain-the-queue-dependabot-tiers-a-b-stale-prs-todo-triage/243-STALE-PR-EVIDENCE.json` and `243-03-SUMMARY.md` — historical PR head/base evidence and branch-preserving precedent.

### Official tool documentation (CITED)

- [Git `for-each-ref`](https://git-scm.com/docs/git-for-each-ref) — fields for full refname, object name/type, symbolic target, and peeled tag targets.
- [Git `cat-file`](https://git-scm.com/docs/git-cat-file) — `-e` object-existence semantics.
- [Git `branch`](https://git-scm.com/docs/git-branch) — local branch deletion and merged-status behavior.
- [Git `push`](https://git-scm.com/docs/git-push) — remote ref deletion, broad `--prune`/`--mirror` behavior, and remote rejection.
- [Git `ls-remote`](https://git-scm.com/docs/git-ls-remote) — querying remote refs.
- [GitHub CLI `gh pr list`](https://cli.github.com/manual/gh_pr_list) — open-state defaults, JSON fields, and result limits.

## Project Constraints (from AGENTS.md)

- Automation-first verification: use deterministic commands/API readback and commit machine-readable evidence; never waive missing evidence or call it passed.
- Keep operations scoped to authorized work; do not start unrelated phases or expand product scope.
- Preserve current user/worktree changes; do not reset, clean, stash, broadly stage, or discard unrelated files. [VERIFIED: `AGENTS.md:1-29`; `.planning/STATE.md:742-747`]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Git and `gh` versions were probed in this environment; command semantics cite official documentation.
- Architecture: HIGH for the coordinator code path — current source and fixture tests were read directly; root cause for the Plan 28 failure remains UNKNOWN.
- Pitfalls: HIGH for error-code distinctions and existing fixture coverage; the proposed additional tests are ASSUMED designs and have not been run.

**Research date:** 2026-10-01  
**Valid until:** 2026-10-27 for tool patterns; all branch/ref/PR inventories must be refreshed immediately before execution.
