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

## WIDENED-UNION-LEDGER
Status: PASS — surface counts under V2 at final committed HEAD: `priv/templates/` **4**,
`test/fixtures/install_golden/tree/` **4**, `test/fixtures/install_golden/STDOUT.txt` **0** (total
**8** triage rows). Disposition counts: `FIX-239-06` **3**, `FALSE-POSITIVE` **1**,
`OUT-OF-SCOPE` **0**, `MIRRORS-<template>` **4**. V1 returned **0** on all three surfaces — the
instrument gap is a measured 0→8 delta, not an assertion. The widened net found **1 beyond the
GAP-1 enumeration** (`sigra_auth.css:696`, plan ID `231-02`), and it is inside `priv/templates/`, so
it joins plan 239-06's fix list without widening the phase.

### (a) V2, verbatim

Built by extending the frozen V1 string from `## PREFLIGHT-UNION-LEDGER` — never retyped from
memory — with six appended alternations after `\bB[0-9]\b`. The first five are the verifier's named
requirement; `\b[Ww]ave [0-9]` is added because GSD wave numbering is the same class of internal
bookkeeping and the verifier's own wider-net command already used it.

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]
```

The six appended alternations, isolated:

```
\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]
```

**Why V1 could not see the leak** (239-VERIFICATION.md's second gap, restated as a mechanism):
V1's plan-ID alternation is `[0-9]{3}-[A-Z0-9-]+\.md`, which requires a trailing `.md`, so the bare
plan ID `231-02` in `sigra_auth.css:696` is structurally unmatchable. V1 has no alternation at all
for `round N`, for 10-digit GitHub Actions run IDs, or for `UAT`.

### (b) Per-alternation positive controls

Every zero in this ledger is paired with a control on a surface where the pattern is known to fire,
so a later zero on `priv/templates/` is a real negative and not a dead alternation. All six controls
returned non-zero; no alternation is dead.

| # | Alternation | Control command | Count |
|---|---|---|---|
| 1 | `\b[0-9]{3}-[0-9]{2}\b` | `grep -cE '\b[0-9]{3}-[0-9]{2}\b' .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-VERIFICATION.md` | **10** |
| 2 | `\b[Rr]ound[s]?[ -][0-9]` | `grep -cE '\b[Rr]ound[s]?[ -][0-9]' .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-VERIFICATION.md` | **4** |
| 3 | `\b[Rr]uns? [0-9]{9,}` | `grep -cE '\b[Rr]uns? [0-9]{9,}' .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-VERIFICATION.md` | **2** |
| 4 | `actions/runs/[0-9]+` | `grep -cE 'actions/runs/[0-9]+' .planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` | **3** |
| 5 | `\bUAT\b` | `grep -cE '\bUAT\b' .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-VERIFICATION.md` | **9** |
| 6 | `\b[Ww]ave [0-9]` | `grep -cE '\b[Ww]ave [0-9]' .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md` | **2** |

Alternation 4's control is `SEED-006` rather than `239-VERIFICATION.md`: the verification report
cites run IDs as bare numbers, not as GitHub URLs, so it returns 0 there. Recording the surface that
does fire is the point of the control — a 0 on the first candidate surface is an unsuitable control,
not a dead alternation, and the distinction is only visible because the control was run.

**Instrument limitation, recorded rather than smoothed over:** these are line-based greps. In
`sigra_auth.css` the phrase `after rounds\n     1-2.` is split across lines 514-515, so alternation 2
does not match it even though it is exactly the bookkeeping the alternation targets. Line 519's
`Live multi-run CI evidence` (`multi-run` has no digit after it) and line 698's `do not re-litigate
this` likewise match nothing. All three sit **inside** the two comment blocks already dispositioned
`FIX-239-06` below, which 239-06 rewrites as whole blocks, so nothing is lost — but a future
`p18` guard built on line-based matching inherits this gap.

### (c) V1 ↔ V2 delta on the two surfaces V1 certified clean

```bash
V1='\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b'
V2="${V1}"'|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]'
# brace group + `|| true` inside every substitution: a zero-match grep is a
# measurement, not a fatal status under `set -eo pipefail` (SAFETY RULESET 1).
{ grep -nE "$V1" $(git ls-files priv/templates) || true; } | wc -l
{ grep -nE "$V2" $(git ls-files priv/templates) || true; } | wc -l
{ grep -nE "$V1" $(git ls-files test/fixtures/install_golden/tree) || true; } | wc -l
{ grep -nE "$V2" $(git ls-files test/fixtures/install_golden/tree) || true; } | wc -l
```

| Surface | V1 lines | V2 lines (pre-fix) | V2 lines (final HEAD) |
|---|---|---|---|
| `priv/templates/` | **0** | **5** | **4** |
| `test/fixtures/install_golden/tree/` | **0** | **4** | **4** |
| `test/fixtures/install_golden/STDOUT.txt` | **0** | **0** | **0** |

The pre-fix column is the measurement taken before this plan's `login_html.ex` edit; the final
column is the same measurement at the committed HEAD. The golden tree is unchanged by this plan by
design — it is generator output and clears only at plan 239-08's single re-bless (D-09).

`STDOUT.txt` is recorded at **0** rather than omitted: D-13 names it as an independent-drift hazard
distinct from `tree/`, and it stays measured-nil under the wider net.

**Paired positive control for the `priv/templates/` measurement** (a green grep over an empty file
list would be indistinguishable from a clean tree otherwise):

```bash
{ grep -lE "$V2" $(git ls-files priv/templates) || true; } | wc -l   # => 2   (files with hits)
{ grep -lc defmodule $(git ls-files priv/templates) || true; } | wc -l  # => 97  (greppable files)
```

### (d) Generated-app observation — the leak closed, on generated bytes

The claim is made on the literal bytes an adopter receives, never on `priv/templates/` (D-15,
Standing Constraint 1). `scripts/ci/install-smoke.sh` scaffolded a fresh Phoenix 1.8.8 app, added
Sigra as a path dep, ran `mix sigra.install --yes Accounts User users` and `mix sigra.gen.oauth`,
and compiled `--warnings-as-errors` (`SMOKE_EXIT=0`).

```bash
ASDF_ERLANG_VERSION=28.5 ASDF_ELIXIR_VERSION=1.19.5-otp-28 \
  TMP_APP_DIR=/tmp/sigra_239_05_app GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh
{ grep -rhE '\bUAT\b' /tmp/sigra_239_05_app/lib /tmp/sigra_239_05_app/priv || true; } | wc -l
# => 0
{ grep -rhc 'defmodule' /tmp/sigra_239_05_app/lib /tmp/sigra_239_05_app/priv || true; } | paste -sd+ - | bc
# => 94   (across 93 files — the paired positive control; the tree is real, not empty)
rm -rf /tmp/sigra_239_05_app
```

The generated `lib/sigra_239_05_app_web/controllers/session_html.ex` moduledoc reads
`… LiveView's form-submission attributes were swallowing the browser form submit. With no LiveView
process on the page, the browser performs a real HTTP POST to \`SessionController.create/2\`.` —
`during UAT` gone, the IN-04 `LiveView's / LiveView` duplication collapsed, the causal claim intact.
The scratch app was removed (REPO-01).

### (e) Per-hit triage — every V2 hit, exactly one disposition

One row per V2 hit across all three surfaces; 4 + 4 + 0 = 8 rows, matching the `Status:` counts.

| path:line | matched alternation | line text (trimmed) | disposition |
|---|---|---|---|
| `priv/templates/sigra.gen.oauth/oauth_html.ex:54` | `\b[0-9]{3}-[0-9]{2}\b` (matched `373-12`) | `<path d="M24 12.073c0-6.627-5.373-12c0 …" fill="#1877F2"/>` | **FALSE-POSITIVE** — SVG `path d=` geometry data in the Facebook provider button; `5.373-12` is two floating-point path coordinates, not a plan ID. Not text, not a comment, not editable prose. |
| `priv/templates/sigra.install/core/sigra_auth.css:524` | `\b[Rr]ound[s]?[ -][0-9]` (`round-3`) | `initial round-3 draft that used \`overflow-wrap: break-word\` here silently` | **FIX-239-06** — review-round history inside the `:508-533` comment block (GAP-1). |
| `priv/templates/sigra.install/core/sigra_auth.css:531` | `\b[Rr]uns? [0-9]{9,}` (`runs 30518012012`) and `\b[Rr]ound[s]?[ -][0-9]` (`round-3`) | `runs 30518012012 and 30518015684 immediately after the round-3 commit, never` | **FIX-239-06** — live GitHub Actions run IDs inside the same `:508-533` block (GAP-1). |
| `priv/templates/sigra.install/core/sigra_auth.css:696` | `\b[0-9]{3}-[0-9]{2}\b` (`231-02`) | `automatic minimum width (min-content) even though 231-02's min-width: 0 already` | **FIX-239-06** — a bare Sigra plan ID inside the `:689-698` comment block (GAP-1). **This is the hit V1 was structurally blind to.** |
| `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/controllers/session_html.ex:8` | `\bUAT\b` | `submit during UAT. With no LiveView process on the page, the browser` | **MIRRORS-`priv/templates/sigra.install/core/login_html.ex`** (D-21 rename mapping) — source fixed in this plan's Task 1; the fixture clears at plan 239-08's single re-bless. |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css:524` | `\b[Rr]ound[s]?[ -][0-9]` | `initial round-3 draft that used \`overflow-wrap: break-word\` here silently` | **MIRRORS-`priv/templates/sigra.install/core/sigra_auth.css`** — fixed in 239-06, clears at 239-08. |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css:531` | `\b[Rr]uns? [0-9]{9,}`, `\b[Rr]ound[s]?[ -][0-9]` | `runs 30518012012 and 30518015684 immediately after the round-3 commit, never` | **MIRRORS-`priv/templates/sigra.install/core/sigra_auth.css`** — fixed in 239-06, clears at 239-08. |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_auth.css:696` | `\b[0-9]{3}-[0-9]{2}\b` | `automatic minimum width (min-content) even though 231-02's min-width: 0 already` | **MIRRORS-`priv/templates/sigra.install/core/sigra_auth.css`** — fixed in 239-06, clears at 239-08. |

Every golden-tree hit resolves to a source template. **No orphan golden hit exists**, so the
stop-the-line condition (a golden hit with no source template, which would mean the fixture is not
generator output) did not fire.

Hand-editing the golden tree is forbidden (D-09); a golden hit is only ever fixed in its source
template.

### (f) Overflow rule

Stated verbatim so a later reader cannot infer a looser one:

> If the `FIX-239-06` set is larger than the GAP-1 enumeration (the two `sigra_auth.css` comment
> blocks), every extra row is added to plan 239-06's fix list and the count is recorded in the
> SUMMARY as "widened net found N beyond the verifier's enumeration". If any extra row requires work
> outside `priv/templates/` and `test/example/` — a `lib/` source edit, a `.github/` edit, a schema
> or behaviour change — do NOT fix it: **record it as `OUT-OF-SCOPE`, file it as a todo per Standing
> Constraint 4, and say so in the SUMMARY — never widen the phase.** The widened net is allowed to
> find more; it is not allowed to silently widen the phase.

Applied here: the `FIX-239-06` set is `{:524, :531, :696}`, a **superset** of GAP-1's two blocks
(`:508-533` contributes `:524` and `:531`; `:689-698` contributes `:696`). The overflow is
`sigra_auth.css:696` — **1 beyond the verifier's enumeration**, and it lives inside
`priv/templates/`, so 239-06 absorbs it with no scope change. No row required work outside
`priv/templates/`/`test/example/`, so no `OUT-OF-SCOPE` todo was triggered by the triage itself.

## CLOSURE-TEMPLATE-COMMIT
Status: PASS — every `FIX-239-06` row from `## WIDENED-UNION-LEDGER` is closed individually with a
literal proving grep, the seven `239-REVIEW.md` prose repairs are applied in `priv/templates/`, and
the commit is path-scoped. Residual V2 on `priv/templates/` is **2 occurrences on 1 line**, and that
line is the row already dispositioned `FALSE-POSITIVE` in the ledger — real bookkeeping under V2 is
**0**. Recorded as measured rather than as the plan's anticipated bare `0`, because the ledger's own
disposition is what makes the 2 harmless, and rounding it to 0 would hide that dependency.

