# Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard — Research

**Researched:** 2026-09-18
**Domain:** In-repo CI guard mechanics (node:test prohibitions + ExUnit contract tests), decision records, monotonic ratchets
**Confidence:** HIGH — every claim below was re-derived by running a command against the working tree at HEAD `ab99f0e5`. No web sources were used and none were needed; this phase is entirely in-repo.

**Method note:** every coordinate cited here was located **by content**, then the line number read back. All verification ran through `bash -c`. No repo file was modified.

---

## Summary

Five of the six research targets resolved cleanly and one produced a **scope finding large enough that the planner must read it before decomposing DEBT-03**: three of D-13's four declared parity legs are *already implemented*, byte-for-byte including both edge cases, by `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs`. The only genuinely new leg in `p21` is the manifest ↔ `MAINTAINING.md` leg, and that leg has exactly one clean RED at HEAD.

The other headline results: the ADR convention exists and is `.planning/decisions/NNN-slug.md` (next number **004**, exactly as `PITFALLS.md:303` already instructs); the `235-FAST-01-REMEDIATION.json` **file** has two other live readers so it must not be deleted — only `phase_233`'s dependency on it is retired; the D-19 regex relaxation is **provably safe** (7 newly-matched lines across the widened universe, all pinned + comment-annotated, zero would-fail); and all three ratchet baselines (**337 / 220 / 58**) reproduce byte-exact at HEAD with commands recorded below.

**Primary recommendation:** Treat `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh` as `p18`'s **written specification** — it is a committed, fail-closed, allowlist-driven, positive-control-bearing implementation of exactly what SURF-04 asks for, authored by Phase 239 explicitly as the thing Phase 241 ports. Do not re-derive it.

---

## Conflicts with locked decisions

**One partial conflict, and one scope overlap that is not a contradiction but changes the work.**

### C-1 — D-13 leg 1, 2 and 3 already exist in `p10`. (Scope overlap, not a contradiction.)

D-13 specifies four assertions for `p21`. Verified by content in `scripts/ci/prohibitions/p10-no-undocumented-demotion.test.mjs`:

| D-13 leg | Already implemented? | `p10` test |
|---|---|---|
| every manifest `id` resolves to a `^  <id>:` in `ci.yml` | **YES** | `:72` `'every manifest id resolves to a real construct in ci.yml'` (`:83` uses `^\s+id: <id>\s*$` for `kind=step`) |
| every `kind=step` row's `parent_job_id` also appears as a `kind=job` row | **YES** | `:90` `'every step row names a parent that is itself a manifest job row'` |
| every `display_name` appears adjacent to its id | **YES** | `:101` `'display_name matches the construct name ci.yml actually declares'` |
| every row's id+parent appears in `MAINTAINING.md`'s honest-skip section | **NO** | — this is `p21`'s only novel content |

`p10` even does the gate-column comparison D-13 explicitly fences off (`:118`), scoped to rows where a single unambiguous `if:` resolves, and a rotted-gate-string check at `:177`.

This is not a violation of D-13 — nothing forbids redundancy — but the planner must decide deliberately, because **an independent re-implementation of legs 1–3 will red on day one unless it reproduces `p10`'s two hardcoded edge cases** (see `## Common Pitfalls` P-1 and P-2). Recommended resolution, inside the discretion D-13 leaves: `p21` implements **only the MAINTAINING.md leg**, and its header comment states in prose that legs 1–3 are delegated to `p10` and names the file. That keeps the honest three-way parity claim true across the guard *set* while not duplicating a parser that already carries the special cases.

### C-2 — D-22's R1 is **not** V3-based, while the folded V3 todo says `p18` "must be built on V3".

