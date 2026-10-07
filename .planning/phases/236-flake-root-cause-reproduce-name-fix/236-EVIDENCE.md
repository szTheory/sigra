# Phase 236 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-FLAKE-RED](#before-flake-red) | Deliberately manufactured RED of `admin-generated.spec.ts:459` (`toHaveURL(actor=...)`), corroborated by a real, unprompted CI failure of the identical assertion on the same day | Real GitHub Actions CI run `35004420339` (`gh run view` / `gh api .../logs`) plus a local `npx playwright test --repeat-each --trace=on` sweep against a scaffolded generated host under real CPU contention | captured (run `35004420339`) |
| [AFTER-P17-GUARD-OBSERVED](#after-p17-guard-observed) | `p17-no-playwright-retry-wrapper.test.mjs` observed RED against a committed known-bad fixture and GREEN against the real config (standing constraint 6) | `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` (RED) then the same command without the env override (GREEN) | captured (run `35034938082`) |
| [AFTER-FIX-GREEN](#after-fix-green) | Five sequential `pull_request` CI runs on the fix branch, each with `Generated admin Playwright smoke` = `success`, plus the plan 236-01 Path-A reproduction re-run unchanged against the fixed code — zero failures of the `:459` assertion | `gh run list --workflow CI --branch gsd/phase-236-flake-root-cause --event pull_request` + `gh run view <id> --json jobs`, and a local `npx playwright test --repeat-each=50 --trace=on` sweep under genuine host-OS CPU contention against the same locally scaffolded generated host as 236-01 | captured (runs `35029916498`, `35030710957`, `35031404780`, `35032086557`, `35034938082`) |

---

## BEFORE-FLAKE-RED

Status: captured (run `35004420339`)

### Primary evidence: real, unprompted CI failure (run `35004420339`)

While gathering local reproduction evidence for this slot, the `Generated admin Playwright
smoke` job failed on an ordinary `push` to `main` at 2026-09-15T17:57:04Z — i.e. GREEN-01's
target failure occurred on its own, on the real CI topology, the same day this plan executed.
This is stronger evidence than a synthetic local repro alone and is recorded as the primary
observation; the local repro (below) is corroborating evidence that the same received-URL
signature reproduces deterministically once the same host-contention conditions are present.

Producing commands:

```bash
gh run list --workflow=ci.yml --limit 50 --json databaseId,conclusion,headBranch,createdAt,event
gh run view 35004420339 --json jobs -q '.jobs[] | select(.name=="Generated admin Playwright smoke")'
gh api repos/szTheory/sigra/actions/jobs/104500542292/logs
```

Job: `Generated admin Playwright smoke`, run `35004420339`, job id `104500542292`
(https://github.com/szTheory/sigra/actions/runs/35004420339/job/104500542292), event `push`,
branch `main`.

Verbatim failure (from the job log):

```text
2026-09-15T18:01:37.8416376Z   ✘  7 [admin-generated] › tests/admin-generated.spec.ts:428:5 › generated audit presets expose one effective filter value and visible applied state (18.2s)
2026-09-15T18:01:41.3002699Z     Error: expect(page).toHaveURL(expected) failed
2026-09-15T18:01:41.3003598Z     Expected pattern: /(?:\?|&)actor=00000000-0000-0000-0000-000000000001(?:&|$)/
2026-09-15T18:01:41.3004326Z     Received string:  "http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure"
2026-09-15T18:01:41.3009375Z     > 459 |   await expect(page).toHaveURL(new RegExp(`(?:\\?|&)actor=${actorId}(?:&|$)`));
2026-09-15T18:01:41.3011597Z         at /home/runner/work/sigra/sigra/test/example/priv/playwright/tests/admin-generated.spec.ts:459:22
```

**Received URL string (verbatim, the D-05 decider):**

```text
http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure
```

The `actor=` key is **completely absent** from the received URL — not present-and-empty. This is
D-05 branch **(a)**.

`retries: 0` and `trace: 'on-first-retry'` mean CI does not produce a `trace.zip` for a
first-attempt failure (there is no retry to trigger it); CI's diagnostic artifact for this
failure is a screenshot, a video, and an `error-context.md` (artifact
`generated-admin-failure-diagnostics`, run `35004420339`), not a trace. The trace requirement is
satisfied by the local reproduction below, which used `--trace=on` unconditionally (a CLI flag,
not a `playwright.config.ts` edit) and observed the **identical** received-URL signature.

### Corroborating evidence: local reproduction with a real trace.zip

30 and then 40, 60, and 80 attempt sweeps of the same test against a locally scaffolded
generated host (`scripts/ci/admin-acceptance-smoke.sh`-equivalent boot: fresh `phx.new` app,
`mix sigra.install`, seeded platform admin, booted on port 4017) produced **zero** failures of
the target assertion under normal load — only boot-warmup false positives (discarded; see
Attempt Log below) and, separately, 60-80 clean passes under CDP CPU/network throttling (4x-12x
CPU, up to 400ms latency). The race did not manifest until genuine host CPU contention was
introduced (17 concurrent `yes > /dev/null` processes on an 18-core machine, approximating a
loaded/shared CI runner), at which point it failed **41 of 50** repeats with the **same** D-05
branch (a) signature.

Producing command (Path A — no `playwright.config.ts` edit; `git status --porcelain` on it is
empty):

```bash
for i in $(seq 1 16); do yes > /dev/null & done
cd test/example/priv/playwright
CI=true SIGRA_EXAMPLE_URL="http://localhost:4017" npx playwright test \
  tests/admin-generated.spec.ts \
  -g "generated audit presets expose one effective filter value and visible applied state" \
  --project=admin-generated \
  --repeat-each=50 --workers=1 --retries=0 --trace=on --reporter=list \
  --output test-results/phase236-repro-contended
```

Result: 41 failed, 9 passed (50 total). First failure at **attempt 3** of the repeat-each sweep
(Playwright's `-repeat2` directory suffix; the first repeat carries no suffix).

Verbatim failure (identical received-URL signature to the CI run above):

```text
1) [admin-generated] › tests/admin-generated.spec.ts:428:5 › generated audit presets expose one effective filter value and visible applied state

    Error: expect(page).toHaveURL(expected) failed

    Expected pattern: /(?:\?|&)actor=00000000-0000-0000-0000-000000000001(?:&|$)/
    Received string:  "http://localhost:4017/admin/audit?action_prefix=admin.impersonation&order_by=inserted_at&order_direction=desc&outcome=failure"
    Timeout: 15000ms

      457 |   await expect(actorFilter).toHaveValue(actorId);
      458 |   await actorFilter.press("Enter");
    > 459 |   await expect(page).toHaveURL(new RegExp(`(?:\\?|&)actor=${actorId}(?:&|$)`));
          |                      ^
      460 |   await expect(page.getByText(`Actor: ${actorId}`, { exact: true })).toBeVisible();
```

Trace artifact (real, non-empty, openable):

```text
/Users/jon/projects/sigra/.gsd/scratch/phase236-evidence/trace.zip
```

(2,005,798 bytes; copied verbatim from
`test/example/priv/playwright/test-results/phase236-repro-contended/admin-generated-generated--69428-e-and-visible-applied-state-admin-generated-repeat2/trace.zip`,
which is the attempt-3/50 failure above. `test-results/` is gitignored per
`test/example/priv/playwright/.gitignore:3`, so the local artifact lives outside version
control at the path above; the run-`35004420339` CI artifact is the durable, retrievable
receipt.)

Verify with:

```bash
npx playwright show-trace /Users/jon/projects/sigra/.gsd/scratch/phase236-evidence/trace.zip
```

`error-context.md` for the same attempt is at
`/Users/jon/projects/sigra/.gsd/scratch/phase236-evidence/error-context.md`.

### Discarded attempts (Attempt Log — not the RED, recorded for honesty)

- 30 attempts on a just-booted (cold, asset-compiling) host: 10 failures, but all 10 were
  `TimeoutError: page.waitForSelector` on `waitForLiveViewReady` at **line 433** (the initial
  `page.goto("/admin/audit")` before any preset click) — a boot-warmup artifact
  (`esbuild`/`tailwind` still downloading), not a failure of the `:459` assertion. Discarded per
  the plan's own instruction: "do not record a passing run as the RED" and, by the same logic, do
  not record a differently-located failure as the RED.
- 40+60+80 attempts against a warm host under CDP throttling alone (network latency 150-400ms,
  CPU throttle 4x-12x, with and without a `context.routeWebSocket` delay forcing the
  `longPollFallbackMs: 2500` fallback): 0 failures of the target assertion. CDP-level throttling
  widens client-side timing but does not reproduce the real contention profile that a shared CI
  runner's CPU scheduling produces; genuine OS-level CPU contention (the `yes` loop) is what
  finally reproduced it, consistent with the `:459` failure being a scheduling race, not a
  network-latency race.

### D-05 branch call

**Branch (a):** `actor=` is absent from the URL entirely, not present-and-empty. Both the real
CI failure and the local reproduction show the identical received string with no `actor=` key.
See `236-DIAGNOSIS.md` for the differential diagnosis.

## AFTER-P17-GUARD-OBSERVED

Status: captured (run `35034938082`)

Per ROADMAP standing constraint 6 ("a guard never observed RED does not count"), both halves of
`scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` were run and their exit codes
recorded.

### CI receipt — existing prohibition route

Run `35034938082`'s exact `Fast checks (milestone/installer/contracts/snapshot/ledger guards)`
job concluded `success`:

```bash
gh run view 35034938082 --repo szTheory/sigra --json jobs --jq '.jobs[] | select(.name == "Fast checks (milestone/installer/contracts/snapshot/ledger guards)") | {name, conclusion}'
```

```json
{"conclusion":"success","name":"Fast checks (milestone/installer/contracts/snapshot/ledger guards)"}
```

This receipt proves that run `35034938082` passed the existing Fast checks prohibition glob,
which includes p17. It proves the CI GREEN route; it does not replace the local known-bad RED
observation recorded below.

### RED half — committed known-bad fixture substituted as the subject

```bash
GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
```

Exit code: `1`.

Failure message (verbatim, from the `the config subject carries no retry wrapper` test):

```text
a `retries` value is read from `process.env` — recovering a failed attempt via an env-controlled retry count masks the isolation evidence a flake investigation depends on
```

TAP summary: `# tests 5`, `# pass 4`, `# fail 1`.

### GREEN half — real, unmodified subject

```bash
node --test --test-reporter=tap scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
```

Exit code: `0`. TAP summary: `# tests 5`, `# pass 5`, `# fail 0`.

### Shared glob unaffected

```bash
node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
```

Exit code: `0`. TAP summary: `# tests 71`, `# pass 71`, `# fail 0` — the new guard does not break
any of the other 15 prohibition guards sharing the `fast_checks` glob.

## AFTER-FIX-GREEN

Status: captured (runs `35029916498`, `35030710957`, `35031404780`, `35032086557`, `35034938082`)

Per ROADMAP SC-3, five sequential `pull_request` CI runs on the fix branch
(`gsd/phase-236-flake-root-cause`, PR #242) were dispatched via ordinary pushes (empty commits,
`git commit --allow-empty`), each allowed to conclude before the next was pushed — never via
`gh workflow run`, which `release_ref_guard` (`ci.yml:78-96`) hard-fails for any ref that is not
`refs/tags/v*`. Both halves of SC-3 are recorded below: the CI-repeat half and the
reproduction-no-longer-reproduces half.

### CI-repeat half: five sequential `pull_request` runs, all `success` on the target job

Harvest command:

```bash
gh run list --workflow CI --branch gsd/phase-236-flake-root-cause --event pull_request \
  --limit 40 --json databaseId,headSha,conclusion,createdAt
```

Per-run job conclusion (verbatim, re-verified independently of the orchestrator's own harvest,
via `bash -c` per the shell-portability note below):

```bash
IDS="35029916498 35030710957 35031404780 35032086557 35034938082"
for id in $IDS; do
  gh run view "$id" --json jobs --jq '.jobs[] | select(.name=="Generated admin Playwright smoke") | {name,conclusion,startedAt,completedAt}'
done
```

```text
--- run 35029916498 ---
{"completedAt":"2026-09-15T22:18:17Z","conclusion":"success","name":"Generated admin Playwright smoke","startedAt":"2026-09-15T22:14:20Z"}
--- run 35030710957 ---
{"completedAt":"2026-09-15T22:27:26Z","conclusion":"success","name":"Generated admin Playwright smoke","startedAt":"2026-09-15T22:23:29Z"}
--- run 35031404780 ---
{"completedAt":"2026-09-15T22:35:23Z","conclusion":"success","name":"Generated admin Playwright smoke","startedAt":"2026-09-15T22:31:47Z"}
--- run 35032086557 ---
{"completedAt":"2026-09-15T22:44:03Z","conclusion":"success","name":"Generated admin Playwright smoke","startedAt":"2026-09-15T22:40:04Z"}
--- run 35034938082 ---
{"completedAt":"2026-09-15T23:21:31Z","conclusion":"success","name":"Generated admin Playwright smoke","startedAt":"2026-09-15T23:17:30Z"}
```

Per-run identity (also re-verified independently, `bash -c`):

```bash
for id in 35029916498 35030710957 35031404780 35032086557 35034938082; do
  gh run view "$id" --json headSha,conclusion,event --jq "{id: \"$id\"} + ."
done
```

```text
{"conclusion":"failure","event":"pull_request","headSha":"2c76167f9736cbd6d542d2cd0c16ddacc4aa6793","id":"35029916498"}
{"conclusion":"failure","event":"pull_request","headSha":"8a8dd4d88b379654510fe3791439e8fe5383561e","id":"35030710957"}
{"conclusion":"failure","event":"pull_request","headSha":"b428e320820b735f36bbc2cdf8be43a237956d30","id":"35031404780"}
{"conclusion":"failure","event":"pull_request","headSha":"5aa896300fd09c7b94e459a8d16a886be4def167","id":"35032086557"}
{"conclusion":"failure","event":"pull_request","headSha":"620991620d9dc93dd0ec2115e92eff67f26885b7","id":"35034938082"}
```

The run-level `conclusion` is `failure` on all five — this is the KNOWN, unrelated, pre-existing
`phase_235_fast_01_*` contract-test staleness documented in 236-02's and 236-03's SUMMARYs (a
v1.48 `REQUIREMENTS.md` rollover that postdates those tests' last edit), not a regression this
phase owns; SC-3's `<fails_when>` clause explicitly rejects only `cancelled` conclusions, and none
of the five is `cancelled`. The `Generated admin Playwright smoke` **job** — the surface this
phase fixed — is `success` on all five, proving the pushes were genuinely sequential (a
self-cancelling rapid-push sequence would show `cancelled`, not `failure`) and that the fix holds
under repetition on the real CI topology.

The fifth run's `headSha` (`620991620d9dc93dd0ec2115e92eff67f26885b7`) equals the final committed
HEAD at evidence-capture time (`git rev-parse HEAD` → `620991620d9dc93dd0ec2115e92eff67f26885b7`),
and `git status --porcelain` at that commit shows only the pre-existing untracked `.gsd/` scratch
directory and `.planning/milestone.lock` (the same pre-existing untracked convention 236-03's own
Self-Check recorded) — no uncommitted change to any tracked file, satisfying standing constraint 2.

**Shell-portability note (recorded for honesty, the same class as the `p12`/zsh-glob findings
already filed this phase):** the plan's own `<verify>` command for this task word-splits `$IDS`
unquoted in a `for` loop, which is correct bash behavior but is NOT correct zsh behavior — zsh
does not word-split unquoted parameter expansions by default. Run under zsh, the loop passes the
entire newline-laden `$IDS` string as a single `gh run view` argument, every invocation fails, and
the check reports `observed 0, expected 5` — a correct RED flag rather than a silent false pass.
All verify commands in this ledger were run via `bash -c`, not the default `zsh`, per this plan's
`<verification_discipline>`.

### Reproduction-no-longer-reproduces half: 50/50 passed under identical contention

The plan 236-01 Path-A reproduction was re-run **unchanged** — same test, same `-g` filter, same
`--project=admin-generated`, same `--repeat-each=50` total (chunked into five `--repeat-each=10`
batches to keep the harness streaming rather than one silent 50-repeat invocation; the batching is
a liveness accommodation only, not a parameter change), same `--workers=1 --retries=0 --trace=on`,
same 16-concurrent-`yes`-process genuine host-OS CPU contention — against the fixed `lib/sigra`
code, reusing the identical locally scaffolded generated host from 236-01
(`/tmp/sigra_admin_smoke_236`, `SIGRA_REPO`-path-dependency on this repo, `mix deps.compile sigra
--force` to pick up the fix, rebooted on port 4017):

```bash
for i in $(seq 1 16); do nohup yes > /dev/null 2>&1 & disown; done
cd test/example/priv/playwright
CI=true SIGRA_EXAMPLE_URL="http://localhost:4017" npx playwright test \
  tests/admin-generated.spec.ts \
  -g "generated audit presets expose one effective filter value and visible applied state" \
  --project=admin-generated \
  --repeat-each=10 --workers=1 --retries=0 --trace=on --reporter=line \
  --output .gsd/scratch/phase236-04-afterfix/batchN   # N = 1..5, 10 repeats each = 50 total
```

Result, all five batches:

```text
Batch 1 (repeats 1-10):   10 passed (14.8s)
Batch 2 (repeats 11-20):  10 passed (13.0s)
Batch 3 (repeats 21-30):  10 passed (13.1s)
Batch 4 (repeats 31-40):  10 passed (16.4s)
Batch 5 (repeats 41-50):  10 passed (22.8s)
```

**50 passed, 0 failed, 50 total.** Zero failures of the `:459` `toHaveURL(actor=...)` assertion —
the identical assertion and identical contention profile that produced 41/50 failures pre-fix
(`BEFORE-FLAKE-RED` slot above). The race no longer manifests.

### `BEFORE-FLAKE-RED` slot status — already settled, no change needed

This plan's action text anticipated needing to choose between leaving `BEFORE-FLAKE-RED` `pending`
or promoting it with a genuine run ID. That decision was already made and settled by plan 236-01:
during 236-01's evidence-gathering, a real, unprompted `push`-to-`main` CI failure of the identical
`:459` assertion was discovered (run `35004420339`), so `BEFORE-FLAKE-RED`'s `Status:` line already
reads `captured (run \`35004420339\`)` — satisfying `p12`'s grammar with a real, `gh run
view`-resolvable run ID, not a borrowed or invented one. Re-verified here:

```bash
gh run view 35004420339 --json databaseId,conclusion,event
```

```text
{"conclusion":"failure","databaseId":35004420339,"event":"push"}
```

No further action was needed or taken on that slot.
