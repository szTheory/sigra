---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 08
subsystem: install-templates
tags: [gap-closure, re-bless, golden-fixture, classifier, surf-01, surf-03, phase-close]
requires:
  - "239-05 (widened V2 definition; login_html.ex `during UAT` fix)"
  - "239-06 (the seven template prose repairs + the three sigra_auth.css comment blocks)"
  - "239-07 (test/example mirror; the tree this re-bless does NOT touch)"
  - "239-comment-only-diff-check.sh (the SC-3 instrument, parameterized here)"
provides:
  - "test/fixtures/install_golden/tree re-blessed and byte-identical to a freshly generated app"
  - "239-golden-expected-2.txt — the round-2 frozen expected-removed set, committed before the run"
  - "fixtures/239-golden-rebless2-code-change.diff — the round-2 known-bad classifier fixture (RED proof)"
  - "239-EVIDENCE.md § REFREEZE-LEDGER, § CLOSURE-OUTCOME, and four HONEST-CLAIMS extensions"
  - "SC-3 and SURF-03 amended with the D-26 carve-out at their own authority locations"
affects:
  - "Phase 239 verification (the criterion a re-verifier applies at final HEAD now matches the topology)"
  - "Phase 241 SURF-04 (tarball lib/ ratchet baseline measured: 475 lines / 84 files)"
tech-stack:
  added: []
  patterns:
    - "Freeze-before-run proven by the commit graph (`git merge-base --is-ancestor`), never by recorded prose"
    - "A non-vacuity floor is re-parameterized to a recorded exact value, never disabled"
    - "Classifier demonstrated RED on a committed known-bad fixture before its green is believed"
    - "Every zero paired with a positive control on the same surface and the same grep invocation"
    - "A measured non-zero is recorded with its disposition rather than rounded to the anticipated 0"
key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-golden-expected-2.txt
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-rebless2-code-change.diff
  modified:
    - test/fixtures/install_golden/tree (7 files)
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-comment-only-diff-check.sh
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
decisions:
  - "The round-2 expected set's N: anchors are the lines REMOVED from priv/templates/ by the closure's own template-edit commits, each searched only inside its own template's golden counterpart. Non-circular (derived from the template edits, not from the diff being validated) and spill-proof."
  - "GOLDEN_MIN_FILES=7 — the exact distinct-path count of the expected set, so the floor stays a real non-vacuity floor. The hardcoded 30 was calibrated to round 1's 35-file diff."
  - "SURF-01 and SURF-03 marked complete at this HEAD on the generated-app and tarball measurements, which is what both requirements actually ask for. SURF-02 left exactly as found — it is Phase 237's and is not this plan's to fix or to unchecked."
  - "The re-bless commit landed only after the classifier returned nonconforming=0 on the captured pre-staging diff, and only after the same classifier was observed exiting 1 on a committed known-bad fixture."
metrics:
  duration: "~95m"
  completed: 2026-09-18
actuals:
  tokens: 11000
  tasks: 4
  commits: 5
status: complete
---

# Phase 239 Plan 08: The Batched Re-bless of the Closure, Re-measured Under the Widened Definition — Summary

Every template edit plans 239-05 and 239-06 made now reaches the golden fixture, the diff that
carried it there was proven comment-only by an instrument first proven able to fail, and the two
authority documents say what the closure actually landed instead of a criterion it would provably
violate.

## What Was Built

### 1. The round-2 expected-removed set, frozen and committed BEFORE the run (Task 1)

`239-golden-expected-2.txt` — **4 `T:` records** (every golden-tree line matched by V2 at the
pre-re-bless HEAD) + **43 `N:` records** (prose repairs V2 cannot match), **47 records across 7
distinct golden paths**. The generating command is the file's `#` header line.

Round 1's set could not be reused: its 139 `T:` records are V1 token lines the round-1 re-bless
already deleted from the tree, so it could not contain round 2's removals *and* could not clear its
own `removed_lines >= 139` floor.

