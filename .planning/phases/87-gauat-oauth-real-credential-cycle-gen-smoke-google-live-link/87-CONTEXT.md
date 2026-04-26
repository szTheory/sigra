# Phase 87: GAUAT OAuth real-credential cycle — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning

<domain>

## Phase boundary

Phase 87 closes the OAuth slice of SEED-001 (items 3–6 = GAUAT-03/04/05/06) by **shifting verification fully left to automation**, mirroring Phase 86's reshape. The original framing — "human runs `mix sigra.gen.oauth` on a fresh host, clicks through real Google consent, captures screen recording, files staged screenshots of all four link/unlink states" — is replaced with a CI-reproducible harness whose green run on a tagged SHA is the audit-defensible evidence:

1. **GAUAT-03 (gen smoke):** Extend the existing `scripts/ci/install-smoke.sh` (which already does `mix phx.new` → `sigra.install` → `sigra.gen.oauth --providers google,github` → `mix compile --warnings-as-errors` → `mix ecto.migrate` on every PR) to additionally run `MIX_ENV=test mix test` on the generated host, emit an explicit `oauth-gen: 12/12 expected artifacts present, mix test green` log line, and tee the transcript to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` (uploaded as a CI artifact, promoted to GitHub release asset on `v*` tags — mirrors Phase 86 D-86-06).
2. **GAUAT-04/05/06 (Google live + linking + email-match):** A new in-process `Sigra.Testing.OAuthIssuer` (TestServer-backed, RS256 ID tokens, real PKCE verification, all five OIDC endpoints) drives Sigra's real Phoenix HTTP stack from three new Playwright specs (`oauth-register.spec.ts`, `oauth-link.spec.ts`, `oauth-email-match.spec.ts`) in the example app. Each spec's pass/fail row + per-cell DB probes + (for GAUAT-05's disabled-tooltip state) a single hero PNG snapshot are filed under `.planning/uat-evidence/v1.20/oauth-{google,link,email-match}/` using Phase 86's manifest schema verbatim.
3. **`mix sigra.oauth.smoketest --provider=google`:** A new Mix task ships in-library (NOT in the generator) that lets adopters verify their own Google `client_id`/`client_secret` at install time via a one-shot click-through on localhost. This is the **adopter-side** real-credential check, properly located in the adopter's environment with the adopter's credentials — paired with `docs/oauth-google-setup.md` (numbered Google Cloud Console recipe with screenshots).
4. **Milestone-scope edits folded into this discuss commit (Phase 86 D-86-08 pattern):** REQUIREMENTS.md GAUAT-03..06, ROADMAP.md Phase 87 success criteria + phase-summary bullet, `docs/uat-ci-coverage.md` SEED-001 row residual column, and CHANGELOG.md `[Unreleased]` are reworded in the same commit so the planner inherits the corrected scope without drift.

**Verdict: 0 human UAT for OAuth at v1.20 launch.** Stronger than a one-off human Google ceremony because it (a) runs every PR, not once at release, (b) is deterministic and reproducible from any SHA by any reviewer, (c) costs zero Google quota and zero banhammer risk, (d) matches the unanimous OSS convention (Assent itself, pow_assent, Auth.js, Spring Security, Devise+omniauth all mock at the issuer/strategy layer), (e) is the strongest SOC 2 Type II posture (continuous control evidence beats one-shot screenshot).

**Explicitly out of scope:** real Google in any Sigra-owned CI lane (banhammer/quota risk + unprecedented in mature OSS auth libs); a release-tag human ceremony (performative — strongest at launch, stale by v1.20.5; SOC 2 auditors don't scope one-time ceremonies); Litmus-style vendor OAuth verification services (none exist for OAuth analogous to email rendering); promotion of `Sigra.Testing.OAuthIssuer` to public adopter API in v0.x (adopters don't write new OAuth strategies — kept in `test/support/` until a real adopter asks); coverage of providers beyond Google for Phase 87's Playwright specs (the issuer is provider-agnostic; GitHub/Apple/Facebook spec expansion is a future phase if/when they get GAUAT requirements).

</domain>

<decisions>

## Implementation decisions (research-backed, coherent set)

### D-87-01 — Verification posture (the reshape, the load-bearing decision)

**Posture A: 0 human UAT.** Mock OIDC issuer + Playwright in CI on every PR is Sigra's release gate. `mix sigra.oauth.smoketest --provider=google` is the adopter-side real-credential check at install time. Posture B (one human ceremony at v1.20.0 tag) is performative; Posture C (real Google in tag-only CI) is unprecedented in mature OSS auth libs and structurally fragile against Google's bot defenses (datacenter-IP detection, test-user banhammer). User explicitly confirmed Posture A.

The Phase 9 / SEED-001 framing of "human-only UAT" for OAuth (items 3-6) is **architecturally superseded** by this decision in the same way Phase 86 superseded items 1-2. Documented in `docs/uat-ci-coverage.md` SEED-001 row residual column per D-87-08; not waived (mirrors Phase 86 D-86-09 — "documented residual ≠ waiver" because nothing is being skipped, items are out-of-scope by architectural classification).

### D-87-02 — `Sigra.Testing.OAuthIssuer` (the test seam)

A **TestServer-backed in-process OIDC issuer** that mirrors Assent's own `Assent.Test.OIDCTestCase` (the only proven Elixir-OIDC test seam in the ecosystem). Lives at `test/support/sigra/testing/oauth_issuer.ex` for v0.x — **not promoted to `lib/`** until a real adopter asks. Adopters don't write new OAuth strategies on top of Sigra; they configure providers + call `Sigra.OAuth.callback/2`, which is already covered by `Sigra.Testing.mock_oauth_callback/1` (in-memory shape) for their unit tests. The issuer is for Sigra's own CI to walk the full ceremony.

**Stack:**
- Built on `test_server ~> 0.1.22` (Schultzer / pow-auth, March 2026 — the canonical Elixir test-server pick over legacy Bypass; transitively present via Assent's test deps; promote to a direct dev dep).
- Embeds a fixture RSA key pair (private for signing, public served via JWKS) — RS256 ID tokens are load-bearing for the OIDC ceremony.
- Pre-registers all 5 Google-shaped endpoints: `/.well-known/openid-configuration`, `/oauth2/v2/auth`, `/token`, `/userinfo`, `/jwks` (paths chosen to mirror Google's real shape, not arbitrary).
- Provider-agnostic core + per-provider claims-shape map (`Google`, `GitHub`, `Apple`, `Facebook`); v1.20 uses Google only, but the structure scales to new providers without rewrites.

**Footgun mitigations** (lessons from `mock-oauth2-server` README + Assent's own kid-rotation precedent):
- Multi-key JWKS support (`count: 2` option for kid-mismatch coverage).
- Real PKCE `code_verifier` validation (NOT "accept any verifier" — would mask a real bug).
- `email_verified` returned as boolean (not string) per OpenID spec — Sigra has been bitten by this shape before.
- Configurable `exp` (default `now + 3600`; tests can drive near-expired-token paths).
- Refresh-token rotation behavior toggleable per test (Google rotates; some don't).

**Adopter API sketch** (test/support/, not exported in v0.x):
```elixir
{:ok, issuer} = Sigra.Testing.OAuthIssuer.start_link(provider: :google)
issuer.url                     # base URL of the in-process issuer
issuer.set_user(%{...})        # configure /userinfo + ID token claims
issuer.openid_config            # discovery doc map for app config injection
```
The example app's test config sets `Application.put_env(:sigra, :oauth_provider_overrides, google: [base_url: issuer.url, openid_configuration: issuer.openid_config])` before starting the Phoenix endpoint.

### D-87-03 — `mix sigra.oauth.smoketest` (the adopter-side real-credential check)

Ships in-library at `lib/mix/tasks/sigra.oauth.smoketest.ex`. NOT generator-emitted (it's a one-shot verification tool, not application code). Behavior:

1. Loads the host app's `Sigra` config (resolves `:client_id`, `:client_secret`, `:redirect_uri` from env / runtime config).
2. Boots a tiny Plug endpoint on `localhost:4001` (or `--port` flag).
3. Prints the authorize URL with state nonce + PKCE.
4. Prompts the developer to click through in their default browser (via `:os.cmd("open ...")` on macOS, `xdg-open` on Linux).
5. Receives the callback, exchanges the code, decodes the `id_token`, prints `OK — got back valid id_token with sub=... and email=...`.
6. Exits with code 0 on success, non-zero with diagnostic on failure (state mismatch, token exchange fail, malformed id_token, missing email claim).

**Why this is load-bearing for v1.20 launch posture:** The mock issuer says "the chain works"; it does NOT say "your `client_id` works." Without `oauth.smoketest`, adopters have a residual gap. With it, Sigra ships a strict superset of what next-auth, Devise+omniauth, pow_assent, dwyl/elixir-auth-google ship — converts a marketing weakness ("you never tested real Google") into an adopter benefit ("we hand you the verification tool"). Phase 89 launch language depends on this.

`docs/oauth-google-setup.md` ships alongside as a numbered checklist (Google Cloud Console screenshots, redirect URI, env var names) plus a "Run `mix sigra.oauth.smoketest --provider=google` to verify" final step.

### D-87-04 — Generator fresh-host smoke (GAUAT-03)

**Extend `scripts/ci/install-smoke.sh` — do NOT add a parallel `mix phx.new` job.** That script (verified in research; lines 63, 87, 90-93 already do `mix phx.new` + `sigra.install` + `sigra.gen.oauth --providers google,github` + `mix compile --warnings-as-errors`) is the right surface. ~105s warm cache, ~3min cold — acceptable. Adding a parallel job would duplicate ~3min CI time per PR for ~0 marginal coverage. Reusing `test/example` defeats the "freshly-generated" intent. Extending `installer-milestone-audit.sh` is the wrong target (static-grep INT-01..03 contract, not runtime).

**Three surgical edits:**
1. After line 93's `mix compile --warnings-as-errors`, add: `MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate && MIX_ENV=test mix test`. Proves the emitted `oauth_test_helpers.ex` actually compiles + the generated tests pass.
2. Emit explicit log line `oauth-gen: 12/12 expected artifacts present, mix test green` (the GAUAT-03 numeric claim becomes self-evidencing in the transcript). Today the script checks 10 paths + 1 migration + 1 router marker = 12 artifacts; print the count.
3. In `.github/workflows/ci.yml` `install_smoke` job, tee the run to `.planning/uat-evidence/v1.20/oauth-gen/transcript.log` and `actions/upload-artifact@v4` it; on `v*` tags promote to GitHub release asset (mirrors Phase 86 D-86-06's release-asset promotion pattern via `email_visual_regression`).

**Decompose the GAUAT-03 claim explicitly:**
- **Structural** ("12 files, routes/config/vault wired, idempotent"): `test/sigra/install/oauth_generator_test.exs` (already exists; in-process injector tests; runs every PR; <1s feedback).
- **Live-host** ("compiles --warnings-as-errors and `mix test` green on Phoenix 1.8.x"): extended `install-smoke.sh` (already runs every PR; ~2min; transcript-evidenced).

Phoenix's own installer suite is *file-emission only* (no compile, no test); Sigra's existing `install-smoke` is already the ecosystem outlier on the strict side. Phase 87 just adds `mix test` and the transcript capture.

**Phoenix-version matrix:** NOT introduced. Phoenix CI doesn't matrix across patch versions inside a minor; cost/benefit doesn't justify it. Pin `mix archive.install hex phx_new 1.8.5` (or current minor) explicitly so the test is reproducible and cache-key deterministic. Bump the pin when Phoenix bumps minor; that's when generator-bug class (Mix.Phoenix.web_module/0 edge cases, scope-rename surprises) actually surfaces.

### D-87-05 — Playwright spec scope (GAUAT-04/05/06)

**Three per-GAUAT specs**, NOT one matrix-driven file:

```
test/example/priv/playwright/
  fixtures/
    mailbox.ts                    # existing; reused for GAUAT-06 email assertion
    oauthIssuer.ts                # NEW — primes Sigra.Testing.OAuthIssuer; exposes mockGoogleIdentity()
  tests/
    oauth-register.spec.ts        # GAUAT-04: register/login cycle
    oauth-link.spec.ts            # GAUAT-05: 4 visual states (linked / disabled-tooltip / password-set / unlinked-after-password)
    oauth-email-match.spec.ts     # GAUAT-06: flash + redirect + identity row + linked email