`2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md` (folded per CONTEXT `### Folded Todos`, and titled "…must be built on the twice-widened bookkeeping definition (V3)…") states the guard must use V3. D-22 pins **R1 = 337, byte-identical to `237-RATCHET-BASELINE.md`** — and that number comes from a *different, narrower* token set (the 237 Python extractor's, which is V1-shaped). Measured:

```
R1 via the 237 extractor  = 337   ✅ matches D-22
R1 via V3 over the same comment surface is not the same instrument at all
V3 over lib/ comment lines = 220  (this is R2, not R1)
237-token-set over lib/ comment lines = 205  (neither R1 nor R2)
```

D-23 already says R3 must *not* use V3. So the coherent reading is: **R1 = 237 token set, R2 = V3, R3 = literal `.planning/`** — three counters, three different definitions, each with its own reason. That is internally consistent and each baseline reproduces exactly. But it means the folded todo's "must be built on V3" is true of **R2 only**, and the plan should say so in writing rather than let a reader infer that the whole guard is V3-based. Flagged loudly rather than planned around.

Nothing else in D-01..D-27 is contradicted by anything found.

---

## User Constraints (from CONTEXT.md)

All 27 decisions D-01..D-27 are locked and are reproduced by reference, not restated. This research assumes them. Verification status of the decisions that carried an explicit "verify this" instruction:

| Decision | Instruction | Verified outcome |
|---|---|---|
| D-01 | deletion is exactly two files | ✅ confirmed — see `## DEBT-01` |
| D-02 | `mix ci` alias never edited; it is a seven-element list at `mix.exs:149-157` | ✅ confirmed verbatim |
| D-03 | ADR must name `235.1` as an affected consumer | ✅ confirmed — and **10 refs**, not one, carry live consumers |
| D-04 | resolve the ADR's home before Task 1 | ✅ **RESOLVED** — `.planning/decisions/`, next number **004** |
| D-10 | sweep `scripts/` for another reader of the JSON | ✅ **a reader exists** — this changes the plan |
| D-15 | re-locate the `MAINTAINING.md` rot by content | ✅ confirmed at `:263-269`, `:278-282`, `:321-322` — plus **two rots D-15 did not name** |
| D-18/D-19 | composite-action universe + regex relaxation | ✅ confirmed; blast radius measured at 7 lines, all clean |
| D-22 | R1/R2/R3 baselines | ✅ all three reproduce byte-exact |
| D-26 | only 1 V3 hit in `priv/templates/` | ✅ confirmed, and it is an **allowlisted false positive** |
| D-27 | prohibitions glob `run:` is at `ci.yml:408` | ✅ confirmed verbatim |

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEBT-01 | ADR + delete `ExUnitTimingFormatter` | `## DEBT-01` — ADR home resolved, deletion scope proven two-file, cross-ref consumer sweep done |
| DEBT-02 | replace `phase_233` contract test, RED-first | `## DEBT-02` — subject-injection mechanism, fixture location, formatter constraint, receipt-retirement footprint |
| DEBT-03 | honest-skip parity guard | `## DEBT-03` — full manifest↔ci.yml↔doc parity state computed row by row; the one clean RED identified |
| DEBT-04 | composite action visible to the pin guard | `## DEBT-04` — universe + relaxation blast radius enumerated exhaustively |
| SURF-04 | `p18` leakage guard + three-counter ratchet | `## SURF-04` — three baselines reproduced, the committed spec located, fixture design constraints |

---

## Target 1 — The ADR's home and numbering (D-04) — **RESOLVED**

**ADRs live at `.planning/decisions/NNN-slug.md`.** There is no `docs/adr/` and no `.planning/adr/`; the assumptions analyst searched for the wrong directory names.

```
.planning/decisions/001-defer-sigra-lockspire-glue-package.md
.planning/decisions/002-strategic-bets-v1.33.md
.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md
.planning/decisions/003-tag-delete-list.tsv          # data sidecar of ADR 003, not an ADR
```

`003-…` is the "ADR 003" `MEMORY.md` cites — confirmed by content: `PROJECT.md:196` says *"Root cause of the phantom `1.20.0` captured in ADR 003 (`.planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md`)"*.

**Convention (from 001 and 003; 002 is a bet-evaluation doc, not an ADR, and is deliberately not titled "ADR 002"):**

- Filename: `NNN-kebab-slug.md`, zero-padded three digits.
- H1: `# ADR NNN: <one-sentence decision statement>`
- Bold pseudo-frontmatter lines immediately after the H1, in this order — **no YAML frontmatter**:
  ```
  **Status:** Accepted
  **Date:** YYYY-MM-DD
  **Context:** Phase NNN (<milestone>) — <one clause>
  ```
- Body sections observed across both: a problem/footgun section, `## Decision`, `## Consequences` (001) or `## Decision — guardrails to preserve (do NOT regress these)` as a numbered list (003), and `## Revisit triggers` (001).
- Amendments are made **in place with a strikethrough and a dated retraction**, never by silent edit. `003:35-40` is the live example: `~~old sentence~~ **Corrected 2026-09-17 — that sentence was false when written and is retracted here rather than left standing.**` Follow this if the ADR is ever amended.
- A data sidecar for an ADR is committed **beside it** with the same number prefix (`003-tag-delete-list.tsv`), with a comment header carrying a why-block and a consumers-block.

**Next number: `004`.** Nothing occupies it. `PITFALLS.md:303` already prescribes the number and content verbatim:

> *"Write an ADR (004) that states TEST-01/TEST-02 are superseded by the single-owner `mix ci` topology, why, and what the replacement guarantee is."*

Suggested slug, consistent with 001/003's naming: `004-test-01-02-superseded-by-single-owner-mix-ci.md`.

**Confidence: HIGH.** `[VERIFIED: .planning/decisions/ listing + .planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md:1-4 + .planning/research/PITFALLS.md:303]`

**No guard asserts ADR numbering or format.** `grep` over `*.exs *.mjs *.sh *.yml` found no test reading `.planning/decisions/` except `scripts/maintainers/delete-planning-tags.sh:62`, which reads the TSV sidecar only. So the ADR is prose-only and cannot red anything — but also nothing will catch a wrong number.

---

## Target 2 — Does any `scripts/` reader consume `235-FAST-01-REMEDIATION.json`? (D-10) — **YES**

**This changes the plan. The JSON file must NOT be deleted.**

Sweep of `scripts/`, `mix.exs`, `.github/`, `test/` (excluding `.planning/` prose and `_build/`):

| Reader | How | Live? |
|---|---|---|
| `test/sigra/planning/phase_233_library_economics_contract_test.exs:6-9` | `Sigra.Test.PlanningPaths.phase_file/2` → `File.read!` at `:108` | the one being retired |
| **`scripts/ci/capture-fast-01-gap-closure.sh:42`** | `jq -r '.file_digests \| to_entries[] …' "$PHASE_DIR/235-FAST-01-REMEDIATION.json"` | **YES — live** |
| **`test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs:35`** | `File.read!(Path.join(@root, Path.join(@phase, "235-FAST-01-REMEDIATION.json"))) \|> Jason.decode!()` | **YES — live** |

The collector is invoked by `.github/workflows/fast-01-gap-closure-evidence.yml:32` and is itself asserted on by `phase_235_fast_01_source_complete_contract_test.exs:5,33` (`@protected_blob_files` names it).

**The load-bearing detail that makes D-09 safe.** `capture-fast-01-gap-closure.sh:39-42` verifies the `file_digests` blobs **at the immutable cutoff SHA**, not at HEAD:

```bash
actual="$(git show "$CUTOFF_SHA:$file_name" | sha256)" || fail "cutoff_blob_missing_${file_name}"
```

with `CUTOFF_SHA = 54c33e904155a454255952666711c882afdd06e4`. So the receipt's digest of `phase_233_library_economics_contract_test.exs` (`…:186` in the JSON, restated at `phase_233_…:185-186`) is pinned to a historical blob. **Rewriting `phase_233` at HEAD does not break the collector.** This both (a) permits D-09's retirement without collateral damage and (b) is the mechanical proof of D-09's own rationale that "nothing recomputes it".

**Disposition for the plan:** delete the *dependency*, keep the *file*. Concretely, remove from `phase_233_library_economics_contract_test.exs`:

- `@remediation_path` attribute (`:6-9`)
- test `"remediation receipt is closed, retry-free, source-bound…"` (`:80-82`)
- test `"remediation receipt rejects altered measurements…"` (`:84-101`)
- `defp remediation_receipt!/0` (`:108`)
- `defp assert_remediation_receipt!/1` (`:110-194`)
- `defp timing_consistent?/1` (`:196-210`) — **only used by the receipt assertions**
- `defp duration_seconds/2` (`:212-216`) — **only used by the receipt assertions**

The last two are the trap: leaving them behind produces unused-private-function warnings, and `mix ci` leg 4 is `compile --warnings-as-errors` (`mix.exs:153`). Deleting the tests without their helpers reds `mix ci` for a reason unrelated to the phase.

**Confidence: HIGH.** `[VERIFIED: repo-wide grep + scripts/ci/capture-fast-01-gap-closure.sh:39-42 + test/sigra/planning/phase_233_library_economics_contract_test.exs:6-9,80-101,108-216]`

---

## Target 3 — The ExUnit fail-first mechanism for DEBT-02 (D-07, D-08)

### Is the existing synthetic-string negative control sufficient for SC-2?

**No — a real committed fixture file is required**, for two independent reasons.

`phase_234_action_pinning_contract_test.exs:44-69` does establish the in-process idiom, and it is a good one:

```elixir
inventory = action_inventory("      - uses: #{action}\n", workflow_path)
error = assert_raise ExUnit.AssertionError, fn -> assert_valid_inventory!(inventory) end
assert error.message =~ workflow_path <> ":1"
assert error.message =~ reason
```

But (1) SC-2's text is literal — *"demonstrated **RED against a committed known-bad fixture**"* — and a string literal inside a test body is not a committed fixture; and (2) the repo's own acceptance rule, recorded in CONTEXT `### Established Patterns`, is "observed RED against a committed known-bad fixture, then GREEN against the real subject". `PITFALLS.md:302` states it as an acceptance criterion: *"Every WS6 guard must have a committed known-bad fixture and a demonstrated red."*

**Recommended shape: use both.** The synthetic `assert_raise` control is cheap, runs in-process on every `mix ci`, and guards against the *extractor* going vacuous. The committed fixture + env-injected subject is what satisfies SC-2 and what re-proves the direction at a future HEAD. They answer different questions.

### The fixture's home

`test/fixtures/prohibitions/` is the established directory, 16 fixtures at HEAD, named `pNN-<slug>.<ext>` with the extension matching the *subject's* type:

```
p04-concurrency-groups-main-pushes.yml   p09-job-without-timeout.yml
p05-admin-eval-red-masked.yml            p10-manifest-stale-entry.tsv
p06-fast-checks-docs-gated.yml           p19-tag-ruleset-absent-or-altered.json
p20-green-04-step-drift.yml              p17-playwright-retry-wrapper.ts   (+ 8 .md)
```

There is **no separate `test/fixtures/` convention for workflow fixtures** — `test/fixtures/` holds exactly three subdirectories (`css/`, `install_golden/tree/`, `prohibitions/`), and every known-bad workflow YAML in the repo lives under `prohibitions/`. DEBT-02's subject is a `ci.yml`, so the fixture is a `.yml`.

**Naming problem to resolve.** The `prohibitions/` directory is keyed to the `pNN` prohibition numbering, and DEBT-02's guard is an ExUnit test, not a `pNN` prohibition. Two coherent options, both inside D-08's fence:

- **(a)** `test/fixtures/prohibitions/phase241-library-economics-two-owners.yml` — reuses the directory (and its comment/format conventions) without stealing a `pNN` slot.
- **(b)** a new `test/fixtures/workflows/` directory.

Recommend **(a)**. Precedent exists for an ExUnit test consuming a `prohibitions/` fixture: `test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs:18` holds `@fixture_path "test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts"` and asserts its existence at `:100-103`. Option (b) requires a `.formatter.exs` decision it does not otherwise need.

**Formatter constraint — load-bearing.** `.formatter.exs` `inputs:` includes `"test/fixtures/{css,prohibitions}/**/*.{ex,exs}"`. A `.ex`/`.exs` fixture under `prohibitions/` **is** format-checked by `mix format --check-formatted`, which is `mix ci` leg 1. A `.yml` fixture is unaffected. Since DEBT-02's fixture is YAML this does not bite, but a plan that later adds an Elixir fixture there must keep it `mix format`-clean.

### The env-overridable subject in ExUnit

**There is no existing precedent** — `grep` over `test/sigra/planning/*.exs` found zero uses of `System.get_env` for a subject path. `@workflow_path ".github/workflows/ci.yml"` at `phase_233_…:4` is hardcoded, exactly as D-07 states.

The mirror of `scripts/ci/prohibitions/_lib.mjs:33-37` in ExUnit is a **module-attribute-free, function-resolved** subject. Module attributes are evaluated at *compile* time, so `@workflow_path System.get_env(...)` bakes the value into the BEAM file and an env var set at `mix test` time would be ignored for an already-compiled module — a silent false GREEN of exactly the class this phase retires. Use a function:

```elixir
@default_workflow ".github/workflows/ci.yml"

defp subject_path do
  case System.get_env("SIGRA_CONTRACT_SUBJECT") do
    nil -> @default_workflow
    "" -> @default_workflow
    p -> p
  end
end

defp subject! do
  p = subject_path()

  unless File.exists?(p) do
    flunk("subject not found at #{p} — a missing subject is a broken run, never an absent violation")
  end

  File.read!(p)
end
```

The `flunk` message is copied from `_lib.mjs:73-75` deliberately; the missing-subject-is-not-a-pass rule is the same rule in both runtimes. Env-var name: `_lib.mjs` uses `GSD_PROHIB_SUBJECT`; reusing that name would let a `GSD_PROHIB_SUBJECT` set for a `.mjs` fail-first run accidentally redirect the ExUnit test in the same shell. Prefer a distinct `SIGRA_CONTRACT_SUBJECT`.

**One substitutable subject only.** `_lib.mjs:16-17` states the rule: *"Secondary artifacts are always read from their real locations — a guard has exactly one substitutable subject."* `phase_233`'s test 4 (`:53-78`) reads `mix.exs` and `test/support/ci/library_test_partitions.exs`; those stay hardcoded.

### How the RED is observed and recorded via `bash -c`

`mix test <file>` exits non-zero on failure, so the two directions are:

```bash
# RED — the committed known-bad fixture. Non-zero exit is the PASS condition of this proof.
bash -c 'set -o pipefail; SIGRA_CONTRACT_SUBJECT=test/fixtures/prohibitions/phase241-library-economics-two-owners.yml \
  mix test test/sigra/planning/phase_233_library_economics_contract_test.exs 2>&1 | tee /tmp/241-red.txt; \
  rc=${PIPESTATUS[0]}; test "$rc" -ne 0 || { echo "FIXTURE DID NOT RED — this is not a proof" >&2; exit 1; }'

# GREEN — the real subject, no env override.
bash -c 'set -eo pipefail; mix test test/sigra/planning/phase_233_library_economics_contract_test.exs'
```

Both invocations and their captured output belong in `241-EVIDENCE.md` per D-08 (*"the RED is mechanized instead by a scripted `bash -c` run recorded in EVIDENCE"*).

**Non-vacuity floor for the RED.** A `mix test` that exits non-zero because the file failed to *compile* is indistinguishable from a demonstrated RED unless the assertion message is checked. Grep the captured output for the specific assertion text, not just the exit code — this is the same lesson `239-v3-vocabulary-check.sh` encodes with distinct exit codes 1 vs 3 (*"if 'the instrument cannot answer' shared an exit code with 'the surface is dirty', a broken script would be indistinguishable from a demonstrated RED"*).

### What the replacement must assert (D-06)

The three dishonest tests are `:11-27`, `:29-41`, `:43-51` — verified as restatements of HEAD's `ci.yml` shape (`assert library_job_ids(workflow) == @library_jobs` at `:14`; `assert aggregate =~ "needs: [library_tests_shard]"` at `:35`). Test 4 (`:53-78`) is the alias guard D-02 preserves **unmodified**; it is the evidence for SC-1 and asserts `ci_legs(mix_exs) == [...]` against the seven-element list.

The invariant D-06 names is already partly present at `:19-20,:23`:

```elixir
assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1
assert length(Regex.scan(~r/MIX_ENV=test mix ci/, Enum.join(Map.values(bodies), "\n"))) == 1
refute body =~ "mix test", "#{job_id} must not retain a second test command"
```

These lines already express "exactly one owner". The defect is not the assertion — it is that `@library_jobs` is a hardcoded list (`:5`) and `library_job_ids/1` (`:103-106`) is compared against it for equality at `:14`, which turns a derived property into a screenshot. The replacement should **derive** the `library_tests*` universe from the subject via `:104`'s regex and assert the count property over whatever it finds, with a non-vacuity floor (`assert length(jobs) >= 1, "the parse broke, this is not a pass"`), rather than pinning the list.

**Confidence: HIGH** for the mechanism and constraints; **MEDIUM** for the exact replacement assertion text, which is Claude's discretion per CONTEXT.

---

## Target 4 — The p18 ratchet's exact scan commands (D-22, D-23, D-26)

### The three baselines, reproduced byte-exact at HEAD

| Counter | Definition | Command (run from repo root) | Value |
|---|---|---|---|
| **R1** | `@moduledoc`/`@doc`/`@shortdoc`/`@typedoc` heredoc ranges under `lib/`, matched against the **237 token set** | `python3 .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py lib` | `total_hits=337` `distinct_sites=254` `distinct_files=69` |
| **R2** | **V3** regex over comment-only lines in tracked `lib/` Elixir sources | `grep -hnE '^[[:space:]]*#' $(git ls-files 'lib/*.ex' 'lib/*.exs') \| grep -cE "$V3"` | `220` |
| **R3** | literal `.planning/` occurrences across the packaged-docs surface | `grep -o '\.planning/' $(git ls-files docs README.md CHANGELOG.md) \| wc -l` | `58` occurrences / `32` lines / `6` files |

All three match D-22 exactly. R1 is additionally byte-identical to `237-RATCHET-BASELINE.md`'s recorded 337/254/69. R3's per-file split also reproduces the folded todo's table exactly: `CHANGELOG.md` 19 lines, `docs/uat-ci-coverage.md` 6, `docs/ga-evidence.md` 3, `docs/nyquist-posture-matrix.md` 2, `docs/audit-semantics.md` 1, `README.md` 1.

`[VERIFIED: all three commands executed at HEAD ab99f0e5]`

### The V3 regex — where it is defined and its exact current form

**Two committed copies, and they agree.**

1. `.planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md:32` — V3 verbatim in a fenced block.
2. `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh` — **runnable**, built as `V3="${V2}|${V3_VOCAB}"` from two separately-quoted shell variables, with a self-asserting substring check that exits 3 if V2 ever stops being a literal substring of V3.

V3 verbatim:

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]|\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md
```

The eight vocabulary alternations V3 adds over V2 are the tail from `\b[Pp]lan[- ]checker\b` onward. The `239-v3-vocabulary-check.sh` header records the design rule the ported guard must inherit verbatim:

> *"Detection WIDTH and asserted SURFACE are separate. V3 stays maximally wide and is never narrowed, tuned, or hand-fitted to whatever the tree happens to contain. What the criterion asserts is `hits_outside_allowlist = 0` over a pre-committed tier file list, with the raw `hits=` total printed alongside on every single run so the allowlist can never hide a number."*

**The line-vs-block matching gap.** The todo records it twice, at `:87-90` and `:129-…`:

- **Case-folding gap.** `test/example/priv/playwright/tests/golden-path.spec.ts:59` carries `post plan 04` — lowercase. Neither V2's `\bPlan [0-9]{2}\b` nor any V3 alternation matches it, because every plan-reference alternation is capital-anchored. The todo says *"Phase 241 should consider case-folding the plan-reference alternations."*
- **Line-based matching gap (the block half).** Three phrases in `sigra_auth.css` are split across two lines and match nothing line-by-line: `after rounds\n 1-2.`, `Live multi-run CI evidence`, `do not re-litigate this`. All three sit inside comment *blocks* the wider net caught anyway, so Phase 239 lost nothing — **but a line-based `p18` inherits the gap.** The todo's instruction: *"Consider block/comment-aware matching."*

Note the gap cuts both ways: block-joining lines before matching would have caught these three, but it also raises false-positive risk across line boundaries. Both changes (case-folding, block matching) are **widenings**, so either one will move R2's baseline upward from 220 and both must be measured before a baseline is committed. **Whether to adopt them is not decided by any D-NN and is an open question for the planner** (see `## Open questions`).

