# Sigra v1.32 Research: 1.0 Release Mechanics + Adoption Push

**Date:** 2026-05-31  
**Mode:** Ecosystem  
**Decision posture:** Opinionated, minimize maintainer/user decision load

## Summary Recommendation (Decisive)

Ship **direct `1.0.0` from `main`** using existing Release Please automation, with one pre-release hardening window in `main` (no public RC artifact by default), then immediately run a time-boxed adoption push.

Why this is the best fit for Sigra now:
- Sigra already has mature release automation and strong CI proof lanes (`release-please.yml`, `ci.yml`, install smoke, docs warnings gates, dep-off lane).
- Hex guidance says pre-1.0 breaks should have been expressed via minor bumps; Sigra already did this in `0.x`, and now has a stable public contract and production-facing docs.
- A public RC track adds operational complexity and user confusion for limited upside unless Sigra needs downstream ecosystem validation at scale before GA.

## Recommended Mechanics

## 1) Versioning + SemVer posture

- Set next release target to **`1.0.0`** (not `0.4.0` / `0.5.0` first).
- Keep strict SemVer after 1.0:
  - `PATCH`: bug/security/documentation corrections without API break.
  - `MINOR`: additive API and new optional capabilities.
  - `MAJOR`: public contract breaks (library API, generated-host contract, migration contract).
- Keep deprecation windows explicit in `CHANGELOG.md` and `@deprecated` docs with removal target versions.
- Keep `v1.x` planning milestones clearly separated from Hex SemVer in docs (Sigra already does this well; keep it).

## 2) Release artifact truth (single source)

Gate release readiness on these being in sync:
- `mix.exs` `@version`
- `.release-please-manifest.json`
- `CHANGELOG.md` top release section
- release tag `v1.0.0`
- Hex package version
- HexDocs source links (`source_ref: "v#{@version}"`)

Use existing Release Please path as canonical:
- Release PR opens/updates from conventional commits.
- Merge Release PR.
- Publish job runs from released tag, tests, dry-run publish, then `mix hex.publish --yes`.

## 3) Hex.pm / docs posture for 1.0 cut

- Ensure package metadata is crisp and stable:
  - final description aligned to production boundary (what Sigra owns vs host owns),
  - links include changelog/docs/source,
  - package file list excludes planning internals and generated clutter.
- Ensure `mix docs --warnings-as-errors` is mandatory in release gate (already present in CI; add to publish flow too for symmetry).
- Add/refresh one **“1.0 contract”** doc section:
  - supported Elixir/Phoenix/Ecto ranges,
  - optional dependencies and feature gates,
  - explicit non-goals (host responsibilities).

## 4) Verification gates (must-pass for 1.0)

Minimum 1.0 release gates (all required):
- Full library test suite green.
- Install golden/idempotency contract green.
- Fresh install smoke green (`phx.new` + `mix sigra.install` path).
- Example app smoke + browser lane green.
- Dep-off optional-dep lane green.
- Docs build with warnings-as-errors green.
- Hex dry-run publish green.
- Post-publish Hex API visibility check green.

Recommendation: add one synthetic **consumer-upgrade smoke lane**:
- scaffold app pinned to previous stable `~> 0.3`,
- upgrade to `1.0.0`,
- run migrations/tests/compile,
- fail release if this breaks unexpectedly.

## 5) RC vs direct 1.0 tradeoff

### Approach A: Direct `1.0.0` (Recommended)
Pros:
- Fastest path; least maintainer overhead.
- No split messaging for adopters.
- Uses already proven automation and CI.

Cons:
- Less external pre-GA signal from public RC users.

Best when:
- Internal CI and example-host evidence are already strong (true for Sigra).

### Approach B: Public RC (`1.0.0-rc.1`, `rc.2`, ...)
Pros:
- Early adopter validation with clear “not final” signal.
- Useful if you expect broad integrator feedback before GA.

Cons:
- Additional comms/docs support burden.
- Can confuse users about install target and stability.
- Requires extra release train discipline.

Best when:
- Large downstream surface and uncertain compatibility.

**Decision:** choose **Approach A** now; only switch to RC if a hard blocker appears during the hardening window.

## 6) Adoption push mechanics (immediately after cut)

