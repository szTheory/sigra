# Phase 241: Retire v1.47's Dishonest Debt + Adopter-Leakage Guard - Context

**Gathered:** 2026-09-18 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Every guard in the repo that currently asserts nothing either asserts something real or is
gone — and new adopter-visible leakage cannot land.

In scope (DEBT-01, DEBT-02, DEBT-03, DEBT-04, SURF-04):
- SC-1: ADR records the TEST-01/02 supersession; `ExUnitTimingFormatter` + its test deleted;
  `mix ci` green; the `mix ci` alias topology **unchanged**.
- SC-2: the `phase_233_library_economics_contract_test.exs` replacement is demonstrated **RED
  against a committed known-bad fixture** before acceptance.
- SC-3: `honest-skip-parity.test.mjs` written and observed **failing against HEAD's
  `MAINTAINING.md`** before the doc is corrected.
- SC-4: `example-playwright-boot/action.yml` visible to the pinning guard **in both directions**.
- SC-5: `p18-*.test.mjs` hard-fails a three-violation fixture; the remaining-bookkeeping counts are
  committed baselines under a **monotonic-decrease ratchet**; picked up with **zero workflow edits**.

Out of scope (named, deliberately not fixed here):
- Any `mix ci` topology change, including adding Credo. `phase_233_*_contract_test.exs` guards the
  alias; editing it reopens the exact v1.47 wound this milestone closes.
- Adding `example_unit_smoke` to `ci-gate.needs` (FUT-03 — a `ci.yml` topology change; see D-17).
- Driving the bookkeeping counts to zero. Zero is explicitly **not** the v1.48 target.
- `p19`'s own defects (two pending todos) and the `ci-observe.yml` tag-ruleset drift observer.
- The tarball/generated-app half of the distribution-boundary leak guard (see D-24).
</domain>

<decisions>
## Implementation Decisions

### A. DEBT-01 — deleting the orphaned formatter (SC-1)

- **D-01:** The deletion is exactly two files — `test/support/ci/ex_unit_timing_formatter.ex` and
  `test/support/ci/ex_unit_timing_formatter_test.exs` — and **nothing else**. Verified at HEAD: a
  repo-wide grep for `ExUnitTimingFormatter` outside `.planning/` returns only those two files plus
  stale `_build/` artifacts and `.gsd/scratch/` logs, neither of which is source. `SIGRA_EXUNIT_TIMING_PATH`
  occurs only inside the formatter itself.
- **D-02:** The `mix ci` alias is **never edited**. Verified: the alias at `mix.exs:149-157` is a
  seven-element list that never names a `--formatter`, so there is nothing in it to change.
  `phase_233_library_economics_contract_test.exs` asserts that exact list via `ci_legs/1`; it is
  **re-run as evidence**, not modified. `mix.exs:55` (`elixirc_paths(:test)` includes `test/support`)
  is why the module compiles at all and is unaffected by removing one file from that tree.
- **D-03:** The ADR must name the **parked `235.1` branch** as an affected consumer. The v1.47
  re-wiring commits live there; a later cherry-pick would compile against a deleted module and red
  `compile --warnings-as-errors` for a reason unrelated to its own diff.
- **D-04:** The ADR's home and numbering is **resolved by the planner before Task 1**, not assumed.
  No `docs/adr/` or `.planning/adr/` directory was located during analysis, yet `MEMORY.md` cites an
  "ADR 003" for the Hex-retire footgun. Find the existing convention and follow it; do not invent a
  second one.
- **D-05:** SC-1 requires a green `mix ci`, but this repo currently has **6 environmental
  `Sigra.Audit.Forwarders.ThreadlineTest` failures** (`Threadline.attach/1 undefined`) that are
  unrelated to this phase and confirmed green in CI at the same commit. The green claim is made
  against **CI**, not a local run, and the plan states this in writing rather than excluding the
  tests from the suite.

### B. DEBT-02 — a replacement that asserts a guarantee, not a screenshot (SC-2)

- **D-06:** Only the **first three** tests in `phase_233_library_economics_contract_test.exs` are the
  dishonest surface. They restate HEAD's `ci.yml` shape (`assert library_job_ids(workflow) == @library_jobs`,
  `assert aggregate =~ "needs: [library_tests_shard]"`). The replacement asserts the **invariant the
  ADR names** — exactly one owner of the full library suite — as a derived property: the count of
  `MIX_ENV=test mix ci` invocations across all `library_tests*` job bodies is 1, and no such job
  invokes bare `mix test`.