```

**Why per-file (not matrix-driven):** Phase 86's `email-visual.spec.ts` worked because every cell had the same assertion (`toHaveScreenshot`). GAUAT-04/05/06 have **divergent assertions** (session+DB / disabled-tooltip+DB-delete / flash-text+redirect+DB+sent-email) — matrix-driving is a poor fit. **File boundaries match evidence boundaries** in `.planning/uat-evidence/v1.20/oauth-{google,link,email-match}/`. Per-spec failure isolation is worth the 2 extra files. Matches consensus from next-auth E2E, Supabase community E2E, Devise+omniauth — none put every OAuth scenario in one file.

**Cell-by-cell minimum-viable coverage** (defensibly closes each requirement, no padding):

**GAUAT-04 (`oauth-register.spec.ts`):**
- Provider button visible on `/users/log_in` (DOM assertion)
- Click → `page.waitForRequest` for 302 to mock issuer's `/oauth2/v2/auth` with `state` param present (assert presence, NOT contents — test the contract, not the cipher)
- Mock auto-consent → callback to `/auth/google/callback` → land on `/` (post-login destination); session cookie set
- DB probe: exactly one `users` row + one `user_identities` row for `(google, mock_uid)` (via test-only `/test/db_probe` JSON endpoint OR direct `Repo.aggregate` from a mix task — pick simplest in planning)
- Logout link → `/`
- Re-login via same provider → same `users.id`, no new `user_identities` row

**GAUAT-05 (`oauth-link.spec.ts`)** — 4 sub-tests = 4 visual states:
- `linked-with-password`: unlink button **enabled**, no tooltip
- `only-oauth-no-password`: unlink button **disabled**, `title` matches `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92` source-of-truth string. **Single hero PNG screenshot** (`expect(page).toHaveScreenshot()`) — the one visual artifact for GAUAT-05.
- `after-set-password`: button flips to enabled (LiveView re-render)
- `post-unlink`: `user_identities` row absent (DB probe), user can still log in with password

**GAUAT-06 (`oauth-email-match.spec.ts`):**
- Pre-seed `alice@example.test` with password
- Click "Sign in with Google" → mock issuer returns `email=alice@example.test` with novel `sub`
- Land on `/users/log_in` with flash text matching the verbatim string from `priv/templates/sigra.gen.oauth/oauth_controller.ex:96`: `"An account with this email exists. Log in to link your google account."`
- Submit password → land on `/`
- DB probe: new `user_identities` row present for `(alice.id, google, novel_sub)`
- `provider_linked_email` arrived in `/dev/mailbox/json` (reuse existing `mailbox.ts` fixture pattern from `ga-uat-shift-left.spec.ts`)

**Drop / NOT covered** (deliberate):
- State nonce / PKCE content inspection (assert callback succeeds — that proves both validate)
- CTA text in linked-email body (Phase 86 already covers email rendering; we'd duplicate)
- Separate "destination URL" cell in GAUAT-06 (covered by "land on `/` after password login" — one assertion, not two)
- Provider-button accessibility / contrast (separate concern; covered by the WCAG path if surfaced)

### D-87-06 — Evidence layout (mirrors Phase 86 D-86-06 verbatim)

```
.planning/uat-evidence/v1.20/
├── INDEX.md                                       # extended with 4 new rows for GAUAT-03..06
├── oauth-gen/                                     # GAUAT-03
│   ├── README.md                                  # YAML frontmatter (9 fields per Phase 86 schema) + outcome table
│   ├── manifest.json                              # one row per (artifact-class, outcome) cell
│   ├── transcript.log                             # tee'd from install-smoke.sh
│   └── reports/
│       └── artifact-inventory.json                # 12-file count + checksums
├── oauth-google/                                  # GAUAT-04
│   ├── README.md
│   ├── manifest.json                              # rows: register / login-cycle / re-login / logout
│   └── reports/
│       └── playwright-trace-{short-sha}.zip       # Playwright trace.zip on failure (CI artifact)
├── oauth-link/                                    # GAUAT-05
│   ├── README.md
│   ├── manifest.json                              # rows: 4 visual states
│   ├── reports/
│   │   └── db-probe-results.json
│   └── snapshots/
│       └── oauth-link__disabled-tooltip__sha-{short-sha}.png   # the one hero PNG
└── oauth-email-match/                             # GAUAT-06
    ├── README.md
    ├── manifest.json                              # rows: flash / redirect / identity-row / linked-email-sent
    └── reports/
        ├── flash-text-assertion.json
        └── linked-email-mailbox.json