### `237-RATCHET-BASELINE.md` and `237-docs-attribute-scan.py` — committed and reusable

Both are committed:

```
.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-RATCHET-BASELINE.md
.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-docs-attribute-scan.py
```

`237-RATCHET-BASELINE.md`'s frontmatter names this phase explicitly: `owner: Phase 241 (p18 docs-surface ratchet, SURF-04)`. It is **not a one-off** — its `## What a later phase should do with this` section is a four-step handover instructing a re-run and a comparison against 337/254/69, and it states the ratchet's pass condition: *"A monotonic decrease (or equal) in `total_hits` is the ratchet's pass condition; an increase is a regression."* It also records a **separate, non-overlapping security-rationale count of 52** (`rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib/ | wc -l`) precisely so a future ratchet run can tell a genuine bookkeeping decrease from a collateral rationale deletion.

**The `p18` runtime problem this creates.** `237-docs-attribute-scan.py` is **Python 3** and `p18` is a `node:test` `.mjs`. `fast_checks` (`ci.yml:160`, which owns the glob at `:408`) does **no `setup-python` step** and contains no `python` reference anywhere between `:160` and `:410`. `python3` is preinstalled on `ubuntu-latest`, so shelling out would work today, but it introduces an undeclared runtime dependency into the PR critical path for a guard whose whole point is not to red for unrelated reasons.

**Recommendation:** port the extractor to JavaScript inside `p18`. The scan is ~40 lines of state machine (`start = ^\s*@(moduledoc|doc|shortdoc|typedoc)\s+(~S)?"""`, then in-block until the next `"""`) and the token regex translates directly. Keep the Python script as the cross-check: assert in EVIDENCE that the JS port and `python3 …237-docs-attribute-scan.py lib` return the same `337` at the same HEAD. That single cross-check is what makes the port trustworthy and is far cheaper than a runtime dependency.

### Prior art for a committed baseline / ratchet in this repo — **p18 is the first of its kind among `p*`, but not the first ratchet**

No `p01`–`p20` guard carries a committed baseline number. But `fast_checks` already runs three monotonic guards, each with a paired self-test step:

| Guard | Self-test | Comparator |
|---|---|---|
| `scripts/ci/quality-ledger-monotonic.sh` | `scripts/ci/quality-ledger-monotonic.test.sh` | fails on **decrease** |
| `scripts/ci/quality-findings-monotonic.sh` | `scripts/ci/quality-findings-monotonic.test.sh` | fails on **increase** |
| `scripts/ci/award-guard.mjs` | `scripts/ci/award-guard.test.mjs` | verify-then-climb |

**These compare HEAD against a git merge-base, not against a committed number.** `quality-findings-monotonic.sh:39-42` reads the ledger `guides/reference/admin-render-sha.json` at `--base` and at HEAD. That is a *different* design from the one D-22 mandates ("each with its own committed baseline"), and it has an obvious advantage — no baseline file to keep current. D-22 is locked, so the committed-number design stands; recording the alternative here so the planner does not re-discover it mid-plan and get tempted.

**The one pattern worth stealing from that family regardless** is `guides/reference/floor-rebase-declarations.json`, documented at `quality-findings-monotonic.sh:18-35`: an **optional, absent-by-default, fail-closed** escape hatch for when the *measurement basis itself* changes rather than the surface. Its rules — *"A declaration is VERIFIED, never trusted"*, every claimed prior/new total cross-checked against actual BASE and HEAD content, a single mismatch invalidating the entire declaration, no partial credit — are exactly what a three-counter ratchet needs when e.g. Phase 242's `CHANGELOG.md` fold legitimately drops R3. A plain monotonic-decrease ratchet handles that case fine (a decrease passes; the baseline is then lowered in the same commit), so the escape hatch is probably **not needed** for v1.48 — but if the planner wants one, the sanctioned shape already exists and should be copied rather than invented.

