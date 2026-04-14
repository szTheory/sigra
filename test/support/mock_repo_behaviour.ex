defmodule Sigra.MockRepo.Behaviour do
  @moduledoc false
  # Minimal Ecto.Repo-like behaviour for Mox mocking in tests.

  @callback get_by(module(), keyword()) :: struct() | nil
  @callback get!(module(), term()) :: struct()
  @callback insert(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback insert!(struct()) :: struct()
  @callback update(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback update!(Ecto.Changeset.t()) :: struct()
  @callback delete!(struct()) :: struct()
  @callback get(module(), term()) :: struct() | nil
  @callback transaction(Ecto.Multi.t()) :: {:ok, map()} | {:error, atom(), term(), map()}
  @callback transact(Ecto.Multi.t()) ::
              {:ok, map()} | {:error, atom(), term(), map()} | {:error, term()}
  @callback delete_all(Ecto.Queryable.t()) :: {non_neg_integer(), nil | [term()]}
  @callback all(Ecto.Queryable.t()) :: [struct()]
  @callback update_all(Ecto.Queryable.t(), keyword()) :: {non_neg_integer(), nil | [term()]}
  @callback one(Ecto.Queryable.t()) :: struct() | nil
  @callback one!(Ecto.Queryable.t()) :: struct()
  @callback aggregate(Ecto.Queryable.t(), atom()) :: term()
end
