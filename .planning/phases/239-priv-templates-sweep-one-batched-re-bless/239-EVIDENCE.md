# Phase 239 Evidence Ledger

Slot-heading convention: `^## [A-Z0-9-]+$` heading, `Status:` line beneath (Phase 238 precedent).

## PREFLIGHT-UNION-LEDGER
Status: PASS — HEAD numbers match the 239-RESEARCH.md / 239-CONTEXT.md ledger exactly; the tree has
not moved since research was captured. This is the phase's first action, run before any template
edit.

- HEAD sha: `ebc5d9-e148cd-814fa1-b679a8-a74c0e-ab921e-c7b4` (hyphen-chunked for readability and to
  avoid a second hex-token match colliding with the WAVE0-COMMIT sha lookup below — concatenate the
  segments to recover the 40-char sha; it is also `git log -1` output at the time this ledger's
  first section was written, on branch `main`)
- `git status --porcelain` at measurement time:
  ```
   M .planning/STATE.md
   M .planning/state.json
  ```
  (only `.planning/` bookkeeping files modified — precondition for this task was verified met
  before any measurement was taken)

Union regex (one definition, per the plan's "The union regex" section):

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b
```

Exact commands run and their output:

```bash
U='\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b'
grep -nE "$U" $(git ls-files priv/templates) | wc -l    # => 158
grep -lE "$U" $(git ls-files priv/templates) | wc -l    # => 46
grep -nE "$U" $(git ls-files test/fixtures/install_golden/tree) | wc -l   # => 139
grep -lE "$U" $(git ls-files test/fixtures/install_golden/tree) | wc -l   # => 35
```

Measured HEAD numbers:

| Surface | Union lines | Union files |
|---|---|---|
| `priv/templates/` | **158** | **46** |
| `test/fixtures/install_golden/tree/` (golden) | **139** | **35** |

All four numbers match `239-RESEARCH.md` §2/§3 exactly. No divergence — the phase proceeds on the
research ledger's numbers without adjustment.

**Positively-asserted favourable context (not silently dropped):**

- `test/fixtures/install_golden/STDOUT.txt` carries **zero** union-token lines today
  (`grep -cE "$U" test/fixtures/install_golden/STDOUT.txt` => `0`). The D-13 independent-drift
  hazard (STDOUT.txt drifting separately from `tree/`) is measured-nil for this phase's starting
  point. This will be checked again, separately, in plan 239-04 after the sweep and re-bless land.
- `git diff --name-only origin/main -- .github/` is **empty** (0 lines). SC-5a ("no `.github/` edit
  in scope") has a genuine zero baseline today, needing no carve-out or waiver.

## WAVE0-COMMIT
Status: DONE — the wave-0 instruments are committed and their commit provably touches nothing
outside the phase directory.

- Commit sha: `a1bb08c6fc498fa6861012485a948a58ba6a2db4`
- Subject: `docs(239): wave-0 SC-3 classifier, frozen expected set, preflight ledger`
- `git show --name-only --format= HEAD` (at that commit) lists exactly six paths, all under
  `.planning/phases/239-priv-templates-sweep-one-batched-re-bless/`:
  - `239-EVIDENCE.md`
  - `239-comment-only-diff-check.sh`
  - `239-golden-expected.txt`
  - `fixtures/239-golden-add-only-hunk.diff`
  - `fixtures/239-golden-code-change.diff`
  - `fixtures/239-golden-comment-only.diff`
- `git diff --quiet HEAD -- priv/templates test/example test/fixtures .github mix.exs lib` exits 0
  at that commit — no source surface is dirty.
- `test/fixtures/prohibitions/` carries no change attributable to this phase (D-04; that directory
  belongs to Phase 241).
- Plan 239-02 should cite the commit sha recorded above (the single one in this file's "Commit
  sha:" bullet) as the pre-sweep baseline sha when it reports SC-3.

## SWEEP-COMMIT
Status: DONE — commit 1 of the D-19 three-commit topology lands, provably confined to
`priv/templates/`, driving the union grep to zero across all 119 tracked template files in all
three generators.

- Commit sha (hyphen-chunked to keep exactly one full 7-40-char hex token in this file, per the
  239-01 SIGPIPE-avoidance fix — concatenate the segments to recover the 40-char sha):
  `cafd9a-5328b5-f08f31-5a123f-d874d2-698831-7537`
- Subject: `refactor(239): strip planning bookkeeping from priv/templates (SURF-01, SURF-03)`
- Before/after union-token counts: **158 -> 0** across `priv/templates/` (46 files touched, 119
  tracked template files enumerated by `git ls-files priv/templates`).
- `git show --name-only --format= HEAD` at that commit lists exactly 46 paths, every one under
  `priv/templates/`.
- `git diff --name-only origin/main -- .github/` is empty — no `.github/` drift introduced.
- `MIX_ENV=test mix compile --warnings-as-errors` is clean (no warning, no error) after the sweep.
- All five D-03 deliberate exclusions (`policy.ex` TODO, `mfa_challenge_live.ex` XXXX-XXXX,
  `sigra_auth.css` v1.46 compat prose, `scope.ex` UPGRADE-v1.2.md pointer, arity/version strings)
  survive verbatim, confirmed by grep against the post-sweep tree.

**Documented instrument limitation (not a regression):** `237-security-comment-diff-check.sh`
(SC-5b), run against this commit's full diff, reports exactly one survivor:
`core/auth.ex:530`'s pre-sweep line `# token clause so security signals are preserved (10.1
IN-03). Tokens`. This is structural, not fixable by rewording: SC-5b's tolerance regex recognizes
only `D-[0-9]{2}`, `SC-[0-9]+`, and `Phase [0-9]{1,3}` co-occurring on the SAME removed line as a
rationale word — it does not recognize `IN-[0-9]{2}`. Any edit to this line necessarily marks the
current HEAD text as "removed" in the diff (unified diff is line-granular), and that HEAD text
already carries "security" + "IN-03" with no SC-5b-recognized token, regardless of what replaces
it. The only tokens SC-5b would tolerate (`D-NN`, `SC-N`, `Phase N`, `.planning/`) are themselves
union-grep tokens this phase must remove, so no rewording of the AFTER text can satisfy both
instruments simultaneously for this one line. Per plan-level constraint D-16, `237-security-
comment-diff-check.sh` was not modified to close this gap. Verified via three independent repro
attempts (isolated single-file diff, six-file partial diff, full sweep-commit diff) — all three
report the identical single survivor and no other. The rationale sentence "security signals are
preserved" is intact in the AFTER text and `IN-03` is fully gone from the file, satisfying the
plan's actual SURF-01/SURF-03 intent; only the SC-5b instrument's advisory tolerance-regex gap is
unresolved, and it is advisory tooling per its own header ("deliberately NOT wired into any
workflow or prohibitions glob"). A second near-identical case
(`organizations/live/organization_settings_live.ex` "enumeration safety" / D-04 window merge) was
found and avoided during execution by leaving the rationale-bearing line untouched and editing
only the adjacent token-only line, keeping that one out of SC-5b's removed-line set entirely —
demonstrating the fix is possible whenever the token and rationale word do not already share HEAD's
one physical line, which is not the case for `auth.ex:530`.

## MIRROR-COMMIT
Status: DONE — commit 2 of the D-19 three-commit topology lands, provably confined to
`test/example/`, mirroring the 30 counterparts of edited templates while leaving the four
already-absent counterparts and the deliberately-unswept repo-wide remainder untouched.

- Commit sha (hyphen-chunked to keep exactly one full 7-40-char hex token in this file, per the
  239-01 SIGPIPE-avoidance fix — concatenate the segments to recover the 40-char sha):
  `e69f4d-9b36a8-700d78-1039aa-1f4326-7b412c-d884`
- Parent commit (the `.planning/` checklist + todo commit, immediately preceding, confirming the
  D-19 commit ordering): `df04-e43a` (subject: `docs(239): SC-4 mirror checklist and pre-existing
  example todo`)
- Subject: `refactor(239): mirror template bookkeeping sweep into test/example counterparts
  (SURF-03)`
- `git show --name-only --format= HEAD` at that commit lists exactly 30 paths, every one under
  `test/example/`.
- `git diff --name-only origin/main -- .github/` is empty — no `.github/` drift introduced.
- Repo-wide `test/example/` union-token count: **476 -> 366** (110 lines removed across the 30
  mirrored counterparts; the remaining ~64-file / ~366-line surface is deliberately unswept per
  SC-4's counterpart-only scope — see `239-MIRROR-CHECKLIST.md`'s scoping statement).
- The four zero-token counterparts (`settings_live.ex`, `auth_error_handler.ex`,
  `organization_invitation.ex`, the timestamped `create_organizations.exs` migration) are
  confirmed unmodified (`git diff --quiet HEAD -- <path>` exits 0 for each).
- `mix format --check-formatted` passes repo-wide; `MIX_ENV=test mix compile
  --warnings-as-errors` inside `test/example/` is clean **except one pre-existing, unrelated
  warning** — `SettingsLive`'s `~p"/dev/mailbox"` verified route has no matching route under
  `MIX_ENV=test` (the route only exists when `dev_routes` is compile-time enabled, which is
  `config/dev.exs`-only). Confirmed pre-existing via `git stash` reproducing the identical warning
  against unmodified HEAD (`7a12-e2e2`) before any of this plan's edits existed; filed as a todo
  (`.planning/todos/pending/2026-09-17-example-settings-live-dev-mailbox-verified-route-test-env.md`,
  committed in `df04-e43a`) rather than fixed in-phase, per the v1.48 standing constraint
  (found-while-cleaning -> new todo, never an in-phase fix) and because `settings_live.ex` is one
  of this plan's four already-absent counterparts — touching it for an unrelated reason would blur
  that row's own audit trail.

## MIX-CI-RUNS
Status: DONE (run #1) — the first of the two `mix ci` runs RESEARCH Open Question 3 calls for
(the second runs after commit 3, in plan 239-04).

- **Cold-build note (not a regression):** the first invocation of `MIX_ENV=test mix ci` on this
  session's `_build` reported `33 doctests, 3 properties, 2606 tests, 6 failures` — all six
  `(UndefinedFunctionError) function Sigra.Audit.Forwarders.Threadline.attach/1 is undefined`.
  `Sigra.Audit.Forwarders.Threadline` gates its own definition behind
  `Code.ensure_compiled(Threadline) == {:module, Threadline}`; on a cold `_build` where the
  optional `threadline` dependency compiles in the *same* run as `sigra` (visible in that run's own
  log: `==> threadline / Compiling 83 files (.ex)` immediately preceding `==> sigra`), the guard
  evaluates false before `threadline` is available, and the module is never defined. This is a
  build-ordering artifact, not a code fault — `git log <wave-0-baseline-sha>..HEAD -- lib/` (see
  the `## WAVE0-COMMIT` "Commit sha:" bullet for the baseline) is empty, so no `lib/` change in
  this phase could have caused it. Running `MIX_ENV=test mix compile --force`
  once (to prime the `_build` deterministically) and then re-running `MIX_ENV=test mix ci`
  reproduced the clean, authoritative result below. Waves 1 and 2 (239-01, 239-02) both went green
  the identical way.
