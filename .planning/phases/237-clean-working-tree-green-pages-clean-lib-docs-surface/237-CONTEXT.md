---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
source: orchestrator-decisions
scope: complete
---

# Phase 237 Context — Decisions

Authority: the user granted standing autonomy for this milestone ("continue on auto
follow ur recommendations as far as possible without my intervention"). The five open
questions raised by `237-RESEARCH.md` are answered here so the planner plans against
settled ground. Every decision below is traceable to a measurement in RESEARCH.md, not
to the ROADMAP.md prose — **the roadmap entry for this phase predates Phase 236's merge
and is stale in six places.** Where roadmap wording and a measurement conflict, the
measurement wins and the divergence is recorded as a D-NN below.

## D-01: Docs-surface scope is a COMMITTED NAMED LIST, not the whole 348-hit surface

The roadmap says the `lib/` doc surface is "clean starting with `lib/sigra/audit.ex:5`",
implying a small tail. Measurement: **348 hits / 259 sites / 71 files.** But only **4**
are dead `.planning/` paths — the rest are benign phase mentions in prose.

**In scope for 237 — exactly these 4 dead `.planning/` paths, all inside `@moduledoc`:**
- `lib/sigra/audit.ex:5`
- `lib/sigra/testing.ex:1274`
- `lib/mix/tasks/rebless_golden.ex:11`
- `lib/mix/tasks/rebless_golden.ex:13`

**Out of scope, handed to Phase 241's `p18` ratchet:** the residual ~344 benign phase
mentions. The roadmap already defines `p18` as a monotonic-decrease ratchet where "zero
is not the target", so this is the mechanism that already exists for exactly this
residual. 237 must record the measured baseline count so 241 has a number to ratchet from.

**Rationale:** a phase that tries to rewrite 259 doc sites is a phase that will be
verified by counting, and count-only acceptance is rejected in this repo. Four named
paths can each be verified individually.

## D-02: Tracked `.log` and `.png` under `.planning/` are KEPT

REPO-01 asks for tracked `.log`/screenshot artifacts to be resolved. Measurement: exactly
one `.log` and one `.png` are tracked, and **both live under `.planning/`** — which
collides head-on with this phase's own Out-of-Scope line "no pruning `.planning/` from the
repo".

**Decision: keep both. The Out-of-Scope fence wins.** The phase records this as a
deliberate, named exception rather than silently leaving it unaddressed — REPO-01 is
satisfied by "no tracked artifacts *outside* `.planning/`", which is true today.

## D-03: Fix the 4 dead guide links here; retire the 2 skip entries they justify

Measured: all 9 `skip_undefined_reference_warnings_on` entries in `mix.exs` are
**load-bearing** — emptying the list produced 14 warnings covering all 9. Zero are dead.
So the roadmap's "prove each load-bearing by remove-and-retest" is already satisfied, and
a naive prune would be vacuous.

However, 4 of those 14 warnings are **dead `.planning/` links in published HexDocs
extras** — real user-visible rot:
- `guides/introduction/upgrading-to-v1.10.md:5` and `:9`
- `guides/introduction/upgrading-to-v1.11.md:7`
(targets `v1.10-ADOPTER-SCOPE.md`, `v1.11-TRIAGE.md`, `milestones/v1.9-ROADMAP.md` — none exist)

**Decision: fix those 3 lines, then remove the 2 skip entries they were propping up, and
re-run `mix docs` to prove the removal stays warning-free.** This is the only non-vacuous
prune available, and it is the difference between "we proved the list is load-bearing" and
"we made the list smaller because the underlying rot is gone".

Also: the comment at `mix.exs:189-191` claiming those paths are "intentionally relative"
is **false** and must be corrected or deleted — a comment that misdescribes its own code
is the same defect class this milestone exists to remove.

## D-04: SC-5 is an in-plan diff check, and the token it searches for must CHANGE

**`# SECURITY:` occurs ZERO times in this repo.** Independently re-verified by the
orchestrator with a positive control (`rg -c 'defmodule' lib/sigra/audit.ex` → 1, so the
search machinery works; `rg -n '# SECURITY:'` → no output).

A guard that greps for the literal `# SECURITY:` **can never fire.** It is precisely the
"green gate that verified nothing" pattern this milestone is named for. Both SC-5 here and
Phase 239's SC-5 inherit this defect.

**Decision:** SC-5's subject is the regex `security|CSRF|enumeration|timing|scope|impersonation`
over `#`-comment lines in `lib/` — **52 matching lines today**. The check is:
> the phase diff deletes no line matching that regex.

It runs **in-plan** against the phase's own diff (Phase 241 owns the durable `p18` guard;
237 must not build a second one). **The check must be demonstrated RED** against a
deliberately-mutated fixture before it is accepted green — a negative result is not
evidence until it has a positive control.

**Highest-risk collateral sites**, named so the planner can guard them explicitly (22
files carry both a bookkeeping hit and a security comment):
- `lib/sigra/auth.ex:1060` — timing
- `lib/sigra/mfa.ex:1008` — replay
- `lib/sigra/session_store.ex:72-77` — the whole authz note is phrased *around* "Phase 14",
  so the bookkeeping token cannot be deleted without rewriting the sentence. Rewrite, never strip.

**File a todo** to correct Phase 239's SC-5 wording too — it carries the same dead literal.

## D-05: `doc/llms.txt` is refreshed and committed in this phase

Measured: the committed `doc/llms.txt` is **stale** — header says `Sigra v1.4.0` while
`mix.exs` is at `1.5.0`, and it is missing `Sigra.Branding.Contrast` from PR #238.
Consequence: **running `mix docs` on a fresh clone immediately dirties the tree**, which
directly falsifies SC-1's clean-tree claim.

