---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 02
subsystem: testing
tags: [brand-pin, sha256-manifest, drift-test, privacy-scan, gitattributes, vendored-assets]

requires:
  - phase: 259-01
    provides: ADR 005 decision to pin the whole tracked brand/ tree (72 files) rather than prune
provides:
  - Root brand.sha256 manifest pinning all 72 regular files under brand/ in stock shasum -a 256 -c format
  - .gitattributes line 'brand/** -text linguist-vendored' (byte-exact vendoring guard)
  - test/sigra/brand/source_pin_test.exs, the single drift-test module for the pin (30 tests)
  - scan_binary/2, a pure privacy scanner with planted-failure and narrowness controls
affects: [259-11, 260, 261, 262, 263]

actuals:
  tokens: 6727
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Manifest-in-memory drift test: regenerate hashes from the working tree, diff against the committed file with a pure diff_maps/2, flunk with added/removed/changed groups and the regeneration pipeline"
    - "Positive controls mutate in-memory maps only; a real file under brand/ is never touched to prove red-ness"
    - "Privacy scanner built from fragments and runtime-compiled regexes (no home-path literal in source, no Regex in module attributes on OTP 28)"

key-files:
  created:
    - brand.sha256
    - .gitattributes
    - test/sigra/brand/source_pin_test.exs
  modified: []

key-decisions:
  - "One scanner function scan_binary/2 (path, bytes) serves both the plan's scan_binary/2 and the behavior block's scan_text/2: planted strings are passed with a synthetic path, so there is no second alias function"
  - "hash_map/1 takes a %{path => bytes} map (not a root dir) so the mutation controls can change bytes in memory and re-hash without touching disk"
  - "Text-like files are scanned whole; binaries (pdf, png, jpg, ico, fonts) only by printable-string runs of 6 or more bytes; PNG metadata is found by walking length-prefixed chunks, JPG Exif by the 6-byte marker"
  - "A malformed PNG is itself a finding (:png_malformed) so an early walker stop can never read as clean"
  - "The scanner has no URL rule and no allowlist; the vendored book's origin URL is not written anywhere in test source"

patterns-established:
  - "Real-tree non-vacuity guard for scanners: assert each rule family has a real file to run on and that the PDF and PNG walkers actually parse the real files"

requirements-completed: [BPOL-02]

coverage:
  - id: D1
    description: "brand.sha256 pins every regular file under brand/ and the single drift test turns red on any added, removed or changed path with a regeneration one-liner"
    requirement: "BPOL-02"
    verification:
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#manifest pin"
        status: pass
      - kind: command
        ref: "shasum -a 256 -c brand.sha256"
        status: pass
    human_judgment: false
  - id: D2
    description: "In-memory positive controls prove the drift check can go red (changed, removed, added) and stays quiet when identical"
    requirement: "BPOL-02"
    verification:
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#diff_maps/2 positive controls"
        status: pass
    human_judgment: false
  - id: D3
    description: ".gitattributes carries 'brand/** -text linguist-vendored' and brand.json is asserted as version 2.0 dated November 13, 2026"
    requirement: "BPOL-02"
    verification:
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#manifest pin"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#book provenance"
        status: pass
    human_judgment: false
  - id: D4
    description: "Privacy scan of every vendored file (home paths, non-.test emails, local file URLs, SVG/PDF/PNG/JPG metadata) is clean with no allowance, and planted/narrowness controls prove it flags and does not over-flag"
    requirement: "BPOL-02"
    verification:
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#privacy scan of the real tree"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#scan_binary/2 planted-failure controls"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/source_pin_test.exs#scan_binary/2 narrowness controls"
        status: pass
    human_judgment: false
  - id: D5
    description: "Personal-name scan of the vendored tree (BPOL-02's names clause) is not in this plan's test by design"
    requirement: "BPOL-02"
    verification: []
    human_judgment: true
    rationale: "A name cannot be written into test source; Plan 259-11's phase gate derives it at run time (id -un) and greps the whole brand/ tree, binaries included, with a recursive planted self-match control. Closes jointly with that plan."

duration: 5min
completed: 2026-11-14
plan_head_before: 1690eb23c24b479ffb94ace32cb581bc4e24dea0
plan_head_after: 1c9a960828f509b817601b9104e5f9f91912f6f0
commits: 2
status: complete
---

# Phase 259 Plan 02: Pinned brand source Summary

**A root brand.sha256 manifest (72 files, verifiable with stock `shasum -a 256 -c`), a `.gitattributes` byte-exact guard and one ExUnit module that fails on any added, removed or changed byte under brand/, plus a binary-aware privacy scan of every vendored file that is clean on the real tree without any allowance.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-11-14T15:40:11Z
- **Completed:** 2026-11-14T15:45:43Z
- **Tasks:** 2 (Task 1 was the tracer)
- **Files modified:** 3 created, 0 modified

## Accomplishments

