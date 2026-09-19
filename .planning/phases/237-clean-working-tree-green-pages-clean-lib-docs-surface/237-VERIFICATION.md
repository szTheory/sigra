---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
verified: 2026-09-19T14:44:34Z
status: passed
score: 5/5 must-haves verified
covered_files:
  - ".gitignore"
  - ".planning/REQUIREMENTS.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-01-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-01-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-02-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-02-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-03-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-03-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-04-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-04-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-05-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-05-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-06-PLAN.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-06-SUMMARY.md"
  - ".planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/COVERAGE.md"
  - "doc/llms.txt"
  - "guides/introduction/code-walkthrough.md"
  - "guides/introduction/upgrading-to-v1.10.md"
  - "guides/introduction/upgrading-to-v1.11.md"
  - "lib/mix/tasks/sigra.fixture.rebless_golden.ex"
  - "lib/sigra/audit.ex"
  - "lib/sigra/testing.ex"
  - "mix.exs"
covered_digest: "v1:sha256:7a6ad347b76e3731b127e2e36497a9271c832e62d3308b7f69594d5fb4151a79"
behavior_unverified: 0
overrides_applied: 2
overrides:
  - must_have: "SC-2 — the published Pages check is green after the operator PUT plus the root `.nojekyll` backstop on the default branch"
    reason: "D-07 (237-CONTEXT.md): a root `.nojekyll` on `main` would publish the entire repository root (CLAUDE.md, AGENTS.md, brandbook/, .planning/) as a public static site. The backstop SC-2 asks for already exists on the `gh-pages` publish branch; the fix repoints Pages `source` there instead. Re-observed live: source.branch=gh-pages, status=built, URL 200."
    accepted_by: "operator (standing autonomy, v1.48 milestone)"
    accepted_at: "2026-09-16"
  - must_have: "SC-3 — all 6 stashes exist as pushed refs on `origin` and `git stash list` is empty"
    reason: "D-09 (237-CONTEXT.md, operator decision 2026-09-16): `origin` is the PUBLIC sigra repository and 4 of the 6 stashes carry ~2,018 lines of home-directory paths; a push to a public remote is irreversible with respect to content. The stash half is deliberately abandoned — all 6 stashes remain local and untouched at SHAs byte-identical to the pre-prune snapshot, proving the phase destroyed nothing. The worktree half proceeded in full (6 -> 1)."
    accepted_by: "operator (D-09)"
    accepted_at: "2026-09-16"
deferred:
  - truth: "The `lib/` documentation-attribute bookkeeping surface is fully clean (residual 337 hits / 254 sites / 69 files, incl. the bare `(D-01)`/`(D-17..D-18)` citations left in `lib/sigra/audit.ex`'s moduledoc — code-review IN-02)"
    addressed_in: "Phase 241"
    evidence: "ROADMAP Phase 241: 'Retire v1.47's Dishonest Debt + Adopter-Leakage Guard'; D-01 hands the residual to Phase 241's `p18` monotonic-decrease docs-surface ratchet, and 237 recorded the reproducible baseline in 237-RATCHET-BASELINE.md (re-run independently at HEAD: total_hits=337, distinct_sites=254, distinct_files=69 — exact match)."
  - truth: "No dead `.planning/` reference ships into an adopter's generated app (`priv/templates/sigra.install/organizations/organizations.ex:59`, code-review WR-01)"
    addressed_in: "Phase 239"
    evidence: "ROADMAP Phase 239 SC-1 names this exact path: 'including `priv/templates/sigra.install/organizations/organizations.ex:59`, the one dead `.planning/` path that ships into every adopter's project today.' Also fenced explicitly in 237-CONTEXT.md 'Phase-boundary fences'. Filed as todo 2026-09-16-installer-template-ships-a-dead-planning-link-to-every-adopter.md."
