defmodule Example.Demo.Personas do
  @moduledoc """
  Single source of truth for the six demo personas used by `Example.Demo.Seeds`.

  This is a pure-data module: no DB calls, no dependencies on other Example modules.
  Consumed both by the seed orchestrator (plan 03) and the `/demo/credentials` LiveView
  (plan 04).

  All personas use the `@demo.sigra.dev` email domain to keep seeded data strictly
  segregated from the golden-path CI fixture domain used in `mix test`.

  Passwords are public-by-design demo credentials. Each password satisfies
  `Sigra.PasswordPolicy` rules (12+ chars, mixed case, digit, symbol).
  Never use these passwords in production.
  """

  # Demo-only — intentionally deterministic. Never use in production.
  @demo_totp_secret :crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)

  @doc """
  Returns the list of all six demo personas as maps.

  Each persona map contains:
  - `:email` — fixed `@demo.sigra.dev` address
  - `:display_name` — role-descriptive, stable across re-seeds
  - `:password` — policy-passing, public-by-design demo credential
  - `:confirmed` — whether to confirm the user after registration
  - `:totp` — whether to enroll TOTP MFA (uses `demo_totp_secret/0`)
  - `:passkey` — whether to insert a display-only passkey row
  - `:locked` — whether to set failed_login_attempts=5 + locked_at
  - `:scheduled_deletion` — whether to set deleted_at + scheduled_deletion_at
  - `:identity_github` — whether to insert a GitHub OAuth identity row
  - `:org_owner` — org handle this persona owns (atom or nil)
  - `:org_member` — org handle this persona is a member of (atom or nil)
  """
  @spec all() :: [map()]
  def all do
    [
      %{
        email: "admin@demo.sigra.dev",
        display_name: "Admin (operator)",
        password: "DemoAdmin1!SecurePass",
        confirmed: true,
        totp: true,
        passkey: true,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: :acme,
        org_member: :beta
      },
      %{
        email: "alice@demo.sigra.dev",
        display_name: "Alice",
        password: "AliceDemoPass1!",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_member: :acme
      },
      %{
        email: "bob@demo.sigra.dev",
        display_name: "Bob",
        password: "BobDemoPass1!Beta",
        confirmed: true,
        totp: true,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: :beta,
        org_member: nil
      },
      %{
        email: "carol@demo.sigra.dev",
        display_name: "Carol",
        password: "CarolDemoPass1!Github",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: true,
        org_owner: nil,
        org_member: nil
      },
      %{
        email: "dave@demo.sigra.dev",
        display_name: "Dave",
        password: "DaveDemoPass1!Locked",
        confirmed: false,
        totp: false,
        passkey: false,
        locked: true,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_member: nil
      },
      %{
        email: "frank@demo.sigra.dev",
        display_name: "Frank",
        password: "FrankDemoPass1!Deleted",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: true,
        identity_github: false,
        org_owner: nil,
        org_member: nil
      }
    ]
  end

  @doc """
  Returns the deterministic demo-only TOTP secret (20-byte binary).

  Derived as `SHA-256("sigra-demo-admin-totp-v1") |> binary_part(0, 20)`.

  Used by both the `admin` and `bob` personas during seeding.

  WARNING: This is a public-by-design fixture value. Never use in production.
  """
  @spec demo_totp_secret() :: binary()
  def demo_totp_secret, do: @demo_totp_secret
end
