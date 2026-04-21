defmodule Sigra.Test.MultiStub do
  @moduledoc false

  @doc """
  Minimal `Ecto.Multi` runner for test repos that do not implement full
  `Ecto.Repo` transaction semantics. Understands `Ecto.Multi.to_list/1` shapes
  (`{:insert | :update | :delete, changeset, opts}` and `{:run, fun}`).
  """
  def run(repo, %Ecto.Multi{} = multi) do
    multi
    |> Ecto.Multi.to_list()
    |> Enum.reduce_while({:ok, %{}}, fn
      {name, {:run, fun}}, {:ok, acc} ->
        case fun.(repo, acc) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, reason} -> {:halt, {:error, name, reason, acc}}
        end

      {name, {:insert, changeset, _opts}}, {:ok, acc} ->
        case repo.insert(changeset) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, %Ecto.Changeset{} = cs} -> {:halt, {:error, name, cs, acc}}
        end

      {name, {:update, changeset, _opts}}, {:ok, acc} ->
        case repo.update(changeset) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, %Ecto.Changeset{} = cs} -> {:halt, {:error, name, cs, acc}}
        end

      {name, {:delete, changeset, _opts}}, {:ok, acc} ->
        struct = Ecto.Changeset.apply_changes(changeset)

        case repo.delete(struct) do
          {:ok, result} -> {:cont, {:ok, Map.put(acc, name, result)}}
          {:error, %Ecto.Changeset{} = cs} -> {:halt, {:error, name, cs, acc}}
        end

      {name, op}, {:ok, _acc} ->
        {:halt, {:error, name, {:unsupported_multi_operation, op}, %{}}}
    end)
  end
end