The `N:` anchors are the **48 lines removed from `priv/templates/` by the closure's own template-edit
commits** (`f3c7f700`, `f11dfbe2`), each searched with `grep -nF` only inside that template's golden
counterpart (basename match; `login_html.ex` → `session_html.ex`; `sigra_auth.css` →
`priv/static/assets/sigra_auth.css`). Accounting is exact: **48 anchors = 43 `N:` records + 4
absorbed as `T:` records + 1 with no golden counterpart** (`organization_invitation_email.ex`, which
is why 7 golden files drift and not 8).

One line of the classifier changed:

```
-floor_files=30
+floor_files="${GOLDEN_MIN_FILES:-30}"
```

set to **7** for round 2 — the exact distinct-path count, so the floor is re-calibrated, not
disabled. All four `refusing to report success` fail-closed guards, the literal
`floor_removed="$expected_t_count"`, and the add-only-hunk class are unchanged.

**The freeze is git-provable:** commit `3c0aee2c` lists exactly two paths, nothing under
`test/fixtures/install_golden/`, and `git merge-base --is-ancestor 3c0aee2c 265f7195` exits 0 with
the shas distinct.

### 2. Classifier RED, then the single re-bless, classified GREEN (Task 2)

Precondition recorded: `rebless_golden --check` exited **2**, `DRIFT DETECTED:` on 7 files.

**RED** — `fixtures/239-golden-rebless2-code-change.diff` (commit `fca05dfc`), the captured diff with
one removed line replaced by a real Elixir function head:

```
changed_lines=88  removed_lines=47  files=7
nonconforming=1  nonconforming_removed=1  nonconforming_files=0  nonconforming_addonly_hunks=0
removed_lines_floor=4
FAIL: 1 nonconforming line(s)/path(s)/hunk(s) found:
…/live/invitation_accept_live.ex:-  def handle_event("open_remove_modal", %{"id" => id}, socket) do
exit 1
```

**GREEN** — the real captured `rebless2.diff`, same expected set, same floor:

```
changed_lines=88  removed_lines=47  files=7
nonconforming=0  nonconforming_removed=0  nonconforming_files=0  nonconforming_addonly_hunks=0
removed_lines_floor=4
exit 0
```

`removed_lines=47` ≥ the 4-record `T:` floor and equals the expected set's total record count;
`files=7` ≥ `GOLDEN_MIN_FILES=7`. **No `N:` record was added mid-task** — the set as frozen classified
the diff green on its first and only run.

Commit `265f7195` lists 7 paths, **0 outside `test/fixtures/install_golden/`**, and
`git log --format=%H aa1372cb..HEAD -- test/fixtures/install_golden | wc -l` → **1**.

```
$ MIX_ENV=test mix sigra.fixture.rebless_golden --check
OK: fixture is up-to-date (check mode).      → exit 0
```

### 3. Every live external observation re-run under V2 (Task 3)

| Surface | Measurement | Positive control |
|---|---|---|
| Golden tree, V2 | **0** occurrences (was 4) | **161** `defmodule` files |
| Golden tree, `\.planning/` | **0** | same |
| `STDOUT.txt`, V2 | **0** of 151 lines (D-13 re-checked) | — |
| Freshly generated app, `\.planning/` | **0** | **201** `defmodule` files |
| Freshly generated app, V2 | **10**, all SVG geometry; **0** excluding SVG lines | same |
| Tarball `lib`+`priv`, `\.planning/` | **0** | **540** `defmodule` files |
| Tarball `priv`, V2 | 2 occurrences, both SVG; **0** non-SVG | same |
| Tarball `lib`, V2 | **475 lines / 84 files** → Phase 241 baseline, deferred | same |
| `MIX_ENV=test mix ci` | exit **0** — 33 doctests, 3 properties, **2606 tests, 0 failures**, 12 skipped (22 excluded); example leg **65 tests, 0 failures** | — |
| `git diff --name-only origin/main -- .github/` | empty | — |
| `git diff origin/main -- .github/ \| grep '^[+-].*name:'` | empty | — |
| `237-security-comment-diff-check.sh` over `aa1372cb..HEAD` | `examined_removed_lines=136`, exit **0**, script unmodified | — |

Out-of-scope tarball hits enumerated, not claimed absent: `README.md` 3, `CHANGELOG.md` 390, `docs/`
37 across 6 named files, plus 58 `.planning/` mentions in those same non-`lib`/`priv` surfaces.
SC-1 boundary stated: `install-smoke.sh` never runs `mix sigra.upgrade`, so the three
`priv/templates/sigra.upgrade/` templates are unreachable by that vehicle and are covered by the
tarball observation instead.

