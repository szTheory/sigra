defmodule Example.Demo.Personas do
  @moduledoc """
  Single source of truth for the nine demo personas used by `Example.Demo.Seeds`.

  This is a pure-data module: no DB calls, no dependencies on other Example modules.
  Consumed both by the seed orchestrator (plan 03) and the `/demo/credentials` LiveView
  (plan 04).

  All personas use the `@demo.vaultr.test` email domain to keep seeded data strictly
  segregated from the golden-path CI fixture domain used in `mix test`.

  Passwords are public-by-design demo credentials. Each password satisfies
  `Sigra.PasswordPolicy` rules (12+ chars, mixed case, digit, symbol).
  Never use these passwords in production.
  """

  # Demo-only — intentionally deterministic. Never use in production.
  @demo_totp_secret :crypto.hash(:sha256, "sigra-demo-admin-totp-v1") |> binary_part(0, 20)
  @demo_domain "demo.vaultr.test"

  @doc """
  Returns the fictional Vaultr cohort email domain used by the demo data.
  """
  @spec demo_domain() :: String.t()
  def demo_domain, do: @demo_domain

  @doc """
  Builds a demo-cohort email address for a local part.
  """
  @spec email(String.t()) :: String.t()
  def email(local) when is_binary(local), do: local <> "@" <> @demo_domain

  @doc """
  Returns the list of all nine demo personas as maps.

  Each persona map contains:
  - `:email` — fixed `@demo.vaultr.test` address
  - `:display_name` — role-descriptive, stable across re-seeds
  - `:password` — policy-passing, public-by-design demo credential
  - `:confirmed` — whether to confirm the user after registration
  - `:totp` — whether to enroll TOTP MFA (uses `demo_totp_secret/0`)
  - `:passkey` — whether to insert a display-only passkey row
  - `:locked` — whether to set failed_login_attempts=5 + locked_at
  - `:scheduled_deletion` — whether to set deleted_at + scheduled_deletion_at
  - `:identity_github` — whether to insert a GitHub OAuth identity row
  - `:org_owner` — org handle this persona owns (atom or nil)
  - `:org_admin` — org handle this persona administers, non-platform (atom or nil)
  - `:org_member` — org handle this persona is a member of (atom or nil)
  """
  @spec all() :: [map()]
  def all do
    [
      %{
        email: email("admin"),
        display_name: "Admin (operator)",
        password: "DemoAdmin1!SecurePass",
        confirmed: true,
        totp: true,
        passkey: true,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: :acme,
        org_admin: nil,
        org_member: :beta
      },
      %{
        email: email("alice"),
        display_name: "Alice",
        password: "AliceDemoPass1!",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_admin: nil,
        org_member: :acme
      },
      %{
        email: email("bob"),
        display_name: "Bob",
        password: "BobDemoPass1!Beta",
        confirmed: true,
        totp: true,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: :beta,
        org_admin: nil,
        org_member: nil
      },
      %{
        email: email("carol"),
        display_name: "Carol",
        password: "CarolDemoPass1!Github",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: true,
        org_owner: nil,
        org_admin: nil,
        org_member: :acme
      },
      %{
        email: email("dave"),
        display_name: "Dave",
        password: "DaveDemoPass1!Locked",
        confirmed: false,
        totp: false,
        passkey: false,
        locked: true,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_admin: nil,
        org_member: nil
      },
      %{
        email: email("frank"),
        display_name: "Frank",
        password: "FrankDemoPass1!Deleted",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: true,
        identity_github: false,
        org_owner: nil,
        org_admin: nil,
        org_member: nil
      },
      %{
        email: email("morgan"),
        display_name: "Morgan (org admin)",
        password: "MorganDemo1!OrgAdmin",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_admin: :acme,
        org_member: nil
      },
      %{
        email: email("pat"),
        display_name: "Pat",
        password: "PatDemoPass1!Passkey",
        confirmed: true,
        totp: false,
        passkey: true,
        locked: false,
        scheduled_deletion: false,
        identity_github: false,
        org_owner: nil,
        org_admin: nil,
        org_member: nil
      },
      %{
        email: email("grace"),
        display_name: "Grace",
        password: "GraceDemoPass1!Acme",
        confirmed: true,
        totp: false,
        passkey: false,
        locked: false,
        scheduled_deletion: true,
        identity_github: false,
        org_owner: nil,
        org_admin: nil,
        org_member: :acme
      }
    ]
  end

  @doc """
  Returns the feature-text map keyed by email local part. Single source of truth (D-02)
  consumed by CredentialsLive and Seeds.run/0. Keys are the email local part (string before
  '@') for all nine @demo.vaultr.test personas.
  """
  @spec feature_map() :: %{String.t() => String.t()}
  def feature_map do
    %{
      "admin" => "Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail",
      "alice" => "Standard confirmed user — happy path login, Acme Corp member",
      "bob" => "TOTP MFA enrolled — org owner (Beta Labs)",
      "carol" => "OAuth identity — GitHub-linked login (#{email("carol")})",
      "dave" => "Locked account — failed login attempts exhausted, unconfirmed",
      "frank" => "Scheduled deletion — account marked for deletion",
      "morgan" => "Org admin — Acme Corp admin, non-platform, org-scoped console",
      "pat" =>
        "Passkey-only user — no MFA, passkey display row, demonstrates Passkeys pill on users index",
      "grace" => "Deletion-scheduled Acme member — demonstrates in-roster Deletion scheduled pill"
    }
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
