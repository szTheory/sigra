# Phase 236 Evidence Ledger

| Slot | What it is | How captured | Status |
|------|-----------|--------------|--------|
| [BEFORE-FLAKE-RED](#before-flake-red) | Deliberately manufactured RED of `admin-generated.spec.ts:459` (`toHaveURL(actor=...)`), corroborated by a real, unprompted CI failure of the identical assertion on the same day | Real GitHub Actions CI run `35004420339` (`gh run view` / `gh api .../logs`) plus a local `npx playwright test --repeat-each --trace=on` sweep against a scaffolded generated host under real CPU contention | captured (run `35004420339`) |

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