advisory:
  - finding: "Published HexDocs *extras* (9 files under `guides/`) still reference `.planning/` paths — mostly as absolute GitHub blob URLs to real, public files, plus prose mentions. Not dead rot, and outside SURF-02's `@moduledoc`/`@doc` scope, but it means the phase GOAL's broad clause ('HexDocs pages that carry no internal planning bookkeeping') is satisfied for module docs only. Phase 241's ratchet baseline scans `lib/` only, so this extras surface is currently baselined nowhere."
    category: other
    reason: "Raised so a later phase can decide whether the `p18` ratchet's scope should include `guides/`. No deterministic failure: `mix docs --warnings-as-errors` exits 0 and every link sampled resolves."
    evidence_status: "none provided"
  - finding: "Code-review WR-02 (lossy removal of three guide pointers, incl. a conditional left with no consequent in `upgrading-to-v1.10.md:9`) and WR-03 (walkthrough excerpt now diverges from the template it quotes, unguarded by `@source_anchors`). Both are quality regressions in published documentation introduced by this phase."
    category: other
    reason: "Both filed as pending todos (2026-09-16-upgrade-guide-link-removal-was-lossy-*, 2026-09-16-walkthrough-excerpt-diverges-*). Neither breaks a must-have or a gate; a lossless fix using the repo's existing absolute-blob-URL convention is available."
    evidence_status: "none provided"
---

# Phase 237: Clean Working Tree, Green Pages, Clean `lib/` Docs Surface — Verification Report

**Phase Goal:** A maintainer who clones Sigra fresh sees a clean `git status`, a Pages check that is green because the site builds, and HexDocs pages that carry no internal planning bookkeeping.
**Verified:** 2026-09-19
**Status:** passed (5/5, 2 via recorded decision overrides)
**Re-verification:** Yes — automation-first refresh after summary and API-coverage reconciliation
**Verified at HEAD:** `3dd5977d` (targeted product and live-service seams re-executed; scoped verification artifacts pending commit)

The 2026-09-19 refresh replaced conversational UAT with 21 deterministic checks in
`237-UAT.md`. It also added the seal-time GitHub API coverage matrix and reclassified four
historical shared-tree commit counters as legacy metadata: their plan-specific hashes and prose
remain intact, while they no longer pretend that an ever-growing `plan_head_before..HEAD` range
is a stable per-plan ledger.

Every observation below was **independently re-executed by the verifier** against the live
codebase at `b5c8b55e` — not read out of a SUMMARY. Where an absence is claimed, a positive
control from the same run is shown, per this phase's own standing rule.

Ledger-integrity precondition confirmed first: `237-EVIDENCE.md` names
`Observed at commit: 0afe33d7`; `git merge-base --is-ancestor 0afe33d7 HEAD` → yes, and
`git diff --name-only 0afe33d7 HEAD | grep -v '^\.planning/'` → empty. Every commit after the
ledger's observation point touches `.planning/` only, so the ledger's `mix ci` and gate results
remain statements about the shipped tree.

## Goal Achievement

### Observable Truths

