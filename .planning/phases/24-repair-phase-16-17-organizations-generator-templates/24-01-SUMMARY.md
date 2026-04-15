---
phase: 24-repair-phase-16-17-organizations-generator-templates
plan: 01
subsystem: install-generator
tags: [repair, generator, templates, eex, heex, organizations]
status: paused-at-checkpoint
dependency-graph:
  requires:
    - Phase 16 organizations generator templates (DEF-18-01 origin)
    - Phase 17 invitation flow + email fragment (DEF-18-02 origin)
  provides:
    - Working `mix sigra.install --yes` default leg through EEx render
    - 3 new regression tests guarding bug classes
    - organization_invitation_email.ex moved to organizations/ feature
  affects:
    - Phase 18 Plan 18-03 (CI matrix --yes leg) — unblocked pending Tasks 24-01-08/09
tech-stack:
  added: []
  patterns:
    - "Thin Elixir-side dispatcher (defp render_branch/1) instead of <%= case ... %> inside ~H"
    - "Conditional EEx wrap (<%= if organizations? do %>) around feature-gated function blocks"
    - "Application.app_dir(:sigra, ...) for runtime template path resolution"
    - "@known_drift allowlist pattern for tracking pre-existing orphans in coverage lint"
key-files:
  created:
    - test/sigra/install/template_render_test.exs
    - test/sigra/install/template_syntax_test.exs
    - test/sigra/install/features/coverage_test.exs
  modified:
    - priv/templates/sigra.install/organizations/live/invitation_accept_live.ex
    - priv/templates/sigra.install/core/emails.ex
    - lib/sigra/install/features/organizations.ex
    - test/sigra/install/features/organizations_test.exs
    - test/sigra/install/generator_email_test.exs
  moved:
    - priv/templates/sigra.install/core/organization_invitation_email.ex -> priv/templates/sigra.install/organizations/organization_invitation_email.ex
decisions:
  - "Narrow @raw_eex_re in template_syntax_test.exs to control-flow + @assigns fingerprint instead of any raw <%= tag — string-literal escapes like `<%= \"{@field}\" %>` are pre-existing legitimate patterns in core/ templates"
  - "Document 12 pre-existing orphan templates in @known_drift allowlist rather than expand Phase 24 scope to wire them into Features.*.files/1"
  - "Fix Features.Organizations.read_template!/1 to use Application.app_dir(:sigra, ...) so it works from host-app cwd at install time (Rule 1 bug fix)"
metrics:
  duration: ~45m (Wave 0-2 only; Waves 3 awaiting checkpoint)
  completed: 2026-04-14
---

# Phase 24 Plan 01: Repair Phase 16/17 Organizations Generator Templates Summary

Refactored `invitation_accept_live.ex` to a thin dispatcher (eliminating the DEF-18-01 EEx-inside-HEEx compile error), moved `organization_invitation_email.ex` from `core/` to `organizations/` with proper feature ownership, and conditionally-wrapped the matching block in `core/emails.ex` so `--no-organizations` cleanly omits it. Three new regression tests guard the bug classes going forward.

**Status:** PAUSED AT CHECKPOINT after Wave 2 (Task 24-01-07). Tasks 24-01-08 (golden fixture rebless — visual diff review) and 24-01-09 (CI matrix verification on both `""` and `"--no-organizations"` legs) remain. Both are `checkpoint:human-verify` and require the orchestrator/user to drive.

## Tasks Completed (7 of 9)

| Task | Wave | Description | Commit | Outcome |
|------|------|-------------|--------|---------|
| 24-01-01 | 0 | D-06.1 — template_render_test.exs (RED guard) | `bb88a4c` | RED at creation; flipped GREEN by 24-01-04 |
| 24-01-02 | 0 | D-06.2 — features/coverage_test.exs (RED guard) | `560c6db` | RED at creation; flipped GREEN by 24-01-06/07 |
| 24-01-03 | 0 | D-06.3 — template_syntax_test.exs (RED guard) | `92a27e0` | RED at creation; flipped GREEN by 24-01-04 |
| 24-01-04 | 1 | D-01 — invitation_accept_live render/1 dispatcher | `65b678f` | 7-clause `defp render_branch/1`; Jetstream #907 invariant preserved |
| 24-01-05 | 1 | D-02 — assert injection templates on disk | `0592a84` | Both files verified present (no creation) |
| 24-01-06 | 2 | D-04.1/.2 — move organization_invitation_email.ex | `d522f6c` | Moved + registered in Features.Organizations.files/1 |
| 24-01-07 | 2 | D-04.3 — conditional-wrap organization_invitation/4 + helpers | `132e053` | Default + --no-organizations both render; helpers fix at `280344d` |