- **D-07:** The missing half is a **substitutable subject**. `@workflow_path` is hardcoded to
  `".github/workflows/ci.yml"`, so today there is no way to point the test at a known-bad file — which
  is precisely why it has never been observed RED. The replacement gains an env-overridable subject
  path, mirroring `scripts/ci/prohibitions/_lib.mjs`'s `subjectPath()` / `GSD_PROHIB_SUBJECT`.
- **D-08:** The replacement **stays in ExUnit**, inside `mix ci`'s existing `test --exclude scaffold`
  leg. Porting it to a `pNN-*.test.mjs` prohibition would buy the GSD fail-first producer for free but
  would move the alias guard **out of `mix ci`**, weakening the local gate and brushing the
  no-topology-change fence. The RED is mechanized instead by a scripted `bash -c` run recorded in
  EVIDENCE.
- **D-09 (operator decision, 2026-09-18):** The `235-FAST-01-REMEDIATION.json` dependency is
  **retired**. The two receipt tests are deleted and the ADR records that git history plus the
  `239`-style evidence files are the tamper record. Rationale: the receipt asserts a sha256 **of
  `phase_233_library_economics_contract_test.exs` itself** — the very file SC-2 rewrites — and nothing
  recomputes it, so after the rewrite the receipt is silently false while its test stays green. That is
  the exact defect class SC-2 exists to remove. Loss is bounded: the JSON is committed and the repo is
  public, so tampering remains visible in `git log`.
- **D-10:** Before deleting, the planner **sweeps `scripts/` for any other reader** of
  `235-FAST-01-REMEDIATION.json`. Analysis covered the test and the `Sigra.Test.PlanningPaths.phase_file/2`
  indirection but did not sweep scripts. If a reader exists, this becomes a two-file change.

### C. DEBT-03 — the honest-skip parity guard (SC-3)

- **D-11 (operator decision, 2026-09-18):** **Write the guard**; do not delete the claim. The rot is
  real and measurable at HEAD, so the RED is free rather than contrived.
- **D-12:** The guard is named `p21-honest-skip-parity.test.mjs` so the `ci.yml` prohibitions glob
  picks it up with zero workflow edits. `.github/ci-skip-manifest.tsv`'s header cites the
  **unprefixed** path twice, so the header is updated to the chosen name either way.
- **D-13 (scope fence, load-bearing):** The guard asserts **only** structural parity: every manifest
  `id` resolves to a `^  <id>:` in `ci.yml`; every `kind=step` row's `parent_job_id` also appears as a
  `kind=job` row; every `display_name` appears adjacent to its id; and every row's id+parent appears in
  `MAINTAINING.md`'s honest-skip section. It **must not** parse the `gate` column's `${{ }}` expressions
  semantically — that is where a parity guard becomes a YAML-expression evaluator and rots into a
  second screenshot that reds on every unrelated `ci.yml` edit.
- **D-14:** The guard **must not assert `ci-gate.needs` membership**. `example_unit_smoke` is a
  manifest row whose lane `ci-gate` does not depend on (FUT-03, knowingly deferred). Asserting
  membership reds the new guard on a known-deferred gap on day one.
- **D-15 (stale citation — re-locate by content):** DEBT-03 cites `MAINTAINING.md:172-178,231`.
  Verified at HEAD: those lines are the `p19` bypass-actor operator note and the nightly cron list —
  unrelated prose. The real rot is around **`MAINTAINING.md:263-269, 280, 322`**: it places
  `design_gallery_snapshots` "inside `example_playwright_smoke`" when `ci.yml` has it inside
  `example_playwright_shard`, and it cites an `Aggregate Playwright step outcomes` step with **zero**
  grep hits in `ci.yml`. The plan re-locates by content; it does not trust the cited line numbers.
- **D-16:** The RED is observed on the **manifest ↔ MAINTAINING.md leg against HEAD's committed
  `MAINTAINING.md`**, before any doc edit. Write the guard, watch it fail, then correct the doc — in
  that order. A guard authored after the doc is fixed has never been seen failing.
- **D-17:** The guard is offline-only — no `gh`, no token, no network — matching the standing
  constraint the whole `p*` family respects.

### D. DEBT-04 — making the composite action visible in both directions (SC-4)

