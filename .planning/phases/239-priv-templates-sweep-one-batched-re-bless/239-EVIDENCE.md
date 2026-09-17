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
