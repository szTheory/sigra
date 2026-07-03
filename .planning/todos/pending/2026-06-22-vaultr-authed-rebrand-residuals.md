---
id: vaultr-authed-rebrand-residuals
created: 2026-06-22
source: 260622-i0e (Vaultr authed-screen rebrand)
severity: info
area: test/example/lib/example_web/live + controllers
resolves_phase: 218
---

# Vaultr authed-screen rebrand — residual daisyUI polish

The WS3 rebrand (260622-i0e) converted the major authed screens to `vt-*`, but a
few deep/low-traffic spots still carry inert daisyUI/Tailwind utilities. They're
**functional** (the demo is `--no-tailwind`, so these classes just don't paint —
they render as plain HTML, not broken), so this is cosmetic polish, not a bug.

Remaining:
1. **MFA settings (`mfa_settings_live.ex`)** — the top settings/disable/regenerate
   cards + status pill are vt-*, but the **enrollment sub-flows** (QR step, backup-
   codes grid, passkey list rows) still use `space-y-*`, `text-gray-*`, custom code
   inputs. Wrap remaining cards in `vt-panel`, code inputs as `.vt-form .input`.
2. **Org members (`organization_members_live.ex`)** — headers/badges/buttons/row-
   actions dropdown are vt-*, but the `<dialog class="modal">` confirm modals
   (invite / revoke / change-role / remove) and the invite form inputs
   (`input input-bordered`, `select select-bordered`, `label-text`) are still
   daisyUI. Build a `vt-modal` (or restyle the native `<dialog>`) + use `.vt-form`.
3. **`mfa_challenge_html.ex` + `mfa_challenge_controller.ex`** — a non-LiveView MFA
   challenge variant that is NOT wired in the router (the live `/users/mfa` is the
   real one). Confirm whether it's reachable at all; if dead code, consider removing;
   if reachable, wrap in the `vt-auth` surface like `mfa_challenge_live`.
4. **Sessions seed realism (`lib/example/demo/seeds.ex`)** — `/users/sessions`
   shows "Unknown device / Unknown IP / Unknown location" because dev has no
   user-agent-parser / GeoIP database (only 3 sessions are actually seeded; the rest
   are accumulated logins). Optionally set `geo_city`/`geo_country_code`/parsed UA on
   the seeded sessions so the demo reads realistic.

None block the demo; the screens are on-brand at the panel/button/form level.
