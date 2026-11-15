---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 03
subsystem: testing
tags: [brand, catalog, tier-2, generated-host, smoke-script, phoenix, liveview, bgen-03]

requires:
  - phase: 260
    provides: "Plan 02 harness (Sigra.Test.Brand.Catalog.build/1) and the raw dump contract this plan fills"
provides:
  - "ExampleWeb.CatalogTest: 20 library admin pages rendered on seeded .test personas, dumped RAW to tier2-example-admin/<slug>.html when SIGRA_CATALOG_RAW_DIR is set"
  - "pin_wall_clock!/0 and assert_clock_pinned!/3: absolute timestamps pinned at the source, clock control that names the page and token"
  - "scripts/ci/admin-acceptance-smoke.sh --test catalog: 5 anonymous generated auth pages and 18 generated email builders from one fresh host"
affects: [260-05, 260-08, 260-11, 262]

actuals:
  tokens: 8652
  tasks: 3
  commits: 4

plan_head_before: 0d42289ce6faee4ca499385938ac2fe26944ef8c
plan_head_after: bcc42edbf6494f7522836bba6b7de11d1d081cbd

tech-stack:
  added: []
  patterns:
    - "Wall-clock columns pinned in SQL to a fixed base plus one second per row rank (idempotent, rank-preserving), never normalized by pattern"
    - "Capture-only config override in the running VM (branding sender), restored afterwards; no shipped default changes"
    - "Documented-defect status pinned in a producer script: accepted only with its exact error signature, flips loudly when fixed"

key-files:
  created:
    - test/example/test/example_web/catalog_test.exs
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-deferred-items.md
  modified:
    - scripts/ci/admin-acceptance-smoke.sh

key-decisions:
  - "Ties in the pin rank are broken by insertion command id (cmin), not ctid: users.inserted_at has one-second precision and ctid order drifts once earlier tests leave dead tuples, which moved the persona rows off page one of the users index"
  - "The unpinnable capture session activity stamp is the only exact-value replacement in the pipeline ({{CAPTURE_SESSION_ACTIVITY}}); everything else absolute is pinned at the source"
  - "GET /users/reset-password is a real 500 on a fresh --live host; the catalog pins it as an expected 500 with a one-line marker instead of failing, and fails loudly when it turns 200"
  - "Capture-only branding sender override in both lanes (noreply@catalog.example.test); the shipped default sender stays outside the captured bytes"

requirements-completed: [BGEN-03]

coverage:
  - id: D1
    description: "Tier-2 producer renders the fixed 20-slug page set on seeded personas through the real router, replaces seeded persona ids with {{PERSONA:<key>}} labels, and writes raw html only when SIGRA_CATALOG_RAW_DIR is set"
    requirement: BGEN-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/catalog_test.exs#tier-2 pages, one test per page group (8) and #the whole tier-2 set dumps exactly the fixed slug list"
        status: pass
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/catalog_test.exs, run with the env set (20 files written) and unset (nothing written)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Absolute wall-clock values are pinned at the source (users.inserted_at, audit_events.inserted_at, organization_invitations.expires_at); the pin is idempotent, ranks users in creation order whatever the heap layout, and a clock control fails on any unpinned rendered date"
    requirement: BGEN-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/catalog_test.exs#the wall-clock pin (ranks users in creation order, is idempotent) and #a second pass with the pin run between yields identical pages"
        status: pass
      - kind: unit
        ref: "test/example/test/example_web/catalog_test.exs#planted controls (capture stamp, today token, run-day rule, reference-date rule, no-env write)"
        status: pass
    human_judgment: false
  - id: D3
    description: "scripts/ci/admin-acceptance-smoke.sh --test catalog boots one fresh generated host and writes raw anonymous auth pages and generated emails with only .test addresses, a .test sender, fixed times and a pinned port, then exits 0 before any Playwright step"
    requirement: BGEN-03
    verification:
      - kind: e2e
        ref: "GITHUB_WORKSPACE=$(pwd) PORT=4017 scripts/ci/admin-acceptance-smoke.sh --test catalog (exit 0; address scan, run-day scan, path scan clean)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every other --test target is untouched: the diff is additions only, the case block is intact, and the contract tests that read the script stay green"
    requirement: BGEN-03
    verification:
      - kind: other
        ref: "git diff -U0 -- scripts/ci/admin-acceptance-smoke.sh | grep -c '^-[^-]' = 0; bash -n; mix test generated_confirmation_ci_contract_test phase_234 phase_235; node --test p20; phase34-uat-contracts.sh"
        status: pass
    human_judgment: false
  - id: D5
    description: "The generated reset-password request page cannot be captured as a rendered page because the shipped generated host answers 500 there; the baseline for that slug is a marker, not a page"
    requirement: BGEN-03
    verification: []
    human_judgment: true
    rationale: "Whether a documented-defect marker is an acceptable before baseline for that slug (versus blocking the capture until the template is fixed) is a product call for the phase owner; plan 05 is the immutable capture."