- Publish same-day “1.0 announcement” with:
  - what’s stable now,
  - migration guidance from `~> 0.3`,
  - explicit boundaries/non-goals.
- Add “quick confidence” artifacts:
  - 10-minute install path,
  - compatibility matrix,
  - one copy-paste upgrade checklist.
- Keep first two weeks as rapid patch window (`1.0.1+`) for integrator friction.

## Idiomatic Ecosystem Lessons (Elixir/Phoenix/Plug/Ecto)

- Mature libs keep **tight changelogs + explicit deprecations + clear version floors** (Phoenix, Plug, Ecto, Oban patterns).
- Mature libs commonly set `source_ref` to tag version, so HexDocs “view source” stays valid per release.
- Release runbooks in successful projects are explicit and mechanical (Phoenix’s `RELEASE.md` is a strong template).
- Auth libs with ambiguous versioning/history create adopter trust drag (seen in older/slowly-updated auth ecosystem projects).

## Footguns To Avoid

- Mixing milestone labels with SemVer in user-facing release headlines.
- Shipping 1.0 without a compatibility statement (Elixir/Phoenix/Ecto ranges).
- Passing CI on branch but publishing from a different ref/tag.
- Docs/source tag mismatch (`source_ref` not matching release tag).
- Letting Release Please manifest/version drift from `mix.exs`.
- Publishing without dry-run + post-publish visibility check.
- Over-claiming production guarantees that belong to host app ops.

## Concrete Milestone Requirement Candidates

Use these as v1.32 requirement seeds.

| ID | Name | Requirement Candidate |
|---|---|---|
| REL1-01 | `SemVer-1.0-Cut` | Release Please cut produces `v1.0.0` with aligned `mix.exs`, manifest, changelog, tag, Hex version. |
| REL1-02 | `Release-Gate-Matrix` | 1.0 publish blocked unless all CI gates (library/install/example/dep-off/docs/dry-run) pass on release ref. |
| REL1-03 | `Docs-Contract-1.0` | Publish explicit 1.0 compatibility + support boundary + non-goals in README/HexDocs. |
| REL1-04 | `Upgrade-Smoke-0x-to-1x` | Automated consumer upgrade smoke from latest `0.3.x` to `1.0.0` added and required. |
| REL1-05 | `Maintainer-Runbook-1.0` | `MAINTAINING.md` gets a deterministic 1.0 cut checklist (normal path + recovery path). |
| REL1-06 | `CI-Evidence-Bundle` | Attach 1.0 release evidence bundle (job URLs/artifacts + pass/fail summary) in release notes. |
| REL1-07 | `Adoption-Launch-Pack` | Ship 1.0 announcement copy + quickstart lane + upgrade guide pointer + known-boundaries section. |
| REL1-08 | `Hotfix-Window-Policy` | Define first-14-day post-1.0 patch policy and triage SLA for adopter-reported regressions. |

## Non-Goals (for this milestone)

- Building new auth surface area (no new major features).
- Re-architecting generator/library boundaries.
- Replacing Release Please with a new release system.
- Adding public RC train unless a specific blocker emerges.
- Compliance/legal certification claims.

## Confidence + Evidence

**Overall confidence:** HIGH for release mechanics; MEDIUM for adoption-impact magnitude.

Primary evidence:
- Sigra repo: `mix.exs`, `CHANGELOG.md`, `MAINTAINING.md`, `release-please-config.json`, `.release-please-manifest.json`, `.github/workflows/release-please.yml`, `.github/workflows/ci.yml`.
- Hex publish docs: https://hex.pm/docs/publish
- SemVer spec: https://semver.org/
- Release Please Action outputs/behavior: https://github.com/googleapis/release-please-action
- Ecosystem examples:
  - Phoenix release/changelog/runbook: https://github.com/phoenixframework/phoenix
  - Ecto metadata/changelog posture: https://github.com/elixir-ecto/ecto
  - Plug changelog/deprecation/security posture: https://github.com/elixir-plug/plug
  - Oban release/changelog posture: https://github.com/oban-bg/oban
  - Ash release cadence/changelog automation style: https://github.com/ash-project/ash
  - Pow/Ueberauth/Guardian maintenance/versioning context: https://github.com/pow-auth/pow, https://github.com/ueberauth/ueberauth, https://github.com/ueberauth/guardian

