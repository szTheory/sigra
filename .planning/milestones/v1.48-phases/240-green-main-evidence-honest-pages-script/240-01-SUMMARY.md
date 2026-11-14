---
phase: 240-green-main-evidence-honest-pages-script
plan: 01
subsystem: ci
tags: [ci, shell, github-pages, error-handling, self-test, GREEN-05, SC-3]
requires:
  - scripts/ci/ensure-github-pages-legacy-branch.sh
  - .github/workflows/playwright-github-pages.yml
provides:
  - scripts/ci/ensure-github-pages-legacy-branch.test.sh
  - "ci.yml fast_checks step: Pages legacy-branch script self-test"
  - "four RED transcripts for Plan 04's AFTER-PAGES-LOUD-RED evidence slot"
affects:
  - .github/workflows/ci.yml
tech-stack:
  added: []
  patterns:
    - "status-line-driven HTTP branching via `gh api -i` (first use in this repo)"
    - "PATH-shadowed recording fake-`gh` stub harness with FAKE_MODE / FAKE_GH_LOG"
key-files:
  created:
    - scripts/ci/ensure-github-pages-legacy-branch.test.sh
    - .planning/phases/240-green-main-evidence-honest-pages-script/deferred-items.md
  modified:
    - scripts/ci/ensure-github-pages-legacy-branch.sh
    - .github/workflows/ci.yml
decisions:
  - "GET /pages branches on the status line: 200 inspects, 404 creates, everything else exits 1 (D-15/D-16)"
  - "PUT /pages 403 is the only tolerated non-2xx status anywhere in the script (D-19)"
  - "The RED proof is a hermetic fake-`gh` stub, never a live misconfiguration of the public repo (D-20)"
metrics:
  duration: ~50m
  completed: 2026-09-18
actuals:
  tokens: 4900
  tasks: 3
  commits: 5
status: complete
---

# Phase 240 Plan 01: Honest Pages Script Summary

`scripts/ci/ensure-github-pages-legacy-branch.sh` now branches on the HTTP status line read from
`gh api -i` at both call sites, so every non-2xx Pages API response is either the one named,
commented PUT-403 tolerance or a loud `exit 1` — proven by a new 10-mode hermetic self-test that
runs from a `ci.yml` `fast_checks` step.

## What Was Built

**Two lenient paths closed.**

1. **GET site (`:18` in the old file, D-15/D-16).** `if ! pages_json=$(gh api ... 2>/dev/null)`
   was an *any-error → create* split: 403, 422, 500, a rate limit or a network blip all read as
   "no Pages site yet" and fell through to `POST /pages`. It is now
   `get_out="$(gh api -i ... 2>/dev/null || true)"`, `get_status` = field 2 of stdout line 1, and a
   three-arm `case`: `200)` splits the body off after the `\r`-tolerant blank separator, `404)`
   runs the unchanged create body, `*)` echoes the status and the raw envelope to stderr and exits
   1. An empty status (gh never ran) lands in `*)` — fail closed.
2. **PUT site (`:66-73` in the old file, D-17/D-18).** The `2>&1`-merged blob tested with an
   unanchored substring match for `403` was replaced by the same status-line `case`: `204|200)`
   prints `updated.`, `403)` keeps the documented tolerance, `*)` exits 1 with the body echoed.
   `-i` is load-bearing, not stylistic — a successful `PUT /pages` returns **204 No Content with
   an empty body**, so the status line is the only signal.

**Mandated comments, all present and verified by reading the file:** the SC-3 ↔ D-19
reconciliation paragraph as a header block (all three parts), the D-16 public-repo rationale with
its 8-repo live-probe provenance directly above the GET `case`, the `240-RESEARCH.md §4`
source-of-truth citation for the `gh api -i` shape, the D-18 `-i` rationale above the PUT call, and
the D-19 rationale inside the `403)` arm citing `playwright-github-pages.yml:36-38`.

