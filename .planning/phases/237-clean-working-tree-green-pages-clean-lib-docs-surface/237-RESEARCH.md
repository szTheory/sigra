# Phase 237: Clean Working Tree, Green Pages, Clean `lib/` Docs Surface — Research

**Researched:** 2026-09-16
**Domain:** Repo hygiene forensics — gitignore semantics, GitHub Pages (legacy Jekyll) configuration, git object state (stashes/worktrees), ExDoc warning surface
**Confidence:** HIGH (every claim below is a live measurement taken this session against `origin/main` @ `b6e889c4`; the few `[ASSUMED]` items are called out explicitly)
**Measurement HEAD:** `b6e889c4` (`Phase 236: fix the generated-admin audit URL flake (product race in LiveView unload()) (#242)`), branch `main`

> **This is a forensic phase.** The ROADMAP entry was written before Phase 236 merged. Everything below was **re-measured live**. Where the roadmap's description and reality disagree, the disagreement is flagged in **bold** and the measurement wins.

---

## Summary

Phase 237 is five loosely-coupled cleanup jobs sharing one theme. Four of the five are **smaller than the roadmap implies**; one (the `lib/` docs sweep) is **an order of magnitude larger**.

The single most important finding: **`mix docs --warnings-as-errors` is already a gate** in three workflows (`ci.yml:635`, `release-please.yml:221`, `hex-publish.yml:153`), and `mix docs` is **already warning-free at HEAD**. SURF-02's "make it a gate" half is already done. What remains is the skip-list prune — and an exhaustive remove-and-retest (run this session) proves **all 9 entries are currently load-bearing, zero are dead**. The prune is only achievable by *fixing the underlying references*, of which 4 are dead `.planning/` links **in published HexDocs extras** (`upgrading-to-v1.10.md`, `upgrading-to-v1.11.md`) that the roadmap did not count.

The second most important finding: **the GitHub Pages fix is a single `gh api --method PUT` that the operator's own local `gh` token can very likely execute**, because `gh auth status` shows scope `repo` on account `szTheory` and `gh api repos/szTheory/sigra --jq .permissions` returns `admin: true`. The `.nojekyll` backstop SC-2 asks for **already exists on the `gh-pages` branch root**. The only blocker is the Pages `source` still pointing at `main /`.

The third: the `lib/` doc-attribute bookkeeping surface is **348 token occurrences across 259 distinct `file:line` sites in 71 files** — not "starting with `lib/sigra/audit.ex:5`" as a small list. `lib/sigra/organizations.ex` alone has 25. This must be scoped explicitly or the phase will not land.

**Primary recommendation:** Split Phase 237 into 5 independent plans (no shared files), sequence nothing, and **descope the `lib/` doc sweep to a named, enumerated file list committed in the plan** rather than "clean everything" — the full surface is 71 files and will not fit alongside four other jobs.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Untracked-artifact suppression | Repo config (`.gitignore`) | — | Only git's ignore machinery can make `git status` clean without deleting |
| `doc/llms.txt` tracked-while-ignored | Repo config (`.gitignore`) | Test suite (`phase_148/149`, `launch-pack-contract.sh`) | The negation is a gitignore-pattern problem; the consumers are the regression guard |
| GitHub Pages build source | GitHub repo settings (REST API) | Repo file (`.nojekyll`) | `build_type`/`source` live only in repo settings; the file is a fallback |
| Stash/worktree materialization | Local git object DB → `origin` refs | — | Stashes are local-only objects; durability requires a push |
| HexDocs rendered surface | `lib/` source doc attributes | `mix.exs` `docs/0` config | ExDoc renders `@moduledoc`/`@doc` verbatim; `mix.exs` only suppresses warnings |
| Docs-warning gate | CI (`ci.yml:635` + 2 release workflows) | — | **Already exists — do not rebuild** |

---

## A. Untracked / Ignored Artifact Inventory `[VERIFIED: live]`

### A.1 What is untracked on `main` today

`git status --porcelain --untracked-files=all` returns **one top-level offender**: `.gsd/`.

```
?? .gsd/dispatch-isolation-sentinel.json
?? .gsd/scratch/…              (267 more files)
```

`find .gsd -type f | wc -l` → **268 files**; `du -sh .gsd` → **660M**. Contents: a
`dispatch-isolation-sentinel.json` plus `scratch/` holding Phase-236 CI artifacts,
Playwright traces (`trace.zip`), `.webm` videos, PNGs, and `mix ci` logs.

**Nothing else is untracked.** `.planning/.gsd-ws-arg` does **not exist**
(`ls .planning/.gsd-ws-arg` → *No such file or directory*). **The roadmap's mention of it is stale.**

### A.2 `.gitignore` current state `[VERIFIED: .gitignore, 68 lines, read this session]`

- `.gsd/` is **absent** from `.gitignore` — verbatim check: `grep -n "gsd" .gitignore` → rc=1 (no match). Positive control: `grep -n "doc" .gitignore` → matched lines 10 and 11, so the grep machinery works.
- `sigra-*.tar` **is already ignored** (`.gitignore` line: `sigra-*.tar`). Two tarballs exist on disk (`sigra-0.1.0.tar`, `sigra-0.2.0.tar`, Apr 2026) but **do not dirty `git status`**. They are local cruft, not a `git status` problem. **The roadmap over-states this item.**
- `/doc/` is ignored at line 11.
- `.git/info/exclude` adds only `**/.claude/*` runtime paths and `/prompts/ARCHITECTURE-CODE-WALKTHROUGH-DNA.md`. `git config core.excludesfile` is unset.

### A.3 Tracked artifact files `[VERIFIED: git ls-files]`

| Path | Kind | Note |
|------|------|------|
| `.planning/milestones/v1.44-phases/216-harness-foundation-award-gradient/216-09-harness-evidence.log` | tracked `.log` | The **only** tracked `.log` in the repo |
| `.planning/uat-screenshots/4.1-sessions-live.png` | tracked screenshot | The only tracked PNG outside `test/example/priv/playwright`, `brandbook`, `guides/assets`, `priv/static` (control: 120 tracked `.png` total) |
| — | tracked `.tar` | **none** (`git ls-files \| grep '\.tar$'` → rc=1) |

⚠️ **Scope conflict the planner must resolve:** both tracked artifacts live under `.planning/`, and Standing Constraint 6 / the Out-of-Scope table bind "**no pruning `.planning/` from the repo**". REPO-01 says "tracked `.log`/screenshot artifacts are resolved." These two read as contradictory. Recommended resolution: **keep both files** (they are committed *evidence*, referenced by phase artifacts) and record the decision explicitly; they do not affect `git status` cleanliness, which is what SC-1 actually asserts.

### A.4 Recommended `.gitignore` addition

```gitignore
# GSD agent runtime + scratch (never ship; 660M of CI artifacts and traces).
/.gsd/
```

---

## B. `doc/llms.txt` — the tracked-while-ignored conflict `[VERIFIED: live]`

### B.1 Current state

- `git ls-files doc/llms.txt` → `doc/llms.txt` (**tracked**), file present, 25768 bytes.
- `git check-ignore -q doc/llms.txt` → **rc=1, NOT ignored** — because git's ignore machinery does not apply to tracked paths.
- `git check-ignore -v --no-index doc/llms.txt` → `.gitignore:11:/doc/	doc/llms.txt` — **it matches the `/doc/` rule**; only its tracked status protects it.
- No `!doc/llms.txt` negation exists anywhere (`grep -n "llms" .gitignore` → rc=1; positive control `grep -n "doc" .gitignore` matched).

### B.2 🚩 CRITICAL: the naive `!doc/llms.txt` negation **does not work**

Git cannot re-include a file whose **parent directory** is excluded. `/doc/` excludes the
directory itself, so git never descends into it and the negation is unreachable.
**Empirically proven this session** in a throwaway repo under `mktemp -d`:

| `.gitignore` content | `doc/llms.txt` | `doc/x.html` |
|---|---|---|
| `/doc/`<br>`!doc/llms.txt` | **IGNORED** ❌ (negation has no effect) | IGNORED ✅ |
| `/doc/*`<br>`!/doc/llms.txt` | **NOT ignored** ✅ | IGNORED ✅ |
| `/doc/`<br>`!/doc/`<br>`/doc/*`<br>`!/doc/llms.txt` | **NOT ignored** ✅ | IGNORED ✅ |

**Prescription — use the directory-glob form, not the literal SC-1 wording:**