### `p03-no-green-on-empty-grep` as the D-26 positive-control precedent

`scripts/ci/prohibitions/p03-no-green-on-empty-grep.test.mjs` is three tests, and its structure is the pattern:

- `:22-27` asserts a **floor before any property assertion**: `assert.ok(captured.length >= 3, "only N captured slot(s) — the parse broke, this is not a pass.")`
- `:63-67` asserts the extractor found *something at all* before asserting what it found: `assert.ok(counts.length >= 1, '"The step ran" is not the claim; "the step ran the tests" is.')`
- `:68-72` then asserts the property, with the message naming the failure class: *"A grep that matched nothing reports success — that is the precise failure this prohibition names."*

**D-26 is already satisfied by the committed spec.** `239-v3-vocabulary-check.sh` implements exactly this with `control_defmodule`, and it measures non-zero on every tier at HEAD. Run at HEAD:

```
tier=priv-templates  hits=1  allowlisted=1  hits_outside_allowlist=0  control_defmodule=98  files_measured=119  exit=0
tier=example         hits=0  allowlisted=0  hits_outside_allowlist=0  control_defmodule=2   files_measured=2    exit=0
tier=golden          hits=0  allowlisted=0  hits_outside_allowlist=0  control_defmodule=78  files_measured=84   exit=0
```

`control_defmodule=0` raises **exit 3** with *"refusing to report success on a surface where the paired positive control is dead"*. The script also carries three further fail-closed controls the port must inherit: an empty file list → exit 3; an allowlist entry whose literal no longer matches anything in its own file → exit 3 (per-entry non-vacuity); and an allowlist entry whose path appears in none of the tier file lists → exit 3 (the union check, which closes the hole the scoped non-vacuity check opens).

### D-26 and the single `priv/templates/` hit — **it is an allowlisted false positive**

The one V3-matching line at HEAD:

```
priv/templates/sigra.gen.oauth/oauth_html.ex:54
  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 …" fill="#1877F2"/>
```

The firing alternation is `\b[0-9]{3}-[0-9]{2}\b`, matching the coordinate substring `373-12` twice inside the Facebook-logo SVG geometry. It is already dispositioned in the committed allowlist:

```
# path	literal	reason
priv/templates/sigra.gen.oauth/oauth_html.ex	M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0	FALSE-POSITIVE — SVG path coordinates …
```

**Consequence for the plan:** a `p18` that hard-fails on *any* V3 match in `priv/templates/` **reds at HEAD on a brand mark**. The guard must port the allowlist mechanism, not just the regex. The allowlist keys on `(path, literal)` — never on a line number, never on a path alone — *"so an entry cannot silently start covering something new when lines shift, and cannot blanket a whole file."* Port that keying exactly.

Also verified: `grep -rn '\.planning/'` across `git ls-files priv/templates lib` returns **zero** — the `.planning/` hard-fail class is genuinely clean at HEAD, so its RED must come from the fixture, never from the live tree.

---

## Target 5 — The composite-action universe and regex relaxation (D-18, D-19) — **blast radius measured: safe**

### The universe

Exactly one composite action exists:

```
.github/actions/example-playwright-boot/action.yml        # the only match for .github/actions/*/action.y*ml
```

No `action.yaml` variant. `@release_workflows` at `phase_234_action_pinning_contract_test.exs:4-7` is the two-file list D-18 describes, and test `:12-22` asserts that list is *exactly* those two entries — so **widening `@release_workflows` in place would red that test**. Add a **separate** attribute (e.g. `@composite_actions` or a `Path.wildcard(".github/actions/*/action.yml")` discovery) and extend `production_inventory/0` at `:94-101`, leaving `:12-22` and the `"./"` blessing at `:71-76` untouched — exactly as D-18 requires.

Prefer `Path.wildcard/1` over a literal list so a second composite action is covered automatically; pair it with a non-vacuity floor (`assert length(files) >= 1`) so an empty glob cannot report green.

### D-19's premise, re-verified by content

`action.yml`'s four `uses:` and their forms:

| Line | Form | Action |
|---|---|---|
| 49 | `    - uses:` (dashed) | `erlef/setup-beam@54075bcc…f124 # v1.24.1` |
| 55 | `    - uses:` (dashed) | `actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0` |
| **63** | `      uses:` (**bare**) | `actions/cache@55cc8345…52a9 # v6.1.0` |
| **111** | `      uses:` (**bare**) | `actions/cache@55cc8345…52a9 # v6.1.0` |

D-19 is confirmed exactly: the inventory regex at `:108` is `~r/^\s*-\s+uses:\s+([^\s#]+)(?:\s+#\s*(.+))?\s*$/` and requires the dash. Without the relaxation, picking line 63 or 111 for SC-4's "unpin one of its four" leaves the guard green and DEBT-04 ships closed with half the composite action's supply-chain surface invisible.

### **Enumeration of every line the relaxed regex newly matches** — the requested blast-radius sweep

Relaxing `^\s*-\s+uses:` → `^\s*(?:-\s+)?uses:` over the widened universe (2 release workflows + 1 composite action). Measured by running both regexes line-by-line through Elixir's `Regex.run/2` with the test's own `action_entry/4` and `assert_valid_inventory!/1` logic:

| File | Line | Action | Pinned 40-hex? | `# vN.N.N` comment? | Verdict |
|---|---|---|---|---|---|
| `release-please.yml` | 88 | `googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7` | ✅ | ✅ `v5.0.0` | passes |
| `release-please.yml` | 157 | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | ✅ | ✅ `v6.1.0` | passes |
| `release-please.yml` | 285 | `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | ✅ | ✅ `v7.0.1` | passes |
| `hex-publish.yml` | 100 | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | ✅ | ✅ `v6.1.0` | passes |
| `hex-publish.yml` | 217 | `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | ✅ | ✅ `v7.0.1` | passes |
| `action.yml` | 63 | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | ✅ | ✅ `v6.1.0` | passes |
| `action.yml` | 111 | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | ✅ | ✅ `v6.1.0` | passes |

**Seven newly-matched lines. Zero would-fail. The full relaxed inventory over the widened universe is clean at HEAD.** `[VERIFIED: /tmp/relax_probe.exs executed against HEAD, both regexes, with the test's own validity predicates]`

**Two details worth pinning:**