### (a) V2 re-measure over `priv/templates/`, with its paired positive control

```bash
V1='\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b'
V2="${V1}"'|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]'
{ grep -hoE "$V2" $(git ls-files priv/templates) || true; } | wc -l           # -> 2
{ grep -nE  "$V2" $(git ls-files priv/templates) || true; } | wc -l           # -> 1 line
{ grep -lc  defmodule $(git ls-files priv/templates) || true; } | wc -l       # -> 97  (positive control)
```

| Measurement | Value | Reading |
|---|---|---|
| V2 occurrences over `priv/templates/` | **2** | both are `373-12`, from one SVG `path d=` coordinate pair |
| V2 matching lines | **1** | `priv/templates/sigra.gen.oauth/oauth_html.ex:54` |
| Of those, dispositioned `FALSE-POSITIVE` in `## WIDENED-UNION-LEDGER` | **1 line / 2 occurrences** | Facebook button geometry `…c0-6.373-5.373-12-12-12s…`, not a plan ID |
| **Undispositioned V2 rows** | **0** | the stop-the-line condition did not fire |
| Positive control: files containing `defmodule` on the same file list | **97** | the grep is live; the zero above is a real negative, not an empty file list |

`sigra_auth.css` — the file this plan rewrote — now returns **0** under V2:
`{ grep -hoE "$V2" priv/templates/sigra.install/core/sigra_auth.css || true; } | wc -l` -> `0`,
paired with `grep -c 'min-width: 0' …` -> **12** on the same file.

Unchanged by design: `test/fixtures/install_golden/tree/` still returns **4** under V2. Those four
rows are `MIRRORS-<template>` and clear only at plan 239-08's single re-bless (D-09) — the golden
tree is a generated snapshot and is deliberately not hand-edited here.

### (b) Row-by-row closure record — one line per `FIX-239-06` row (no aggregate count)

| # | Row (from `## WIDENED-UNION-LEDGER`) | Before | Proving grep (run at this commit) | Result |
|---|---|---|---|---|
| 1 | `sigra_auth.css:524` | `initial round-3 draft that used \`overflow-wrap: break-word\` here silently` | `grep -cE '\b[Rr]ound[s]?[ -][0-9]' priv/templates/sigra.install/core/sigra_auth.css` | **0** |
| 2 | `sigra_auth.css:531` | `runs 30518012012 and 30518015684 immediately after the round-3 commit, never` | `grep -cE '30518012012\|30518015684\|actions/runs/' priv/templates/sigra.install/core/sigra_auth.css` | **0** |
| 3 | `sigra_auth.css:696` | `automatic minimum width (min-content) even though 231-02's min-width: 0 already` | `grep -cE '\b[0-9]{3}-[0-9]{2}\b' priv/templates/sigra.install/core/sigra_auth.css` | **0** |

Absorbed in the same block rewrites — the three lines the ledger recorded as a **line-based
instrument gap** (V2 cannot match them, so they would have survived a green V2 forever):

| # | Line | Before | Proving grep | Result |
|---|---|---|---|---|
| 4 | `sigra_auth.css:514-515` | `after rounds` / `1-2.` split across two lines | `grep -c 'after rounds' priv/templates/sigra.install/core/sigra_auth.css` | **0** |
| 5 | `sigra_auth.css:514` | `/* Live multi-run CI evidence showed H2/P sharing one` | `grep -c 'Live multi-run CI evidence' priv/templates/sigra.install/core/sigra_auth.css` | **0** |
| 6 | `sigra_auth.css:698` | `do not re-litigate this; this comment records the verified mechanism` | `grep -c 'do not re-litigate this' priv/templates/sigra.install/core/sigra_auth.css` | **0** |
| 7 | `sigra_auth.css:705` | `/* Live multi-run CI evidence` (third block, outside the GAP-1 enumeration) | covered by row 5's grep | **0** |

Mechanism-survived positive controls on the same file, so rows 1-7 are not a deletion:
`grep -c 'min-width: 0'` -> **12**, `grep -c 'overflow-wrap'` -> **7**,
`grep -cE 'automatic-minimum-size|automatic minimum'` -> **2**.

### (c) Comment-containment proof for the `sigra_auth.css` diff (T-239-06-04)

Two orthogonal assertions, both run over this commit's `git diff -U0` hunk headers (a header with no
explicit count read as count = 1). Neither is a character-class grep over diff text.

```
masked_single_line_spans post=1 pre=1
changed added_lines=20 removed_lines=26
added:   [514,515,516,517,518,519,520,522,523,524,525,526,527,528,529,530,693,694,695,700]
removed: [514,515,516,517,518,519,520,521,523,524,525,526,527,528,529,530,531,532,533,
          696,697,698,699,700,705,706]
ASSERTION_1 comment-range membership:        PASS   (post_set_size=50, pre_set_size=56)
ASSERTION_2 empty non-comment remainder:     PASS
```

Assertion 1 masks every single-line `/* … */` span before the state machine runs, so the one line in
this file that is simultaneously a declaration and a comment (`min-width: 0; /* … */`, near `:732`)
cannot latch the machine open. Assertion 2 is independent of any post-edit-derived line set: it
strips comment spans from each changed line's own text and requires the remainder to be whitespace.
Assertion 2 is what would catch an edit to the declaration half of that mixed line, and what would
catch an edit that drops a closing `*/` and thereby widens Assertion 1's own oracle. Plan 239-08's
`239-comment-only-diff-check.sh` over the re-bless diff remains the phase-level backstop; neither
check is trusted alone.

### (d) SC-5 re-proof at this commit (D-16 — script run, never edited)

```bash
git diff -- priv/templates > /tmp/239-06.diff        # 187 diff lines
.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh /tmp/239-06.diff
```

```
examined_removed_lines=45
SC5_EXIT=0
```

`examined_removed_lines=45` is > 0, so a vacuous pass is mechanically excluded. The two rationale
sites this plan touched were **strengthened**, not thinned: `organization_invitation_email.ex` now
reads `(phishing defense — prevents inviter/org spoofing)`, and `invitation_accept_live.ex` carries
a tool-agnostic `That absence is asserted by a test … do not add accept controls to this branch.`
The claim is true at HEAD — `test/example/test/example_web/live/invitation_accept_live_test.exs:582`
(T19) asserts the `render_mismatch/1` body contains no `phx-click="accept` / `phx-submit="accept`.
The original `ZERO \`phx-click\`/\`phx-submit\`` invariant sentence is intact (`grep -c 'ZERO .phx-click'` -> **1**).

### (e) `.github/` untouched (D-23, T-239-06-05)

```bash
git diff --name-only origin/main -- .github/ | wc -l    # -> 0
```

### (f) Commit scope and golden staleness

`git show --name-only --format= HEAD` lists only paths under `priv/templates/` and
`.planning/phases/239-priv-templates-sweep-one-batched-re-bless/`; `git status --porcelain` is clean
afterward. `MIX_ENV=test mix sigra.fixture.rebless_golden --check` exits **2** with
`DRIFT DETECTED:` — the correct state, proving the template edits do reach generated output and that
plan 239-08's single re-bless has real work to carry. `MIX_ENV=test mix compile --warnings-as-errors`
exits 0 with no output.

## CLOSURE-MIRROR-COMMIT

Status: RECORDED — plan 239-07, the `test/example/` mirror of the closure batch. Parent `60bac0bb`.

### (a) V2 re-measure with a live positive control

V2 is the widened union regex frozen in § `WIDENED-UNION-LEDGER` (used verbatim, not retyped).

| Surface | V2 count | Reading |
|---|---|---|
| `test/example/lib/example_web/router.ex` + `…/components/layouts.ex` (the two files Task 1 edited) | **0** | the assertion |
| `test/example/lib/example/demo/seeds.ex`, `…/lib/example/sigra_admin_policy.ex`, `…/lib/example_web/live/admin/design_gallery_live.ex` (IN-05 example-only, deliberately unswept) | **28** | the positive control — V2 is live on this tree, so the 0 above is a measurement and not a dead grep |
| the four files Task 2 converged | **0** | — |

A zero on both rows would have meant the grep was dead and the first number proved nothing. It is
not: the same regex, the same tree, the same invocation shape returns 28 on the files this plan is
prohibited from touching.

**Measured departure from the plan's anticipated fix list (Rule 2, recorded not smoothed).** The
first V2 run over the two Task-1 files returned **1**, not 0: `router.ex:175`
`# Dev-only routes for local UAT — …` carries `\bUAT\b`. That alternation entered V2 in 239-05 and
is exactly the token 239-05 removed from `login_html.ex`; the site is on a file this plan was
already editing, and leaving it would have falsified this plan's own `V2 → 0` truth. Rewritten to
`# Dev-only routes for local manual testing — Swoosh local-mailbox preview at / # /dev/mailbox`,
meaning preserved (the next line still reads "so manual testers can inspect rendered emails"). It is
example-only: no template or golden counterpart exists, so nothing diverges by fixing it here.

### (b) Per-sentence convergence, namespace-normalized

Method: extract the `@moduledoc` body from both trees, substitute `<%= web_module %>` → `ExampleWeb`,
`<%= app_module %>` → `Example`, `<%= context_module %>` → `Example.Accounts`, then diff.

