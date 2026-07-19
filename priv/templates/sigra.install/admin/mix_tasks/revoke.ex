defmodule Mix.Tasks.Sigra.Admin.Revoke do
  use Mix.Task

  @shortdoc "Revoke an account's platform-admin access"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args), do: <%= app_module %>.SigraAdminTask.run(:revoke, args)
end
