# 241-06 evidence — doc-range hard-fail and independent ratchets

## Doc-range port and hard-fail

```sh
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p18-doc-range-leak.ex node --test scripts/ci/prohibitions/p18-doc-range.test.mjs
```

Exited non-zero from the hard-fail assertion and named
`test/fixtures/prohibitions/p18-doc-range-leak.ex:3: .planning/`.

```sh
node --test --test-reporter=tap scripts/ci/prohibitions/p18-doc-range.test.mjs
```

Passed; the live scan found 655 doc ranges in 161 tracked library files and zero hard-fail hits.
At this execution HEAD, the zero-at-HEAD hard-fail subset is `.planning/`, `-PLAN.md`,
`-SUMMARY.md`, `todos/`, lowercase `phase-N`/`phase_N`, `SC-N`, `REQ-*`, and `INV-N`. The
remaining nonzero categories are capitalized `Phase N` (67), `D-NN` (259), `Pitfall N` (10), and
`-CONTEXT.md` (1). They remain measured by R1 and are not hard-failable at this HEAD. This hard
fail asks whether a planning artifact appeared where none existed; R1 asks whether historical
bookkeeping is shrinking.

```sh
python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib
node --input-type=module -e 'import {docRangeTotal} from "./scripts/ci/prohibitions/_p18-lib.mjs"; console.log(docRangeTotal("lib"))'
```

The committed Python scanner printed `total_hits=337`; the synchronous JS port printed `337`.

## Execution-HEAD ratchet baselines

The committed baseline is R1=337, R2=220, R3=58. These are three separate values, surfaces,
definitions, and tests; equality passes, decreases pass, increases fail, and zero is not the target.

```sh
node --input-type=module -e 'import {docRangeTotal} from "./scripts/ci/prohibitions/_p18-lib.mjs"; console.log(docRangeTotal("lib"))'
node --input-type=module -e 'import {libraryCommentBookkeepingLines} from "./scripts/ci/prohibitions/_p18-lib.mjs"; console.log(libraryCommentBookkeepingLines())'
node --input-type=module -e 'import {packagedPlanningPathOccurrences} from "./scripts/ci/prohibitions/_p18-lib.mjs"; console.log(packagedPlanningPathOccurrences())'
```

Outputs: `337`, `220`, and `58` respectively.

```sh
rg -n -i '^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b' lib/ | wc -l
```

Output: `52`. Any future R2 reduction must re-run this separate rationale count and confirm it did
not fall.

```sh
node --input-type=module -e 'import {execFileSync} from "node:child_process"; import {readFileSync} from "node:fs"; import {BOOKKEEPING_REGEX_SOURCE} from "./scripts/ci/prohibitions/_p18-lib.mjs"; const files=execFileSync("git",["ls-files","--","lib"],{encoding:"utf8"}).split("\n").filter(f=>/\.exs?$/.test(f)); for(const flags of ["","i"]){const v=new RegExp(BOOKKEEPING_REGEX_SOURCE,flags); let n=0; for(const f of files)for(const l of readFileSync(f,"utf8").split("\n"))if(/^\s*#/.test(l)&&v.test(l))n++; console.log(`flags=${flags||"default"} count=${n}`)}'
```

Output: default vocabulary `220`; case-folding the full vocabulary `221`, an upper bound of one
additional comment line for the proposed plan-reference case-folding. The other proposed widening,
block-aware matching, remains unmeasured and carries cross-line false-positive risk. Both widenings
are declined for v1.48 (D-29); the lowercase plan reference in
`test/example/priv/playwright/tests/golden-path.spec.ts:59` remains outside the defined surfaces.
The pending todo is annotated as partially folded and remains pending.

## Independent ratchet fail-first matrix

```sh
for fx in r1 r2 r3; do
  GSD_P18_BASELINE=test/fixtures/prohibitions/p18-ratchet-$fx-exceeded.tsv \
    node --test --test-reporter=tap scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs
done
node --test --test-reporter=tap scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs
```

| Injected baseline | Result | Only failing assertion | Measured vs injected baseline |
| --- | --- | --- | --- |
| `p18-ratchet-r1-exceeded.tsv` | FAIL, 1 test | R1 | 337 vs 336 |
| `p18-ratchet-r2-exceeded.tsv` | FAIL, 1 test | R2 | 220 vs 219 |
| `p18-ratchet-r3-exceeded.tsv` | FAIL, 1 test | R3 | 58 vs 57 |
| committed baseline | PASS, 3 tests | none | 337/337, 220/220, 58/58 |

## Pickup and scope

```sh
rg -n 'Phase 230 prohibition guards|run: node --test --test-reporter=tap scripts/ci/prohibitions/\*\.test\.mjs' .github/workflows/ci.yml
git diff --name-only "$(git merge-base HEAD origin/main)" HEAD -- .github/workflows/ci.yml mix.exs
```

The prohibitions glob remains at the workflow command found by content. The scoped diff command
printed no paths: neither `ci.yml` nor `mix.exs` was edited. No fourth `guides/` counter was added.
Plan 241-05 supplied the first two hard-fail classes; this plan supplies the doc-range class and
the three distinct ratchets, completing SURF-04.
