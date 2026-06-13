# SEED-004 — Forward-compat with phx.new ≥ 1.8.8 `<.button>` (type attr dropped)

**Status:** OPEN (follow-up). Filed 2026-06-13 on v1.38-brand-v2 / PR #52.
**Priority:** Medium — real DX bug for new adopters on latest Phoenix, but worked around for CI.

## Problem
`phx_new` **1.8.8** (released 2026-06-10) changed the generated host app's default
`CoreComponents.button/1`: its `:global` `:rest` include list no longer accepts `type`
(and friends). Sigra's generated templates call `<.button type="submit" phx-disable-with=…>`
in many places (e.g. `organization_settings_live.ex:65/104/140/244`, `mfa_settings_live.ex:205`,
`invitation_accept_live.ex:283`, `session_html.ex:54`, `organization_members_live.ex:343`).
Against the 1.8.8 button these emit `undefined attribute "type" for component …CoreComponents.button/1`,
which **fails the generated app's compile under `--warnings-as-errors`**.

Sigra does **not** generate/patch `core_components.ex` — the button comes from `mix phx.new`.
So any adopter running latest `mix phx.new` + `sigra.install` hits the same compile failure.

This is upstream environment drift, **not** a brand-v2 regression: the affected `<.button>`
callsites are byte-identical to green `origin/main`, and PR #47 (off main) was fully green on
2026-06-07 when latest phx_new was 1.8.7.

## Workaround applied (PR #52)
Pinned `mix archive.install --force hex phx_new` → `phx_new 1.8.7` in all CI workflows
(`ci.yml` ×9, `release-please.yml`, `hex-publish.yml`). This restores deterministic green for
install/golden/vault jobs and is the right call for reproducible install testing — but it
**masks** the forward-compat gap for end users on latest Phoenix.

## Real fix options (pick during follow-up)
1. **Make Sigra robust to the new button API.** Detect/patch the generated `core_components.ex`
   during `sigra.install` to add `type` (+ needed phx-* globals) back into the button's `:rest`
   include list — or, better, align Sigra's templates with whatever 1.8.8+ button contract is
   (inspect the new daisyUI button; it may expose `type` differently).
2. **Stop relying on host `<.button type=…>`** in generated templates — use a Sigra-owned button
   wrapper (`sigra_auth_components.ex` already exists) or plain `<button type=…>` where the
   semantic `type` matters (form submit vs button).
3. Bump the pin forward (1.8.8/1.8.x) **once** option 1 or 2 lands, so CI tracks current Phoenix.

## Acceptance
- Fresh `mix phx.new` (latest) + `mix sigra.install` compiles clean under `--warnings-as-errors`.
- CI pin bumped to current phx_new (or pin removed) with install/golden/vault jobs green.
- Golden fixture regenerated against the new phx_new if its `core_components.ex` bytes change.

## Pointers
- Diagnosis evidence: PR #52 CI run 27460287319 (install-smoke / vault_promotion_test logs).
- Pin commit: this branch (v1.38-brand-v2).
- Related (resolved, different pair): `preexisting-core-template-failures.md`.
