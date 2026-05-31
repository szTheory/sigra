# Sigra 1.0 Release Runbook

Canonical maintainer procedure for cutting and verifying the public Hex `1.0.0` release.
This document is the single source of truth for release gates, evidence, recovery, and first-14-day hotfix policy.

## Release Gate Matrix

| Gate | Workflow/job or command | Ref rule | Required evidence | Waiver rule (only if not runnable on release ref) |
|------|--------------------------|----------|-------------------|----------------------------------------------------|
| Library tests | `CI` / `library_tests` | release tag | `Gate=library_tests`, run URL, run id, pass status | If unavailable on tag, record: `gate`, `reason`, `approver`, `evidence URL`, `expiry` |
| Install golden/idempotency | `CI` / `install_golden_contract` | release tag | `Gate=install_golden_contract`, run URL/log, pass status | Same waiver fields required |
| Install smoke | `CI` / `install_smoke` | release tag | `Gate=install_smoke`, run URL/log, pass status | Same waiver fields required |
| Example HTTP smoke | `CI` / `example_http_smoke` | release tag | `Gate=example_http_smoke`, run URL/log, pass status | Same waiver fields required |
| Example Playwright smoke | `CI` / `example_playwright_smoke` | release tag | `Gate=example_playwright_smoke`, run URL/log, pass status | Same waiver fields required |
| Generated admin Playwright smoke | `CI` / `generated_admin_playwright_smoke` | release tag | `Gate=generated_admin_playwright_smoke`, run URL/log, pass status | Same waiver fields required |
| Dep-off lane | `CI` / `library_tests_dep_off` | release tag | `Gate=library_tests_dep_off`, run URL/log, pass status | Same waiver fields required |
| Release metadata truth | `Release Please` outputs `tag_name` + `version` and manifest check | pre-merge main evidence | Release PR/run URL proving `tag_name`, `version`, and `.release-please-manifest.json` alignment | If metadata proof cannot be generated, capture waiver fields |
| Dry-run and package inspection | `mix hex.build --unpack --output sigra-hex-inspect` and `mix hex.publish --dry-run --yes` | release tag | command logs + artifact listing for unpacked package | If run blocked on ref, capture waiver fields |
| Hex publish (manual recovery) | `Hex publish (manual recovery)` workflow | release tag | run URL showing inputs `tag` and `release_version`, pass status | If unavailable, waiver fields required |
| Hex visibility | `curl -fsS https://hex.pm/api/packages/sigra/releases/1.0.0` | manual post-publish | API response/log proving version is visible | If endpoint unreachable, waiver fields required and retry plan |
| HexDocs/source-link truth | Verify HexDocs page + `source_ref: "v#{@version}"` behavior | manual post-publish | URL showing docs version + source link resolving to `v1.0.0` | If HexDocs lagging, waiver fields required plus follow-up check window |

Ref rule values are strict and limited to: `release tag`, `pre-merge main evidence`, or `manual post-publish`.

## Release Evidence Checklist

Use one row per gate and do not publish until required rows are complete.

| Gate | Workflow/job or command | Release ref | Evidence URL or log | Reviewer | Waiver? | Notes |
|------|--------------------------|-------------|---------------------|----------|---------|-------|
| library_tests | `CI` / `library_tests` | `v1.0.0` |  |  |  |  |
| install_golden_contract | `CI` / `install_golden_contract` | `v1.0.0` |  |  |  |  |
| install_smoke | `CI` / `install_smoke` | `v1.0.0` |  |  |  |  |
| example_http_smoke | `CI` / `example_http_smoke` | `v1.0.0` |  |  |  |  |
| example_playwright_smoke | `CI` / `example_playwright_smoke` | `v1.0.0` |  |  |  |  |
| generated_admin_playwright_smoke | `CI` / `generated_admin_playwright_smoke` | `v1.0.0` |  |  |  |  |
| library_tests_dep_off | `CI` / `library_tests_dep_off` | `v1.0.0` |  |  |  |  |
| Release Please metadata truth | `Release Please` outputs + manifest checks | `main` release PR evidence |  |  |  |  |
| Dry-run + package inspection | `mix hex.build --unpack --output sigra-hex-inspect` + `mix hex.publish --dry-run --yes` | `v1.0.0` |  |  |  |  |
| Hex publish (manual recovery) | Workflow dispatch run | `v1.0.0` |  |  |  |  |
| Hex visibility | Hex API check | post-publish `v1.0.0` |  |  |  |  |
| HexDocs/source-link checks | HexDocs and source link checks | post-publish `v1.0.0` |  |  |  |  |