**D-22 preserved.** The three `gh api .../pages/builds --method POST >/dev/null 2>&1 || true`
build-trigger swallows are byte-unchanged, now at `:81`, `:109`, `:156`, each preceded by a reason
comment. Swallow #1's comment also records that CONTEXT D-22's `:31`/`:52` citations were one line
late (the real pre-rewrite swallows were `:30`, `:50`, `:75`). The no-token early `exit 0` and the
`jq`-presence `exit 1` are untouched.

**New self-test.** `scripts/ci/ensure-github-pages-legacy-branch.test.sh` (308 lines) follows
`notify-failure-issue.test.sh`: lettered case enumeration in the header, `mktemp -d` + `trap`, a
recording stub `gh` written to `$TMP/bin/gh` that appends `"$*"` to `$FAKE_GH_LOG` and dispatches
on `${FAKE_MODE:-ok}`, `PATH` prepended per invocation, `set +e` / capture `$?` / `set -e` around
every expected failure with a distinguishing stderr token asserted alongside the exit code, and a
PASS/FAIL tally ending in `ensure-github-pages-legacy-branch.test: PASS`. The 403 stub reproduces
all four observable channels of live-probed gh 2.95.0 verbatim (exit 1; `HTTP/2.0 403 Forbidden`
as stdout line 1; the JSON error body on stdout after a `\r\n` blank, no trailing newline;
`gh: <msg> (HTTP 403)` on stderr). Ten modes: `get_200_already_gh_pages`, `get_404`, `get_403`,
`get_500`, `build_type_workflow`, `no_token`, `put_204`, `put_403`, `put_422`, `put_500`.

**CI wiring.** A `Pages legacy-branch script self-test` step was added to `fast_checks`,
immediately after `Notify-failure-issue self-test`, in the identical three-line shape.
`ci-gate.needs` was not touched — the whole `ci.yml` diff is six inserted lines at `:262-267`,
nowhere near `:1534-1560`.

## SC-3 RED transcripts (raw material for Plan 04's `AFTER-PAGES-LOUD-RED` slot)

Each captured by invoking the script directly under the stub with `bash` (never `zsh`), at
committed HEAD `50ffafdb`, on 2026-09-18.

```
$ FAKE_MODE=get_403 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: GET /pages returned '403'; refusing to guess.
HTTP/2.0 403 Forbidden
Content-Type: application/json; charset=utf-8

{"message":"Resource not accessible by integration","documentation_url":"https://docs.github.com/rest/pages/pages#update-information-about-a-apiname-pages-site","status":"403"}
```

```
$ FAKE_MODE=get_500 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: GET /pages returned '500'; refusing to guess.
HTTP/2.0 500 Internal Server Error
Content-Type: application/json; charset=utf-8
X-GitHub-Request-Id: DEAD:0403:BEEF

{"message":"Server Error (ref 403); Resource not accessible by integration was not the cause","documentation_url":"https://docs.github.com/rest","status":"500"}
```

(The `get_500` body carries the bare digits `403` twice — once in the request id, once in the
message — and the old unanchored match would have read it as "expected 403, carry on". It now
exits 1. This is the D-17 false-positive guard firing.)

```
$ FAKE_MODE=put_422 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: PUT /pages returned '422'.
HTTP/2.0 422 Unprocessable Entity
Content-Type: application/json; charset=utf-8

{"message":"Invalid request.","documentation_url":"https://docs.github.com/rest","status":"422"}
```

```
$ FAKE_MODE=put_500 ... bash scripts/ci/ensure-github-pages-legacy-branch.sh
exit=1
ensure-github-pages-legacy-branch: PUT /pages returned '500'.
HTTP/2.0 500 Internal Server Error
Content-Type: application/json; charset=utf-8

{"message":"Server Error","documentation_url":"https://docs.github.com/rest","status":"500"}
```

## Verification