REPO-01: `sigra-1.5.0.tar` and the unpacked tree deleted immediately; `/tmp/sigra_239_08_app`
removed; `git status --porcelain` clean.

### 4. SC-3 and SURF-03 amended with the D-26 carve-out (Task 4)

Both now carry the literal `batched re-bless per batch of template edits` at their own authority
locations and both cite `D-26`. `ROADMAP.md` Phase 239 SC-3 still reads `only comment lines` and
still requires a `separate commit`; `REQUIREMENTS.md:84` (the one `**SURF-03**:` line) keeps its
mirror sentence byte-identical (`counterparts of edited templates are mirrored` → 1).

## Deviations from Plan

### Measured departures from acceptance-criterion literals (not defects)

| Criterion | Expected | Measured | Reading |
|---|---|---|---|
| `--check` literal | `OK: fixture is up-to-date (check mode.)` | `OK: fixture is up-to-date (check mode).` | The period is **outside** the parenthesis in the task's actual output. A grep on the quoted form returns 0 and is unsatisfiable. The line, exit code and semantics are otherwise exactly as specified. |
| Generated-app V2 | 0 | **10** | All ten fire one alternation (`\b[0-9]{3}-[0-9]{2}\b`) on SVG `path d=` float coordinates, in `oauth_html.ex:54` (already dispositioned `FALSE-POSITIVE`) and in two **stock Phoenix** files Sigra never authors (`page_html/home.html.heex`, `priv/static/images/logo.svg`). Non-SVG V2 lines: **0**. Recorded rather than rounded, because the 10's harmlessness depends on that disposition. |
| Tarball `priv` V2 | 0 | **2** | Same SVG-geometry class; non-SVG **0**. |
| Tarball `lib` V2 | "472 lines / 83 files" (plan's prohibition text) | **475 lines / 84 files** | The plan quoted the round-1 figure; the closure's own template prose added lines. Recorded as the measured Phase 241 baseline. |
| `N:` records vs anchors | equal counts | 48 anchors → 43 records | Accounted exactly: 4 anchors are `T:` records (they match V2), 1 anchor's template has no golden counterpart. Full mapping table is in § REFREEZE-LEDGER (c). |
| SC-5 structural survivor | possibly `core/auth.ex:530`'s `IN-03` gap | **none** | That removal belongs to the round-1 sweep diff and is not inside `aa1372cb..HEAD`. The instrument limitation is unchanged and stays filed for Phase 241's `p18`. The script was run, never edited (D-16). |

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] The first `MIX_ENV=test mix ci` run was RED on stale `_build`**

- **Found during:** Task 3
- **Issue:** exit 2, 6 failures, all `Sigra.Audit.Forwarders.ThreadlineTest` —
  `function Sigra.Audit.Forwarders.Threadline.attach/1 is undefined`.
- **Diagnosis:** `lib/sigra/audit/forwarders/threadline.ex` wraps its whole `defmodule` in
  `if Code.ensure_compiled(Threadline) == {:module, Threadline}`. The local `_build` held a sigra beam
  compiled while `:threadline` was absent — the run's own log shows `threadline` being fetched and
  compiled *after* sigra. `Code.ensure_compiled(Threadline)` returned `{:module, Threadline}` while
  `Code.ensure_loaded?(Sigra.Audit.Forwarders.Threadline)` returned `false`.
- **Fix:** `MIX_ENV=test mix deps.compile threadline --force && mix compile --force`. **Zero source
  files changed.** This closure touches no file under `lib/sigra/audit/`. Local build staleness, not
  a regression.
- **Files modified:** none
- **Commit:** n/a

### Deliberate departure from the plan's task ordering

Task 4's amendment commit (`9acc49da`) was landed **before** Task 3's evidence commit, so that
`MIX_ENV=test mix ci` ran at the final *code* HEAD rather than at a HEAD the amendment would later
change. The only commit after the `mix ci` run is the evidence file itself, which `mix ci` neither
compiles nor tests. Every Task 3 and Task 4 acceptance criterion is unaffected: the amendment commit
still lists exactly `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md`, and the evidence commit is
still path-scoped to the phase directory.

