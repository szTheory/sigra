# Phase 241 Plan 06 — p18 doc-range and ratchet evidence

**Implementation commits:** `f1a95dee` (doc-range guard) and `e24ee4ed` (three-counter ratchet). All commands ran through `bash -c` at execution HEAD. `SURF-04` is completed by this plan, not by 241-05.

## Deliberately distinct instruments

The doc-range hard fail and R1 cover the same HexDocs-rendering surface but answer different questions. The hard fail asks whether a planning-artifact token that had measured zero has appeared; R1 asks whether historical bookkeeping is non-increasing. Conflating those questions would make either instrument dishonest.

## Doc-range fixture RED and real-tree GREEN

```bash
bash -c 'set -o pipefail; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p18-doc-range-leak.ex node --test scripts/ci/prohibitions/p18-doc-range.test.mjs > /tmp/241-06-a.txt 2>&1; rc=$?; test "$rc" -ne 0 || exit 1; grep -q "P18 DIRTY SURFACE: doc-range planning artifact" /tmp/241-06-a.txt'
```

Captured RED: non-zero as required, `doc_ranges=1 total_hits=1`, and the specific diagnostic was `P18 DIRTY SURFACE: doc-range planning artifact planning directory=.planning/ (1) in test/fixtures/prohibitions/p18-doc-range-leak.ex`.

```bash
bash -c 'set -eo pipefail; node --test --test-reporter=tap scripts/ci/prohibitions/p18-doc-range.test.mjs; py=$(python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib | sed -n "s/^total_hits=//p"); js=$(node -e "import(\"./scripts/ci/prohibitions/_p18-lib.mjs\").then(m => console.log(m.docRangeTotal(\"lib\")))"); echo "python=$py js=$js"; test "$py" = "$js"'
```

Captured GREEN: `doc_ranges=655 total_hits=337 distinct_sites=254 distinct_files=69`, Node passed 2/2, and `python=337 js=337`. The JS port is synchronous and is the CI guard's only runtime implementation; Python is a cross-check only.

## Independent committed ratchet baselines

`scripts/ci/prohibitions/p18-ratchet-baseline.tsv` states separate definitions and reproducible commands for all counters.

| Counter | Measured | Surface and vocabulary |
| --- | ---: | --- |
| R1 | 337 | `lib/` documentation-attribute ranges; narrower Phase-237 scanner vocabulary |
| R2 | 220 | comment-only tracked `lib/` Elixir lines; wide Phase-239 V3 vocabulary |
| R3 | 58 | Hex-packaged docs (`docs/`, `README.md`, `CHANGELOG.md`); literal `.planning/` only |

```bash
bash -c 'set -eo pipefail; node --test --test-reporter=tap scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs'
```

Captured GREEN: `R1 measured=337 baseline=337`, `R2 measured=220 baseline=220`, and `R3 measured=58 baseline=58`; all three passed and each log says `pass=decrease-or-equal zero-is-not-the-target`.

## Three independently reachable REDs

```bash
bash -c 'set -uo pipefail; : > /tmp/241-06-matrix.txt; for fx in r1 r2 r3; do if GSD_P18_BASELINE=test/fixtures/prohibitions/p18-ratchet-$fx-exceeded.tsv node --test --test-reporter=tap scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs > /tmp/241-06-$fx.txt 2>&1; then echo "$fx PASS" >> /tmp/241-06-matrix.txt; else echo "$fx FAIL $(grep -c "^not ok" /tmp/241-06-$fx.txt)" >> /tmp/241-06-matrix.txt; fi; done; cat /tmp/241-06-matrix.txt; set -e; grep -qx "r1 FAIL 1" /tmp/241-06-matrix.txt; grep -qx "r2 FAIL 1" /tmp/241-06-matrix.txt; grep -qx "r3 FAIL 1" /tmp/241-06-matrix.txt'
```

Captured matrix: `r1 FAIL 1`, `r2 FAIL 1`, `r3 FAIL 1`. The individual captured diagnostics were `P18 RATCHET REGRESSION R1`, `P18 RATCHET REGRESSION R2`, and `P18 RATCHET REGRESSION R3`; no fixture lowers more than one counter.

## Security-rationale standing constraint

```bash
bash -c 'set -eo pipefail; rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib | awk "END { print \"security_rationale=\" NR }"'
```

Captured count: `security_rationale=52`. Any future R2 decrease must re-run this separate, non-overlapping count and confirm it did not fall, so bookkeeping deletion cannot silently remove security rationale.

## D-29: widenings declined for v1.48

The decision was made before committing the baseline. Case-folding V3 was measured at `R2_case_folded=221`, versus unwidened `R2=220` (`delta=1`), and is declined for v1.48. The lowercase `post plan 04` gap remains outside the three ratcheted surfaces. Block/comment-aware matching is also declined: it needs a new implementation to measure honestly and could create cross-line false positives. Both decisions and the surviving gap remain in the existing pending todo, marked partially folded.

## Wiring and scope confirmation

```bash
bash -c 'set -eo pipefail; rg -n "run: node --test --test-reporter=tap scripts/ci/prohibitions/\\*.test.mjs" .github/workflows/ci.yml; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs; mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs; test -z "$(git diff --name-only "$(git merge-base HEAD origin/main)" -- .github/workflows/ci.yml mix.exs)"'
```

Captured result: the content-located prohibitions glob is CI line 408; all 104 prohibition tests passed; focused ExUnit passed 7/7; neither `.github/workflows/ci.yml` nor `mix.exs` appears in this phase's diff.
