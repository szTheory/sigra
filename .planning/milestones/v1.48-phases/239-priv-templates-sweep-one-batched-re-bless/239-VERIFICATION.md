---
phase: 239-priv-templates-sweep-one-batched-re-bless
verified: 2026-09-18T19:05:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  previous_head: d65e6eb8 (pre-closure; 38 commits behind this HEAD)
  gaps_closed:
    - "SC-1 — the two plan-vocabulary sentences (`The plan-checker greps this function body and asserts zero matches.`, `Flop / sortable columns are a v1.2 concern.`) no longer exist in priv/templates, the golden tree, the mirror, or generated output; re-derived here by fixed-string grep with a live control"
    - "SC-2 — re-scoped by D-27 to lib/+priv/ inside the tarball and independently re-measured at 0 with a live control; the excluded 58/32/6 packaged-docs surface is disclosed and double-owned"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "SC-3's final clause — the `install_golden_contract` GitHub Actions job observed green"
    addressed_in: "Ship time (nothing is pushed; 93 commits unpushed on main), corroborated by Phase 240 (green-main evidence backed by run ids)"
    evidence: "239-EVIDENCE.md § HONEST-CLAIMS (239-13 extension) item 1 — the plan pushed nothing and claimed no Actions verdict. Local substitutes re-run independently by this verification: `mix sigra.fixture.rebless_golden --check` exit 0 and `MIX_ENV=test mix ci.install_golden` 19 tests / 0 failures."
  - truth: "The tarball's `lib/` still carries inline planning-bookkeeping comments (measured here: 439 lines matching a V2-subset pattern under the extracted tarball's lib/)"
    addressed_in: "Phase 241 (SURF-04)"
    evidence: "REQUIREMENTS.md SURF-04: 'a monotonic-decrease ratchet on remaining inline lib/ comments. Zero is explicitly not the v1.48 target.' Also 239-EVIDENCE.md § HONEST-CLAIMS item 2."
  - truth: "The packaged docs surface (`docs/`, `README.md`, `CHANGELOG.md`) ships 58 `.planning/` occurrences across 32 lines in 6 files inside the Hex tarball"
    addressed_in: "Phase 241 (SURF-04)"
    evidence: "D-27; SURF-04's requirement text names the packaged-docs surface; `.planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md`. Re-measured independently here: 58 occurrences / 32 lines / 6 files, in both the source tree and the extracted tarball."
  - truth: "The `test/example/` remainder outside SC-4's counterpart scope (482 V3-matching lines across 157 files), including review finding IN-06"
    addressed_in: "Phase 241 (SURF-04)"
    evidence: "D-30; `.planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md`. Not adopter-shipped (test/ is not in mix.exs's Hex `files:` list)."
  - truth: "FUT-01 — the template↔example parity guard is filed and unbuilt"
    addressed_in: "Backlog todo (Phase 241 SURF-04 adjacent)"
    evidence: "`.planning/todos/pending/2026-09-17-fut-01-template-example-parity-guard.md` exists; SC-4 explicitly requires it be filed rather than built."
  - truth: "`237-security-comment-diff-check.sh`'s bookkeeping token set omits `IN-NN`-class tokens, so one removed line in the round-1 sweep diff survives the classifier"
    addressed_in: "Phase 241 (`p18` spec input)"
    evidence: "`.planning/todos/pending/2026-09-17-security-comment-classifier-token-set-omits-half-the-union.md`. Re-derived here at the `origin/main..HEAD` width (see SC-5 row) and confirmed to be a token-set gap, not a rationale deletion — the sentence survives verbatim at `priv/templates/sigra.install/core/auth.ex:530`."
---

# Phase 239: `priv/templates/` Sweep + One Batched Re-bless — Verification Report

**Phase Goal:** Nothing an adopter generates or downloads contains Sigra's internal planning bookkeeping.
**Verified:** 2026-09-18
**Status:** passed
**Re-verification:** Yes — this REPLACES the pre-closure `gaps_found` report written at `d65e6eb8`, 38 commits behind this HEAD (`5e69c66d`).
**Verification stance:** every number below was re-derived from the bytes in this verifier's own process, using `/usr/bin/grep` explicitly, `git ls-files -z | xargs -0` where a file list was needed, and a live positive control paired with every zero. No figure is carried over from a SUMMARY or from `239-EVIDENCE.md`; where a SUMMARY figure and mine agree, that agreement is reported as corroboration, not as the source.

## Goal Achievement

### Observable Truths (the ROADMAP Success Criteria, as amended by D-26 … D-33)