- **Double-space before `#`.** `release-please.yml:285` and `hex-publish.yml:217` have `…0a  # v7.0.1` with two spaces. The `(?:\s+#\s*(.+))?` group absorbs it and `comment` captures `"v7.0.1"`. No change needed — verified, not assumed. Three *pre-existing* dashed lines share this shape (`release-please.yml:110,311`, and `ci.yml:165`'s checkout).
- **Inventory size.** Current inventory = **7** entries (5 dashed in `release-please.yml`, 2 in `hex-publish.yml`). After relaxation + widening = **16** (7 + 5 newly-matched in existing files + 4 in `action.yml`). The non-vacuity floor at `:27-28` (`assert inventory != []`) still holds; consider raising it to a numeric floor so a future regex regression that silently halves the inventory is caught.

**Direct answer to the stated fear:** the relaxation cannot silently pull in dozens of new `uses:` lines from existing workflows, because the scanned universe is an **explicit file list**, not a glob over `.github/workflows/`. `ci.yml` has many `uses:` lines and remains entirely out of scope (the composite-action todo names this as a separate known gap — see `## Open questions`). The relaxation's blast radius is bounded by the universe, and within that universe it is the seven lines above, all clean.

### Proving the relaxation itself with a fixture (D-19/D-20)

Two fixtures are needed, because two different things must be proven and one fixture cannot prove both non-vacuously (this is exactly the `2026-09-17-p19-known-bad-fixture-short-circuits` lesson, applied prospectively):

1. **`…-composite-unpinned-bare-uses.yml`** — a copy of `action.yml` with the **bare** `uses:` at line 63 or 111 changed to a floating tag (`actions/cache@v6`). Reds *only if* the regex was relaxed. This is the proof of the relaxation.
2. **`…-composite-unpinned-dashed-uses.yml`** — the same with the **dashed** `uses:` at 49 or 55 unpinned. Reds under both old and new regex. This is the proof of the widened universe.

Both go under `test/fixtures/prohibitions/`; the real `action.yml` is never mutated (D-20/D-21). Because `phase_234_action_pinning_contract_test.exs` has no subject indirection today, either add one (same function-not-attribute pattern as DEBT-02) or drive both fixtures through the existing in-process `action_inventory/2` + `assert_raise` idiom at `:44-69` by reading the fixture file and passing its text. The latter is a smaller change and stays inside the test's existing shape; the former satisfies the "committed fixture through a substitutable subject" reading of SC-4 more literally. Recommend the former for symmetry with DEBT-02, since both phases' guards then share one injection idiom.

---

## Target 6 — The honest-skip parity guard's inputs (D-13, D-15)

### `.github/ci-skip-manifest.tsv` in full

**59 comment lines, 1 header row at `:60`, 16 data rows at `:61-76`.** 8 tab-separated columns: `tier · kind · id · parent_job_id · display_name · gate_level · gate · observer`. `_lib.mjs:201-225` already parses it (`parseSkipManifest`), throws on a row with fewer than 8 columns, throws if no `tier` header row is seen, and throws on zero rows.

The two header citations D-12 names are at **`:8`** and **`:16`**:

```
#  8: # scripts/ci/prohibitions/honest-skip-parity.test.mjs asserts
# 16: #   - scripts/ci/prohibitions/honest-skip-parity.test.mjs   three-way parity guard
```

Both are inside the `#` comment block, so `parseSkipManifest` skips them and renaming to `p21-honest-skip-parity.test.mjs` cannot red `p10`. **Note:** `test/fixtures/prohibitions/p10-manifest-stale-entry.tsv` is a copy of the manifest **including that same header**, so it carries the identical stale citation. Updating the live manifest without the fixture leaves a second copy of the false claim in the tree. Neither `p10` nor anything else asserts on the header text, so it is cosmetic — but it is the same rot class this phase retires, and the fixture is the substituted subject, so a copy is cheap.

The 16 rows:

| # | tier | kind | id | parent | gate_level | observer |
|---|---|---|---|---|---|---|
| 61 | A | job | `install_matrix` | – | job | ignore |
| 62 | A | job | `upgrade_smoke` | – | job | ignore |
| 63 | A | job | `passkeys_manual_fallback_smoke` | – | job | ignore |
| 64 | A | job | `passkeys_opt_out_smoke` | – | job | ignore |
| 65 | A | job | `nightly_probe` | – | job | ignore |
| 66 | A | job | `admin_design_recapture` | – | job | ignore |
| 67 | A | job | `admin_checkpoint_recapture` | – | job | ignore |
| 68 | A | job | `notify_release_lane_rot` | – | job | exempt |
| 69 | B | job | `admin_eval_render` | – | job | **assert** |
| 70 | B | **step** | `design_gallery_snapshots` | `example_playwright_shard` | step | **assert** |
| 71 | C | job | `example_playwright_shard` | – | step | ignore |
| 72 | C | job | `library_tests_dep_off` | – | job | ignore |
| 73 | C | job | `example_unit_smoke` | – | step | ignore |
| 74 | C | job | `install_smoke` | – | step | ignore |
| 75 | C | job | `example_http_smoke` | – | step | ignore |
| 76 | C | job | `example_playwright_smoke` | – | step | ignore |

Exactly one `kind=step` row, and its parent is present as a `kind=job` row (`:71`). D-14's fence holds: `example_unit_smoke` is row `:73` and the guard must not assert `ci-gate.needs` membership.

### **Exact parity state at HEAD — which assertions go RED on day one**

Computed row by row against `ci.yml` and `MAINTAINING.md` at HEAD.

**Leg 1 — id → `^  <id>:` in `ci.yml` (or `^\s+id: <id>` for the step row): 16/16 PASS.** Zero reds.

**Leg 2 — every step row's parent is a manifest `kind=job` row: 1/1 PASS.** Zero reds.

**Leg 3 — `display_name` adjacent to its id in `ci.yml`: 14/16 pass under a naive check; 16/16 under `p10`'s.** The two that a naive implementation reds on:

- **`example_playwright_shard`** — `ci.yml:1190` declares `name: Example Playwright shard (${{ matrix.seam }})`; the manifest records the *materialized* `Example Playwright shard (design_gallery)`. `p10:103-105` carries a hardcoded special case for exactly this id.
- **`install_smoke`** — two YAML comment lines sit between `^  install_smoke:` (`ci.yml`) and its `name:`, so a strict next-line-equality check fails. `p10:107` sidesteps this by matching `^ {4}name: <escaped>` anywhere in the file rather than requiring adjacency.

**Leg 4 — manifest id + parent present in `MAINTAINING.md`'s honest-skip section (`:232-297`): 15/16 pass, 1 RED.**

| Row | In `MAINTAINING.md` at all? | Verdict |
|---|---|---|
| all rows except `example_playwright_shard` | yes | pass |
| **`example_playwright_shard`** (row `:71`, and the parent of the row `:70` step) | **absent from the entire file — 0 grep hits** | **RED** |

**This is the free, uncontrived RED D-16 needs.** It fires on both sub-checks of leg 4 simultaneously (the id-as-a-row check and the parent-of-a-step-row check), it is caused by real rot rather than by construction, and it is fixed by the same `MAINTAINING.md` correction D-15 mandates.

### D-15's coordinates, confirmed by content — **and two rots D-15 did not name**

| Location | Claim in `MAINTAINING.md` | Reality at HEAD | Named by D-15? |
|---|---|---|---|
| `:263`, `:269` | step `design_gallery_snapshots` is "inside `example_playwright_smoke`" | the step is at `ci.yml:1318`, inside the job that opens at `ci.yml:1189` — **`example_playwright_shard`** | ✅ yes |
| `:268`, `:322` | cites a step named `` `Aggregate Playwright step outcomes` `` | **zero grep hits in `ci.yml`.** The real step is `Aggregate every Playwright shard result` at `ci.yml:1395` | ✅ yes |
| **`:263`** | quotes the step's display name as `"Run design gallery board snapshots (non-PR)"` | `ci.yml:1317` declares `name: Run design gallery behavior and snapshots` (the manifest's `display_name` is correct; only the doc is wrong) | ❌ **unnamed** |
| **`:278-282`** | lists `example_playwright_smoke` among "the heavy steps … of the four app-behaviour ruleset-required lanes … each guarded `if: needs.changes.outputs.docs_only != 'true'`" | `example_playwright_smoke` (`ci.yml:1388-1415`) is a **pure aggregator with exactly one step** and **no docs_only step gate at all**. Its only step is `Aggregate every Playwright shard result` | ❌ **unnamed** |
| **`:320-322`** | quotes the docs-only backstop line as `"docs-only fast path: every Playwright seam was skipped -- no browser assertion was made on this run"` | `ci.yml:1411` emits `"docs-only fast path: every Playwright seam was skipped (all five shard browser bodies)"` | partially (D-15 names `:322` for the step-name rot only) |
| `:265` | quotes the step's `if:` as `!cancelled() && github.event_name != 'pull_request' && needs.changes.outputs.docs_only != 'true'` | `ci.yml:1319` declares `!cancelled() && needs.changes.outputs.docs_only != 'true' && matrix.seam == 'design_gallery' && github.event_name != 'pull_request'` — the `matrix.seam` clause is missing from the doc | outside D-13's fence (do not parse gates semantically) |

**D-15's cited line numbers are accurate.** `:263-269`, `:280`, `:322` are all real and all rotted. `MAINTAINING.md:172-178,231` — the coordinates DEBT-01..04's requirement text and the `2026-09-15-honest-skip-parity-guard-does-not-exist` todo both cite — are confirmed unrelated prose: `:172-178` is the `p19` drift-observer honest caveat (`:176` begins *"**Honest caveat on the drift observer.**"*) and `:231` sits inside the "CI cadence — PR-fast vs nightly/main-broad (Phase 196)" section that ends at `:231`. `DEBT-03`'s requirement text and `ROADMAP` SC-3 both carry the stale citation; **do not repeat it in the plan.**

### One manifest rot the guard will *not* catch, recorded rather than fixed

Manifest row `:76` records `example_playwright_smoke` with `gate_level=step` and `gate=needs.changes.outputs.docs_only != 'true'`. At HEAD that job has **no step-level docs_only gate**; the real gate lives in `example_playwright_shard`'s steps. `p10:125-133` explicitly *skips* the `if:`-vs-`gate` comparison for `kind=job` rows with `gate_level=step` (the comment at `:126-131` says the manifest carries no step id for these rows to resolve unambiguously), and D-13 forbids `p21` from parsing the gate column semantically. So this is a **real, unasserted manifest inaccuracy that survives this phase by design**. It is correctly out of scope — recording it here so the planner can decide whether to file a todo rather than discover it in review.

### Offline-only (D-17)

`p21` needs `ci-skip-manifest.tsv`, `ci.yml`, and `MAINTAINING.md` — three committed files. No `gh`, no token, no network, matching `p20`'s standing-constraint header (*"it can be run on a plane"*).

---

## DEBT-01 — deletion scope and the ADR's consumer sweep

### The deletion is exactly two files ✅

Repo-wide grep for `ExUnitTimingFormatter` and `SIGRA_EXUNIT_TIMING`, excluding `_build/`, `deps/`, `node_modules/`, `.git/`, `.gsd/`, `.planning/`:

```
test/support/ci/ex_unit_timing_formatter.ex        :1, :17, :23
test/support/ci/ex_unit_timing_formatter_test.exs  :1, :4, :8, :39, :54, :66, :67, :76, :77
```

Plus two stale `_build/test/lib/sigra/ebin/*.beam` artifacts, which are not source. D-01 confirmed exactly.

Sibling file `test/support/ci/library_test_partitions.exs` does **not** reference the formatter (checked by content), so the shard partitions are unaffected. `mix.exs:55` is `defp elixirc_paths(:test), do: ["lib", "test/support"]` — removing one `.ex` from that tree changes nothing else.

`.formatter.exs` `inputs:` includes `"test/{sigra,support,mix}/**/*.{ex,exs}"`, so both deleted files leave the formatter's input set cleanly.

### The cross-ref consumer sweep for the ADR (D-03 + `PITFALLS.md:304`) — **10 refs, not one**