```gitignore
# Where third-party dependencies like ExDoc output generated docs.
# `/doc/*` (not `/doc/`) so the negation below is reachable — git cannot
# re-include a file whose parent *directory* is excluded.
/doc/*
!/doc/llms.txt
```

SC-1 says "`!doc/llms.txt` negation". Taken literally that is a **broken** fix that will silently
re-ignore the file. The planner should record the two-line form as the satisfying implementation
and note the SC wording as shorthand. `[VERIFIED: empirical git check-ignore, this session]`

### B.2b 🚩 The committed `doc/llms.txt` is STALE — running `mix docs` dirties the tree

Discovered accidentally: my `mix docs` runs modified the tracked `doc/llms.txt`.
`git diff doc/llms.txt` produced **exactly this**, verbatim:

```diff
-# Sigra v1.4.0 - Table of Contents
+# Sigra v1.5.0 - Table of Contents
@@
 - [Sigra.Branding](Sigra.Branding.md): Brand profile resolution for generated auth UI and transactional emails.
+- [Sigra.Branding.Contrast](Sigra.Branding.Contrast.md): Colour maths for resolving brand tokens against a theme surface.
```

(I restored it with `git checkout -- doc/llms.txt`; the tree is clean again.)

Two drifts: the **version header is a release behind** (`v1.4.0` vs `mix.exs`'s 1.5.0) and the
index is **missing `Sigra.Branding.Contrast`**, the module added by PR #238
(`fb11c8d3 fix(branding): add dark_logo_url and derive the dark accent by contrast`).
`[VERIFIED: live git diff, this session]`

**Why this matters to SC-1.** SC-1 asserts a fresh clone reports a clean `git status`. That is true
today *as long as nobody runs `mix docs`* — and `mix docs` is the first thing a maintainer runs
when touching docs, and is exactly what this phase does. The moment it runs, a tracked file is
dirty. The planner must pick and record one of:

| Option | Effect |
|---|---|
| **(1) Regenerate and commit `doc/llms.txt` as part of this phase** | Clean tree survives a `mix docs`. But it re-drifts on the next version bump (Phase 242 cuts 1.5.1) and on every new public module. |
| **(2) Untrack it, relying on the fact that `mix docs` regenerates it** | ❌ **Breaks all three consumers** (§B.3) on a fresh clone, which is exactly what REPO-02 forbids. |
| **(3) Commit it here AND note the recurring drift as a todo** (e.g. a CI `mix docs` + `git diff --exit-code doc/llms.txt` drift check) | **Recommended.** Matches the milestone's "found-while-cleaning → a new todo, never an in-phase fix" constraint, while leaving the tree clean at this HEAD. |

Note the interaction with **Phase 242**, which publishes 1.5.1: whatever is committed here will be
stale again the moment the version bumps, unless a drift check or a release-lane regeneration step
is filed. File it as a todo; do not build it here.

### B.3 The three live consumers `[VERIFIED: rg, all three read the working-tree file]`

| Consumer | Lines | What it does |
|---|---|---|
| `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` | `:21` `llms = read!("doc/llms.txt")`; asserts at `:35`, `:36`, `:37` | Asserts three exact index entries exist in `doc/llms.txt` (`demo-showcase.md`, `troubleshooting-install.md`, and the evaluator-funnel sentence `"Evaluating first? Start with https://hexdocs.pm/sigra/demo-showcase.html."`) |
| `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` | `:69` `read!("doc/llms.txt")`, `:70` `read!("llms.txt")`; asserts `:100`, `:103`–`:105`, `:117`, `:134`, `:136` | Asserts every catalogued entry appears in `doc/llms.txt`; asserts the **root** `llms.txt` stays pointer-only (`=~ "doc/llms.txt"`, `=~ "https://hexdocs.pm/sigra/llms.txt"`, `refute =~ "## Pages"`) |
| `scripts/ci/launch-pack-contract.sh` | `:18` `LLMS="${ROOT}/doc/llms.txt"`, `:19` `ROOT_LLMS="${ROOT}/llms.txt"`, `:105`–`:109` | `require_text` on the root pointer; hard-fails with `"FAIL: root llms.txt must stay pointer-only and must not define ## Pages"` |

All three read the **on-disk** file, so deletion breaks all three; the negation keeps them green.
There is also a **separate root-level `llms.txt`** (tracked, 6 lines, pointer-only) — do not confuse
the two. `[VERIFIED: ./llms.txt:1-6]`

⚠️ Note `scripts/ci/launch-pack-contract.sh` **has no workflow caller** — this is already known and
filed for Phase 243 as **FUT-04**. SC-1 says these consumers must pass "under `mix ci`"; the two
ExUnit tests do run under `mix ci`, the shell script does not run anywhere. The plan should verify
the script manually (`bash scripts/ci/launch-pack-contract.sh`) and say so.

---

## C. GitHub Pages `[VERIFIED: live GitHub API, 2026-09-16]`

### C.1 Raw API state

```bash
$ gh api repos/szTheory/sigra/pages
{"url":"https://api.github.com/repos/szTheory/sigra/pages","status":"errored","cname":null,
 "custom_404":false,"html_url":"https://sztheory.github.io/sigra/","build_type":"legacy",
 "source":{"branch":"main","path":"/"},"public":true,"protected_domain_state":null,
 "pending_domain_unverified_at":null,"https_enforced":true}
```

- `status`: **`errored`**
- `build_type`: **`legacy`** → `.nojekyll` backstop **is** applicable (it only applies to legacy branch-sourced Pages, never to `workflow` build type)
- `source`: **`{"branch":"main","path":"/"}`** ← **this is the root cause**

### C.2 Build history — 8 consecutive failures

```
completed  failure  pages build and deployment  main  35052016058  29s   2026-09-16T03:29:54Z
completed  failure  …                           main  35004418988  39s   2026-09-15T17:57:03Z
completed  failure  …                           main  34997700744  1m33s 2026-09-15T16:52:15Z
completed  failure  …                           main  34996935202  30s   2026-09-15T16:44:52Z
completed  failure  …                           main  34990228376  38s   2026-09-15T15:42:23Z
completed  failure  …                           main  34776807148  33s   2026-09-13T19:09:08Z
completed  failure  …                           main  34775035794  31s   2026-09-13T18:34:17Z
completed  failure  …                           main  34298915803  33s   2026-09-09T01:22:15Z
```

### C.3 The actual fatal error (run `35052016058`, `--log-failed`)

```
Liquid Exception: Liquid syntax error (line 174): Tag '{%' was not properly terminated
  with regexp: /\%\}/ in guides/introduction/code-walkthrough.md
/usr/local/bundle/gems/liquid-4.0.4/lib/liquid/block_body.rb:132:in `raise_missing_tag_terminator'
```

Environment: `github-pages v232`, `jekyll v3.10.0`, theme `jekyll-theme-primer`, `Configuration file: none`.

**Why it crashes — `guides/introduction/code-walkthrough.md:174` verbatim:**

```
      |> redirect(to: ~p"/organizations/#{slug}/sso?#{%{routing_source: "local_policy"}}")
```

The Elixir sigil interpolation `#{%{routing_source: …}}` contains the two-character sequence
**`{%`**. Jekyll/Liquid preprocesses the **entire file including fenced code blocks** (Liquid runs
before Markdown), so it reads `{%` as an opening Liquid tag and never finds a closing `%}`. This is
a hard `Liquid::SyntaxError`, which aborts the whole site build. `[VERIFIED: run 35052016058 log]`

Three **non-fatal** Liquid warnings also appear, all in `MAINTAINING.md` (lines 174, 193, 396 —
`{{ !cancelled() … }}` and `{{ secrets.RELEASE_PLEASE_TOKEN || github.token }}` from copied
workflow YAML). These are warnings only and do **not** need fixing for the build to pass, but they
are the same class of hazard.

### C.4 The real fix is the `source` PUT, not the Markdown edit

`.github/workflows/playwright-github-pages.yml` publishes a Playwright report site to a
**`gh-pages`** branch and then calls `scripts/ci/ensure-github-pages-legacy-branch.sh` to point
Pages at it. Measured:

- **`gh-pages` branch exists on `origin`:** `b9ad84b0083bc1660dcb59735e7377d8170ae7ad`
- **`git ls-tree --name-only origin/gh-pages` → `.nojekyll`, `index.html`, `runs`**
  → **SC-2's "root `.nojekyll` backstop" ALREADY EXISTS on the publish branch.** `[VERIFIED: git ls-tree origin/gh-pages]`
- The publisher runs green daily: `34939422390`, `34816257784`, `34743972050`, `34679293472`, `34572120687`, `34447574368` — all `success`, all `schedule` on `main`.
- `scripts/ci/ensure-github-pages-legacy-branch.sh` attempts the PUT and **swallows 403**:

```bash
if echo "${put_out}" | grep -qE '403|Resource not accessible by integration'; then
  echo "…Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source)…" >&2
  exit 0          # ← reports success while the site stays broken
fi
```

The existing todo `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
(front-matter `resolves_phase: 237`) already contains the post-merge confirmation log line:

```
ensure-github-pages-legacy-branch: updating Pages source -> gh-pages / (was: main /)
ensure-github-pages-legacy-branch: Pages API PUT returned 403 …
```

**So: the whole failure chain reduces to one unperformed settings change.** Once `source` becomes
`gh-pages /`, Jekyll never sees `guides/` or `MAINTAINING.md` at all, `.nojekyll` on that branch
bypasses Jekyll entirely, and the build goes green.

### C.5 Operator-only? — **measured answer: probably NOT, and that matters**

| Token | Scopes / perms | Can PUT Pages source? |
|---|---|---|
| Actions default `GITHUB_TOKEN` | `pages: write` declared in the workflow | **No — observed 403 live** (todo log, 2026-07-31) |
| Local `gh` CLI (`szTheory`) | `gist, read:org, read:packages, repo, workflow`; repo perms `{"admin":true,"maintain":true,"pull":true,"push":true,"triage":true}` | **Very likely yes** `[ASSUMED — not executed; this research is read-only]` |

**Exact command the operator would run (NOT run this session — repo-settings mutation is out of a research agent's remit):**

```bash
gh api repos/szTheory/sigra/pages --method PUT --input - <<'JSON'
{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}
JSON

# verify
gh api repos/szTheory/sigra/pages --jq '{status,build_type,source}'
# expect: {"status":"built","build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}

# force a build and confirm the URL serves
gh api repos/szTheory/sigra/pages/builds --method POST
curl -sSI https://sztheory.github.io/sigra/ | head -1   # expect HTTP/2 200
```

Equivalent UI path: **Settings → Pages → Build and deployment → Branch → `gh-pages` / `(root)`**.

> **Planner guidance:** write this as a `checkpoint:human-verify` task with the exact command
> pasted in, **not** as an executable task. Even though the local token almost certainly has the
> rights, an agent flipping repo settings is the wrong default. After the operator step, the
> subsequent verification tasks (API read, curl) are fully automatable.

### C.6 Two competing fixes — the planner must pick one and record it

| Option | Effect | Assessment |
|---|---|---|
| **(A) PUT `source` → `gh-pages /`** | Jekyll never renders repo content; `.nojekyll` already present; Playwright report site is published at the URL — the *intended* design of `playwright-github-pages.yml` | **Recommended.** Matches the existing architecture and the todo's own "Required owner action". |
| **(B) Add root `.nojekyll` to `main`, leave source at `main /`** | Jekyll bypassed; whole repo root published as raw static files | **Not recommended.** Publishes `AGENTS.md`, `CLAUDE.md`, `brandbook/`, `.planning/` links etc. as a public static site. Fixes the red check by publishing *more* internal surface — the opposite of this milestone's thesis. |
| **(C) `{% raw %}`-wrap or edit `code-walkthrough.md:174`** | Removes one crash; the next `{%`-shaped Elixir example re-breaks it | **Not recommended alone.** But worth doing as defence-in-depth *if* (A) is taken, since ExDoc also renders this guide. **Do not** change the Elixir semantics of the snippet. |

⚠️ **SC-2 as written asks for both the PUT and a "root `.nojekyll` backstop" and for
`code-walkthrough.md:174` to "no longer crash the legacy Jekyll builder."** Under option (A),
`code-walkthrough.md` is never rendered by Jekyll at all, so that clause becomes vacuously true.
The planner should state which reading it is satisfying so the verifier does not chase a
now-unreachable code path.

### C.7 Related prior art — do not duplicate

- `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` already guards the publisher's seeds step.
- The "fail loudly on 403" repair of `ensure-github-pages-legacy-branch.sh` is **Phase 240's GREEN-05**, not 237's. Do not do it here.
- Closing issue **#231** and the two todos is **Phase 240 SC-4**. Do not close them here.

---

## D. Git object hygiene `[VERIFIED: live, read-only]`

### D.1 Worktrees — 6 entries, 5 stale

```
$ git worktree list
/Users/jon/projects/sigra                         b6e889c4 [main]                                          ← LIVE
/private/tmp/sigra-chimeway-backport-62ceb46      b8d71e3a [fix/chimeway-opaque-recipient-backport-62ceb46]
/private/tmp/sigra-chimeway-opaque-main           00000000 [fix/chimeway-opaque-recipient-main]            ← NULL HEAD
/private/tmp/sigra-plan35.5RDe7U/candidate        a1f9e34a (detached HEAD)
/private/tmp/sigra-plan36.NlKLPW/candidate        0bf7b8e9 (detached HEAD)
/private/tmp/sigra-plan35.5RDe7U/candidate-final  f179e3af (detached HEAD)
```

`--porcelain` confirms the null entry verbatim:

```
worktree /private/tmp/sigra-chimeway-opaque-main
HEAD 0000000000000000000000000000000000000000
branch refs/heads/fix/chimeway-opaque-recipient-main
```

**5 stale worktrees — matches REPO-03's "5 stale worktrees" exactly.** All 5 live under
`/private/tmp/`, i.e. macOS temp; their directories may already be gone, which is precisely why
`git worktree prune` (never `rm -rf` first) is the prescribed order — pruning first removes the
admin entries cleanly; removing the directory first can leave a locked/orphaned admin record.

Three of the detached ones (`a1f9e34a`, `f179e3af`, `0bf7b8e9`) hold commits. If any is unmerged
work, pruning the worktree does **not** delete the commit — but it does make it reachable only via
reflog, which Standing Constraint / SC-3's "no `git gc`, no `reflog expire`, no `--prune=now`"
exists to protect. Recommend recording all 6 SHAs in a committed pre-prune snapshot (the same
pattern Phase 245 SC-1 uses) before running `git worktree prune`.

### D.2 Stashes — exactly 6, none on `origin`

```
stash@{0}: On gsd/238-generated-auth-runtime-proof-evidence: safety: pre-release workspace snapshot 2026-08-31
stash@{1}: WIP on chore/phase-88-uat-evidence: a93f195 Merge remote-tracking branch 'origin/main' into chore/phase-88-uat-evidence
stash@{2}: On chore/phase-88-uat-evidence: GSD broken unstaged changes from incomplete phases 93-96
stash@{3}: WIP on worktree-agent-abbba1c7: a046e64 docs(17): gap plan 17-09 — close INV-08 cross-tenant IDOR in revoke/3
stash@{4}: WIP on worktree-agent-a2d214b9: b14e490 chore: merge executor worktree (17-06)
stash@{5}: WIP on worktree-agent-a9e38565: 29f4cca fix(16): drop duplicate delegators now injected by use Sigra.Organizations
```

Count = **6** — matches the roadmap. `git stash list | wc -l` → 6.

**No stash-archive refs exist on `origin`.** `git ls-remote origin | grep -iE "stash|archive|safety"` → rc=1 (no match).
Positive control: `git ls-remote origin | grep -c "refs/heads/main"` → **1**, and `git ls-remote origin | wc -l` → **343** total refs, so the query and the grep both work.

The only safety-ish refs currently on `origin` are three branches (not stash refs):

```
ac7d670a…  refs/heads/ci/phase-235-1-evidence
e932a2c8…  refs/heads/ci/phase-235-16-source-complete
f26212cd…  refs/heads/ci/phase-88-provenance
```

Note the roadmap/Phase 245 SC-2 also names `safety/local-main-before-release-cleanup-*` and
`archive/local-main-pre-235-recovery` as safety refs that "survive on `origin`" — **neither is on
`origin` today.** Flag for Phase 245; out of 237's scope but worth the planner's note.

### D.3 Prescribed materialization pattern (not executed)

Each stash is a real commit object. The durable-push pattern:

```bash
# per stash i in 0..5, resolved BEFORE any drop
sha=$(git rev-parse "stash@{$i}")
git push origin "$sha:refs/stash-archive/2026-09-16/stash-$i"
git cat-file -e "$sha^{commit}"      # resolvability assertion
```

Push all 6 **first**, verify all 6 with `git cat-file -e`, **then** `git stash clear`
(or six `git stash drop`). Never the reverse. `[ASSUMED — pattern, not executed here]`

**Do not** `git stash drop` before the push is confirmed on `origin` with `git ls-remote`.

---

## E. HexDocs / `lib/` docs surface `[VERIFIED: live scan + mix docs runs]`

### E.1 The dead `.planning/` paths in `lib/` — exactly 4, all inside `@moduledoc`

`rg -n "\.planning" lib/` (positive control: `rg -c "defmodule" lib/` returned matches, so the search works):

| file:line | Verbatim text | Classification |
|---|---|---|
| `lib/sigra/audit.ex:5` | ``See `.planning/phases/09-audit-logging/09-CONTEXT.md` for the 28 decisions`` / `that shape this module. Summary:` | **(ii) load-bearing prose** — the sentence introduces the bullet list that follows. Rewrite to `"Design summary:"`, keep the bullets. Deleting the whole sentence orphans the list. |
| `lib/sigra/testing.ex:1274` | ``the `deviations` field in`` / ``  `.planning/phases/15-audit-integration/15-02-semantic-workers-credo-PLAN.md` `` / `for the D-31 refinement rationale (the `(repo, fields)` shape from CONTEXT.md would require synthesizing…)` | **(ii) load-bearing** — this is a real API-design rationale under a `## Signature note` heading. Strip the path + `D-31` + `CONTEXT.md`; keep "This helper intentionally takes `(map, keyword)` — NOT `(repo, fields)`" and the parenthetical explanation. |
| `lib/mix/tasks/sigra.fixture.rebless_golden.ex:11` | ``This automates the manual iex-driven runbook in`` / `` `.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-01-…-PLAN.md:953-1025` `` | **(i) pure bookkeeping** — delete the two sentences (`:10-13`) entirely; the rest of the moduledoc stands alone. |
| `lib/mix/tasks/sigra.fixture.rebless_golden.ex:13` | ``and the older runbook in`` / `` `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`. `` | **(i) pure bookkeeping** — same block as above. |

All 4 are confirmed **inside `@moduledoc """ … """`** heredocs → all 4 render on HexDocs today.
`[VERIFIED: lib/sigra/audit.ex:1-20, lib/sigra/testing.ex:1265-1279, lib/mix/tasks/sigra.fixture.rebless_golden.ex:1-14]`

The roadmap's 5th dead `.planning/` path is
`priv/templates/sigra.install/organizations/organizations.ex:59`, which belongs to **Phase 239**.

### E.2 🚩 The full doc-attribute bookkeeping surface is **348 hits / 259 sites / 71 files**

A scan of all 161 `.ex`/`.exs` files under `lib/`, extracting only `@moduledoc`/`@doc`/`@shortdoc`/`@typedoc`
heredoc ranges and matching the token set
`.planning/ | Phase NNN | phase-NN | D-NN | SC-N | REQ-… | Pitfall N | INV-N | *-PLAN.md | *-CONTEXT.md | *-SUMMARY.md`:

- **348 token occurrences**
- **259 distinct `file:line`**
- **71 distinct files**

Token histogram (top): `Phase 14` ×20, `D-07` ×15, `Phase 16` ×15, `D-14` ×13, `D-13` ×12,
`D-08`/`D-03`/`D-09`/`D-05` ×11 each, `D-04` ×10, `D-01`/`D-11` ×9, … `.planning/` ×4.

File histogram (top 15):

| File | Hits |
|---|---|
| `lib/sigra/organizations.ex` | 25 |
| `lib/sigra/admin/components.ex` | 15 |
| `lib/sigra/auth.ex` | 13 |
| `lib/sigra/oauth.ex` | 13 |
| `lib/sigra/audit.ex` | 12 |
| `lib/sigra/audit/forwarders/threadline.ex` | 12 |
| `lib/sigra/mfa.ex` | 11 |
| `lib/sigra/workers/audit_forward.ex` | 11 |
| `lib/sigra/plug/put_active_organization.ex` | 10 |
| `lib/sigra/config.ex` | 9 |
| `lib/sigra/plug/require_membership.ex` | 9 |
| `lib/sigra/organizations/invitations.ex` | 8 |
| `lib/sigra/oauth/callback.ex` | 8 |
| `lib/sigra/account/deletion.ex` | 8 |
| `lib/sigra/scope.ex` | 7 |

Full enumerated hit list (path:line, token, surrounding text) was produced by the scanner and is
reproducible with the script in `<!-- scanner -->` §E.6. Representative samples:

```
lib/sigra/audit.ex:8      [D-01] - Direct `Ecto.Multi` writes (D-01) — **not** telemetry subscribers (D-02)
lib/sigra/auth.ex:1262    [Phase 14] ## Phase 14: organization selector (D-12, D-26, ORG-SCOPE-06)
lib/sigra/auth.ex:1060    [D-38] with a dummy hash operation to match timing (per D-38).
lib/sigra/mfa.ex:1008     [D-41] to prevent replay attacks (D-41).
lib/sigra/session_store.ex:75  [Phase 14] authz — see Phase 14 threat register (T-14-04).
lib/mix/tasks/sigra.install.ex:30  [Phase 11] ## Architecture (Phase 11)
```

Two structural observations the planner needs:

1. **A `## Phase 14: organization selector` heading (`lib/sigra/auth.ex:1262`) is a rendered HexDocs section heading.** Renaming it changes the HexDocs anchor `#phase-14-organization-selector`. Any in-repo or external link to that anchor breaks silently. Grep guides/ and `test/` for the anchor before renaming.
2. **`lib/sigra/config.ex:46,51` hits are NimbleOptions `doc:` strings** inside the schema, not `@doc` attributes (my scanner counted them because they sit inside the surrounding `@moduledoc` range, but they are also independently rendered by `NimbleOptions.docs/1`). They render on HexDocs either way — `"Structured audit logging options (Phase 9). See `Sigra.Audit`."` — so they are in scope, but the edit is to a keyword-list literal, not a heredoc. `[VERIFIED: lib/sigra/config.ex:46,51]`

> **Descope recommendation (strong).** 71 files × careful prose rewrite is not compatible with the
> other four jobs in this phase. Recommend the plan commit an **explicit named file list** — e.g.
> the 4 dead-`.planning/` sites (§E.1) plus the top-N-by-hit-count public-API modules — and file
> the remainder as a todo governed by the **Phase 241 SURF-04 `p18` ratchet**, which the roadmap
> already establishes as the monotonic-decrease mechanism ("zero is explicitly not the v1.48
> target"). Attempting all 71 here will either overrun the phase or produce low-care edits in
> `@doc` prose for a shipped auth library.

### E.3 `mix docs` baseline — **already warning-free, already gated**

```
$ mix docs
Generating docs...
View html docs at "doc/index.html"
View markdown docs at "doc/llms.txt"
EXIT=0
```

`grep -in "warning"` on the full captured log → **0 matches** (positive control: `grep -c "Generating"` → 1, so the log and the grep are both real). `[VERIFIED: live run, this session]`

**`mix docs --warnings-as-errors` is already wired as a gate in three places** — do not add a fourth:

| Location | Line |
|---|---|
| `.github/workflows/ci.yml` | `:635` → `run: mix docs --warnings-as-errors` |
| `.github/workflows/release-please.yml` | `:221` |
| `.github/workflows/hex-publish.yml` | `:153` |

(`scripts/uat/RUNBOOK.md:638` documents it as part of the `library_tests` job.)
`mix.exs` has **no** `warnings_as_errors:` key in `docs/0` — the enforcement is the CLI flag in CI.
So **SURF-02's "as a gate" clause is satisfied at HEAD.** The phase's real SURF-02 work is
§E.1/§E.2 (content) + §E.4 (skip-list prune).

### E.4 `skip_undefined_reference_warnings_on` — **all 9 entries are load-bearing, 0 are dead**

Current list, `mix.exs:192-206` `[VERIFIED: mix.exs:188-206]`:

```elixir
# ExDoc only autolinks extras by basename; maintainer paths under `.planning/`
# are intentionally relative from this guide for repo navigation.
skip_undefined_reference_warnings_on: [
  "guides/introduction/upgrading-to-v1.10.md",
  "guides/introduction/upgrading-to-v1.11.md",
  # Phase 131: hidden Application helpers referenced in moduledocs; suppressed pending
  # a @doc false / @moduledoc false strategy alignment in a future phase.
  "lib/sigra/audit/forwarder.ex",
  "lib/sigra/audit/forwarders.ex",
  "lib/sigra/audit/forwarders/noop.ex",
  "lib/sigra/audit/forwarders/threadline.ex",
  "lib/sigra/workers/audit_forward.ex",
  # Phase 132: recipe files reference hidden Application helpers and the Sigra.Mailer
  # behaviour callback (which is a @callback, not a @doc function).
  "guides/recipes/companion-libs/threadline.md",
  "guides/recipes/companion-libs/mailglass.md"
],
```

(**Note: 9 entries, not the 8 an eyeball count sometimes gives.**)

**Method:** emptied the list to `[]`, ran `mix docs`, captured all warnings, then restored `mix.exs`
from a byte copy and verified with `git diff --exit-code mix.exs` (clean) and `shasum mix.exs`
(`88bd2c24c7f245dd6d057205a0e87365f9813101`, identical before and after). **`mix.exs` is unmodified.**

**Result — 14 warnings, covering all 9 entries:**

| # | Warning | Attributed to | Skip entry it justifies |
|---|---|---|---|
| 1 | `references file "../../.planning/v1.10-ADOPTER-SCOPE.md" but it does not exist` | `guides/introduction/upgrading-to-v1.11.md` | v1.11 ✅ |
| 2 | `references file "../../.planning/v1.10-ADOPTER-SCOPE.md" but it does not exist` | `guides/introduction/upgrading-to-v1.10.md` | v1.10 ✅ |
| 3 | `references file "../../.planning/v1.11-TRIAGE.md" but it does not exist` | `guides/introduction/upgrading-to-v1.11.md` | v1.11 ✅ |
| 4 | `references file "../../.planning/milestones/v1.9-ROADMAP.md" but it does not exist` | `guides/introduction/upgrading-to-v1.10.md` | v1.10 ✅ |
| 5 | `references function "Sigra.Mailer.deliver/3" but it is undefined or private` | `guides/recipes/companion-libs/mailglass.md:104` | mailglass.md ✅ |
| 6 | `"Sigra.Application.maybe_warn_missing_forwarder_deps/0" … hidden` | `guides/recipes/companion-libs/threadline.md:98` | threadline.md ✅ |
| 7 | `"Sigra.Application.attach_forwarders/0" … hidden` | `guides/recipes/companion-libs/threadline.md:107` | threadline.md ✅ |
| 8 | `"Sigra.Audit.Forwarders.dispatch_async/3" … undefined or private` | `lib/sigra/workers/audit_forward.ex:8` | audit_forward.ex ✅ |
| 9 | `"Sigra.Application.attach_forwarders/0" … hidden` | `lib/sigra/audit/forwarders/noop.ex:15` | noop.ex ✅ |
| 10 | `"Sigra.Application.start/2" … hidden` | `lib/sigra/audit/forwarder.ex:53` | forwarder.ex ✅ |
| 11 | `"Sigra.Application.maybe_warn_missing_forwarder_deps/0" … hidden` | `lib/sigra/audit/forwarders/noop.ex:18` | noop.ex ✅ |
| 12 | `"Sigra.Application.attach_forwarders/0" … hidden` | `lib/sigra/audit/forwarder.ex:19` | forwarder.ex ✅ |
| 13 | `"Sigra.Application.attach_forwarders/0" … hidden` | `lib/sigra/audit/forwarders.ex:39` | forwarders.ex ✅ |
| 14 | `"Sigra.Application.attach_forwarders/0" … hidden` | `lib/sigra/audit/forwarders/threadline.ex:19` | forwarders/threadline.ex ✅ |

**Every one of the 9 entries is proven load-bearing by remove-and-retest. None can simply be deleted.**
SC-4 says "every surviving `skip_undefined_reference_warnings_on` entry proven load-bearing by
remove-and-retest" — if the plan performs **zero prune**, the criterion is satisfied by this table
alone (everything survives, everything is proven). That is a legitimate, honest close.

**However, a genuine reduction is available and should be taken:**

Warnings 1–4 are **dead `.planning/` links inside published HexDocs extras** — exactly the SURF-02
class, just in `guides/` rather than `lib/`. The roadmap counted 5 dead `.planning/` paths; this is
**4 more it did not count.**

Verbatim sources `[VERIFIED: rg -n "\.planning" guides/]`:
- `guides/introduction/upgrading-to-v1.10.md:5` — `` For what "first production" is assumed to include in v1.10, see **[v1.10 adopter scope](../../.planning/v1.10-ADOPTER-SCOPE.md)**. ``
- `guides/introduction/upgrading-to-v1.10.md:9` — `` read the archived roadmap **[v1.9 ROADMAP](../../.planning/milestones/v1.9-ROADMAP.md)** ``
- `guides/introduction/upgrading-to-v1.11.md:7` — `` see **[v1.10 adopter scope](../../.planning/v1.10-ADOPTER-SCOPE.md)** and **[Adoption stabilization triage](../../.planning/v1.11-TRIAGE.md)** ``

None of those three target files exist. Fixing the links (remove them, or convert to absolute
`https://github.com/sztheory/sigra/blob/main/…` URLs — the pattern already used at
`guides/introduction/upgrading-to-v1.12.md:7-8` and `intermediate-production-path.md:19`) lets
**2 of the 9 entries be deleted**, leaving 7 — all genuinely about hidden/undefined function refs.

⚠️ Note the `mix.exs:189-191` comment claims those `.planning/` paths are *"intentionally relative
from this guide for repo navigation."* **That rationale is now false** for these three targets — the
files were deleted/archived. Correct the comment along with the links.

### E.5 `.planning/` references in `guides/` — wider surface (FYI, not all in scope)

`rg -n "\.planning" guides/` finds ~15 more references beyond the 4 dead ones, in
`admin-quality-ledger.md` (lines 93, 94, 95, 135), `companion-oauth-provider.md:51`,
`upgrading-to-v1.12.md:3,5,7,8`, `upgrading-to-v1.0.md:9`, `upgrading-to-v1.7.md:3,7,20`,
`upgrading-to-v1.8.md:3`, `intermediate-production-path.md:19`. **These do not warn** (they are
prose mentions or absolute GitHub URLs, not relative file links ExDoc resolves). They are
bookkeeping-in-published-docs but are **not** covered by SURF-02's wording (which scopes to
`@moduledoc`/`@doc` ranges in `lib/`). Recommend filing as a todo rather than expanding scope.

### E.6 Reproducible scanner

```python
# extracts @moduledoc/@doc/@shortdoc/@typedoc heredoc ranges under lib/ and
# matches planning-bookkeeping tokens
tokens = re.compile(r"(\.planning/|\bPhase \d{1,3}\b|\bphase[-_]\d{1,3}\b|\bD-\d{2}\b|"
                    r"\bSC-\d\b|\bREQ-[A-Z0-9]|\bPitfall \d\b|\bINV-\d|"
                    r"-PLAN\.md|-CONTEXT\.md|-SUMMARY\.md|\btodos/\b)")
start   = re.compile(r'^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"""')
oneline = re.compile(r'^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"')
```

---

## F. SECURITY-comment inventory `[VERIFIED: live rg with positive control]`

### F.1 🚩 The literal marker `# SECURITY:` **does not exist anywhere in this repository**

```
$ rg -l "# SECURITY" --glob '!.git' --glob '!_build' --glob '!deps' --glob '!doc' --glob '!.gsd' . | wc -l
0
```

**Positive control, same invocation:** `rg -c -e "# SECURITY" -e "enumeration" …` returned counts
for 8 files (`lib/sigra/crypto.ex:2`, `lib/sigra/hasher.ex:1`,
`lib/sigra/live_view/organization_scope.ex:2`, `lib/sigra/organizations/invitations.ex:2`,
`lib/sigra/plug/load_organization_from_slug.ex:1`, `guides/reference/admin-glossary.md:2`, …) —
so the search machinery, the globs and the path all work. The `# SECURITY` alternative simply has
**zero** matches. Secondary control: `rg -n "# SECURITY" priv/templates/` → no output.

**Planning consequence — this is the highest-risk misreading in the phase.** SC-5 and Phase 239 SC-5
both say "`# SECURITY:`-class rationale". If a plan writes a guard that searches for the literal
string `# SECURITY:`, that guard **can never fire** — a textbook "green gate that verifies nothing,"
which is exactly the failure mode this milestone exists to close (Standing Constraint 1 cites three
precedents). **The class must be defined by the regex, not the marker.**

### F.2 The real class

`rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib/` → **52 comment lines**.

### F.3 Overlap set — files at risk of collateral deletion

Files that have **both** a doc-attribute bookkeeping hit (§E.2) **and** a security-class `#` comment.
These are where a careless sweep could take the sentence along with the token:

```
lib/sigra/account.ex                              lib/sigra/mfa/trust.ex
lib/sigra/account/deletion.ex                     lib/sigra/oauth.ex
lib/sigra/account/email_change.ex                 lib/sigra/optional_deps.ex
lib/sigra/account/password_change.ex              lib/sigra/organizations.ex
lib/sigra/api_token.ex                            lib/sigra/organizations/invitations.ex
lib/sigra/audit.ex                                lib/sigra/organizations/query.ex
lib/sigra/auth.ex                                 lib/sigra/plug/load_active_organization.ex
lib/sigra/install/features/organizations.ex       lib/sigra/scope/hydration.ex
lib/sigra/live_view/organization_scope.ex         lib/sigra/workers/cleanup_expired_invitations.ex
lib/sigra/lockout.ex
lib/sigra/mfa.ex
lib/sigra/mfa/backup_codes.ex
lib/sigra/mfa/lockout.ex
```

**22 files.** Note two of the highest-hit files are in this set (`organizations.ex` 25 hits,
`auth.ex` 13 hits) — the riskiest edits and the security-densest files are the same files.

### F.4 Highest-risk individual sites — bookkeeping token *inside* security rationale

| file:line | Text | Risk |
|---|---|---|
| `lib/sigra/auth.ex:1060` | `with a dummy hash operation to match timing (per D-38).` | **timing** rationale; deleting the line to remove `D-38` deletes a timing-attack note |
| `lib/sigra/mfa.ex:1008` | `to prevent replay attacks (D-41).` | replay-prevention rationale |
| `lib/sigra/mfa.ex:1008` / `:24` | `Replay prevention via `last_verified_step` tracking (D-41)` | same |
| `lib/sigra/session_store.ex:72-77` | `This callback is a trusted internal write; callers (e.g. the Phase 14 …) … authz — see Phase 14 threat register (T-14-04). Added in Phase 14 (Plan 14-01, D-20).` | **the entire trust/authz note is phrased around "Phase 14"** — rewriting here needs care, not deletion |
| `lib/sigra/audit.ex:9` | `Public API enforces reserved prefixes (D-17..D-18); internal `__log_internal__/3` bypasses this check for library-owned events` | scope/authority boundary |
| `lib/sigra/mfa/backup_codes.ex` (see `mfa.ex:25`) | `Backup codes: SHA-256 hashed, atomic consumption (D-13, D-16)` | crypto rationale |

**Prescribed guard for SC-5 (mechanical, and provably able to fire):**

```bash
# on the phase branch, against origin/main
git diff origin/main -- lib/ \
  | grep -E '^-' | grep -vE '^---' \
  | grep -iE '\b(security|CSRF|enumeration|timing|scope|impersonation)\b' \
  | grep -vE '^-.*\b(D-[0-9]{2}|SC-[0-9]|Phase [0-9]{1,3}|\.planning/)\b.*$'
# any surviving line = a removed security sentence that was NOT a pure bookkeeping token → FAIL
```

This is expressible as a `scripts/ci/prohibitions/*.test.mjs` guard, but note Standing
Constraint 6: it needs a committed known-bad fixture and a demonstrated RED. Consider whether a
one-shot in-plan verification is sufficient here — the roadmap assigns the durable `p18`
bookkeeping guard to **Phase 241 SURF-04**, so 237 probably should not build a second one.

---

## G. Existing CI / script coverage — extend, don't duplicate

`rg -n "git status|--porcelain|diff --exit-code|dirty" .github/workflows/ scripts/ci/ mix.exs`:

| Concern | Existing coverage | Verdict for 237 |
|---|---|---|
| **Whole-repo clean-tree check** | **None.** All `git status --porcelain` uses are scoped: `ci.yml:1784`, `ci.yml:2039`, `scripts/ci/snapshot-canary-guard.sh:96` all pass `-- "$SNAP_DIR"` | No existing gate to extend. If SC-1 needs mechanization, it is new. **Recommend: verify by fresh `git clone` into a temp dir + `git status --porcelain` — the literal SC-1 wording — rather than building a CI job.** |
| **Docs-warning gate** | **Exists** — `ci.yml:635`, `release-please.yml:221`, `hex-publish.yml:153`, all `mix docs --warnings-as-errors` | **Do not add.** SURF-02's gate clause is already satisfied. |
| **Pages** | `scripts/ci/ensure-github-pages-legacy-branch.sh` (swallows 403); `scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs`; `.github/workflows/playwright-github-pages.yml` | The 403 hardening is **Phase 240 (GREEN-05)**. 237 does the settings change + live observation only. |
| **`doc/llms.txt` contract** | `test/sigra/planning/phase_148_*`, `phase_149_*` (run under `mix ci`); `scripts/ci/launch-pack-contract.sh` (**no workflow caller — FUT-04**) | Regression coverage already exists; just keep it green. |
| **Prohibitions glob** | `ci.yml:393` picks up `scripts/ci/prohibitions/*.test.mjs` with zero workflow edits; 17 guards exist (`p01`…`p17`) | If 237 adds a guard, drop it here. But `p18` is **Phase 241's** slot per the roadmap. |
| **Stash / worktree** | **None** | New; read-only verification is sufficient (`git worktree list`, `git stash list`, `git cat-file -e`, `git ls-remote`). |

---

## H. Common Pitfalls

### Pitfall 1: The `!doc/llms.txt` negation that silently does nothing
**What goes wrong:** `/doc/` + `!doc/llms.txt` re-ignores the file; `git status` still looks clean (file is tracked), so nobody notices until someone regenerates docs and `git add doc/llms.txt` refuses.
**How to avoid:** use `/doc/*` + `!/doc/llms.txt`. **Verify with `git check-ignore -q --no-index doc/llms.txt`** (must exit 1) — `git check-ignore` **without** `--no-index` is useless here, because tracked paths are never reported as ignored regardless of pattern. `[VERIFIED: measured both ways this session]`

### Pitfall 2: Fixing `code-walkthrough.md:174` and declaring Pages fixed
**What goes wrong:** the Liquid crash is one of many `{%`-shaped constructs across a repo full of Elixir sigils and copied workflow YAML; `MAINTAINING.md` already has 3 warnings of the same shape. Fixing one file leaves the next commit to re-break it.
**How to avoid:** fix the **source**, not the symptom (§C.6 option A). Confirm with `gh api …/pages --jq .status` == `built` plus a live `curl -I`, not by re-reading the Markdown.

### Pitfall 3: Dropping a stash before confirming the push landed
**What goes wrong:** `git stash drop` makes the commit reachable only via reflog; with `git gc` forbidden it survives, but the milestone loses its "resolvable ref" claim.
**How to avoid:** push all 6 → `git ls-remote origin 'refs/stash-archive/*'` shows 6 → `git cat-file -e` each → **only then** clear.

### Pitfall 4: `rm -rf` a stale worktree directory before `git worktree prune`
**What goes wrong:** git's admin record in `.git/worktrees/` can end up locked or half-removed; the `00000000` null-HEAD entry is already evidence of a half-broken record.
**How to avoid:** `git worktree prune` first, `git worktree list` to confirm one entry, then remove directories if any remain.

### Pitfall 5: A `# SECURITY:` guard that can never fire (§F.1)
**How to avoid:** define the class by regex. Demonstrate the guard RED against a fixture before accepting it.

### Pitfall 6: Renaming a HexDocs section heading and breaking anchors
**What goes wrong:** `lib/sigra/auth.ex:1262` is `## Phase 14: organization selector (D-12, D-26, ORG-SCOPE-06)` — a rendered heading with anchor `#phase-14-organization-selector`.
**How to avoid:** grep `guides/`, `test/`, `README.md`, `CHANGELOG.md` for the anchor before renaming; ExDoc will **not** warn about a broken in-page anchor.

### Pitfall 7: Colliding with Phase 236's file
**How to avoid:** `lib/sigra/admin/live/audit_index_live.ex` belongs to 236 and is **excluded** from 237's sweep (roadmap, Ordering and Parallelism). It is not in the §E.2 top-15 list, so this is easy to honor.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---|---|---|---|
| Deciding whether a path is ignored | Custom pattern matcher | `git check-ignore -v --no-index <path>` | Tracked-file semantics are subtle (§B.1); `--no-index` is mandatory here |
| Making stashes durable | tarball / copy the diff to a file | `git push origin <sha>:refs/<ns>/<name>` | A stash is already a commit object; pushing the SHA preserves it exactly with no lossy re-application |
| Removing stale worktrees | `rm -rf` | `git worktree prune` | Removes the admin record git owns; the null-HEAD entry shows what happens otherwise |
| Docs-warning enforcement | A new CI job | `mix docs --warnings-as-errors` — **already at `ci.yml:635`** | Three workflows already run it |
| Verifying Pages is green | Reading workflow YAML | `gh api repos/szTheory/sigra/pages` + `curl -I <html_url>` | Standing Constraint 1 requires a live external observation |
| Extracting doc-attribute ranges | Regex over whole files | Heredoc-range scanner (§E.6) | A naive whole-file grep can't tell a rendered `@moduledoc` from an inline `#` comment — and the roadmap's tiering depends on exactly that distinction |

---

## Standard Stack

**No external packages are installed by this phase.** All work uses tools already present:

| Tool | Version | Purpose |
|---|---|---|
| `git` | system (macOS) | ignore semantics, worktrees, stashes, refs |
| `gh` CLI | authenticated as `szTheory`, scopes `gist, read:org, read:packages, repo, workflow` | Pages API, Actions run logs |
| `mix docs` (ExDoc) | `~> 0.40` per `CLAUDE.md` | HexDocs render + warning surface |
| `rg` | system | doc sweeps (with positive controls) |
| `mix ci` | repo alias | the only sanctioned pre-push gate (Standing Constraint 3) |

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** No `mix.exs` dependency change, no
npm install, no registry lookup required. `[VERIFIED: phase scope is repo config + docs prose + repo settings]`

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json`. `[VERIFIED: .planning/config.json]`

### Test Framework
| Property | Value |
|---|---|
| Framework | ExUnit (Elixir `~> 1.18`) + shell contract scripts + `*.test.mjs` prohibitions |
| Config file | `mix.exs` (`ci` alias), `test/test_helper.exs` |
| Quick run command | `MIX_ENV=test mix test test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` |
| Full suite command | `MIX_ENV=test mix ci` (**never** root `mix test` — Standing Constraint 3) |

### Phase Requirements → Test Map
| Req | Behavior | Test type | Automated command | Exists? |
|---|---|---|---|---|
| REPO-01 | Fresh clone has clean `git status` | integration (external) | `d=$(mktemp -d); git clone --depth 1 https://github.com/szTheory/sigra "$d/s" && git -C "$d/s" status --porcelain --untracked-files=all` → empty | ✅ (ad-hoc, no file needed) |
| REPO-02 | `doc/llms.txt` stays tracked and un-ignored | unit | `git check-ignore -q --no-index doc/llms.txt` → **exit 1**; `git ls-files doc/llms.txt` → non-empty | ✅ |
| REPO-02 | Three consumers green | unit | `MIX_ENV=test mix test test/sigra/planning/phase_148_*.exs test/sigra/planning/phase_149_*.exs` + `bash scripts/ci/launch-pack-contract.sh` | ✅ (script has no workflow caller — FUT-04) |
| GREEN-03 | Pages built | integration (live external) | `gh api repos/szTheory/sigra/pages --jq '.status'` → `built`; `curl -sSI https://sztheory.github.io/sigra/ \| head -1` → `200` | ✅ |
| REPO-03 | Worktrees / stashes | unit | `git worktree list \| wc -l` → 1; `git stash list` → empty; per-SHA `git cat-file -e`; `git ls-remote origin 'refs/stash-archive/*' \| wc -l` → 6 | ✅ |
| SURF-02 | No `.planning/` in rendered docs | unit | `rg -n "\.planning" lib/` → no match **(must be paired with a positive control, e.g. `rg -c "defmodule" lib/`)** | ✅ |
| SURF-02 | `mix docs` warning-free | unit | `mix docs --warnings-as-errors` | ✅ **already in `ci.yml:635`** |
| SURF-02 | Skip list load-bearing | unit | remove-and-retest, §E.4 table | ✅ (evidence table) |
| SC-5 | No security sentence deleted | unit | §F.4 `git diff` pipeline | ❌ **Wave 0** — needs writing |

### Sampling Rate
- **Per task commit:** `MIX_ENV=test mix test test/sigra/planning/` + the relevant one-liner from the table
- **Per wave merge:** `MIX_ENV=test mix ci`
- **Phase gate:** `mix ci` green + live `gh api …/pages` observation at final committed HEAD on a clean tree (Standing Constraint 2)

### Wave 0 Gaps
- [ ] The SC-5 security-sentence-preservation check (§F.4) — a shell snippet in the plan, or a `p18`-adjacent guard. **Note the roadmap assigns `p18` to Phase 241**; prefer an in-plan check here.
- [ ] Nothing else. There is **no** framework install and **no** new test file strictly required.

*(A "negative result needs a positive control" rule is standing repo policy — every `rg`/`grep` assertion in the plan's verification steps must ship with a control command whose output is non-empty.)*

---

## Security Domain

`security_enforcement` is not disabled; this section is included.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | No auth code changes in this phase (`audit_index_live.ex` is excluded and owned by 236) |
| V3 Session Management | no | — |
| V4 Access Control | **yes (meta)** | The Pages `source` PUT changes what is **publicly published**. Option (B) would publish the entire repo root as a static site. Choose option (A). |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |
| V14 Configuration | **yes** | `.gitignore` and GitHub Pages settings are configuration-surface changes |

### Known Threat Patterns
| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Publishing internal planning surface via a root `.nojekyll` on `main` | Information Disclosure | Point Pages at `gh-pages` (option A), never publish `main /` raw |
| Deleting a security rationale comment while stripping a `D-NN` token | Repudiation / knowledge loss | §F.4 diff guard, regex-defined class (**not** the literal `# SECURITY:`, which has zero occurrences) |
| Dropping a stash whose archive push silently failed | Denial (of recoverability) | Push → `git ls-remote` → `git cat-file -e` → *then* clear |
| Secrets in the pushed diff | Information Disclosure | This is a **public repo** (standing memory rule). The `.gsd/scratch/` contents being gitignored — not committed — is the correct disposition; 660M of CI logs/traces must never be committed. |

---

## Runtime State Inventory

This phase touches repo and remote state, so the categories are answered explicitly:

| Category | Items Found | Action Required |
|---|---|---|
| **Stored data** | None — no database, schema, or persisted-record change in scope. Verified: the phase touches `.gitignore`, `guides/*.md`, `lib/**` doc attributes, `mix.exs` docs config, and git refs only. | none |
| **Live service config** | **GitHub Pages `source` = `{"branch":"main","path":"/"}` and `build_type: "legacy"`, held in GitHub repo settings — NOT in git.** This is the only live-service config item, and it is the phase's central one. | REST `PUT` (operator) — §C.5 |
| **OS-registered state** | 5 stale git worktree admin records under `.git/worktrees/`, pointing at `/private/tmp/` paths that may no longer exist (one has a `00000000` HEAD). | `git worktree prune` (never `rm -rf` first) |
| **Secrets / env vars** | None changed. `secrets.GITHUB_TOKEN` is *observed* to be insufficient for the Pages PUT; no secret is created, rotated, or referenced by name-change. | none |
| **Build artifacts** | `doc/` (660 generated files, ignored); `sigra-0.1.0.tar`, `sigra-0.2.0.tar` (Apr 2026, already ignored, untracked); `.gsd/` 268 files / 660M (to be ignored). None are tracked, so none are stale-after-rename. | ignore `.gsd/`; optionally delete the two tarballs locally (cosmetic, not a `git status` issue) |

---

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `/Users/jon/projects/sigra/CLAUDE.md`, binding on the plan:

1. **GSD Workflow Enforcement** — "Before using Edit, Write, or other file-changing tools, start work through a GSD command." All 237 edits must run inside `/gsd-execute-phase`.
2. **`mix ci` is the local gate** — "run `MIX_ENV=test mix ci` before pushing; root `mix test` misses formatting AND `test/example`" (334 tests vs 251).
3. **Local dev prerequisites** — `mix test` needs a live Postgres (`postgres`/`postgres`, db `sigra_test`). `scripts/db/up.sh` + `direnv allow`, or CI's 5432 fallback.
4. **Install golden tests need phx_new 1.8.8** — `mix archive.install --force hex phx_new 1.8.8`, or `golden_diff_test` produces spurious byte-diffs. (Not expected to be touched by 237, but `mix ci` runs it.)
5. **Admin UI direction** — `guides/reference/admin-ui-principles.md` + `admin-design-contract.md`; preserve `sg-*` cascade-layer/BEM. **237 makes no UI change**, so this is inert here — but `lib/sigra/admin/components.ex` is #2 on the §E.2 hit list, so any doc edit there must not touch markup.
6. **Security: OWASP standards throughout; enumeration prevention by default.** Reinforces §F.
7. **Minimal transitive deps** — no new dependency; §"Package Legitimacy Audit" is N/A accordingly.
8. **Public repo, no adopter PII** (standing memory rule) — grep the pushed diff, not just memory.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | The operator's local `gh` token (scope `repo`, repo `admin:true`) can successfully `PUT` `repos/szTheory/sigra/pages`. **Not executed** — repo-settings mutation is outside a research agent's remit, so this is inference from the permissions payload, not a falsification attempt. | §C.5 | If it 403s too, the fix drops to the Settings UI. Cost: a UI click instead of a CLI command. Low. |
| A2 | Pointing `source` at `gh-pages` produces `status: built`, given `.nojekyll` + `index.html` + `runs/` are already on that branch and the publisher runs green daily. | §C.4/C.6 | If the site still errors, a second diagnosis round is needed. Mitigated by SC-2's live `gh api` + `curl` verification. |
| A3 | The stash-materialization ref namespace (`refs/stash-archive/<date>/stash-N`) is a free choice. No existing convention was found on `origin` (only `refs/heads/ci/*`). | §D.3 | Cosmetic. |
| A4 | The two tracked `.planning/` artifacts (`216-09-harness-evidence.log`, `4.1-sessions-live.png`) should be **kept**, since "no pruning `.planning/` from the repo" is an explicit Out-of-Scope line and neither affects `git status`. | §A.3 | If the intent was deletion, one extra commit. Low — but **this needs a decision recorded**, because REPO-01 and the Out-of-Scope table read as contradictory. |
| A5 | SC-2's "root `.nojekyll` backstop" is satisfied by the existing `.nojekyll` on the `gh-pages` branch root (verified present), rather than requiring a new one on `main`. | §C.4 | If the verifier demands `.nojekyll` on `main`, see option (B)'s disclosure risk — do not add it blindly. |
| A6 | `lib/sigra/config.ex:46,51` NimbleOptions `doc:` strings render on HexDocs via `NimbleOptions.docs/1`. Not confirmed by reading the generated HTML. | §E.2 | If they don't render, two fewer edit sites. Trivial. |

---

## Open Questions

1. **How much of the 348-hit / 71-file `lib/` doc surface is in scope for 237?**
   - Known: the 4 dead `.planning/` paths are unambiguously in scope; `mix docs` is already gated; Phase 241 SURF-04 owns the durable `p18` ratchet and explicitly says "zero is not the target."
   - Unclear: whether SC-4's "`@moduledoc`/`@doc` ranges in `lib/` are clean" means all 348 or just the `.planning/` class.
   - **Recommendation:** commit an explicit named file list in the plan (the 4 `.planning/` sites + a bounded set of top-hit public modules), record the residual count as the **Phase 241 ratchet baseline**, and say so in the SUMMARY. Do not attempt 71 files.

2. **REPO-01 vs. the Out-of-Scope "no pruning `.planning/`" line** (A4). Needs an explicit recorded decision.

3. **Should the 4 dead `.planning/` guide links be fixed here (letting 2 skip entries go), or left to a todo?**
   - They are the exact SURF-02 defect class and are **rendered in published HexDocs**, but they live in `guides/`, and SURF-02's wording scopes to `lib/`.
   - **Recommendation:** fix them here. They are 3 lines in 2 files, they retire 2 of 9 skip entries, they correct a now-false comment at `mix.exs:189-191`, and they are the only route to a non-vacuous skip-list prune.

4. **Does 237 need a mechanized SC-5 guard, or is an in-plan `git diff` check enough?** Phase 241 owns `p18`. **Recommendation:** in-plan check + evidence in the SUMMARY; leave the durable guard to 241.

5. **What to do about the stale committed `doc/llms.txt` (§B.2b)?** Running `mix docs` — which this
   phase must do — dirties a tracked file, which is in direct tension with SC-1.
   **Recommendation:** option (3) — regenerate and commit it here, and file the recurring-drift
   check as a todo (it interacts with Phase 242's 1.5.1 cut).

---

## Environment Availability

| Dependency | Required by | Available | Version / detail | Fallback |
|---|---|---|---|---|
| `git` | REPO-01/02/03 | ✓ | system (macOS, Darwin 25.6.0) | — |
| `gh` CLI (authenticated) | GREEN-03 | ✓ | account `szTheory`, scopes `gist, read:org, read:packages, repo, workflow` | Settings UI |
| Repo admin permission | GREEN-03 | ✓ | `{"admin":true,"maintain":true,"pull":true,"push":true,"triage":true}` | Settings UI |
| `mix` / Elixir / OTP | SURF-02 | ✓ | `mix docs` completed EXIT=0 this session | — |
| `rg` | SURF-02 sweeps | ✓ | — | quoted `grep -r` |
| `python3` | doc-range scanner | ✓ | — | Elixir script |
| Live Postgres (`sigra_test`) | `mix ci` | *not probed this session* | `scripts/db/up.sh` per CLAUDE.md | — |
| `phx_new 1.8.8` archive | `mix ci` golden tests | *not probed this session* | `mix archive.install --force hex phx_new 1.8.8` | — |
| `origin` push access | REPO-03 | ✓ | `push: true` | — |

**Missing with no fallback:** none.
**Missing with fallback:** the Pages `PUT` may 403 → Settings UI.

---

## State of the Art

| Old (roadmap's picture) | Measured reality | Impact |
|---|---|---|
| Untracked includes `.gsd/`, `.planning/.gsd-ws-arg`, `sigra-*.tar`, `.log`/screenshots | **Only `.gsd/` is untracked.** `.gsd-ws-arg` does not exist; `sigra-*.tar` is already ignored; the `.log`/`.png` are *tracked*, under `.planning/` | REPO-01 shrinks to a one-line `.gitignore` addition + a decision on two tracked files |
| Fix `guides/introduction/code-walkthrough.md:174` to make Pages green | **Root cause is the Pages `source`, not the file.** `gh-pages` exists, has `.nojekyll`, publishes green daily; the PUT 403s from CI but the operator's token has admin | GREEN-03 becomes one settings change + live verification |
| `mix docs` needs to be made warning-free "as a gate" | **Already warning-free and already gated in 3 workflows** | SURF-02's gate clause is done; only content + skip-list remain |
| `skip_undefined_reference_warnings_on` should be "pruned to what is still needed" | **All 9 entries are load-bearing; 0 dead.** A prune requires first fixing 4 dead `.planning/` links in `guides/` | Prune is 9→7, achievable only via a content fix |
| `lib/` doc bookkeeping "starting with `lib/sigra/audit.ex:5`" | **348 hits / 259 sites / 71 files** | Must be explicitly descoped or the phase overruns |
| SC-5's "`# SECURITY:`-class" | **Zero `# SECURITY` occurrences repo-wide** (positive-controlled) | A literal-marker guard would be a guard that never fires |

**Deprecated / superseded:**
- `mix.exs:189-191` comment ("maintainer paths under `.planning/` are intentionally relative from this guide for repo navigation") — **now false** for the three targets, which no longer exist.
- The Pages todo's "Owner: repo admin… set Settings → Pages manually" framing predates the observation that the operator's CLI token also carries `admin: true` — a `gh api PUT` is likely a faster path than the UI.

---

## Sources

### Primary (HIGH confidence — live tool observation, this session)
- `gh api repos/szTheory/sigra/pages` — raw JSON, §C.1
- `gh api repos/szTheory/sigra --jq .permissions`, `gh auth status` — §C.5
- `gh run view 35052016058 --log-failed` — the Liquid exception, §C.3
- `gh run list --workflow=pages-build-deployment --limit 8`, `--workflow=playwright-github-pages.yml --limit 6` — §C.2, §C.4
- `git status --porcelain -uall`, `git clean -ndx`, `git ls-files`, `git check-ignore -v [--no-index]`, `git worktree list [--porcelain]`, `git stash list`, `git ls-remote origin`, `git ls-tree --name-only origin/gh-pages`
- `mix docs` (baseline, EXIT=0, 0 warnings) and `mix docs` with `skip_undefined_reference_warnings_on: []` (14 warnings) — `mix.exs` restored and verified byte-identical (`git diff --exit-code mix.exs` clean; `shasum` `88bd2c24c7f245dd6d057205a0e87365f9813101` before and after)
- Empirical `.gitignore` negation matrix in a throwaway `git init` repo — §B.2
- `rg` sweeps with paired positive controls — §A.2, §E.1, §F.1

### Repo files read this session
- `/Users/jon/projects/sigra/.planning/ROADMAP.md` (full)
- `/Users/jon/projects/sigra/.planning/REQUIREMENTS.md` (`:19`, `:35`, `:41-43`, `:99`, `:109`, `:112-114`, `:132`)
- `/Users/jon/projects/sigra/.planning/STATE.md` (`:1-55`)
- `/Users/jon/projects/sigra/.planning/config.json`
- `/Users/jon/projects/sigra/CLAUDE.md`
- `/Users/jon/projects/sigra/.gitignore`, `.git/info/exclude`
- `/Users/jon/projects/sigra/mix.exs` (`:180-232`)
- `/Users/jon/projects/sigra/guides/introduction/code-walkthrough.md` (`:160-185`)
- `/Users/jon/projects/sigra/.github/workflows/playwright-github-pages.yml` (full)
- `/Users/jon/projects/sigra/scripts/ci/ensure-github-pages-legacy-branch.sh` (full)
- `/Users/jon/projects/sigra/scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs` (`:1-20`)
- `/Users/jon/projects/sigra/.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md` (full)
- `/Users/jon/projects/sigra/lib/sigra/audit.ex` (`:1-20`), `lib/sigra/testing.ex` (`:1265-1285`), `lib/mix/tasks/sigra.fixture.rebless_golden.ex` (`:1-25`)

### Secondary (MEDIUM)
- `guides/introduction/upgrading-to-v1.10.md`, `upgrading-to-v1.11.md`, `upgrading-to-v1.12.md`, `intermediate-production-path.md` — read via `rg -n` line output, not full-file reads

### None (no LOW-confidence web sourcing was needed — every claim is a local or GitHub-API measurement)

---

## Metadata

**Confidence breakdown:**
- Untracked/ignore inventory: **HIGH** — direct `git` output, positive-controlled greps
- `doc/llms.txt` negation semantics: **HIGH** — empirically falsified the naive form in a throwaway repo
- Pages diagnosis: **HIGH** — raw API JSON + the failing run's own stack trace
- Pages *fix* outcome: **MEDIUM** (A1, A2) — the PUT was deliberately not executed
- Stash/worktree state: **HIGH** — direct output, counts match the roadmap exactly
- `mix docs` / skip-list: **HIGH** — exhaustive remove-and-retest with a verified byte-identical `mix.exs` restore
- `lib/` doc bookkeeping scale: **HIGH** for the counts; **MEDIUM** for the (i)/(ii) classification of the 4 `.planning/` sites (judgment call, text quoted verbatim so it is re-checkable)
- SECURITY-comment class: **HIGH** — zero-match claim carries a same-invocation positive control

**Research date:** 2026-09-16
**Valid until:** ~2026-09-23 (7 days). Short-lived: the Pages state, the stash/worktree list, and `.gsd/` contents are all live mutable state, and Phases 236/238 are running in parallel.
**Explicitly NOT mutated during this research:** no git state changed (no prune, no drop, no clean, no push); no repo settings changed; `mix.exs` restored byte-for-byte and verified.