| # | Truth | Status | Evidence (re-derived at HEAD `5e69c66d`) |
|---|---|---|---|
| SC-1 | A freshly generated app greps clean for `.planning/` paths and planning bookkeeping (V3 measured form, D-28/D-30) | ✓ VERIFIED | `mix sigra.fixture.rebless_golden --check` → **exit 0** run by this verifier: the committed golden tree is byte-equal to a freshly scaffolded `phx.new` + `sigra.install` app, which is what makes the golden tier admissible as *generated* bytes rather than a committed snapshot. V3 `golden` tier: `hits=0 / allowlisted=0 / hits_outside_allowlist=0 / control_defmodule=78 / files_measured=84`, exit 0. Fixed-string (`grep -rnF`, no regex) over `priv/templates` + the golden tree: `.planning/` → **0**, `The plan-checker greps this function body and asserts zero matches.` → **0**, `Flop / sortable columns are a v1.2 concern.` → **0**, `generates no tests` → **0**; live control `defmodule` on the same surface → **176**. The `organizations.ex:59` dead `.planning/` path named in SC-1 is gone (region read directly). |
| SC-2 | The `mix hex.build` tarball, extracted, greps clean for `.planning/` paths **under `lib/` and `priv/`** (D-27) | ✓ VERIFIED | `mix hex.build` run by this verifier; `contents.tar.gz` extracted. `grep -rnF -- '.planning/' lib priv` → **0**; live control `grep -rn 'defmodule' lib priv` → **286**. The D-27-excluded surface re-measured in the same extracted tarball: `docs/` + `README.md` + `CHANGELOG.md` → **32 matching lines in 6 files, 58 occurrences** — exactly the disclosed figure. |
| SC-3 | One batched re-bless **per batch** (D-26/D-29); each alone in its commit, comment-only diff, `--check` exit 0, local gate green | ✓ VERIFIED (one clause deferred — see below) | All four re-bless commits inspected line by line with `git show -U0`: `38c9bd9a` (35 files), `265f7195` (7), `87581665` (2), `5f7ae9d7` (1). **Files outside `test/fixtures/install_golden/` in each: 0, 0, 0, 0.** Every added/removed line is `#` comment, `@moduledoc`/`@doc` prose, HEEx `<% # %>` comment, JS `//` comment, or CSS `/* */` comment — **no executable line in any of the four**, read directly rather than trusted to the classifier. `--check` → exit 0 (re-run here). `MIX_ENV=test mix ci.install_golden` → **19 tests, 0 failures, exit 0** (re-run here, 291s). Each batch carries a by-name justification in § `BATCH-JUSTIFICATION` written before its re-bless. |
| SC-4 | Only the `test/example/` counterparts of edited templates are mirrored, recorded as a per-file checklist; FUT-01 filed | ✓ VERIFIED | `git diff --name-only origin/main HEAD -- test/example` → **32 files**; `239-MIRROR-CHECKLIST.md` enumerates **36** paths (all exist on disk). `comm -23 changed checklist` → **empty**: every mirrored file is on the checklist, none is off-checklist. Convergence spot-checked across all three surfaces at the same line: template / example / golden `invitation_accept_live.ex:21` all carry `your generated project does not inherit that assertion`. FUT-01 todo present. |
| SC-5 | Load-bearing infrastructure provably untouched: no `.github/` `name:` change; no `# SECURITY:`-class rationale sentence deleted | ✓ VERIFIED | `git diff origin/main -- .github/` → **0 changed lines**; `… \| grep '^[+-].*name:'` → **0**. Both zeroes carry a live control: the same base with no pathspec is **190 files changed / 21,574 insertions**, so the pathspec matched nothing changed rather than the diff being empty. `237-security-comment-diff-check.sh` re-run by this verifier at the **criterion's own `origin/main` width** over `lib priv test/example test/fixtures` (3,688-line diff): one survivor, `# token clause so security signals are preserved (10.1 IN-03). Tokens`. Investigated rather than accepted: the rationale sentence **survives verbatim** at `priv/templates/sigra.install/core/auth.ex:530` (`# token clause so security signals are preserved. Tokens`, 3 occurrences across template/example/golden); only the `10.1 IN-03` bookkeeping token was removed. This is the pre-existing, already-filed classifier token-set gap, not a rationale deletion. |

**Score:** 5/5 truths verified (0 present, behavior-unverified).

### The goal sentence vs. what the criteria establish — the one thing a reader must not over-read