| Sentence group | Template | Example | Verdict |
|---|---|---|---|
| WR-03 / WR-04 / IN-01 / IN-02 — members seam + Architecture bullets | `organizations/live/organization_members_live.ex` | `lib/example_web/live/organization_members_live.ex` | **MATCH** (prose identical; the sole residual delta is the demo app's own CSS class `vt-modal` vs `modal`, a pre-existing mini-brand substitution of the same class as the namespace substitution, on a line this phase did not touch) |
| WR-05 — Branch B | `organizations/live/organizations_live/index.ex` | `lib/example_web/live/organizations_live/index.ex` | **MATCH** |
| IN-04 + `during UAT` — login moduledoc | `core/login_html.ex` | `lib/example_web/controllers/session_html.ex` (renamed, D-21) | **MATCH** |
| IN-03(b) — `:mismatch` invariant note | `organizations/live/invitation_accept_live.ex` | `lib/example_web/live/invitation_accept_live.ex` | **MATCH** |
| WR-07 — MFA auto-submit comment | `core/mfa_settings_live.ex` | `lib/example_web/live/mfa_settings_live.ex` | **MATCH** (no edit — see (c)) |

Every row reads MATCH after normalization. No sentence ships in two wordings.

### (c) Confirmed no-edit dispositions (recorded, never a phantom edit)

| File | Confirming evidence | Disposition |
|---|---|---|
| `test/example/lib/example_web/live/mfa_settings_live.ex` | `diff <(sed -n '606,610p' priv/templates/sigra.install/core/mfa_settings_live.ex) <(sed -n '631,635p' <example>)` → identical, exit 0 | already converged — 239-06 adopted the example's wording into the template |
| `test/example/lib/example/accounts/organization_invitation.ex` | `sed -n '2p'` → `  @moduledoc false` | no counterpart sentence for WR-06 to converge into |

Neither file appears in `git diff --name-only` for this commit.

### (d) `sigra_auth.css` closure row asserted, not assumed

`grep -c 'min-width: 0' test/example/priv/static/assets/sigra_auth.css` → **3** (live control).
`grep -cE '30518012012|30518015684|re-litigate' test/example/priv/static/assets/sigra_auth.css` → **0**.
The example's CSS is a different, shorter build-free file with none of the three swept comment
blocks. No mirror edit; the file is absent from this commit.

### (e) IN-03(a) no-counterpart search

`grep -rc 'phishing defense — prevents inviter/org spoofing' test/example/` → **0 files**, against a
live control of **2** files under `test/example/` matching `phishing`. The example's
`lib/example/accounts/emails.ex` carries its own longer, differently-structured phishing rationale
(pre-existing, untouched), which is not the IN-03(a) parenthetical. D-22 holds for the closure batch.

### (f) Scope proofs

```
$ git diff --name-only origin/main -- .github/
(empty — 0 lines)
```

`MIX_ENV=test mix compile --warnings-as-errors` exits **0** with no output, run after Task 1 and
again after Task 2. `git show --name-only --format= HEAD` lists only paths under `test/example/` and
`.planning/phases/239-priv-templates-sweep-one-batched-re-bless/`; `git status --porcelain` is clean
afterward. No route, pipeline, plug, `attr` name, `default:`, import, or function head moved — the
full `git diff` for the two Task-1 files is 7 changed comment/`doc:` hunks and nothing else.


## REFREEZE-LEDGER

Status: PASS — the round-2 expected-removed set is frozen, committed **before** the re-bless, and the
ordering is readable from `git log` rather than taken on trust.

### (a) Why a second expected set is required

`239-golden-expected.txt` (round 1) is 139 `T:` records plus 2 anchored `N:` records, and every one
of those 139 lines is a V1 union-token line that the round-1 re-bless (`38c9bd9a`) already removed
from the golden tree. Those lines no longer exist, so round 1's set cannot contain round 2's
removals: reusing it would fail the containment check on every line of the new diff while
simultaneously failing its own `removed_lines >= 139` floor. A second set is not a convenience — it
is the only non-circular option.

### (b) Counts

| Record class | Count |
|---|---|
| `T:` (every golden-tree line matched by V2 at the pre-re-bless HEAD) | **4** |
| `N:` (prose repairs V2 cannot match, located by literal anchor) | **43** |
| Total records | **47** |
| Distinct golden paths across all records | **7** |

The 4 `T:` records are the `session_html.ex` `during UAT` line and the three `sigra_auth.css` lines
(`round-3`, `runs 30518012012`, `231-02`) that § WIDENED-UNION-LEDGER triaged as `MIRRORS-<template>`.

### (c) The literal-anchor list

The anchors are **not** a blanket radius and **not** derived from the diff they validate. Each anchor
is a line REMOVED from an edited template by the closure's own template-edit commits
(`f3c7f700` = plan 239-05, `f11dfbe2` = plan 239-06; `git diff aa1372cb..HEAD -- priv/templates/`),
searched verbatim with `grep -nF` **only inside that template's own golden counterpart** — basename
match, with two documented renames: `core/login_html.ex` renders to
`…_web/controllers/session_html.ex`, and `core/sigra_auth.css` renders to
`priv/static/assets/sigra_auth.css`. An anchor that matches nothing in its counterpart contributes no
record, and no anchor can spill into a file its template does not render into.

**48 anchors → 43 `N:` records**, accounted for exactly:

| Anchor group (template) | Anchors | `N:` records | Note |
|---|---|---|---|
| `core/login_html.ex` | 3 | 2 | the `during UAT` line is a `T:` record, not an `N:` |
| `core/mfa_settings_live.ex` | 2 | 2 | `6 digits entered:` + the dispatch line |
| `core/sigra_auth.css` | 26 | 23 | 3 absorbed as `T:` records (`round-3`, `runs …`, `231-02`) |
| `organizations/live/invitation_accept_live.ex` | 1 | 1 | the `:mismatch` invariant sentence |
| `organizations/live/organization_members_live.ex` | 10 | 10 | `Generated by` wrap, `this section` pointer, `will replace the card body`, `only.` |
| `organizations/live/organizations_live/index.ex` | 2 | 2 | Branch B + the dangling `until then` |
| `organizations/organization_invitation.ex` | 3 | 3 | `Implements the full invitation flow` |
| `organizations/organization_invitation_email.ex` | 1 | 0 | **no golden counterpart** — the phishing parenthetical is not rendered into the golden tree, which is why 7 golden files drift, not 8 |
| **Total** | **48** | **43** | 4 absorbed as `T:`, 1 with no counterpart |

The generating command is written verbatim into the file's `#`-prefixed header line (round-1 shape,
V2 substituted for V1, `BASE=aa1372cb`), so the set is reproducible from the file alone.

### (d) The freeze is git-provable, not prose-provable

```
expected-set / classifier commit : 3c0aee2c8cc3c49f212523563fc3191342290836
re-bless commit                  : 265f71955de44078b2f49f364e836ab7c6b7c8c4
$ git merge-base --is-ancestor 3c0aee2c 265f7195   → exit 0   (and the two shas are distinct)
$ git show --name-only --format= 3c0aee2c
.planning/phases/239-…/239-comment-only-diff-check.sh
.planning/phases/239-…/239-golden-expected-2.txt
```

Exactly two paths; nothing under `test/fixtures/install_golden/` appears in the freeze commit. The
last commit to touch the golden fixture **before** the freeze was `38c9bd9a` (the round-1 re-bless),
so the set was generated against an unmodified, committed golden tree.

### (e) The one parameterized floor

```
-floor_files=30
+floor_files="${GOLDEN_MIN_FILES:-30}"
```

One changed line, and only that line (`git diff --stat` → `1 insertion(+), 1 deletion(-)`).
`GOLDEN_MIN_FILES` was set to **7** for round 2 — the exact count of distinct paths in
`239-golden-expected-2.txt`, so the floor stays a real non-vacuity floor rather than a disabled one.
Round 1's hardcoded 30 was calibrated to a 35-file diff; round 2's batch renders into 7 files.

**Unchanged, asserted by grep at the final HEAD:**

| Guard | Assertion |
|---|---|
| empty-diff-input guard | `grep -c 'refusing to report success'` → **4** (all four fail-closed messages present) |
| empty-expected-set guard | same count |
| `removed_lines` floor | `grep -c 'floor_removed="$expected_t_count"'` → **1** (literal unchanged) |
| add-only-hunk class | `nonconforming_addonly_hunks` still one of the three summed violation classes |

### (f) The precondition, recorded

`MIX_ENV=test mix sigra.fixture.rebless_golden --check` at the start of this plan exited **2** with
`DRIFT DETECTED:` on **7** golden files — the template edits from plans 239-05/239-06 had genuinely
not reached the fixture. A `--check` exit 0 here would have meant the template edits never reached
generated output, and the plan would have halted.

---

## CLOSURE-OUTCOME

Status: PASS — one re-bless commit, classifier RED then GREEN, `--check` exit 0, V2 clean on the
golden tree / a freshly generated app / the tarball's `priv/`, `mix ci` green with a recorded count,
and SC-5 re-proven.

### (a) Commit topology — stated plainly, not left for `git log` to reveal

**The phase now carries TWO re-bless commits:** the original `38c9bd9a` (plan 239-04) and
`265f7195` (this plan). The gap closure required a second batch of template edits, and a second
batch cannot reach the golden fixture without a second batched run. This is not a deviation being
argued for in a downstream ledger: **SC-3 (`.planning/ROADMAP.md`) and SURF-03
(`.planning/REQUIREMENTS.md`) are now amended, per D-26, to read "one batched re-bless per batch of
template edits"** — so the criterion a re-verifier applies at final HEAD is the criterion this
closure satisfies. Each re-bless individually retains every property SC-3 protects: one batched run,
confined to `test/fixtures/install_golden/`, diff proven comment-only by a classifier demonstrated
falsifiable first, alone in its own commit.

```
$ git log --format=%H aa1372cb..HEAD -- test/fixtures/install_golden | wc -l
1
$ git show --name-only --format= 265f7195 | grep -vc '^test/fixtures/install_golden/'
0            (7 paths listed, none outside the fixture directory)
```

### (b) Classifier RED — on a committed known-bad fixture, before any green was believed

`fixtures/239-golden-rebless2-code-change.diff` (committed as `fca05dfc`) is the captured re-bless-2
diff with exactly one removed line replaced by a real Elixir function head from the golden tree:

```
$ GOLDEN_MIN_FILES=7 239-comment-only-diff-check.sh fixtures/239-golden-rebless2-code-change.diff 239-golden-expected-2.txt
changed_lines=88
removed_lines=47
files=7
nonconforming=1
nonconforming_removed=1
nonconforming_files=0
nonconforming_addonly_hunks=0
removed_lines_floor=4
FAIL: 1 nonconforming line(s)/path(s)/hunk(s) found:
test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:-  def handle_event("open_remove_modal", %{"id" => id}, socket) do
exit 1
```

### (c) Classifier GREEN — on the real captured diff, same expected set, same floor

```
$ GOLDEN_MIN_FILES=7 239-comment-only-diff-check.sh <scratch>/rebless2.diff 239-golden-expected-2.txt
changed_lines=88
removed_lines=47
files=7
nonconforming=0
nonconforming_removed=0
nonconforming_files=0
nonconforming_addonly_hunks=0
removed_lines_floor=4
exit 0
```

`removed_lines=47` ≥ the `T:` record count (**4**) — the floor held rather than was bypassed — and
equals the expected set's total record count exactly. `files=7` ≥ `GOLDEN_MIN_FILES=7`.

**No `N:` record was added mid-task.** The expected set as committed in `3c0aee2c` classified the
real diff green on its first and only run; nothing was widened to admit a line.

### (d) `--check` after the commit

```
$ MIX_ENV=test mix sigra.fixture.rebless_golden --check
OK: fixture is up-to-date (check mode).
exit 0
```

**Measured departure from the plan's literal:** the plan (and this phase's earlier records) quote the
line as `OK: fixture is up-to-date (check mode.)` with the period inside the parenthesis. The task's
actual output is `OK: fixture is up-to-date (check mode).` — period outside
(`rebless_golden.ex`). Recorded as measured rather than rounded to the quoted form; a criterion
grepping the quoted string would return 0 and be unsatisfiable.

### (e) V2 on the golden tree — with its positive control

```
golden_tree_V2_occurrences   = 0        (was 4 before this re-bless)
golden_tree_defmodule_files  = 161      ← positive control: a clean tree, not an empty file list
golden_tree_planning_hits    = 0
STDOUT_V2_lines              = 0        (of 151 total lines — D-13's independent-drift hazard
                                         re-checked under the widened net, not assumed still nil)
```

### (f) A freshly generated app — the bytes an adopter actually receives

`TMP_APP_DIR=/tmp/sigra_239_08_app GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh` →
`SMOKE_EXIT=0` (phx.new 1.8.8 pin asserted by the script, `mix sigra.install`, `mix sigra.gen.oauth`,
compile `--warnings-as-errors`, 3 app tests green).

```
app_planning_occurrences = 0
app_defmodule_files      = 201     ← positive control on the same generated tree
app_V2_occurrences       = 10
app_V2_lines_excluding_SVG_path_geometry = 0
```

**The 10 is recorded, not rounded to 0.** All ten fire one alternation, `\b[0-9]{3}-[0-9]{2}\b`, on
SVG `path d=` float-coordinate pairs — `373-12`, `575-10`, `798-15`, `003-32`, `457-78`, `806-82`,
`851-48` — in three files: `oauth_html.ex:54` (the Facebook button, already dispositioned
`FALSE-POSITIVE` in § WIDENED-UNION-LEDGER) and two **stock Phoenix** files Sigra never authors or
touches, `page_html/home.html.heex` and `priv/static/images/logo.svg`. Excluding SVG geometry lines,
V2 returns **0**. The harmlessness of the 10 depends on that disposition; writing 0 would hide the
dependency.

**SC-1 coverage boundary, stated:** `install-smoke.sh` never runs `mix sigra.upgrade`, so the three
`priv/templates/sigra.upgrade/` templates are structurally unreachable by this vehicle. They are
covered by the tarball observation below, not by this one.

Scratch app removed after measurement (REPO-01): `/tmp/sigra_239_08_app` no longer exists.

### (g) The built tarball

`mix hex.build` → `sigra-1.5.0.tar`, unpacked to scratch.

```
tarball lib+priv  '\.planning/'  = 0          ← the in-scope claim
tarball priv      V2             = 2 occurrences, both SVG path geometry; non-SVG V2 lines = 0
tarball lib       V2             = 634 occurrences / 475 lines / 84 files
control: defmodule files in lib+priv          = 540
```

**Out-of-scope by design, enumerated rather than claimed absent:** `README.md` 3 V2 hits;
`CHANGELOG.md` 390; `docs/` 37 across 6 files — `docs/ga-evidence.md`,
`docs/launch/v1.0/announcement.md`, `docs/launch/v1.0/evidence.md`, `docs/uat-ci-coverage.md`,
`docs/nyquist-posture-matrix.md`, `docs/audit-semantics.md`; and 58 `.planning/` mentions across
`docs/` + `README.md` + `CHANGELOG.md`.

