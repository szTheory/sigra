# Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard - Pattern Map

**Mapped:** 2026-09-19
**Files analyzed:** 6 gap-relevant source/evidence files
**Analogs found:** 5 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
| --- | --- | --- | --- | --- |
| `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-01-EVIDENCE.md` | evidence/configuration | request-response (command transcript) | `241-06-EVIDENCE.md` | exact |
| `scripts/ci/prohibitions/_p18-lib.mjs` | utility/scanner | transform (tracked files to scan result) | `237-docs-attribute-scan.py` | exact specification, current implementation diverges |
| `scripts/ci/prohibitions/p18-doc-range.test.mjs` | test | request-response (fixture subject to assertions) | `p18-planning-paths.test.mjs` | role-match |
| `test/fixtures/prohibitions/p18-doc-range-delimited-sigils.ex` | test fixture | transform input | `p18-doc-range-leak.ex` | role/data-flow match |
| `test/sigra/audit/forwarders/threadline_test.exs` | test (diagnostic only) | event-driven | `test/sigra/rate_limiters/hammer_test.exs` (named in source) | role-match |
| final-HEAD CI run record (URL/status) | evidence artifact | request-response | `241-01-EVIDENCE.md:150-158` | no committed analog; obtain CI evidence |

## Pattern Assignments

### Final-HEAD `mix ci` evidence (`241-01-EVIDENCE.md`)

**Analog:** `241-06-EVIDENCE.md` lines 11-21 (reproducible `bash -c` transcript) and `241-01-EVIDENCE.md` lines 150-158 (CI-only qualification).

Use a committed, immutable final-HEAD CI run as the success claim; do not relabel the local run green or exclude tests. The existing wording is explicit:

```markdown
The full-suite claim for SC-1 is made against **CI** at this phase's final committed HEAD;
it is not a local-green claim. A local `MIX_ENV=test mix ci` currently carries 6 environmental
`Sigra.Audit.Forwarders.ThreadlineTest` failures (`Threadline.attach/1 undefined`) ...
Those tests are **not** excluded from the suite.
```

The local diagnostic source is `test/sigra/audit/forwarders/threadline_test.exs:121-137`, where `attach_threadline/1` calls `:ok = Threadline.attach(opts)`. The six failures are therefore an environmental/missing-implementation signal, not a pattern for changing the alias or filtering tests. Evidence should record HEAD SHA, CI URL, exact `mix ci` command, and conclusion.

### `scripts/ci/prohibitions/_p18-lib.mjs` (utility, transform)

**Analog:** `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py:14-20,27-66`.

Restore the bounded Phase-237 language exactly: token regex at lines 14-18, heredoc opener at line 19, one-line quoted attribute at line 20, sorted `*.ex` then `*.exs` traversal at lines 27-29, and state machine that counts opener/closer lines at lines 32-66. The JS helper’s existing traversal/result shape is useful (`_p18-lib.mjs:143-195`), but `docRangeOpening` must not recognize generalized sigils. Specifically remove/use no analog for the current `SIGIL_CLOSING_DELIMITERS` table (`_p18-lib.mjs:27-36`) or `^~[sS](...` parser (`:52-57`); those produce the parity failure.

Parity command pattern from `241-06-EVIDENCE.md:18-21` should remain, but add the committed counterexample: Python scans `p18-doc-range-delimited-sigils.ex` as zero hits while the broadened JS scanner reports two. After restoring the port, both implementations must agree on that fixture and the real-tree 337 total.

### `scripts/ci/prohibitions/p18-doc-range.test.mjs` (test, fixture-driven)

**Analog:** current `p18-doc-range.test.mjs:39-62` and the fixture RED pattern in `241-06-EVIDENCE.md:11-15`.

Keep the real-tier non-vacuity assertion (`docRanges > 0`), explicit `P18InstrumentFailure` distinction, and hard-fail diagnostic format. Delete tests that encode the rejected generalized-sigil contract (`:64-91`), especially the expected `docRanges=3` and `.planning/ (2)` assertion. Replace with a parity regression that runs the Python reference and JS port against the delimited-sigil fixture and asserts equal zero results (or otherwise proves the fixture is outside the locked scanner surface). Do not broaden the scanner merely to satisfy the fixture.

### `test/fixtures/prohibitions/p18-doc-range-delimited-sigils.ex` (fixture, transform input)

**Analog:** `test/fixtures/prohibitions/p18-doc-range-leak.ex` (used by `241-06-EVIDENCE.md:12-15`).

This fixture intentionally contains normal heredoc plus `~s|...|` and `~S(...)` forms (`:7-15`). Preserve it as the semantic counterexample: the Phase-237 Python scanner must return `total_hits=0`; JS must match rather than claim those forms are doc ranges. Its value is proving bounded parity, not proving a new sigil feature.

### `test/sigra/audit/forwarders/threadline_test.exs` (diagnostic only)

No implementation change is assigned by this gap mapping. Use its existing test setup/teardown and explicit `Threadline.attach/1` call only to identify the six local failures. Do not edit this test, `mix.exs`, or the `mix ci` topology as a workaround for missing final-HEAD CI evidence.

## Shared Patterns

### Deterministic evidence

Use `bash -c` with `set -eo pipefail` for green assertions and capture command, HEAD, output, and exit status. The phase precedent is `241-06-EVIDENCE.md:17-21`; fixture RED runs intentionally invert the exit check as at `:11-15`.

### Offline scanner subject injection

Retain `GSD_PROHIB_SUBJECT` indirection in `_p18-lib.mjs:96-112,115-117` so committed fixtures are substituted without mutating tracked source. A missing subject is an instrument failure, never a clean result (`:100-105`).

### Fail-closed scanner inputs

Retain sorted tracked-file discovery and non-vacuity (`_p18-lib.mjs:74-94,124-146`). Preserve the raw totals and distinct-site reporting used by `p18-doc-range.test.mjs:48-56`; parity must be checked independently of the current corpus total.

## No Analog Found

| File | Role | Data Flow | Reason |
| --- | --- | --- | --- |
| Final-HEAD CI run / provider receipt | evidence artifact | request-response | No committed successful run exists for this unpushed final HEAD; `241-01-EVIDENCE.md:158` is explicitly `PENDING`. |

## Metadata

**Analog search scope:** `scripts/ci/prohibitions/`, `.planning/phases/237-*`, `.planning/phases/241-*`, `test/fixtures/prohibitions/`, `test/sigra/audit/`
**Tracked-source gate:** all named source analogs verified with `git ls-files`; no ignored mirrors named.
**Pattern extraction date:** 2026-09-19