| # | Truth (ROADMAP SC, as governed by D-01..D-09) | Status | Evidence (verifier-run) |
|---|---|---|---|
| 1 | **SC-1 / REPO-01 / REPO-02** — a fresh clone reports a clean `git status`; `doc/llms.txt` stays tracked via a *reachable* negation; its three consumers pass | ✓ VERIFIED | Real `git clone file://$(pwd)` into a temp dir → `git status --porcelain --untracked-files=all` produced **no output**; `git ls-files doc/llms.txt` → tracked inside the clone. `git check-ignore -q --no-index doc/llms.txt` → **exit 1** (un-ignored) with same-run positive control `doc/index.html` → **exit 0** (the ignore machinery discriminates). `.gitignore:14-15` = `/doc/*` + `!/doc/llms.txt` (D-06 working form); `.gitignore:73` = `/.gsd/`, and `git check-ignore -v .gsd/` → `.gitignore:73:/.gsd/` while the directory still exists on disk (ignored, not deleted). `mix docs` → `git diff --exit-code -- doc/llms.txt` → **exit 0** (index is idempotent at HEAD). Consumers: `MIX_ENV=test mix test phase_148_* phase_149_*` → **7 tests, 0 failures**; `bash scripts/ci/launch-pack-contract.sh` → `OK`, exit 0. |
| 2 | **SC-2 / GREEN-03** — Pages reports built (not errored) and the published URL serves | ✓ VERIFIED | Live, this session: `gh api repos/szTheory/sigra/pages --jq '{status,build_type,source}'` → `{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"status":"built"}`; `builds/latest` → commit `29e6ad40`, status `built`. `curl -o /dev/null -w %{http_code} https://sztheory.github.io/sigra/` → **200**, with negative control on `/__nope__` → **404** (the assertion can fail). Liquid crash de-fanged: `grep -n '{%' guides/introduction/code-walkthrough.md` → **no match**, control `grep -c '```'` → 30 (the file and the search are real). Root `.nojekyll` correctly **absent** from the default branch (D-07 rejected option): `ls .nojekyll` → no such file; `git ls-files .nojekyll` → empty. |
| 3 | **SC-3 / REPO-03** — worktrees pruned to the live one; stash half deliberately abandoned | ✓ VERIFIED (worktree) + PASSED (override, D-09, stash) | `git worktree list` → **exactly 1 entry** (`<HOME>/projects/sigra b5c8b55e [main]`). `git stash list --format=%H` → **6 SHAs, byte-identical and in the same order** to `STASH-ROW|0..5` in the committed `237-GIT-OBJECT-SNAPSHOT.md` — the same six objects, nothing destroyed, nothing rewritten. `git ls-remote origin 'refs/stash-archive/*'` → no output (exit 0), with positive control `git ls-remote origin refs/heads/main` → `b6e889c4` (the remote is reachable and the query works) — i.e. nothing was pushed to the public remote. Snapshot sanitization: `grep -cE "/Users/[a-zA-Z0-9._-]+"` on the committed snapshot → **0**. |
| 4 | **SC-4 / SURF-02** — nothing rendered from `lib/` doc attributes carries dead planning links; `mix docs` is warning-free as a gate; the suppression list is earned down | ✓ VERIFIED | `grep -rn '\.planning/' lib/` → **no output**, with positive control `grep -c defmodule` on all three edited files → 1 each (the files are real and non-empty). Suppression list re-counted from `mix.exs`: **7 entries** (was 9); the comment heading it no longer claims the removed paths are "intentionally relative". `mix docs --warnings-as-errors` → **exit 0**. The gate clause was pre-existing (4 workflow files reference `warnings-as-errors`) and `git diff <merge-base> HEAD --name-only -- .github/` → **empty**, so no fourth gate was bolted on. |
| 5 | **SC-5** — the phase diff deletes no security/design rationale | ✓ VERIFIED | Re-ran all four cases myself against `237-security-comment-diff-check.sh`: RED fixture → exit **1**, naming `# Constant-time comparison prevents timing attacks…`; bookkeeping-only fixture → `examined_removed_lines=1`, exit **0** (discriminating, not always-green); empty stdin via `-` → `FAIL: empty diff input` exit **1** (fail-closed on the exact channel the real run uses); real diff `git diff $(git merge-base origin/main HEAD) HEAD -- ':/lib/'` → `examined_removed_lines=14`, exit **0**. Class count independently re-measured: 52 security-rationale comment lines in `lib/` — the same number the ratchet baseline records. |

**Score:** 5/5 truths verified (0 present, behavior-unverified). Two of the five carry a
recorded, rationale-bearing decision override (D-07, D-09) rather than literal SC satisfaction.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Residual `lib/` doc-attribute bookkeeping (337 hits / 254 sites / 69 files), incl. the bare `(D-NN)` citations in `lib/sigra/audit.ex` | Phase 241 | D-01 + ROADMAP Phase 241 `p18` ratchet; baseline recorded and independently reproduced at HEAD |
| 2 | `priv/templates/.../organizations.ex:59` dead `.planning/` link shipping to adopters (review WR-01) | Phase 239 | ROADMAP Phase 239 SC-1 names this exact file:line; fenced in 237-CONTEXT.md; todo filed |

### Advisory (New Scope, Unevidenced)

