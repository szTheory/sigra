defmodule Sigra.Install.OAuthSmoketestTaskTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  defmodule TaskImplStub do
    def run(opts) do
      send(self(), {:task_impl_opts, opts})

      case Process.get(:task_impl_result, :ok) do
        fun when is_function(fun, 1) -> fun.(opts)
        other -> other
      end
    end
  end

  describe "mix sigra.oauth.smoketest" do
    setup do
      original = Application.get_env(:sigra, :oauth_smoketest_impl)
      Application.put_env(:sigra, :oauth_smoketest_impl, TaskImplStub)

      on_exit(fn ->
        if original do
          Application.put_env(:sigra, :oauth_smoketest_impl, original)
        else
          Application.delete_env(:sigra, :oauth_smoketest_impl)
        end

        Process.delete(:task_impl_result)
      end)

      :ok
    end

    test "passes validated options to the runtime" do
      capture_io(fn ->
        Mix.Tasks.Sigra.Oauth.Smoketest.run([
          "--provider=google",
          "--port=4100",
          "--config=Example.Accounts.sigra_config/0"
        ])
      end)

      assert_received {:task_impl_opts,
                       [provider: "google", port: 4100, config: "Example.Accounts.sigra_config/0"]}
    end

    test "prints success when the runtime returns :ok" do
      output =
        capture_io(fn ->
          Mix.Tasks.Sigra.Oauth.Smoketest.run(["--provider=google"])
        end)

      assert output =~ "OK — round-trip succeeded."
    end

    test "exits with the runtime error code" do
      Process.put(:task_impl_result, {:error, 2, "missing config"})

      assert catch_exit(
               capture_io(:stderr, fn ->
                 Mix.Tasks.Sigra.Oauth.Smoketest.run(["--provider=google"])
               end)
             ) == {:shutdown, 2}
    end

    test "requires --provider" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Mix.Tasks.Sigra.Oauth.Smoketest.run([])
      end
    end
  end

  describe "Sigra.OAuth.Smoketest.run/1" do
    test "returns success after a simulated callback and exchanges on loopback" do
      parent = self()

      result =
        capture_io(fn ->
          send(
            parent,
            {:runtime_result,
             Sigra.OAuth.Smoketest.run(
               provider: "google",
               port: 4101,
               load_config_fun: fn _opts ->
                 {:ok,
                  %{
                    secret_key_base: String.duplicate("a", 64),
                    oauth: [
                      providers: [
                        google: [client_id: "cid", client_secret: "secret"]
                      ]
                    ]
                  }}
               end,
               start_server_fun: fn server_opts ->
                 send(parent, {:server_opts, server_opts})
                 {:ok, self()}
               end,
               stop_server_fun: fn _server -> :ok end,
               authorize_url_fun: fn _provider_config ->
                 {:ok,
                  %{
                    url: "https://accounts.example.test/auth?state=placeholder",
                    session_params: %{code_verifier: "verifier"}
                  }}
               end,
               receive_callback_fun: fn _timeout_ms ->
                 receive do
                   {:authorize_state, state} -> {:ok, %{"state" => state, "code" => "auth-code"}}
                 end
               end,
               callback_fun: fn _provider_config, _params, _session ->
                 {:ok, %{"sub" => "google-sub", "email" => "jon@example.test"},
                  %{
                    "id_token" =>
                      "eyJhbGciOiJub25lIn0." <>
                        Base.url_encode64(
                          Jason.encode!(%{
                            "sub" => "google-sub",
                            "email" => "jon@example.test"
                          }),
                          padding: false
                        ) <> ".sig"
                  }}
               end,
               print_fun: fn line ->
                 if String.contains?(line, "https://accounts.example.test/auth") do
                   [_, state] = Regex.run(~r/state=([^&]+)/, line)
                   send(parent, {:authorize_state, state})
                 end

                 send(parent, {:print, line})
               end
             )}
          )
        end)

      assert is_binary(result)
      assert_received {:runtime_result, :ok}

      assert_received {:server_opts,
                       [ip: {127, 0, 0, 1}, port: 4101, owner: _, callback_path: "/callback"]}

      assert_received {:print,
                       "OK — got back valid id_token with sub=google-sub and email=jon@example.test"}
    end

    test "returns config error when the provider is missing" do
      assert {:error, 2, "provider google is not configured under :sigra oauth.providers"} =
               Sigra.OAuth.Smoketest.run(
                 provider: "google",
                 load_config_fun: fn _opts ->
                   {:ok, %{secret_key_base: String.duplicate("a", 64), oauth: []}}
                 end
               )
    end
  end
end
