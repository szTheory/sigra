# ADR 003: Hex package version must never be derived from arbitrary git tags; no milestone `vX.Y` tags in the `v1.*` namespace

**Status:** Accepted
**Date:** 2026-07-11
**Context:** Phase 223 (v1.45 RELEASE-CURRENCY) — root-causing the stray Hex `1.20.0` release before deferring its retire.

## The footgun (what actually went wrong)

Sigra used **two different meanings for `v1.*` git tags in the same namespace**:

- **Milestone tags** — two-component `vMAJOR.MILESTONE` (e.g. `v1.20`, `v1.21`, … `v1.35`),
  minted by the old `/gsd-complete-milestone` close flow to mark a milestone. These are
  *not* package versions.
- **Hex release tags** — semver `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`, `v1.1.0`, `v1.3.0`),
  the actual published package versions.

An **early, naive publish pipeline derived the Hex package version from any pushed `v*`
tag** (normalizing `v1.20` → `1.20.0`). When milestone `v1.20` was pushed, that pipeline
published a phantom Hex package **`1.20.0`** (same family as the earlier phantom `1.32.0`).

Because `1.20.0 > 1.3.0` by SemVer, Hex reports `latest_stable_version = 1.20.0`, so a real
adopter's `{:sigra, "~> 1.0"}` resolves to the **phantom**, not the real GA. Hex forbids
deletion after the grace window, so the only lever is `mix hex.retire` (reversible via
`--unretire`) — an interactive, write-authed step that has been repeatedly deferred (see the
retire todo). Low stakes today because there are no real adopters yet.

## Decision — guardrails to preserve (do NOT regress these)

1. **Publishing is Release-Please-driven.** The Hex version comes from Release Please's
   Release PR (conventional commits → `steps.release.outputs.version`), never from an
   arbitrary tag push. See `.github/workflows/release-please.yml`.
2. **No `on: push: tags: 'v*'` publish trigger, ever.** The only other publish path,
   `.github/workflows/hex-publish.yml`, is `workflow_dispatch`-only and requires an
   **explicit `release_version` input** that must match `@version` in `mix.exs` at the ref.
   A tag alone can never cause a publish.
3. **Do not mint milestone `vX.Y` git tags.** Milestone tagging was stopped after `v1.35`
   precisely to eliminate the namespace collision. If milestone marking is ever wanted
   again, use a **distinct namespace** (e.g. `milestone/v1.36`), never bare `v1.36`.

## Status of the residue

The historical footgun is **already structurally closed** (guardrails 1–3 are in place). The
only remaining residue is the already-published phantom `1.20.0` on Hex, whose retire is a
manual operator step **deferred indefinitely** (no adopters; the CI gate is unaffected — the
`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin greens it regardless). Tracked in
`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`.

## Consequences

- Future releases cannot repeat the phantom-publish even if stray `v*` tags exist.
- Phase 223's PROOF-01 "current on Hex at 1.3.0" bundle cannot be truthfully emitted until
  the phantom is retired; the phase is paused on that deferred operator step rather than
  force-completed.
