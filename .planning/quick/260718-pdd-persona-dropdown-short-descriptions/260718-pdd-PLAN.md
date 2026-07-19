---
quick_id: 260718-pdd
title: "Persona switch <select> options need short unique descriptors"
status: ready
---

# Persona dropdown descriptions — add a short tagline per persona. Example-only, dev-gated surface.

ALL example-only (test/example/). NO priv/templates/, NO test/fixtures/, NO *.png.
The persona `<select>` in the unified demo bar currently shows bare `display_name`s
("Admin (operator)", "Alice", "Bob"…) — meaningless to demo visitors. Every option
needs a VERY short unique descriptor of what makes that account distinct, format
`Name — <descriptor>`. Distinct from the LONG `feature_map/0` (that drives the identity
block + credentials cards); this is a NEW short map for the dropdown only.

## Task 1 — `taglines/0` short map + enrich `options/0`
`test/example/lib/example/demo/personas.ex`:
(a) Add a public `taglines/0` (mirror the `feature_map/0` doc/spec style), keyed by email
local part, VERY short (≤ ~4 words), describing the unique account state — NOT the name:
```elixir
@spec taglines() :: %{String.t() => String.t()}
def taglines do
  %{
    "admin" => "MFA + passkey, multi-org",
    "alice" => "standard user, happy path",
    "bob" => "MFA + Beta Labs owner",
    "carol" => "GitHub OAuth login",
    "dave" => "locked, unconfirmed",
    "frank" => "scheduled for deletion",
    "morgan" => "Acme org console",
    "pat" => "passkey sign-in",
    "grace" => "member, deletion scheduled",
    "zoe" => "zero-state, empty panels"
  }
end
```
(b) Change `options/0` to include `:tagline` (keep `:key` + `:display_name` unchanged):
```elixir
def options do
  Enum.map(all(), fn p ->
    local = p.email |> String.split("@") |> hd()
    %{key: local, display_name: p.display_name, tagline: taglines()[local]}
  end)
end
```
Update the `@spec` for `options/0` accordingly. FIRST grep to confirm `options/0` is
consumed ONLY by the demo-bar dropdown (session_html, sudo_html, layouts → `<.demo_bar>`),
so adding a key is safe — do NOT touch `feature_map/0`, `featured_keys/0`, or the home
get-started picker (those are separate surfaces).

## Task 2 — render the tagline in the `<option>`
`test/example/lib/example_web/components/demo_bar.ex` (`demo_bar/1`, the `<option :for>`):
render the descriptor after an em-dash, gracefully omitting it if absent:
```heex
<option :for={p <- @personas} value={p.key} selected={@persona && @persona.key == p.key}>
  {[p.display_name, p.tagline && " — #{p.tagline}"]}
</option>
```
(HEEx renders the list; a `nil`/`false` tagline yields nothing. Keep the placeholder
`<option value="" disabled>Switch persona…</option>` and `data-demo-persona-switch` /
`aria-label` unchanged.)

## Verification (executor, browser-free)
- `cd test/example && mix compile --warnings-as-errors` clean.
- `git diff --stat`: only test/example/ (personas.ex + demo_bar.ex). No priv/templates, no test/fixtures, no *.png.
- `cd test/example && mix test test/example_web/controllers/session_controller_test.exs test/example_web/controllers/auth/sudo_controller_test.exs test/example_web/live/app_live_test.exs --include example_app` green (dev-gate refutes still hold). If DB down: scripts/db/up.sh && source tmp/db.env if present, else note SKIPPED.
- Commit in one part (code only, NOT docs). Live browser verification is the orchestrator's job.