- **D-18 (the requirement's diagnosis is wrong):** DEBT-04 blames `action_entry/4` returning `[]` for
  local `"./"` actions. Verified: that head is **correct and deliberately blessed** by the test at
  `phase_234_action_pinning_contract_test.exs:71-77` — a `uses: ./.github/actions/foo` reference has no
  third-party ref to pin. The real gap is the two-entry `@release_workflows` universe
  (`:4-7` = `release-please.yml`, `hex-publish.yml`), so `action.yml` is **never opened**. The fix adds a
  second scanned universe for composite-action files and leaves the `"./"` head and its blessing test
  untouched.
- **D-19 (second blind spot, unrecorded anywhere — SC-4 is vacuously satisfiable without this):**
  The inventory regex is `~r/^\s*-\s+uses:\s+.../` and **requires a leading dash**. Verified at HEAD,
  `action.yml`'s four `uses:` are at lines 49 and 55 (`- uses:`) and lines **63 and 111 (bare `uses:`)**.
  SC-4 says to prove the guard by "unpinning **one of its four**" — pick line 63 or 111 and the guard
  stays green even after the universe is widened, and DEBT-04 ships "closed" with half the composite
  action's supply-chain surface invisible. The regex is relaxed to `^\s*(?:-\s+)?uses:` and **the
  relaxation itself is proven by a fixture**.
- **D-20:** The two-directional proof uses a **committed known-bad fixture plus subject indirection**,
  never a mutation of the live `action.yml`. A fixture copy with one ref replaced by a floating tag
  gives RED; HEAD's real `action.yml` gives GREEN; both runs are scripted, recorded in EVIDENCE with
  their `bash -c` invocations, and the working tree is never left holding an unpinned action.
- **D-21 (rejected alternative, recorded):** A transient `git stash`-and-run mutation of the real
  `action.yml`, recorded as a transcript. Cheaper to write, but leaves no committed artifact, so nothing
  re-proves the direction at the next HEAD — the same rot class this phase retires.

### E. SURF-04 — the ratchet is three counters, not one (SC-5)

- **D-22 (the ratchet-defeat this prevents):** `p18` carries **three separate monotonic counters**,
  each with its own committed baseline and its own reproducible command. A single fused total lets a
  decrease in one surface pay for an increase in another — and concretely, Phase 242's `CHANGELOG.md`
  fold (REL-05) would mechanically drop R3 by ~40 and thereby license 40 new `lib/` bookkeeping
  comments under a green ratchet. Baselines measured at HEAD during analysis, **not quoted from the
  requirement**: **R1** = 337 HexDocs-rendering doc-range token occurrences in `lib/` (254 sites,
  69 files, byte-identical to `237-RATCHET-BASELINE.md`); **R2** = 220 inline `lib/` comment lines;
  **R3** = 58 `.planning/` occurrences across the packaged-docs surface (32 lines, 6 files —
  independently reproduced by the orchestrator).
- **D-23:** R3 is **`.planning/`-only and must not use the V3 bookkeeping vocabulary**. Running V3
  over `docs/ README.md CHANGELOG.md` yields 299 matching lines at HEAD, overwhelmingly `CHANGELOG.md`
  legitimately citing phase numbers — exactly the prose the Out-of-Scope table protects as
  "the traceability needed to judge which `Phase NN` comments are real rationale". A V3-based R3 would
  be a 299-line ratchet nobody can move, on a file Phase 242 owns.
- **D-24:** `guides/` is **out of scope for the ratchet**. Verified: `mix.exs`'s Hex `files:` list
  omits `guides`, so guides never ship in the tarball; they reach HexDocs only via `extras:` at
  docs-build time. The 9 `guides/` files containing `.planning/` are mostly live absolute GitHub blob
  URLs that resolve — a fourth counter over them buys a number that cannot honestly decrease. This
  answers and closes the `2026-09-16-phase-241-ratchet-baseline-scans-lib-only` todo **as a decision**.
- **D-25:** `p18`'s three hard-fail classes are proven by a fixture design where each violation is
  **independently reachable** — not one fixture whose checker returns on the first hit. The
  `2026-09-17-p19-known-bad-fixture-short-circuits` todo records exactly that failure: "the RED proof is
  genuine — the fixture does go red — but it proves one assertion, not the two it declares."
- **D-26:** The `priv/templates/` clean-side assertion needs a **real positive control**. Only 1
  V3-matching line exists there at HEAD, so a zero is otherwise indistinguishable from an empty file
  list. `p03-no-green-on-empty-grep` is the in-repo precedent.
- **D-27 (stale citation — re-locate by content):** SC-5 cites `ci.yml:393` for the prohibitions glob.
  At HEAD the `run:` line is **`ci.yml:408`**. Naming the guard `p18-*.test.mjs` under
  `scripts/ci/prohibitions/` is what earns zero-workflow-edit pickup; the `mix ci` alias has no node
  leg, so a `.mjs` guard cannot enter `mix ci` by construction.

### Claude's Discretion

- Plan/wave decomposition and how many plans the five SCs split into.
- Exact guard file internals, fixture contents, and helper factoring, within D-13/D-19/D-25.
- ADR prose and section ordering, once D-04 settles its home.
- Whether R1/R2/R3 live in one `p18` file with three assertions or three sibling files.

### Folded Todos

- `2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md` — becomes ratchet
  R3. Its 58/32/6 numbers reproduce exactly at HEAD.
- `2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md` — it *is* `p18`'s spec (V3 regex,
  per-alternation positive controls, the line-vs-block matching gap).
