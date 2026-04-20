---
phase: 31
slug: automation-first-verification
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-16
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix ConnTest/LiveViewTest + Playwright + focused shell smoke |
| **Config file** | `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts`, `.github/workflows/ci.yml` |
| **Quick run command** | `bash -lc 'PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/authorizer_test.exs test/sigra/admin/audit/query_test.exs test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1 && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/controllers/admin/audit_export_controller_test.exs --max-failures 1'` |
| **Browser smoke command** | `bash -lc 'cd test/example && MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.create >/dev/null && mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-validation.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-checkpoints.spec.ts --project=chromium --project=mobile --project=dark-chromium'` |
| **Runtime smoke command** | `bash -lc 'cd test/example && MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.create >/dev/null && mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-http-smoke.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd ../.. && HOST=http://localhost:4000 scripts/ci/http-smoke.sh && GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all'` |
| **Full suite command** | `bash -lc 'PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test && MIX_ENV=dev mix ecto.create >/dev/null && MIX_ENV=dev mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-full.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-checkpoints.spec.ts --project=chromium --project=mobile --project=dark-chromium; cd ../../.. && HOST=http://localhost:4000 scripts/ci/http-smoke.sh && GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all'` |
| **Estimated runtime** | ~20-40s targeted direct-path slices, ~60-150s browser/checkpoint slices, ~120-240s runtime smoke, ~240-420s full combined gate |

---

## Sampling Rate

