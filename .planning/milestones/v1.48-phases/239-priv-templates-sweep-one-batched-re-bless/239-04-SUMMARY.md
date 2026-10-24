---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 04
subsystem: testing
tags: [install-golden, re-bless, sc-1, sc-2, sc-3, sc-5b, elixir]

requires:
  - phase: 239-03
    provides: "test/example/ mirrored for the 30 counterparts of edited templates (mirror commit e69f4d9b); mix ci run #1 green"
provides:
  - "Commit 3 of the D-19 three-commit topology: the single batched re-bless (38c9bd9a), 35 paths, every one under test/fixtures/install_golden/"
  - "SC-3 classifier green on the re-bless diff from the frozen pre-sweep baseline: nonconforming=0, removed_lines=140 (floor 139), files=35, changed_lines=258"
  - "SC-1 generated-app evidence: 0 .planning/ hits and 0 union-token hits under a freshly installed app's lib/ and priv/, with a live positive control"
  - "SC-2 tarball evidence: 0 .planning/ hits under the built tarball's lib/ and priv/; the 32 out-of-scope hits enumerated rather than claimed absent"
  - "239-EVIDENCE.md ## MIX-CI-RUNS (run #2) and ## HONEST-CLAIMS sections, including SC-5b recorded RED with its diagnosis and a positive control"
  - "Three todos filed with diagnoses attached, none fixed in-phase"
affects: []

actuals:
  tasks: 3
  commits: 4
plan_head_before: a757d517

tech-stack:
  added: []
  patterns:
    - "Byte-preserving a locked neighbour can break the sentence it preserves: in a merge site only the token-bearing line is editable, so when that line also carries the sentence structure, a neighbour-preserving rewrite silently degrades prose. Read the resulting paragraph, do not just count nonconforming lines."
    - "A comment sweep can regress a test: capitalising a word at a new sentence start put a literal `Organization` into Sigra.Install.Features.Core's source and broke the Pitfall X-1 isolation invariant. mix ci caught it; inspection had not."
    - "mix ci poisons its own next run: the alias ends with sigra.dep_off, leaving _build compiled without optional deps, so the following cold invocation fails every Code.ensure_compiled/1-guarded module. Force-compile as a control before citing any mix ci result."
    - "A gate can be RED for a reason that is not a finding: record the diagnosis and a positive control rather than arguing it green or widening the instrument."

key-files:
  - test/fixtures/install_golden/tree/
  - lib/sigra/install/features/core.ex
  - priv/templates/sigra.install/core/sigra_auth.css
  - priv/templates/sigra.install/organizations/live/organization_members_live.ex
  - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md
---

## Accomplishments

Commit 3 of the D-19 three-commit topology landed. The install golden fixture is re-blessed from
the swept templates in a single commit whose diff is entirely under `test/fixtures/install_golden/`,
and the SC-3 classifier passes on the success path with every non-vacuity floor cleared.

Two repair commits landed ahead of it, both of which exist because wave 4's first attempt fixed the
classifier at the cost of the prose.

### The re-bless

`MIX_ENV=test mix sigra.fixture.rebless_golden` regenerates the tree; the executor stages and
commits by path (D-11 — the task itself does not stage). Against the frozen pre-sweep baseline
`a1bb08c6`, `239-comment-only-diff-check.sh` reports:

```
changed_lines=258 removed_lines=140 files=35 nonconforming=0
nonconforming_removed=0 nonconforming_files=0 nonconforming_addonly_hunks=0
removed_lines_floor=139
```

Exit 0. `git show --name-only` at the commit lists **35 paths, 0 of them outside**
`test/fixtures/install_golden/`, and `git log --oneline origin/main..HEAD --
test/fixtures/install_golden` returns exactly one line — SC-3's single-commit requirement holds.
`STDOUT.txt` is byte-unchanged against the baseline, so the D-13 independent-drift hazard stayed
measured-nil. `MIX_ENV=test mix sigra.fixture.rebless_golden --check` prints the literal
`OK: fixture is up-to-date (check mode).` and exits 0.

### The repairs, and why they were needed