- `brand.sha256` at the repo root, generated with the stock `find | LC_ALL=C sort -z | xargs -0 shasum -a 256` pipeline, 72 lines, `.DS_Store` excluded. `shasum -a 256 -c brand.sha256` prints 72 `OK` lines and nothing else.
- `.gitattributes` (new) holds the single line `brand/** -text linguist-vendored`.
- `test/sigra/brand/source_pin_test.exs` regenerates the manifest in memory and diffs it with a pure `diff_maps/2`. The failure message lists added, removed and changed paths and ends with the exact regeneration pipeline. A second assertion catches a manifest with the right hashes but wrong order or formatting.
- Four in-memory controls (changed, removed, added, identical) prove the drift check can go red. One of them was also checked by hand against a temporarily corrupted copy of the manifest (restored byte-for-byte) to see the real failure text; no file under brand/ was touched.
- `scan_binary/2` scans every real file: home-directory shapes (macOS, Linux, Windows profile), `/private/var/`, absolute `file:///` URLs, emails whose domain does not end in `.test`, SVG metadata/creator/editor markers, PDF `/Author` plus Creator and Producer string values (balanced, escape-aware parsing), PNG tEXt/iTXt/zTXt/eXIf chunks by walking length-prefixed chunks, JPG Exif marker, and printable-string runs of binary fonts. The real tree is clean with no allowance; the bare `file://` in a benign JS comment at `brand/sigra-brand-book.html:687` passes because the rule needs the third slash plus a path.
- 13 planted-failure tests and 7 narrowness tests (benign `file://` comment, plain https URL with no URL rule, `.test` email, `tEXt`/`eXIf` bytes inside PNG chunk data, malformed PNG flagged, clean JPG/SVG/PDF) prove the scan flags what it claims and does not over-flag.
- Version constants: `brand/brand.json` decodes (stdlib `JSON`) to version `"2.0"` and date `"November 13, 2026"`.

## Task Commits

1. **Task 1: Manifest, .gitattributes and the drift test with positive control (tracer)** - `36db6cc80` (test)
2. **Task 2: Privacy scan, planted-failure controls, version constants** - `1c9a96082` (test)

The tracer gate ran after Task 1: auto mode off (`_auto_chain_active` and `auto_advance` false), `human_verify_mode` end-of-phase, tracer verify automated-only, so the verify was re-run (7 tests, 0 failures, 72/72 OK) and expansion continued with no checkpoint.

**Plan metadata:** recorded in the follow-up `docs(259-02)` commit (SUMMARY, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `brand.sha256` - pins all 72 regular files under brand/ (7,436 bytes)
- `.gitattributes` - byte-exact vendoring guard for brand/
- `test/sigra/brand/source_pin_test.exs` - drift test, privacy scan, planted and narrowness controls (30 tests)

## Decisions Made

- Single scanner function: the plan's action names `scan_binary/2` and its behavior block names `scan_text/2`. One function covers both (planted strings use a synthetic path), avoiding a pointless alias.
- `hash_map/1` takes `%{path => bytes}` rather than a root directory, because the mutation controls need to change bytes in memory and re-hash.
- Real-tree privacy findings are reported as a failure message that says do not weaken the scan and to record the file and stop for the owner; none were produced.
- Regexes are compiled at call time, never stored in module attributes (OTP 28 / Elixir 1.19 restriction), which also keeps the home-directory prefixes fragment-built.

## Deviations from Plan

None - plan executed exactly as written.

Additions inside the plan's intent, none a deviation from its requirements: a malformed-PNG finding kind, a test that the PDF and PNG walkers actually parse the real files (non-vacuity), and extra planted controls for Linux home paths, Windows profile paths, `/private/var/`, JPG Exif and font printable strings. The plan's acceptance floor of 9 tests is exceeded (30).

**Total deviations:** 0.

## Issues Encountered

None. The vendored tree needed no change and no file under it tripped the privacy scan, so the stop-for-owner path was not taken.

## Known Stubs

None.

## Verification Results

- `mix test test/sigra/brand`: 45 tests, 0 failures (source_pin 30, policy_docs 15); `mix test test/sigra/brand/source_pin_test.exs`: 30 tests, 0 failures.
- `shasum -a 256 -c brand.sha256`: 72 OK, zero non-OK, count equals manifest line count.
- Acceptance greps: tracked brand/ file count equals manifest line count; `brand/` and `brandbook/` diff stat and porcelain status empty against `aeda7273d`; `.gitattributes` line present; every manifest line matches `<64 hex>  brand/`; no literal home-directory shape in the test source (planted control matched); no `github.io` or `og:image` text in the test source (control: `og:image` count in `brand/index.html` is 1); no personal-name word match and no email literal in the test source.
- Plan-level: zero shipped bytes (`lib priv brandbook brand .github scripts` diff stat empty, untracked empty, with the planning diff and tracked-tree sample as controls); privacy gate over the phase diff (phase planning dir excluded) clean with planted control; `mix format --check-formatted` clean for the whole repo.

## Threat Flags

None. Test-only plus two repo-root data files; no new network, auth, file-access or schema surface.

## Next Phase Readiness

Plan 259-11's phase gate owns the personal-name scan of the whole brand/ tree and the run-time derivation of the vendored book's origin host; this plan deliberately wrote neither. Later phases that read `brand/brand.json` and `brand/tokens.json` now get a hard failure on any silent edit, and re-vendoring is a one-line regeneration (printed in the failure message).

## Self-Check: PASSED

- FOUND: `brand.sha256`, `.gitattributes`, `test/sigra/brand/source_pin_test.exs`
- FOUND commits: `36db6cc80`, `1c9a96082`
- evaluation-scope (commits-only) resolved both plan commits on this branch
