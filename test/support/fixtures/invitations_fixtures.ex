defmodule Sigra.InvitationsFixtures do
  @moduledoc """
  Phase 17 invitation test fixtures.

  These helpers are parameterized on the caller's `schema_module` and
  `repo` so they are reusable from both the Sigra library test suite
  and downstream host-app test suites (the example app or any
  generator-consuming project).

  The canonical invitation schema shape comes from
  `priv/templates/sigra.install/organizations/organization_invitation.ex`
  and has these fields:

    * `:organization_id`
    * `:email`
    * `:role`
    * `:hashed_token`
    * `:expires_at`
    * `:invited_by_id`
    * `:accepted_at`
    * `:revoked_at`

  Use `invitation_attrs/1` when you need a keyword list of attrs
  without inserting, or one of the `*_invite/3` helpers when you
  need a row inserted through a repo.
  """

  alias Sigra.Token

  # Default invitation TTL used by fixture helpers. Tests that need a
  # specific TTL should override `:expires_at` in opts.
  @default_ttl_ms :timer.hours(24 * 7)

  @doc """
  Builds a keyword list of invitation attrs. Does NOT insert.

  ## Required opts

    * `:organization_id`
    * `:invited_by_id`

  ## Optional opts

    * `:email` — defaults to a unique invitee address
    * `:role` — defaults to `:member`

  Returns the hashed token; callers that also need the raw token
  should call `Sigra.Token.generate_hashed_token/0` directly.
  """
  @spec invitation_attrs(keyword()) :: keyword()
  def invitation_attrs(opts \\ []) do
    email =
      Keyword.get(
        opts,
        :email,
        "invitee-#{System.unique_integer([:positive])}@example.com"
      )

    {_raw, hashed} = Token.generate_hashed_token()

    [
      organization_id: Keyword.fetch!(opts, :organization_id),
      email: email,
      role: Keyword.get(opts, :role, :member),
      hashed_token: hashed,
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(@default_ttl_ms, :millisecond)
        |> DateTime.truncate(:second),
      invited_by_id: Keyword.fetch!(opts, :invited_by_id),
      accepted_at: nil,
      revoked_at: nil
    ]
  end

  @doc """
  Inserts a pending invitation row through the caller's `repo` using
  the caller's invitation `schema_module`.
  """
  @spec pending_invite(module(), module(), keyword()) :: struct()
  def pending_invite(schema_module, repo, opts \\ []) do
    attrs = invitation_attrs(opts)

    schema_module
    |> struct!(attrs)
    |> repo.insert!()
  end

  @doc """
  Inserts an invitation with `accepted_at` pre-stamped.
  """
  @spec accepted_invite(module(), module(), keyword()) :: struct()
  def accepted_invite(schema_module, repo, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Keyword.put(invitation_attrs(opts), :accepted_at, now)

    schema_module
    |> struct!(attrs)
    |> repo.insert!()
  end

  @doc """
  Inserts an invitation with `revoked_at` pre-stamped.
  """
  @spec revoked_invite(module(), module(), keyword()) :: struct()
  def revoked_invite(schema_module, repo, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = Keyword.put(invitation_attrs(opts), :revoked_at, now)

    schema_module
    |> struct!(attrs)
    |> repo.insert!()
  end

  @doc """
  Inserts an invitation with `expires_at` set to one hour in the past.
  """
  @spec expired_invite(module(), module(), keyword()) :: struct()
  def expired_invite(schema_module, repo, opts \\ []) do
    expired =
      DateTime.utc_now()
      |> DateTime.add(-3600, :second)
      |> DateTime.truncate(:second)

    attrs = Keyword.put(invitation_attrs(opts), :expires_at, expired)

    schema_module
    |> struct!(attrs)
    |> repo.insert!()
  end
end