`2a34e1c8` resolved the first run's 7 nonconforming neighbour lines correctly in *mechanism* —
plan 04 Safety Rule 1 explicitly sanctions editing templates and re-running, and every locked
neighbour line stayed byte-identical to its pre-sweep text. But in a merge site the only editable
line is the token-bearing one, and where that line also carried the sentence structure, preserving
the neighbours left the sentence broken. Four sites survived intact; two did not.

`061c1758` repairs the two prose breaks:

- `core/sigra_auth.css:698` — `do not re-litigate this;` had been left dangling in front of the
  untouched `and the reflow failure payload ... that proves it.` It now reads `... this comment
  records the verified mechanism`, which closes the sentence without reintroducing the removed
  `231-GAP-GATE02-SUMMARY.md` reference and without inventing a referent that does not exist.
- `organizations/live/organization_members_live.ex:24` — removing the `(D-22).` fragment removed
  the sentence terminator with it, running the pagination note into the Flop sentence. The line now
  opens `only.` Mirrored into `test/example` (SC-4).

`e4e03980` repairs two more in `lib/sigra/install/features/core.ex`, one of which was a live
regression rather than a cosmetic one:

- `:479` — `6fa3ead2` rewrote `# Phase 14 Plan 03: organization-aware pipelines` as
  `# Organization-aware pipelines`. Capitalising the word at sentence start put a literal
  `Organization` into the module's own source, which breaks the Pitfall X-1 isolation invariant at
  `test/sigra/install/features/core_test.exs:309` (it refutes `~r/\bOrganization\b/` against
  `core.ex`). Now `# Opt-in organization-aware pipelines.` — same meaning, no capitalised
  occurrence. `core_test.exs`: 29 tests, 0 failures.
- `:482` — `Phase 16 wires these to` had become the subjectless `Wires these to`, running into the
  untouched `# the organization picker + switcher.` Now `These wire into`.

Every repaired line is itself a token-bearing line from the frozen expected set, so removed-line
containment is unchanged; the fourth and final re-bless run produced byte-identical counters to the
third. Neither repair commit touches any path under `test/fixtures/install_golden/`, so Safety
Rule 1 is preserved.

### Live external observations

**SC-1** — `scripts/ci/install-smoke.sh` scaffolded a fresh phx.new 1.8.8 app and ran
`mix sigra.install` to completion. On the generated tree, never the source tree:
`SC1_planning_hits=0`, `SC1_union_token_hits=0`, `SC1_positive_control_defmodule_lines=78`. The
script's later `mix ecto.migrate` leg failed for an environmental reason — it is documented as
requiring Postgres on `localhost:5432` while this machine runs the test database on a dynamic port
— and the grep is taken before that leg and does not depend on it.

**SC-2** — `mix hex.build`, unpacked in a scratch directory. In scope: 0 `.planning/` hits under
`lib/` and `priv/`, positive control 161 greppable files. Out of scope by design and enumerated:
`docs/` 12, `README.md` 1, `CHANGELOG.md` 19, `mix.exs` 0 — 32 total, matching the plan's
prediction. No `sigra-*.tar` or `sigra-*/` is left in the repo (Safety Rule 8, verified after).

## Gates

| Gate | Result |
|---|---|
| `239-comment-only-diff-check.sh` on the re-bless diff | `nonconforming=0`, exit 0 |
| `mix sigra.fixture.rebless_golden --check` | `OK: fixture is up-to-date (check mode).`, exit 0 |
| `MIX_ENV=test mix ci` (warm build) | exit 0, 2606 tests, 0 failures |
| `MIX_ENV=test mix ci.install_golden` (standalone) | 19 tests, 0 failures (3 excluded) |
| `.github/` untouched | 0 paths, 0 changed `name:` lines |
| `237-security-comment-diff-check.sh` (SC-5b) | **RED** — diagnosed below |

## Issues Encountered

