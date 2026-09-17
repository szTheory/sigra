# Phase 239 Evidence Ledger

Slot-heading convention: `^## [A-Z0-9-]+$` heading, `Status:` line beneath (Phase 238 precedent).

## PREFLIGHT-UNION-LEDGER
Status: PASS — HEAD numbers match the 239-RESEARCH.md / 239-CONTEXT.md ledger exactly; the tree has
not moved since research was captured. This is the phase's first action, run before any template
edit.

- HEAD sha: `ebc5d9e148cd814fa1b679a8a74c0eab921ec7b4` (branch `main`)
- `git status --porcelain` at measurement time:
  ```
   M .planning/STATE.md
   M .planning/state.json
  ```
  (only `.planning/` bookkeeping files modified — precondition for this task was verified met
  before any measurement was taken)

Union regex (one definition, per the plan's "The union regex" section):

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b
```

Exact commands run and their output:

```bash
U='\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b'
grep -nE "$U" $(git ls-files priv/templates) | wc -l    # => 158
grep -lE "$U" $(git ls-files priv/templates) | wc -l    # => 46
grep -nE "$U" $(git ls-files test/fixtures/install_golden/tree) | wc -l   # => 139
grep -lE "$U" $(git ls-files test/fixtures/install_golden/tree) | wc -l   # => 35
```

Measured HEAD numbers:

| Surface | Union lines | Union files |
|---|---|---|
| `priv/templates/` | **158** | **46** |
| `test/fixtures/install_golden/tree/` (golden) | **139** | **35** |

All four numbers match `239-RESEARCH.md` §2/§3 exactly. No divergence — the phase proceeds on the
research ledger's numbers without adjustment.

**Positively-asserted favourable context (not silently dropped):**

- `test/fixtures/install_golden/STDOUT.txt` carries **zero** union-token lines today
  (`grep -cE "$U" test/fixtures/install_golden/STDOUT.txt` => `0`). The D-13 independent-drift
  hazard (STDOUT.txt drifting separately from `tree/`) is measured-nil for this phase's starting
  point. This will be checked again, separately, in plan 239-04 after the sweep and re-bless land.
- `git diff --name-only origin/main -- .github/` is **empty** (0 lines). SC-5a ("no `.github/` edit
  in scope") has a genuine zero baseline today, needing no carve-out or waiver.

## WAVE0-COMMIT
Status: DONE — the wave-0 instruments are committed and their commit provably touches nothing
outside the phase directory.

- Commit sha: `a1bb08c6fc498fa6861012485a948a58ba6a2db4`
- Subject: `docs(239): wave-0 SC-3 classifier, frozen expected set, preflight ledger`
- `git show --name-only --format= HEAD` (at that commit) lists exactly six paths, all under
  `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/`:
  - `239-EVIDENCE.md`
  - `239-comment-only-diff-check.sh`
  - `239-golden-expected.txt`
  - `fixtures/239-golden-add-only-hunk.diff`
  - `fixtures/239-golden-code-change.diff`
  - `fixtures/239-golden-comment-only.diff`
- `git diff --quiet HEAD -- priv/templates test/example test/fixtures .github mix.exs lib` exits 0
  at that commit — no source surface is dirty.
- `test/fixtures/prohibitions/` carries no change attributable to this phase (D-04; that directory
  belongs to Phase 241).
- Plan 239-02 should cite `a1bb08c6fc498fa6861012485a948a58ba6a2db4` as the pre-sweep baseline sha
  when it reports SC-3.