- `2026-09-16-phase-241-ratchet-baseline-scans-lib-only-but-guides-render-on-hexdocs-too.md` — folded
  **as a decision** (D-24), closed by that answer rather than by work.
- `2026-09-17-bookkeeping-leak-guard-on-distribution-boundary.md` — folded **partially**: `p18` is the
  source-side mechanism it asks for. Its tarball/generated-app half stays pending (D-24 fence).
</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` → `### Phase 241` — the five success criteria.
- `.planning/REQUIREMENTS.md:87` (SURF-04), `:105-108` (DEBT-01..04), and the **Out of Scope** table.
- `scripts/ci/prohibitions/_lib.mjs` — `subjectPath()` / `GSD_PROHIB_SUBJECT`; the fail-first contract.
- `test/fixtures/prohibitions/` — 16 existing known-bad fixtures; the pattern to copy.
- `.planning/phases/237-*/237-RATCHET-BASELINE.md` — R1's 337/254/69, unchanged at HEAD.
- `.planning/research/PITFALLS.md:304-305` — "write the guard, don't delete the claim"; ADR must name
  affected branches.
</canonical_refs>

<code_context>
## Existing Code Insights

### Verified Live During Analysis (2026-09-18, HEAD `1c317d95`)

- `ExUnitTimingFormatter` has **no source consumer** outside its own two files.
- `mix.exs:149-157`'s `ci` alias is a seven-element list naming no formatter.
- `action.yml`'s four `uses:` split 2 dashed / 2 bare (lines 49, 55 vs 63, 111).
- `phase_234_action_pinning_contract_test.exs:108`'s regex requires the leading dash.
- `@release_workflows` is two entries and does not include composite actions.
- `MAINTAINING.md:172-178` is `p19` prose, not shard topology.
- The prohibitions glob `run:` is at `ci.yml:408`.
- R3 = 58 `.planning/` occurrences in `docs/ CHANGELOG.md README.md`.

### Established Patterns

- Guards drop into `scripts/ci/prohibitions/*.test.mjs` and are picked up by the glob with zero
  workflow edits. Offline only.
- A guard is accepted only when observed RED against a committed known-bad fixture, then GREEN against
  the real subject. Phase 216 SC-5 and Phase 240 plan-review B-1 are the two times this repo was burned
  by skipping it.
</code_context>

<specifics>
## Specific Ideas

- Three of this phase's own inputs carry stale line citations (D-15, D-19, D-27). The planner
  re-locates every cited coordinate by content before writing a task against it. The
  `2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist` todo is the precedent for a
  criterion that names a literal occurring zero times in the repo.
</specifics>

<deferred>
## Deferred Ideas

- The tarball/generated-app half of the distribution-boundary leak guard (greping `mix hex.build`
  output in CI) — a `ci.yml` edit, which SC-5's zero-workflow-edits fence forbids.
- A fourth ratchet counter over `guides/` as a non-increase tripwire (D-24 declines it).
- FUT-03 (`example_unit_smoke` → `ci-gate.needs`) stays deferred; D-14 keeps the new guard from
  tripping on it.

### Reviewed Todos (not folded)

- `2026-09-17-p19-bypass-actors-literal-is-constructed-at-runtime...` — same defect class, different
  subject (`p19`/tag rulesets). Fix only if a plan is already editing `p19`.
- `2026-09-17-p19-known-bad-fixture-short-circuits...` — **cite, don't fix**. It shapes `p18`'s fixture
  design (D-25); repairing `p19`'s own fixture is out of scope.
- `2026-09-17-tag-ruleset-drift-observer-has-never-run...` — unrelated `ci-observe.yml` lane, and its
  "never run" premise is self-superseded (run `35249205910` observed green).
- `2026-09-16-phase-239-sc5-names-a-comment-marker-that-does-not-exist.md` — closed history; used as a
  checklist lesson only (see `<specifics>`).
</deferred>