**Phase 241 SURF-04 ratchet baseline: tarball `lib/` carries 475 V2-matching lines across 84 files.**
Explicitly **not fixed here** — SURF-04 owns the monotonic-decrease ratchet, and Standing Constraint 5
forbids this phase from building a guard. Recorded so the ratchet has a measured starting point
rather than a guessed one.

REPO-01: `sigra-1.5.0.tar` deleted and the unpacked directory removed immediately;
`git status --porcelain` clean. Two gitignored tarballs from April 2026 (`sigra-0.1.0.tar`,
`sigra-0.2.0.tar`) predate this phase entirely and were left untouched rather than silently swept.

### (h) `MIX_ENV=test mix ci` — green, with the count

```
$ MIX_ENV=test mix ci          → exit 0
33 doctests, 3 properties, 2606 tests, 0 failures, 12 skipped (22 excluded)
65 tests, 0 failures (2599 excluded)        ← the test/example (--include example_app) leg
```

**First run recorded RED, and why it was not a finding.** The first `MIX_ENV=test mix ci` exited 2
with 6 failures, all in `Sigra.Audit.Forwarders.ThreadlineTest`
(`function Sigra.Audit.Forwarders.Threadline.attach/1 is undefined`). Diagnosis:
`lib/sigra/audit/forwarders/threadline.ex` wraps its entire `defmodule` in
`if Code.ensure_compiled(Threadline) == {:module, Threadline}`, and the stale local `_build` held a
sigra beam compiled while the `:threadline` dep was not yet present — the run's own log shows
`threadline` being fetched and compiled *after* sigra. `MIX_ENV=test mix deps.compile threadline
--force && mix compile --force` restored the module (`Code.ensure_loaded?/1` → `true`), and the
re-run is the green above. Zero source files changed between the two runs; this closure touches no
file under `lib/sigra/audit/`. Local `_build` staleness, not a regression.

Run at the final code HEAD (`9acc49da`). The only commit that follows it is this evidence file
itself, which `mix ci` does not compile or test.

### (i) SC-5, re-proven after the closure

```
$ git diff --name-only origin/main -- .github/                     → 0 lines (empty)
$ git diff origin/main -- .github/ | grep '^[+-].*name:'           → 0 lines (empty)
$ 237-security-comment-diff-check.sh <full closure diff aa1372cb..HEAD>
examined_removed_lines=136
exit 0
$ git diff --name-only origin/main -- .planning/phases/237-*/237-security-comment-diff-check.sh
(empty — the instrument was run, never edited; D-16 holds)
```

