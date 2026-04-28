defmodule Mix.Tasks.Sigra.Oauth.Smoketest do
  @shortdoc "Verifies your OAuth provider configuration with a real round-trip"

  @moduledoc """
  Adopter-side real-credential check. Boots a tiny callback endpoint on
  `127.0.0.1`, prints the authorize URL, and waits for you to complete the
  provider flow in a browser.

  ## Usage

      mix sigra.oauth.smoketest --provider=google
      mix sigra.oauth.smoketest --provider=google --port=4001

  ## Flags

    * `--provider` - Required provider to test. Currently only `google`.
    * `--port` - Local callback port. Default: `4001`.
    * `--config` - Optional explicit config path (for example
      `MyApp.Accounts.sigra_config/0`).

  ## Exit Codes

    * `0` - Success
    * `1` - Usage error
    * `2` - Config error
    * `3` - Round-trip failure
  """

  use Mix.Task

  @switches [provider: :string, port: :integer, config: :string]

  @options_schema [
    provider: [type: :string, required: true, doc: "Provider to test (google)."],
    port: [type: :integer, default: 4001, doc: "Local callback port."],
    config: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Optional explicit Sigra config path."
    ]
  ]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")

    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)
    validated = NimbleOptions.validate!(opts, @options_schema)

    case impl().run(validated) do
      :ok ->
        Mix.shell().info("OK — round-trip succeeded.")

      {:error, code, reason} ->
        Mix.shell().error("FAIL: #{reason}")
        exit({:shutdown, code})
    end
  end

  defp impl do
    Application.get_env(:sigra, :oauth_smoketest_impl, Sigra.OAuth.Smoketest)
  end
end