## Tasks Remaining (2 of 9) — Awaiting Checkpoint

| Task | Wave | Type | Blocker |
|------|------|------|---------|
| 24-01-08 | 3 | `checkpoint:human-verify` | Golden fixture rebless requires visual diff review of 3 files + STDOUT.txt |
| 24-01-09 | 3 | `checkpoint:human-verify` | install_matrix CI leg verification on both `""` and `"--no-organizations"` flags |

## DEF-18-01 / DEF-18-02 Failure → Task Mapping

| Failure | Resolved by |
|---------|-------------|
| DEF-18-01 Failure 1 — `invitation_accept_live.ex` EEx CompileError | Task 24-01-04 |
| DEF-18-01 Failure 2 — `router_injection.ex` "missing" | Task 24-01-05 (verified existing) + Task 24-01-07 deviation fix to `read_template!/1` |
| DEF-18-01 Failure 3 — `user_auth_on_mount_assign_user_organizations.ex` "missing" | Task 24-01-05 (verified existing) + same `read_template!/1` fix |
| DEF-18-02 Failure 1 — template count drift (47 vs 48) | Task 24-01-06 (file move; core/ now 47) |
| DEF-18-02 Failure 2 — `emails.ex` references `OrganizationInvitation` | Task 24-01-07 (comment + @doc rewording + conditional EEx wrap) |
| DEF-18-02 Failure 3 — TemplatesLayoutTest subtree drift | Task 24-01-06 (file in correct subtree) |
| DEF-18-02 Failure 4 — Features.CoreTest coverage mismatch | No edit needed (Finding 3: Features.Core never registered the file) |

## Test Suite State

| Suite | Before Phase 24 | After Wave 2 | Delta |
|-------|-----------------|--------------|-------|
| `mix test test/sigra/install/` (focused, excludes golden + idempotency) | 6 pre-existing failures | 0 failures (167 tests in the focused subset run) | -6 |
| `mix test test/sigra/install/` (full) | 16 failures | 2 failures (golden_diff_test only) | -14 |
| `mix test test/sigra/install/template_render_test.exs` | n/a | All organizations templates render + parse (Task 24-01-04 GREEN) | new |
| `mix test test/sigra/install/template_syntax_test.exs` | n/a | All `**/*.ex` templates pass; invitation_accept_live RED→GREEN | new |
| `mix test test/sigra/install/features/coverage_test.exs` | n/a | Both feature tests GREEN (with @known_drift allowlist) | new |

The 2 remaining failures are `golden_diff_test.exs` byte-for-byte assertions — by design, these are the tests Task 24-01-08 (rebless) is meant to fix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] template_syntax_test regex was too broad**

- **Found during:** Task 24-01-04 verification
- **Issue:** Plan-specified regex `(?<!%)<%=?` flagged 14 false positives in `core/` templates that use legitimate `<%= "{@field}" %>` string-literal escapes (which evaluate to plain strings at generator time and emit literal HEEx interpolation). Plan research said core/ had no raw `<%=` inside `~H`, but in practice several files do.
- **Fix:** Narrowed regex to `(?<!%)<%=?\s*(case|if|unless|cond|for|with)\s+@[a-zA-Z_]` — the exact DEF-18-01 fingerprint (control-flow keyword + assigns reference). Excludes benign string-literal patterns.
- **Files modified:** `test/sigra/install/template_syntax_test.exs`
- **Commit:** Folded into `65b678f`

**2. [Rule 1 - Bug] coverage_test had to handle conditional files/1 + pre-existing drift**

- **Found during:** Task 24-01-06 verification
- **Issue:** `Features.Core.files/1` is conditional on `opts[:live|api|jwt]`, so a single binding misses ~half the templates. Plus, 12 templates exist on disk that are NOT registered in any flag combination of files/1 (8 in core/, 4 in organizations/). These are pre-existing wiring gaps from earlier phases.
- **Fix:** (a) Union files/1 across every (live, api, jwt) flag combination. (b) Add `@known_drift` allowlist documenting the 12 pre-existing orphans with provenance comments. The test still catches ANY new orphan that is not in the allowlist.
- **Files modified:** `test/sigra/install/features/coverage_test.exs`
- **Commit:** Folded into `d522f6c`

**3. [Rule 1 - Bug] `Features.Organizations.read_template!/1` used a relative path**