The ROADMAP goal is *"Nothing an adopter generates or downloads contains Sigra's internal planning bookkeeping."* The **generates** half is achieved and I re-derived it from generated bytes. The **downloads** half is achieved *for `.planning/` paths under `lib/` and `priv/`* and is **not** achieved for bookkeeping generally: the extracted tarball's `lib/` still carries **439** lines matching a V2-subset bookkeeping pattern, and the packaged docs carry **58** `.planning/` occurrences. Both are measurements I made myself in the extracted tarball.

This is a gap in the **goal sentence**, not in the phase's contract: SC-2 as amended by D-27 asserts only `.planning/` paths, SURF-04's requirement text says in as many words that *"Zero is explicitly not the v1.48 target"* for the inline `lib/` ratchet, and both residues are named in `239-EVIDENCE.md § HONEST-CLAIMS` with owners. Recorded under `deferred:` above rather than as a gap, and flagged here so no downstream reader mistakes a 5/5 for a literal reading of the goal sentence.

### Adversarial checks specifically requested

**1. Were the three post-hoc amendments (D-27, D-31, D-33) goalpost moves?** All three narrow what is *claimed* while disclosing what is *not cleaned*. Each verified independently:

- **D-27** — legitimate. The excluded surface is measured exactly as disclosed (58/32/6, re-derived twice: source tree and extracted tarball) and it keeps **two** owners that both exist: SURF-04's requirement text (read at `.planning/REQUIREMENTS.md:87`) and a pending todo file that is on disk. The narrowing routes, it does not delete.
- **D-31** — legitimate, and it *raised* the bar. Its factual basis re-derived: `lib/sigra/install/features/admin.ex:38-39` does create `test/<otp_app>/sigra_admin_policy_test.exs` (`grep -rn 'test\.exs' lib/sigra/install/features/` → 3 hits, non-empty, so the enumeration is not a dead grep). The retracted sentence was genuinely false and is gone from every surface (`generates no tests` → 0 over templates + golden). The `T-239-12-03` re-base from `== 0` to `>= 1` is a *harder* observation, not a softer one.
- **D-33** — legitimate; its defense is provenance and I checked the commit graph directly: `git merge-base --is-ancestor 1a85508e 23f3c711` → exit 0 and `… 23f3c711 HEAD` → exit 0. The bound is real: `git ls-files -z | xargs -0 grep -lF -- '<literal>'` returns exactly **one** tracked source file (`priv/templates/sigra.gen.oauth/oauth_html.ex`) plus the two phase documents — against a live control of **513** files carrying `defmodule Sigra` on the same command shape. The literal sits at line 54 of the template and the halting probe reported the rendered hit at line 54. `(basename, literal)` is looser than `(path, literal)` by exactly one hypothetical third file; the disposition itself is unchanged. This changes *how an existing FALSE-POSITIVE is matched across a rendering boundary*, never *what counts as bookkeeping*.

**2. Any instrument that could not fail?** I fired the V3 instrument's failure paths myself rather than reading the ledger's claim that they fire:

| Probe | Expected | Observed |
|---|---|---|
| `--files lib/sigra/audit.ex` (known-dirty) | dirty | `hits=16 / hits_outside_allowlist=16`, **exit 1** |
| `--files` (no paths) | fail-closed | `FAIL: empty file list — refusing to report success`, **exit 3** |
| `--files README.md` (no `defmodule`) | fail-closed on dead control | `control_defmodule=0` guard, **exit 3** |
| `bogus-tier` | usage error | **exit 2** |

Exit 1 (dirty) and exit 3 (cannot answer) are genuinely distinct. Every green tier run I made printed a **non-zero** `control_defmodule` on its own surface (98 / 2 / 78), so no zero above came from a dead grep — including the `ugrep`-wrapper hazard, which cannot have silenced the pattern grep in a process whose control grep returned 98.

I also tested the one place the instrument's own scoping looked thin: the `example` tier measures **only 2 files**. I therefore re-ran V3 in `--files` mode over the **full 36-file SC-4 mirror checklist** — `hits=0 / hits_outside_allowlist=0 / control_defmodule=36 / files_measured=36`, exit 0. The wider surface is clean too, so the narrow tier list understates rather than manufactures the result.

The one disclosed vacuity is real and correctly disclosed: for re-bless batch 4 both of the comment-only classifier's non-vacuity floors were off (`GOLDEN_MIN_FILES=1`, `expected_t_count=0`), stated in § `REFREEZE-LEDGER-4 (f)` *before* the green was reported. It does not affect this verdict, because I classified all four re-bless diffs by reading them, not by running that classifier.

**3. `mix ci` currency.** `git diff --name-only 3230d212 HEAD` → **5 files, all under `.planning/`**; excluding `.planning/`, **0**. The green `MIX_ENV=test mix ci` run recorded at `3230d212` therefore still describes this source tree. Confirmed by me, not taken from the SUMMARY.

