# Phase 237 Evidence Ledger

Observed at commit: 0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173

This ledger's six slots re-observe every one of this phase's five requirements at the
committed HEAD named above, on a clean tree, after all five wave plans (`237-01` through
`237-05`) and this plan's own Task 1 (todos + ratchet baseline) were already committed. Every
observation below was captured by running the cited command against that exact commit before
this file itself was written or committed — this file's own commit is the only thing that
moves HEAD past the sha named above, and it touches nothing outside `.planning/`.

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-PHASE-BASELINE](#before-phase-baseline) | The measured pre-phase state `237-RESEARCH.md` established: Pages errored on every push, 6 stale worktree entries, 6 local stashes, a stale docs index, 4 dead `lib/` doc references | Live `gh` / `git` commands run during research, cited verbatim | pending (historical baseline, re-cited from committed research) |
| [AFTER-CLEAN-TREE](#after-clean-tree) | A real fresh clone reports empty status; the `doc/llms.txt` negation is reachable; the three consumers pass | Real `git clone` into a temp dir, `git check-ignore --no-index`, `bash scripts/ci/launch-pack-contract.sh`, `mix ci`'s ExUnit run | pending (local run, this commit) |
| [AFTER-PAGES-BUILT](#after-pages-built) | GitHub Pages source is `gh-pages`, status `built`, published URL returns 200 | Live `gh api` read-back + `curl -sSI` | captured (build `29e6ad40bf3e892d7582e7c07ed1fa7cc7910ec1`, observed 2026-09-16) |
| [AFTER-GIT-OBJECTS](#after-git-objects) | One live worktree; all 6 stashes still present at identical SHAs (D-09); no archive refs; no home-directory path in the committed snapshot | `git worktree list`, `git stash list --format=%H`, `git ls-remote`, `grep` on the committed snapshot | pending (local run, this commit) |
| [AFTER-DOCS-SURFACE](#after-docs-surface) | The 4 D-01-named dead references are absent from the 3 edited `lib/` files; suppression list is 7; `mix docs --warnings-as-errors` exits 0 | `grep` with positive controls, `sed`-scoped list count, `mix docs --warnings-as-errors` | pending (local run, this commit) |
| [AFTER-RATIONALE-PRESERVED](#after-rationale-preserved) | The regex-class check re-run at FINAL HEAD (not inherited from `237-04`) against the real `lib/` diff, plus its fixture RED/GREEN/fail-closed proofs | `git diff <merge-base> HEAD -- ':/lib/' \| 237-security-comment-diff-check.sh -`, fixture runs | pending (local run, this commit) |

---

## BEFORE-PHASE-BASELINE

Status: pending (historical baseline established in `237-RESEARCH.md`, re-cited here, not a live re-run — this slot exists to give the five `AFTER-` slots a before/after pair rather than five unanchored afters)

Measured live during research, before this phase changed anything (`237-RESEARCH.md` §C.1, §B.2b, and `237-CONTEXT.md`'s D-09 pre-check):

```bash
$ gh api repos/szTheory/sigra/pages
{"url":"https://api.github.com/repos/szTheory/sigra/pages","status":"errored","cname":null,
 "custom_404":false,"html_url":"https://sztheory.github.io/sigra/","build_type":"legacy",
 "source":{"branch":"main","path":"/"},"public":true,"protected_domain_state":null,
 "pending_domain_unverified_at":null,"https_enforced":true}
```

```bash
$ git worktree list | grep -c .
6
$ git stash list | grep -c .
6
```

```diff
$ git diff doc/llms.txt   # after running `mix docs` on the then-committed tree
-# Sigra v1.4.0 - Table of Contents
+# Sigra v1.5.0 - Table of Contents
@@
 - [Sigra.Branding](Sigra.Branding.md): Brand profile resolution for generated auth UI and transactional emails.
+- [Sigra.Branding.Contrast](Sigra.Branding.Contrast.md): Colour maths for resolving brand tokens against a theme surface.
```

```
lib/sigra/audit.ex:5, lib/sigra/testing.ex:1274, lib/mix/tasks/rebless_golden.ex:11,
lib/mix/tasks/rebless_golden.ex:13   — the 4 D-01-named dead .planning/ references
```

## AFTER-CLEAN-TREE

Status: pending (local run, this commit — `0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173`)

### A real fresh clone reports empty status

```bash
$ TMPDIR_CLONE=$(mktemp -d)
$ git clone -q "file://$(pwd)" "$TMPDIR_CLONE/sigra-clone"
$ cd "$TMPDIR_CLONE/sigra-clone"
$ git status --porcelain --untracked-files=all
# (no output)
$ echo $?
0
```

### The `doc/llms.txt` negation is reachable, with a same-block positive control

```bash
$ git check-ignore -q --no-index doc/llms.txt
$ echo $?
1
# doc/llms.txt is NOT ignore-matched — the negation reaches it

$ git check-ignore -q --no-index doc/index.html   # positive control: a sibling GENERATED file
$ echo $?
0
# doc/index.html IS ignore-matched — the check discriminates; the search machinery works

$ git ls-files doc/llms.txt
doc/llms.txt
# tracked, never deleted
```

### The three live consumers

```bash
$ bash scripts/ci/launch-pack-contract.sh
==> launch-pack-contract
==> launch-pack-contract: OK
$ echo $?
0
```

`scripts/ci/launch-pack-contract.sh` is recorded as **manual-only, with no workflow caller**
(known as FUT-04) — verified with a positive control proving the search itself ran against a
populated directory:

```bash
$ grep -rn "launch-pack-contract" .github/workflows/
$ echo $?
1
# no match — confirmed no workflow invokes it

$ grep -rln "scripts/ci/" .github/workflows/
.github/workflows/playwright-github-pages.yml
.github/workflows/terminal-ratification-evidence.yml
.github/workflows/ci-observe.yml
.github/workflows/generated-app-login-runtime-proof.yml
.github/workflows/release-please.yml
.github/workflows/hex-publish.yml
.github/workflows/fast-01-gap-closure-evidence.yml
.github/workflows/fast-01-remeasurement-evidence.yml
.github/workflows/ci.yml
$ echo $?
0
# positive control: 9 workflow files DO call other scripts/ci/ scripts — the grep and the path both work
```

`test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` and
`test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` run as part of
`mix ci`'s `test --exclude scaffold` step — see the [AFTER-CLEAN-TREE gate section](#gate-section-task-3--mix-ci-at-final-head) appended below for the full-suite result covering both.

## AFTER-PAGES-BUILT

Status: captured (run 29e6ad40bf3e892d7582e7c07ed1fa7cc7910ec1, observed live 2026-09-16)

This uses the **captured** form, not `pending`, because a real GitHub API build identifier
exists — this is the one slot in this ledger with a live external observation, per the v1.48
standing constraint requiring one per phase.

```bash
$ gh api repos/szTheory/sigra/pages --jq '{status,build_type,source}'
{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"status":"built"}
```

```bash
$ gh api repos/szTheory/sigra/pages/builds/latest --jq '{status,commit,updated_at}'
{"commit":"29e6ad40bf3e892d7582e7c07ed1fa7cc7910ec1","status":"built","updated_at":"2026-09-16T13:10:03Z"}
```

Real HTTP fetch of the published URL, with a same-block negative control proving the 2xx
assertion is not an artifact of a check that cannot fail:

```bash
$ curl -sSI https://sztheory.github.io/sigra/ | head -6
HTTP/2 200
server: GitHub.com
content-type: text/html; charset=utf-8
last-modified: Wed, 16 Sep 2026 13:10:03 GMT
access-control-allow-origin: *
etag: "6aaa952b-66f"

$ curl -sS -o /dev/null -w "%{http_code}" https://sztheory.github.io/sigra/__definitely_not_a_real_path__
404
```

`build_type: legacy` and `source.branch: gh-pages` are unchanged from the state plan `237-02`
established on 2026-09-16T13:11:21Z — this re-observation, run independently at this plan's
own execution time, confirms the fix holds rather than merely re-reading the earlier record.

## AFTER-GIT-OBJECTS

Status: pending (local run, this commit — `0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173`)

### One live worktree

```bash
$ git worktree list
/Users/jon/projects/sigra  0afe33d7 [main]
$ git worktree list | grep -c .
1
```

### SC-3's stash half — INTENTIONALLY UNMET under D-09, not failed

**SC-3, as the ROADMAP wrote it, is the inverse of what is true here on purpose.** It asked
for all 6 stashes to exist as pushed refs on `origin` and `git stash list` to be empty. Per
`237-CONTEXT.md` D-09 (operator decision, 2026-09-16), that half is **abandoned**: `origin` is
the public sigra repository, four of the six stashes carry roughly two thousand lines of
home-directory paths, and a push to a public GitHub remote is irreversible with respect to
content. This slot's job is the inverse assertion: **six stashes still present, untouched, at
identical SHAs to plan `237-03`'s pre-prune snapshot** — proof the phase destroyed nothing,
recorded as a choice rather than a gap.

```bash
$ git stash list --format="%H"
089ced30df5f91ede6c97d7c63076da03758075b
9c959d2274aabee537a8d4ea97ce00cde4a72a18
b15f95edd6ee8dadb964829fe2b44b138028d320
2fc400fd196c08a923599ca4d11d5b353d247221
44e310947ce46140e059d25e453427471e8f4e51
a649b5affa184835eb835fc9e766331b65b446c7
```

These 6 SHAs are byte-identical, in the same order, to the pre-prune snapshot recorded in
`237-GIT-OBJECT-SNAPSHOT.md` (`STASH-ROW|0` through `STASH-ROW|5`) — the same six objects, not
a new set that happens to number six.

No archive refs exist on `origin` — confirmed with a positive control proving the remote is
reachable and the search machinery works:

```bash
$ git ls-remote origin 'refs/stash-archive/*'
# (no output)
$ echo $?
0

$ git ls-remote origin 'refs/heads/main'
b6e889c42af9c0719e9e4b75da1f145ded95700e	refs/heads/main
```

There are no archive refs, no drop, and no post-drop resolvability results in this ledger —
that apparatus was deleted from the plan by D-09, not disabled or left pending.

### No home-directory path in the committed snapshot, with a positive control

```bash
$ grep -qE "/Users/[a-zA-Z0-9._-]+" .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-GIT-OBJECT-SNAPSHOT.md
$ echo $?
1
# no home-directory path present

$ printf '/Users/example/x' | grep -cE '/Users/[a-zA-Z0-9._-]+'
1
# positive control: the same pattern DOES match a synthetic example — the grep and the pattern both work
```

## AFTER-DOCS-SURFACE

Status: pending (local run, this commit — `0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173`)

### The 4 D-01-named dead references are absent, each with a same-block positive control

```bash
$ grep -n '\.planning' lib/sigra/audit.ex
$ echo $?
1
$ grep -c 'defmodule' lib/sigra/audit.ex
1

$ grep -n '\.planning' lib/sigra/testing.ex
$ echo $?
1
$ grep -c 'defmodule' lib/sigra/testing.ex
1

$ grep -n '\.planning' lib/mix/tasks/sigra.fixture.rebless_golden.ex
$ echo $?
1
$ grep -c 'defmodule' lib/mix/tasks/sigra.fixture.rebless_golden.ex
1
```

All three files have zero `.planning` references and a real `defmodule` line — the search
found real files, not empty ones, and found nothing in each.

### The suppression list is at 7 entries

```bash
$ sed -n '/skip_undefined_reference_warnings_on: \[/,/\],/p' mix.exs | grep -c '"'
7
```

```elixir
      skip_undefined_reference_warnings_on: [
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

### `mix docs --warnings-as-errors` exits zero

```bash
$ mix docs --warnings-as-errors
Generating docs...
View html docs at "doc/index.html"
View markdown docs at "doc/llms.txt"
$ echo $?
0
```

## AFTER-RATIONALE-PRESERVED

Status: pending (local run, this commit — `0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173`)

**Re-run at final HEAD, not inherited from plan `237-04`.** Plan `237-05` ran after `237-04`
and edited `mix.exs` and two upgrade guides; this plan's own first claim is that every
observation is taken at final committed HEAD, so this check is re-executed here rather than
citing `237-04`'s earlier `examined_removed_lines=14` result.

### Fixture proofs (RED, discriminating GREEN, fail-closed)

```bash
$ bash .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh \
    .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-security-sentence-deleted.diff
FAIL: removed line(s) carry security/design rationale with no bookkeeping token:
-    # Constant-time comparison prevents timing attacks against the token check.
$ echo $?
1

$ bash .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh \
    .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-bookkeeping-only-deleted.diff
examined_removed_lines=1
$ echo $?
0

$ printf "" | bash .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh -
FAIL: empty diff input — refusing to report success on no input (fail-closed guard)
$ echo $?
1
```

### Real diff at FINAL HEAD, root-anchored pathspec, against `git merge-base origin/main HEAD`

```bash
$ git fetch -q origin main
$ BASE=$(git merge-base origin/main HEAD)
$ echo "$BASE"
b6e889c42af9c0719e9e4b75da1f145ded95700e

$ git diff "$BASE" HEAD -- ':/lib/' | bash .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh -
examined_removed_lines=14
$ echo $?
0
```

`examined_removed_lines=14` — the same real diff plan `237-04` measured, but this is a fresh
invocation of the check at this ledger's own commit, comparing against `merge-base
origin/main HEAD` (root-anchored `:/lib/` pathspec, not the live branch tip and not a
cwd-relative path) — not a citation of `237-04`'s earlier number.

---

## Where measurement superseded the ROADMAP

The ROADMAP entry for Phase 237 predates Phase 236's merge and is stale in the places listed
below (`237-CONTEXT.md`'s own framing: "Where roadmap wording and a measurement conflict, the
measurement wins and the divergence is recorded as a D-NN"). This phase is graded against the
decisions below, not against the original ROADMAP text.

| ROADMAP says (SC-N) | What was measured | Governing decision |
|---|---|---|
| SC-1: `doc/llms.txt` stays tracked "via a `!doc/llms.txt` negation" | That exact negation form is unreachable — git cannot re-include a file beneath an excluded directory. Empirically proven in a throwaway repo. The working form is `/doc/*` + `!/doc/llms.txt`. | **D-06** |
| SC-1: "no untracked `.gsd/`, `.planning/.gsd-ws-arg`, `sigra-*.tar`, `.log` or screenshot artifacts" | `.planning/.gsd-ws-arg` does not exist anywhere in the repo; `sigra-*.tar` was already ignored; the ONLY actually-untracked item was `.gsd/` (268 files, ~660M). The tracked `.log` and `.png` (REPO-01's artifact clause) both live under `.planning/`, which the phase's own out-of-scope fence forbids pruning — kept deliberately, not left unaddressed. | **D-02**, **D-08** |
| SC-1: doc index "still tracked… never deleted", consumers "passing under `mix ci`" | The committed `doc/llms.txt` was stale (`v1.4.0` header vs `mix.exs`'s `1.5.0`; missing `Sigra.Branding.Contrast`) — a plain `mix docs` on a fresh clone would dirty the tracked file, falsifying the clean-tree claim. Regenerated and committed. One of the three named consumers (`scripts/ci/launch-pack-contract.sh`) has **no workflow caller** and does not run "under `mix ci`" as SC-1 implies — it is verified manually and the gap is disclosed rather than claimed as CI coverage. | **D-05**, **D-08** |
| SC-2: "the root `.nojekyll` backstop" plus fixing `code-walkthrough.md:174` | A root `.nojekyll` on `main` was **explicitly rejected** — it would publish the entire repository root (`CLAUDE.md`, `AGENTS.md`, `brandbook/`, `.planning/`) as a public static site. The actual fix repoints the Pages `source` setting to the existing `gh-pages` publish branch, which already has `.nojekyll` — the backstop SC-2 asks for was already satisfied there. The Liquid-crashing line was fixed as defence in depth, not as the mechanism that makes the check green (under the repoint, the legacy builder never parses `main`'s guides at all). | **D-07** |
| SC-3: "all 6 stashes exist as pushed refs on `origin`… `git stash list` is empty" | **Abandoned outright**, not rescoped. `origin` is the public sigra repository; 4 of 6 stashes carry ~2,018 lines of home-directory paths; a push to a public remote is irreversible with respect to content. All 6 stashes stay local and untouched — the inverse of SC-3's literal assertion, recorded as a deliberate operator decision, not a gap. The worktree-prune half of SC-3 (1 live entry, from 6) still proceeded in full. | **D-09** |
| SC-4: "`lib/` doc ranges are clean starting with `lib/sigra/audit.ex:5`" (implying the whole surface) | The full surface is 348 hits / 259 sites / 71 files at research time (337/254/69 after this phase's fix, measured in `237-RATCHET-BASELINE.md`). Only the **4** D-01-named dead `.planning/` references were fixed. The residual ~337 hits are overwhelmingly benign phase-history/decision-ID prose, explicitly handed to Phase 241's `p18` ratchet rather than attempted here — a 71-file low-care prose sweep was recommended against. | **D-01** |
| SC-4: "`mix docs` runs warning-free as a gate" | Already true and already gated in three workflows (`ci.yml`, `release-please.yml`, `hex-publish.yml`) before this phase touched anything — SC-4's "as a gate" clause needed recording, not building. | (pre-existing, recorded not built) |
| SC-4: "every surviving `skip_undefined_reference_warnings_on` entry proven load-bearing by remove-and-retest" | All 9 original entries were already proven load-bearing (remove-and-retest showed 14 warnings covering all 9, zero dead). A genuine, earned reduction was still available: 4 of those 14 warnings were dead `.planning/` links in published guides. Fixed the 3 links, dropped the 2 entries they justified (9→7), corrected the mix.exs comment that falsely called those paths "intentionally relative." | **D-03** |
| SC-5: `` `# SECURITY:`-class `` rationale must not be lost | The literal marker `` `# SECURITY:` `` occurs **zero** times anywhere in the repository (positive-controlled). A guard or check written against that literal string can never fire. The subject was pinned to the regex class `security\|CSRF\|enumeration\|timing\|scope\|impersonation` over `#`-comment lines instead — the class SC-5's own phrasing gestures at but which only the regex, not the literal, actually matches. | **D-04** |



Appended below the six slots above. Recorded in this same ledger file rather than a separate
document, per the plan's instruction to record the gate result "in the ledger's clean-tree
slot, or in a short appended gate section."

**Precondition check, before running:**

```bash
$ pg_isready
/tmp:5432 - accepting connections
$ psql -h localhost -U postgres -c "select 1"
 ?column?
----------
        1
(1 row)
```

Live PostgreSQL confirmed reachable. The pinned application-generator archive was **not**
installed at the CLAUDE.md-named version at the start of this task — the local archive was
`phx_new-1.8.13`, while CI and `mix.exs`-adjacent workflows pin `phx_new 1.8.8` (confirmed:
`grep -rn "phx_new" .github/workflows/ci.yml` shows `mix archive.install --force hex phx_new
1.8.8` at four call sites). This is the exact precondition the plan names — asserted before
running, and corrected rather than reported as a phase regression, using the exact command
CLAUDE.md documents:

```bash
$ mix archive.install --force hex phx_new 1.8.8
Resolving Hex dependencies...
New:
  phx_new 1.8.8
* Getting phx_new (Hex package)
Generated archive "phx_new-1.8.8.ez" with MIX_ENV=prod
* creating /Users/jon/.asdf/installs/elixir/1.19.5-otp-28/.mix/archives/phx_new-1.8.8
```

**`MIX_ENV=test mix ci`, run against commit `0afe33d7f934c5d5fcb35fb063f89a7d0b2c9173`:**

The alias's constituent steps (`mix.exs` `defp aliases`, `ci:`):

```elixir
ci: [
  "format --check-formatted",
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "test --exclude scaffold",
  "ci.install_golden",
  "sigra.dep_off"
]
```

Result recorded below in `## SC verdict` — see that section for the full pass/fail table, the
tree-clean re-assertion, and the documentation-build-leaves-index-untouched re-assertion this
task's closing instruction requires.