`PITFALLS.md:304` asks for this as an assertion, not a claim. Run across every local and remote ref:

**Refs carrying `SIGRA_EXUNIT_TIMING_PATH` in non-`test/support`, non-`.planning/` files:**

| Ref | Affected paths |
|---|---|
| `refs/heads/agent-exec-235-1-04-evidence` | `.github/workflows/ci.yml`, `scripts/ci/library-economics.sh`, `…test.sh`, `test/sigra/planning/phase_233_…`, `phase_235_1_…` |
| `refs/heads/agent-exec-235-1-12-evidence` | `scripts/ci/library-economics.{sh,test.sh}`, `library-partitions.{sh,test.sh}`, `phase_235_1_…` |
| `refs/heads/agent-exec-235-1-18-evidence` | same five |
| `refs/heads/agent-exec-235-1-29-authority` | the above + `library-partitions-portability.test.sh` |
| `refs/heads/ci/phase-235-1-evidence` | five paths |
| **`refs/heads/ci/phase-235-16-source-complete`** | six paths (this is the documented keep-list safety ref) |
| `refs/heads/gsd/phase-232-playwright-economics` | `.github/workflows/ci.yml`, `phase_233_…` |
| `refs/remotes/origin/ci/phase-235-1-evidence` | six paths |
| `refs/remotes/origin/ci/phase-235-16-source-complete` | five paths incl. `.github/workflows/ci.yml` |
| `refs/remotes/origin/gsd/phase-232-playwright-economics` | `.github/workflows/ci.yml`, `phase_233_…` |

**D-03 names the parked `235.1` branch. The sweep finds it and nine more**, including `gsd/phase-232-playwright-economics` — a *different* branch family D-03 does not mention. All ten belong in the ADR's affected-consumers list. This strengthens D-03 rather than contradicting it, and it is the `PITFALLS.md:295` risk made concrete: *"Deleting the module on `main` makes that branch unmergeable-as-is. That is fine if it is a recorded decision; it is data loss if nobody notices."*

Reproducible command for the plan's evidence:

```bash
bash -c 'for r in $(git for-each-ref --format="%(refname)" refs/heads refs/remotes); do
  git grep -l "SIGRA_EXUNIT_TIMING_PATH" "$r" 2>/dev/null \
    | grep -v "test/support" | grep -v "^\S*:\.planning"
done'
```

`[VERIFIED: executed at HEAD; `git grep` across 10 matching refs]`

### The `mix ci` green claim (D-05)

`mix.exs:149-157` verbatim:

```elixir
      ci: [
        "format --check-formatted",
        "deps.get --check-locked",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "test --exclude scaffold",
        "ci.install_golden",
        "sigra.dep_off"
      ],
```

Seven elements, no `--formatter`, byte-identical to the list `phase_233_…:61-69` asserts. D-02 confirmed. **`mix ci` was deliberately not run** per the research constraint (6 environmental `Sigra.Audit.Forwarders.ThreadlineTest` failures); the green claim is made against CI at the same commit, per D-05.

---

## SURF-04 — `p18` design constraints

### Zero-workflow-edit pickup is real and already guarded

- `ci.yml:408`: `run: node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — inside `fast_checks` (job header at `ci.yml:160`). D-27 confirmed exactly.
- The glob is `*.test.mjs`, so `_lib.mjs` is correctly excluded and any `p18-*.test.mjs` / `p21-*.test.mjs` is picked up with **no workflow edit**.
- `test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs:105-111` already asserts that exact glob string survives in `ci.yml`, and `:113-120` asserts `mix.exs` **never** references `scripts/ci/prohibitions` (*"standing constraint 5"*). Both constraints the phase must respect are therefore already machine-enforced — a plan that accidentally wires `p18` into `mix ci` reds an existing test.
- `mix.exs`'s aliases contain no node leg, so a `.mjs` guard **cannot** enter `mix ci` by construction. D-27 confirmed.

### Fixture design for D-25 (three independently-reachable violations)

The `2026-09-17-p19-known-bad-fixture-short-circuits` todo's own suggested fix is *"Split into two fixtures, one violation each, so each branch has its own proof"* — applied to `p18`, that means **three fixtures, one violation class each**, not one fixture with three.

This interacts with the GSD machinery: `subjectPath()` substitutes exactly **one** subject per guard invocation. Three fixtures therefore implies either three guard files or a guard that reads a subject *directory*. Both satisfy SURF-04's `p18-*.test.mjs` glob:

- `scripts/ci/prohibitions/p18-planning-paths.test.mjs` → fixture with a `.planning/` path
- `scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs` → fixture with a V3 bookkeeping token in a template
- `scripts/ci/prohibitions/p18-doc-range-bookkeeping.test.mjs` → fixture with a token inside a `@moduledoc """ … """` range

Three sibling files is cleaner than one file with three subjects, gives each violation its own genuinely independent RED, and is explicitly inside Claude's Discretion (*"Whether R1/R2/R3 live in one `p18` file with three assertions or three sibling files"*).

**Caution on an Elixir fixture.** A fixture for the doc-range class is naturally a `.ex`, and `.formatter.exs` includes `test/fixtures/prohibitions/**/*.{ex,exs}` — so it **is** format-checked by `mix ci` leg 1 and must be `mix format`-clean. This is survivable (a `defmodule` with a `@moduledoc """…"""` formats fine) but it is a trip-wire worth naming in the task.

### R1/R2/R3 as three separate counters (D-22)

The measured commands are in `## Target 4`. Three separate committed baselines, three separate comparisons, no fusion — D-22's ratchet-defeat concern (a CHANGELOG fold in Phase 242 dropping R3 by ~40 and licensing 40 new `lib/` comments) is structurally impossible once the counters are independent.

`guides/` is out of scope (D-24). Confirmed against the source of truth: `mix.exs:184` is

```elixir
      files: ~w(lib priv docs .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
```

— `guides` is absent, so guides never ship in the tarball. D-24's premise is correct.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Parse `.github/ci-skip-manifest.tsv` | a TSV reader in `p21` | `_lib.mjs:201-225` `parseSkipManifest` | already throws on <8 columns, missing header, zero rows |
| Split `ci.yml` into job blocks | a second YAML walker | `_lib.mjs:93-113` `jobBlocks` / `:179-182` `jobBlock` | handles the `on:` block's 2-space keys leaking in |
| Strip YAML comments before content assertions | a naive `s/#.*//` | `_lib.mjs:128-146` `stripYamlComments` | quote-aware; `ci.yml` documents its own design in comments containing the tokens being matched |
| Normalize a GHA `if:` expression | bespoke normalization | `_lib.mjs:191-198` `normalizeExpr` | the bare-vs-`${{ }}` split is the exact form a naive regex drops |
| The V3 bookkeeping definition + allowlist + positive controls | re-derive from the todo | port `239-v3-vocabulary-check.sh` | it is the committed spec, self-asserts V2⊂V3, and carries four fail-closed controls |
| The `lib/` doc-range extractor | invent a heredoc walker | port `237-docs-attribute-scan.py` | committed, reproduces 337 exactly, cross-checkable |
| A monotonic ratchet's escape hatch | design one | `guides/reference/floor-rebase-declarations.json` + `quality-findings-monotonic.sh:18-35` | verified-never-trusted, single-use, fail-closed — if one is needed at all |
| Legs 1–3 of `p21` | reimplement | delegate to `p10` and say so | `p10` carries the two edge cases a fresh implementation will miss |

---

## Common Pitfalls

### P-1: Reimplementing the `display_name` check and reding on a templated matrix name
`ci.yml:1190` is `name: Example Playwright shard (${{ matrix.seam }})`; the manifest records `Example Playwright shard (design_gallery)`. Any literal comparison reds. `p10:103-105` hardcodes the exception. **Avoid:** delegate leg 3 to `p10`. **Warning sign:** a `p21` draft that iterates all 16 rows comparing names.

### P-2: Assuming `name:` is the line after `<job_id>:`
`install_smoke` has two comment lines between them. `p10:107` matches `^ {4}name: <escaped>` anywhere rather than requiring adjacency. **Warning sign:** a `sed -n "$((n+1))p"` in a task's verification command.

### P-3: Deleting the receipt tests but not their private helpers
`timing_consistent?/1` and `duration_seconds/2` are used *only* by the receipt assertions. Leaving them reds `mix ci` leg 4 (`compile --warnings-as-errors`) for a reason unrelated to the diff. **Warning sign:** a task that names only the two `test` blocks.

### P-4: Deleting `235-FAST-01-REMEDIATION.json` itself
Two other live readers. `scripts/ci/capture-fast-01-gap-closure.sh:42` and `phase_235_fast_01_gap_closure_contract_test.exs:35`. Retire the **dependency**, keep the **file**.

### P-5: `p18` hard-failing on the allowlisted SVG false positive
`priv/templates/sigra.gen.oauth/oauth_html.ex:54` matches V3 via `\b[0-9]{3}-[0-9]{2}\b` on the coordinate `373-12`. A hard-fail without the allowlist reds at HEAD on a brand mark.

### P-6: A green `p18` because the file list was empty
`239-v3-vocabulary-check.sh` raises exit **3** for an empty file list and for `control_defmodule=0`. Port both. `p03` is the in-repo articulation: *"A grep that matched nothing reports success."*

