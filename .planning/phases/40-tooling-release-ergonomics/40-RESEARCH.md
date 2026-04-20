# Phase 40 — Technical research

**Phase:** 40 — Tooling & release ergonomics  
**Question:** What do we need to know to plan TOOL-01 and REL-01 well?

## Summary

- **Hex / Mix publish:** Official path is `mix hex.publish` with scoped [`HEX_API_KEY`](https://hex.pm/docs/publish); non-interactive CI uses `mix hex.publish --yes`. Package version is the single source of truth in `mix.exs` `@version`; `source_ref: "v#{@version}"` in docs must stay aligned with the Git tag used for the release.
- **Pre-1.0 semver (library):** Hex and Mix treat `0.x` minors as potentially breaking; additive public `lib/` API (e.g. `Sigra.Audit.Assertions` from Phase 39) warrants **`0.2.0`** over `0.1.1` when first published to consumers — matches project CONTEXT D-40-17..D-40-18.
- **TOOL-01:** `gsd-tools audit-open --json` is a Node helper from get-shit-done; known `ReferenceError: output is not defined`. Sigra’s closure posture is **deprecation + repo-owned checklist** (no contributor dependency on Node for `mix test`), optional maintainer-only script, supersession notes in still-referenced planning templates — **not** blocking on upstream.
- **GitHub Actions:** Phase 37 established **full SHA pins** + version comments on `actions/checkout`, `erlef/setup-beam`, `actions/cache`. Any new workflow must copy that discipline; **`workflow_dispatch` only** avoids accidental publish on merge.
- **Doc split:** Contributor-facing `CONTRIBUTING.md` stays Postgres/`mix test`/CI; maintainer-only shipping steps live in root **`MAINTAINING.md`** (discoverable, matches MILESTONES expectation).

## Repo-specific findings

| Area | Finding |
|------|---------|
| `mix.exs` `docs/0` | `extras` already lists `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, guides — **`MAINTAINING.md` absent**; add for HexDocs parity (CONTEXT D-40-10). |
| `ci.yml` | Documents that `HEX_API_KEY` is **not** read unless an explicit publish job adds it — good pattern to preserve; new publish workflow must remain **separate file**. |
| Live grep | **`scripts/`** has **no** `gsd-tools` / `audit-open` references; **`CONTRIBUTING.md` / `README.md`** same. Remaining actionable strings are **`.planning/`** (`MILESTONES.md`, `PROJECT.md`, phase `26-01-PLAN.md`). |
| Optional automation | A **bash** helper under `scripts/maintainers/` can list planning hygiene items without Node; keep **non-executable in default CI** (no wiring in `ci.yml` required). |

## Risks / pitfalls

- Publishing from CI without running **`mix test`** first yields false confidence — REL-01 checklist and optional workflow must run tests before `hex.publish`.
- Putting **`secrets.HEX_API_KEY`** on compile-only jobs widens blast radius — restrict to publish job/step only.
- Linking `MAINTAINING.md` from `MILESTONES` / `PROJECT` **before** the file exists breaks readers mid-phase — **plan order:** create `MAINTAINING.md` first (Plan 02), then supersede audit-open narrative (Plan 01 depends on Plan 02).

## Validation Architecture

This phase is **documentation + optional CI YAML + optional shell helper**; no new `lib/` runtime behavior.

**Sampling strategy**

| When | Command / check |
|------|-----------------|
| After each task | `grep` / `test -f` acceptance criteria from the plan |
| After each plan | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` (full library suite — unchanged bar) |
| After Plan 02 YAML edit | `actionlint` **if** available locally; otherwise manual read for `workflow_dispatch` only + `permissions` + secret scope |
| Before phase sign-off | Confirm **`rg 'audit-open --json'`** outside `.planning/phases/26*/**` historical archives** resolves only to superseded lines or intentional archive text per decisions |

**Dimension 8 (Nyquist):** Every task carries grep-verifiable `<acceptance_criteria>`; no Wave 0 new test files required — existing ExUnit + CI suffice.

## RESEARCH COMPLETE

Next: pattern map (`40-PATTERNS.md`), plans `40-01` / `40-02`, checker pass.
