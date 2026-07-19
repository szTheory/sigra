defmodule Mix.Tasks.Sigra.Admin.Grant do
  use Mix.Task

  @shortdoc "Grant platform-admin access to an existing confirmed account"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args), do: SigraInstallGoldenTmp.SigraAdminTask.run(:grant, args)
end
