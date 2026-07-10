---
created: 2026-07-10T00:00:00.000Z
status: pending
resolves_phase: 223
title: Publish v1.2.0/v1.3.0 to Hex — one-time break of the upgrade-smoke chicken-and-egg (self-heals)
area: release
files:
  - scripts/ci/upgrade-smoke.sh
  - .github/workflows/hex-publish.yml
source: 2026-07-10 v1.44 ship — Jon chose defer-Hex (Option A). Irreversible publish; deliberate manual step.
---

## What

v1.44 shipped to `main` (terminal PR #73 → `c0595e09`). release-please cut **v1.2.0** (#66) and
**v1.3.0** (#74) — both git-tagged + GitHub-released. **Neither is on Hex.** Hex is still v1.1.0.

## Root cause (corrected 2026-07-10 — it is NOT a code fix)

release-please's `hex-publish` is gated on `ci-gate` green on the release SHA. `ci-gate` is red
because the **push/schedule-only** `Upgrade smoke (published source → local candidate)` job fails:

```
warning: undefined attribute "type" for component TmpAppUpgradeWeb.CoreComponents.button/1
  <.button type="submit" class="btn btn-error" phx-disable-with="Updating...">
Compilation failed due to warnings while using --warnings-as-errors
```

**The current templates are already fixed** — `priv/templates/sigra.install/organizations/live/organization_settings_live.ex`
uses `<.button class="btn btn-error" …>` (no `type=`; a `<button>` inside a form defaults to
submit, and phx.new 1.8's `button/1` declares `attr :rest, :global` **without** `type` in its
include list, so passing `type=` warns). There is **no `<.button type=>` left in `priv/templates/`**.
(The `lib/sigra_web/…organization_settings_live.ex` reference in the first draft of this TODO was a
red herring — that path was stray stash contamination during the ship, now removed; sigra keeps web
code in `priv/templates/`, not `lib/sigra_web/`.)

`upgrade-smoke.sh` sets `SOURCE_SERIES="${SIGRA_UPGRADE_SOURCE_SERIES:-1}"` and resolves the
**latest published `1.x`** from Hex (`resolve_latest_sigra_source`). Today that's **v1.1.0**, whose
OLD template still has `<.button type="submit">` → the generated-then-upgraded app fails
`--warnings-as-errors`. Pure **chicken-and-egg**: publish is blocked by upgrade-smoke; upgrade-smoke
is red only because the fixed template isn't published yet.

## Fix — one-time manual publish (self-heals)

Publishing v1.2.0 (or v1.3.0) to Hex ONCE makes `resolve_latest_sigra_source` pick up the fixed,
`type=`-free template on the next push, so `Upgrade smoke` / `ci-gate` go green and future
release-please auto-publishes work normally. The v1.2.0/v1.3.0 **content is already verified** (all
5 required checks + `fast_checks` were green on PRs #66/#73/#74), so this is a safe one-time break of
the gate, not shipping unverified code:

```
gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=true   # verify
gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=false  # publish
gh workflow run hex-publish.yml -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=false  # publish (contiguous 1.1→1.2→1.3)
```

(`hex-publish.yml` is `workflow_dispatch` with `tag` + `release_version` + `dry_run`; `HEX_API_KEY`
is configured — it has published before. Hex publish is IRREVERSIBLE — versions can only be retired.)

Optional hardening (avoids relying on the one-time break): make `upgrade-smoke.sh` tolerant of an
old published template — e.g. don't compile the generated-from-published app with
`--warnings-as-errors`, or pin `SIGRA_UPGRADE_SOURCE_SERIES` to a known-good minor. Lower priority
once v1.2/v1.3 are published.

Also revisit the stray Hex `1.20.0` retire ([[2026-07-03-hex-retire-stray-1-20-0]]) so
`latest_stable` resolves correctly.

## Status

- GitHub side: **DONE** (v1.44 on `main`; v1.2.0 + v1.3.0 tagged + released).
- Hex side: **DONE** (Phase 221, 2026-07-10) — v1.2.0 (runs 29108801612 dry-run + 29109600146 real)
  and v1.3.0 (29113000684) published; both confirmed live via the Hex API. Phase 221 also pinned
  `SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` (the deterministic lever, orthogonal to the self-heal).
- Remaining for Phase 223: the optional `upgrade-smoke.sh` hardening above, and the stray `1.20.0`
  retire ([[2026-07-03-hex-retire-stray-1-20-0]], still deferred — Hex 2.5 blocks programmatic retire).