- **Authoritative run-#1 result** (`MIX_ENV=test mix compile --force` then `MIX_ENV=test mix ci`):
  exit **0**.
  - `mix format --check-formatted`: pass (no output, alias would have halted otherwise).
  - `mix deps.get --check-locked`: pass (alias continued).
  - `mix deps.unlock --check-unused`: pass (alias continued).
  - `mix compile --warnings-as-errors`: pass (alias continued; root `lib/` only — `test/example/`
    is a separate nested Mix project not compiled by this step).
  - `mix test --exclude scaffold`: **33 doctests, 3 properties, 2606 tests, 0 failures, 12
    skipped (22 excluded)**.
  - `ci.install_golden` (`mix test test/sigra/install/features/passkeys_js_test.exs
    test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/golden_diff_test.exs
    test/sigra/install/idempotency_test.exs test/sigra/install/vault_promotion_test.exs
    test/upgrade_test.exs`): **65 tests, 0 failures (2599 excluded)**.
  - `sigra.dep_off` (`scripts/ci/sigra-dep-off.sh`): guard step (`mix test --only
    threadline_guard --no-deps-check`) and restore step (`mix deps.get --check-locked` +
    `mix compile threadline`) both clean; script's own standalone run separately confirmed exit 0.
- **Correction on how this run may be cited (do not over-claim):** `golden_diff_test.exs` carries
  `@moduletag :scaffold`. `mix ci`'s earlier `test --exclude scaffold` step leaves an
  `:excluded_tags` filter that leaks into the *same-VM* `ci.install_golden` invocation, so
  `golden_diff_test`'s actual assertions did not run inside this `ci.install_golden` pass — proven
  independently (standalone: `2 tests, 1 failure`; chained after `--exclude scaffold`: `0 tests,
  0 failures (1 excluded)`). **This run is valid evidence for this plan's own scope (formatting,
  deps-lock, compilation, the full non-scaffold test suite, and the dep-off guard) but is NOT
  corroboration of golden-fixture drift state either way** — the golden fixture still mirrors the
  pre-sweep templates (re-blessing is commit 3's job, owned by plan 239-04), and this run's
  `ci.install_golden` pass neither confirms nor denies that; it simply didn't exercise the
  `:scaffold`-tagged assertion this time.

## REBLESS-COMMIT
Status: DONE — commit 3 of the D-19 three-commit topology lands, provably confined to
`test/fixtures/install_golden/`, and the fixture is proven settled by both the `--check`
contract and `ci.install_golden`.

- **First run's classifier result was NOT clean** — `nonconforming=7` on the first
  `MIX_ENV=test mix sigra.fixture.rebless_golden` run. All seven were comment-reflow side
  effects of SWEEP-COMMIT's (cafd9a53) token removal shifting word-wrap onto an adjacent,
  non-token line that `239-golden-expected.txt` never anticipated (built at wave 0, before
  wave 2's actual edits landed). Per the plan's stop-the-line rule, each was diagnosed and the
  responsible template edited so only the token-bearing line changes and every reflow-neighbour
  line stays byte-identical to its pre-sweep text, then the fixture was `git checkout`'d and the
  re-bless re-run. Fixed in commit `2a34e1c8` (`refactor(239): resolve re-bless reflow
  neighbours in priv/templates`):
  - `priv/templates/sigra.install/core/mfa_settings_live.ex:606-607`
  - `priv/templates/sigra.install/organizations/live/organization_members_live.ex` (3 spots:
    the "Generated by" attribution line, the Pagination bullet, and the Phase-17-seam
    paragraph)
  - `priv/templates/sigra.install/organizations/live/organization_settings_live.ex:3-4`
  - `priv/templates/sigra.install/core/sigra_auth.css:697-700`
- **A second, distinct gap surfaced after the reflow fixes**: `removed_lines=136`, three below
  the 139 floor. `comm -23` against the expected T-set isolated exactly 4 missing router.ex
  lines (expected lines 71, 74, 86, 97). Their source is **not** `priv/templates/` at all —
  it's `lib/sigra/install/features/core.ex`'s `content = """ ... """` heredoc (lines 479, 482,
  494, 503), the literal text this generator injects into a fresh app's router.ex.
  SWEEP-COMMIT's scope was `priv/templates/` only, so this heredoc was never touched. SURF-01
  (REQUIREMENTS.md:82) scopes the requirement to "**lib/ or priv/templates/**", so this is in
  scope — it was fixed in commit `6fa3ead2` (`fix(239): sweep bookkeeping tokens from router.ex
  heredoc in Sigra.Install.Features.Core`), touching only the 4 heredoc lines. Every other
  union-token line elsewhere in `core.ex` (lines 12, 93, 176, 184, 197, 207, 219, 226, 236, 242,
  247, 250, 285) is Sigra's own internal comment about the generator's own code structure,
  outside any heredoc destined for a generated app, and was left untouched — confirmed by
  reading the surrounding code (those lines sit in `@moduledoc`, `migrations/1`, and other
  functions, never inside the `content = """ ... """` block that spans lines ~454-521).
  **This is a deviation from the D-19 three-commit topology** (Rule 2/3: missing coverage
  blocking both the re-bless floor and Task 2's generated-app grep) — committed separately,
  ahead of the golden re-bless commit, not folded into it.
- **Two of those neighbour-preserving rewrites damaged the prose they preserved.** The
  constraint is real — in a merge site the only editable line is the token-bearing one, so when
  that line also carries the sentence structure, byte-preserving the neighbours can leave the
  sentence broken. Four sites survived intact; two did not, and one of those was a live
  regression rather than a cosmetic one:
  - `core/sigra_auth.css:698` — `do not re-litigate this;` was left dangling in front of the
    untouched `and the reflow failure payload ... that proves it.` Repaired in `061c-1758` to
    `... this comment records the verified mechanism`, which closes the sentence without
    reintroducing the removed `231-GAP-GATE02-SUMMARY.md` reference and without inventing a
    referent that does not exist.
  - `organizations/live/organization_members_live.ex:24` — removing the `(D-22).` fragment also
    removed the sentence terminator, running the pagination note into the Flop sentence.
    Repaired in `061c-1758`; the line now opens `only.` Mirrored into `test/example` (SC-4).
  - `lib/sigra/install/features/core.ex:479` — **regression, caught by `mix ci`, not by
    inspection.** `6fa3ead2` rewrote `# Phase 14 Plan 03: organization-aware pipelines` as
    `# Organization-aware pipelines`, and capitalising the word at sentence start put a literal
    `Organization` into the module's own source. That breaks the Pitfall X-1 isolation invariant
    at `test/sigra/install/features/core_test.exs:309`, which refutes `~r/\bOrganization\b/`
    against `core.ex`. Repaired in `e4e0-3980` to `# Opt-in organization-aware pipelines.`
    (`core_test.exs`: 29 tests, 0 failures).
  - `lib/sigra/install/features/core.ex:482` — `Phase 16 wires these to` became the subjectless
    `Wires these to`, running into the untouched `# the organization picker + switcher.` Now
    `These wire into`. Repaired in the same commit.

  Every repaired line is itself a token-bearing line from the frozen expected set, so removed-line
  containment is unchanged and no locked neighbour byte moved. Both repair commits touch zero
  paths under `test/fixtures/install_golden/`, so Safety Rule 1 holds.
- **Fourth and final rebless run** (after the two repair commits): `nonconforming=0`,
  `removed_lines=140` (floor 139), `files=35` (floor 30), `changed_lines=258` — byte-identical
  counters to the third run, which is the expected result since the repairs only re-word lines
  that were already inside the expected removed set.
- Commit sha (hyphen-chunked per the 239-01 SIGPIPE-avoidance convention — concatenate the
  segments to recover the 40-char sha): `38c9bd-9ab462-78a431-516524-3dcf97-99e07e-863a`
  (subject: `chore(239): re-bless install golden fixture after template bookkeeping sweep
  (SURF-03)`).
- `git show --name-only --format= HEAD` at that commit lists exactly 35 paths, every one under
  `test/fixtures/install_golden/`.
- `git log --oneline origin/main..HEAD -- test/fixtures/install_golden` returns exactly 1 line —
  SC-3's single-commit requirement holds.
- `test/fixtures/install_golden/STDOUT.txt` diffstat is empty at this commit — no swept comment
  leaked into installer summary output; the D-13 independent-drift hazard stayed measured-nil.
- `MIX_ENV=test mix sigra.fixture.rebless_golden --check` prints the literal `OK: fixture is
  up-to-date (check mode).` and exits 0.
- `MIX_ENV=test mix ci.install_golden` (standalone, not chained after `--exclude scaffold`, so
  the `:scaffold`-tagged `golden_diff_test.exs` assertions actually execute this time — see the
  `## MIX-CI-RUNS` entry above for why a chained run can't be trusted for this): **19 tests, 0
  failures (3 excluded)**.
- `mix archive` confirms `phx_new-1.8.8` — the D-14 precondition held throughout all three
  rebless runs, so every byte-diff observed above is real drift, not an archive-version
  artifact.

## MIX-CI-RUNS (run #2, after commit 3)
Status: DONE — green, with the same cold-`_build` ordering artifact as run #1 documented and
distinguished from a real failure by a force-compile control.

- **First invocation after the golden commit**: `MIX_ENV=test mix ci` exited 2 with
  `2606 tests, 6 failures` — all six in `Sigra.Audit.Forwarders.ThreadlineTest`, the identical
  set run #1 saw. Root cause is unchanged and is an artifact of `mix ci`'s own shape: the alias
  ends with `sigra.dep_off`, which recompiles without optional deps and leaves `_build` in the
  deps-off state for the *next* invocation. `Sigra.Audit.Forwarders.Threadline` sits behind
  `if Code.ensure_compiled(Threadline) == {:module, Threadline}`, so it is absent on the
  following cold run.
- **An earlier invocation additionally failed `Sigra.DeliveryTest` "routes to :sync when Oban is
  not supervised"** with a `KeyError` on `:user_id` in `Sigra.Delivery.build_job/3`. Same root
  cause, same family: Oban is an optional dep, so `sigra.dep_off` changes which branch
  `deliver_async/3` takes. Positive control that it is not this phase's doing:
  `git log --oneline ebc5d9e1^..HEAD -- lib/sigra/delivery.ex test/sigra/delivery_test.exs`
  returns nothing, while the same query against
  `lib/sigra/install/features/core.ex` returns `6fa3ead2` — so the query was live and the
  silence is a real absence, not a mistyped path.
- **Control**: `MIX_ENV=test mix compile --force` (exit 0, 178 files) then
  `MIX_ENV=test mix test --exclude scaffold` -> **exit 0, 33 doctests, 3 properties, 2606 tests,
  0 failures, 12 skipped (22 excluded)**. Both failure families disappear on a warm build, which
  is what distinguishes an ordering artifact from a regression.
- **Full gate on a warm build**: `MIX_ENV=test mix ci` -> **exit 0**, `2606 tests, 0 failures`.
- **Golden gate standalone** (not chained after `--exclude scaffold`, so the `:scaffold`-tagged
  `golden_diff_test.exs` assertions actually execute): `MIX_ENV=test mix ci.install_golden` ->
  **19 tests, 0 failures (3 excluded)**.
- `MIX_ENV=test mix sigra.fixture.rebless_golden --check` prints the literal
  `OK: fixture is up-to-date (check mode).` and exits 0.

## HONEST-CLAIMS
Status: DONE — including one gate recorded RED with its diagnosis rather than argued green.

**SC-1 — freshly generated app (live external observation #1).**
`scripts/ci/install-smoke.sh` scaffolded a fresh phx.new 1.8.8 app and ran `mix sigra.install`
to completion (`Sigra authentication has been installed` printed once). Against the generated
tree, never against the source tree:

```
SC1_planning_hits=0
SC1_union_token_hits=0
SC1_positive_control_defmodule_lines=78
```

The positive control is load-bearing: a zero-hit grep and a grep that never ran are the same
observation without it. 79 files under `lib/`, 20 under `priv/`.

The script's *later* `mix ecto.migrate` leg failed, and that failure is environmental, not a
finding: `install-smoke.sh` is documented as requiring Postgres on `localhost:5432`, while this
machine runs the Dockerized test Postgres on a dynamic port. The grep above is taken after
`mix sigra.install` and does not depend on the database.

**SC-2 — built tarball (live external observation #2).**
`mix hex.build`, unpacked in a scratch directory (Safety Rule 8 — no `sigra-*.tar` or `sigra-*/`
is left in the repo; verified after the fact). In scope: `grep -rn '\.planning/' lib priv` ->
**0 hits**, with a positive control of 161 greppable files under `lib/`. Out of scope by design,
enumerated rather than claimed absent: `docs/` 12, `README.md` 1, `CHANGELOG.md` 19, `mix.exs` 0
— **32 total**, matching the figure the plan predicted.

The honest claim is that `lib/` and `priv/` are clean. The whole tarball is not, by design, and
the published 1.5.0 on Hex still carries the leak — that reaches adopters only at 1.5.1.

**SC-3 `install_golden_contract` job clause — ship-time deferral.**
SC-3's remaining clause asks for a green `install_golden_contract` Actions run. This phase pushes
nothing, so no Actions verdict exists to read. Recorded as an explicit deferral to ship time
rather than left silently unobserved or asserted from a local proxy.

**SC-5b — `237-security-comment-diff-check.sh`: RED, with the failure diagnosed and filed.**

Against the full phase diff (`git diff a1bb08c6 HEAD -- lib/ priv/ test/example/ test/fixtures/`)
the classifier **exits 1**. It flags one line, appearing in three mirrored locations
(`priv/templates/.../core/auth.ex`, `test/example/.../accounts.ex`, and the golden fixture):

```
-  # token clause so security signals are preserved (10.1 IN-03). Tokens
+  # token clause so security signals are preserved. Tokens
```

This is a classifier scope mismatch, not a lost rationale. The script's tolerated-token set is
`\b(D-[0-9]{2}|SC-[0-9]+|Phase [0-9]{1,3})\b|\.planning/`. This repository's actual bookkeeping
definition — the frozen union regex in `## PREFLIGHT-UNION-LEDGER` above — is wider and includes
`IN-[0-9]{2}`. So `IN-03` **is** a bookkeeping token by the phase's own definition and **is not**
by the script's, and the line reads to the script as security rationale deleted with nothing
justifying it.

The rationale is intact. The comment at `priv/templates/sigra.install/core/auth.ex:526-532` still
reads, in full: *"Legacy API accepting a user struct. Test-only helper — bypasses the HMAC
signature rewind, audit log row, and telemetry events that the signed-token clause above emits
via `Sigra.Auth.reset_password/4`. Do NOT call this from controllers; production flows must use
the signed token clause so security signals are preserved. Tokens are invalidated in a single
transaction so the caller can create a fresh session after reset."* Only the citations
`(10.1 IN-03)` and `(D-29)` left.

**Positive control** — the same script over the same diff with the `auth.ex`/`accounts.ex`
mirrors excluded: `examined_removed_lines=409`, **exit 0**. So the check was live across 409
removed lines and this one line family is its sole trip.

Not fixed here, for two independent reasons that point the same way: D-16 pins the script as
unmodifiable, and Standing Constraint 4 makes found-while-cleaning a todo. Filed as
`2026-09-17-security-comment-classifier-token-set-omits-half-the-union.md`, with the suggestion
that Phase 241's `p18` ratchet own a single shared token definition instead of each phase
artifact hand-copying a subset.

**`.github/` untouched.** `git diff --name-only origin/main -- .github/` returns 0 paths, and
`git diff origin/main -- .github/` contains 0 changed `name:` lines.

**Todos filed, none fixed in-phase** (Standing Constraint 4), each with its diagnosis attached:
- `2026-09-17-ci-change-detector-omits-sigra-upgrade-and-gen-oauth.md`
- `2026-09-17-fut-01-template-example-parity-guard.md`
- `2026-09-17-security-comment-classifier-token-set-omits-half-the-union.md`
