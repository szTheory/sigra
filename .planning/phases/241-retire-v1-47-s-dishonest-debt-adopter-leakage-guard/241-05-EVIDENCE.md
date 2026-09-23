# 241-05 evidence — p18's first two hard-fail classes

`_p18-lib.mjs` ports the Phase 239 V3 vocabulary and its keyed allowlist controls.  The live
allowlist has one `(path, literal)` entry for the SVG coordinate false positive in
`priv/templates/sigra.gen.oauth/oauth_html.ex`.

## Clean real-tree runs

```sh
node --test --test-reporter=tap scripts/ci/prohibitions/p18-planning-paths.test.mjs scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
```

Both tests passed.  The planning surface measured `hits=0`, `hits_outside_allowlist=0`,
`control_defmodule=286`, and `files_measured=280`.  The templates surface measured `hits=1`,
`allowlisted=1`, `hits_outside_allowlist=0`, `control_defmodule=98`, and `files_measured=119`.
The non-zero raw count confirms the allowlist dispositions the logo hit rather than hiding an
empty scan.

## Fixture cross-product

```sh
set -uo pipefail
for fx in p18-planning-path-leak.ex p18-template-bookkeeping.ex; do
  for g in p18-planning-paths p18-templates-bookkeeping; do
    GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/$fx \
      node --test scripts/ci/prohibitions/$g.test.mjs
  done
done
```

| Fixture | Guard | Result | Named reason |
| --- | --- | --- | --- |
| `p18-planning-path-leak.ex` | planning paths | FAIL | `DIRTY SURFACE: planning-directory path` |
| `p18-planning-path-leak.ex` | templates bookkeeping | FAIL | `DIRTY SURFACE: templates bookkeeping vocabulary` |
| `p18-template-bookkeeping.ex` | planning paths | PASS | no `.planning/` literal |
| `p18-template-bookkeeping.ex` | templates bookkeeping | FAIL | `DIRTY SURFACE: templates bookkeeping vocabulary` |

The first fixture intentionally fails both guards: `.planning/` is the first alternative in the
wide V3 vocabulary.  The independent, load-bearing cell is the template fixture passing the
literal planning-path guard.

## Fail-closed controls

```sh
GSD_PROHIB_FORCE_EMPTY_FILE_LIST=1 node --test scripts/ci/prohibitions/p18-planning-paths.test.mjs
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/does-not-exist.ex node --test scripts/ci/prohibitions/p18-planning-paths.test.mjs
GSD_P18_ALLOWLIST=/private/tmp/241-05-stale-allowlist.tsv node --test scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
```

Each command failed with the distinct `INSTRUMENT FAILURE:` prefix: respectively an empty file
list, a missing injected subject, and a vacuous allowlist literal.  The helper also checks every
allowlist path against the real tracked tier union, not a fixture-collapsed list.

## Regression checks

```sh
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
mix format --check-formatted test/fixtures/prohibitions/p18-planning-path-leak.ex test/fixtures/prohibitions/p18-template-bookkeeping.ex
```

The full prohibition glob passed 98 tests; both committed Elixir fixtures are format-clean.

This plan supplies only two of the three p18 hard-fail classes.  `SURF-04` remains open until
Plan 241-06 adds the final class and all three ratchet counters.
