defmodule Sigra.MockRepo.Behaviour do
  @moduledoc false
  # Minimal Ecto.Repo-like behaviour for Mox mocking in tests.

  @callback get_by(module(), keyword()) :: struct() | nil
  @callback get!(module(), term()) :: struct()
  @callback insert(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback insert!(struct()) :: struct()
  @callback update(Ecto.Changeset.t()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback delete!(struct()) :: struct()
end