| # | Finding | Category | Why Advisory |
|---|---------|----------|--------------|
| 1 | 9 published `guides/` extras still carry `.planning/` references (live absolute blob URLs + prose), baselined nowhere | other | outside SURF-02's `@moduledoc`/`@doc` scope; no gate fails; raised for Phase 241 scope-setting |
| 2 | Review WR-02 (lossy guide-pointer removal, dangling conditional) and WR-03 (walkthrough↔template divergence) | other | both filed as pending todos; neither breaks a must-have or a gate |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `.gitignore` | `/doc/*` + `!/doc/llms.txt`, `/.gsd/` | ✓ VERIFIED | both present and *effective* (check-ignore exits re-observed) |
| `doc/llms.txt` | tracked, regenerated, idempotent | ✓ VERIFIED | tracked in a fresh clone; `mix docs` leaves it byte-identical |
| `mix.exs` | suppression list 9 → 7, corrected comment | ✓ VERIFIED | 7 entries counted; review's independent empty-list probe showed the 7 are minimal and complete |
| `lib/sigra/audit.ex`, `lib/sigra/testing.ex`, `lib/mix/tasks/sigra.fixture.rebless_golden.ex` | 4 dead `.planning/` refs removed, prose still standing | ✓ VERIFIED | zero `.planning/` hits with positive controls; surrounding prose reads as complete sentences |
| `guides/introduction/upgrading-to-v1.10.md`, `-v1.11.md` | 3 dead links gone | ✓ VERIFIED | no dead-target links remain; prose `.planning/` mentions retained deliberately (D-03/237-05 prohibition) |
| `guides/introduction/code-walkthrough.md` | Liquid-hostile `{%` gone, semantics unchanged | ✓ VERIFIED | no `{%` in file; redirect target + query payload unchanged (extraction only); enumeration-rationale comment survives verbatim |
| `237-PAGES-SETTING-RECORD.md` | prior Pages config recorded before the change | ✓ VERIFIED | records `main`/`/` prior value + exact revert PUT |
| `237-GIT-OBJECT-SNAPSHOT.md` | pre-prune inventory, sanitized | ✓ VERIFIED | 6 worktree rows + 6 stash rows; 0 home-directory paths |
| `237-EVIDENCE.md` | six parseable slots at final HEAD | ✓ VERIFIED | all six `BEFORE-`/`AFTER-` slots present with `Status:` lines and instrument-invoking fenced blocks |
| `237-RATCHET-BASELINE.md` + `237-docs-attribute-scan.py` | reproducible number for Phase 241 | ✓ VERIFIED | re-ran the committed scanner: 337/254/69 — exact match to the recorded baseline |
| `237-security-comment-diff-check.sh` + 2 fixtures | RED-proven, discriminating, fail-closed | ✓ VERIFIED | all four cases re-run by the verifier (see truth 5) |
| 2 required todos (+5 total filed) | exist under `.planning/todos/pending/` | ✓ VERIFIED | both D-required todos present, plus the 3 review findings |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `.gitignore` glob form | `doc/llms.txt` on disk | `git check-ignore --no-index` exit 1 | ✓ WIRED | negation genuinely reachable; control proves discrimination |
| committed `doc/llms.txt` | clean-tree claim | `mix docs` idempotence | ✓ WIRED | `git diff --exit-code` exit 0 after a real docs build |
| Pages `source` setting | what the legacy builder renders | `gh api` + live HTTP | ✓ WIRED | `gh-pages` / `built` / 200, with a 404 control |
| `git worktree prune`/`remove` | `.git/worktrees/` admin records | `git worktree list` | ✓ WIRED | 1 entry; snapshot discloses that entries 2–3 needed `git worktree remove` (git-native, never `rm -rf` first) |
| D-09 no-push/no-drop | stash objects alive locally | `git stash list --format=%H` vs snapshot | ✓ WIRED | 6/6 SHAs identical |
| regex-class check | this phase's real `lib/` diff | `237-security-comment-diff-check.sh -` | ✓ WIRED | `examined_removed_lines=14`, exit 0, RED-proven |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Fresh clone is clean | `git clone file://$(pwd) tmp && git status --porcelain -uall` | (no output) | ✓ PASS |
| Docs build is a warning-free gate | `mix docs --warnings-as-errors` | exit 0 | ✓ PASS |
| Docs index does not drift | `mix docs && git diff --exit-code -- doc/llms.txt` | exit 0 | ✓ PASS |
| `doc/llms.txt` consumers pass | `MIX_ENV=test mix test phase_148_… phase_149_…` | 7 tests, 0 failures | ✓ PASS |
| Launch-pack contract | `bash scripts/ci/launch-pack-contract.sh` | `OK`, exit 0 | ✓ PASS |
| Rationale guard fires (RED) | check vs `237-security-sentence-deleted.diff` | exit 1, names the line | ✓ PASS |
| Rationale guard discriminates | check vs `237-bookkeeping-only-deleted.diff` | exit 0, `examined_removed_lines=1` | ✓ PASS |
| Rationale guard fails closed | `printf "" \| check -` | exit 1 | ✓ PASS |
| Ratchet baseline reproduces | `python3 237-docs-attribute-scan.py lib` | 337/254/69 | ✓ PASS |
| Pages serves | `curl -w %{http_code} https://sztheory.github.io/sigra/` | 200 (control 404) | ✓ PASS |