duration: 35min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 03: Raw Inputs for the Before Catalog Summary

**Tier 2 (20 example admin pages on seeded .test personas, timestamps pinned in SQL at the source) and the generated lane (5 anonymous auth pages and 18 email builders from one fresh generated host) are now dumped as raw text, with the one real adopter defect they hit recorded instead of hidden.**

## Performance

- **Duration:** 35 min (start 2026-11-15T18:27:44Z, end 19:02Z)
- **Tasks:** 3 (Task 1 tracer, Task 2 TDD, Task 3 auto)
- **Files:** 3 (1 test file created, 1 script modified, 1 phase log created); nothing under `lib/` or `priv/`

## Accomplishments

- `ExampleWeb.CatalogTest` renders every tier-2 page through the real router as the seeded admin persona and writes raw html to `<SIGRA_CATALOG_RAW_DIR>/tier2-example-admin/<slug>.html`. With the variable unset the same 23 tests are a plain smoke and write nothing (observed: the directory is not recreated).
- The pin is a single idempotent SQL pass run before every request. Dumps contain only `2026-01-01 00:00:NN` dates (124 date tokens, no other date, no 2099 band date because the dead render shows no invitation expiry today).
- `--test catalog` is an early exit after the boot readiness loop. The diff is 205 added lines and 0 removed lines; the `case "${TEST_TARGET}"` block is untouched.
- Generated emails are built with a `.test` sender override, an explicit fixed `time:` in every details map, fixed `https://host.example.test/...` URLs and `PORT=4000` pinned for the build, so two runs and two different caller ports produce byte-identical emails (diffed).

## Final slug lists and exact paths