`examined_removed_lines=136` > 0, so the check was live across the whole closure diff rather than
vacuously passing on nothing. **The single structural survivor round 1 documented
(`core/auth.ex:530`'s `IN-03` tolerance gap) does not reappear here** — that removal belongs to the
round-1 sweep diff, and it is not inside `aa1372cb..HEAD`. The instrument limitation itself is
unchanged and remains filed as
`2026-09-17-security-comment-classifier-token-set-omits-half-the-union.md` for Phase 241's `p18`.

### (j) The SC-3 / SURF-03 amendment

```
$ sed -n '/^### Phase 239/,/^### Phase 240/p' .planning/ROADMAP.md \
    | grep -ic 'batched re-bless per batch of template edits'          → 1
$ grep -ic 'batched re-bless per batch of template edits' .planning/REQUIREMENTS.md   → 1
$ grep -n '\*\*SURF-03\*\*:' .planning/REQUIREMENTS.md                 → line 84 (exactly one)
$ grep -n 'batched re-bless per batch of template edits' .planning/REQUIREMENTS.md    → line 84
$ grep -c 'D-26' .planning/ROADMAP.md / .planning/REQUIREMENTS.md      → 1 / 1
```

Per-commit properties survived the amendment: SC-3 still reads `only comment lines` (1 match) and
still requires `separate commit` (1 match) inside the Phase 239 block, and SURF-03's mirror sentence
is byte-identical (`grep -c 'counterparts of edited templates are mirrored'` → 1). The amendment
commit `9acc49da` lists exactly `.planning/ROADMAP.md` and `.planning/REQUIREMENTS.md`.

The SURF-03 `edge_coverage_assumptions` tension — "SURF-03 said one sweep plus one batched re-bless,
and this closure adds a second re-bless commit" — is **resolved by this amendment**, not merely
recorded next to it. The edge probe itself remains unclassified, so the assumption stays surfaced;
what changed is that the re-interpretation it named is now the criterion's own text.

---

## HONEST-CLAIMS (extended by plan 239-08 — the four items below are additions, not restatements)

**1. The `install_golden_contract` Actions clause is STILL a ship-time deferral.** SC-3's remaining
clause asks for a green `install_golden_contract` GitHub Actions run. This closure pushes nothing, so
no Actions verdict exists to read, and none is claimed. What is established locally is
`MIX_ENV=test mix ci` exit 0 (count above) and `rebless_golden --check` exit 0. The Actions clause
closes at ship time, not here.

**2. The tarball `lib/` bookkeeping is measured and deferred, not fixed.** 475 V2-matching lines
across 84 files ship inside `lib/` in the `mix hex.build` tarball. That is Phase 241 SURF-04's
monotonic-decrease ratchet, and SURF-04 explicitly does not target zero for v1.48. Recorded here as
the ratchet's measured baseline. Relatedly, the adopter-facing fixes this phase landed reach adopters
only at the **next publish** — the published 1.5.0 on Hex still carries the pre-sweep bytes.

**3. `SURF-02` is marked `[x]` in `REQUIREMENTS.md` but does not hold at HEAD.** Plan 239-05 filed
`.planning/todos/pending/2026-09-17-surf-02-marked-complete-but-does-not-hold-at-head.md`. SURF-02
belongs to Phase 237, not to Phase 239; this plan neither fixed it nor silently unchecked it. It is
surfaced for the operator and left exactly as found.

**4. Both edge-probe rows remain unresolved, carried forward as flagged assumptions.**
*SURF-01* — the assumed edge is the dead-grep case; every zero in § CLOSURE-OUTCOME is paired with a
positive control on the same surface and the same invocation, and the adopter-facing claims are made
on generated and built bytes rather than on `priv/templates/`. Surfaced, not resolved.
*SURF-03* — the assumed edge is commit topology; the tension is now resolved by the D-26 amendment
(see § CLOSURE-OUTCOME (j)), but the edge probe itself still did not classify, so the assumption
stays surfaced.

**What this closure DOES establish, and the exact evidence:** SURF-01 — zero `.planning/` path
references in a freshly generated app's `lib/` + `priv/` (control: 201 `defmodule` files) and in the
`mix hex.build` tarball's `lib/` + `priv/` (control: 540 files), measured on generated and built
bytes, never on the source tree. SURF-03 — `priv/templates/` carries no undispositioned bookkeeping
under V2; the closure landed as one sweep commit plus one batched re-bless in separate commits, with
the `test/example/` counterparts of edited templates mirrored (plan 239-07), under the amended
criterion. Both are marked complete at this HEAD on that evidence and on nothing else.

---

## VOCABULARY-LEDGER

*(Written by gap-closure plan 239-09. Placed after `## WIDENED-UNION-LEDGER`, at the end of the
ledger, following this file's chronological convention — the same way plan 239-08 extended
`## HONEST-CLAIMS` by appending rather than by interleaving.)*

Status: **RED on all three tiers, as required.** V3 is defined, committed as a runnable phase
artifact, and demonstrated RED at this plan's HEAD before a single template byte is edited.
`hits_outside_allowlist` = **2 / 2 / 2** on `priv-templates` / `example` / `golden`, each with a
non-zero paired `control_defmodule`, and the two sentences named in `239-VERIFICATION.md`'s SC-1
`gaps:` block appear by `path:line:` in all three. The instrument is wired into nothing
(Standing Constraint 5, D-04).

### (a) V3, verbatim

V3 is V2 — copied mechanically out of § `WIDENED-UNION-LEDGER` (a), never retyped — plus one
appended vocabulary class. **Why V2 could not see the leak**, restated as a mechanism: V2 matches
plan *identifiers* (`D-12`, `239-05`, 10-digit run ids, `UAT`). The two residual sentences are plan
*vocabulary* — `The plan-checker greps this function body…` and `Flop / sortable columns are a v1.2
concern.` — and contain no identifier of any shape V2 knows. That is V1's blind spot one class up.

```
\.planning/|[Pp]hase[ -][0-9]+|\bD-[0-9]{2}\b|\bPlan [0-9]{2}\b|[0-9]{3}-[A-Z0-9-]+\.md|[0-9]{2}-CONTEXT\.md|SC-[0-9]|ORG-UX-[0-9]{2}|GATE-0[0-9]|UI-SPEC|DX-[0-9]{2}|IN-[0-9]{2}|T-[0-9]+-[0-9]+|\bB[0-9]\b|\b[0-9]{3}-[0-9]{2}\b|\b[Rr]ound[s]?[ -][0-9]|\b[Rr]uns? [0-9]{9,}|actions/runs/[0-9]+|\bUAT\b|\b[Ww]ave [0-9]|\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md
```

The eight appended alternations, isolated (the V2 -> V3 delta):

```
\b[Pp]lan[- ]checker\b|\bthis phase\b|\bthe plan\b|v[0-9]+\.[0-9]+ concern|\bgap[- ]closure\b|\bre-?bless\b|\bROADMAP\b|SUMMARY\.md
```

**Strictly-wider check — which check was used: substring containment.** V3 is constructed in
`239-v3-vocabulary-check.sh` as `V3="${V2}|${V3_VOCAB}"`, so every V2 alternation survives verbatim
by construction. The script does not take that on trust: it asserts it at runtime and fails closed
(exit 3, `refusing to report success on a definition that is not strictly wider`) if it ever stops
holding.

```bash
case "$V3" in *"$V2"*) echo "V2_IS_SUBSTRING_OF_V3" ;; *) echo "NOT_WIDER" ;; esac
# => V2_IS_SUBSTRING_OF_V3
```

### (b) Per-alternation live positive controls — every added alternation, a named surface, a non-zero count

A dead alternation produces a reassuring zero and is indistinguishable from a clean surface. Each
of the eight additions therefore carries its own control on a surface where it is known to fire.
All eight returned non-zero; **no alternation is dead, and none was dropped.**

| # | Alternation | Control surface | Count |
|---|---|---|---|
| 1 | `\b[Pp]lan[- ]checker\b` | `239-VERIFICATION.md` | **4** |
| 2 | `\bthis phase\b` | `239-CONTEXT.md` | **4** |
| 3 | `\bthe plan\b` | `239-09-PLAN.md` | **2** |
| 4 | `v[0-9]+\.[0-9]+ concern` | `239-VERIFICATION.md` | **3** |
| 5 | `\bgap[- ]closure\b` | `.planning/ROADMAP.md` | **4** |
| 6 | `\bre-?bless\b` | `.planning/ROADMAP.md` | **4** |
| 7 | `\bROADMAP\b` | `.planning/ROADMAP.md` | **13** |
| 8 | `SUMMARY\.md` | `.planning/ROADMAP.md` | **1** |

Command shape (phase paths abbreviated to `$P`; brace group + `|| true` so a zero is a value, not a
fatal status — SAFETY RULESET 3):

```bash
P=.planning/phases/239-priv-templates-sweep-one-batched-re-bless
{ grep -cE '\b[Pp]lan[- ]checker\b' "$P/239-VERIFICATION.md" || true; }   # => 4
{ grep -cE '\bthis phase\b'          "$P/239-CONTEXT.md"      || true; }   # => 4
{ grep -cE '\bthe plan\b'            "$P/239-09-PLAN.md"      || true; }   # => 2
{ grep -cE 'v[0-9]+\.[0-9]+ concern' "$P/239-VERIFICATION.md" || true; }   # => 3
{ grep -cE '\bgap[- ]closure\b'      .planning/ROADMAP.md     || true; }   # => 4
{ grep -cE '\bre-?bless\b'           .planning/ROADMAP.md     || true; }   # => 4
{ grep -cE '\bROADMAP\b'             .planning/ROADMAP.md     || true; }   # => 13
{ grep -cE 'SUMMARY\.md'             .planning/ROADMAP.md     || true; }   # => 1
```

### (c) Recall pass — keep/drop record, a reason on every row

Each candidate was grepped over `.planning/ROADMAP.md`, over `.planning/phases/` (is it live GSD
vocabulary at all?) and over the three tiers (what does it actually catch on shipped surface?). A
dropped candidate with no recorded reason would be a silent narrowing of the instrument, so every
row below carries its disposition explicitly — including the three that catch nothing on any
shipped tier today.

| Candidate | `.planning/phases/` | priv/templates | golden | test/example (whole tree) | Disposition |
|---|---|---|---|---|---|
| `\b[Pp]lan[- ]checker\b` | 21 | 1 | 1 | 1 | **KEEP** — this is the SC-1 gap's first sentence. Case-folded initial and the spaced variant both included because GSD prose uses both. |
| `\bthis phase\b` | 304 | 0 | 0 | 0 | **KEEP** — heavily live planning vocabulary (304 lines). Zero on every shipped tier today, which is exactly the state a guard should preserve: it is a tripwire for the next leak, not a finder of an existing one. Its control (b#2) proves it is not dead. |
| `\bthe plan\b` | 214 | 0 | 0 | 1 | **KEEP** — live vocabulary and already present once in the unswept `test/example/` remainder, so it is not hypothetical. Known false-positive risk on ordinary English ("the plan the user selected"); accepted, because triage is per-hit and the allowlist exists for precisely that case. |
| `v[0-9]+\.[0-9]+ concern` | 19 | 1 | 1 | 1 | **KEEP** — this is the SC-1 gap's second sentence. Deliberately anchored on the word `concern` rather than on `v1.2` alone: a bare version number is legitimate in adopter-facing prose, roadmap *sequencing* is not. |
| `\bgap[- ]closure\b` | 35 | 0 | 0 | 1 | **KEEP** — live in the ROADMAP (4) and already leaking once into the example remainder. |
| `\bre-?bless\b` | 614 | 0 | 0 | 0 | **KEEP** — the single most-used internal term in this phase (614 lines) and meaningless in an adopter project. Tripwire, same as `this phase`. |
| `\bROADMAP\b` | 235 | 0 | 0 | 0 | **KEEP** — uppercase-anchored so it cannot fire on the ordinary English word "roadmap" in adopter-facing marketing prose; `\bROADMAP\b` is the GSD artifact name. |
| `SUMMARY\.md` | 121 | 0 | 0 | 2 | **KEEP** — a GSD artifact filename; already leaking twice into the example remainder. |

**Dropped: none.** Every seeded candidate is live vocabulary with a non-zero control. Adding an
alternation is cheap (a per-hit triage row and, if genuinely a false positive, one allowlist entry);
dropping one silently re-creates V1's blind spot, which is the defect under repair.

**Recorded instrument limitation, not smoothed over.** V3 is still line-based and still
case-sensitive where GSD prose is not: review finding **IN-06**'s lowercase `post plan 04` matches
no V3 alternation (proof in § (j)). That is a *vocabulary class V3 still misses*, recorded here as
a direct input to Phase 241's `p18` spec rather than quietly absorbed.

### (d) Tier file lists — FIXED HERE, before the RED ran, consumed unchanged by plans 239-11/12/13

| Tier | File list | Files at this HEAD |
|---|---|---|
| `priv-templates` | `git ls-files priv/templates` | 119 |
| `example` | **scoped** — two literal paths, enumerated in the script, never a glob or a tree walk | 2 |
| `golden` | `git ls-files test/fixtures/install_golden/tree` | 84 |

The `example` tier's two paths:

```
test/example/lib/example_web/live/invitation_accept_live.ex
test/example/lib/example_web/live/organization_members_live.ex
```

**Why the `example` tier is scoped, in plain words.** SC-4 governs the mirror and says only the
`test/example/` counterparts of edited templates are mirrored. Those two files are the counterparts
plan 239-11 edits, so they are the whole of this phase's contract inside `test/example/`. Nothing
else in that tree is inside the contract. Sweeping it repo-wide measures 4.3x over the D-19/SC-4
scope (`239-RESEARCH.md` § 1.6), cannot fit plan 239-11's fixed two-file commit scope, and collides
with surfaces this milestone has not cleared. **The unswept remainder is therefore a measured,
named, routed number that this phase explicitly does not claim to clean — see § (i).** The script
enforces the scoping structurally: it contains no tree walk over that directory at all.

### (e) The allowlist, verbatim, with its per-entry reason and both controls

`239-v3-allowlist.tsv` — tab-separated, columns `path`, `literal`, `reason`. Exactly **one** record
at this HEAD, and it is dispositioned here **by name, at this plan's time**, not discovered later at
plan 239-11's time:

| path | literal (fragment) | reason |
|---|---|---|
| `priv/templates/sigra.gen.oauth/oauth_html.ex` | `M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0` | FALSE-POSITIVE — SVG path coordinates. |

The V2 alternation `\b[0-9]{3}-[0-9]{2}\b` fires on the numeric coordinate pair `373-12` inside the
Facebook-logo `<path d="…">` geometry at line 54. Confirmed by isolating the match:

```bash
grep -oE '\b[0-9]{3}-[0-9]{2}\b' priv/templates/sigra.gen.oauth/oauth_html.ex   # => 373-12 (x2)
```

It is not prose, is not bookkeeping, and is not editable without changing a brand mark's rendered
geometry. Already dispositioned FALSE-POSITIVE by plan 239-08's ledger and confirmed by
`239-VERIFICATION.md`; this entry is that disposition made machine-readable. The stored literal is
a fragment of the path geometry only — deliberately not the `fill=` attribute, because this repo is
public and brand hex values are not written into phase artifacts.

**Matching key.** A hit is suppressed only when its path equals the entry's `path` **and** its line
text contains the entry's `literal`. Never a line number (lines shift; the EEx header alone offsets
template line numbers by 2 against the golden tree), never a path alone (that would blanket a whole
file). Keying on (path, literal) is what stops an entry from silently starting to cover something
new.

**Per-entry non-vacuity control — scoped to the run that exercises it.** For every entry whose
`path` is in the file list being measured, the script asserts the literal is still found at that
path AND that the line still matches V3; a failure is fail-closed exit 3. The entry above is
exercised by the `priv-templates` run, where it passed (its hit is reported and marked
`[ALLOWLISTED]`, visible rather than removed). It is **not exercised** by the `example` or `golden`
runs, whose file lists do not contain that path — and that is correctly *not* a vacuity failure.
The scoping is mandatory, not a convenience: a tier-blind control demanding every entry be present
in every tier's file list would fail closed on two of three tiers before either could report a
result, and the RED demonstration this whole closure rests on could never have run.

**Companion union check — so no entry escapes its control everywhere.** Computed once over the
union of the three named tier file lists, independent of which tier is being measured:

| Entry path | In `priv-templates`? | In `example`? | In `golden`? | Exercised by ≥1 tier |
|---|---|---|---|---|
| `priv/templates/sigra.gen.oauth/oauth_html.ex` | **yes** | no | no | **PASS** |

An entry exercised by no tier is fail-closed exit 3. Both halves are demonstrated live in § (g),
not asserted.

### (f) The RED demonstration — all three tiers, at this plan's HEAD, in one pass

```bash
d=.planning/phases/239-priv-templates-sweep-one-batched-re-bless
for t in priv-templates example golden; do "$d/239-v3-vocabulary-check.sh" "$t"; echo "rc=$?"; done
```

| Tier | `hits` (raw) | `allowlisted` | `hits_outside_allowlist` | `control_defmodule` | files | exit |
|---|---|---|---|---|---|---|
| `priv-templates` | **3** | 1 | **2** | **98** | 119 | **1** |
| `example` (SC-4 counterparts) | **2** | 0 | **2** | **2** | 2 | **1** |
| `golden` | **2** | 0 | **2** | **78** | 84 | **1** |

Every tier is RED, every tier's paired positive control is alive, and the raw `hits=` total is
printed on every run alongside the criterion, so the allowlist never hides a number.

**The two SC-1 sentences, by `path:line:`, matched against `239-VERIFICATION.md`'s `gaps:` block
rather than by eye. Neither is allowlisted.**

| Tier | Sentence 1 (`The plan-checker greps this function body…`) | Sentence 2 (`…a v1.2 concern.`) |
|---|---|---|
| `priv-templates` | `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex:326` | `priv/templates/sigra.install/organizations/live/organization_members_live.ex:24` |
| `example` | `test/example/lib/example_web/live/invitation_accept_live.ex:332` | `test/example/lib/example_web/live/organization_members_live.ex:24` |
| `golden` | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:326` | `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex:24` |

The `gaps:` block names line 326 and line 24 for the template and golden tiers; both agree exactly.
The `example` counterpart sits at 332 rather than 326 (the example file carries six extra lines
ahead of it), which is why matching is keyed on (path, text) and never on a line number.

If V3 could not see these today, its zero tomorrow would mean nothing. That is the falsification
the whole closure rests on, and it is now on the record.

### (g) Fail-closed, demonstrated live rather than asserted

Exit **1** means *the surface is dirty*. Exit **3** means *the instrument cannot answer*. They are
deliberately distinct: if they shared a code, a broken script would be indistinguishable from a
demonstrated RED — the same failure shape this closure repairs everywhere else. Every consuming
verify in plans 239-11/12/13 treats exit 3 as a halt, never as a result.

| # | Case | Command | Result |
|---|---|---|---|
| 1 | usage error | `239-v3-vocabulary-check.sh` (no args) | exit **2**, usage line |
| 2 | empty file list | `239-v3-vocabulary-check.sh --files` | exit **3**, `FAIL: empty file list — refusing to report success on no input (fail-closed guard)` |
| 3 | vacuous allowlist entry, on the tier that exercises it | allowlist copied with its literal corrupted to `ZZZ-NOT-PRESENT-ZZZ…`, run against `priv-templates` | exit **3**, `FAIL: refusing to report success on a vacuous allowlist entry: priv/templates/sigra.gen.oauth/oauth_html.ex :: ZZZ-NOT-PRESENT-ZZZ…` |
| 4 | allowlist entry exercised by no tier | allowlist copied with its path changed to `priv/NOT/A/TIER/path.ex` | exit **3**, `FAIL: allowlist entry 'priv/NOT/A/TIER/path.ex' is exercised by none of the three named tiers — refusing to report success on an allowlist entry that escapes its own control (fail-closed guard)` |
| 5 | **scoping proof** — the same corrupted-literal copy as #3, run against the `example` tier, which does **not** exercise that entry | same copy, `example` tier | exit **1** (a real RED result, not a halt) — proving the control is scoped to the runs that exercise an entry, and does not fail closed on tiers that do not |

Cases 3, 4 and 5 use temporary copies under `/tmp`; **neither corrupted copy is committed**. The
committed `239-v3-allowlist.tsv` is the single-record file in § (e).

### (h) Per-hit triage — every V3 hit over the three scoped tiers, exactly one disposition

Seven hits, seven rows (3 + 2 + 2, matching § (f)). No row is deleted to reduce a count: the raw
total stays visible alongside the triaged one, always.

| # | Tier | `path:line` | Text | Disposition |
|---|---|---|---|---|
| 1 | priv-templates | `.../sigra.gen.oauth/oauth_html.ex:54` | SVG `<path d="…">` geometry | **FALSE-POSITIVE** — SVG coordinate pair `373-12`. Allowlisted (§ e). Survives the closure. |
| 2 | priv-templates | `.../organizations/live/invitation_accept_live.ex:326` | `# The plan-checker greps this function body and asserts zero matches.` | **BOOKKEEPING → plan 239-11 work list.** Sigra-internal GSD tooling; has no existence in an adopter's project (review finding WR-02). |
| 3 | priv-templates | `.../organizations/live/organization_members_live.ex:24` | `Flop / sortable columns are a v1.2 concern.` | **BOOKKEEPING → plan 239-11 work list.** Sigra's internal roadmap sequencing inside an adopter-owned moduledoc. |
| 4 | example | `test/example/lib/example_web/live/invitation_accept_live.ex:332` | same as #2 | **BOOKKEEPING → MIRRORS `invitation_accept_live.ex` (plan 239-11 mirror commit, SC-4).** |
| 5 | example | `test/example/lib/example_web/live/organization_members_live.ex:24` | same as #3 | **BOOKKEEPING → MIRRORS `organization_members_live.ex` (plan 239-11 mirror commit, SC-4).** |
| 6 | golden | `.../install_golden/tree/.../invitation_accept_live.ex:326` | same as #2 | **BOOKKEEPING → cleared by the batched re-bless (plan 239-12).** Generator output; never hand-edited (D-09). |
| 7 | golden | `.../install_golden/tree/.../organization_members_live.ex:24` | same as #3 | **BOOKKEEPING → cleared by the batched re-bless (plan 239-12).** |

Raw vs outside-allowlist, side by side: `priv-templates` 3 / 2 · `example` 2 / 2 · `golden` 2 / 2.

**Recall backstop — every hit was reviewed, not only the two known ones.** The `priv-templates` V3
pass reported **3** hits; all 3 are in the table above, and the third (#1) is the pre-existing SVG
false positive rather than a newly found leak. V3 found **no bookkeeping in `priv/templates/` beyond
the two sentences `239-VERIFICATION.md` already named** — reported as a measurement under a named,
versioned definition, not as "clean".

**Triage is bounded to the three scoped tiers, deliberately.** Row-by-row triage of the unswept
`test/example/` remainder is not in this plan's budget, cannot fit plan 239-11's fixed two-file
commit scope, and would collide with D-19's commit topology and SC-4's counterpart-only mirror
rule. It is handled as a measured, routed number instead — next section.

### (i) The unswept `test/example/` remainder — measured, named, routed, not dropped

```bash
REM=$(git ls-files test/example \
  | grep -vxF -e 'test/example/lib/example_web/live/invitation_accept_live.ex' \
              -e 'test/example/lib/example_web/live/organization_members_live.ex')
{ grep -HnE "$V3" $REM || true; } | grep -c '.'                      # => 482   lines
{ grep -HnE "$V3" $REM || true; } | cut -d: -f1 | sort -u | wc -l     # => 157   files
```

**Measured: 482 lines across 157 files, over 344 scanned files, at this plan's base.** V2 over the
same set returns 480, so the vocabulary class adds 2 there.

**This differs materially from the plan's expected order of magnitude (~392 lines across ~67 files)
and is reported rather than smoothed.** The difference is in both directions and is structural: the
line count is ~1.2x the estimate, but the *file* count is 2.3x it, and the heavyweights are not the
ones the plan anticipated. The top contributors measured are Playwright test tooling, not
application code:

| File | Lines |
|---|---|
| `test/example/priv/playwright/lib/eval/probes.ts` | 38 |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | 33 |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | 29 |
| `test/example/lib/example/demo/seeds.ex` | 18 |
| `test/example/priv/playwright/playwright.config.ts` | 17 |
| `test/example/priv/playwright/tests/admin-flow-org-admin.spec.ts` | 16 |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | 15 |
| `test/example/priv/playwright/tests/admin-flow-support-investigator.spec.ts` | 14 |
| `test/example/priv/playwright/tests/organizations.spec.ts` | 12 |
| `test/example/test/example_web/live/organization_members_live_test.exs` | 11 |

The plan predicted `seeds.ex`, `personas.ex`, `design_gallery_live.ex`, `config/*.exs` and
`README.md`; only `seeds.ex` appears in the measured top ten. The bulk sits in
`test/example/priv/playwright/` — test tooling that is **not** adopter-shipped, which is a
materially different (and lower-severity) surface than the estimate implied. That distinction is
itself useful to the Phase 241 owner and would have been lost by reporting the expected number.

Routed to `.planning/todos/pending/2026-09-18-test-example-remainder-outside-the-sc-4-counterpart-scope.md`,
owner **Phase 241 SURF-04**.

### (j) IN-06 — routed by finding, because V3 cannot measure it. Proven, not assumed.

Review finding **IN-06** is `test/example/priv/playwright/tests/golden-path.spec.ts:59`, a lowercase
plan reference inside a test-tooling comment (`// The login page is a plain controller (post plan
04). …`), example-only and not adopter-shipped.

```bash
239-v3-vocabulary-check.sh --files test/example/priv/playwright/tests/golden-path.spec.ts
# => hits=6 ; line 59 is NOT among them
{ grep -nE "$V3" test/example/priv/playwright/tests/golden-path.spec.ts || true; } | grep -c '^59:'
# => 0
```

V3 reports 6 hits in that file and **line 59 is not one of them**: `plan 04` is lowercase, so
neither V2's `\bPlan [0-9]{2}\b` identifier alternation nor any V3 vocabulary alternation fires on
it. A measurement-based routing would have missed this finding entirely. It is therefore named by
ID and `file:line` in the remainder todo, by hand — and, more importantly, recorded here as
**evidence of a vocabulary class V3 still misses**, which makes it a real input to Phase 241's `p18`
spec rather than a low-severity line to drop. IN-06 is the only review finding with no disposition
elsewhere in this closure (IN-01 … IN-04 are explicitly deferred in plan 239-11; IN-05 is filed by
plan 239-10), so without this record it would be invisible to `/gsd-execute-phase`.

*(The single-file invocation above exits **3**, not 1 — `control_defmodule=0` on a TypeScript file,
so the paired positive control is inapplicable and the instrument correctly refuses to report a
verdict. The hit list is still printed, which is what the line-59 measurement is read from. The
fail-closed guard behaving this way on an off-tier file list is the guard working, not a defect.)*

### (k) D-30 — the instrument's detection WIDTH and the criterion's asserted SURFACE are separate

**Statement.** V3 stays maximally wide and is never narrowed, tuned, or hand-fitted so that the
current tree happens to pass it. What the criterion in plans 239-11, 239-12 and 239-13 asserts is
`hits_outside_allowlist = 0` — never `hits = 0` — over a tier file list and a per-line triage
allowlist that were both committed *before* the RED demonstration ran, with the raw `hits=` total
printed alongside on every run. The `example` tier is asserted only over SC-4's mirrored-counterpart
surface; the unswept remainder of `test/example/` is a measured, named, routed number this phase
does not claim to clean.

**Rationale.** At this plan's base a literal `hits = 0` criterion is arithmetically unreachable: V2
alone returns **1** hit in `priv/templates/` (an SVG coordinate false positive that cannot be edited
without changing a brand mark's geometry) and **390** across `test/example/`; under V3 the example
remainder is **482**. A plan asserting `hits = 0` would either halt on its first verify or be
"resolved" under time pressure by hand-fitting V3 or bolting on an undocumented exclusion — which is
precisely the goalpost-move `T-239-09-02` exists to prevent. Separating width from asserted surface
keeps the instrument honest *and* the criterion reachable.

**Alternatives not taken.**
(a) *Narrow V3 until the tree passes* — rejected: it reinstates exactly the blind spot the widening
exists to remove, and it is the V1→V2 failure repeating a third time.
(b) *Sweep `test/example/` repo-wide* — rejected: 4.3x over the SC-4 scope (`239-RESEARCH.md`
§ 1.6), incompatible with plan 239-11's two-file commit scope and D-19's commit topology.
(c) *Silently drop the false positive from the reported count* — rejected: prohibited by this plan's
own prohibitions, and indistinguishable from the defect under repair. The hit is reported, marked
`[ALLOWLISTED]` inline, and counted in `hits=`.

**Reversibility:** costly. V3 is the instrument every later acceptance criterion in this closure is
measured against, and Phase 241's `p18` guard inherits it; reverting means re-deriving the
measurements in plans 239-11, 239-12 and 239-13. Mitigated by the keep/drop record in § (c), which
lets a later reader reconstruct the derivation rather than inherit it on trust.

**Implemented by plan 239-09.**

### (l) D-28 — the widening is implemented as a measurement instrument only; Phase 241 owns mechanization

**Statement.** This closure implements the widening as a *measurement instrument only*. V3 is
defined, demonstrated and recorded here as a phase artifact wired into nothing, and Phase 241's
SURF-04 `p18` guard inherits it as its spec. Standing Constraint 5 and D-04 both forbid building the
guard in Phase 239.

Proof that nothing is wired:

```bash
grep -rn '239-v3-vocabulary-check' mix.exs .github scripts/ 2>/dev/null | wc -l   # => 0
```

**Note.** Plan **239-10** is where SC-1's wording is amended to name the definition it is measured
under, so the criterion stops over-claiming — "clean" becomes "clean under V3", which is the only
form of the claim the evidence supports.

**Reversibility:** reversible (the artifact is deletable and referenced by nothing executable).

**Implemented by plan 239-09.**

## BATCH-JUSTIFICATION

**Obligation (D-29).** SC-3 and SURF-03 were amended by D-26 from "exactly **one** batched re-bless
for the phase" to "**one batched re-bless per batch of template edits**". That is unbounded where the
original was countable. D-29 bounds it without restoring a count: **every re-bless batch must be
justified by name in this section — which template edits compose the batch, and why they could not
have been folded into the previous batch — recorded *before* that batch's re-bless runs.** The count
stays auditable even though it is no longer fixed.

D-29 adds this obligation; it does **not** re-amend SC-3's or SURF-03's prose (see D-29 in
`239-CONTEXT.md`, including the recorded reading hazard around SURF-03's "second batch" rationale
clause).

### Batch 1 — the original sweep *(retrospective justification, derived from § `## SWEEP-COMMIT` and § `## REBLESS-COMMIT`)*

**Composition:** the 158 planning-bookkeeping lines stripped from 46 files under `priv/templates/`
(commit subject `refactor(239): strip planning bookkeeping from priv/templates (SURF-01, SURF-03)`),
plus the seven reflow-neighbour repairs in `2a34e1c8`, mirrored to their 30 `test/example/`
counterparts.

**Why not foldable into a previous batch:** there was no previous batch. This is the phase's first
batch of template edits and the origin of the D-19 three-commit topology.

### Batch 2 — the gap-closure template repairs *(retrospective justification, derived from § `## CLOSURE-TEMPLATE-COMMIT`, § `## CLOSURE-MIRROR-COMMIT` and § `## REFREEZE-LEDGER`)*

**Composition:** every `FIX-239-06` row from § `## WIDENED-UNION-LEDGER` plus the seven
`239-REVIEW.md` prose repairs in `priv/templates/`, mirrored to `test/example/` and re-blessed
against the round-2 expected-removed set frozen in § `## REFREEZE-LEDGER` (47 records: 4 `T:`,
43 `N:`, across 7 golden paths).

**Why not foldable into batch 1:** batch 1's edits were derived from the V1 union regex, which was
frozen at wave 0 and — as `239-VERIFICATION.md` records — is structurally incapable of matching the
bookkeeping batch 2 removes. The V2 widening and the `239-REVIEW.md` findings that produced batch 2's
edit list did not exist until after batch 1 had landed and been reviewed. Folding was not merely
inconvenient; the edits were **not yet derivable**.

### Batch 3 — the V3-vocabulary sweep and the WR-01 repair *(written by plan 239-12, BEFORE batch 3's re-bless ran)*

**Composition — the two template edits, named.** Batch 3 is the two-file sweep committed as
`7eee6b00` (`refactor(239): remove residual plan vocabulary and repair the false safety claim in
priv/templates (SURF-01, SURF-03)`), mirrored into `test/example/` by `8dc2ecc4`:

| Edit | Template file | What changed |
|---|---|---|
| WR-01 + WR-02 | `priv/templates/sigra.install/organizations/live/invitation_accept_live.ex` | The `@moduledoc` sentence `That absence is asserted by a test, not merely conventional` replaced with prose true in an adopter's project, and the comment line `# The plan-checker greps this function body and asserts zero matches.` deleted in full |
| WR-03 | `priv/templates/sigra.install/organizations/live/organization_members_live.ex` | The pagination bullet gains its terminator; `Flop / sortable columns are a v1.2 concern.` deleted |

Five removed template lines in total (`git diff 74e6a148..HEAD -- priv/templates/`), rendering into
**2** golden files.

**Why not foldable into batch 2.** Both edits were derived from findings that did not exist when
batch 2 was composed. WR-01 is a `239-REVIEW.md` finding and WR-02/WR-03 are the two sentences in
`239-VERIFICATION.md`'s SC-1 `gaps:` block — both documents were produced **after** batch 2's
re-bless commit `265f7195`, as the gap-closure review of the work batch 2 landed. Beyond the
chronology, batch 2's edit list was derived from the V2 definition, and V2 is an *identifier* regex
that is structurally incapable of matching either sentence: they carry no identifier of any shape V2
knows (§ `## VOCABULARY-LEDGER` (a) states the mechanism). Closing them required the V3 vocabulary
class, which plan 239-09 defined after batch 2 had landed. The edits were not merely inconvenient to
fold — under the definition in force at batch 2 they were **not detectable**, and therefore not
derivable.

**Running count of re-bless commits, with shas (D-29 auditability).** Before batch 3: **2**.

| Batch | Re-bless commit | Plan |
|---|---|---|
| 1 | `38c9bd9a` | 239-04 |
| 2 | `265f7195` | 239-07 (closure) |
| 3 | recorded in § `## REBLESS-COMMIT-3` — a commit cannot carry its own sha | 239-12 |

After batch 3 the phase carries **3** re-bless commits, one per batch, which is SC-3 as amended by
D-26 and bounded by D-29.


## BATCH-3-SWEEP-COMMIT

Status: PASS — the two residual bookkeeping sentences named in `239-VERIFICATION.md`'s SC-1 `gaps:`
block are gone from `priv/templates/`, `WR-01`'s false safety claim is replaced with prose that is
true in an adopter's project, `WR-03`'s unterminated bullet is repaired, and the two tiers this plan
owns report `hits_outside_allowlist=0` under the V3 definition that plan 239-09 demonstrated RED on
exactly these tiers. The instrument and its allowlist are byte-unchanged (D-30) — the green was
produced by editing the surface.

Sweep commit: **`7eee6b00`** (`priv/templates/` only). Mirror commit: recorded in
`239-11-SUMMARY.md` (a commit cannot carry its own sha).

### (a) The two edits, before and after — `invitation_accept_live.ex`

**WR-01 — `@moduledoc`, the `## Structural Jetstream #907 defense` section (`:19-20` at base).**

Before:

```
  "by construction, not by convention" defense. That absence is asserted by a
  test, not merely conventional — do not add accept controls to this branch.
```

After:

```
  "by construction, not by convention" defense — do not add accept controls to
  this branch. Sigra's own suite asserts this absence in the shipped template;
  `mix sigra.install` generates no tests, so if you customize this file, add an
  equivalent assertion to your own test suite.
```

**WR-02 / SC-1 gap item 1 — the comment block above `defp render_mismatch/1` (`:326` at base).**
Deleted in full, one line:

```
  # The plan-checker greps this function body and asserts zero matches.
```

**Surviving constraint line, quoted as the proof that the reason was not removed with the
bookkeeping** (the block as it stands at the sweep commit):

```
  # STRUCTURAL INVARIANT (Jetstream #907 / CVE-2026-1529):
  # This function MUST NOT contain any phx-click="accept..." or
  # phx-submit="accept..." or form action targeting an accept endpoint.
  # DO NOT add an accept button here even "for convenience" — the entire
  # point of this branch is that the accept action does not exist in the
  # rendered DOM for a mismatched visitor.
```

The `DO NOT add an accept button here` imperative and the `Jetstream #907 / CVE-2026-1529`
attribution both survive verbatim. What was deleted named an internal tool; what survives states the
constraint and why it exists.

### (b) The edit, before and after — `organization_members_live.ex`

**WR-03 / SC-1 gap item 2 — the `## Architecture` pagination bullet (`:23-24` at base).**

Before:

```
    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`
      Flop / sortable columns are a v1.2 concern.
```

After:

```
    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`.
```

Surviving constraint: the bullet still states the pagination mechanism (`LIMIT 100` + `Load more`
via `stream_insert(..., at: -1)`) in full. The deleted sentence stated only *when Sigra intends to
add Flop*, which is a Sigra release-sequencing fact and not a constraint on the adopter's code.

### (c) The two observations the WR-01 replacement rests on — re-run here, not cited

**Observation 1 — `T19`'s subject is the template path, never the adopter's copy.**

```bash
sed -n '570,600p' test/example/test/example_web/live/invitation_accept_live_test.exs
```

```elixir
    test "T19: mismatch_branch source has zero phx-click=\"accept...\" and zero phx-submit=\"accept...\"" do
      path =
        Path.join([
          File.cwd!(), "..", "..", "priv", "templates", "sigra.install",
          "organizations", "live", "invitation_accept_live.ex"
        ])
        |> Path.expand()
```

The subject is `priv/templates/.../invitation_accept_live.ex`. It is a Sigra-repo test over the
shipped template.

**Observation 2 — the generated app's whole `test/` tree contains zero `_test.exs` files.**

```bash
ls -R test/fixtures/install_golden/tree/test/
```

```
support
support/conn_case.ex
support/conn_case_helpers.ex
support/fixtures/auth_fixtures.ex
```

Three support modules, zero `_test.exs`. An adopter receives no test that asserts this invariant,
which is exactly what the replacement prose now says.

### (d) Named-string check — independent of every regex under examination

Run at the sweep commit on a clean tree. Every grep is `/usr/bin/grep` explicitly (the interactive
shell resolves `grep` to a `ugrep` wrapper), and the file list is fed via `git ls-files -z | xargs -0`
because this shell does **not** word-split an unquoted `$(git ls-files …)` — a first attempt that
relied on splitting produced `0`/`0` with a **dead control of 0**, i.e. a false negative caught only
because the control was paired. The numbers below are the re-run with a live control.

```bash
git ls-files priv/templates -z | xargs -0 /usr/bin/grep -lF 'defmodule'                      # control
git ls-files priv/templates -z | xargs -0 /usr/bin/grep -nF 'The plan-checker greps this function body and asserts zero matches.'
git ls-files priv/templates -z | xargs -0 /usr/bin/grep -nF 'Flop / sortable columns are a v1.2 concern.'
git ls-files priv/templates -z | xargs -0 /usr/bin/grep -lF 'DO NOT add an accept button here'   # second live control
```

| Measurement | Value | Reading |
|---|---|---|
| Sentence 1 (`The plan-checker greps …`) over `priv/templates/` | **0** | gone |
| Sentence 2 (`Flop / sortable columns are a v1.2 concern.`) over `priv/templates/` | **0** | gone |
| Control: files containing `defmodule` on the same file list | **97** | the grep is live |
| Control: files containing `DO NOT add an accept button here` | **1** | a string that *does* exist still matches — the zeros above are real negatives |

### (e) V3 tier result — the GREEN half of plan 239-09's RED/GREEN pair

```bash
.planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh priv-templates
```

```
tier=priv-templates
hits=1
allowlisted=1
hits_outside_allowlist=0
control_defmodule=98
files_measured=119
priv/templates/sigra.gen.oauth/oauth_html.ex:54: [ALLOWLISTED]  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 …
exit 0
```

| Tier | At plan 239-09 (RED) | At the sweep commit | Reading |
|---|---|---|---|
| `priv-templates` | `hits=3 allowlisted=1 hits_outside_allowlist=2` exit 1 | `hits=1 allowlisted=1 hits_outside_allowlist=0` exit 0 | **RED → GREEN** |

The raw `hits=1` is reported, not rounded away: it is the allowlisted SVG-coordinate false positive
in `sigra.gen.oauth/oauth_html.ex:54`, dispositioned by name in § `## VOCABULARY-LEDGER`. The
criterion is `hits_outside_allowlist=0`, and the raw total is what keeps the allowlist honest.

`control_defmodule=98` is non-zero, so the zero is a measurement and not an empty file list. Exit `3`
(the instrument cannot answer) was never returned at any point in this plan.

### (f) The instrument and the allowlist are byte-unchanged (D-30)

```bash
git diff --name-only 74e6a148..HEAD -- \
  .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-vocabulary-check.sh \
  .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-v3-allowlist.tsv
```

Empty across both of this plan's commits. Neither file appears in `git status --short` at any point.
No allowlist row was added: the tier went green because two sentences were deleted from the surface.

### (g) Region-extraction criteria — asserted non-empty before being trusted

The `sed` range is anchored on `^  ## Structural Jetstream #907 defense$` (one space after `##`, as
it exists in the file) through `^  ## Route$`, and its length is asserted before any grep over it.

| Check | Value |
|---|---|
| `region_lines` (length assertion, must be ≥ 5) | **11** |
| flattened region contains `generates no tests` | **1** |
| flattened region contains `your own test suite` | **1** |
| flattened region contains `asserted by a test` | **0** |
| flattened region contains `merely conventional` | **0** |
| flattened region contains `do not add accept controls to this branch` | **1** |

The two `0` rows are run over the region flattened with `tr '\n' ' ' | tr -s ' '`, because the false
claim spanned a line break and a single-line grep could not have expressed its absence. The
imperative survives the rewrite; only the false enforcement claim was removed.

`organization_members_live.ex`: the `@moduledoc` line containing `stream_insert` now ends in `.` —
`sed -n '1,35p' … | /usr/bin/grep -n 'stream_insert' | /usr/bin/grep -c '\.$'` → **1**.

### (h) No executable line moved — every changed line classified

`git show HEAD -- priv/templates` yields nine `+`/`-` content lines, classified individually:

| Line | Classification |
|---|---|
| `-  "by construction, not by convention" defense. That absence is asserted by a` | inside `@moduledoc """` heredoc |
| `-  test, not merely conventional — do not add accept controls to this branch.` | inside `@moduledoc """` heredoc |
| `+  "by construction, not by convention" defense — do not add accept controls to` | inside `@moduledoc """` heredoc |
| `+  this branch. Sigra's own suite asserts this absence in the shipped template;` | inside `@moduledoc """` heredoc |
| ``+  `mix sigra.install` generates no tests, so if you customize this file, add an`` | inside `@moduledoc """` heredoc |
| `+  equivalent assertion to your own test suite.` | inside `@moduledoc """` heredoc |
| `-  # The plan-checker greps this function body and asserts zero matches.` | `#` comment (after leading whitespace) |
| ``-    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)` `` | inside `@moduledoc """` heredoc |
| `-      Flop / sortable columns are a v1.2 concern.` | inside `@moduledoc """` heredoc |
| ``+    * Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`.`` | inside `@moduledoc """` heredoc |

No function head, guard, pattern, pipeline, route, plug, `attr` name, or `default:` appears in the
diff. `defp render_mismatch(assigns) do` and its `~H` body are byte-unchanged.

### (i) Formatter — the plan's check was inapplicable by construction; the repo's contract was run instead

`mix format --check-formatted priv/templates/.../organization_members_live.ex` **cannot** pass on a
template file and never could: templates carry EEx placeholders in Elixir syntax positions and are
not parseable Elixir.

```
** (SyntaxError) invalid syntax found on …/organization_members_live.ex:1:13:
  1 │ defmodule <%= web_module %>.OrganizationMembersLive do
```

`.formatter.exs` accordingly does **not** list `priv/templates` in its `inputs:` — the exclusion is
deliberate and pre-dates this phase. The meaningful check is the one `mix ci` actually runs, over the
repo's configured inputs:

```bash
mix format --check-formatted        # exit 0
```

Exit `0` at the sweep commit. Recorded as a deviation rather than silently substituted.

### (j) SC-5 security-comment classifier (D-16 — run, never edited)

```bash
git diff -- priv/templates > <scratch>/239-11-sweep.diff
.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh <scratch>/239-11-sweep.diff
```

```
examined_removed_lines=5
exit 0
```

Over the **combined** sweep+mirror diff (`git diff HEAD~1` at the mirror commit): `examined_removed_lines=10`, exit `0`. The script file is byte-unchanged — it does not appear in
`git status --short` or in either commit's `--name-only`.

### (k) Commit scope

```bash
git show --name-only --format= 7eee6b00
```

```
priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
priv/templates/sigra.install/organizations/live/organization_members_live.ex
```

Exactly two paths. Nothing under `test/`, `lib/`, `.github/`, or `.planning/`.
`git diff --name-only 74e6a148..7eee6b00 -- test/fixtures/install_golden/ .github/` is empty.

### (l) Mirror — `test/example/`, the second commit (D-19)

The same two edits applied to the two SC-4 counterparts, located by **reading the files**, not by
copying line numbers: after the four-line `@moduledoc` replacement the `plan-checker` line sat at
`:334` in the example tier (it was at `:332` before the replacement, and at `:326` in the template) —
a line number copied across tiers would have deleted the wrong line.

**Post-substitution tier equality, asserted per changed region rather than claimed.** The template
side is passed through `sed -e 's/<%= web_module %>/ExampleWeb/g' -e 's/<%= app_module %>/Example/g'`
and diffed against the same region in the example copy:

| Region | Command | Result |
|---|---|---|
| `## Structural Jetstream #907 defense` → `## Route` | `diff <(sed -n '/^  ## Structural Jetstream #907 defense$/,/^  ## Route$/p' <tmpl> \| sub) <(sed -n '…' <ex>)` | **empty** |
| `# STRUCTURAL INVARIANT (Jetstream #907` → `defp render_mismatch` | same shape | **empty** |
| the changed pagination bullet | `diff <(grep -n stream_insert <tmpl> \| cut -d: -f2-) <(… <ex>)` | **empty** |

One residual difference exists in the *wider* `## Architecture` block — `class="modal"` (template)
vs `class="vt-modal"` (example) — and it is **pre-existing, not introduced here**: the identical
one-line diff is reproduced at the plan's base commit `74e6a148` with
`diff <(git show "74e6a148:<tmpl>" | sed -n '/^  ## Architecture$/,/^  ## Pending invitations seam$/p' | sub) <(git show "74e6a148:<ex>" | sed -n '…')`.
It is the demo app's `vt-*` brand-class drift, outside every region this batch changed. Recorded
rather than reconciled; this plan changes no CSS class.

**Fixed-string check over the WHOLE of `test/example/`** — a different and wider claim than the V3
criterion below, deliberately not conflated with it:

| Measurement | Value |
|---|---|
| Sentence 1 over `git ls-files test/example` | **0** |
| Sentence 2 over `git ls-files test/example` | **0** |
| Control: files containing `defmodule` on the same list | **156** |
| Control: files containing `DO NOT add an accept button here` | **1** |
| `grep -cF 'generates no tests' <example invitation file>` | **1** |
| `grep -cF 'DO NOT add an accept button here' <example invitation file>` | **1** |
| `grep -cF 'Jetstream #907 / CVE-2026-1529' <example invitation file>` | **1** |

**V3 `example` tier — SCOPED, and the scope is restated so the zero cannot be misread:**

```
tier=example
hits=0
allowlisted=0
hits_outside_allowlist=0
control_defmodule=2
files_measured=2
exit 0
```

`files_measured=2`. This is the two SC-4 counterparts fixed in plan 239-09's tier list — **not**
`git ls-files test/example`. The unswept remainder of `test/example/` was measured by plan 239-09 at
**482 lines across 157 files** (mostly `priv/playwright/` tooling) and is routed to **Phase 241
SURF-04**. This zero says nothing about that remainder.

**Golden tier — still RED, which is the expected state:**

```
tier=golden
hits=2  allowlisted=0  hits_outside_allowlist=2  control_defmodule=78  files_measured=84
test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:326:   # The plan-checker greps this function body and asserts zero matches.
test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex:24:       Flop / sortable columns are a v1.2 concern.
exit 1
```

The golden tier is stale by **exactly this batch** — the two hits are the two sentences this plan
removed from the other two tiers, and nothing else. Plan 239-12's single re-bless closes it (D-09).
A golden `hits_outside_allowlist=0` here would have meant the fixture was hand-edited; it was not,
and `git diff --name-only 74e6a148..HEAD -- test/fixtures/` is empty across both commits.

**Three-tier state at the mirror commit:** template **==** example, golden stale by batch 3. That is
precisely the state plan 239-12 expects to find.

`mix format --check-formatted` on both edited example files: exit **0** (these *are* in
`.formatter.exs` `inputs:`, unlike the templates).

**Router re-derivation (not inherited).** `test/example/lib/example_web/router.ex` was re-read at
both flagged sites because a prior plan's enumeration missed `:175`:

| Site | Text | Disposition |
|---|---|---|
| `:103` | `# Login page is a plain controller, not a LiveView.` | **n/a — carries no batch-3 text.** Mechanism-only comment, no plan vocabulary, no V3 hit. Not edited. |
| `:175-179` | `# Dev-only routes for local manual testing — Swoosh local-mailbox preview at /dev/mailbox …` | **n/a — carries no batch-3 text.** Already de-bookkept by plan 239-07 (see § `## MIRROR-CHECKLIST` C-1). No V3 hit at the mirror commit. Not edited. |

Neither site is in this batch's edit set, and the router does not appear in either commit.


## REFREEZE-LEDGER-3

*(Written by plan 239-12, extending § `## REFREEZE-LEDGER` rather than interleaving with it —
this file's append-only chronological convention. Rounds 1 and 2 live in that section; round 3
lives here.)*

Status: PASS — the round-3 expected-removed set is frozen, committed **before** batch 3's re-bless,
and the ordering is readable from `git log` rather than taken on trust.

### (a) Why a third expected set is required

Round 2's set (`239-golden-expected-2.txt`, 47 records across 7 paths) was generated against the
golden tree as it stood before re-bless `265f7195`, and every one of its 47 records names a line that
re-bless removed. Those lines no longer exist in the tree, so round 2's set cannot contain round 3's
removals: reusing it would fail containment on every line of the new diff while simultaneously
failing its own `removed_lines >= 4` `T:` floor against a 5-line diff drawn from different files. A
third set is the only non-circular option, exactly as it was at round 2.

### (b) Counts

| Record class | Count |
|---|---|
| `T:` (golden-tree lines matched by V3 at the pre-re-bless HEAD) | **2** |
| `N:` (prose repairs V3 cannot match, located by literal anchor) | **3** |
| Total records | **5** |
| Distinct golden paths across all records | **2** |

The 2 `T:` records are the two sentences named in `239-VERIFICATION.md`'s SC-1 `gaps:` block — the
`plan-checker` comment line and the `v1.2 concern` release-sequencing sentence. They are the same 2
hits the V3 instrument reports as `hits_outside_allowlist=2` on the `golden` tier at this plan's
base, which is why that tier was the one tier still RED after plan 239-11.

### (c) The literal-anchor list — 5 anchors, 5 records, accounted for exactly

The anchors are **not** a blanket radius and **not** derived from the diff they validate. Each anchor
is a line REMOVED from an edited template by batch 3's own template-edit commit `7eee6b00`
(`git diff 74e6a148..HEAD -- priv/templates/`), searched verbatim with `grep -nF` **only inside that
template's own golden counterpart** (basename match; neither of batch 3's two files is one of the two
documented renames). An anchor matching nothing in its counterpart contributes no record.

| # | Anchor (template line removed by `7eee6b00`) | Template | Record class |
|---|---|---|---|
| 1 | `"by construction, not by convention" defense. That absence is asserted by a` | `organizations/live/invitation_accept_live.ex` | `N:` |
| 2 | `test, not merely conventional — do not add accept controls to this branch.` | `organizations/live/invitation_accept_live.ex` | `N:` |
| 3 | `# The plan-checker greps this function body and asserts zero matches.` | `organizations/live/invitation_accept_live.ex` | absorbed as `T:` (V3 matches it) |
| 4 | ``* Pagination is `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)` `` | `organizations/live/organization_members_live.ex` | `N:` |
| 5 | `Flop / sortable columns are a v1.2 concern.` | `organizations/live/organization_members_live.ex` | absorbed as `T:` (V3 matches it) |

**5 anchors → 3 `N:` + 2 absorbed `T:` = 5 records.** No anchor is unaccounted for and no record
lacks an anchor. The generating command is written verbatim into the file's `#`-prefixed header line
(round-2 shape with V3 substituted for V2 and `BASE=74e6a148`), so the set is reproducible from the
file alone.

### (d) The freeze is git-provable, not prose-provable

The freeze commit's own sha and the re-bless sha cannot be written by the commits they name (a commit
cannot carry its own sha, and the re-bless commit is path-scoped to `test/fixtures/install_golden/`
and may carry nothing else). Both are recorded, with their `git merge-base --is-ancestor` result, in
§ `## REBLESS-COMMIT-3` below, written in this plan's final documentation commit.

