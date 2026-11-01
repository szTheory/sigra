# Phase 241 Plan 05: p18 first-two-classes evidence

**Captured:** 2026-09-19
**Code commits under test:** `bfde841a`, `8498df3a`

This plan lands the first two of p18's three hard-fail classes. It does **not**
complete SURF-04: Plan 241-06 owns the doc-range class and the three independent
monotonic-decrease ratchets.

## Real-tree GREEN runs

The planning-path surface is literal `.planning/` only (D-23), not a V3 scan:

```bash
bash -c 'node --test --test-reporter=tap scripts/ci/prohibitions/p18-planning-paths.test.mjs'
```

Captured measurement:

```text
tier=planning-paths
hits=0
allowlisted=0
hits_outside_allowlist=0
control_defmodule=286
files_measured=280
ok 1 - tracked lib/ and priv/templates/ contain no literal .planning/ path
```

The templates guard retains V3 verbatim, reports the raw count, and dispositions
the sole real match via its committed `(path, literal)` allowlist entry:

```bash
bash -c 'node --test --test-reporter=tap scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs'
```

Captured measurement:

```text
tier=priv-templates
hits=1
allowlisted=1
hits_outside_allowlist=0
control_defmodule=98
files_measured=119
ok 1 - tracked priv/templates/ contain no V3 bookkeeping vocabulary outside the allowlist
```

That allowlisted line is the committed third-party Facebook SVG path coordinate
`373-12` in `priv/templates/sigra.gen.oauth/oauth_html.ex`; it is not prose or
bookkeeping. The allowlist key includes both the file and the exact SVG literal,
so it neither follows a line number nor blankets the file (D-26).

## Fixture-by-guard reachability matrix

```bash
bash -c 'set -uo pipefail; : > /tmp/241-05-matrix.txt; for fx in p18-planning-path-leak.ex p18-template-bookkeeping.ex; do for g in p18-planning-paths p18-templates-bookkeeping; do if GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/$fx node --test scripts/ci/prohibitions/$g.test.mjs > /tmp/241-05-x-$fx-$g.txt 2>&1; then r=PASS; else r=FAIL; fi; echo "$fx $g $r" >> /tmp/241-05-matrix.txt; done; done; cat /tmp/241-05-matrix.txt; set -e; grep -qx "p18-planning-path-leak.ex p18-planning-paths FAIL" /tmp/241-05-matrix.txt; grep -qx "p18-planning-path-leak.ex p18-templates-bookkeeping FAIL" /tmp/241-05-matrix.txt; grep -qx "p18-template-bookkeeping.ex p18-templates-bookkeeping FAIL" /tmp/241-05-matrix.txt; grep -qx "p18-template-bookkeeping.ex p18-planning-paths PASS" /tmp/241-05-matrix.txt'
```

| Fixture | Planning paths | Template bookkeeping | Failure reason / property |
| --- | --- | --- | --- |
| `p18-planning-path-leak.ex` | FAIL | FAIL | Planning guard reports `P18 DIRTY SURFACE: planning-directory literal`; template guard reports `P18 DIRTY SURFACE: template bookkeeping vocabulary`. The latter is expected because V3 strictly contains `.planning/`. |
| `p18-template-bookkeeping.ex` | PASS | FAIL | This is the independent cell: the fixture has no planning path, while its one `Phase 241` token triggers the template guard's own V3 diagnostic. |

Captured matrix:

```text
p18-planning-path-leak.ex p18-planning-paths FAIL
p18-planning-path-leak.ex p18-templates-bookkeeping FAIL
p18-template-bookkeeping.ex p18-planning-paths PASS
p18-template-bookkeeping.ex p18-templates-bookkeeping FAIL
```

Each RED has its own non-vacuous diagnostic, including the fixture path and line:

```text
P18 DIRTY SURFACE: planning-directory literal .planning/ at test/fixtures/prohibitions/p18-planning-path-leak.ex:2
P18 DIRTY SURFACE: template bookkeeping vocabulary hit outside allowlist: test/fixtures/prohibitions/p18-planning-path-leak.ex:2
P18 DIRTY SURFACE: template bookkeeping vocabulary hit outside allowlist: test/fixtures/prohibitions/p18-template-bookkeeping.ex:2
```

## Fail-closed instrument controls

Missing subjects are an instrument failure, not an absent violation:

```bash
bash -c 'set -o pipefail; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/does-not-exist.ex node --test scripts/ci/prohibitions/p18-planning-paths.test.mjs > /tmp/241-05-instrument-missing.txt 2>&1; rc=$?; test "$rc" -ne 0 || { echo "missing subject did not fail"; exit 1; }; grep -q "P18 INSTRUMENT FAILURE: subject not found" /tmp/241-05-instrument-missing.txt'
```

```text
P18 INSTRUMENT FAILURE: subject not found at …/test/fixtures/prohibitions/does-not-exist.ex — a missing subject is a broken run, never an absent violation
```

An explicitly forced empty list fails before any property assertion:

```bash
bash -c 'node --input-type=module -e "import { scanBookkeeping } from \"./scripts/ci/prohibitions/_p18-lib.mjs\"; try { scanBookkeeping(\"priv-templates\", { files: [] }); console.error(\"empty file list did not fail\"); process.exitCode = 1; } catch (error) { console.error(error.message); if (!error.message.startsWith(\"P18 INSTRUMENT FAILURE: empty file list\")) process.exitCode = 1; }" > /tmp/241-05-instrument-empty.txt 2>&1; grep -q "P18 INSTRUMENT FAILURE: empty file list" /tmp/241-05-instrument-empty.txt'
```

```text
P18 INSTRUMENT FAILURE: empty file list — refusing to report success on no input
```

Finally, a temporary uncommitted second row for the real SVG path with literal
`P18-TEMPORARY-UNMATCHED-LITERAL` was added, exercised, and removed before this
commit. It proves per-entry non-vacuity rather than merely renaming an allowlist
row:

```bash
bash -c 'set -o pipefail; node --test scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs > /tmp/241-05-instrument-allowlist.txt 2>&1; rc=$?; test "$rc" -ne 0 || { echo "vacuous allowlist did not fail"; exit 1; }; grep -q "P18 INSTRUMENT FAILURE: vacuous allowlist entry" /tmp/241-05-instrument-allowlist.txt'
```

```text
P18 INSTRUMENT FAILURE: vacuous allowlist entry: priv/templates/sigra.gen.oauth/oauth_html.ex :: P18-TEMPORARY-UNMATCHED-LITERAL
```

The helper also verifies every committed allowlist path is in the real tracked
`lib/` ∪ `priv/templates/` union, independently of a collapsed fixture subject.

## Integration verification and scope

```bash
bash -c 'set -eo pipefail; node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs; mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs; mix format --check-formatted; test -z "$(git diff --name-only bfde841a^..HEAD -- .github/workflows/ci.yml mix.exs)"'
```

Captured result: the prohibition glob passed 99 tests, the existing CI-route and
never-in-`mix ci` contract passed 7 ExUnit tests, and formatting was green. No
workflow or `mix.exs` edit was made; `p18-*.test.mjs` is picked up solely by the
existing prohibitions glob.

D-29's two proposed vocabulary widenings remain declined and out of this plan:
this helper ports the committed V3 source verbatim and does not case-fold it or
join comment lines. Plan 241-06 records that locked decision beside its ratchet
baselines; this plan does not expand that scope.