`MIX_ENV=test mix ci` was **not** re-run by the verifier: the ledger records a green run
(0 failures, exit 0) at `0d630f0c`, every subsequent commit touches `.planning/` only
(verified above), the orchestrator independently re-ran `mix compile --warnings-as-errors`
→ exit 0, and CLAUDE.md's known local-DX bug makes a naive re-run deterministically red on 6
`ThreadlineTest` cases (already filed as a todo). Re-running would have produced no new
evidence and one known-false red.

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| `237-security-comment-diff-check.sh` (phase-local instrument) | `bash … <fixture>` / `… -` | see spot-checks | PASS (3/3 cases) |
| `scripts/ci/launch-pack-contract.sh` | `bash …` | `OK` | PASS |

No `scripts/*/tests/probe-*.sh` exist for this phase; the phase declares none.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| GREEN-03 | 237-02, 237-06 | Pages builds successfully; legacy builder no longer renders `main`'s root | ✓ SATISFIED | live `gh api` → `gh-pages`/`built`; URL 200; `{%` removed from the guide |
| REPO-01 | 237-01, 237-06 | Clean `git status` on a fresh checkout; `.gsd/` ignored; stray artifacts resolved | ✓ SATISFIED | real clone → empty status; `/.gsd/` ignore rule effective; tracked `.log`/`.png` live under `.planning/` and are kept by named exception (D-02) |
| REPO-02 | 237-01, 237-06 | `doc/llms.txt` conflict resolved by negation, consumers keep passing | ✓ SATISFIED | negation reachable (D-06 form); 7 consumer tests pass; contract script OK (disclosed as manual-only, no workflow caller — control-proven) |
| SURF-02 | 237-04, 237-05, 237-06 | No planning bookkeeping in HexDocs-rendered `@moduledoc`/`@doc`; `mix docs` warning-free as a gate; suppression list pruned | ✓ SATISFIED | zero `.planning/` in `lib/`; list 9→7 earned by fixing the underlying rot; `mix docs --warnings-as-errors` exit 0 |
| REPO-03 | 237-03, 237-06 | 6 stashes materialized as pushed refs; 5 stale worktrees removed before any branch deletion; no `git gc` | ✓ SATISFIED (worktree half) / PASSED (override D-09, stash half) | 1 worktree; 6 stashes intact at identical SHAs; no remote archive refs (control-proven); no branch deleted; no gc/reflog/prune evidenced by object survival |

No ORPHANED requirements: REQUIREMENTS.md maps exactly GREEN-03, REPO-01, REPO-02, REPO-03,
SURF-02 to Phase 237, and all five appear in plan frontmatter (237-06 claims all five).

### Prohibition Checks (must-NOTs, with enforcement evidence)

