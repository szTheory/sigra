<!-- validated_against: mailglass ~> 1.2 -->
<!-- last_validated: 2026-05-27 -->
# Recipe: Sigra + Mailglass (transactional auth email)

Validated against: `mailglass ~> 1.2` as of 2026-05-27

> **Sigra works fully standalone.** Mailglass is an optional integration; Sigra ships without it, and removing the entry below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| Sigra-side email callback | `Sigra.Mailer` behaviour (host-owned impl) | `deliver/3` contract; host implements and configures |
| Mail dispatch + auth-stream privacy guard | **Mailglass** `~> 1.2` | Routes transactional email through configured provider; enforces `NoTrackingOnAuthStream` at compile time |

Mailglass sits **above** Swoosh — it is not a Swoosh adapter. Sigra's existing Swoosh-based
mailer rails are unaffected when you add Mailglass. The host implements `Sigra.Mailer` and
delegates to a Mailglass-backed module; Sigra has no direct dependency on Mailglass.

## Prerequisites

- **Sigra email flows must be green first** — confirm that confirmation, password-reset, and
  magic-link emails are delivering correctly before adding Mailglass. See the
  [installation guide](../introduction/installation.html) and [OAuth flow](../flows/oauth.html).
- **Mailglass `~> 1.2` installed and configured** — API key and sender domain set in your
  Mailglass config.

## `mix.exs` snippet

**Host app only** — Sigra does not add Mailglass as a dependency.

```elixir
defp deps do
  [
    {:sigra, "~> 1.29"},
    {:mailglass, "~> 1.2"},
    # ... your other deps
  ]
end
```

> Mailglass sits **above** Swoosh — it is not a Swoosh adapter. Sigra's existing
> Swoosh-based mailer rails are unaffected.

## Sigra-side mailer module

Define a module in your host app that implements `@behaviour Sigra.Mailer` and delegates
delivery to Mailglass:

```elixir
defmodule MyApp.SigraAuthMailer do
  @moduledoc """
  Sigra.Mailer implementation backed by Mailglass transactional delivery.
  """

  @behaviour Sigra.Mailer

  # stream: :transactional is REQUIRED — see note below
  use Mailglass.Mailable, stream: :transactional

  @impl Sigra.Mailer
  def deliver(to, subject, body) do
    html = if is_map(body), do: Map.get(body, :html), else: body
    text = if is_map(body), do: Map.get(body, :text), else: body

    Mailglass.deliver(%{
      to: to,
      subject: subject,
      html_body: html,
      text_body: text
    })
  end
end
```

> **`stream: :transactional` is required.** Mailglass enforces `NoTrackingOnAuthStream` at
> compile time on this stream (`deps/mailglass/lib/mailglass/mailable.ex:30-33`). Using
> `:bulk` for auth mail would re-introduce open/click tracking pixels into password-reset and
> confirmation email, and the guard blocks compilation. Always use `stream: :transactional`
> for auth email.

Then register the module in your Sigra config:

```elixir
config :sigra, mailer: MyApp.SigraAuthMailer
```

## Failure modes

### 1. Mailable wired on wrong stream

If any non-transactional stream (e.g. `:bulk`) is used in a module handling auth email,
Mailglass raises a `NoTrackingOnAuthStream` compile-time error. This is a privacy guard —
open/click tracking pixels in password-reset and confirmation email are a data-exposure
regression. Fix: ensure `use Mailglass.Mailable, stream: :transactional` is set on the
module registered as `Sigra.Mailer`.

### 2. Mailglass adapter unconfigured or API key missing

If Mailglass is not configured or the API key is missing at runtime, `Mailglass.deliver/2`
returns `{:error, _}`. Because `MyApp.SigraAuthMailer.deliver/3` propagates this return value,
`Sigra.Mailer.deliver/3` returns `{:error, _}` and the calling auth flow surfaces an error to
the user. This is intentional — Sigra does not silently swallow delivery failures. See the
[OAuth flow](../flows/oauth.html) for error-bubbling semantics.

### 3. Mailglass + Oban backpressure

If Mailglass is configured with Oban-backed delivery and the Oban queue is saturated, emails
queue and the auth flow returns success immediately (Mailglass owns retry semantics for its
queue). Sigra's v1.25 EMAIL-RAILS async-delivery telemetry (`Sigra.Delivery` /
`Sigra.Workers.EmailDelivery`) still applies for the Sigra-originated dispatch leg.

## Non-goals

- Sigra does **not** ship a library-resident Mailglass adapter. The orphaned Phase 111/114
  adapter code does not re-land in v1.29 (see STATE.md deferred items and STACK.md:14-23). A
  corrigendum correcting the v1.25 EMAIL-RAILS Mailglass narrative has landed in `CHANGELOG.md`
  (v1.25 entry); the same correction appears in MILESTONES.md and PROJECT.md under v1.25.
- There is **no `--with-mailglass` install flag** in `mix sigra.install`.
- Sigra does **not** ship mailable templates for Mailglass — host owns rendering. The
  `deliver/3` body argument accepts `String.t()`, `%{html:, text:}`, or `%{text:}` per the
  `Sigra.Mailer` behaviour contract; host formats the body before passing it to the mailer.

## See also

- [OAuth flow](../flows/oauth.html) — email delivery error-bubbling semantics
- [Installation guide](../introduction/installation.html) — Sigra email flow prerequisites
- [Threadline recipe](./threadline.html) — forwarding audit events to Threadline timelines
- [Suite integration overview](../introduction/suite-integration.html) — companion-library
  ecosystem diagram (Phase 133 NX-01; link ships ahead of the page)
