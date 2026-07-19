defmodule Mix.Tasks.Sigra.Admin.Grant do
  use Mix.Task

  @shortdoc "Grant platform-admin access to an existing confirmed account"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args), do: <%= app_module %>.SigraAdminTask.run(:grant, args)
end