### Deliberate non-action

`SURF-02` remains `[x]` in `REQUIREMENTS.md` while not holding at HEAD. It is Phase 237's requirement;
239-05's todo (`2026-09-17-surf-02-marked-complete-but-does-not-hold-at-head.md`) is the operator's to
action. Neither fixed nor silently unchecked here, and surfaced in § HONEST-CLAIMS item 3.

## Known Stubs

None. No placeholder, TODO, or deferred wording was introduced. The two enumerated deferrals — the
tarball `lib/` ratchet and the `install_golden_contract` Actions clause — are recorded deferrals with
measured values and named owners, not stubs.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern, or schema change.

| Threat | Status |
|---|---|
| T-239-08-01 (code change absorbed under a comment sweep) | mitigated — diff captured before staging, classified `nonconforming=0`, RED demonstrated first |
| T-239-08-02 (unfalsifiable green from a circular expected set) | mitigated — set derived from the template removals, committed in its own pre-re-bless commit, ordering asserted by `merge-base --is-ancestor` |
| T-239-08-03 (a floor silently disabled) | mitigated — `GOLDEN_MIN_FILES=7` = exact expected-path count; other three guards and the `removed_lines` floor grep-asserted unchanged |
| T-239-08-04 (security rationale deleted across the closure) | mitigated — `examined_removed_lines=136`, exit 0, script unmodified |
| T-239-08-05 (`.github/` `name:` drift) | mitigated — both `.github/` diffs empty |
| T-239-08-06 (claiming adopters are clean) | mitigated — § HONEST-CLAIMS states the fix reaches adopters only at the next publish |
| T-239-08-07 (stray tarball artifacts) | mitigated — `sigra-1.5.0.tar` removed, tree clean; the two April 2026 gitignored tarballs predate this phase and were left rather than silently swept |

## Verification Results

| Check | Result |
|---|---|
| Task 1 `<automated>` | `REFREEZE_OK` |
| Task 2 `<automated>` | `OK: fixture is up-to-date (check mode).` exit 0 |
| Task 3 `<automated>` (`MIX_ENV=test mix ci`) | exit **0**, 2606 tests / 0 failures (+ 65 example tests / 0 failures) |
| Task 4 `<automated>` | `AMENDED` (both greps ≥ 1) |
| Classifier RED on the known-bad fixture | exit **1**, `nonconforming=1`, offending line named |
| Classifier GREEN on the real diff | exit **0**, `nonconforming=0` |
| `git log aa1372cb..HEAD -- test/fixtures/install_golden` | **1** sha |
| Re-bless commit paths outside the fixture dir | **0** |
| `git merge-base --is-ancestor 3c0aee2c 265f7195` | exit **0**, shas distinct |
| `grep -c 'refusing to report success'` | **4** |
| `grep -c 'floor_removed="$expected_t_count"'` | **1** |
| SC-3 / SURF-03 carve-out greps | 1 / 1, both citing D-26 |
| `git status --porcelain` | clean |

## Flagged Assumptions (surfaced, per the plan's frontmatter)

- **SURF-01 edge (dead grep):** every zero above is paired with a positive control on the same
  surface and the same invocation, and the adopter-facing claims are made on generated and built
  bytes. Surfaced, not resolved.
- **SURF-03 edge (commit topology):** the *tension* is resolved — SC-3 and SURF-03 now say what the
  closure landed. The edge probe itself still did not classify, so the assumption stays surfaced.

## Self-Check: PASSED

- `.planning/phases/239-…/239-golden-expected-2.txt` — FOUND
- `.planning/phases/239-…/fixtures/239-golden-rebless2-code-change.diff` — FOUND
- `.planning/phases/239-…/239-EVIDENCE.md` §§ `REFREEZE-LEDGER`, `CLOSURE-OUTCOME`, `HONEST-CLAIMS (extended…)` — FOUND
- `test/fixtures/install_golden/tree` — FOUND, `--check` exit 0
- Commits `3c0aee2c`, `fca05dfc`, `265f7195`, `9acc49da` — all FOUND in `git log`