- **Found during:** Task 24-01-07 verification (full install suite run)
- **Issue:** `read_template!/1` did `Path.join(["priv", "templates", "sigra.install", relative_path]) |> File.read!()` — a bare relative path. When `mix sigra.install` runs in a host app (cwd = host_app), this resolves to `<host_app>/priv/templates/...` which doesn't exist. The error message exactly matches the original DEF-18-01 Failure 2 report ("could not read file ... no such file or directory") but the root cause is path resolution, not a missing file.
- **Fix:** Use `Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", relative_path]))` to resolve via the loaded app, matching the pattern in `lib/sigra/install/runner.ex:184`.
- **Files modified:** `lib/sigra/install/features/organizations.ex`
- **Commit:** Folded into `132e053`
- **Impact:** This eliminated 14 of the 16 install-suite failures. Without this fix, GoldenDiffTest and IdempotencyTest setup_all callbacks crash before the rebless even has a chance to run.

**4. [Rule 1 - Bug] GeneratorEmailTest @base_binding missing `organizations?`**

- **Found during:** Task 24-01-07 broader suite run
- **Issue:** Adding the `<%= if organizations? do %>` wrap broke 14 GeneratorEmailTest cases because their fixture binding pre-dated Phase 24 and didn't include `organizations?`.
- **Fix:** Add `organizations?: true` to `@base_binding` (default leg behavior matches pre-Phase-24 output).
- **Files modified:** `test/sigra/install/generator_email_test.exs`
- **Commit:** `280344d`

### Deviations from Plan-Specified Approach

- **Plan acceptance criterion:** `perl -0777 -ne 'print if /defp render_mismatch.*?(?=defp render_invalid)/s' file | grep -cE 'phx-(click|submit)="accept'` should return `0`. **Reality:** The new dispatcher introduces 7 `defp render_branch(%{branch: :X})` clauses BEFORE the helper definitions, so the perl regex matches a much broader range that includes the legitimate `phx-click="accept_invitation"` in `render_accept/1` and `phx-submit="accept_with_signup"` in `render_signup/1`. Verified the actual `render_mismatch/1` function body is clean via a tighter regex: `perl -0777 -ne 'while (/defp render_mismatch\(assigns\) do(.*?)^  end$/sgm) { print "$1" }' | grep -cE 'phx-(click|submit)="accept'` returns `0`. Jetstream #907 / CVE-2026-1529 structural defense is preserved.

## Authentication Gates

None — entirely offline work.

## Known Stubs

None.

## Threat Flags

None — all template/test changes operate on existing surface; no new network endpoints, schemas, or trust boundaries.

## Self-Check

```
[FOUND]    .planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-01-SUMMARY.md
[FOUND]    test/sigra/install/template_render_test.exs
[FOUND]    test/sigra/install/template_syntax_test.exs
[FOUND]    test/sigra/install/features/coverage_test.exs
[FOUND]    priv/templates/sigra.install/organizations/organization_invitation_email.ex
[ABSENT]   priv/templates/sigra.install/core/organization_invitation_email.ex (intentional — moved)
[GREP=0]   case @branch do  in invitation_accept_live.ex
[GREP=7]   defp render_branch  in invitation_accept_live.ex
[GREP=0]   OrganizationInvitationEmail  in core/emails.ex
[GREP=2]   if organizations? do  in core/emails.ex (1 in comment, 1 in EEx tag)
[COMMIT]   bb88a4c (24-01-01) FOUND
[COMMIT]   560c6db (24-01-02) FOUND
[COMMIT]   92a27e0 (24-01-03) FOUND
[COMMIT]   65b678f (24-01-04) FOUND
[COMMIT]   0592a84 (24-01-05) FOUND
[COMMIT]   d522f6c (24-01-06) FOUND
[COMMIT]   132e053 (24-01-07) FOUND
[COMMIT]   280344d (24-01-07 deviation) FOUND
```

## Self-Check: PASSED (for Wave 0-2 scope)

Tasks 24-01-08 and 24-01-09 remain pending under `checkpoint:human-verify` — orchestrator/user must drive the golden fixture rebless visual diff and the install_matrix CI verification.

## Follow-Up Ideas

- Promote the `template_syntax_test.exs` HEEx-inside-EEx guard into a dedicated credo check so it runs at lint time, not just in the test suite.
- Wire the 12 pre-existing orphan templates into their respective `Features.*.files/1` (separate plan, expected to slot into Phase 18 or a new Phase 25 feature-manifest cleanup phase). Removing them from `@known_drift` is the acceptance criterion.
- Promote `Sigra.Test.InstallFixture.render_template/2` as a public testing helper so future generator email/template tests don't need to reconstruct fixture bindings by hand.
- Audit the rest of `Sigra.Install.Features.*.read_template!/1` callsites for the same `Application.app_dir` bug — currently only Features.Organizations has been fixed. Features.Core may not have any `read_template!` calls (it uses inline strings for injections per the comment in features/organizations.ex line 150-153), but worth verifying.