| Prohibition (plan) | Status | Evidence |
|---|---|---|
| MUST NOT delete/untrack `doc/llms.txt` (01) | ✓ NOT VIOLATED | tracked in a fresh clone |
| MUST NOT use the unreachable bare `!doc/llms.txt` form (01) | ✓ NOT VIOLATED | `.gitignore` uses `/doc/*` + `!/doc/llms.txt`; check-ignore exit 1 |
| MUST NOT delete the tracked `.log`/`.png` under `.planning/` (01) | ✓ NOT VIOLATED | both still tracked; phase diff touches neither |
| MUST NOT add a root Jekyll-bypass file to the default branch (02) | ✓ NOT VIOLATED | `.nojekyll` absent from root and from `git ls-files` |
| MUST NOT modify `ensure-github-pages-legacy-branch.sh` or close #231 (02) | ✓ NOT VIOLATED | `git diff <merge-base> HEAD -- scripts/` → empty |
| MUST NOT change the walkthrough snippet's Elixir semantics (02) | ✓ NOT VIOLATED | map extracted to a bound variable; redirect target and query payload identical |
| MUST NOT push/drop/clear any stash; MUST NOT push stash objects to any remote (03) | ✓ NOT VIOLATED | 6/6 SHAs identical to snapshot; `refs/stash-archive/*` empty on origin with a reachability control |
| MUST NOT run `git gc` / `reflog expire` / `prune --now` (01, 03) | ✓ NOT VIOLATED | all six stash objects still resolvable at their original SHAs — the observable consequence had any run |
| MUST NOT `rm -rf` a worktree before pruning (03) | ✓ NOT VIOLATED | snapshot documents `git worktree prune` for 3 entries and git-native `git worktree remove` for the 2 live-directory entries (disclosed, not concealed) |
| MUST NOT commit a home-directory path (03) | ✓ NOT VIOLATED | `grep -cE "/Users/[a-z…]+"` on the snapshot → 0 |
| MUST NOT delete any branch (03) | ✓ NOT VIOLATED | no branch operations in the phase diff; `origin/main` intact |
| MUST NOT guard on the literal `# SECURITY:` (04) | ✓ NOT VIOLATED | the committed check uses the D-04 regex class, proven RED |
| MUST NOT edit `lib/sigra/admin/live/audit_index_live.ex` (04) | ✓ NOT VIOLATED | absent from the phase diff (Phase 236's file) |
| MUST NOT add a durable guard under `scripts/ci/prohibitions/` (04) | ✓ NOT VIOLATED | `scripts/` unchanged in the phase diff |
| MUST NOT remove a suppression entry whose warnings were not fixed at source (05) | ✓ NOT VIOLATED | `mix docs --warnings-as-errors` exit 0 with the shorter list; review's empty-list probe shows the 7 survivors are exactly load-bearing |
| MUST NOT add a fourth docs gate (05) | ✓ NOT VIOLATED | `.github/` unchanged in the phase diff |
| MUST NOT replace dead links with absolute URLs to the same non-existent docs (05) | ✓ NOT VIOLATED | links removed, not re-pointed (see WR-02 advisory for the quality cost) |
| MUST NOT fix anything the new todos describe (06) | ✓ NOT VIOLATED | todos filed; the described defects are still present in-tree |

Every prohibition above resolves against a direct, reproducible observation rather than a
SUMMARY assertion, so none is left as an unverified/flagged must-NOT.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `lib/sigra/audit.ex` | 7-14 | Bare `(D-01)`, `(D-02)`, `(D-17..D-18)`, `(D-20)` decision IDs rendered on HexDocs with no resolvable referent | ℹ️ Info | Part of the 337-hit residual D-01 explicitly hands to Phase 241; `lib/sigra/testing.ex` took the opposite (better) treatment in the same diff |
| `guides/introduction/upgrading-to-v1.10.md` | 9 | Conditional clause whose imperative was deleted ("If you have not followed v1.9 … note that v1.10 builds on that baseline") | ⚠️ Warning | Published guide reads as a non-instruction; lossless absolute-URL fix is precedented in-repo; todo filed |
| — | — | No `TBD` / `FIXME` / `XXX` debt markers introduced | ✓ | `git diff <merge-base> HEAD` over changed non-planning files carries none |

### Human Verification Required

None. Every truth resolved against a deterministic, verifier-executed observation, and every
prohibition carries direct enforcement evidence. The two deviations from literal ROADMAP SC
text are pre-recorded operator decisions (D-07, D-09) with rationale, and are carried as
overrides rather than gaps.

### Gaps Summary

No gaps. The phase goal is achieved as governed by its recorded decisions:

- **Clean `git status` on a fresh clone** — proven by performing the clone, not by a proxy.
- **Pages green because the site builds** — proven by a live API read-back plus a real HTTP
  200 with a 404 control, and green for the right reason (the `source` root cause, not the
  Liquid symptom, which was fixed anyway as defence in depth).
- **HexDocs pages carrying no internal planning bookkeeping** — fully true for the `lib/`
  doc-attribute surface that SURF-02 names (zero `.planning/` references, control-proven), and
  *partially* true for the broader docs site: 337 benign residual hits in `lib/` prose and 9
  `guides/` extras with (live, resolvable) planning links remain, explicitly and traceably
  handed to Phase 241's `p18` ratchet with a reproducible baseline this verifier re-derived
  independently. That is a scoped handoff with a named successor, not an unaddressed miss.

The one finding that could have undermined the goal — code-review WR-01, the dead `.planning/`
link that ships to every adopter via `mix sigra.install --organizations` — sits in
`priv/templates/`, which is not a HexDocs-rendered surface (the generated docs contain no
module page for it), and is named verbatim in ROADMAP Phase 239's SC-1. It is deferred, not a
gap against Phase 237.

---

_Verified: 2026-09-16_
_Verifier: Claude (gsd-verifier)_
