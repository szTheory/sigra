---
quick_id: 260718-svg
title: "Wire the current-session detection so the sessions self-revoke guard actually renders"
status: ready
---

# Sessions self-revoke guard — light up the already-coded (but dead) "This device" badge + revoke-current confirm.

The badge + guard already EXIST in all three synced copies; they never render because
`mount/3` reads `get_connect_params(socket)["_sigra_token"]` and NOTHING sets `_sigra_token`,
so `current_token` is always `nil`. Replace the dead client connect-param path with a
server-side read of the Plug `session` map (works on dead + connected render, no JS, and
stops trusting a spoofable client value). Apply the SAME fix to all three copies, then
re-bless the golden fixture.

Facts (verified):
- Raw session token is stored in the Plug session under `:user_token` (`user_auth.ex:493`,
  read as `session["user_token"]` in on_mount at `user_auth.ex:374`).
- DB session rows store `hashed_token = Sigra.Token.hash_token(raw_token)` (`accounts.ex:525`).
- `Sigra.Token.hash_token/1` is public: `@spec hash_token(binary()) :: binary()` (`lib/sigra/token.ex:113`).
- So: `Sigra.Token.hash_token(session["user_token"])` == the current row's `hashed_token`.

## Task 1 — Demo copy: `test/example/lib/example_web/live/auth/session_live.ex`
(a) `mount/3` (~L21): stop ignoring the session; compute the current hashed token server-side.
    Rename the assign `current_token` → `current_hashed_token` for accuracy:
```elixir
def mount(_params, session, socket) do
  user = socket.assigns.current_scope.user
  sessions = Auth.list_sessions(user)

  {:ok,
   assign(socket,
     sessions: sessions,
     current_hashed_token: current_hashed_token(session),
     user_organizations: Organizations.list_organizations_for_user(user),
     page_title: "Active sessions"
   )}
end
```
(b) Update the three render refs `@current_token` → `@current_hashed_token` (badge `:if` ~L62,
    revoke_current `:if` ~L74, revoke `:if` ~L83). No other markup change.
(c) Replace `current_session?/2` (~L154-161) with a direct binary compare + add the helper:
```elixir
defp current_hashed_token(%{"user_token" => raw}) when is_binary(raw),
  do: Sigra.Token.hash_token(raw)

defp current_hashed_token(_), do: nil

defp current_session?(%{hashed_token: token}, current) when is_binary(current),
  do: token == current

defp current_session?(_, _), do: false
```
(d) Update the moduledoc line (~L9-10): "Current session is identified via the session token
    passed through LiveView connect params" → "Current session is identified from the server-side
    Plug session token (hashed for comparison) and tagged with a \"This device\" badge."

## Task 2 — Installer template: `priv/templates/sigra.install/core/session_live.ex`
Apply the IDENTICAL logic (EEx flavor). The template mount has no `user_organizations` — keep
it minimal:
```elixir
def mount(_params, session, socket) do
  user = socket.assigns.current_scope.user
  sessions = Auth.list_sessions(user)

  {:ok, assign(socket,
    sessions: sessions,
    current_hashed_token: current_hashed_token(session),
    page_title: "Active Sessions"
  )}
end
```
Update the render refs (`@current_token` → `@current_hashed_token` at the badge `:if` ~L52 and
BOTH branches of the `<%%= if current_session?(session, @current_token) do %>` ~L68/L52),
replace `current_session?/2` + add `current_hashed_token/1` (same bodies as Task 1c), and update
the same moduledoc line (~L9-10). Keep the Tailwind markup and `import <%= web_module %>.SigraAuthComponents`
exactly. `Sigra.Token` is a dependency of every generated app, so `Sigra.Token.hash_token/1`
resolves in the generated LiveView.

## Task 3 — Re-bless the golden fixture
Run `mix sigra.fixture.rebless_golden` (regenerates `test/fixtures/install_golden/tree/.../live/auth/session_live.ex`
from the updated template). Confirm via `git diff --stat` that the ONLY golden change is that one
session_live.ex file (if the rebless touches unrelated files, STOP and report — do not commit noise).

## Verification (executor)
- `mix compile --warnings-as-errors` at repo root AND `cd test/example && mix compile --warnings-as-errors` — both clean.
- Golden + template tests green:
  `mix test test/sigra/install/golden_diff_test.exs test/sigra/templates/session_templates_test.exs`
  (these require the phx_new 1.8.8 archive + Postgres; if DB down try `scripts/db/up.sh && source tmp/db.env`, else note SKIPPED with reason).
- Demo tests unaffected: `cd test/example && mix test test/example_web/live/auth --include example_app` if such dir exists, else the smoke suite touching sessions — note what ran.
- `git diff --stat`: exactly three files — the demo session_live.ex, the template session_live.ex, and the one golden session_live.ex. NO other golden/fixture churn, no *.png.
- Commit in ONE atomic commit (message e.g. `fix(quick-260718-svg): wire current-session detection for sessions self-revoke guard`). Code/fixtures only — NOT docs/planning. Orchestrator does live browser verification (badge + confirm) + STATE.md.