What is asserted here and checkable at any later HEAD: the freeze commit lists exactly three paths —
`239-golden-expected-3.txt`, `fixtures/239-golden-rebless3-code-change.diff`, `239-EVIDENCE.md` — and
nothing under `test/fixtures/install_golden/`.

### (e) The floor: two different runs, two different jobs

`GOLDEN_MIN_FILES` for round 3's **real** run is **2** — the exact count of distinct paths in
`239-golden-expected-3.txt`. That is a real non-vacuity floor equal to the expected path count, not a
disabled one. Batch 3 renders into 2 files, so round 1's hardcoded default of 30 (calibrated to a
35-file diff) and round 2's 7 would both fail spuriously.

The RED demonstration in (g) below deliberately runs with `GOLDEN_MIN_FILES=1`, and the two numbers
are not a contradiction:

| Run | Input | Floor | Why that floor |
|---|---|---|---|
| RED demonstration | `fixtures/239-golden-rebless3-code-change.diff` — a known-bad fixture built from the real diff shape with exactly one **code** line substituted | `1` | The fixture must fail on the altered code line, not on a file-count floor. Failing on the floor would prove nothing about the classifier's ability to detect a code line, which is the only thing this run measures. |
| Real classification (Task 2) | the captured re-bless-3 working-tree diff | `2` (computed) | This is the run the floor exists to protect — a thin real diff waved through by a vacuous pass. The floor is **applied**, not disabled, on the run the acceptance criteria gate on. |

