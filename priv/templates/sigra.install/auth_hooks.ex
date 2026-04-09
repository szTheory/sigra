defmodule <%= context_module %>.Hooks do
  @moduledoc """
  Lifecycle hooks for auth operations.

  Each function receives an `Ecto.Multi` and a context map, and must return
  `{:ok, multi}` (optionally with additional Multi steps) or `{:error, reason}`
  to abort the transaction.

  Uncomment the hooks you need and add your application logic.
  See `Sigra.Hooks` documentation for details.

  ## Configuration

  Enable hooks in your Sigra config:

      config :<%= otp_app %>, :sigra,
        hooks: [
          # on_register: {<%= context_module %>.Hooks, :on_register},
          # on_email_change: {<%= context_module %>.Hooks, :on_email_change},
          # on_password_change: {<%= context_module %>.Hooks, :on_password_change},
          # on_delete: {<%= context_module %>.Hooks, :on_delete}
        ]
  """

  # @doc \"\"\"
  # Called after user registration.
  #
  # Context map includes:
  # - `:user` - The newly registered user
  # - `:changes` - Multi changes so far
  # \"\"\"
  # def on_register(multi, %{user: _user} = _context) do
  #   # Example: Create a profile record
  #   # multi = Ecto.Multi.insert(multi, :profile, %MyApp.Profile{user_id: user.id})
  #   {:ok, multi}
  # end

  # @doc \"\"\"
  # Called after email change is confirmed (not at request time).
  #
  # Context map includes:
  # - `:user` - The user whose email changed
  # - `:new_email` - The new email address
  # - `:changes` - Multi changes so far
  # \"\"\"
  # def on_email_change(multi, %{user: _user, new_email: _new_email} = _context) do
  #   {:ok, multi}
  # end

  # @doc \"\"\"
  # Called after password change.
  #
  # Context map includes:
  # - `:user` - The user whose password changed
  # - `:changes` - Multi changes so far
  # \"\"\"
  # def on_password_change(multi, %{user: _user} = _context) do
  #   {:ok, multi}
  # end

  # @doc \"\"\"
  # Called when account deletion is scheduled.
  #
  # Context map includes:
  # - `:user` - The user being deleted
  # - `:strategy` - The deletion strategy (:soft_delete, :hard_delete, :anonymize)
  # - `:changes` - Multi changes so far
  # \"\"\"
  # def on_delete(multi, %{user: _user, strategy: _strategy} = _context) do
  #   {:ok, multi}
  # end
end