**`mix ci` poisons its own next run.** The alias ends with `sigra.dep_off`, which recompiles
without optional deps and leaves `_build` in that state. The next cold invocation then fails every
`Code.ensure_compiled/1`-guarded module: 6 failures in `Sigra.Audit.Forwarders.ThreadlineTest`, and
in one run a 7th in `Sigra.DeliveryTest` (Oban is also optional, so `deliver_async/3` takes a
different branch). Control: `mix compile --force` then `mix test --exclude scaffold` → exit 0,
2606 tests, 0 failures. Both families are ordering artifacts, not regressions. Positive control
that the delivery failure is not this phase's doing: `git log ebc5d9e1^..HEAD --
lib/sigra/delivery.ex test/sigra/delivery_test.exs` returns nothing, while the same query against
`lib/sigra/install/features/core.ex` returns `6fa3ead2` — so the query was live.

**SC-5b is RED, and it is a classifier scope mismatch rather than a lost rationale.** The script
flags one line in three mirrored locations: the sweep removed the citation `(10.1 IN-03)` from
`# token clause so security signals are preserved (10.1 IN-03). Tokens`. `IN-03` is a bookkeeping
token under this repository's frozen union regex and is *not* in the script's narrower tolerated
set (`D-NN|SC-N|Phase N|.planning/`), so the line reads to the script as security rationale deleted
with nothing justifying it. The rationale is intact — the surrounding comment still says in full
that this is a test-only helper, that it bypasses the HMAC rewind, audit row and telemetry, and
that production flows must use the signed token clause so security signals are preserved. Positive
control: the same script over the same diff with the `auth.ex`/`accounts.ex` mirrors excluded
examines 409 removed lines and exits 0, so the check was live and this one line family is its sole
trip. Wave 2 independently reached the same conclusion and recorded it under `## SWEEP-COMMIT`.
Not fixed here: D-16 pins the script as unmodifiable and Standing Constraint 4 makes
found-while-cleaning a todo.

## Deviations from Plan

**Two repair commits were added ahead of the re-bless, outside the D-19 three-commit topology.**
The plan anticipates template fixes between re-bless attempts (Safety Rule 1) but assumed they
would be folded into the re-bless cycle silently. They are committed separately and visibly
instead, because one of them fixes a test regression and deserves its own bisectable commit.
Neither touches `test/fixtures/install_golden/`, so the single-re-bless-commit constraint the rule
actually protects is intact.

**The commits `d40bec7e` and `a757d517` were withdrawn.** They were the previous re-bless and its
evidence entry, blessed at a template state that still carried the broken prose and the
`Organization` regression. Keeping them would have meant two commits touching the golden fixture,
which the plan's first must-have forbids outright. `git reset --mixed` moved HEAD back with the
working tree intact — nothing was discarded — and both commits are additionally saved as patches in
the session scratchpad. All phase commits were unpushed, so no shared history moved.

**SC-3's `install_golden_contract` job clause is deferred to ship time.** This phase pushes
nothing, so no Actions verdict exists to read. Recorded explicitly in `## HONEST-CLAIMS` rather
than left unobserved or asserted from a local proxy.

## Todos Filed (none fixed in-phase — Standing Constraint 4)

- `2026-09-17-ci-change-detector-omits-sigra-upgrade-and-gen-oauth.md` — `install-smoke.sh` never
  runs `mix sigra.upgrade`, so 3 of the 46 edited templates are structurally unreachable by SC-1.
- `2026-09-17-fut-01-template-example-parity-guard.md` — nothing mechanical keeps
  `priv/templates/` and `test/example/` in agreement; includes why byte parity is the wrong
  contract and what a narrower guard would compare.
- `2026-09-17-security-comment-classifier-token-set-omits-half-the-union.md` — the SC-5b
  tolerated-token set omits `IN-NN`, `ORG-UX-NN`, `GATE-NN` and the rest of the union, so
  bookkeeping sweeps produce false REDs on a security gate.

## Next Phase Readiness

Phase 239's implementation is complete: all four plans have summaries, the three-commit topology
plus three adjunct commits are on `main` (unpushed), and the full local gate is green. Ready for
`/gsd-verify-work 239`.

The verifier should know that SC-5b is RED by design and that the reasoning is recorded in two
independent places (`## SWEEP-COMMIT` from wave 2 and `## HONEST-CLAIMS` from wave 4), with a
positive control in the latter.