The classifier itself is byte-unchanged in this round: `GOLDEN_MIN_FILES` was already parameterized by
plan 239-08, and `git diff --name-only` for `239-comment-only-diff-check.sh` across this plan is
empty.

### (f) The precondition, recorded

`MIX_ENV=test mix sigra.fixture.rebless_golden --check` at the start of this plan exited **2**:

```
==> sigra.fixture.rebless_golden: scaffolding fresh tmp app via InstallFixture
DRIFT DETECTED:
Files test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex and …/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex differ
Files test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex and …/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex differ
```

Exactly the 2 files batch 3 edits, and no others. A `--check` exit 0 here would have meant the
template edits never reached generated output (or the fixture was hand-edited) and the plan would
have halted.

### (g) The classifier proven able to fail, before any of its greens are believed

**RED — one code line altered in a real-shaped diff:**

```bash
GOLDEN_MIN_FILES=1 ./239-comment-only-diff-check.sh \
  fixtures/239-golden-rebless3-code-change.diff 239-golden-expected-3.txt
```

```
changed_lines=10
removed_lines=5
files=2
nonconforming=1
nonconforming_removed=1
nonconforming_files=0
nonconforming_addonly_hunks=0
removed_lines_floor=2
FAIL: 1 nonconforming line(s)/path(s)/hunk(s) found:
test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex:-  defp render_mismatch(assigns) do
```