- **After every task commit:** Run the targeted command listed for that task row.
- **After every plan wave:** Run the full suite command for root tests, example-app tests, browser checkpoints, and runtime smoke.
- **Before `/gsd-verify-work`:** All targeted rows green, then the full suite command green.
- **Max feedback latency:** Keep task-level checks under ~40 seconds where possible; reserve booted browser/runtime passes for plan-wave boundaries and browser/smoke-touching tasks.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 31-01-01 | 01 | 1 | VFY-01, VFY-02, VFY-04 | T-31-01 | Playwright behavior specs route only to `chromium`, while checkpoints alone expand to `mobile` and `dark-chromium`; trace/screenshot/selective video policy stays scoped | harness | `cd test/example/priv/playwright && npx playwright test --list tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-generated.spec.ts` | ❌ planned in-task | ⬜ pending |
| 31-01-02 | 01 | 1 | VFY-01, VFY-02, VFY-04 | T-31-02, T-31-03 | Generated-host parity smoke remains narrow, deterministic, and capable of emitting curated screenshots plus retained failure video | generated-host browser | `GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all` | ❌ planned in-task | ⬜ pending |
| 31-02-01 | 02 | 2 | VFY-01, VFY-02, VFY-04 | T-31-04, T-31-05 | Example-app browser specs pin the canonical admin journeys plus checkpoint inventory without moving negative-case matrices into Playwright | browser | `bash -lc 'cd test/example && MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.create >/dev/null && mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-browser-a.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-checkpoints.spec.ts --project=chromium --project=mobile --project=dark-chromium'` | ❌ planned in-task | ⬜ pending |
| 31-02-02 | 02 | 2 | VFY-01, VFY-02, VFY-04 | T-31-04..T-31-06 | Example-app admin journeys and checkpoints turn green with curated desktop/mobile/dark artifacts on the intended projects | browser | `bash -lc 'cd test/example && MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.create >/dev/null && mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-browser-b.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd priv/playwright && CI=true SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-checkpoints.spec.ts --project=chromium --project=mobile --project=dark-chromium'` | ❌ planned in-task | ⬜ pending |
| 31-03-01 | 03 | 1 | VFY-01, VFY-03 | T-31-07 | Library and example direct-path tests keep denied, out-of-scope, and export/impersonation regressions proven outside the browser happy path | unit + integration | `bash -lc 'PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/authorizer_test.exs test/sigra/admin/audit/query_test.exs test/sigra/plug/forbid_during_impersonation_test.exs --max-failures 1 && cd test/example && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/controllers/impersonation_controller_test.exs test/example_web/controllers/admin/audit_export_controller_test.exs --max-failures 1'` | ✅ existing | ⬜ pending |
| 31-03-02 | 03 | 1 | VFY-01, VFY-03 | T-31-08, T-31-09 | Example-host and generated-host runtime smoke prove boot, route, cookie, success, and denial seams through real HTTP and fresh install | runtime smoke | `bash -lc 'cd test/example && MIX_ENV=dev PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix ecto.create >/dev/null && mix ecto.migrate >/dev/null && PHX_SERVER=true mix phx.server >/tmp/sigra-phase31-http-smoke.log 2>&1 & SERVER_PID=$!; trap "kill $SERVER_PID" EXIT; for i in $(seq 1 30); do curl -sf http://localhost:4000/ >/dev/null && break; sleep 1; done; cd ../.. && HOST=http://localhost:4000 scripts/ci/http-smoke.sh && GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test all'` | ✅ existing | ⬜ pending |
| 31-04-01 | 04 | 3 | VFY-01, VFY-02, VFY-04 | T-31-10, T-31-11 | CI keeps example-admin behavior, checkpoints, and runtime seams separate and publishes green review bundles plus failure diagnostics | workflow config | `node - <<'NODE'\nconst fs = require('fs');\nconst text = fs.readFileSync('.github/workflows/ci.yml', 'utf8');\nconst exampleJob = text.match(/example_playwright_smoke:[\\s\\S]*?(?=^\\S|\\Z)/m)?.[0];\nif (!exampleJob) throw new Error('missing example_playwright_smoke job block');\nconst required = [\n  'admin-user-operations.spec.ts',\n  'impersonation.spec.ts',\n  'admin-audit.spec.ts',\n  'admin-checkpoints.spec.ts',\n  'dark-chromium',\n  'artifacts/admin-checkpoints/',\n  'admin-example-report',\n  'playwright-report/',\n  'test-results/',\n];\nfor (const needle of required) {\n  if (!exampleJob.includes(needle)) {\n    throw new Error(`missing example job text: ${needle}`);\n  }\n}\nconst artifactNames = [...exampleJob.matchAll(/name:\\s*([A-Za-z0-9._-]+)/g)].map((m) => m[1]);\nif (new Set(artifactNames).size !== artifactNames.length) {\n  throw new Error('duplicate artifact names in example_playwright_smoke job');\n}\nif (!text.includes('example_http_smoke:')) {\n  throw new Error('missing example_http_smoke job');\n}\nconsole.log('workflow example-admin structure ok');\nNODE` | ✅ existing | ⬜ pending |
| 31-04-02 | 04 | 3 | VFY-01, VFY-02, VFY-03, VFY-04 | T-31-10..T-31-12 | CI preserves generated-host parity, scoped uploads, selective retained video, and 7/14-day branch-aware retention without collapsing into one job | workflow config | `node - <<'NODE'\nconst fs = require('fs');\nconst text = fs.readFileSync('.github/workflows/ci.yml', 'utf8');\nconst generatedJob = text.match(/generated_admin_playwright_smoke:[\\s\\S]*?(?=^\\S|\\Z)/m)?.[0];\nif (!generatedJob) throw new Error('missing generated_admin_playwright_smoke job block');\nfor (const needle of ['admin-acceptance-smoke.sh', '--test all', 'playwright-report/', 'test-results/']) {\n  if (!generatedJob.includes(needle)) {\n    throw new Error(`missing generated job text: ${needle}`);\n  }\n}\nconst artifactNames = [...generatedJob.matchAll(/name:\\s*([A-Za-z0-9._-]+)/g)].map((m) => m[1]);\nif (new Set(artifactNames).size !== artifactNames.length) {\n  throw new Error('duplicate artifact names in generated_admin_playwright_smoke job');\n}\nif (!text.match(/retention-days:\\s*7/) || !text.match(/retention-days:\\s*14/)) {\n  throw new Error('missing branch-aware 7/14 retention rules');\n}\nconsole.log('workflow generated-admin structure ok');\nNODE` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Planned File Creation Inside Phase Tasks

- [ ] `test/example/priv/playwright/helpers/adminArtifacts.ts` — created by Plan 31-01 Task 2 as part of the browser artifact helper seam.
- [ ] `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — created by Plan 31-02 Task 1 as the dedicated checkpoint suite.
- [ ] `test/example/priv/playwright/playwright.config.ts` — updated by Plan 31-01 Task 1 to partition projects and add screenshot/selective video policy.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Reviewer usefulness of the final green artifact bundle | VFY-02, VFY-04 | Automation can prove artifact generation, but a quick human pass is still useful to confirm the chosen screenshots are the right pages and readable at a glance | Download the example-admin and generated-admin green artifacts from CI, open the HTML report and attached screenshots, and confirm desktop/mobile/dark checkpoints are easy to inspect without browsing raw diagnostic folders |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or explicit in-plan file creation
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] No external Wave 0 prerequisite remains; planned file creation is owned by explicit in-plan tasks
- [ ] No watch-mode flags
- [ ] Feedback latency stays within the targeted slice budget
- [x] `nyquist_compliant: true` set in frontmatter for this validation contract

**Approval:** pending
