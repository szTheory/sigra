defmodule <%= app_module %>.SigraAdminTask do
  @moduledoc false

  alias <%= app_module %>.SigraAdminAccess

  def run(action, args) when action in [:grant, :revoke, :check] do
    Mix.Task.run("app.start")
    {opts, rest, invalid} = OptionParser.parse(args, strict: [email: :string, yes: :boolean])
    validate_args!(rest, invalid)
    email = (opts[:email] || Mix.shell().prompt("Account email:")) |> String.trim()

    if email == "", do: Mix.raise("An account email is required. Pass --email EMAIL.")
    maybe_confirm!(action, email, opts[:yes])
    dispatch(action, email)
  end

  def run(:list, args) do
    Mix.Task.run("app.start")
    {opts, rest, invalid} = OptionParser.parse(args, strict: [])
    validate_args!(rest, invalid)
    _ = opts

    case SigraAdminAccess.list_active() do
      [] -> Mix.shell().info("No active platform-admin grants.")
      grants -> Enum.each(grants, &Mix.shell().info(&1.user.email))
    end
  end

  defp dispatch(:grant, email) do
    case SigraAdminAccess.grant(email) do
      {:ok, _grant, :granted} -> Mix.shell().info("Granted platform-admin access to #{email}.")
      {:ok, _grant, :already_granted} -> Mix.shell().info("#{email} already has platform-admin access.")
      {:error, reason} -> raise_action_error!(email, reason)
    end
  end

  defp dispatch(:revoke, email) do
    case SigraAdminAccess.revoke(email) do
      {:ok, _grant, :revoked} -> Mix.shell().info("Revoked platform-admin access from #{email}.")
      {:ok, _grant, :already_revoked} -> Mix.shell().info("#{email} has no active platform-admin grant.")
      {:error, reason} -> raise_action_error!(email, reason)
    end
  end

  defp dispatch(:check, email) do
    case SigraAdminAccess.check(email) do
      {:ok, _user, true} -> Mix.shell().info("#{email} has platform-admin access.")
      {:ok, _user, false} -> Mix.raise("#{email} does not have platform-admin access.")
      {:error, reason} -> raise_action_error!(email, reason)
    end
  end

  defp maybe_confirm!(:check, _email, _yes), do: :ok

  defp maybe_confirm!(_action, _email, true), do: :ok

  defp maybe_confirm!(action, email, _yes) do
    unless Mix.shell().yes?("#{String.capitalize(to_string(action))} platform-admin access for #{email}?") do
      Mix.raise("Cancelled; no changes were made.")
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    Mix.raise(
      "Unexpected arguments: #{inspect(rest ++ invalid)}. Use --email EMAIL and, for mutations, optional --yes."
    )
  end

  defp raise_action_error!(email, :user_not_found),
    do: Mix.raise("No account exists for #{email}. Register the account first.")

  defp raise_action_error!(email, :user_unconfirmed),
    do: Mix.raise("#{email} is not confirmed. Confirm the account before granting access.")

  defp raise_action_error!(email, :user_deleted),
    do: Mix.raise("#{email} is deleted and cannot receive platform-admin access.")

  defp raise_action_error!(_email, %Ecto.Changeset{} = changeset),
    do: Mix.raise("The platform-admin grant could not be saved: #{inspect(changeset.errors)}")

  defp raise_action_error!(_email, reason),
    do: Mix.raise("The platform-admin operation failed: #{inspect(reason)}")
end