| Check | Result |
|---|---|
| `bash scripts/ci/ensure-github-pages-legacy-branch.test.sh` | **PASS**, 10 passed / 0 failed, terminal line `ensure-github-pages-legacy-branch.test: PASS` |
| `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` | **PASS**, 90/90 |
| `shellcheck` on both scripts | clean |
| `python3 -c "yaml.safe_load(open('.github/workflows/ci.yml'))"` | parses |
| `grep -n "grep -qE '403" scripts/ci/ensure-github-pages-legacy-branch.sh` | no hit |
| `grep -n 'gh api -i' …` | hits at `:55` (GET) and `:133` (PUT), both with `2>/dev/null` |
| `git diff 04e94a86..HEAD -- .github/workflows/ci.yml` | +6 lines at `:262-267`; nothing between `:1534` and `:1560` |
| `gh api repos/szTheory/sigra/pages --jq '.source'` after the plan | `{"branch":"gh-pages","path":"/"}` — unchanged, no settings mutation (D-20/T-240-04) |
| `MIX_ENV=test mix ci` | **RED** — 6 pre-existing `ThreadlineTest` failures, unrelated to this diff (see below) |

**TDD gate compliance:** RED → GREEN observed twice, once per site.
`test(240-01)` `56edd766` (GET cases fail: 403 silently POST-creates, 500 swallowed) →
`feat(240-01)` `4f71ca49`; `test(240-01)` `46bc9953` (PUT cases fail) → `feat(240-01)` `2ca65989`.

## Deviations from Plan

**1. [Rule 3 - Blocking, out of scope] `MIX_ENV=test mix ci` is red for a pre-existing reason.**
- **Found during:** Task 3.
- **Issue:** 6 failures, all `Sigra.Audit.Forwarders.ThreadlineTest`, all
  `** (UndefinedFunctionError) function Sigra.Audit.Forwarders.Threadline.attach/1 is undefined
  (module Sigra.Audit.Forwarders.Threadline is not available)` at
  `test/sigra/audit/forwarders/threadline_test.exs:136`. Reproduced on two consecutive runs
  (second with a fully warm build).
- **Why it is not this plan's:** `git diff --name-only 04e94a86..HEAD` lists exactly three files —
  `.github/workflows/ci.yml` and the two Pages shell scripts. **No Elixir source, test, dependency
  or config file changed**, so a module-availability failure cannot originate in this diff. The
  optional `:threadline` dep (`mix.exs:120`, `~> 0.5`, locked at 0.7.0) recompiles on every
  invocation, which points at a local optional-dep load-order artifact.
- **Action:** logged to
  `.planning/phases/240-green-main-evidence-honest-pages-script/deferred-items.md` (commit
  `50ffafdb`) rather than fixed, per the executor scope boundary. The wave gate is therefore
  **not** green on this machine, and that fact is disclosed here rather than papered over. The two
  fast gates this plan owns — the new self-test and the prohibitions glob — are both green.

**2. [Rule 2 - Correctness] Comment wording changed to satisfy an acceptance grep.**
The D-17 explanatory comment originally quoted the removed code verbatim, which made
`grep -n "grep -qE '403" …` return a hit against a comment and thus fail an acceptance criterion
that exists to prove the old arm is gone. Reworded to "an unanchored regex for a bare 403" — same
meaning, no false positive for the criterion.

## Known Stubs

None. The fake `gh` is a test double inside a `.test.sh`, not a stub in shipped code.

## Threat Flags

None. `T-240-01` is mitigated as planned (anchored status-line read, no `eval`, no interpolation of
the response body into a further command, empty status fails closed). `T-240-04` is mitigated and
verified: live Pages `.source` is unchanged after the plan.

## Self-Check: PASSED

- `scripts/ci/ensure-github-pages-legacy-branch.sh` — FOUND
- `scripts/ci/ensure-github-pages-legacy-branch.test.sh` — FOUND
- `.github/workflows/ci.yml` — FOUND
- `.planning/phases/240-green-main-evidence-honest-pages-script/deferred-items.md` — FOUND
- Commits `56edd766`, `4f71ca49`, `46bc9953`, `2ca65989`, `50ffafdb` — all FOUND in `git log`