### P-7: One RED exit code for two different failures
`239-v3-vocabulary-check.sh`'s header states the rule: exit 1 = the surface is dirty; exit 3 = the instrument cannot answer. Collapsing them makes a broken guard indistinguishable from a demonstrated RED — which is the failure this phase exists to retire.

### P-8: `@workflow_path System.get_env(...)` as a module attribute
Evaluated at compile time; the env var is baked into the `.beam`. A later `SIGRA_CONTRACT_SUBJECT=…` run silently reads the *old* path and reports green. Use a function.

### P-9: Widening `@release_workflows` in place
`phase_234_action_pinning_contract_test.exs:12-22` asserts that list is exactly two entries. Add a separate composite-action universe.

### P-10: Correcting `MAINTAINING.md` before the guard exists
D-16 and `PITFALLS.md:305`. A guard authored after the doc is fixed has never been seen failing. Order: write `p21` → observe the `example_playwright_shard` RED → correct the doc → observe GREEN.

---

## Code Examples

### The fail-first subject indirection this phase mirrors

```javascript
// Source: scripts/ci/prohibitions/_lib.mjs:33-37, 70-78
export function subjectPath(defaultRelPath) {
  const injected = process.env.GSD_PROHIB_SUBJECT;
  if (injected && injected.length > 0) return resolve(injected);
  return resolve(REPO_ROOT, archiveAwareRelPath(defaultRelPath));
}

export function readSubject(defaultRelPath) {
  const p = subjectPath(defaultRelPath);
  if (!existsSync(p)) {
    throw new Error(
      `subject not found at ${p} — a missing subject is a broken run, never an absent violation`,
    );
  }
  return readFileSync(p, 'utf8');
}
```

### The positive-control-before-property idiom (D-26)

```javascript
// Source: scripts/ci/prohibitions/p03-no-green-on-empty-grep.test.mjs:59-72
test('a non-zero executed test count is on the record for the demoted work', () => {
  const counts = captured
    .flatMap((s) => [...s.text.matchAll(/\b(\d+)\s+passed\b/g)])
    .map((m) => Number(m[1]));
  assert.ok(counts.length >= 1, 'no captured slot records an executed test count (`N passed`).');
  assert.ok(
    counts.some((n) => n > 0),
    `every recorded test count is zero (${counts.join(', ')}). A grep that matched nothing ` +
      `reports success — that is the precise failure this prohibition names.`,
  );
});
```

### The in-process ExUnit negative control already in the repo

```elixir
# Source: test/sigra/planning/phase_234_action_pinning_contract_test.exs:57-68
for {name, action, reason} <- invalid_actions do
  workflow_path = "synthetic/#{String.replace(name, " ", "-")}.yml"
  inventory = action_inventory("      - uses: #{action}\n", workflow_path)

  error = assert_raise ExUnit.AssertionError, fn -> assert_valid_inventory!(inventory) end

  assert error.message =~ workflow_path <> ":1"
  assert error.message =~ reason
end
```

### The blessing D-18 must leave untouched

```elixir
# Source: test/sigra/planning/phase_234_action_pinning_contract_test.exs:71-76, :130
test "repository-local actions are deliberately outside third-party scope" do
  assert action_inventory("      - uses: ./.github/actions/release-guard\n", "synthetic/local.yml") == []
end

defp action_entry(_workflow_path, _line_number, "./" <> _local_action, _comment), do: []
```

---

## Project Constraints (from CLAUDE.md)

Relevant to this phase:

- **GSD Workflow Enforcement** — file-changing work goes through a GSD command. This research made no edits.
- **Testing** — "Comprehensive spec coverage — happy path, main error cases, boundary conditions. AAA style, flat, self-contained." The `p*` guards and planning contract tests follow this: flat `test(...)` blocks, no shared setup, each reading its own subject.
- **Local development prerequisites** — `mix test` needs a live Postgres. Not exercised here.
- **Public repo** — no adopter PII and no brand hex values in artifacts. The one hex value encountered (`#1877F2`, the Facebook brand blue inside the OAuth template's SVG) is a **third-party public brand constant already committed to this public repo in `priv/templates/`**, quoted here only because it appears inside the exact line the V3 allowlist entry disposes of. No adopter data of any kind appears in this file.

---

## Environment Availability

| Dependency | Required by | Available locally | In `fast_checks` | Fallback |
|---|---|---|---|---|
| `node` (node:test) | `p18`, `p21` | ✓ | ✓ (glob at `ci.yml:408` already runs) | — |
| `python3` | `237-docs-attribute-scan.py` (R1) | ✓ | **not declared** — no `setup-python` between `ci.yml:160-410` | **port the extractor to JS**; keep Python as a cross-check |
| `elixir` / `mix` | DEBT-01, DEBT-02 | ✓ | separate `library_tests_shard` lane | — |
| `git` | cross-ref consumer sweep, R2/R3 file lists via `git ls-files` | ✓ | ✓ | — |
| `jq` | `capture-fast-01-gap-closure.sh` only | ✓ | not needed by this phase | — |
| `gh` / network | **none** | — | — | D-17: guards are offline-only |

**No blocking gaps.** The only item with a fallback is `python3`, and the fallback (port to JS + cross-check) is strictly better.

---

## Validation Architecture

### Test framework

| Property | Value |
|---|---|
| Frameworks | ExUnit (Elixir 1.18+) **and** `node:test` (node 22) — two runtimes by design, see `_lib.mjs:3-9` |
| Config | `mix.exs` `ci:` alias at `:149-157`; `.formatter.exs` |
| Quick run (ExUnit) | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` |
| Quick run (guards) | `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` |
| Full suite | `MIX_ENV=test mix ci` (green asserted against **CI**, not local — D-05) |

### Phase requirements → test map

| Req | Behavior | Type | Automated command | Exists? |
|---|---|---|---|---|
| DEBT-01 | formatter + test gone, alias unchanged | unit | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` (test 4 at `:53-78`) | ✅ exists |
| DEBT-02 RED | replacement reds on a committed fixture | contract | `SIGRA_CONTRACT_SUBJECT=<fixture> mix test test/sigra/planning/phase_233_…` → non-zero | ❌ Wave 0 |
| DEBT-02 GREEN | replacement greens on real `ci.yml` | contract | `mix test test/sigra/planning/phase_233_…` | ✅ file exists, assertions change |
| DEBT-03 RED | `p21` reds on HEAD's `MAINTAINING.md` | guard | `node --test scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs` → non-zero | ❌ Wave 0 |
| DEBT-03 GREEN | greens after the doc is corrected | guard | same, exit 0 | ❌ Wave 0 |
| DEBT-04 both | pin guard reds on each fixture, greens on real | contract | `mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs` | ✅ file exists, universe+regex change |
| SURF-04 ×3 | each `p18-*` reds on its own fixture | guard | `GSD_PROHIB_SUBJECT=<fixture> node --test scripts/ci/prohibitions/p18-*.test.mjs` | ❌ Wave 0 |
| SURF-04 ratchet | R1/R2/R3 ≤ committed baselines | guard | the three commands in `## Target 4` | ❌ Wave 0 |

### Sampling rate

- **Per task commit:** the single affected `mix test <file>` or `node --test <guard>`.
- **Per wave merge:** `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` + `mix test test/sigra/planning/`.
- **Phase gate:** CI green (not local `mix ci` — D-05).

### Wave 0 gaps

- [ ] `test/fixtures/prohibitions/phase241-library-economics-two-owners.yml` — DEBT-02 known-bad `ci.yml`
- [ ] `test/fixtures/prohibitions/p21-honest-skip-*.{tsv|md}` — DEBT-03 known-bad
- [ ] two composite-action fixtures (bare-`uses:` and dashed-`uses:` unpinned) — DEBT-04
- [ ] three `p18-*` known-bad fixtures, one violation class each — SURF-04 / D-25
- [ ] the R1/R2/R3 baseline file (form is Claude's discretion; numbers are 337 / 220 / 58)
- [ ] `scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs`
- [ ] `scripts/ci/prohibitions/p18-*.test.mjs` (1 or 3 files)
- [ ] `.planning/decisions/004-…md`

No framework install is needed — both runtimes are already wired.

---

## Security Domain

`security_enforcement` is not disabled, so this section is included. This phase ships **no runtime code** — it touches CI guards, a decision record, one doc, and test fixtures. No `lib/` or `priv/templates/` file changes.

### Applicable ASVS categories

| ASVS Category | Applies | Standard control |
|---|---|---|
| V2 Authentication | no | no auth surface touched |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | **partially** | the guards parse untrusted-shaped committed files; `_lib.mjs` throws rather than returning empty on every parse |
| V6 Cryptography | no | the sha256 digests in `235-FAST-01-REMEDIATION.json` are verified by an existing script this phase does not modify |
| V14 Configuration | **yes** | supply-chain pinning is DEBT-04's entire subject |

### Threat patterns for this stack

| Pattern | STRIDE | Mitigation |
|---|---|---|
| Unpinned/floating GitHub Action ref in a release-critical or composite action | Tampering (supply chain) | 40-hex SHA pin + same-line `# vN.N.N` comment, asserted by `phase_234_action_pinning_contract_test.exs:116-128` — **this phase widens its reach, which is a net security improvement** |
| Annotated tag object used instead of its dereferenced commit | Tampering | `@forbidden_tag_object` refute at `:121-122` |
| Vacuous guard (green because it matched nothing) | Repudiation | non-vacuity floors + `p03`; `239-v3-vocabulary-check.sh` exit 3 |
| Planning-bookkeeping leakage into the adopter-downloaded tarball | Information disclosure (low severity) | `p18` — SURF-04's whole purpose |

**Security-rationale collateral risk.** `237-RATCHET-BASELINE.md` records **52** security-rationale comment lines in `lib/` as a separate, non-overlapping count, explicitly so a ratchet-driven comment deletion cannot quietly remove one:

```bash
rg -n -i "^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b" lib/ | wc -l
```

R2's ratchet operates on the *same* `lib/` comment surface. Any plan that lowers R2 by deleting comments must re-run that count and confirm it did not fall. Recommend the plan state this as a standing constraint.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|---|---|---|
| A1 | `.planning/decisions/004-…md` is the right next number and slug style | Target 1 | Low — the directory listing and `PITFALLS.md:303` both point here; only the slug is a guess |
| A2 | `python3` is preinstalled on the `ubuntu-latest` runner | Target 4 / Environment | Low, and the recommendation is to not depend on it |
| A3 | Splitting `p18` into three sibling files satisfies the GSD `prohibition-enforcement` producer's one-subject-per-guard model | SURF-04 | Medium — inferred from `_lib.mjs:11-17`'s "exactly one substitutable subject"; **not verified against the producer itself** |
| A4 | `SIGRA_CONTRACT_SUBJECT` is a free env-var name | Target 3 | Low — grep found no `System.get_env("SIGRA_` in `test/sigra/planning/` |
| A5 | Updating `test/fixtures/prohibitions/p10-manifest-stale-entry.tsv`'s header does not red `p10` | Target 6 | Low — `parseSkipManifest` skips `#` lines and no test asserts header text; verify by running `p10` after the edit |
| A6 | R2's definition is "V3 over `^\s*#` lines in tracked `lib/*.{ex,exs}`" | Target 4 | Low — it reproduces **220** exactly and no other candidate definition did (205, 223, 1669 were the alternatives) |

---

## Open questions for the planner

1. **Does `p21` implement all four D-13 legs, or only the MAINTAINING.md leg?** Legs 1–3 already exist in `p10` including both edge cases. Recommended: leg 4 only, with a header comment delegating and naming `p10`. Either way the decision should be written down, because an independent reimplementation *will* red on `example_playwright_shard`'s templated name unless it copies `p10:103-105`.

2. **Does `p18` adopt the two V3 widenings the folded todo recommends** (case-folding the plan-reference alternations; block/comment-aware rather than line-based matching)? Both are widenings and both will move R2's baseline above 220, so they must be measured *before* the baseline is committed. No D-NN decides this. Not adopting them is defensible (V3 is the definition the todo names as inherited, verbatim) — but then `golden-path.spec.ts:59`'s lowercase `post plan 04` stays permanently invisible, which is the failure class the todo exists to flag.

3. **Which definition does each ratchet counter use, stated in writing?** See `## Conflicts` C-2. R1 = 237 token set, R2 = V3, R3 = literal `.planning/`. Coherent, but a reader will assume "V3 throughout" unless the plan says otherwise.

4. **Where does the baseline live and what shape is it?** A committed TSV/JSON beside the guard, or numeric constants inside the `.mjs`? Constants are simpler and diff-visible; a data file is easier to regenerate. Discretion, but it needs deciding before Task 1 of SURF-04.

5. **Is the DX-02 Dependabot half of the composite-action todo in scope?** `2026-09-15-composite-action-outside-supply-chain-guards.md` names two gaps: the pin guard (DEBT-04, in scope) **and** a missing `github-actions` Dependabot entry for `/.github/actions/example-playwright-boot`. `phase_234_dependabot_contract_test.exs:15-16` locks the config to exactly three entries, so adding coverage requires editing that test. Not named by any D-NN. Probably out of scope; say so explicitly so the todo is not silently half-closed.

6. **`ci.yml`'s own action pins remain unguarded.** The same todo notes *"every pin in `ci.yml` is unguarded."* DEBT-04 and SC-4 name only the composite action, so this is out of scope — but the plan should record that DEBT-04 closing does not mean the repo's action-pinning surface is fully covered, or the next audit will re-find it.

7. **Manifest row `:76` (`example_playwright_smoke`, `gate_level=step`) is inaccurate at HEAD** and neither `p10` nor a D-13-compliant `p21` will catch it. File a todo, or fix the row in passing? Fixing it is a one-cell TSV edit; leaving it unrecorded is the rot pattern this phase retires.

8. **Does the `p10` fixture header get updated alongside the live manifest (D-12)?** `test/fixtures/prohibitions/p10-manifest-stale-entry.tsv` carries the same two stale `honest-skip-parity.test.mjs` citations. Cosmetic, cheap, and leaving it means a second copy of the false claim survives the phase.

---

## Sources

### Primary (HIGH confidence — read at HEAD `ab99f0e5` this session)

- `.planning/decisions/{001,002,003}-*` — ADR convention, numbering, amendment style
- `.planning/research/PITFALLS.md:295-311` — Pitfall 9 in full; `:303` prescribes ADR 004; `:304` prescribes the cross-ref sweep; `:305` the write-the-guard rule
- `.planning/ROADMAP.md` `### Phase 241` — the five SCs (note SC-3 and SC-5 both carry the stale citations D-15/D-27 correct)
- `.planning/REQUIREMENTS.md` — SURF-04, DEBT-01..04
- `mix.exs:55,149-157,184` — `elixirc_paths`, the `ci` alias, the Hex `files:` list
- `.formatter.exs` — fixture inputs
- `.github/workflows/ci.yml:160,408,1189-1190,1301,1317-1319,1388-1415` — `fast_checks`, the prohibitions glob, the shard job, the gallery steps, the aggregator
- `.github/ci-skip-manifest.tsv` (all 76 lines) and `.github/actions/example-playwright-boot/action.yml:49,55,63,111`
- `.github/workflows/{release-please,hex-publish}.yml` — the 7-then-16-entry pin inventory
- `MAINTAINING.md:172-178,232-297,318-330` — the honest-skip section and the rot
- `scripts/ci/prohibitions/_lib.mjs`, `p03`, `p10`, `p20` — the guard idiom, parsers, and the parity implementation that already exists
- `scripts/ci/quality-findings-monotonic.sh:1-42` — the in-repo ratchet + floor-rebase prior art
- `scripts/ci/capture-fast-01-gap-closure.sh:29-42` — the second reader of the remediation JSON and its cutoff-blob verification
- `test/sigra/planning/phase_233_library_economics_contract_test.exs` (full), `phase_234_action_pinning_contract_test.exs` (full), `phase_236_retry_wrapper_prohibition_test.exs` (full), `phase_234_evidence_contract_test.exs:1-40`, `phase_235_fast_01_gap_closure_contract_test.exs:1-50`
- `.planning/phases/237-…/237-RATCHET-BASELINE.md` and `237-docs-attribute-scan.py`
- `.planning/phases/239-…/239-v3-vocabulary-check.sh` and `239-v3-allowlist.tsv`
- `.planning/todos/pending/` — the V3 todo, the packaged-docs todo, the honest-skip todo, the composite-action todo, the `p19` short-circuit todo

### Commands executed (all via `bash -c`)

- `python3 …/237-docs-attribute-scan.py lib` → 337/254/69
- V3 over `^\s*#` in `git ls-files lib/*.ex lib/*.exs` → 220
- `grep -o '\.planning/'` over `git ls-files docs README.md CHANGELOG.md` → 58 / 32 lines / 6 files
- `bash …/239-v3-vocabulary-check.sh {priv-templates,example,golden}` → exit 0, 0, 0
- `/tmp/relax_probe.exs` — both pin regexes line-by-line over the widened universe → 7 newly matched, 0 would-fail
- per-row manifest parity loops against `ci.yml` and `MAINTAINING.md`
- `git grep` for the formatter across all local + remote refs → 10 affected refs

### Tertiary

None. No web search was performed; every question was in-repo and answerable by reading committed files.

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|---|---|---|
| ADR home & numbering (T1) | HIGH | directory listing + `PROJECT.md:196` cross-reference + `PITFALLS.md:303` prescribing "004" |
| JSON reader sweep (T2) | HIGH | exhaustive grep; both readers opened and the cutoff-SHA mechanism read line by line |
| ExUnit fail-first mechanism (T3) | HIGH for constraints, MEDIUM for the exact replacement assertion (discretion) |
| Ratchet baselines & commands (T4) | HIGH | all three reproduce byte-exact; the committed spec script was executed |
| Regex relaxation blast radius (T5) | HIGH | both regexes run programmatically with the test's own validity predicates over every file in the widened universe |
| Parity state (T6) | HIGH | computed row by row; every rot re-located by content and the cited numbers read back |
| `p18` fixture/producer interaction (A3) | MEDIUM | inferred from `_lib.mjs`, not verified against GSD's producer |

**Research date:** 2026-09-18
**Measured against:** HEAD `ab99f0e5` (clean tree, branch `main`)
**Valid until:** any commit that touches `.github/workflows/ci.yml`, `.github/ci-skip-manifest.tsv`, `MAINTAINING.md`, `lib/`, `docs/`, `README.md`, or `CHANGELOG.md` — the three ratchet baselines and the parity table are HEAD-pinned measurements and must be re-run if the base moves before planning.