**Tier 2 (20), lane `library-admin (example-mirror shell)`**, state personas resolved from `Example.Demo.Personas.all/0` by their flags (active = alice, locked = dave, unconfirmed = dave, scheduled-deletion = frank, zero-state = zoe, org = the admin persona's owner membership, `acme-corp`):

| Slug | Path |
| --- | --- |
| `admin-overview` | `/admin` |
| `admin-users-index` | `/admin/users` |
| `admin-user-show-{active,locked,unconfirmed,scheduled-deletion,zero-state}` | `/admin/users/<persona id>` |
| `admin-user-sessions-{...same five}` | `/admin/users/<persona id>/sessions` |
| `admin-user-audit-{...same five}` | `/admin/users/<persona id>/audit` |
| `admin-audit-index` | `/admin/audit` |
| `admin-auth-branding` | `/admin/auth-branding` |
| `admin-org-acme` | `/admin/organizations/acme-corp` |

`unconfirmed` and `locked` render the same account: the seeds carry a single unconfirmed persona and it is also the locked one.

**Generated pages (5), dead renders, no redirects followed:** `log-in` (`/users/log_in`, 200), `register` (`/users/register`, 200), `reset-password` (`/users/reset-password`, **500**, see Issues), `reset-password-invalid-token` (`/users/reset-password/catalog-invalid-token`, 200), `confirm` (`/users/confirm`, 200).

**Generated emails (18):** `confirmation`, `reset-password`, `magic-link`, `suspicious-login` (the four required), plus `backup-code-used`, `deletion-cancelled`, `deletion-finalized`, `deletion-scheduled`, `email-changed`, `enterprise-sso-reset`, `lockout-notification`, `mfa-disabled`, `mfa-enabled`, `mfa-lockout`, `oauth-reset`, `organization-invitation`, `passkey-registration`, `password-changed`. Each file is `Subject:`, `To:`, `From:` header lines, then `=== HTML ===` plus the html body, then `=== TEXT ===` plus the text body. Left out: `email_change_confirmation_email/3` and `email_change_notification_email/3` (a sentence ends with the address plus a period, which the plan's literal address scan flags).

## Task Commits

1. **Task 1: tracer, users index on a seeded persona dumped raw** - `4b52c3c29` (feat)
2. **Task 2: full tier-2 page set (TDD)** - RED `bec8b1035` (test), GREEN `029ddb42d` (feat)
3. **Task 3: `--test catalog` in the smoke script** - `bcc42edbf` (feat)

**Plan metadata:** docs commit (SUMMARY, deferred items, STATE, ROADMAP, REQUIREMENTS).

## TDD Gate Compliance

Task 2 is `tdd="true"` inside an `execute` plan; `workflow.tdd_mode` is not enabled and ExUnit console output is not a report format `gsd_run check tdd-red-evidence` classifies, so there is no classifier record and the assessment below is semantic.

- **RED** (`bec8b1035`): 21 tests, 8 failures. Each failing test executed and failed on the planned assertion, `captured |> Map.keys() |> Enum.sort() == Enum.sort(expected_slugs(group))` with `left: []`, or the whole-set slug-list assertion with `left: ["admin-users-index"]`. The registry still held only the tracer page, so this is the missing behavior, not a compile or fixture fault. The persona-replacement, address-scan, placeholder-mask and comparison-scrub controls and the idempotency test passed in RED (they test helpers that existed or are satisfied by one page); a comparison-scrub control that used an unrealistic per-render id was fixed before the RED commit.
- **GREEN** (`029ddb42d`): registry, state-persona resolution and organization resolution added; 23 tests green, and the full example suite (419 tests) green.

## Positive controls (each observed red against a deliberately broken source, restored byte-identical with `cmp`)

- Capture-stamp replacement by pattern instead of exact value: only the stamp control failed.
- Run-day rule disabled: first attempt stayed green because the planted token also tripped the reference-date rule (a weak control of my own); the control was rebuilt so the run-day rule fires on its own (a seed-era date equal to the injected run day), then observed red.
- Reference-date rule disabled: the matching control failed.
- Pin ordering replaced by `random()`: the two-pass idempotency test and the users-index test failed.
- Pin ordering reverted to `(value, ctid)` on a reused heap: the creation-order test failed on 2 of 3 full-suite runs (see Deviation 1).

## Decisions Made

See `key-decisions`. In short: ties by insertion command id, the capture-session stamp is the only exact-value replacement, the reset request page is a pinned documented 500, and both lanes override the branding sender for the capture only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tier-2 pin ordering was heap-order dependent**
- **Found during:** Task 2, running the full example suite (the tracer file passed alone)
- **Issue:** The plan's `(current value, ctid)` rank broke ties by heap position. `users.inserted_at` has one-second precision, so the seeded users tie, and ctid drifts after earlier tests leave dead tuples. After a few suite runs the persona rows left page one of the users index (the new users-index test failed on the full suite while passing standalone).
- **Fix:** rank by `(value, cmin, ctid)`; added a creation-order test and an idempotency test on the DB.
- **Verification:** reproduced the failure by running the old ordering through the full suite until it broke (5th run), then 6 consecutive full-suite runs on the same dirty table were correct with the fix; the creation-order test fails on the old ordering on a dirty heap.
- **Files modified:** `test/example/test/example_web/catalog_test.exs`
- **Committed in:** `029ddb42d`

**2. [Rule 2 - Missing critical] Branding page exposed a non-.test address**
- **Found during:** Task 2
- **Issue:** the auth branding page prints the host default sender as a form value (`noreply@example.com`), and the plan forbids any non-.test address in the raw directory.
- **Fix:** capture-only override of `:example, :sigra_config` branding to `noreply@catalog.example.test`, restored on exit, plus an exact mask of the shipped sign-in preview literal to `{{PREVIEW_EMAIL}}` (the token plan 02's normalizer uses, so its own mask stays a no-op).
- **Commit:** `029ddb42d`

**3. [Rule 3 - Blocking] The generated reset-password request page is a real 500**
- **Found during:** Task 3
- **Issue:** `GET /users/reset-password` raises `CaseClauseError` at `ResetPasswordLive.mount/3` on every fresh `--live` host (route without a live action). The plan says to fail loudly on any non-200 and expects a rendered `reset-password.html`; `lib/` and `priv/` may not change, so it cannot be fixed here.
- **Fix:** expected status is pinned per page. A 500 is accepted only when the dev error page carries the exact signature, the error page (which holds local paths) is replaced by a one-line marker comment, and the script prints `KNOWN:`. If the template is fixed the status becomes 200 and the script fails until the entry is changed. Logged in `260-deferred-items.md`. The phase owner may prefer to block plan 05 on the fix instead; that is why D5 is a human-judgment deliverable.
- **Commit:** `bcc42edbf`

**4. [Rule 3 - Blocking] Emails embed `Endpoint.url()`, which reads `PORT`**
- **Found during:** Task 3 determinism diff
- **Issue:** dumped emails carried whichever port the caller chose.
- **Fix:** `PORT=4000` pinned for the email build only (no server starts in that process). Verified byte-identical across two outer ports.
- **Commit:** `bcc42edbf`

### Implementation choices that differ from the plan's literal wording

- **Two-pass idempotency test compares in-memory masked pages, not raw bytes.** Raw pages differ per render by csrf and `phx-` ids by construction; the dumps stay raw (the root normalizer owns those), only the comparison masks them.
- **The verify command for Task 3 was run without `source tmp/db.env`.** See Issues.
- **Two optional email builders left out** (see slug list).
- **`organization_invitations.expires_at` is pinned although the seeds already use constants** (2099-06-30 and 2026-01-01). The plan listed it; no page renders it today, so it is defensive.

**Total deviations:** 4 auto-fixed (1 bug, 1 missing-critical, 2 blocking) plus the choices above. **Impact:** all acceptance criteria met; D5 needs an owner call before plan 05.

## Issues Encountered

- **`source tmp/db.env` breaks the smoke script here.** With it exported, `mix ecto.drop`/`ecto.create` follow `PGPORT` (dockerized Postgres) while the generated `Repo` connects to `localhost:5432`, so the first migrate hit a stale `sigra_admin_smoke_test` on 5432 (`duplicate_table`). First attempt failed on this; after unsetting the `PG*` and `SIGRA_TEST_PG_*` variables all three commands target 5432 and the run passed. A stray empty `sigra_admin_smoke_test` database created on the docker Postgres by the failed attempt was dropped. Pre-existing script behavior, logged in `260-deferred-items.md`; plan 05 should run the target the same way.
- A one-off experiment inserted and deleted 4000 committed rows in the example test database's `auth.users` to create reusable heap space, then `VACUUM FULL` reset it; nothing is left behind.
- The `Seeds.run/0` credentials banner prints during the example suite; the new test captures its own call.

## Authentication Gates

None.

## Known Stubs

None. The `reset-password` marker is a deliberate record of a shipped defect, not a placeholder for missing work.

## Threat Flags

None. The only new surface is a script branch that writes under `tmp/`; no endpoint, auth path or schema changed. T-260-08: the address, run-day, path and secret scans over the raw directory are clean and each scan has a planted positive control. T-260-09: the smoke script diff has 0 removed lines and the catalog branch is guarded by exact string equality (full `--test all` re-run is plan 11).

## Verification Run

| Check | Result |
| --- | --- |
| `cd test/example && MIX_ENV=test SIGRA_CATALOG_RAW_DIR=... mix test --include example_app test/example_web/catalog_test.exs` | 23 tests, 0 failures, 20 files written |
| same, `SIGRA_CATALOG_RAW_DIR` unset | 23 tests, 0 failures, nothing written |
| `cd test/example && MIX_ENV=test mix test --include example_app` | 419 tests, 0 failures |
| `mix format --check-formatted test/example/test/example_web/catalog_test.exs` | exit 0 |
| `git status --porcelain -- lib priv` | empty |
| `scripts/ci/admin-acceptance-smoke.sh --test catalog` | exit 0, 5 pages, 18 emails |
| address scan (plan's literal command), run-day scan, path/secret scan over `generated-host` | clean; positive control prints `a@b.com` |
| `git diff --numstat` / removed lines for the script | 205 added, 0 removed |
| contract tests reading the script | 31 ExUnit tests, 3 node tests, `phase34-uat-contracts.sh` green |

Commit ledger (measured): `plan_head_before` `0d42289ce6faee4ca499385938ac2fe26944ef8c`, `plan_head_after` `bcc42edbf6494f7522836bba6b7de11d1d081cbd`, `git rev-list --count` = 4. `actuals.tokens` is chars/4 over the added diff lines (34,609 bytes / 4 = 8,652) against a plan estimate of 60,000; not rounded toward the estimate.

## Handoff for Plans 05, 08 and 11

- Raw layout is exactly the shared contract: `tmp/catalog-raw/tier2-example-admin/<slug>.html`, `generated-host/pages/<slug>.html`, `generated-host/emails/<slug>.txt`. Raw size is about 416 KB (tier 2) and 156 KB (generated host).
- Plan 05's manifest `coverage` text should add: the tier-2 branding page's sender field is overridden for the capture (as the generated emails are); `generated-host-pages/reset-password.html` is a marker for a shipped 500, and `deferred_shipped_byte_fixes` should name the reset request page fix; the capture session activity stamp is the only exact-value replacement.
- Run the smoke target without `tmp/db.env` exported (see Issues). The example catalog test does need `source tmp/db.env`.
- The tier-2 dumps keep non-persona UUIDs, csrf values, `phx-` ids and relative text raw by design; plan 05 asserts the normalized output is free of them. If a per-render id shape appears that the root normalizer does not cover, it is the root normalizer's rule to add (this test's comparison scrub covers `mg-<n>-...-<n>` only with a stable first number).
- The creation-order and idempotency pin tests are live in `catalog_test.exs`; a new displayed wall-clock column fails the clock control by naming the page and token and joins `@pin_columns`.

## Next Phase Readiness

Plan 05 (the single immutable capture) has both raw inputs. Decide D5 first: either accept the reset-page marker as the baseline or hold the capture until the template is fixed.

## Self-Check: PASSED

- Created and modified files exist (`[ -f ]`): `test/example/test/example_web/catalog_test.exs`, `scripts/ci/admin-acceptance-smoke.sh`, `260-deferred-items.md`.
- All four production commits (`4b52c3c29`, `bec8b1035`, `029ddb42d`, `bcc42edbf`) are ancestors of HEAD (`git merge-base --is-ancestor`).
- Task 1, 2 and 3 acceptance criteria re-run and passing; plan-level verification re-run after the last commit.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
