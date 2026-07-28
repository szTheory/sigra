---
created: 2026-07-28T00:00:00.000Z
status: pending
title: "gate-ci-green's 30-minute polling ceiling is shorter than the push-to-main CI run it waits for, so it times out on a green release and blocks the automated Hex publish"
area: release
files:
  - .github/workflows/release-please.yml
  - .github/workflows/ci.yml
severity: high
source: 2026-07-28 quick task (post-release 1.4.0 bookkeeping) — diagnosed during the Sigra 1.4.0 Hex publish recovery
resolves_phase: 231
---

## What

The `gate-ci-green` job in `.github/workflows/release-please.yml` polls for a successful
`ci-gate` on the release SHA with `max_attempts=60` at `wait_seconds=30`
(release-please.yml lines 119-120) — a hard **30-minute ceiling**. On the 1.4.0 release it
timed out on a release that was *actually green*, blocking the automated Hex publish for no
good reason.

This never worked for a push-to-`main` release run, and it will not work on the next release
either. It is not a flake.

## Evidence

Each of these is checkable against the run history:

- Release SHA `cfc5e6b88e1e95403c488fc518fd6f5469a9b015` (tag `v1.4.0`).
- ci.yml run **30379435985** (event `push`, branch `main`) started **2026-07-28T16:41:34Z**
  and concluded `success`; its `ci-gate` job also concluded `success`.
- `gate-ci-green` in release-please run **30379435970** logged that it gave up waiting for
  `ci-gate` on that SHA at **2026-07-28T17:16:37Z** and exited 1 — roughly **one minute
  BEFORE the very run it was waiting on finished**.
- Consequence: `publish-hex` was skipped because its `needs` were unmet (release-please.yml
  line 173: `needs: [release-please, gate-ci-green]`), so tag `v1.4.0` and a GitHub Release
  existed with **nothing on Hex**.

## Why this is structural, not bad luck

A push-to-`main` ci.yml run is **strictly heavier** than the `pull_request` run that gates the
Release PR, because jobs such as the in-CI admin-design baseline recapture are skipped on
`pull_request` but run on `push`.

Observed on the same content:

| Run | Event | Duration |
|-----|-------|----------|
| 30376746574 | `pull_request` | ~25 minutes |
| 30379435985 | `push` to `main` | ~35 minutes (16:41:34Z → ~17:16Z), including ~4 minutes of queue time before any job started |

The 30-minute ceiling is therefore **below the expected duration of the run it waits for**. Every
future release hits this until the ceiling changes.

## Recommended fix (NOT implemented by this todo)

This todo records the diagnosis only. Nothing in `.github/` or `scripts/` was changed.

1. Raise `max_attempts` so the ceiling lands at **45 to 60 minutes** — roughly 90 to 120
   attempts at the existing 30-second `wait_seconds` interval.
2. Consider having the give-up message (release-please.yml line 168,
   `Timed out waiting for ci-gate on SHA ${sha}. Last run: ${last_run_url:-none}`) name the run
   URL it abandoned in a more prominent form, so the timeout is diagnosable from the annotation
   alone.

Note that the workflow already dispatches ci.yml on the tag at attempt 3 when no run exists, so
the **retry scaffolding itself is sound** — only the ceiling is wrong.

## Working recovery (verbatim, so it need not be re-derived)

1.4.0 was shipped by manually dispatching the standalone publish workflow:

```bash
gh workflow run hex-publish.yml -f tag=v1.4.0 -f release_version=1.4.0 -f dry_run=false
```

Run **30382271344**, all 23 steps green.

That workflow independently re-verifies the following before it writes to Hex, so the manual
dispatch is not a trust downgrade relative to the automated path:

- tag/version match
- tag-commit provenance
- the `@version` in `mix.exs`
- agreement with `.release-please-manifest.json`
- `source_ref`
- a full unsharded `mix test`
- `mix docs` with warnings-as-errors
- tarball contents, asserting `.planning` is absent

It also dry-runs before publishing and is idempotent — it skips if the version is already on Hex.
