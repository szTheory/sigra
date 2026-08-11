defmodule Example.Accounts.CrosswakeContinuation do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "crosswake_continuations" do
    field :handle_digest, :binary
    field :state_digest, :binary
    field :pkce_challenge_digest, :binary
    field :return_ref, :string
    field :session_ref, :string
    field :subject_ref, :string
    field :session_version, :integer
    field :route_id, :string
    field :return_route_id, :string
    field :issued_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :consumed_at, :utc_datetime
    field :outcome, :string
    field :reason, :string
    field :audit_correlation_ref, :string
    timestamps(type: :utc_datetime)
  end

  def issue_changeset(continuation, attrs) do
    continuation
    |> cast(attrs, [
      :handle_digest,
      :state_digest,
      :pkce_challenge_digest,
      :return_ref,
      :session_ref,
      :subject_ref,
      :session_version,
      :route_id,
      :return_route_id,
      :issued_at,
      :expires_at,
      :audit_correlation_ref
    ])
    |> validate_required([
      :handle_digest,
      :state_digest,
      :pkce_challenge_digest,
      :return_ref,
      :session_ref,
      :subject_ref,
      :session_version,
      :route_id,
      :return_route_id,
      :issued_at,
      :expires_at,
      :audit_correlation_ref
    ])
    |> unique_constraint(:handle_digest)
  end

  def outcome_changeset(continuation, outcome, reason) do
    change(continuation, outcome: outcome, reason: to_string(reason))
  end
end
