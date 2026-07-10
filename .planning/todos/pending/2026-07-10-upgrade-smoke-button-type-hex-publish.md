---
created: 2026-07-10T00:00:00.000Z
status: pending
resolves_phase: 223
title: Fix upgrade-smoke `<.button type>` warning-as-error, then publish v1.2.0 + v1.3.0 to Hex
area: release
files:
  - lib/sigra_web/live/organization_settings_live.ex
  - priv/templates/sigra.install/organizations/live/organization_settings_live.ex
  - .github/workflows/hex-publish.yml
source: 2026-07-10 v1.44 ship — pre-existing push-CI debt blocks release-please auto Hex-publish; Jon chose defer-Hex (Option A). Manual/interactive publish step.
---

## What

v1.44 ADMIN-UX-RATCHET shipped to `main` (terminal PR #73 → `c0595e09`, 6/6 green on all
required gates). release-please cut **v1.2.0** (from #66) and **v1.3.0** (from #74) — both are
git-tagged + GitHub-released. **Neither is published to Hex.** Hex is still at v1.1.0.

## Why Hex publish was skipped

release-please's `hex-publish` job is gated on `ci-gate` being **green on the release SHA**.
`ci-gate` is red because of the **`Upgrade smoke (published source → local candidate)`** job,
which is **push/schedule-only** (it `skip`s on every `pull_request`, so it never appears on a PR's
checks — it only runs on push-to-`main`). It fails compiling the upgrade harness's generated app:

```
warning: undefined attribute "type" for component TmpAppUpgradeWeb.CoreComponents.button/1
  <.button type="submit" class="btn btn-error" phx-disable-with="Updating...">
Compilation failed due to warnings while using the --warnings-as-errors option
```

sigra's generated `organization_settings_live.ex` passes `type="submit"` to a host `<.button>`
whose `CoreComponents.button/1` (from the published phx.new series) does **not** declare an
`attr :type`. This has been **red on every push to `main` since the v1.43 ship (2026-07-03)** —
the last green main push was `49a89a18` (2026-07-02, pre-v1.43). It is **pre-existing debt, not a
v1.44 regression**. v1.42/v1.43 tolerated it because those were internal milestones not published
to Hex.

## Fix (two parts)

1. **Resolve the `<.button type>` incompatibility** so `Upgrade smoke` (and thus `ci-gate`) goes
   green on push-to-`main`. Occurrences: `lib/sigra_web/live/organization_settings_live.ex:173`
   and the installer template `priv/templates/sigra.install/organizations/live/organization_settings_live.ex:104`
   (and any siblings — grep `phx-disable-with="Updating..."` / `"Deleting..."`). Decide the correct
   Phoenix-1.8 pattern: either drop `type="submit"` (submit is the default for a `<.button>` inside
   a form) / use a native `<button type="submit">`, or ensure the emitted component declares
   `attr :type`. Verify by running the upgrade-smoke harness (or `gh workflow run "CI" --ref main`
   and confirm the `Upgrade smoke` job passes).

2. **Publish the two already-cut versions to Hex.** Once `ci-gate` is green (or via the manual
   escape hatch), dispatch the publish workflow for each:
   ```
   gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=true   # verify
   gh workflow run hex-publish.yml -f tag=v1.2.0 -f release_version=1.2.0 -f dry_run=false  # publish
   gh workflow run hex-publish.yml -f tag=v1.3.0 -f release_version=1.3.0 -f dry_run=false
   ```
   (`hex-publish.yml` is `workflow_dispatch` with `tag` + `release_version` + `dry_run` inputs;
   `HEX_API_KEY` is configured — it has published before.) NOTE: publishing v1.2.0 then v1.3.0
   keeps the Hex series contiguous (v1.1.0 → v1.2.0 → v1.3.0). Also revisit the stray Hex
   `1.20.0` retire ([[2026-07-03-hex-retire-stray-1-20-0]]) so `latest_stable` resolves correctly.

## Status

- GitHub side: **DONE** (v1.44 on `main`; v1.2.0 + v1.3.0 tagged + released).
- Hex side: **DEFERRED** — this TODO.
- Jon chose defer-Hex (Option A) at ship time to avoid pulling pre-existing out-of-scope upgrade-smoke
  debugging into the milestone close and to avoid force-bypassing a genuinely-red gate.
