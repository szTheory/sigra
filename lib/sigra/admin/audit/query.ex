defmodule Sigra.Admin.Audit.Query do
  @moduledoc """
  Admin-owned audit query wrapper for shared explorer and export semantics.
  """

  import Ecto.Query

  alias Sigra.Audit.Query, as: AuditQuery

  @subject_filter :subject_user_id

  @spec allowed_filters() :: [atom()]
  def allowed_filters do
    AuditQuery.allowed_filters() ++ [@subject_filter]
  end

  @spec build(Ecto.Queryable.t(), keyword()) :: Ecto.Query.t()
  def build(audit_schema, filters \\ []) do
    {subject_user_id, base_filters} = Keyword.pop(filters, @subject_filter)

    audit_schema
    |> AuditQuery.build(base_filters)
    |> maybe_filter_subject_user(subject_user_id)
  end

  @spec paginate(Ecto.Query.t(), nil | {DateTime.t(), binary()}, pos_integer()) :: Ecto.Query.t()
  def paginate(query, cursor, limit), do: AuditQuery.paginate(query, cursor, limit)

  @spec for_subject_user(Ecto.Queryable.t(), binary()) :: Ecto.Query.t()
  def for_subject_user(queryable, user_id) when is_binary(user_id) do
    from(event in queryable,
      where: event.effective_user_id == ^user_id or event.target_id == ^user_id
    )
  end

  defp maybe_filter_subject_user(query, nil), do: query
  defp maybe_filter_subject_user(query, user_id), do: for_subject_user(query, user_id)
end
