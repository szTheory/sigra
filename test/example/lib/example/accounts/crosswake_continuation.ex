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
    field :issued_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec
    field :outcome, :string
    field :reason, :string
    field :audit_correlation_ref, :string
    timestamps(type: :utc_datetime)
  end

  @issue_fields [
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
  ]

  def issue_changeset(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> change(Map.take(attrs, @issue_fields))
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
    |> validate_change(:handle_digest, &validate_digest/2)
    |> validate_change(:state_digest, &validate_digest/2)
    |> validate_change(:pkce_challenge_digest, &validate_digest/2)
    |> validate_number(:session_version, greater_than: 0)
    |> unique_constraint(:handle_digest)
  end

  def outcome_changeset(continuation, outcome, reason) do
    change(continuation, outcome: outcome, reason: stable_reason(reason))
  end

  defp validate_digest(_field, value) when is_binary(value) and byte_size(value) == 32, do: []
  defp validate_digest(field, _value), do: [{field, "must be a SHA-256 digest"}]

  defp stable_reason(reason)
       when reason in [
              :allowed,
              :invalid_or_expired_handle,
              :oauth_state_or_pkce_failure,
              :invalid_return_evidence,
              :session_unavailable,
              :binding_mismatch,
              :route_denied
            ],
       do: Atom.to_string(reason)

  defp stable_reason(_reason), do: "route_denied"
end
