# Pitfalls Research

**Domain:** Large housekeeping / release-readiness pass on a mature, PUBLIC Elixir+Hex library (sigra 1.5.0 on Hex, public repo `sztheory/sigra`) with a hybrid lib+generator architecture, byte-exact golden fixtures, and a snapshot-heavy Playwright suite.
**Researched:** 2026-09-15
**Confidence:** HIGH (repo mechanics verified live against this working tree, the GitHub API, and the Hex API; external mechanics verified against Hex and GitHub/Playwright docs)

**Milestone under study:** v1.48 CLEAN-BASELINE. Six workstreams:

| WS | Name |
|----|------|
| **WS1** | Green main, honestly (Playwright flake root-cause, `pages build`, issue #231, consecutive-push proof) |
| **WS2** | Unambiguous release namespace + cut the release (tag deletion, non-SemVer tag guard, Hex retire, adopter-resolution proof, land release) |
| **WS3** | Clean shipped surface (strip planning bookkeeping from `lib/` + `priv/templates/`) |
| **WS4** | Clean git working state (branches, worktrees, stashes, gitignore, stray tracked artifacts) |
| **WS5** | Drain the queue (10 Dependabot PRs, 8 stale PRs, 41 pending todos) |
| **WS6** | Retire v1.47's dishonest debt (TEST-01/02 supersession, skip-manifest/`MAINTAINING.md` repair, composite action into supply-chain guards) |

Ranked by **likelihood × blast radius**, with published-artifact and adopter-resolution impact weighted highest.

---

## Live evidence gathered for this research

Everything below was measured in this working tree on 2026-09-15, not recalled:

- **Hex API** (`https://hex.pm/api/packages/sigra`): `latest_stable_version = 1.20.0`, `latest_version = 1.20.0`, `retirements = {}`. Published releases: `1.20.0, 1.5.0, 1.4.0, 1.3.0, 1.2.0, 1.1.0, 1.0.0, 0.3.0, 0.2.5, 0.2.4, 0.2.3, 0.2.2, 0.2.0`. (Note `0.2.1` has a git tag and a GitHub Release but was never published to Hex — a pre-existing asymmetry, out of scope, but it means "tags and Hex releases are 1:1" is **false** here.)
- **Git tags:** 52 total. The deletion target set is 28 two-component `v1.NN` milestone tags + 11 `phase-238-generated-auth-proof-<sha>` tags. The keep set is 13 three-component SemVer release tags (`v0.2.1`…`v1.5.0`) plus `archive/local-main-pre-235-recovery`.
- **GitHub Releases:** 12, all on three-component SemVer tags only. **No GitHub Release exists on any two-component `v1.NN` tag or any `phase-238-*` tag.**
- **Reachability:** 30 tags point at commits NOT reachable from `origin/main` — including the real release tag **`v0.2.5`**, and including `archive/local-main-pre-235-recovery`.
- **Open PRs:** 18. **PR #211 is based on `gsd/238-generated-auth-runtime-proof-evidence`**, a branch on the prune candidate list.
- **Dependabot branch names are stale relative to their titles:** `dependabot/hex/hammer-7.4.1` is titled "bump hammer from 7.4.0 to **7.5.0**"; `dependabot/hex/oban-2.24.0` is titled "…to **2.24.1**".
- **`mix.exs`:** `source_ref: "v#{@version}"` (currently `v1.5.0`); `files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)` — **`priv/` ships**; `docs` has an explicit `skip_undefined_reference_warnings_on` list of 9 paths.
- **Planning bookkeeping in shipped code:** 604 matching lines across `lib/` + `priv/templates/` for `Phase NN|D-NN|NNN-NN|.planning/`. Five are `.planning/` paths, one of which — `priv/templates/sigra.install/organizations/organizations.ex:59` — **ships into every adopter's generated project**.
- **Golden fixture:** 85 files under `test/fixtures/install_golden/`; re-bless tooling exists at `lib/mix/tasks/sigra.fixture.rebless_golden.ex`.
- **No template↔`test/example/` parity guard exists.** `grep -rl parity test/sigra` returns 4 files, none of which compares `priv/templates/sigra.install/` to `test/example/`.
- **`ci.yml` job names are byte-locked to a branch-protection ruleset:** `name: Library tests  # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)`.
- **Stashes:** 6, the newest being `stash@{0}: On gsd/238-generated-auth-runtime-proof-evidence: safety: pre-release workspace snapshot 2026-08-31`.
- **Worktrees:** 6 (5 stale, all under `/private/tmp/`, one — `sigra-chimeway-opaque-main` — with a null HEAD `00000000`).

---

## Critical Pitfalls

### Pitfall 1: A glob-based tag deletion eats real release tags — and silently turns published GitHub Releases into hidden drafts

**What goes wrong:**
The natural way to delete 28 planning tags is a pattern: `git tag -d $(git tag -l 'v1.*')` or `git tag -l 'v1.4*'`. Both over-match. `v1.4*` matches the milestone tag `v1.4` **and** the real release tag `v1.4.0`. `v1.*` matches all 13 release tags. Verified external behavior: when the git tag behind a GitHub Release is deleted, **GitHub converts the Release into an untagged draft — it disappears from the public releases page** and becomes awkward to recover (`gh release list` does not list it usefully; you must re-push the tag to republish).

Worse, the compound effect: the milestone tag set includes `v1.0`, `v1.1`, `v1.3`, `v1.4`, `v1.5` — one character away from `v1.0.0`, `v1.1.0`, `v1.3.0`, `v1.4.0`, `v1.5.0`, which are the exact tags `source_ref: "v#{@version}"` points published HexDocs "View source" links at. Deleting `v1.5.0` 404s every source link in the currently-published HexDocs for 1.5.0.

Additionally, `v0.2.5` — a real release tag with a real GitHub Release — is **not reachable from `main`**. So "it's on main anyway, git will keep it" is false for at least one release tag.

**Why it happens:**
The two tag namespaces were deliberately overloaded (ADR 003) and differ only by the presence of a third version component. Shell globs cannot express "exactly two components." Nobody checks `gh release list` before deleting tags because "these are just planning tags."

**How to avoid (testable):**
1. Build the delete list as an **explicit, committed allowlist file** (`.planning/<phase>/tags-to-delete.txt`), one exact tag name per line — never a glob at the `git tag -d` call site.
2. **Gate the file** with an assertion that runs before any deletion:
   - every entry matches `^v[0-9]+\.[0-9]+$` or `^phase-238-generated-auth-proof-[0-9a-f]{8}$`;
   - **zero** entries match `^v[0-9]+\.[0-9]+\.[0-9]+$`;
   - `comm -12 <(sort delete-list) <(gh release list --limit 200 --json tagName --jq '.[].tagName' | sort)` is **empty**;
   - the surviving tag set after deletion equals the 13 SemVer tags + `archive/local-main-pre-235-recovery`, asserted by exact set comparison.
3. **Back the set up first**: `git for-each-ref --format='%(refname) %(objectname)' refs/tags > tags-backup.txt`, committed, plus `git push origin refs/tags/*:refs/tags/backup/*` is *not* needed — the text file is sufficient to restore (`git tag <name> <sha>; git push origin <name>`).
4. Delete **local first, verify, then remote** — never `git push --delete` in the same command as `git tag -d`.
5. **Post-delete assertion (WS2 acceptance criterion):** `gh release list --limit 200 | wc -l` is still 12, and `gh api repos/sztheory/sigra/releases --jq '[.[]|select(.draft)]|length'` is `0`.

**Warning signs:**
Any command in a plan containing `git tag -l 'v*'`, `git tag -d v1.*`, or a `--delete` push with a wildcard. Any plan step that deletes tags without a prior `gh release list` snapshot.

**Which of the feared risks are FOLKLORE here:**
- **"Deleting the planning tags will 404 HexDocs 'View source' links."** FOLKLORE *for the actual target set*. `source_ref` is `v#{@version}` — always three-component. No published HexDocs build ever pointed at a two-component tag. The risk is entirely in the over-match, not in the intended deletions.
- **"Deleting the planning tags will break GitHub Releases."** FOLKLORE for the target set — verified: zero Releases exist on any `v1.NN` or `phase-238-*` tag. It is a REAL risk only via over-match. **Verify, don't assume:** make the `comm -12` emptiness check a hard gate rather than trusting this research.
- **"Contributors' local clones will resurrect the deleted tags."** Mostly FOLKLORE for this repo: `git push` does not push tags by default, and this is effectively a single-maintainer repo. It becomes REAL only if someone runs `git push --tags` or has `push.followTags=true`. Mitigate with the CI non-SemVer `v*` tag guard WS2 is already scoping — that guard, not social convention, is the durable fix.
- **"Deleting a tag orphans the commit and loses work."** REAL but *narrow*: unreachable-from-main is common here (30 tags), but every unreachable tag checked is also contained in at least one branch. It becomes REAL and dangerous only when tag pruning and branch pruning happen in the same milestone — see Pitfall 5.

**Phase to address:** WS2, first phase. Explicitly sequence tag deletion **before** branch pruning so the tag-reachability check runs against the full branch set.

---

### Pitfall 2: `mix hex.retire 1.20.0` does not do what the milestone assumes, and the milestone's success criterion is unverifiable as written

**What goes wrong:**
Three distinct failure modes, in increasing subtlety:

1. **Wrong-version retire.** `mix hex.retire sigra 1.20.0 invalid` is one keystroke from `1.2.0`. Retiring the real `1.2.0` degrades a real published release. It is reversible (`--unretire`), but the retirement is publicly visible in the interim and shows on hex.pm.
2. **Auth failure re-run in a loop.** The documented Hex 2.5.0 blocker is precise and not an ownership problem: the OAuth device-flow token that `mix hex.user auth` provisions can *read* (owner-list works) but returns `key not authorized for this action` on retire. The recorded path is: mint an API **write** key at `https://hex.pm/dashboard/keys`, then `HEX_API_KEY=<key> mix hex.retire …`. A planner who writes "run `mix hex.retire`" without the `HEX_API_KEY` leg reproduces the v1.45/v1.47 deferral verbatim.
3. **The retire may not move `latest_stable_version` at all.** This is the load-bearing uncertainty. Verified from the Hex docs: *"A retired package is still resolvable and usable but it will be flagged as retired in the repository and a message will be displayed to users when they use the package."* Retirement is advisory metadata, not deletion. The resolver *prefers* non-retired versions but will still fall back to a retired one when nothing else satisfies the requirement, and `HEX_IGNORE_RETIREMENTS` can override it entirely. Whether hex.pm's `latest_stable_version` API field recomputes to exclude retirements is **not documented** — the milestone's own runbook asserts it will drop to `1.3.0` (now `1.5.0`), but that assertion has never been executed.

So the milestone can perform a technically successful retire and still have `{:sigra, "~> 1.0"}` resolve to `1.20.0`, or have `latest_stable_version` still report `1.20.0`, and a tidy-looking runbook would call it done.

**Why it happens:**
The runbook was written in 2026-07 and never executed; its "Done when" was an expectation, not an observation. Three milestones have deferred it, so each new plan inherits the unverified claim.

**How to avoid (testable):**
- **Capture pre-state as a committed artifact**, not a console read: `curl -s https://hex.pm/api/packages/sigra > evidence/hex-pre.json`, then assert `latest_stable_version == "1.20.0"` and `retirements == {}` from that file.
- **Make the retire command a literal, copy-paste operator step with the version echoed back**, and gate it: the runbook step must first run `curl -s https://hex.pm/api/packages/sigra | jq '.releases[].version'` and require the operator to confirm `1.20.0` (not `1.2.0`) is the target.
- **Separate the two acceptance criteria.** They are different claims and only one is guaranteed:
  - **RETIRE-A (guaranteed by the docs):** `curl … | jq '.retirements'` contains `1.20.0` with reason `invalid`. This WILL be satisfiable.
  - **RETIRE-B (empirical, may fail):** `latest_stable_version == "1.5.0"` AND a **real resolution proof** — scaffold a throwaway project with `{:sigra, "~> 1.0"}`, run `mix deps.get`, and assert `mix.lock` pins `1.5.0` (or whatever the released version is), capturing `mix deps.get` stdout including any retirement warning.
  - If RETIRE-B fails, that is a **finding to record**, not a phase to force green. The honest fallback is: keep the documented pinned install line, and record that Hex `latest_stable_version` does not respect retirement.
- **Do the resolution proof in a clean `HEX_HOME`** (`HEX_HOME=$(mktemp -d)`), otherwise a cached local registry makes the proof meaningless.
- **Do NOT add `HEX_IGNORE_RETIREMENTS` anywhere.** If a CI job starts failing on the retirement warning, that warning is the proof working.

**Warning signs:**
A plan whose Hex acceptance criterion is a single bullet ("Hex resolves `~> 1.0` to the GA"). A phase that marks the retire done from `mix hex.retire` exiting 0. Any use of `mix hex.retire` without `HEX_API_KEY=`.

**Recoverability:** HIGH confidence the retire is reversible — `mix hex.retire sigra 1.20.0 --unretire` is documented. Deletion is NOT available post-grace-window, which is exactly why retire is the only lever; do not let anyone propose "just delete 1.20.0."

**Blast radius:** Highest of any pitfall in the milestone — this is the one operation that mutates a public artifact that adopter resolution reads.

**Phase to address:** WS2, its own phase, after the tag work. Human-gated operator step, as already scoped.

---

### Pitfall 3: A "harmless comment edit" in `priv/templates/sigra.install/` cascades through four coupled surfaces — and the weakest link has no guard

**What goes wrong:**
WS3 wants to strip 604 planning-bookkeeping references from `lib/` and `priv/templates/`. Every single edit under `priv/templates/sigra.install/` touches four things:

1. **The byte-exact golden fixture** — 85 files under `test/fixtures/install_golden/`, asserted *byte-for-byte* by `golden_diff_test.exs` (tree + normalized `STDOUT.txt`). A one-word comment change fails this test.
2. **`test/example/`** — a hand-maintained parallel copy of generated output. This repo's own history records it as a repeatedly-biting drift source (the `sigra_auth` CSS staleness todo W-2 names it explicitly). **Verified: there is no automated template↔example parity guard.** So template edits and example edits diverge silently and the suite stays green.
3. **The published Hex tarball** — `files:` includes `priv`, so template comments are shipped artifacts. WS3's premise is correct: one dead `.planning/` path (`organizations/organizations.ex:59`) is currently copied into every adopter's project.
4. **Playwright snapshots**, if the edit is anywhere near markup or class names (the `sigra-auth-*` / `sg-*` surfaces).

The classic failure is: edit templates → re-bless the golden fixture → suite green → ship. `test/example/` is now behind the templates, and the next milestone that relies on `test/example` as a faithful generated-host stand-in gets a false result.

The second failure is re-blessing carelessly: `mix sigra.fixture.rebless_golden` makes the diff go away regardless of whether the diff was intended. Re-bless is how you *record* a change, not how you *validate* it.

**Why it happens:**
Comment edits feel zero-risk, so they are batched large ("strip 171 references") rather than reviewed per-file. The golden diff is the only thing that shouts, and its remedy (re-bless) is one command.

**How to avoid (testable):**
- **Split WS3 into two independent surfaces with different risk profiles:**
  - `lib/` only — no golden impact, no example impact, only HexDocs (see Pitfall 4). Do this first and in bulk.
  - `priv/templates/` — do this second, as a small, explicitly-enumerated set, ideally *only* the five dead `.planning/` paths plus whatever renders into adopter files. **Explicitly descope** "all 171/604 references in templates" if it cannot be done with a reviewable diff.
- **Mandate the re-bless review protocol as an acceptance criterion:** the golden re-bless commit must be *separate* from the template-edit commit, and the phase must assert `git show <rebless-sha> --stat` contains only comment-line changes — i.e. `git diff <before> <after> -- test/fixtures/install_golden | grep '^[+-]' | grep -v '^[+-][+-]' | grep -vE '^\s*[+-]\s*#'` is **empty**. Any non-comment line in a "comment cleanup" re-bless is a stop-the-line event.
- **Close the parity hole in this milestone or explicitly declare it out of scope.** Cheapest honest option: a phase task that, for each file edited under `priv/templates/sigra.install/`, asserts the corresponding `test/example/` file received the same edit — a per-file checklist in the plan is acceptable; a test is better. Do not let the milestone touch templates while claiming the parity risk is handled by "the suite is green."
- **Assert the adopter-visible outcome, not the grep count:** after WS3, `grep -rn '\.planning/' priv/templates/` returns 0, **and** a freshly generated app (the existing install fixture harness) contains zero `.planning/` strings. Grep the *generated output*, not the templates.
- **Assert the Hex tarball:** `mix hex.build` then `tar tzf sigra-*.tar` / inspect `contents.tar.gz` and grep for `.planning/` → 0 hits. This is the criterion that actually matches "clean shipped surface."

**Warning signs:**
A single commit touching both `priv/templates/` and `test/fixtures/install_golden/`. A re-bless whose diff contains non-comment lines. A plan that says "strip planning references" with a count target instead of a file list.

**Phase to address:** WS3, split into `lib/`-surface and `templates/`-surface phases. The parity assertion belongs to the templates phase.

---

### Pitfall 4: Editing `@moduledoc`/`@doc` breaks ExDoc autolinks or silently invalidates the `skip_undefined_reference_warnings_on` allowlist

**What goes wrong:**
`mix.exs` carries a 9-entry `skip_undefined_reference_warnings_on` list — five `lib/` modules whose moduledocs reference hidden Application helpers, two upgrade guides, and two recipe guides. Two coupled failure modes:

1. **Removing text un-needs a suppression.** If WS3 deletes the moduledoc paragraph that referenced the hidden helper, the suppression entry becomes dead. Dead entries are harmless at runtime but they are exactly the kind of stale allowlist this milestone exists to kill — and leaving them means the next person can't tell which suppressions are live.
2. **Editing text around an autolink breaks it.** ExDoc autolinks `` `Module.fun/1` `` by backtick convention. Reflowing a paragraph to remove "Phase 131:" can split a backticked reference across a line, or drop a backtick, producing a broken or plain-text link. Worse direction: *adding* a reference to something undefined raises a new warning — which in this repo's docs posture is treated as a build failure.
3. **`.planning/` paths in moduledocs are autolink-adjacent.** `lib/sigra/audit.ex:5` says `` See `.planning/phases/09-audit-logging/09-CONTEXT.md` `` — backticked, rendered on HexDocs, pointing at a path no adopter has. This is a real docs defect, not just bookkeeping, and it is the strongest justification for WS3 on `lib/`.

**Why it happens:**
Doc edits are invisible to the test suite. `mix test` is green with broken HexDocs. The only detector is a docs build, which nobody runs during a comment cleanup.

**How to avoid (testable):**
- **Acceptance criterion: `mix docs` produces zero warnings, run as a gate in the WS3 phase**, not as a spot check. Capture stderr to an evidence file.
- **Prune the suppression list in the same phase.** For each of the 9 entries, assert it is still needed: remove the entry, run `mix docs`, and if there is no warning, the entry stays removed. The end state is: every remaining entry is provably load-bearing. This directly serves the milestone thesis (no stale guards).
- **Assert no `.planning/` path survives in any rendered doc:** `grep -rn '\.planning/' doc/` after `mix docs` → 0 hits (covers moduledocs *and* extras).
- **Do not touch `@doc` on public functions in a cleanup milestone** beyond removing bookkeeping prefixes. Rewording public docs is a behavior-adjacent change on a public library and is scope creep (Pitfall 10).

**Warning signs:**
A WS3 diff that reflows paragraphs rather than deleting bookkeeping tokens. A phase with no `mix docs` step. `skip_undefined_reference_warnings_on` unchanged after a doc cleanup that touched the listed files.

**Phase to address:** WS3, `lib/` surface phase.

---

### Pitfall 5: Compound reachability loss — tag prune + branch prune + worktree removal + stash drop in one milestone

**What goes wrong:**
Individually each prune is safe because *something else* still references the commits. Together they are not. Measured state:

- 30 tags point at commits unreachable from `main`; each is currently held by at least one branch.
- `archive/local-main-pre-235-recovery` (2026-09-08, `docs(235-16): unblock source-complete gap closure`) is an explicit safety tag — **a tag named `archive/*` is a keep, not a prune**, and a naive "delete non-SemVer tags" rule kills it.
- `ci/phase-235-16-source-complete` is **442 commits ahead of main** and is documented as holding work not on main (the TEST-01/02 re-wiring the WS6 supersession decision is *about*).
- `safety/local-main-before-release-cleanup-20260831` is 16 ahead / 29 behind — a prior safety branch.
- 6 stashes, oldest from the phase-88 era; `stash@{0}` is literally labelled `safety: pre-release workspace snapshot`.
- 5 stale worktrees, one (`/private/tmp/sigra-chimeway-opaque-main`) with a null HEAD, which makes `git worktree remove` behave unexpectedly and can leave a broken admin entry.
- Worktrees live under `/private/tmp/` — **macOS may have already reaped them**, meaning `git worktree list` shows entries whose directories no longer exist. `git worktree prune` is the right verb; `rm -rf` on a live worktree without pruning leaves stale metadata.

Once tags are gone and branches are pruned, a stash drop or a `git gc` makes the commits genuinely unrecoverable — `git reflog` on a *deleted* branch is not durable, and `gc` will eventually reap.

**Why it happens:**
The four prunes read as one "tidy the git state" task and get batched into one phase. The safety artifacts are *named* as safety artifacts, but the prune criterion is "is it merged to main?" — and by construction, safety artifacts are not.

**How to avoid (testable):**
1. **Hard keep-list, asserted before any prune:** `archive/local-main-pre-235-recovery`, `ci/phase-235-16-source-complete`, `safety/local-main-before-release-cleanup-20260831`, and every branch that is the head **or base** of an open PR. Assert the keep-list survives with `git rev-parse --verify` after the prune.
2. **Sequence: tags → branches → worktrees → stashes.** Never the reverse, and never in parallel. Each step re-runs the reachability check against the *post-previous-step* ref set.
3. **Before any branch deletion, materialize the stashes.** Stashes are the least durable artifact in git. Convert each of the 6 to a real ref: `git stash branch stash-archive/<n> stash@{n}` or `git tag stash-archive/<n> stash@{n}`, push, *then* `git stash clear`. Assert: 6 archive refs exist on `origin` before `git stash list` is empty.
4. **`git worktree list` → `git worktree prune` → verify.** Do not `rm -rf` first. Acceptance: `git worktree list | wc -l` is 1.
5. **Acceptance criterion for the whole WS4: every commit SHA recorded in the pre-prune inventory is still `git cat-file -e`-resolvable at the end of the milestone**, and no `git gc --prune=now` is run anywhere in the milestone.

**Warning signs:**
A plan step containing `git stash clear` before the branch work. A prune criterion phrased as "delete merged branches" (none of the risky ones are merged). Any `git gc`, `git reflog expire`, or `--prune=now`.

**Phase to address:** WS4, as a strictly sequenced single phase with per-step gates. Must run **after** WS2's tag work and **after** WS5's PR drain (so no open PR's base or head is a prune candidate).

---

### Pitfall 6: Deleting a branch that is the BASE of an open PR silently closes the PR

**What goes wrong:**
GitHub closes a pull request when its **base** branch is deleted. **PR #211** (`ci/recapture-admin-checkpoints-31043224661`) is based on `gsd/238-generated-auth-runtime-proof-evidence` — a `gsd/*` branch that reads exactly like prune bait. **PR #219** uses that same branch as its head. Pruning it closes #211 and #219 in one move, with no recovery path other than reopening and re-pushing the branch.

More broadly, the WS4 prune candidates overlap the WS5 PR set: `ci/phase-235-1-evidence` (PR #234), `gsd/phase-232-playwright-economics` (PR #174), `docs/230-phase-complete` (PR #124), and every `dependabot/*` branch.

**Why it happens:**
Branch prune lists are usually built from `git branch --merged` / age, not from the PR graph. Base-branch relationships are invisible in `git branch` output.

**How to avoid (testable):**
- **Build the prune exclusion from the PR graph, both directions:**
  `gh pr list --state open --limit 200 --json headRefName,baseRefName --jq '.[] | .headRefName, .baseRefName' | sort -u` → this set is excluded, verbatim, from any prune.
- **Order WS5 before WS4.** Drain/close the PRs first; the branches become prunable as a consequence.
- **Never let Dependabot branches be pruned manually.** Deleting a Dependabot branch closes its PR and Dependabot will re-open it on the next run, producing churn that looks like the queue regrew.
- **Acceptance criterion:** after WS4, `gh pr list --state open --json number --jq 'length'` equals the number WS5 intentionally left open, and no PR has `closed` with reason "base branch deleted" in the milestone window.

**Warning signs:**
A prune list built before the PR drain. Any `git push origin --delete` on a branch matching `gsd/*` or `dependabot/*`.

**Phase to address:** WS5 (drain) sequenced before WS4 (prune); the exclusion query is a WS4 pre-flight assertion.

---

### Pitfall 7: "Fixing" the Playwright flake with retries, waits, or a single green run

**What goes wrong:**
The `Generated admin Playwright smoke` flake is the mechanism that silently stranded releases in v1.45 — a red `ci-gate` blocks release-please's auto-publish. There are three ways to fail at fixing it:

1. **Retry-wrap it.** `retries: 2` in the Playwright config, or a workflow-level re-run, makes the job green while preserving the defect. The milestone brief already forbids this; the plan must make the prohibition *checkable*, because "add a retry" is the path of least resistance under time pressure.
2. **Add a `waitForTimeout`.** Sleep-based stabilization is retry-wrapping with extra steps and produces a slower suite that still flakes under load. Note the repo's documented history: a per-shard-DB parallelization todo and a documented actor-filter *race* (`2026-07-30-admin-generated-audit-presets-actor-filter-race.md`) — meaning at least one admin-surface race is already known to exist. **The flake may be a real intermittent product bug**, and the actor-filter race is the leading hypothesis to rule in or out first.
3. **Declare it fixed from one green run.** A flake with, say, a 15% failure rate passes a single run 85% of the time. One green proves nothing.

**Why it happens:**
Flake root-causing is open-ended and the milestone has five other workstreams. The green checkmark is the same shape either way.

**How to avoid (testable):**
- **Require a reproduction before a fix.** Acceptance criterion: the phase records a *failing* run — either a captured CI failure with trace/video artifact, or a local loop (`npx playwright test <spec> --repeat-each=30`) that reproduces. **No fix lands without a recorded red.** This repo has a documented lesson (the 216 probe/DOM-scope gap) that green self-tests cannot be trusted; the symmetric rule is that a fix needs a red to have fixed.
- **Require a differential diagnosis artifact**: is this (a) a test-harness race (selector/ordering/fixture), (b) a shared-DB/parallelism collision, or (c) a product race in the admin surface? Name which, with evidence. If (c), the fix belongs in `lib/`, and that is a legitimate scope expansion to accept — a real intermittent product bug in a shipped auth library outranks the cleanup.
- **Statistical acceptance, not a single run.** The milestone already asks for "consecutive pushes with live-run evidence." Make the number explicit and derived: to claim a ≤1% residual flake rate with reasonable confidence you need on the order of **20+ consecutive green runs** of that job. This repo has precedent for exactly this kind of n-run evidence bundle (FAST-01 ran n=52), so the machinery exists — reuse it rather than inventing a new harness.
- **Prohibition guard.** This repo already mechanizes prohibitions under `scripts/ci/prohibitions/*.test.mjs` and CI runs them. Add one: no `retries:` > 0 in the Playwright config for the affected project, and no new `waitForTimeout` in the touched specs. That turns "don't retry-wrap" from a plan sentence into a failing test.

**Warning signs:**
A diff adding `retries`, `waitForTimeout`, `test.slow()`, or `--repeat-each` only as a *verification* step without a prior red. A phase verification that cites "CI green" with n=1.

**Phase to address:** WS1, first phase, as its own phase with the reproduction as a gate before the fix plan is written.

---

### Pitfall 8: Merging 10 Dependabot PRs into the lanes being stabilized — especially Playwright 1.59→1.62 against a snapshot suite

**What goes wrong:**
Three distinct hazards, one of which is specific to this repo's snapshot posture:

1. **Confounding.** WS1's whole output is "prove `ci-gate` green across consecutive pushes." Merging 10 dependency bumps into the same window destroys the attribution: a post-merge red could be the flake, the bump, or both. Worse in reverse — a bump could *mask* the flake by changing timing.
2. **`@playwright/test` 1.59.1 → 1.62.1 against a large baseline suite.** Verified from the release notes: 1.60 (May 2026), 1.61 (June 2026, WebAuthn passkeys + Web Storage API, "no breaking changes"), 1.62 (July 2026, adds WebP for visual comparisons, a new component-testing model, isolated retries, bundled MCP). No release note announces a snapshot-format break — but **the real risk is not the API, it is the bundled browser build.** A Playwright minor bump ships new Chromium, and new Chromium changes font rasterization/antialiasing at the pixel level. On a repo with ~115 committed baselines whose recapture is documented as CI-native-only (never recapture on darwin), a browser-version change can invalidate a large fraction of baselines at once — and the repo's own canary-drift guard is designed to *fail* on exactly that, which is correct behavior that will read as "the Playwright bump broke CI."
   Note 1.61's **WebAuthn passkeys** support is directly relevant to a passkey-heavy auth library: it could change how existing virtual-authenticator test scaffolding behaves. That is an opportunity, not just a risk, but it is a behavior-surface change.
3. **`credo` 1.7.18 → 1.7.19 against `mix ci`.** Credo patch releases routinely add or tighten checks. `mix ci` is the declared single-owner local/PR parity path, so a new credo finding fails the whole gate, and the fix is a code change — i.e. a dependency bump turns into a refactor inside a cleanup milestone.
4. **Stale branch names.** `dependabot/hex/hammer-7.4.1` is actually 7.4.0→**7.5.0**; `dependabot/hex/oban-2.24.0` is actually →**2.24.1**. Anything that reasons about the version from the branch name (a script, a changelog entry, a plan) will be wrong.

**How to avoid (testable):**
- **Sequence WS5's Dependabot drain AFTER WS1's green-main proof is captured.** The green-main evidence must be taken on a HEAD that does not include the bumps; otherwise the proof is about a different tree.
- **Tier the 10 PRs by blast radius and merge in tiers, not as a batch:**
  - *Tier A (merge freely, one batch):* `actions/attest-build-provenance`, `@anthropic-ai/sdk`, `zod` — no effect on the visual suite or the library gate.
  - *Tier B (merge individually, watch one full CI):* `flop_phoenix`, `hammer`, `threadline`, `oban`, `otplib`, `@axe-core/playwright` — library/runtime behavior; `@axe-core/playwright` 4.11→4.13 can add new a11y rules that fail existing axe assertions.
  - *Tier C (its own phase):* `@playwright/test` 1.59.1 → 1.62.1.
- **Tier C acceptance criteria (write these as plan tasks):**
  - Record the bundled Chromium/Firefox/WebKit revisions before and after (`npx playwright --version`, `npx playwright install --dry-run`), as an evidence artifact.
  - Run the full snapshot suite **CI-native on ubuntu** (never darwin — the repo's documented rule) and record the exact count and list of drifted baselines.
  - If drift is zero: bump merges, done.
  - If drift is non-zero: recapture **only** via the existing in-CI recapture lane, and require a human/visual diff review of the drifted set before blessing — a recapture that is blessed unreviewed converts a browser-rendering change into a permanently-accepted baseline, which is the visual-testing equivalent of re-blessing a golden diff you didn't read (Pitfall 3).
  - **The canary slugs are excluded from recapture** (documented in this repo's recapture lane) — verify the canary list is preserved post-recapture.
- **Read the version from `mix.lock` / `package-lock.json` in the merged result, never from the branch name.** Acceptance: for each merged bump, the locked version matches the PR title.
- **`credo` bump:** run `mix credo --strict` locally before merging; if it produces findings, the bump is **deferred to a todo**, not fixed inline. Fixing credo findings is scope creep.

**Warning signs:**
"Merge all Dependabot PRs" as a single plan task. A recapture commit in the same PR as the Playwright bump. Green-main evidence dated after the bump merges.

**Phase to address:** WS5, tiered; Tier C gets its own phase, scheduled after WS1.

---

### Pitfall 9: Retiring TEST-01/02 by deleting the module and rewriting the guard — producing a *second* dishonest guard

**What goes wrong:**
The v1.47 audit's finding is precise: `phase_233_library_economics_contract_test.exs` was rewritten to *assert* the single-owner `mix ci` topology (`length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1`, `refute body =~ "mix test"`, `refute workflow =~ "library_tests_scaffold:"`), so the guard now passes at HEAD **because it encodes the regression as the requirement**. Phase 233 therefore re-verified green while TEST-01/TEST-02 were dead.

The obvious v1.48 move — delete `ExUnitTimingFormatter`, rewrite the contract test to say "superseded" — reproduces the exact failure if the rewritten test still merely restates HEAD. A test that asserts "the workflow looks like it currently looks" is not a guard; it is a screenshot.

Two secondary hazards:
- **Deleting something with a non-obvious consumer.** `SIGRA_EXUNIT_TIMING_PATH` has zero references in `.github/`, `scripts/`, `mix.exs` — verified by the audit — but the re-wiring commits exist on `ci/phase-235-16-source-complete` (442 commits ahead). Deleting the module on `main` makes that branch unmergeable-as-is. That is fine *if it is a recorded decision*; it is data loss if nobody notices.
- **The parallel case in WS6:** the skip manifest cites `scripts/ci/prohibitions/honest-skip-parity.test.mjs`, which **does not exist** (only p01–p16 do), and the unenforced `MAINTAINING.md` leg has already rotted — `MAINTAINING.md:172-178` describes `design_gallery_snapshots` inside a job it no longer lives in, and `:177,231` cite a step `Aggregate Playwright step outcomes` that Phase 232 deleted (0 grep hits at HEAD). Deleting the manifest's two false claims is the *easy* fix and leaves the rot unenforced; writing the guard is the *honest* fix and will fail until `MAINTAINING.md` is corrected.

**Why it happens:**
Under close-out pressure, "make the guard match reality" and "make the guard catch drift" look identical from the diff. Only the *failure* direction distinguishes them, and nobody tests the failure direction.

**How to avoid (testable):**
- **Fail-first is mandatory for every guard this milestone writes or rewrites.** This repo already has the machinery: `check prohibition-enforcement` proves each prohibition fails against a known-bad fixture in `test/fixtures/prohibitions/` before accepting a pass. Every WS6 guard must have a committed known-bad fixture and a demonstrated red. Acceptance: the phase records the guard's failing output against the fixture, not just its passing output.
- **A supersession is a decision record, not a test rewrite.** Write an ADR (004) that states TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology, why, and what the replacement guarantee is. The test then asserts *the replacement guarantee* (e.g. "the library suite has exactly one owner and that owner is `mix ci`"), and the ADR is what makes that assertion legitimate rather than circular.
- **Pre-delete consumer sweep as an assertion**, not a claim: `git grep -n ExUnitTimingFormatter -- ':!test/support' ':!.planning'` and `git grep -n SIGRA_EXUNIT_TIMING_PATH` across **all refs** (`git grep <term> $(git rev-list --all --branches)` is expensive; at minimum grep `main` plus every keep-list branch). Record the branches that would be affected in the ADR.
- **For the skip manifest: write the guard, don't delete the claim.** Acceptance: `scripts/ci/prohibitions/honest-skip-parity.test.mjs` exists, is wired into the `node --test … scripts/ci/prohibitions/*.test.mjs` step, has a known-bad fixture, and **initially fails** against HEAD's `MAINTAINING.md`. Then fix `MAINTAINING.md:172-178,231` to describe the shard topology. Both halves in the same phase.

**Warning signs:**
A rewritten contract test with no accompanying decision record. A guard added with no known-bad fixture. A WS6 plan that "removes the inaccurate manifest lines."

**Phase to address:** WS6, split: (a) TEST-01/02 supersession ADR + deletion + replacement guarantee guard; (b) skip-parity guard + `MAINTAINING.md` repair; (c) Phase 232 composite action brought inside the supply-chain guards (SHA-pinning + mutation coverage — same fail-first rule applies).

---

### Pitfall 10: Declaring the cleanup done from a tidy diff, with no live evidence

**What goes wrong:**
This is the repo's signature failure mode and it is *maximally* likely in a cleanup milestone, because a cleanup milestone's output genuinely *is* a tidy diff. The documented precedents:

- v1.47's Phase 233 contract test re-verified green while blessing a regression.
- The skip manifest asserts a guard file that does not exist; `231-RESEARCH.md:275` found this and it was never fixed.
- `ci-gate` counted `skipped` as pass (fixed in v1.47).
- `generated_admin_playwright_smoke` was skipped on every PR behind a long-merged branch name.
- The v1.45 close-out deferred the Hex retire with a runbook whose "Done when" was an unexecuted expectation (Pitfall 2).
- The 216 probe/DOM-scope lesson: green self-tests could not be trusted; and the SC-5 committed-HEAD trap — a harness green at a pre-commit SHA is invalid.

The v1.48-specific shape: grep counts go to zero, tags disappear, branch list shrinks, PR count drops — every metric is a *count*, and counts are trivially satisfiable without the underlying property holding. `grep -c '.planning/' priv/templates/ == 0` does not prove a generated app is clean. `git tag | wc -l == 14` does not prove no Release became a draft. `gh pr list | wc -l` dropping does not prove the merges were safe.

**Why it happens:**
Cleanup work has no natural functional test. The absence of a thing is harder to assert than its presence, so planners reach for counts.

**How to avoid (testable):**
- **Every WS gets at least one acceptance criterion that is an observation of a live external system, not a repo grep.** Concretely:
  - WS1 → n≥20 consecutive green `ci-gate` runs pulled from the GitHub API, plus a captured *red* for the flake before the fix.
  - WS2 → `curl https://hex.pm/api/packages/sigra` pre/post artifacts; a `mix deps.get` resolution proof in a clean `HEX_HOME`; `gh release list` count unchanged; `gh api …releases --jq '[.[]|select(.draft)]|length' == 0`.
  - WS3 → a **freshly generated app** grepped clean, plus `mix hex.build` tarball grepped clean, plus `mix docs` warning-free.
  - WS4 → every pre-prune commit SHA still `git cat-file -e`-resolvable; 6 stash archive refs present on `origin`.
  - WS5 → locked versions in `mix.lock`/`package-lock.json` match PR titles; snapshot drift count recorded (even if zero).
  - WS6 → each new/rewritten guard demonstrated RED against a committed known-bad fixture.
- **Ban count-only criteria.** A plan whose only acceptance for a workstream is a grep count or a `wc -l` is rejected at review.
- **Capture evidence at the final committed HEAD on a clean tree** — the SC-5 lesson. An evidence bundle rendered at a pre-commit SHA is invalid.
- **Run `mix ci` (the declared local/PR parity path) before every push**, not root `mix test` — root `mix test` misses formatting and `test/example`.
- **Milestone-level criterion:** a close-out re-audit that re-derives each workstream's claim from primary sources (GitHub API, Hex API, a fresh generation) rather than from the phase SUMMARYs. v1.47's close-out re-audit is the model — it is what caught the blessed regression.

**Warning signs:**
Any phase VERIFICATION whose evidence section is a list of greps. A phase marked complete with no artifact under an `evidence/` path. "The suite is green" as the sole verification for a template or workflow change.

**Phase to address:** Every workstream; enforce at roadmap level by requiring one live-observation criterion per phase, and at milestone close by a mandatory re-audit.

---

### Pitfall 11: Renaming or "tidying" a CI job name, breaking a branch-protection required context

**What goes wrong:**
`ci.yml:567` reads `name: Library tests  # BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT (D-02)`. There are five ruleset-required contexts. A cleanup pass that normalizes job names, or strips the `D-02` bookkeeping comment *and the warning it carries*, can rename a required context. The failure mode is the dangerous direction: GitHub does not error — the required context simply **never reports**, and PRs hang forever "waiting for status," or (depending on ruleset config) merge with the gate absent.

This is squarely in v1.48's blast radius because WS3's mandate is "strip `Phase NN`, `D-NN`, `NNN-NN`" — and those tokens appear in load-bearing CI comments.

**Why it happens:**
The coupling lives in GitHub's settings, not in the repo, so nothing in the working tree fails when it breaks.

**How to avoid (testable):**
- **Scope WS3 explicitly to `lib/` and `priv/templates/` only.** `.github/`, `scripts/`, `MAINTAINING.md` and `test/` bookkeeping tokens are **out of scope** — they are cross-references to guards and decisions, not shipped surface. Write this as a negative scope statement in the milestone brief.
- **Assertion:** `git diff origin/main -- .github/ | grep -E '^\+.*name:'` is empty for WS3 phases.
- **If any workflow job name must change (it shouldn't):** update the ruleset first via `gh api repos/sztheory/sigra/rulesets/14941512`, confirm, then rename.

**Warning signs:**
Any WS3 diff touching `.github/`. A "normalize comments repo-wide" task.

**Phase to address:** WS3 scope boundary; assert in every WS3 phase.

---

### Pitfall 12: Scope creep — the cleanup metastasizes

**What goes wrong:**
Each workstream has an adjacent, tempting, larger problem:

| Workstream | The adjacent temptation |
|---|---|
| WS1 flake | "while we're here, shard the Playwright DB" (there's a todo for it) |
| WS2 tags | "while we're here, slim the 645M `.git` with filter-repo" — **explicitly out of scope** |
| WS3 docs | "while we're here, rewrite these moduledocs properly" |
| WS4 git | "while we're here, move `.planning/` out of the repo" — **explicitly out of scope** |
| WS5 credo bump | "while we're here, fix the 12 new credo findings" |
| WS5 todos | "while we're here, fix the easy ones" (41 pending todos) |
| WS6 TEST-01/02 | "while we're here, actually restore two-shard partitioning" |

The 41-todo triage is the highest-risk item: triage means **keep / close / defer with a recorded reason**, and every todo read invites a 20-minute fix. 41 × "just this one" is a second milestone.

**Why it happens:**
Cleanup work has no natural boundary — every file touched reveals another thing worth touching. And the milestone's own thesis ("pay down baseline debt") reads as permission.

**How to avoid (testable):**
- **The todo triage produces exactly three outputs per todo: `keep` (stays pending, with a reason), `close` (with evidence it's resolved), `defer` (with a named future milestone).** Zero todos are *fixed* during triage. Acceptance criterion: the triage phase's diff touches only `.planning/todos/`.
- **A "found while cleaning" intake rule:** anything discovered mid-phase that is not on the workstream's list becomes a **new todo file**, never an in-phase fix. This repo already has the loose-notes capture pattern; use it.
- **One exception, pre-authorized:** if the WS1 flake root-cause lands on a genuine product race in `lib/` (Pitfall 7 case (c)), fixing it is in scope — a real intermittent bug in a shipped auth library outranks the cleanup. Name this exception explicitly in the roadmap so it doesn't have to be argued for mid-execution.
- **Re-state the out-of-scope list in every phase brief**, verbatim: W-3/W-4 generated-auth runtime proof, admin/operator-UI iteration, pruning `.planning/` from the repo, BFG/filter-repo history slimming, any new feature work.

**Warning signs:**
A phase diff touching `lib/` outside the WS3 doc-comment surface. A todo triage commit that also changes code. A phase whose plan count grows during execution.

**Phase to address:** Roadmap-level guardrail; re-asserted per phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Re-bless the golden fixture without reading the diff | Green in 30 seconds | The fixture stops being a regression barrier and starts being a transcript of whatever last happened | **Never.** Require a comment-lines-only assertion on the re-bless diff. |
| Retry-wrap the Playwright flake | `ci-gate` green today; release unblocked | The v1.45 silent-release-stranding mechanism stays live, now with a longer feedback loop | **Never** in this milestone — WS1's entire purpose is the root cause. A *temporary* retry with a filed todo + a hard deadline is arguable only if the release is genuinely blocked. |
| Skip the `test/example/` mirror when editing templates | Half the edits | Silent drift; the next milestone's "generated host" evidence is about a stale tree | Only if the edit is provably template-only (e.g. a file with no example counterpart), asserted per-file. |
| Delete the two false skip-manifest lines instead of writing the guard | Manifest is accurate today | The `MAINTAINING.md` leg stays unenforced and re-rots; the milestone repeats the exact pattern it exists to kill | Acceptable only as an explicitly-recorded deferral with a filed todo — not as the phase's definition of done. |
| Batch-merge all 10 Dependabot PRs | One merge event | Green-main attribution destroyed; a Playwright browser bump silently invalidates ~115 baselines mid-stabilization | Tier A only (provenance action, SDK, zod). |
| Use a glob for tag deletion | One command | Release tags deleted; GitHub Releases become hidden drafts; published HexDocs source links 404 | **Never.** Explicit allowlist file + set-equality assertion. |
| `git stash clear` to tidy | Clean `git stash list` | Six stashes, one explicitly labelled "safety," unrecoverable after gc | **Never** before materializing each stash as a pushed ref. |
| Accept the retire as done on exit code 0 | The three-milestone-old todo closes | `latest_stable_version` may still be `1.20.0`; the adopter-facing problem persists behind a closed todo | **Never.** Split RETIRE-A (guaranteed) from RETIRE-B (empirical) and let RETIRE-B fail honestly. |
| Fix todos during triage | Fewer pending todos | The milestone becomes unbounded | **Never.** Triage is keep/close/defer only. |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **hex.pm — retire** | Assuming retire removes the version from resolution. Docs: *"A retired package is still resolvable and usable but it will be flagged as retired… a message will be displayed to users."* | Treat retire as advisory metadata. Assert `retirements` contains `1.20.0` (guaranteed) separately from `latest_stable_version == 1.5.0` (empirical). Prove adopter resolution with a real `mix deps.get` in a clean `HEX_HOME`. |
| **hex.pm — auth (Hex 2.5)** | Running `mix hex.retire` with the device-flow token from `mix hex.user auth`. Returns `key not authorized for this action` despite `full` ownership — an OAuth *scope* problem, not an ownership problem. | Mint an API **write** key at `https://hex.pm/dashboard/keys` (Hex 2.5 removed the CLI `key generate` subcommand) and run `HEX_API_KEY=<key> mix hex.retire …`. |
| **hex.pm — resolution override** | Reaching for `HEX_IGNORE_RETIREMENTS` when a warning appears in CI | Never set it. The warning is the proof that the retirement works. |
| **GitHub Releases** | Deleting a tag that backs a Release. The Release becomes an untagged **draft**, vanishes from the public page, and is hard to enumerate or delete. | Diff the delete-list against `gh release list --json tagName` and require an empty intersection before deleting. Recovery: re-push the tag, then republish the draft. |
| **GitHub PRs** | Deleting a branch that is a PR's **base** — GitHub closes the PR. PR #211's base is `gsd/238-generated-auth-runtime-proof-evidence`. | Exclude both `headRefName` and `baseRefName` of all open PRs from any prune. Drain PRs (WS5) before pruning (WS4). |
| **GitHub branch-protection rulesets** | Renaming a CI job. The required context silently never reports. `ci.yml` marks names `BYTE-IDENTICAL to ruleset 14941512 — DO NOT EDIT`. | Keep `.github/` out of WS3 scope; assert `git diff -- .github/ \| grep '^\+.*name:'` is empty. |
| **ExDoc / HexDocs** | Editing moduledocs without running `mix docs`; leaving stale `skip_undefined_reference_warnings_on` entries | `mix docs` warning-free as a phase gate; prune each of the 9 suppression entries by removing-and-retesting. |
| **Hex tarball** | Assuming `priv/templates/` comments aren't shipped. `files:` includes `priv`. | `mix hex.build` + grep the tarball for `.planning/` → 0. |
| **Playwright minor upgrade** | Treating 1.59→1.62 as an API-compat question. The real risk is the bundled Chromium rev changing pixel rendering across ~115 committed baselines. | Record browser revisions pre/post; run the snapshot suite CI-native on ubuntu (never darwin); recapture only via the in-CI lane with the canary slugs preserved; human-review the drifted set. |
| **Dependabot** | Reading the version from the branch name. `dependabot/hex/hammer-7.4.1` is actually →7.5.0; `oban-2.24.0` is actually →2.24.1. | Read from `mix.lock`/`package-lock.json` in the merged result and assert it matches the PR title. |
| **release-please** | Assuming the release lands because the Release PR (#224, `chore(main): release 1.5.1`) is open. Auto-publish is gated on `ci-gate`; a red gate strands it silently — the exact v1.45 mechanism. | Land the release **only after** WS1's green-main proof. Verify publish by querying the Hex API for the new version, not by the workflow's green check. Note the documented `gate-ci-green` timeout and the manual `hex-publish.yml` dispatch recovery path. |
| **`mix ci` vs `mix test`** | Verifying locally with root `mix test` | `mix ci` is the declared parity path; root `mix test` misses formatting and `test/example`. |

---

## Performance Traps

Not a scaling milestone, but three timing/throughput traps apply:

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-flaking the suite by fixing a race with sleeps | PR p50 creeps back up from 7m49s toward the v1.47 baseline of 27.3m | Prohibit `waitForTimeout` in the touched specs (mechanized prohibition); re-measure PR p50 after WS1 and assert it stays <720s | Immediately — v1.47's headline win is the thing at risk |
| n≥20 flake-proof runs consuming the CI budget | The green-main proof itself becomes the slowest part of the milestone | Prove on the *single affected job* via `workflow_dispatch` / a matrix repeat, not by 20 full pushes | If proof is attempted via 20 full CI runs |
| Golden-diff test runtime under repeated re-bless cycles | `golden_diff_test.exs` carries `timeout: 300_000` and scaffolds a real app per test | Batch template edits into one re-bless rather than iterating edit→re-bless→edit | If WS3 edits templates file-by-file |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Pasting the Hex API write key into a plan, SUMMARY, evidence file, or commit message | Full publish/retire authority over a public auth package, leaked in a **public** repo | Key passes only through `HEX_API_KEY=` in an interactive operator shell. Acceptance: `git log -p` for the milestone contains no string matching a Hex key pattern. Revoke the key at hex.pm after the retire. |
| Merging Dependabot bumps without reviewing the diff because "it's just a version bump" | Supply-chain injection via a compromised release — on a package that *is* the auth layer for its adopters | Tier B/C bumps get a changelog read and a `mix.lock` hash review. The repo already SHA-pins release workflow actions; keep `actions/attest-build-provenance` pinned by SHA after the bump. |
| Bringing Phase 232's composite action inside the supply-chain guards by loosening the guard | The guard stops catching unpinned actions repo-wide | Fail-first: the guard must be demonstrated RED against a deliberately-unpinned fixture before the composite action is added. |
| Publishing 1.5.1 from a HEAD whose `ci-gate` was never actually green | The v1.45 pattern: a release built on an unverified tree, on a security-sensitive package | Publish gated on the captured WS1 green-main evidence at the exact release SHA. |
| Stripping a `# SECURITY:` or threat-model rationale comment while stripping `Phase NN` bookkeeping | Loss of the reasoning that keeps a future editor from removing a defense-in-depth measure | WS3's rule is **remove the bookkeeping token, keep the sentence**. Acceptance: no WS3 diff deletes a whole comment block that contains `security`, `CSRF`, `enumeration`, `timing`, `scope`, or `impersonation` (case-insensitive) — assert this with a grep over the WS3 diff. |
| A stale `.planning/` path shipping in adopter code that hints at internal structure | Minor information disclosure; mostly an embarrassment and a dead link | Already WS3's goal; assert on the *generated app*, not the template. |

---

## UX Pitfalls

"User" here = adopters of the library and future maintainers.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Stripping `Phase NN` by deleting whole comment blocks | Adopters lose the *why* behind generated code they now own — the core promise of the hybrid lib+generator model | Remove the bookkeeping prefix; keep the rationale. "Phase 16: configured `@sigra_org_config` because X" → "Configured `@sigra_org_config` because X". |
| Retiring 1.20.0 with a terse message | Adopters see a warning with no guidance | Use the drafted message: `"Published in error during dev cycle; not a real release — use 1.5.0+"` (≤140 chars). |
| Deleting 39 tags with no note | A future maintainer sees `v1.5` missing next to `v1.5.0` and can't tell whether it was a mistake | The CI non-SemVer `v*` tag guard should carry an explanatory failure message pointing at ADR 003, and ADR 003 should be amended with the deletion date and the delete-list file path. |
| Closing 8 stale PRs silently | Contributors (and future-you) can't tell whether the work was rejected or subsumed | Each close gets a comment: subsumed by / superseded by / obsolete because. Especially #234 and #174, which reference real work. |
| A release whose CHANGELOG is missing the cleanup | Adopters can't tell what changed | The 1.5.1 release should note the template `.planning/` path removal, since it changes generated output. Watch the documented release-please "orphaned Unreleased block" gotcha. |

---

## "Looks Done But Isn't" Checklist

- [ ] **Tag deletion:** looks done when `git tag | wc -l` drops — verify `gh release list` still returns 12 AND `gh api repos/sztheory/sigra/releases --jq '[.[]|select(.draft)]|length'` is `0` AND the surviving tag set equals the 13 SemVer tags + `archive/local-main-pre-235-recovery` by exact set comparison.
- [ ] **Non-SemVer tag guard:** looks done when the workflow exists — verify it FAILS against a pushed test tag `v9.9` (on a scratch remote or via a deliberate red), then delete the test tag.
- [ ] **Hex retire:** looks done when the command exits 0 — verify `retirements` in the API contains `1.20.0` AND (separately, may fail) `latest_stable_version == "1.5.0"` AND a clean-`HEX_HOME` `mix deps.get` on `{:sigra, "~> 1.0"}` locks the real GA.
- [ ] **Release landed:** looks done when release-please's PR merges — verify the Hex API lists the new version and HexDocs for it renders with working "View source" links (i.e. the matching three-component tag exists and was NOT deleted).
- [ ] **Template cleanup:** looks done when `grep -rn '\.planning/' priv/templates/` is 0 — verify a **freshly generated app** is clean AND `mix hex.build`'s tarball is clean AND `test/example/` received the same edits.
- [ ] **Golden re-bless:** looks done when `golden_diff_test` is green — verify the re-bless diff contains only comment lines.
- [ ] **`lib/` doc cleanup:** looks done when greps are 0 — verify `mix docs` emits zero warnings AND `grep -rn '\.planning/' doc/` is 0 AND every surviving `skip_undefined_reference_warnings_on` entry was proven still-needed.
- [ ] **Playwright flake fixed:** looks done on one green run — verify a recorded RED reproduction exists, a named root cause (harness race / DB collision / product race), and n≥20 consecutive greens of that job.
- [ ] **`pages build` fixed:** looks done when the workflow is green once — verify it is green on the next 3 consecutive pushes to `main` (it currently fails on *every* push, so a single green is meaningful but not sufficient).
- [ ] **Dependabot drained:** looks done when the PR list is empty — verify locked versions match PR titles, `mix credo --strict` is clean, and the Playwright bump's baseline-drift count is recorded (even if zero).
- [ ] **Branch/worktree/stash prune:** looks done when the lists are short — verify every pre-prune commit SHA is still `git cat-file -e`-resolvable, the keep-list refs exist, 6 stash archive refs are pushed, and no open PR was auto-closed.
- [ ] **TEST-01/02 supersession:** looks done when the module is deleted and the test is green — verify an ADR records the supersession, the replacement guard has a known-bad fixture, and the guard was demonstrated RED.
- [ ] **Skip-parity guard:** looks done when the manifest is accurate — verify `honest-skip-parity.test.mjs` **exists**, is wired into the prohibitions glob, and `MAINTAINING.md:172-178,231` describe the actual HEAD topology.
- [ ] **Todo triage:** looks done when the count drops — verify each of the 41 has a recorded keep/close/defer with a reason, and that the triage commit touched only `.planning/todos/`.
- [ ] **`ci-gate` green on main:** looks done from one push — verify across consecutive pushes, pulled from the GitHub API, at the final committed HEAD on a clean tree (the SC-5 lesson).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Deleted a release tag | LOW — **if** the backup file exists | `git tag <name> <sha>` from `tags-backup.txt`; `git push origin <name>`; then republish the now-draft GitHub Release from the releases UI. Without the backup, recover the SHA from `gh release view` (GitHub retains `target_commitish`) or from the reflog. |
| GitHub Release became a draft | LOW | Re-push the tag, then publish the draft. Note drafts are hard to enumerate via CLI — use the web releases page. |
| Retired the wrong version | LOW | `mix hex.retire sigra <version> --unretire` with the write key. Publicly visible in the interim. |
| Retire didn't move `latest_stable_version` | N/A — not a failure to recover from | Record it as a finding; keep the pinned install line documented; file a todo and (optionally) a hex.pm issue. Do **not** unretire. |
| Re-blessed a golden fixture that hid a real change | MEDIUM | `git revert` the re-bless commit, re-run `golden_diff_test`, read the diff properly, re-bless. Cheap **only** because the re-bless was a separate commit — which is why Pitfall 3 mandates that. |
| Template↔example drift shipped | MEDIUM–HIGH | Diff `priv/templates/sigra.install/` against `test/example/` file-by-file. Historically painful; the real fix is the missing parity guard. |
| Pruned a branch holding unique work | HIGH if `gc` has run, LOW otherwise | `git reflog` on the deleted ref if within the expiry window; otherwise recover from a contributor clone or from GitHub (`gh api repos/.../commits/<sha>` still resolves for a while). Prevention (archive refs) is dramatically cheaper. |
| Dropped a stash with unique work | HIGH | `git fsck --unreachable` for dangling commits, before gc. Materializing stashes as refs first makes this unnecessary. |
| Auto-closed a PR by deleting its base | LOW | Re-push the base branch, reopen the PR. Comments/reviews are preserved. |
| Renamed a required CI job | LOW once diagnosed, HIGH to diagnose | Rename back, or update the ruleset. Symptom is a PR stuck "waiting for status" with no failing check. |
| Playwright bump invalidated baselines | MEDIUM | Recapture CI-native on ubuntu with canary slugs preserved; human-review the drift set. Do **not** recapture on darwin. |
| Published a release from an unverified tree | HIGH — cannot unpublish post-grace-window | Publish a fixed patch and retire the bad one. This is why the publish must be gated on the green-main evidence. |

---

## Pitfall-to-Phase Mapping

Priority = likelihood × blast radius. Published-artifact and adopter-resolution impact ranked highest.

| # | Pitfall | Priority | Workstream / Phase | Verification |
|---|---------|----------|--------------------|--------------|
| 2 | Hex retire doesn't do what's assumed | **P0** | WS2 — retire phase (operator-gated) | `retirements` contains `1.20.0`; separately, `latest_stable_version` + clean-`HEX_HOME` `mix deps.get` proof |
| 1 | Glob tag deletion eats release tags / drafts Releases | **P0** | WS2 — tag phase (runs first) | Explicit allowlist; empty `comm -12` against `gh release list`; 12 Releases and 0 drafts post-delete; exact surviving-tag set |
| 10 | Done-from-a-tidy-diff | **P0** | All WS + milestone close | One live-external-observation criterion per phase; close-out re-audit from primary sources |
| 7 | Retry-wrapping the flake | **P0** | WS1 — flake phase (runs first) | Recorded RED reproduction; named root cause; n≥20 consecutive greens; mechanized no-retry/no-sleep prohibition |
| 3 | Template edit cascade (golden / example / tarball) | **P1** | WS3 — templates phase | Fresh-generated app clean; tarball clean; separate re-bless commit with comment-lines-only diff; per-file example parity |
| 9 | Second dishonest guard in WS6 | **P1** | WS6 — (a) supersession ADR, (b) skip-parity guard | Every guard demonstrated RED against a committed known-bad fixture; ADR 004 recorded |
| 6 | Deleting a PR's base branch | **P1** | WS5 before WS4 | Prune exclusion derived from `gh pr list` head+base; no PR auto-closed |
| 5 | Compound reachability loss | **P1** | WS4 — single sequenced phase | Keep-list survives; every pre-prune SHA resolvable; 6 stash archive refs pushed; no `git gc` |
| 8 | Batch Dependabot merge / Playwright browser drift | **P1** | WS5 — tiered; Tier C own phase, after WS1 | Locked versions match titles; browser revs recorded; drift count recorded; canary slugs preserved; `mix credo --strict` clean |
| 4 | ExDoc autolink / suppression-list rot | **P2** | WS3 — `lib/` phase | `mix docs` zero warnings; `grep '.planning/' doc/` = 0; each suppression entry proven still-needed |
| 11 | Renamed CI job breaks a required context | **P2** | WS3 scope boundary (all phases) | `git diff -- .github/ \| grep '^\+.*name:'` empty |
| 12 | Scope creep | **P2** | Roadmap-level guardrail | Todo-triage diff touches only `.planning/todos/`; found-while-cleaning → new todo, not a fix; out-of-scope list restated per phase |

**Recommended phase ordering (236+), driven by the dependency graph above:**

1. **WS1 flake root-cause** — must precede the release (release-please is gated on `ci-gate`) and must precede the Dependabot merges (attribution).
2. **WS1 `pages build` + issue #231 + green-main evidence capture.**
3. **WS2 tag deletion + non-SemVer `v*` CI guard** — before branch pruning, so tag reachability is checked against the full branch set.
4. **WS2 Hex retire (operator-gated) + adopter-resolution proof + land the 1.5.1 release** — after WS1's green-main evidence exists.
5. **WS3 `lib/` doc surface** (low coupling) **then WS3 `priv/templates/` surface** (high coupling; needs the golden + example protocol).
6. **WS6 dishonest-debt retirement** — independent; can run parallel to WS3.
7. **WS5 PR drain, tiered** (Tier A/B, then Tier C Playwright as its own phase) **+ todo triage.**
8. **WS4 git-state prune** — last, so no open PR's head or base is a candidate.

---

## Sources

- **Repo-native evidence (HIGH, verified live 2026-09-15):** `git tag`, `git rev-list`/`merge-base` reachability sweep, `gh release list`, `gh pr list --json headRefName,baseRefName`, `git stash list`, `git worktree list`, `git ls-remote --heads`, `mix.exs` (`docs`, `package`), `test/sigra/install/golden_diff_test.exs`, `find test/fixtures/install_golden`, `grep` sweeps over `lib/` + `priv/templates/`, `.github/workflows/ci.yml`.
- **`https://hex.pm/api/packages/sigra`** — live package state: `latest_stable_version=1.20.0`, `retirements={}`, 13 published releases. (HIGH, verified)
- **[`mix hex.retire` docs](https://hex.hexdocs.pm/Mix.Tasks.Hex.Retire.html)** — reasons (`renamed|deprecated|security|invalid|other`), `--message` ≤140 chars, `--unretire` reverses, and the definitive line: *"A retired package is still resolvable and usable but it will be flagged as retired in the repository and a message will be displayed to users when they use the package."* (HIGH, verified)
- **[Hex.pm FAQ](https://hex.pm/docs/faq) / [Dependency policies](https://hex.pm/docs/dependency-policies)** — retired versions remain resolvable; `HEX_IGNORE_RETIREMENTS` override; retirement-reason-based blocking is an org policy feature, not default resolver behavior. (MEDIUM — `latest_stable_version` recomputation after retirement is **not documented anywhere**; this is the milestone's genuine unknown.)
- **GitHub tag/release deletion behavior** — [community discussion #7008](https://github.com/orgs/community/discussions/7008), [hub#2435](https://github.com/mislav/hub/issues/2435), [scivision guide](https://www.scivision.dev/github-delete-release-tag/): deleting the tag converts the Release to an untagged draft, hidden from the public page and awkward to enumerate; re-pushing the tag allows republishing. (HIGH, corroborated across three sources)
- **[Playwright release notes](https://playwright.dev/docs/release-notes)** + [1.61/1.62 adoption guide](https://qaskills.sh/blog/playwright-1-61-whats-new-adoption-guide) — 1.60 (May 2026), 1.61 (Jun 2026, WebAuthn passkeys, "no breaking changes"), 1.62 (Jul 2026, WebP visual comparisons, new component-testing model, isolated retries). No announced snapshot-format break; bundled-browser rendering drift is the unannounced risk. (MEDIUM — no release note confirms or denies baseline invalidation; must be measured empirically.)
- **`.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`** — the tag-derived-publish footgun that created the phantom `1.20.0`; guardrails 1–3. (HIGH)
- **`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`** — the Hex 2.5 OAuth-scope blocker and the `HEX_API_KEY` web-key workaround. (HIGH)
- **`.planning/todos/pending/2026-09-15-test-01-02-timing-machinery-orphaned.md`** — the guard-blesses-the-regression pattern, with the exact rewritten assertions. (HIGH)
- **`.planning/todos/pending/2026-09-15-honest-skip-parity-guard-does-not-exist.md`** — the manifest citing a non-existent guard and the rotted `MAINTAINING.md` leg. (HIGH)
- **`.planning/PROJECT.md`** — v1.48 brief, six workstreams, out-of-scope list; v1.45/v1.47 close-out history. (HIGH)

---
*Pitfalls research for: large housekeeping / release-readiness pass on a mature public Elixir+Hex library*
*Researched: 2026-09-15*
