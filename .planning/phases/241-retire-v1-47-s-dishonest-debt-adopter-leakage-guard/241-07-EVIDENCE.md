# Phase 241 Plan 07 — D-30 doc-range scanner parity evidence

**Candidate implementation SHA:** `1fa86ff53043ff42c28f4a8291343cab56f3d17e`

The permanent Node guard consumes only the committed TSV expectations. Python is a one-time
same-commit evidence oracle; it is not added to `fast_checks` or any CI runtime.

## Same-commit Python/JavaScript parity corpus

```bash
bash -c 'set -eo pipefail; tmp=$(mktemp -d); trap '\''rm -rf -- "$tmp"'\'' EXIT; baseline=$(awk -F "\t" '\''$1=="R1" {print $2}'\'' scripts/ci/prohibitions/p18-ratchet-baseline.tsv); test -n "$baseline"; py=$(python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib | sed -n "s/^total_hits=//p"); js=$(node -e '\''import("./scripts/ci/prohibitions/_p18-lib.mjs").then(m => console.log(m.docRangeTotal("lib")))'\''); test "$py" = "$js"; test "$js" = "$baseline"; for f in p18-doc-range-leak.ex p18-doc-range-lowercase-sigil.ex p18-doc-range-delimited-sigils.ex p18-doc-range-python-language.ex; do rm -f -- "$tmp/fixture.ex"; cp "test/fixtures/prohibitions/$f" "$tmp/fixture.ex"; py=$(python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py "$tmp" | sed -n "s/^total_hits=//p"); js=$(GSD_PROHIB_SUBJECT="test/fixtures/prohibitions/$f" node -e '\''import("./scripts/ci/prohibitions/_p18-lib.mjs").then(m => console.log(m.docRangeTotal("lib")))'\''); test "$py" = "$js" || { echo "$f python=$py js=$js" >&2; exit 1; }; done'
```

Exit code: `0`.

| Subject | Python total | JavaScript total | R1 baseline | Result |
| --- | ---: | ---: | ---: | --- |
| `lib/` | 337 | 337 | 337 | equal |
| `p18-doc-range-leak.ex` | 1 | 1 | — | equal |
| `p18-doc-range-lowercase-sigil.ex` | 0 | 0 | — | equal |
| `p18-doc-range-delimited-sigils.ex` | 0 | 0 | — | equal |
| `p18-doc-range-python-language.ex` | 4 | 4 | — | equal |

The genuine leak remains protected: subject injection for `p18-doc-range-leak.ex` exits nonzero
and includes `P18 DIRTY SURFACE: doc-range planning artifact`.

## Locked scanner language

The JavaScript state machine literally follows the committed Phase-237 Python scanner: plain and
uppercase-`~S` triple-quoted doc attributes plus plain and uppercase-`~S` one-line quoted doc
attributes. Generalized, lowercase, escaped, pipe-delimited, and paired-delimiter sigils remain
outside D-30's locked language.

The parity guard was also mutation-proven: temporarily widening the uppercase-only heredoc
condition to accept lowercase `~s` made the Node suite exit `1` on its own `P18 D-30 PARITY`
assertion; restoring the condition returned the suite to green.

## Permanent tests and all prohibition consumers

```bash
bash -c 'set -eo pipefail; mix format --check-formatted test/fixtures/prohibitions/p18-doc-range-python-language.ex; node --test --test-reporter=tap scripts/ci/prohibitions/p18-doc-range.test.mjs; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p18-doc-range-leak.ex node --test scripts/ci/prohibitions/p18-doc-range.test.mjs >/tmp/241-07-leak.txt 2>&1 && { echo "known-bad doc leak passed" >&2; exit 1; } || grep -q "P18 DIRTY SURFACE: doc-range planning artifact" /tmp/241-07-leak.txt; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs'
```

Exit code: `0`. The focused D-30 suite passed `4/4`; the full prohibition glob passed `106/106`.
