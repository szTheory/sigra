# Phase 239 Evidence Ledger

Slot-heading convention: `^## [A-Z0-9-]+$` heading, `Status:` line beneath (Phase 238 precedent).

## PREFLIGHT-UNION-LEDGER
Status: PASS — HEAD numbers match the 239-RESEARCH.md / 239-CONTEXT.md ledger exactly; the tree has
not moved since research was captured. This is the phase's first action, run before any template
edit.

- HEAD sha: `ebc5d9-e148cd-814fa1-b679a8-a74c0e-ab921e-c7b4` (hyphen-chunked for readability and to
  avoid a second hex-token match colliding with the WAVE0-COMMIT sha lookup below — concatenate the
  segments to recover the 40-char sha; it is also `git log -1` output at the time this ledger's
  first section was written, on branch `main`)
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
- Plan 239-02 should cite the commit sha recorded above (the single one in this file's "Commit
  sha:" bullet) as the pre-sweep baseline sha when it reports SC-3.

## SWEEP-COMMIT
Status: DONE — commit 1 of the D-19 three-commit topology lands, provably confined to
`priv/templates/`, driving the union grep to zero across all 119 tracked template files in all
three generators.

- Commit sha (hyphen-chunked to keep exactly one full 7-40-char hex token in this file, per the
  239-01 SIGPIPE-avoidance fix — concatenate the segments to recover the 40-char sha):
  `cafd9a-5328b5-f08f31-5a123f-d874d2-698831-7537`
- Subject: `refactor(239): strip planning bookkeeping from priv/templates (SURF-01, SURF-03)`
- Before/after union-token counts: **158 -> 0** across `priv/templates/` (46 files touched, 119
  tracked template files enumerated by `git ls-files priv/templates`).
- `git show --name-only --format= HEAD` at that commit lists exactly 46 paths, every one under
  `priv/templates/`.
- `git diff --name-only origin/main -- .github/` is empty — no `.github/` drift introduced.
- `MIX_ENV=test mix compile --warnings-as-errors` is clean (no warning, no error) after the sweep.
- All five D-03 deliberate exclusions (`policy.ex` TODO, `mfa_challenge_live.ex` XXXX-XXXX,
  `sigra_auth.css` v1.46 compat prose, `scope.ex` UPGRADE-v1.2.md pointer, arity/version strings)
  survive verbatim, confirmed by grep against the post-sweep tree.

**Documented instrument limitation (not a regression):** `237-security-comment-diff-check.sh`
(SC-5b), run against this commit's full diff, reports exactly one survivor:
`core/auth.ex:530`'s pre-sweep line `# token clause so security signals are preserved (10.1
IN-03). Tokens`. This is structural, not fixable by rewording: SC-5b's tolerance regex recognizes
only `D-[0-9]{2}`, `SC-[0-9]+`, and `Phase [0-9]{1,3}` co-occurring on the SAME removed line as a
rationale word — it does not recognize `IN-[0-9]{2}`. Any edit to this line necessarily marks the
current HEAD text as "removed" in the diff (unified diff is line-granular), and that HEAD text
already carries "security" + "IN-03" with no SC-5b-recognized token, regardless of what replaces
it. The only tokens SC-5b would tolerate (`D-NN`, `SC-N`, `Phase N`, `.planning/`) are themselves
union-grep tokens this phase must remove, so no rewording of the AFTER text can satisfy both
instruments simultaneously for this one line. Per plan-level constraint D-16, `237-security-
comment-diff-check.sh` was not modified to close this gap. Verified via three independent repro
attempts (isolated single-file diff, six-file partial diff, full sweep-commit diff) — all three
report the identical single survivor and no other. The rationale sentence "security signals are
preserved" is intact in the AFTER text and `IN-03` is fully gone from the file, satisfying the
plan's actual SURF-01/SURF-03 intent; only the SC-5b instrument's advisory tolerance-regex gap is
unresolved, and it is advisory tooling per its own header ("deliberately NOT wired into any
workflow or prohibitions glob"). A second near-identical case
(`organizations/live/organization_settings_live.ex` "enumeration safety" / D-04 window merge) was
found and avoided during execution by leaving the rationale-bearing line untouched and editing
only the adjacent token-only line, keeping that one out of SC-5b's removed-line set entirely —
demonstrating the fix is possible whenever the token and rationale word do not already share HEAD's
one physical line, which is not the case for `auth.ex:530`.