**Decision: regenerate and commit it here.** A clean-tree criterion that a single `mix docs`
breaks is not a clean tree. It will go stale again at Phase 242's 1.5.1 cut — that is
acceptable and expected; the durable fix is a drift check, which is **filed as a todo**,
not built here (it belongs with 242's release lane).

## D-06: The `.gitignore` negation form in SC-1 is WRONG AS WRITTEN

SC-1 specifies a `!doc/llms.txt` negation. **Git cannot re-include a file beneath an
excluded directory** — empirically falsified in a throwaway repo this session: `/doc/`
plus `!doc/llms.txt` leaves the file ignored.

**The working form is `/doc/*` plus `!/doc/llms.txt`.** The plan uses the working form.

Verification must use `git check-ignore -q --no-index doc/llms.txt` and expect **exit 1**.
Without `--no-index`, `git check-ignore` never reports a *tracked* path as ignored, so the
check passes for the wrong reason — another gate that would verify nothing.

Untracked inventory is otherwise smaller than the roadmap claims: **only `.gsd/` is
untracked** (268 files, 660M). `.planning/.gsd-ws-arg` **does not exist**. `sigra-*.tar` is
**already ignored**. The fix is one line: `/.gsd/`.

## D-07: Pages — the root cause is the `source` setting, not `code-walkthrough.md:174`

Re-verified live by the orchestrator: `gh api repos/szTheory/sigra/pages` →
`{"build_type":"legacy","source":{"branch":"main","path":"/"},"status":"errored"}`.

The Liquid crash at `guides/introduction/code-walkthrough.md:174` is real — Liquid parses
the `{%` inside the Elixir sigil `#{%{routing_source: ...}}` as a tag even inside a code
fence — **but it is a symptom.** It only happens because Pages is pointed at `main`, where
it tries to Jekyll-build the entire source repo.

`origin/gh-pages` **already exists** and **already contains a root `.nojekyll`** (verified:
`git ls-tree origin/gh-pages` → `.nojekyll`, `index.html`, `runs`), and its publisher runs
green daily. **SC-2's ".nojekyll backstop" is already satisfied on the publish branch.**

**Decision: repoint Pages at `gh-pages`.** Exact call:

```
gh api repos/szTheory/sigra/pages --method PUT --input - <<<'{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}'
```

Local `gh` authenticates as `szTheory` with `repo` scope and
`gh api repos/szTheory/sigra --jq .permissions` → `admin: true`, so this is expected to
succeed from this session rather than requiring a human in the GitHub UI. **It remains an
outward-facing repo-settings change and is called out as such in the plan.** It is
reversible by re-`PUT`ting the previous value, which the plan records before changing it.

**Explicitly REJECTED: adding a root `.nojekyll` to `main`.** That would publish the entire
repository root — `CLAUDE.md`, `AGENTS.md`, `brandbook/`, `.planning/` — as a public static
site. For a public repo mid-way through sanitizing adopter material out of its history,
that is the wrong direction.

The Liquid-crashing line should still be fixed opportunistically (it is one escaped
sequence) so the failure cannot recur if Pages is ever repointed at `main`, but the phase
does **not** depend on it.

## D-08: SC-1 is verified by a literal fresh clone, not by a new CI job

Measured: **no whole-repo clean-tree CI check exists** — every `git status --porcelain` in
CI is scoped with `-- "$SNAP_DIR"`.

**Decision: verify SC-1 by actually running `git clone` into a temp dir and inspecting
`git status` there.** Do not build a CI job for it. The criterion says "a fresh `git clone`
reports a clean `git status`" — the honest verification is to perform that clone. A CI job
that approximates it is a proxy, and proxies are what this milestone is retiring.

`scripts/ci/launch-pack-contract.sh` has **no workflow caller** (known as FUT-04). SC-1
says its consumers pass "under `mix ci`" — the script does **not** run there. Run it
manually and record the result; do not claim `mix ci` covered it.

## Phase-boundary fences (do not drift into these)

- Repairing `ensure-github-pages-legacy-branch.sh` to **fail loudly on its swallowed 403**,
  and closing issue #231 → **Phase 240**.
- The `p18` docs-surface ratchet guard → **Phase 241**.
- `priv/templates/.../organizations.ex:59`, the 5th dead `.planning/` path → **Phase 239**
  (the `priv/templates/` sweep).
- A `doc/llms.txt` staleness drift check → **todo, lands with Phase 242's release lane**.

## Standing constraints (inherited, non-negotiable)

- **sigra is a public repo.** No adopter or personal identity, no org names, no adopter
  repo/PR references, no local filesystem paths, no brand hex values in any artifact.
- **A search returning nothing is not evidence of absence until it has a positive control.**
  Every "no matches" claim in this phase's evidence must be accompanied by a control
  proving the search ran.
- **Count-only acceptance is rejected.** Each named item is verified individually.
- No `git gc`, `git reflog expire`, or `--prune=now` anywhere in this phase.
- Reach `git worktree list` cleanliness via `git worktree prune` — never `rm -rf` first.
  Measured: 6 worktrees = 1 live + 5 stale; the null-HEAD entry is a `/private/tmp/` path.
- 6 stashes exist; **no stash-archive refs exist on `origin` today** (control: 343 remote
  refs enumerated, `refs/heads/main` matched). They must be pushed as refs and proven
  `git cat-file -e`-resolvable **before** `git stash list` is emptied. Push first, verify,
  then drop — never the reverse.