```

**Schema (Phase 86 verbatim):** YAML frontmatter fields = `phase`, `gauat_requirement`, `hex_version`, `git_sha`, `git_tag`, `ci_run_url`, `ci_workflow`, `generated_by`, `generated_at`, `disposition`. Manifest JSON = one row per cell with outcome + ci_run_url + artifact_url. README table auto-generated from manifest JSON to prevent drift. Naming: `{slug}__{state}__sha-{short-sha}.png` (double-underscore separators, short-SHA tail).

**CI artifact at tag time:** full Playwright traces + DB probe outputs + mock-issuer logs uploaded as Actions artifact AND promoted to GitHub release asset on `v*` tags (Actions artifacts cap at 400 days; release assets don't expire — matters for SOC 2 Type II 6-12 month audit windows).

`mix sigra.uat.report --phase=oauth-gen|oauth-google|oauth-link|oauth-email-match` generates the manifest + README table from the same JSON (Phase 86 D-86-06 task; reuse, do not duplicate).

### D-87-07 — Two-commit closure sequencing (Phase 86 D-86-11 pattern)

1. **Commit A (Phase 87 plan-1):** `Sigra.Testing.OAuthIssuer` module + RSA fixture + `test_server` dev dep + `mix sigra.oauth.smoketest` task + `docs/oauth-google-setup.md` adopter recipe + `install-smoke.sh` extensions (mix test + 12/12 log line) + 3 Playwright specs + `oauthIssuer.ts` fixture + test-only DB probe endpoint (or whatever assertion seam planning picks) + new tests for the issuer module itself + tests for the smoketest task. **Gate:** library test suite + extended `install_smoke` + new Playwright job all green.

2. **Commit B (Phase 87 plan-2):** `.planning/uat-evidence/v1.20/oauth-{gen,google,link,email-match}/` (README.md + manifest.json + reports/ + snapshots/ — Phase 86 schema verbatim) + `email_visual_regression`-style CI promotion to GitHub release asset on `v*` tags + `87-VERIFICATION.md` recording the merge-gate outcome (CI run URL, snapshot count, artifact count, dated PASS attestations per GAUAT-03/04/05/06) + `docs/uat-ci-coverage.md` SEED-001 row update (residual column points at the new CI jobs). **Gate:** all CI jobs green at SHA; manifest matches README table per evidence dir.

### D-87-08 — Milestone-scope edits (commit alongside this CONTEXT.md)

Per Phase 86 D-86-08 pattern. Edits land in the same commit as `87-CONTEXT.md` so the planner inherits the corrected scope without drift:

- **REQUIREMENTS.md GAUAT-03..06** rewritten:
  - GAUAT-03: "automated `install-smoke` job (`scripts/ci/install-smoke.sh`) on every PR runs `mix phx.new` + `sigra.install` + `sigra.gen.oauth` + `mix compile --warnings-as-errors` + `MIX_ENV=test mix test` and emits `oauth-gen: 12/12 expected artifacts present, mix test green`. Transcript filed at `.planning/uat-evidence/v1.20/oauth-gen/transcript.log`."
  - GAUAT-04: "automated Playwright spec `oauth-register.spec.ts` drives Sigra's example app against the in-process `Sigra.Testing.OAuthIssuer` to exercise: provider button → consent → callback → user record + identity row + session → logout → re-login. Evidence: pass/fail manifest under `.planning/uat-evidence/v1.20/oauth-google/`."
  - GAUAT-05: "automated Playwright spec `oauth-link.spec.ts` covers four visual states (linked-with-password / only-oauth-no-password disabled-tooltip / after-set-password re-enabled / post-unlink row-deleted). Evidence: 4-row manifest + one hero PNG of the disabled-tooltip state under `.planning/uat-evidence/v1.20/oauth-link/`."
  - GAUAT-06: "automated Playwright spec `oauth-email-match.spec.ts` covers flash text (verbatim from `oauth_controller.ex:96`), redirect destination, identity-row creation, and `provider_linked_email` arrival in `/dev/mailbox/json`. Evidence: 4-row manifest + flash-text assertion under `.planning/uat-evidence/v1.20/oauth-email-match/`."

- **ROADMAP.md Phase 87 success criteria** rewritten parallel to the GAUAT changes; phase-summary bullet at the top of ROADMAP.md updated from "real-credential cycle … capture evidence per scenario" to "automated end-to-end OAuth verification (Sigra.Testing.OAuthIssuer + Playwright × 3 specs) producing CI-reproducible evidence per GAUAT-03/04/05/06; `mix sigra.oauth.smoketest` ships for adopter-side real-credential check."

- **`docs/uat-ci-coverage.md` SEED-001 row** updated: residual column for items 3-6 now points at `install_smoke` (extended) + new `oauth_e2e_playwright` CI job + the `mix sigra.oauth.smoketest` adopter recipe.

- **CHANGELOG.md `[Unreleased]`** carries the verification-approach correction bullet (Phase 86 precedent — surgical planning-truth edit, dated supersession footnote).

This is a verification-approach correction, not a new capability — counts as milestone-level scope edit but folded here for the same reason Phase 86 folded its GAUAT-01/02 rewording.

### D-87-09 — Residual policy (documented, NOT waived — Phase 86 D-86-09 framing)

**0 residual human work for v1.20 launch.** The following live in `docs/uat-ci-coverage.md` SEED-001 row residual column (NOT in a waiver — nothing is being skipped; items are out-of-scope by architectural classification):

1. **Live consumer Google consent UX surface** (any UI change Google ships post-mock-build) — adopter-facing only; `mix sigra.oauth.smoketest` is the per-adopter check at install time, not a Sigra release gate. Sigra cannot meaningfully react faster than adopters to a real-Google API regression because Sigra calls Assent which calls Google.
2. **Adopter's specific `client_id` correctness** — `docs/oauth-google-setup.md` recipe + the smoketest task; not Sigra's release gate.
3. **Bot-detection / quota / banhammer concerns** — architecturally avoided (no real Google in CI).

**No vendor commitments.** No quarterly Litmus-equivalent for OAuth (no analogous service exists; nothing to fake-promise).

### D-87-10 — Tests (the L1 unit-extension layer for the new code)

- `test/sigra/testing/oauth_issuer_test.exs` (~80 LOC, AAA-flat) — covers issuer endpoint shapes, RS256 signing/verification, kid rotation (`count: 2`), PKCE rejection on bad verifier, configurable `exp` near-expiry, refresh-token rotation toggle, `email_verified` boolean shape.
- `test/sigra/install/oauth_smoketest_task_test.exs` (~40 LOC) — covers the Mix task: config loading, port-flag handling, error diagnostic emission, exit-code semantics. Does NOT exercise a real browser open (Mix task tests stub `:os.cmd`).
- `test/example/test/example_web/oauth_controller_test.exs` extension (~30 LOC) — covers controller-level integration (state mismatch from browser, provider error response, no-email flash) NOT covered by `MockStrategy` unit tests today, using `Sigra.Testing.OAuthIssuer` instead of MockStrategy. Closes the gap surfaced by research (controller integration was missing).

L2 (Playwright) lives in `test/example/priv/playwright/tests/oauth-{register,link,email-match}.spec.ts` per D-87-05.

### Claude's discretion

- Exact location of `Sigra.Testing.OAuthIssuer` for v0.x (`test/support/sigra/testing/oauth_issuer.ex` is the recommendation; planner may move to `lib/sigra/testing/oauth_issuer.ex` if compile-time-conditional shipping makes more sense than test/support copy). Flag for promotion to `lib/` only when an adopter requests.
- Whether the Playwright DB probe is a test-only `/test/db_probe` JSON endpoint (mounted only when `Mix.env() == :test`) or a Playwright-side `request.post` to a Mix-task-driven probe. Pragmatic call. Test-only endpoint is simpler; Mix-task probe is more hygienic. Planner picks.
- `oauthIssuer.ts` fixture API exact shape (`use({ oauthIssuer })` Playwright fixture vs. plain helper module). Mirrors `mailbox.ts` precedent — pick the closest match.
- Whether `mix sigra.oauth.smoketest` opens the browser via `:os.cmd("open ...")` or just prints the URL and waits (simpler, more terminal-friendly, no platform branching). Default to print-and-wait; add `--open-browser` flag if interactive devs ask later.
- `test_server` lock to specific version (`~> 0.1` or pinned); planner picks based on stability concerns. 0.1.22 is current.
- Pin `phx_new` archive version explicitly in `install-smoke.sh` (recommended `1.8.5`); planner picks the exact pin matching the Phoenix version Sigra targets at v1.20 ship time.
- Whether to ship a screenshot of all 4 GAUAT-05 visual states or just the `disabled-tooltip` hero (research recommended just the disabled-tooltip; planner can decide if 4 PNGs reads better in the evidence README).

### Folded scope

- **`mix sigra.oauth.smoketest` task + `docs/oauth-google-setup.md`** — explicitly approved as part of Phase 87 scope (load-bearing for the launch posture; converts the residual "you never tested real Google" into an adopter benefit).
- **REQUIREMENTS.md GAUAT-03..06 + ROADMAP.md Phase 87 + `docs/uat-ci-coverage.md` SEED-001 + CHANGELOG.md `[Unreleased]` rewording** — explicitly approved as part of this discuss commit (Phase 86 D-86-08 precedent; verification-approach correction, not a new capability).
- **Controller-level integration test extension** for `oauth_controller.ex` error paths (state mismatch, provider error, no-email) — surfaced as a gap by research; folded so the implementation commit covers it without a separate phase.

### Folded todos

_None — `gsd-sdk query todo.match-phase 87` to be confirmed during planning._

</decisions>

<canonical_refs>

## Canonical references

**Downstream agents MUST read these before planning or implementing.**

### Requirements and roadmap

- `.planning/REQUIREMENTS.md` — **GAUAT-03**, **GAUAT-04**, **GAUAT-05**, **GAUAT-06** (rewritten in this commit per D-87-08); **GAUAT-09** (Phase 88 results-filing matrix that links back here).
- `.planning/ROADMAP.md` — Phase 87 goal + rewritten success criteria + phase-summary bullet (this commit per D-87-08).
- `.planning/PROJECT.md` — v1.20 GA framing + "use this in production" launch positioning.
- `.planning/STATE.md` — v1.20 leg-2 framing (Phase 87 = SEED-001 OAuth slice closure).

### Seed and prior-phase context

- `.planning/seeds/SEED-001-v1.0-ga-human-uat-gate.md` — original 8-item human gate; Phase 87 closes items 3-6 via shift-left automation, mirroring Phase 86's closure of items 1-2.
- `.planning/phases/86-gauat-email-visual-qa-phase-04-phase-08-templates/86-CONTEXT.md` — **the precedent that matters**: D-86-06 (evidence layout schema), D-86-08 (milestone-scope-edits-folded-into-discuss-commit), D-86-09 (documented residual ≠ waiver), D-86-11 (two-commit closure sequencing). Phase 87 inherits all four patterns verbatim.
- `.planning/phases/85-oauth-audit-atomicity-closure-aud-21/85-CONTEXT.md` — two-commit closure shape; AUD-21 establishes that OAuth-side audit atomicity is a closed concern Phase 87 does not need to revisit.
- `.planning/uat-evidence/v1.20/INDEX.md` — top-level evidence index; Phase 87 extends with 4 new rows (oauth-gen, oauth-google, oauth-link, oauth-email-match).
- `.planning/uat-evidence/v1.20/email-phase-04/{README.md,manifest.json}` — schema templates Phase 87 mirrors verbatim.
- `.planning/v1.4-GA-UAT.md` — matrix-file shape; Phase 88's `v1.20-GA-UAT-RESULTS.md` follows this column set.

### Code (integration points)

- `lib/sigra/oauth.ex` and `lib/sigra/oauth/` (callback.ex, strategies.ex, strategies/{google,github,apple,facebook,generic}.ex) — public API surface (`authorize_url/3`, `handle_callback/4`, `link_provider/4`, `unlink_provider/4`, `get_tokens/2`); HMAC state signing; Ecto.Multi atomicity; `UserIdentity` schema. **Already covered** by unit tests + AUD-21; Phase 87 does not modify these.
- `lib/sigra/testing.ex` (`mock_oauth_callback/1` at line 1015 + `create_identity/1` + `oauth_user_fixture/1`) — in-memory shape helpers; Phase 87 ADDS `Sigra.Testing.OAuthIssuer` (TestServer-backed HTTP-stack issuer; D-87-02). The two are complementary — `mock_oauth_callback` for unit tests, `OAuthIssuer` for HTTP-ceremony integration tests.
- `lib/mix/tasks/sigra.gen.oauth.ex` (~300 LOC) — generator emits 12 files on a fresh host (9 core + 2 vault + conditional LiveView settings); Phase 87 does not modify, only verifies via the extended `install-smoke.sh`.
- `priv/templates/sigra.gen.oauth/oauth_controller.ex:96` — flash text source-of-truth: `"An account with this email exists. Log in to link your #{provider} account."`. Phase 87 GAUAT-06 spec asserts verbatim against this string.
- `priv/templates/sigra.gen.oauth/oauth_settings_live.ex:92` — disabled-unlink tooltip source-of-truth string. Phase 87 GAUAT-05 spec asserts verbatim.
- `test/sigra/oauth/oauth_test.exs`, `test/sigra/oauth/oauth_audit_atomicity_test.exs`, `test/sigra/oauth/oauth_ceremony_audit_test.exs`, `test/sigra/install/oauth_generator_test.exs`, `test/example/test/example_web/smoke/oauth_test.exs` — existing OAuth test inventory; Phase 87 ADDS issuer test + smoketest task test + controller integration extension; does not modify existing.
- `scripts/ci/install-smoke.sh:90-93` (current `mix sigra.gen.oauth` block) — extension point for D-87-04 (add `mix test` + 12/12 log line).
- `.github/workflows/ci.yml` — `install_smoke` job extension (transcript tee + artifact upload + release-asset promotion on `v*` tags); new `oauth_e2e_playwright` job (or extension of existing `playwright` job — planner picks).
- `test/example/priv/playwright/playwright.config.ts` — adds (or reuses) chromium project for the 3 new specs; serial mode already active.
- `test/example/priv/playwright/fixtures/mailbox.ts` — reused by GAUAT-06; pattern reference for new `oauthIssuer.ts`.
- `test/example/priv/playwright/tests/email-visual.spec.ts` — Phase 86 spec precedent (file structure, fixture usage, evidence wiring).
- `test/example/priv/playwright/tests/golden-path.spec.ts` — LiveView interaction precedent + helper-function-at-top-of-file style.
- `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` — describe-block + mailbox polling precedent.

### Verification + planning truth touch points

- `docs/uat-ci-coverage.md` — SEED-001 row residual column for items 3-6 updated to point at the new CI jobs; per Phase 86 precedent.
- `MAINTAINING.md` — "Post-launch monitoring (v1.20)" lane (added in Phase 90); Phase 87 does not edit.
- `.planning/v1.20-GA-UAT-RESULTS.md` — filed in Phase 88; carries one row per GAUAT-03/04/05/06 with link back into Phase 87 evidence dirs.
- `.planning/phases/87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link/87-VERIFICATION.md` — to be authored at phase close (records CI run URL, snapshot count, dated PASS attestations per GAUAT-03/04/05/06).

### External (research-cited; downstream agents may verify)

- [Assent OIDCTestCase](https://github.com/pow-auth/assent/blob/main/test/support/strategies/oidc_test_case.ex) — the Elixir-OIDC test seam that `Sigra.Testing.OAuthIssuer` mirrors.
- [pow_assent TestProvider](https://github.com/pow-auth/pow_assent/blob/main/test/support/test_provider.ex) — `test_server`-composed strategy precedent.
- [hexdocs.pm/test_server](https://hexdocs.pm/test_server/TestServer.html) — Schultzer's TestServer (v0.1.22, March 2026); the canonical 2026 Elixir test-HTTP-server pick.
- [hexdocs.pm/assent](https://hex.pm/packages/assent) — Sigra's OAuth foundation; `http_adapter` test seam documentation.
- [Auth.js testing guide](https://authjs.dev/guides/testing) — explicit "do not automate real provider flows" recommendation; basis for D-87-01 posture.
- [Spring Security OAuth2 testing](https://docs.spring.io/spring-security/reference/reactive/test/web/oauth2.html) — WireMock-stubbed providers; cross-language precedent for D-87-01.
- [omniauth Integration Testing](https://github.com/omniauth/omniauth/wiki/Integration-Testing) — `OmniAuth.config.test_mode = true` precedent (Ruby/Rails ecosystem).
- [Playwright Authentication](https://playwright.dev/docs/auth) — fixture + storageState patterns; basis for `oauthIssuer.ts` shape.
- [Playwright Test Fixtures](https://playwright.dev/docs/test-fixtures) — fixture API for `mockGoogleIdentity()` helper.
- [Phoenix CI workflow](https://github.com/phoenixframework/phoenix/blob/main/.github/workflows/ci.yml) — reference for structural-vs-live test split (basis for D-87-04 decomposition).
- [navikt/mock-oauth2-server](https://github.com/navikt/mock-oauth2-server) — JVM-based reference for OAuth-mock accuracy footguns (kid rotation, exp handling, PKCE validation) that `Sigra.Testing.OAuthIssuer` must avoid.
- [Descope: 5 OAuth Misconfigurations](https://www.descope.com/blog/post/5-oauth-misconfigurations) — confirms misconfigurations are downstream of library correctness; basis for "smoketest belongs in adopter env" framing.
- [Test Double — Auth flow E2E with Playwright + Next.js](https://testdouble.com/insights/how-to-test-auth-flows-with-playwright-and-next-js) — per-flow file split precedent for D-87-05.

</canonical_refs>

<code_context>

## Existing code insights

### Reusable assets

- **`Sigra.OAuth.*` public API** (`lib/sigra/oauth.ex`) — fully covered by unit tests + audit atomicity tests; Phase 87 invokes through this surface, never modifies it.
- **`Sigra.Testing.mock_oauth_callback/1`** (`lib/sigra/testing.ex:1015`) — kept as the in-memory shape helper for unit tests; complementary to the new `Sigra.Testing.OAuthIssuer` (HTTP-stack issuer). No deprecation.
- **`scripts/ci/install-smoke.sh`** (already does `mix phx.new` + `sigra.install` + `sigra.gen.oauth --providers google,github` + `mix compile --warnings-as-errors`) — the existing fresh-host smoke; Phase 87 surgically extends with `mix test` + transcript capture rather than building a parallel job.
- **`test/sigra/install/oauth_generator_test.exs`** — structural file-emission tests; keeps every-PR <1s feedback layer. Not modified by Phase 87.
- **`test/example/priv/playwright/fixtures/mailbox.ts`** — `/dev/mailbox/json` polling helper; reused for GAUAT-06 `provider_linked_email` assertion. Pattern reference for the new `oauthIssuer.ts` fixture.
- **Existing Playwright harness** (`golden-path.spec.ts`, `email-visual.spec.ts`, `ga-uat-shift-left.spec.ts`, etc.) — Phase 87 adds 3 new spec files using established patterns (top-of-file helpers, describe blocks, serial mode).
- **Phase 86 evidence schema** (`.planning/uat-evidence/v1.20/email-phase-04/{README.md,manifest.json}`, `mix sigra.uat.report --phase=...` task) — reused verbatim for the 4 new evidence dirs.
- **`Plug.Swoosh.MailboxPreview`** (`test/example/lib/example_web/router.ex:175`) — kept for ad-hoc human preview during template authoring; CI does not depend on it.

### Established patterns

- **Two-commit closure (Phase 85 / 86 D-X-11 pattern)** — code+tests commit, then verification+narrative commit. Mirror in D-87-07.
- **Surgical planning-truth edits (Phase 81/82 D-X-04, Phase 86 D-86-08 pattern)** — dated supersession footnote + one CHANGELOG bullet + one paragraph in summary doc. Apply to `docs/uat-ci-coverage.md` SEED-001 row + REQUIREMENTS.md GAUAT-03..06 + ROADMAP.md Phase 87 in the same commit as this CONTEXT.md.
- **Frozen test fixtures for time-dependent code** (Phase 86 D-86-04) — extend to issuer ID-token `iat`/`exp` fixtures; deterministic `~U[2026-04-17 12:00:00Z]` baseline.
- **`role="presentation"` table layout + inline CSS only** (Phase 86 — `base_layout/1` already follows this for emails) — irrelevant for OAuth pages but cited as the canonical Sigra-template hygiene pattern.
- **Generator + thin runtime** (project-wide) — `mix sigra.oauth.smoketest` is in-library (verification tool, not application code), NOT generator-emitted; mirrors how `mix sigra.upgrade` ships in-library.

### Integration points

- **CI workflow:** `install_smoke` (extended in D-87-04 — adds `mix test` + transcript tee); new `oauth_e2e_playwright` job (or extension of existing playwright job) running the 3 new specs against the example app + `Sigra.Testing.OAuthIssuer`. Both jobs upload Phase 87 evidence as Actions artifacts; both promote to GitHub release asset on `v*` tags via the same workflow Phase 86 established.
- **Adopters:** `mix sigra.oauth.smoketest --provider=google` is a one-shot Mix task; `docs/oauth-google-setup.md` is a numbered checklist pointing to it. Existing adopters discover it via CHANGELOG `[Unreleased]` entry + new docs page in ExDoc nav.
- **`mix sigra.gen.oauth`:** unchanged. The 12-file emission contract is already correct; Phase 87 just adds `mix test` after generation in the smoke harness.
- **`Sigra.Testing` namespace:** gains `Sigra.Testing.OAuthIssuer` (test/support/, not exported in v0.x). No public-API surface changes; internal addition only.

</code_context>

<specifics>

## Specific ideas

- **"Tested like Assent / Spring Security / Auth.js test"** — the launch-language anchor (Phase 89 README + announcement post inherit this). Strongest defensible claim because it names peers; honest because Sigra's harness IS structurally identical to Assent's `OIDCTestCase`. Phase 89 plan inherits this constraint (don't say "tested against real Google" — would be false).
- **`mix sigra.oauth.smoketest` is the load-bearing complement** — without it, the launch claim has a residual "but did you actually test against real Google?" hole. With it, Sigra ships a strict superset of next-auth/Devise+omniauth/pow_assent/dwyl/elixir-auth-google. This is genuine adopter DX, not yak-shaving.
- **`Sigra.Testing.OAuthIssuer` mirrors Assent's own `OIDCTestCase` deliberately** — the only proven Elixir-OIDC test seam. Diverging would be inventing protocol; matching gets us protocol conformance for free. RSA fixture, RS256 ID tokens, real PKCE, kid rotation, `email_verified` boolean — all locked from Assent's precedent.
- **`oauth-link.spec.ts` ships ONE hero PNG (the disabled-tooltip state)** — the visual artifact is the tooltip on a disabled button. The other 3 states are pure behavior assertions (DB rows, button enabled/disabled). 4 PNGs would be visually noisy in the evidence README; one is the load-bearing visual.
- **State nonce + PKCE asserted at the contract level (callback succeeds), NOT decoded** — testing the cipher contents would either leak fixture values or reimplement the verifier. The right test: "can the round-trip complete?" That proves both validate.
- **DB probe via test-only `/test/db_probe` endpoint OR Mix task** — left to planner. Test-only endpoint is simpler; Mix-task probe is more hygienic. Either works; the requirement is "Playwright can assert `user_identities` row count after a flow."
- **Pin `phx_new` archive version in `install-smoke.sh`** — today it floats. Pin makes the test reproducible and cache-key deterministic. Bump on Phoenix minor bumps (next minor = next investigation surface).
- **Documented residual is NOT a waiver** (Phase 86 D-86-09 framing) — there's no work being skipped; residual items (live consumer Google UX, adopter `client_id`, bot detection) are out-of-scope by architectural classification, not deferral. Mirrors the Phase 85 D-AUD-06 sub-class framing.
- **Adopter-side smoketest is the right place for live-Google verification** — confirmed by Descope's 5-misconfigurations analysis: every documented OAuth production bug is in *adopter integration code* (state, redirect URI, code reuse), not library correctness. Sigra cannot meaningfully test what the adopter must verify themselves.

</specifics>

<deferred>

## Deferred ideas

- **Promote `Sigra.Testing.OAuthIssuer` to `lib/sigra/testing/oauth_issuer.ex` as adopter-facing public API** — out of v1.20 scope. Adopters don't write new OAuth strategies on top of Sigra; they configure providers + call `Sigra.OAuth.callback/2`. Promote only when a real adopter asks for it (probably v1.21+ if at all).
- **Playwright spec coverage for GitHub / Apple / Facebook providers** — out of v1.20 scope. The issuer is provider-agnostic; the GAUAT requirements are Google-only. Add specs in a future phase if/when those providers get GAUAT requirements.
- **Mocha-style retries in Playwright OAuth specs for flake mitigation** — should not be needed (deterministic in-process issuer). Defer until observed flake.
- **`mix sigra.oauth.smoketest` browser auto-open** (`:os.cmd("open ...")` on macOS, `xdg-open` on Linux) — defaults to print-and-wait (terminal-friendly, no platform branching). Add `--open-browser` flag if interactive devs ask later.
- **OIDC nonce parameter (separate from state)** — Sigra currently uses state for CSRF; nonce is for ID-token replay protection. If Sigra adopts strict nonce in a future phase, `Sigra.Testing.OAuthIssuer` adds support then.
- **Refresh-token flow Playwright coverage** — out of v1.20 GAUAT scope. The lib-level `Sigra.OAuth.get_tokens/2` is unit-tested for refresh; UI-level "session-extend on token refresh" is a future phase.
- **Mock issuer with multiple concurrent providers in a single test** (e.g., link Google AND GitHub in one spec) — defer; current GAUAT-05 covers single-provider link/unlink, which closes the requirement.
- **Real-Google CI lane as a sponsor-funded feature** — if a community sponsor donates a stable test Google project + commits to monitoring it, document as future-enhancement track in `MAINTAINING.md` "Post-launch monitoring" lane (added in Phase 90). Out of v1.20 scope.
- **`mix sigra.oauth.smoketest --provider=github|apple|facebook`** — Phase 87 ships Google only; add other providers when their respective configurations stabilize (and when adopters request).
- **`docs/oauth-google-setup.md` rewrite as `docs/oauth-providers/{google,github,apple,facebook}.md`** — out of v1.20 scope. Single Google doc for now; restructure when more providers land.

### Reviewed todos (not folded)

_None — `gsd-sdk query todo.match-phase 87` to be confirmed during planning._

</deferred>

---

*Phase: 87-gauat-oauth-real-credential-cycle-gen-smoke-google-live-link*
*Context gathered: 2026-04-26*