**4. SURF-03's checkbox.** `git show --name-only 62a4e10c` → touches `.planning/REQUIREMENTS.md` and nothing else; committed last and alone, after the evidence commit. The claim it asserts holds at HEAD on my own measurements (SC-1/SC-3/SC-4 rows above).

### Requirements Coverage

| Requirement | Source plans | Description | Status | Evidence |
|---|---|---|---|---|
| SURF-01 | 239-02/04/05/06/08/09/10/11/12/13/14/15/16 | Zero `.planning/` path references in `lib/` or `priv/templates/`, verified on a freshly generated app and the `mix hex.build` tarball | ✓ SATISFIED | `grep -rnF -- '.planning/' lib priv` → 0 (control: 286 `defmodule` lines). Extracted tarball `lib/`+`priv/` → 0 (control: 286). Golden tree (byte-equal to a fresh install per my own `--check` exit 0) → 0. `[x]` in REQUIREMENTS.md, correctly. |
| SURF-03 | all 16 plans | `priv/templates/` carries no planning bookkeeping; one sweep + one batched re-bless per batch, in separate commits; only edited templates mirrored | ✓ SATISFIED | V3 `priv-templates`: `hits=1 / allowlisted=1 / outside=0 / control=98 / 119 files`, exit 0 — the single raw hit read by eye and confirmed an SVG `<path d=…>` coordinate pair in a Facebook logo, not bookkeeping. Four re-bless commits, each fixture-only and comment-only. Mirror ⊆ checklist. `[x]` in REQUIREMENTS.md; roll-up row `SURF-03 \| Phase 239 \| Complete`. |

**Orphan check:** `grep 'Phase 239' .planning/REQUIREMENTS.md` maps exactly SURF-01 and SURF-03 to this phase; both are claimed by plans. **No orphaned requirements.** SURF-04 is correctly `[ ]` / Phase 241 / Pending and is the named owner of three of this phase's deferrals.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `priv/templates/.../mfa_challenge_html.ex` and 4 mirrored counterparts | ~113 | `XXXX-XXXX` | ℹ️ Info | False positive — an HTML `placeholder=` attribute for a backup-code input, not a debt marker. |

`grep -nE 'TBD|FIXME|XXX'` across every source file this phase touched returns only the five `XXXX-XXXX` placeholder rows above. **No unreferenced debt marker was introduced.**

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Golden fixture equals a freshly generated install | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date (check mode.)`, exit 0 | ✓ PASS |
| Local install-golden gate | `MIX_ENV=test mix ci.install_golden` | 19 tests, 0 failures, exit 0 (291s) | ✓ PASS |
| Hex artifact is buildable and clean in its asserted scope | `mix hex.build` + extract + `grep -rnF '.planning/' lib priv` | 0, control 286 | ✓ PASS |
| V3 instrument, three tiers | `239-v3-vocabulary-check.sh {priv-templates,example,golden}` | outside=0 on all three, controls 98/2/78, all exit 0 | ✓ PASS |
| V3 instrument can still fail | 4 negative probes (above) | exits 1 / 3 / 3 / 2 | ✓ PASS |
| `install_golden_contract` GitHub Actions job | — | Nothing pushed (93 commits ahead of `origin/main`); no run exists to read | ? SKIP — deferred to ship time, declared |

### Human Verification Required

None. Every criterion resolved from bytes in this verifier's own process. The single unobservable clause (SC-3's Actions job) is recorded under `deferred:` with its owner, exactly as `239-EVIDENCE.md § HONEST-CLAIMS` declares it, and is unobservable for a structural reason — nothing is pushed — rather than an unmeasured one.

### Gaps Summary

No gaps. The pre-closure report's two gap entries (SC-1's plan-vocabulary sentences, SC-2's unqualified tarball claim) are both closed: the sentences are absent from templates, mirror, golden tree and generated output under a fixed-string grep with a live control, and SC-2's scope is now stated, measured at zero, and its excluded remainder disclosed with two owners.

The honest residue, stated once more so it is not lost in a 5/5: **the goal sentence is wider than the criteria that were met.** An adopter who downloads the tarball after this phase closes still receives 439 lines of inline `Phase N` / `D-NN`-class comments under `lib/` and 58 `.planning/` references in the packaged docs. Phase 239 measured both, claimed neither, and routed both to Phase 241 SURF-04 — which is the correct disposition, and is why the phase's closure is admissible rather than an over-claim.

---

_Verified: 2026-09-18_
_Verifier: Claude (gsd-verifier)_
