defmodule <%= app_module %>.Mailer do
  @moduledoc """
  Swoosh mailer wrapper.

  This file is emitted by `mix sigra.install` only if the host application
  does not already define a `<%= app_module %>.Mailer` module. If the host
  was scaffolded via `mix phx.new` (without `--no-mailer`), Phoenix already
  generates this module and the installer's skip-if-exists guard will
  leave the existing file untouched.

  Configure the adapter per environment in `config/{dev,test,prod}.exs`:

      config :<%= otp_app %>, <%= app_module %>.Mailer,
        adapter: Swoosh.Adapters.Local
  """
  use Swoosh.Mailer, otp_app: :<%= otp_app %>
end
