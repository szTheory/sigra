---
created: 2026-07-03T00:00:00.000Z
status: pending
resolves_phase: 223
title: Retire stray Hex 1.20.0 so 1.1.0 is the resolved latest_stable
area: release
files:
  - milestones/v1.43-phases/214-debt-robustness-clear/214-05-SUMMARY.md
source: 2026-07-03 v1.43 close — Jon deferred (no time now); manual/interactive step, cannot be automated
deferred_again:
  - "2026-07-10 (Phase 221 close): nobody really using this yet"
  - "2026-07-11 (Phase 223 exec): Jon deferred indefinitely — no time, no adopters, don't stress it. Phase 223 paused on this step. Root cause captured in ADR 003."
priority: low
root_cause: ".planning/decisions/003-hex-release-versioning-no-tag-derived-publish.md (tag-derived publish + milestone vX.Y namespace collision; footgun already structurally closed)"
---

## What

A stray `1.20.0` was published to Hex during an earlier dev cycle (same family as
the old 1.32.0 confusion). Because 1.20.0 > 1.1.0 by SemVer, Hex reports
`latest_stable_version = 1.20.0`, so `{:sigra, "~> 1.0"}` resolves to **1.20.0**
instead of the real 1.1.0 GA. Deletion is not allowed post-grace-window — **retire
is the only lever** (reversible via `--unretire`). Hex.pm web UI has no retire
button; it's CLI/API only.

Phase 214 (DEBT-04) already cleared the *local* wart — deleted git tag `v1.20.0`
(local + remote) and corrected `contract.md` to 1.1.0 — but the **published Hex
version still outranks the GA**. This is the remaining half, and it needs Jon's
interactive Hex auth, so it can't be done by an agent.

## Why deferred

Purely a manual/interactive step, and now additionally blocked by a Hex 2.5
tooling limitation (see runbook). No real adopters are blocked today. Jon
deferred it at the v1.43 close ("don't have time right now"), and again at the
Phase 221 close (2026-07-10): "nobody is really using this yet." Orthogonal to
the gate — retire does NOT change the upgrade-smoke `sort -V` (the
`SIGRA_UPGRADE_SMOKE_START_VERSION=1.3.0` pin greens the gate), so PUB-01 is
unaffected by leaving this open. Target GA is now **1.3.0** (v1.2.0 + v1.3.0 were
published in Phase 221).

## How (runbook — updated Phase 221, Hex 2.5.0)

**Hex 2.5.0 wrinkle (found 2026-07-10):** the old `mix hex.user key generate
--key-name … --permission api` no longer exists (2.5 dropped the CLI `key
generate` subcommand — `mix help hex.user` shows only `auth`/`whoami`/`deauth`).
`mix hex.user auth` now uses an OAuth **device flow**; the token it provisions can
read (owner-list works) but is **NOT authorized to retire** — `mix hex.retire`
returns `key not authorized for this action` even though `sztheory` is a `full`
owner of the package. Programmatic retire via the device-flow token appears
blocked (likely the known Hex OAuth-scope issue).

Remaining path (untried by operator choice at 221 close):
1. Mint an API **write** key on the web dashboard: https://hex.pm/dashboard/keys
   (Hex 2.5 has no CLI key-gen). Grant it API / write permission.
2. Retire using that key via env override:
   `HEX_API_KEY=<key> mix hex.retire sigra 1.20.0 invalid --message "Published in error during dev cycle; not a real release — use 1.3.0+"`
3. Verify: `curl -s https://hex.pm/api/packages/sigra | jq '.latest_stable_version, .retirements'`
   → `latest_stable_version` should drop to `1.3.0`; `1.20.0` in `retirements`.

Reversible with `mix hex.retire sigra 1.20.0 --unretire` if ever needed.

## Done when

Hex reports `1.3.0` (not `1.20.0`) as `latest_stable_version` and `~> 1.0`
resolves to the real GA. See also the full runbook in
`milestones/v1.43-phases/214-debt-robustness-clear/214-05-SUMMARY.md`.