**exit 1**, and the output names the offending line. The known-bad fixture differs from the real
captured diff by exactly one line (`diff` of the two files → `22c22`): the removed comment
`#  The plan-checker greps this function body…` replaced by the removed code line
`defp render_mismatch(assigns) do`.

**Fail-closed on empty input, demonstrated live rather than cited:**

```bash
printf '' | GOLDEN_MIN_FILES=1 ./239-comment-only-diff-check.sh - 239-golden-expected-3.txt
FAIL: empty diff input — refusing to report success on no input (fail-closed guard)
```

**exit 1**.

**Guards still present at this plan's HEAD:**

| Guard | Assertion |
|---|---|
| all four fail-closed messages | `grep -c 'refusing to report success'` → **4** |
| `removed_lines` floor | `grep -c 'floor_removed="$expected_t_count"'` → **1** (literal unchanged) |
| add-only-hunk class | `nonconforming_addonly_hunks` still one of the three summed violation classes |

### (h) A dead-grep caught by its own control, in this plan

The first attempt at the round-3 generator was pasted from round 2's **header line**, which carries an
inline `#` comment between `BASE=…` and `V3=…`. Executed as a command, that `#` comments out the rest
of the line and the generator produced **zero** records — indistinguishable from "the golden tree is
already clean". The paired positive control (`grep -cE '\bdefmodule\b'` over the same 84-file list →
non-zero on the `.ex` files) is what exposed it. This is the `unclassified` edge-probe's dead-grep
case firing for real, for the second time in this phase, and the reason every zero here is paired
with a control on the same surface.
