---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 11
subsystem: docs
tags: [adr, name-record, claims-register, doc-contract-test, phase-gate, privacy-gate, enumeration]

requires:
  - phase: 259-01
    provides: ADR 005 (decision #14 points at this record for the clear-space measurement and the name posture)
  - phase: 259-07
    provides: test/fixtures/brand/public-surfaces.json, the 13-row registry the claims register mirrors
  - phase: 259-10
    provides: the bounded enumeration wording in the published docs that the register cites
  - phase: 259-12
    provides: the reconciled vocabulary (no dependency beyond ordering)
  - phase: 259-13
    provides: the three fix-tracking todos the register cites by path
provides:
  - ADR 006, a name search log that says in its title it is not a clearance, with the same-name Hex package crosswake_sigra recorded as an apparent own companion pending maintainer confirmation
  - the clear-space authority and logo-use wording as two recommended defaults (owner confirmation pending), with the measured 300 versus 233.75 unit conflict
  - a claims register of 21 rows (13 enumeration rows, one per registry row, plus 8 policy and source rows) with a four-value status vocabulary
  - test/sigra/brand/name_clearance_test.exs, 18 tests that keep the register in step with the registry state and keep clearance and trademark wording out
  - the recorded outputs of the single phase gate (mix ci, example suite, 17 shell checks)
affects: [260, 261, 262, 263]

actuals:
  tokens: 7900
  tasks: 2
  commits: 1
commits: 1
plan_head_before: e31b01933e8e2993b3376f34d6d0b7fbb7f71d16
plan_head_after: 03107061657fe32aa009750e3765f1c1931f8613

tech-stack:
  added: []
  patterns:
    - "Register-versus-registry consistency test: the claims register's status cell is checked against the registry row's state (parity must read bounded, anything else must read not proven or by design), so a surface cannot be quietly upgraded in prose"
    - "Run-time derivation of identity values: the GitHub owner handle is read from mix.exs inside the test and compared against the record, never written into any file"
    - "Citation-rot guard on a decision record: every backticked file path in the record must exist"

key-files:
  created:
    - .planning/decisions/006-name-clearance-search-log-and-claims-register.md
    - test/sigra/brand/name_clearance_test.exs
  modified: []

key-decisions:
  - "Clear-space authority recommended as the book's prose rule of 2 T (300 units in the symbol SVG) over brand.json logo.clearSpace (a quarter of the typemark height, 233.75 units in the lockup viewBox); brand.json also disagrees with itself between logo.clear and logo.clearSpace; owner confirmation pending"
  - "Logo-use statement recommended as: unchanged use for reference allowed, no implied endorsement, modification needs maintainer approval; reconciled with the MIT license by treating it as a request about identity use, not an added license term, with a possible logo carve-out left as a separate owner decision"
  - "crosswake_sigra is recorded as an apparent own-ecosystem companion (same GitHub owner as source_url), never as a third-party conflict and never as support for any claim; ownership stays 'maintainer to confirm'"
  - "No trademark claim and no clearance wording anywhere in the record; the register marks this claim bounded, because the vendored book itself names both mark symbols in a sentence about when to use them and that pinned text is not edited"

patterns-established:
  - "A claims row for a registry surface cites the registry id in backticks inside the Evidence cell, so the same string is both the cross-check key and the reader's pointer"

requirements-completed: [BPOL-04, BCOPY-07]

coverage:
  - id: D1
    description: "ADR 006 exists with an H1 containing 'search log, not clearance', a dated lookup table for six registries, the crosswake_sigra note, an explicit no-trademark-claim decision, and both default decisions labelled 'owner confirmation pending'"
    requirement: BPOL-04
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/name_clearance_test.exs#title and the same-name package"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/brand/name_clearance_test.exs#forbidden wording"
        status: pass
    human_judgment: false
  - id: D2
    description: "The claims register references every registry row id by backticked id, states each row's status consistently with its registry state, and states the example-host limitation"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/name_clearance_test.exs#claims register covers the surface registry"
        status: pass
      - kind: unit
        ref: "mix test test/sigra/brand/name_clearance_test.exs#limits, decisions and citations"
        status: pass
    human_judgment: false
  - id: D3
    description: "The single phase gate: mix ci, the example suite with the parity module, and the shell checks for zero shipped bytes, process budget, ratchet, privacy (paths, user name in the diff and in brand/, vendored origin, maintainer address, generic address shape), manifest and project-rule guards"
    requirement: BPOL-04
    verification:
      - kind: command
        ref: "MIX_ENV=test mix ci"
        status: pass
      - kind: command
        ref: "cd test/example && MIX_ENV=test mix test --include example_app"
        status: pass
      - kind: command
        ref: "phase-gate shell checks, steps 3 to 8 (run twice, before and after this SUMMARY was written)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Whether the clear-space authority, the logo-use wording and the crosswake_sigra reading are the right calls"
    verification: []
    human_judgment: true
    rationale: "Both decisions are recommended defaults and the crosswake_sigra ownership is not stated by the registry's API response; a test can prove they are recorded and labelled, only the owner can confirm them"

duration: 11min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 11: Name search log, claims register and phase gate Summary

**ADR 006 logs the name lookups as a search log that says in its title it is not a clearance, records crosswake_sigra as an apparent own companion pending maintainer confirmation, defaults clear space to the book's 2 T rule, and carries a 21-row claims register that an 18-test doc contract keeps in step with all 13 enumeration registry rows; the phase gate then ran green with every control passing.**

## Performance

- **Duration:** about 11 min (approximate; the start time was not captured, taken from the previous plan's close-out stamp of 17:27Z)
- **Started:** 2026-11-14T17:27Z (approximate)
- **Completed:** 2026-11-14T17:38Z
- **Tasks:** 2 (Task 1 the tracer; Task 2 verification only, no files modified)
- **Files modified:** 2, both created; zero bytes under `lib/`, `priv/`, `brandbook/`, `brand/`, `.github/` or `scripts/`

## Accomplishments

- Task 1 (tracer): wrote ADR 006 and its doc-contract test end to end. The record has the lookup table (Hex, npm, PyPI, RubyGems, crates.io, GitHub), the `crosswake_sigra` section with what the record does and does not conclude, the no-trademark-claim decision, the clear-space and logo-use decisions with the measured conflict, the claims register, its limitations, and revisit triggers.
- The register has 21 rows. Thirteen are one per surface registry row (three `parity` rows read `bounded`; the other ten read `not proven` or `by design`), plus install-pin shape, brand pin integrity, vendored-tree privacy, the frozen-surface ratchet, the copy inventory, the copy lexicon, the no-trademark-claim row and the name-search row.
- The test (18 tests) goes beyond the plan's six behaviours: it also checks that every parity id appears, that the register's status cell agrees with the registry state, that the record spells no GitHub owner handle (derived from `mix.exs` at run time), and that every file path the record cites exists.
- Live red proofs on the real record (restored byte-identical afterwards, confirmed with `cmp`): removing the backticks from one non-parity id turned three tests red (the coverage test, the status-agreement test and the removal control, which assumes a complete record); appending a clearance sentence turned the wording test red; marking every `not proven` row as `bounded` turned the status-agreement test red and named all five affected ids; breaking one cited path turned the path test red.
- Task 2: ran the single phase gate. Every leg passed; the outputs are below. No failure needed a pristine-base comparison, so nothing is recorded as pre-existing.

## Task Commits

1. **Task 1: ADR 006 search log, claims register and doc-contract test (tracer)** - `031070616` (docs)
2. **Task 2: Phase gate (verification only)** - no commit by design; its results are this file.

**Plan metadata:** the `docs(259-11)` close-out commits that carry this SUMMARY, STATE.md, ROADMAP.md and REQUIREMENTS.md.

Tracer gate: the tracer has no `gate="blocking-human"`, `human_verify_mode` is the end-of-phase default and its `<verify>` is automated-only, so the verify was re-run after the commit (18 tests, then the whole `test/sigra/brand` directory at 290 tests, 0 failures) and expansion to Task 2 continued; logged "Tracer verified end-to-end - expanding".

## Files Created/Modified

- `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` - the record (156 lines)
- `test/sigra/brand/name_clearance_test.exs` - doc-contract test with pure helpers `missing_ids/2`, `forbidden_wording/1`, `status_violations/2` and `cited_paths/1` and a planted control for each

## Decisions Made

See `key-decisions`. Two interpretation points worth the owner's eye:

- **The registry's real states beat the plan's wording.** The plan text expected "bounded" rows for password reset and confirmation resend (example host only). Plan 07 registered both as `not_proven`, because the example host cannot drive either, so the register states them as `not proven` and the test enforces that a non-`parity` row can never read `bounded`.
- **The MIT reconciliation is a request, not a term.** The book says the logo is covered by the MIT license unless the repository says otherwise, and the repository's license file has no logo carve-out. So "modification needs maintainer approval" cannot be an enforceable term today; the record words it as the maintainers' request about identity use and leaves the carve-out as a separate owner decision.

## Deviations from Plan

### Auto-fixed Issues

None.

### Interpretation choices

1. **Parity ids are also required in the register** (one extra test) and each parity row must read `bounded`; the plan required only the non-parity ids. A new `parity` row added later now forces a register row.
2. **Status-versus-state test** (`status_violations/2`) added so T-259-36 (a register that over-claims a surface) fails on status, not only on a missing id.
3. **Owner-handle absence test** derived from `mix.exs` at run time, so the acceptance grep (which names the handle shape) has a permanent test counterpart without writing the handle anywhere.
4. **Cited-path existence test** added; it found nothing, but the record cites 24 distinct file paths and a decision record is exactly where a stale path hides.
5. **Date handling:** the plan says to re-run the Hex lookup if executed after 2026-11-13. It was executed on 2026-11-14, so the `crosswake_sigra` row carries both dates and says the re-run returned the same result; the other registry rows keep the research session's date and say they were not repeated. No result was invented.
6. **Self-review before the commit** removed one claim I could not verify (that the install smoke does not compare enumeration responses) and corrected "student-results" to "learning-results" for the PHP project named in the research log.

**Total deviations:** 0 auto-fixed, 6 interpretation choices. **Impact:** all inside the plan's two files; the register is stricter than specified.

## Phase gate results (Task 2)

Base commit for every base-relative check: `aeda7273d`. Nothing in this task modified a tracked file; `git status --short` was empty after every leg.

### 1. Full local gate

`source tmp/db.env && MIX_ENV=test mix ci` (format check, `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`, `test --exclude scaffold`, `ci.install_golden`, `sigra.dep_off`):

```
test --exclude scaffold:   33 doctests, 3 properties, 2939 tests, 0 failures, 12 skipped (22 excluded)
ci.install_golden:         65 tests, 0 failures (2932 excluded)
sigra.dep_off:             restored threadline and sigra compiles, silent on success
EXIT=0   (wall time 60 s, 2026-11-14T17:35:04Z to 17:36:04Z)
```

The test leg printed `error: undefined variable "web_module"` and "redefining module" warnings from tests that compile generated templates inside the suite; none is a failure (0 failures), none touches a file this plan changed, and they were not triaged. The phx_new archive is 1.8.8, the CI pin.

### 2. Example suite

`source tmp/db.env && cd test/example && MIX_ENV=test mix test --include example_app`:

```
365 tests, 0 failures    EXIT=0
```

The parity module alone (`... --include example_app test/example_web/enumeration_parity_test.exs`): `22 tests, 0 failures`, so its tests are present in the suite.

### 3 to 8. Shell checks

Run as one script that wraps each command from the plan in a function and prints PASS or FAIL; the planted-failure and self-match controls are inside each command. Run twice (once before this SUMMARY was written, once after, because the vendored-origin check also scans the phase directory). Derived values (user name, maintainer address, vendored-book origin host) are never printed or recorded.

```
PASS  step 3  zero shipped bytes (lib priv brandbook brand), untracked aware
PASS  step 4  process budget (.github scripts)
PASS  step 5  frozen-surface ratchet only grew (no deleted lines, has added lines)
INFO  step 5  copy-baseline.json deleted-line count (base-relative): 0
PASS  step 6a privacy: no home-path shapes in shipped diff (+planted control)
PASS  step 6b privacy: derived user name absent from shipped diff (+self-match control)
PASS  step 6c privacy: derived user name absent from brand/ tree incl. binaries (+recursive self-match control)
PASS  step 6d privacy: vendored-origin host absent from diff and phase dir (+self-match control)
PASS  step 6e privacy: derived maintainer address absent from shipped diff (+self-match control)
PASS  step 6f privacy: generic email-shape scan over added lines (+planted control)
PASS  step 7  manifest independent check (shasum -c, OK count equals manifest lines)
INFO  step 7  manifest lines: 72; shasum OK lines: 72
PASS  step 8a no scaffold moduletag under test/sigra/brand
PASS  step 8b mix.exs, doc/llms.txt, CHANGELOG.md unchanged
PASS  step 8c no upgrading-to-* guide added or changed (non-empty guides diff as control)
PASS  step 8d no {:sigra, dependency tuple line changed in README or guides
PASS  step 8e no tag at HEAD
PASS  clean  no tracked file other than .planning changed; no stray files
```

Step contents, in the plan's order:

- **Step 3 (zero shipped bytes):** `D=$(git diff --stat aeda7273d -- .planning)`, non-empty (control: the planning diff resolves); `L=$(git ls-files -- lib priv brandbook brand .github scripts | head -1)`, non-empty (control: the pathspecs resolve); `Z=$(git diff --stat aeda7273d -- lib priv brandbook brand)` empty; `U=$(git status --porcelain -- lib priv brandbook brand)` empty (the untracked-aware leg).
- **Step 4 (process budget):** the same capture-then-test form over `.github scripts`, diff and porcelain both empty.
- **Step 5 (ratchet):** `F=$(git diff aeda7273d -- test/fixtures/brand/frozen-surface.json)` non-empty, no `^-[^-]` line, at least one `^+[^+]` line. For `copy-baseline.json` the base-relative diff has 0 deleted lines (it is a new file in this phase).
- **Step 6 (privacy):** shipped diff `git diff aeda7273d --text -- . ':(exclude).planning/phases/259-*'` non-empty and free of home-path shapes, with a planted home-path-shaped line matching the same pattern (the only exclusion is this phase's planning directory, which necessarily quotes the pattern; no other exclusion was added and no regex was loosened). Personal name derived with `id -un` and searched whole-word, case-insensitive, fixed-string in the diff, with the derived value matching itself as the control. The same derived name searched recursively in all 72 tracked files under `brand/`, binaries included (`grep -rIaiw -F`), with a `mktemp` probe containing the name as the recursive self-match control and `git ls-files brand` non-empty as the tracked-tree sample. The vendored-origin host derived from `og:image` in `brand/index.html`, absent from the whole diff and from every file under `.planning/phases/259-*`, with a self-match control. `git config user.email` is set, so the address leg ran (diff free of it; `mktemp`/`printf` self-match control passed); the explicit "no address configured" skip line was not needed. The generic email-shape scan over added lines only found no address-shaped token outside `example.com/org/net`, `.test`, `.example`, `.invalid` and the `@2x` image-suffix shape, with a planted `someone@corp.io` surviving the filters.
- **Step 7 (manifest):** `shasum -a 256 -c brand.sha256` printed 72 `OK` lines against 72 manifest lines and none that were not OK.
- **Step 8 (project rules):** no `moduletag :scaffold` under `test/sigra/brand`; `mix.exs`, `doc/llms.txt`, `CHANGELOG.md` unchanged against the base; the guides diff is non-empty and contains no `upgrading-to-` file (tracked or untracked); no `{:sigra, ` tuple line changed in `README.md` or `guides`. No push, tag, merge, release or CI trigger was performed by this plan (`git tag --points-at HEAD` is empty).

### BPOL-02 names clause

Plan 02's test scans the vendored tree for home paths, addresses and file metadata and, by design, not for personal names. Step 6c above is the other half: the derived name is absent from every tracked file under `brand/`, binaries included, with its recursive self-match control passing. BPOL-02's personal-name scan is therefore closed jointly with Plan 02.

## Owner review pending (non-blocking)

None of these stalled execution. Each is a recommended default or a statement the owner should accept or change.

1. **SemVer level.** Minor release, `feat`/`fix`/`docs` commit types only, no `!` marker, no BREAKING footer (ADR 005 decision 3).
2. **Security-model wording versus OWASP.** The Plan 10 doc wording (README, six guides, demo-showcase, example README) and this claims register state exactly what the three `parity` rows prove and no more. Whether that wording is the right public stance is the owner's call.
3. **Generator and host-contract output.** The msgid policy and the rename-table rule (ADR 005 decision 4), and the ownership lanes, change what later phases may emit into hosts.
4. **Clear-space and logo-use authority.** The 2 T prose rule as authority over the JSON quarter-height rule (300 versus 233.75 units, a 66.25 unit gap), and the logo-use wording with its MIT reconciliation, including whether the repository should carve the logo out of the MIT grant (ADR 006).
5. **Vendoring scope.** The whole 72-file `brand/` tree is pinned, with the consumed subset documented as a table (ADR 005 decision 8).
6. **PNG-lane park.** Demoting the two PNG-compare lanes from PR-blocking to dispatch (ADR 005 decision 7); merging that change needs explicit owner approval.
7. **Profile defaults frozen.** `Sigra.Branding.Profile` keys and default values do not move to the book's neutrals in v1.51 (ADR 005 decision 1).
8. **Install-pin shape.** Three-segment equal requirements enforced now, the value bump left to Phase 263 (ADR 005 decision 11).
9. **`crosswake_sigra` ownership.** The record says it appears to be an own companion and asks the maintainer to confirm; the owner's answer is a revisit trigger.

Two statements the owner should read as limits, not as resolved items:

- **The library moduledoc over-claims stay in the shipped API documentation.** `lib/sigra/lockout.ex`, `lib/sigra/error.ex` and `lib/sigra/auth.ex` state enumeration safety more broadly than the parity rows prove and ship on HexDocs. This phase carries zero lib bytes, so it could not edit them; they are tracked by `.planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md` (from Plan 259-13) and bounded by the claims register.
- **A green parity claim needs a later fix.** A green parity claim for the passkey options endpoint, and for any registration or rate-limit divergence, needs a LATER `priv/templates` or `lib` fix plus a golden-fixture rebless, which this phase deliberately does not do. Read literally, SC-4 means divergences are registered and asserted, not made green.

Also for the verifier and owner:

- Playwright specs (Plan 03's `loginSubmit` replacements) were not run locally. They are proven only by the PR `example_playwright_shard` lanes; the local proof is the ConnTest that the selector matches exactly one element.
- The BPOL-06 approval covered `CLAUDE.md`, `AGENTS.md` and the two admin guides only. `test/example/AGENTS.md` and three orphaned pointers were filed as todos, not edited.
- Three of the five surfaces the roadmap names are `parity`; password reset request and confirmation resend are `not_proven` because the example host cannot drive them (Plan 07 key-decisions and `deferred-items.md`). Whether that satisfies SC-4's intent is the owner's call.

## Deferred Issues

None new in this plan. The phase's `deferred-items.md` carries the earlier findings (example-host route and call defects, generated reset-request struct-versus-binary call, reset guide configuration blocks, copy that promises an unlock control that does not exist).

## Issues Encountered

None blocking. The test leg of `mix ci` prints compile diagnostics from tests that compile generated templates; no failure resulted.

## Authentication Gates

None.

## Known Stubs

None. No stub patterns, skipped tests or unrun verifies in the two files created.

## Threat Flags

None. A planning record and a test; no new network, auth or file-access surface. T-259-34 (read as clearance): title, explicit no-claim section and a wording test with planted controls. T-259-35 (identity leak): owner handle derived and asserted absent at run time; privacy gate passed with run-time-derived name, address and origin. T-259-36 (register omits a divergence): the test cross-checks every registry id and its status. T-259-37 (gate weakened): the only exclusion is this phase's planning directory, unchanged from the plan.

## Verification Results

- `source tmp/db.env && mix test test/sigra/brand/name_clearance_test.exs`: 18 tests, 0 failures. `mix test test/sigra/brand`: 290 tests, 0 failures. `mix format --check-formatted` on the new test: clean.
- Task 1 acceptance criteria: title grep count 1; `crosswake_sigra` count 7 (at least 1); clearance, mark-symbol and registered-trademark grep prints nothing, planted control `printf 'it is cleared\n' | grep -i -E '\bcleared\b'` prints a match; owner-handle and `github.com/<name>` grep prints nothing, `source_url` count 1 (at least 1); zero-shipped-bytes gate exits 0.
- Task 2 acceptance criteria: all eight command groups above with observed output and the "Owner review pending (non-blocking)" heading; the manifest check, the CHANGELOG/mix.exs/llms.txt check and the no-upgrade-guide check each exit 0; the maintainer-address and brand-tree name legs ran and passed with controls; the generic email-shape scan passed with nothing to reword; no tracked file other than this SUMMARY changed in the task.

## Next Phase Readiness

Phase 259 has no remaining plan. Phase 260 (the PNG-lane park) and the later phases can cite ADR 005 for policy and ADR 006 for the name and claims boundary. Phase 263's public copy must restate a registry row only with its bounds, and must not assert clearance of the name.

## Self-Check: PASSED

Created files exist on disk; commit `031070616` is an ancestor of HEAD and is the only commit in the plan range (`rev-list --count` = 1); every acceptance criterion and the plan-level verification commands were re-run green after the last code commit; no stub patterns found.
