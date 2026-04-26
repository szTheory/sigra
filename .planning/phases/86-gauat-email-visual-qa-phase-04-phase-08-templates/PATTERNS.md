# Phase 86 Pattern Map

Mapped: 2026-04-26

## Target files

| Planned file | Role | Data flow | Nearest analog | Match |
|---|---|---|---|---|
| `test/example/test/support/email_assertions.ex` | test helper | transform | `test/example/test/support/conn_case_helpers.ex` | role-match |
| `test/example/test/example/accounts/emails_security_html_test.exs` | test | request-response | `test/example/test/example/accounts/emails_security_html_test.exs` | exact |
| `test/example/test/example/accounts/emails_lifecycle_html_test.exs` | test | request-response | `test/example/test/example/accounts/emails_lifecycle_html_test.exs` | exact |
| `test/example/priv/playwright/tests/email-visual.spec.ts` | Playwright spec | snapshot/transform | `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | role-match |
| `test/example/priv/playwright/fixtures/*.ts` | Playwright fixture/helper | polling/file-I/O | `test/example/priv/playwright/fixtures/mailbox.ts` | role-match |
| `lib/mix/tasks/sigra.email.snapshot.ex` | Mix task | file-I/O/batch | `lib/mix/tasks/sigra.fixture.rebless_golden.ex` | close |
| `.github/workflows/ci.yml` `email_visual_regression` job | CI job | batch/artifact | `.github/workflows/ci.yml` admin Playwright jobs | exact pattern |
| `.planning/uat-evidence/v1.20/.../README.md` | planning doc | evidence/pointer | `.planning/uat-evidence/v1.4/GA-01-pointer/README.md` | close |
| `.planning/uat-evidence/v1.20/.../INDEX.md` | planning doc | evidence/index | `.planning/uat-evidence/v1.4/INDEX.md` | exact pattern |
| `.planning/uat-evidence/v1.20/.../waiver.md` | planning doc | waiver schema | `.planning/uat-evidence/v1.4/GA-02/waiver.md` | exact pattern |

## Pattern assignments

### ExUnit helper modules

Copy module style from `test/example/test/support/conn_case_helpers.ex:1-57`.
- Small focused module with `@moduledoc`, public helper fns only, no macros.
- Keep deterministic helpers and import explicitly from tests.

Copy fixture/helper discipline from `test/example/test/support/fixtures/auth_fixtures.ex:40-117`.
- Helpers may bypass real boundaries, but say so in `@doc`.
- Keep deterministic data builders separate from route-backed coverage.

For email assertions, copy assertion style from:
- `test/example/test/example/accounts/emails_security_html_test.exs:25-64`
- `test/example/test/example/accounts/emails_lifecycle_html_test.exs:15-150`
- `test/example/test/example_web/emails/organization_invitation_email_test.exs:100-203`

Planner guidance:
- Keep AAA-flat ExUnit tests.
- Build stable sample structs/time literals in private helpers.
- Assert concrete HTML/text strings and multipart parity directly; avoid over-abstracting the call sites.

### Mix tasks

Primary analog: `lib/mix/tasks/sigra.fixture.rebless_golden.ex:1-251`.
- `use Mix.Task`, `@shortdoc`, detailed `@moduledoc` usage/examples.
- Parse opts with `OptionParser.parse/2` (`:check` mode is the key pattern).
- Force env/setup inside `run/1`: `Mix.env(:test)`, `Mix.Task.run("loadpaths")`, `Mix.Task.run("compile")`.
- Fail with `Mix.raise/1` for contract/setup errors and `exit({:shutdown, 2})` for drift-style CI failures.
- Print structured operator output through `Mix.shell().info/error`.

Secondary analog: `lib/mix/tasks/sigra.install.ex:69-163`.
- Keep `run/1` thin.
- Isolate validation and binding/build steps in private fns.

Planner guidance:
- The snapshot task should behave like a harness, not a generator.
- Prefer explicit tmp/output dirs and deterministic filenames.
- Add a `--check` or equivalent CI-safe mode instead of always mutating committed baselines.

### Playwright snapshot specs and fixtures

Spec analog: `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:86-145,147-255`.
- Single curated spec per artifact lane.
- Helper functions at top of file.
- Assert artifact existence after capture, not just that helper ran.
- Pair screenshot assertions with an accessibility gate when practical.
- Keep one authenticated journey instead of many isolated tests when startup is expensive.

Config analog: `test/example/priv/playwright/playwright.config.ts:38-147`.
- Serial execution: `workers: 1`, `fullyParallel: false`.
- `retries: process.env.CI ? 1 : 0` only.
- Snapshot `pathTemplate` pinned so committed baselines are stable across OS naming.
- Partition matrix with dedicated `projects` instead of duplicating spec logic.

Fixture analog: `test/example/priv/playwright/fixtures/mailbox.ts:1-52`.
- Keep fixtures as small polling helpers.
- Poll with bounded retries and throw explicit errors on missing evidence.
- Parse mailbox/content once, then return normalized URLs/data to the spec.

Planner guidance:
- New email snapshot spec should follow the admin-checkpoint shape, but with committed baselines instead of ad hoc reviewer PNGs.
- Use engine/theme projects in config, not theme toggles inside the spec.
- Freeze fixture data in one place and keep naming deterministic.

### CI jobs and artifact upload

Copy job structure from `.github/workflows/ci.yml:640-789`.
- Separate behavior run, artifact staging, final collection, bundle contract, and upload steps.
- Stage curated PNGs before another Playwright invocation clears `test-results/`.
- Use `cp -n` plus visible `src_count` logging to catch basename collisions.
- Split success review bundle from failure diagnostics.
- Express retention policy with two literal upload steps, `main` vs non-`main`.

Generated-host parity variant at `.github/workflows/ci.yml:791-908`.
- Install Node + browsers inside the job.
- Keep reviewer bundle upload always-on, diagnostics failure-only.

Planner guidance:
- `email_visual_regression` should mirror this seam: run, stage evidence, enforce a bundle contract, upload review artifact always, upload raw diagnostics only on failure.

### Evidence and verification docs

Index pattern: `.planning/uat-evidence/v1.4/INDEX.md:1-23`.
- Text-first evidence.
- Point to canonical matrix and CI workflow instead of duplicating large tables.
- Include SHA anchor and workflow anchor.

Pointer README pattern: `.planning/uat-evidence/v1.4/GA-01-pointer/README.md:1-13`.
- Treat CI paths/job ids as durable proof pointers.
- Be explicit about what is and is not proof.

Scoped README pattern: `.planning/uat-evidence/v1.4/GA-02/README.md:1-9`.
- Scope sentence.
- Machine baseline sentence.
- Human trigger sentence.
- Evidence filing sentence.

Waiver schema: `.planning/uat-evidence/v1.4/GA-02/waiver.md:1-14`.
- Keep fields `reason`, `compensating controls`, `residual risk`, `expiry_or_next_trigger`, `owner`, `date`.
- Keep claims narrow and evidence-linked.

## Anti-patterns to avoid

- Do not add a broad reusable assertion DSL for email tests. Existing repo style favors small support helpers plus explicit asserts at call sites.
- Do not make Playwright fully parallel or increase retries beyond `1` in CI. Current harness treats extra retries as masking flake.
- Do not rerun the full browser suite across every engine/theme. Use dedicated matrix projects for the narrow visual lane.
- Do not rely on whole `test-results/` as the primary green-run artifact. Curated evidence is the repo pattern; raw diagnostics are failure-only.
- Do not silently overwrite staged screenshots. Follow the `cp -n` + count/log pattern.
- Do not encode dark mode via interactive UI toggles when Playwright project config can set `colorScheme`.
- Do not duplicate UAT matrices inside phase evidence docs. Point to the canonical matrix and CI job ids.
- Do not overclaim manual-client parity from screenshots alone. Existing GA docs explicitly forbid that claim.