Evidence capture command snippets:

```bash
gh workflow run "CI" --ref v1.0.0
gh run list --workflow "CI" --limit 5
gh run view <run-id> --log
gh run watch <run-id> --exit-status
gh release view v1.0.0 --json tagName,targetCommitish,url
gh workflow run "Hex publish (manual recovery)" -f tag=v1.0.0 -f release_version=1.0.0
mix hex.build --unpack --output sigra-hex-inspect
mix hex.publish --dry-run --yes
curl -fsS https://hex.pm/api/packages/sigra/releases/1.0.0
```

## Dry Run And Package Inspection

Required checks before publish:

1. `mix.exs` `@version` is `1.0.0`.
2. Release Please outputs agree: `tag_name=v1.0.0` and `version=1.0.0`.
3. `.release-please-manifest.json` points `.` to `1.0.0`.
4. GitHub release/tag exists at `v1.0.0` and points to expected commit.
5. `mix.exs` docs config still uses `source_ref: "v#{@version}"`.
6. `mix hex.build --unpack --output sigra-hex-inspect` contains expected package files and excludes `.planning`.
7. `mix docs --warnings-as-errors` passes.
8. `mix hex.publish --dry-run --yes` passes with no unresolved blockers.

Any failure in these checks blocks publish.

## Publish Paths

Default publish path: `Release Please` (Release PR merge creates tag/release and runs publish flow).

Primary no-invention recovery path: `Hex publish (manual recovery)` with required inputs:

- `tag` must be `v1.0.0` or exact release SHA.
- `release_version` must be `1.0.0`.

Local trusted-machine publish is fallback only. If fallback is used, maintainers must preserve the same truth checks as automation: tag/version alignment, manifest alignment, `source_ref` check, package inspection, dry-run evidence, and post-publish visibility checks.

## Post-Publish Visibility

After successful publish, verify:

1. Hex package visibility: `curl -fsS https://hex.pm/api/packages/sigra/releases/1.0.0`.
2. Hex package page shows `1.0.0`.
3. HexDocs for `1.0.0` is available.
4. Source links resolve to tagged source via `source_ref: "v#{@version}"`.
5. Evidence checklist rows for manual post-publish checks are complete with reviewer sign-off.

## Recovery Decision Tree

- Dry-run failure (`mix hex.publish --dry-run --yes` fails):
  - Do not publish.
  - Fix root cause, rerun package inspection and dry-run, then continue.
- Publish failure before Hex visibility:
  - Retry via `Hex publish (manual recovery)` using validated `tag` and `release_version`.
  - Re-verify `mix.exs @version`, `release-please-manifest`, and `source_ref` checks before retry.
- Docs/source-link issue after package is visible:
  - Use docs republish path or a focused follow-up fix, then verify links again.
- Incorrect public package outcome:
  - If inside allowed Hex window, use `mix hex.publish --replace` or `mix hex.publish --revert` as applicable.
  - Documented windows: 24 hours for a brand-new package release, and 1 hour for replacing or reverting an existing package version.
  - If outside allowed windows, cut a follow-up patch release; do not invent untracked overrides.

## First 14 Days Hotfix Policy

Scope: first 14 calendar days after public Hex publish of `1.0.0`.

Severity classes:

- `P0`: security-sensitive auth/session/token/MFA/passkey regression.
- `P1`: install/compile/generated-host boot/docs-source-link/package-truth blocker.
- `P2`: serious adopter-blocking regression without workaround.
- `P3`: non-blocking bug or docs polish.

Triage timing:

- `P0` and `P1`: same business day.
- `P2`: within 24 hours.
- `P3`: next planned patch window.

Minimum evidence for every hotfix intake:

- Repro command and ref.
- Failing run URL or log.
- Affected version(s).
- Workaround status (available/unavailable).

Patch decision boundaries:

- Immediate patch/recovery consideration: `P0`, `P1`, and `P2` without viable workaround.
- `P3` or issues with acceptable workaround: batch into planned patch release.
- Deferred feature ideas remain out of scope during this 14-day window.

Communication posture:

- Keep updates factual and version-specific.
- State impact, workaround status, and next decision checkpoint.
- Avoid implying unsupported guarantees beyond documented release evidence.

## Post-1.0 Release Please Cleanup

- [ ] After the `1.0.0` Release PR merges and release is cut, remove or update `release-please-config.json` `release-as: "1.0.0"`.
- [ ] Confirm subsequent release planning returns to normal conventional-commit SemVer flow.

