defmodule Sigra.OAuth.Smoketest do
  @moduledoc """
  Runtime support for `mix sigra.oauth.smoketest`.

  This module intentionally keeps the host-app ceremony small: load Sigra's
  runtime config, boot a loopback-only callback endpoint, print the Google
  authorize URL, wait for the callback, then exchange the code and print the
  decoded `id_token` claims.
  """

  @oauth_state_purpose "sigra-oauth-state"
  @oauth_state_max_age 900
  @callback_path "/callback"
  @callback_timeout_ms 300_000

  @type exit_code :: 1 | 2 | 3

  @spec run(keyword()) :: :ok | {:error, exit_code(), String.t()}
  def run(opts) do
    provider_input = Keyword.get(opts, :provider)
    port = Keyword.get(opts, :port, 4001)
    owner = self()

    with {:ok, provider} <- normalize_provider(provider_input),
         {:ok, runtime_config} <- load_runtime_config(opts),
         {:ok, provider_config} <- provider_config(runtime_config, provider, port),
         {:ok, start_info} <- start_callback_server(opts, owner, port),
         {:ok, authorize} <- build_authorize_request(opts, provider, provider_config),
         :ok <- print_instructions(opts, authorize.url, port),
         {:ok, params} <- await_callback(opts),
         :ok <- verify_state(params, authorize.state, authorize.secret_key_base),
         {:ok, user_info, token} <-
           exchange_callback(opts, provider, provider_config, params, authorize),
         {:ok, claims} <- decode_id_token(token),
         {:ok, %{sub: sub, email: email}} <- extract_identity(claims, user_info) do
      print_success(opts, sub, email, claims)
      stop_callback_server(opts, start_info)
      :ok
    else
      {:error, _code, _reason} = error ->
        maybe_stop_server(opts)
        error
    end
  rescue
    error ->
      maybe_stop_server(opts)
      {:error, 3, Exception.message(error)}
  end

  defp normalize_provider("google"), do: {:ok, :google}
  defp normalize_provider(:google), do: {:ok, :google}
  defp normalize_provider(nil), do: {:error, 1, "missing --provider"}
  defp normalize_provider(other), do: {:error, 1, "unknown provider #{inspect(other)}"}

  defp load_runtime_config(opts) do
    load_fun = Keyword.get(opts, :load_config_fun, &default_load_runtime_config/1)

    case load_fun.(opts) do
      {:ok, config} -> {:ok, config}
      {:error, reason} when is_binary(reason) -> {:error, 2, reason}
      {:error, code, reason} -> {:error, code, reason}
      other -> {:error, 2, "unexpected config loader result: #{inspect(other)}"}
    end
  end

  defp default_load_runtime_config(opts) do
    config_ref = Keyword.get(opts, :config)

    with {:ok, raw} <- load_raw_config(config_ref),
         {:ok, normalized} <- normalize_runtime_config(raw) do
      {:ok, normalized}
    end
  end

  defp load_raw_config(nil) do
    otp_app = Application.get_env(:sigra, :otp_app) || Mix.Project.config()[:app]

    cond do
      is_nil(otp_app) ->
        {:error,
         "could not determine otp_app; set Application.get_env(:sigra, :otp_app) or use --config"}

      true ->
        sigra_config = Application.get_env(otp_app, :sigra_config, [])
        sigra_runtime = Application.get_env(otp_app, :sigra, [])

        unless is_list(sigra_config) and is_list(sigra_runtime) do
          {:error, "expected #{inspect(otp_app)} :sigra and :sigra_config to be keyword lists"}
        else
          merged =
            sigra_config
            |> Keyword.merge(sigra_runtime)
            |> Keyword.put_new(:otp_app, otp_app)

          secret_key_base =
            merged[:secret_key_base] ||
              infer_secret_key_base(otp_app, merged[:endpoint])

          {:ok, Keyword.put(merged, :secret_key_base, secret_key_base)}
        end
    end
  end

  defp load_raw_config(config_ref) when is_binary(config_ref) do
    with {:ok, {module, function}} <- parse_config_ref(config_ref),
         true <- Code.ensure_loaded?(module) || {:error, "could not load #{inspect(module)}"},
         true <-
           function_exported?(module, function, 0) ||
             {:error, "#{inspect(module)}.#{function}/0 is not available"},
         result <- apply(module, function, []) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, "invalid config reference #{inspect(config_ref)}"}
    end
  end

  defp normalize_runtime_config(%Sigra.Config{} = config) do
    {:ok,
     %{
       otp_app: config.otp_app,
       secret_key_base: config.secret_key_base,
       oauth: config.oauth
     }}
  end

  defp normalize_runtime_config(config) when is_list(config) do
    {:ok,
     %{
       otp_app: Keyword.get(config, :otp_app),
       secret_key_base: Keyword.get(config, :secret_key_base),
       oauth: Keyword.get(config, :oauth, [])
     }}
  end

  defp normalize_runtime_config(other) do
    {:error, "expected a Sigra config keyword list or %Sigra.Config{}, got: #{inspect(other)}"}
  end

  defp parse_config_ref(config_ref) do
    cleaned = config_ref |> String.trim() |> String.trim_trailing("/0")

    case Regex.run(~r/\A(.+)\.([a-z_][a-zA-Z0-9_]*)\z/, cleaned, capture: :all_but_first) do
      [module_name, function_name] ->
        {:ok, {Module.concat([module_name]), String.to_atom(function_name)}}

      nil ->
        {:ok, {Module.concat([cleaned]), :sigra_config}}
    end
  end

  defp infer_secret_key_base(_otp_app, nil), do: nil

  defp infer_secret_key_base(otp_app, endpoint) when is_atom(endpoint) do
    cond do
      Code.ensure_loaded?(endpoint) and function_exported?(endpoint, :config, 1) ->
        endpoint.config(:secret_key_base)

      true ->
        otp_app
        |> Application.get_env(endpoint, [])
        |> Keyword.get(:secret_key_base)
    end
  end

  defp infer_secret_key_base(otp_app, _endpoint) do
    endpoint =
      otp_app
      |> to_string()
      |> Macro.camelize()
      |> Kernel.<>("Web")
      |> then(&Module.concat([&1, "Endpoint"]))

    infer_secret_key_base(otp_app, endpoint)
  end

  defp provider_config(%{secret_key_base: nil}, _provider, _port) do
    {:error, 2,
     "missing secret_key_base; set it in runtime config or pass a config module that provides it"}
  end

  defp provider_config(%{secret_key_base: secret_key_base, oauth: oauth}, provider, port) do
    providers = Keyword.get(oauth, :providers, [])

    case Keyword.get(providers, provider) do
      nil ->
        {:error, 2, "provider #{provider} is not configured under :sigra oauth.providers"}

      provider_config ->
        required = [:client_id, :client_secret]

        case Enum.find(required, &(blank?(provider_config[&1]) && &1)) do
          nil ->
            callback_url = "http://127.0.0.1:#{port}#{@callback_path}"

            {:ok,
             provider_config
             |> Keyword.put(:redirect_uri, callback_url)
             |> Keyword.put(:secret_key_base, secret_key_base)}

          key ->
            {:error, 2, "provider #{provider} is missing #{key}"}
        end
    end
  end

  defp start_callback_server(opts, owner, port) do
    start_fun = Keyword.get(opts, :start_server_fun, &default_start_callback_server/1)

    server_opts = [
      ip: {127, 0, 0, 1},
      port: port,
      owner: owner,
      callback_path: @callback_path
    ]

    case start_fun.(server_opts) do
      {:ok, server} ->
        Process.put({__MODULE__, :server}, server)
        {:ok, server}

      {:error, _reason} = error ->
        error

      other ->
        {:error, 2, "unexpected server start result: #{inspect(other)}"}
    end
  end

  defp default_start_callback_server(server_opts) do
    unless Code.ensure_loaded?(Bandit) do
      {:error, 2,
       "Bandit is not available. Add it to your host app deps or run the smoketest from a Phoenix 1.8+ app."}
    else
      bandit_opts = [
        scheme: :http,
        ip: Keyword.fetch!(server_opts, :ip),
        port: Keyword.fetch!(server_opts, :port),
        plug: {CallbackPlug, owner: Keyword.fetch!(server_opts, :owner)}
      ]

      case apply(Bandit, :start_link, [bandit_opts]) do
        {:ok, pid} -> {:ok, pid}
        {:error, reason} -> {:error, 2, "could not start callback server: #{inspect(reason)}"}
      end
    end
  end

  defp build_authorize_request(opts, provider, provider_config) do
    authorize_fun =
      Keyword.get(opts, :authorize_url_fun, fn cfg ->
        Sigra.OAuth.Strategies.Google.authorize_url(cfg)
      end)

    secret_key_base = Keyword.fetch!(provider_config, :secret_key_base)

    case authorize_fun.(provider_config) do
      {:ok, %{url: url, session_params: session_params}} ->
        state = generate_state(secret_key_base, provider)

        {:ok,
         %{
           url: replace_url_state(url, state),
           state: state,
           secret_key_base: secret_key_base,
           session_params: session_params
         }}

      {:ok, %{url: url}} ->
        state = generate_state(secret_key_base, provider)

        {:ok,
         %{
           url: replace_url_state(url, state),
           state: state,
           secret_key_base: secret_key_base,
           session_params: %{}
         }}

      {:error, reason} ->
        {:error, 2, "could not build authorize URL: #{inspect(reason)}"}
    end
  end

  defp print_instructions(opts, url, port) do
    print_fun = Keyword.get(opts, :print_fun, fn line -> Mix.shell().info(line) end)
    print_fun.("Open this URL in your browser:")
    print_fun.(url)
    print_fun.("Waiting for callback on http://127.0.0.1:#{port}#{@callback_path} ...")
    :ok
  end

  defp await_callback(opts) do
    receive_fun = Keyword.get(opts, :receive_callback_fun, &default_receive_callback/1)
    receive_fun.(Keyword.get(opts, :timeout_ms, @callback_timeout_ms))
  end

  defp default_receive_callback(timeout_ms) do
    receive do
      {:sigra_oauth_smoketest_callback, params} -> {:ok, params}
    after
      timeout_ms -> {:error, 3, "timed out waiting for the OAuth callback"}
    end
  end

  defp verify_state(params, expected_state, secret_key_base) do
    received = params["state"] || params[:state]

    cond do
      blank?(received) ->
        {:error, 3, "provider callback did not include a state parameter"}

      not Plug.Crypto.secure_compare(received, expected_state) ->
        {:error, 3, "state mismatch during callback"}

      true ->
        case Sigra.Token.verify(secret_key_base, @oauth_state_purpose, received,
               max_age: @oauth_state_max_age
             ) do
          {:ok, _payload} -> :ok
          {:error, _reason} -> {:error, 3, "state verification failed"}
        end
    end
  end

  defp exchange_callback(opts, _provider, provider_config, params, authorize) do
    callback_fun =
      Keyword.get(opts, :callback_fun, fn cfg, incoming, session_params ->
        Sigra.OAuth.Strategies.Google.callback(cfg, incoming, session_params)
      end)

    case callback_fun.(provider_config, params, authorize.session_params) do
      {:ok, user_info, token} ->
        {:ok, user_info, token}

      {:error, reason} ->
        {:error, 3, "token exchange failed: #{inspect(reason)}"}
    end
  end

  defp decode_id_token(%{"id_token" => id_token}) when is_binary(id_token) do
    with [_, payload, _] <- String.split(id_token, "."),
         {:ok, decoded} <- Base.url_decode64(payload, padding: false),
         {:ok, claims} <- Jason.decode(decoded) do
      {:ok, claims}
    else
      _ -> {:error, 3, "malformed id_token returned by provider"}
    end
  end

  defp decode_id_token(_token), do: {:error, 3, "provider callback did not return an id_token"}

  defp extract_identity(claims, user_info) do
    email = claims["email"] || user_info["email"]
    sub = claims["sub"] || user_info["sub"]

    cond do
      blank?(sub) -> {:error, 3, "id_token did not include sub"}
      blank?(email) -> {:error, 3, "id_token did not include email"}
      true -> {:ok, %{sub: sub, email: email}}
    end
  end

  defp print_success(opts, sub, email, claims) do
    print_fun = Keyword.get(opts, :print_fun, fn line -> Mix.shell().info(line) end)
    print_fun.("OK — got back valid id_token with sub=#{sub} and email=#{email}")
    print_fun.("Claims: #{inspect(claims)}")
  end

  defp stop_callback_server(opts, server) do
    stop_fun = Keyword.get(opts, :stop_server_fun, &default_stop_callback_server/1)
    stop_fun.(server)
    Process.delete({__MODULE__, :server})
  end

  defp maybe_stop_server(opts) do
    case Process.get({__MODULE__, :server}) do
      nil -> :ok
      server -> stop_callback_server(opts, server)
    end
  end

  defp default_stop_callback_server(pid) when is_pid(pid) do
    GenServer.stop(pid)
    :ok
  end

  defp generate_state(secret_key_base, provider) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    Sigra.Token.generate(
      secret_key_base,
      @oauth_state_purpose,
      %{provider: to_string(provider), nonce: nonce},
      max_age: @oauth_state_max_age
    )
  end

  defp replace_url_state(url, state) do
    uri = URI.parse(url)
    query = URI.decode_query(uri.query || "")
    new_query = Map.put(query, "state", state) |> URI.encode_query()
    %{uri | query: new_query} |> URI.to_string()
  end

  defp blank?(value), do: is_nil(value) or value == ""

  defmodule CallbackPlug do
    @moduledoc false

    import Plug.Conn
    @callback_path "/callback"

    def init(opts), do: opts

    def call(%Plug.Conn{request_path: @callback_path} = conn, opts) do
      conn = fetch_query_params(conn)
      send(opts[:owner], {:sigra_oauth_smoketest_callback, conn.params})

      send_resp(
        conn,
        200,
        "Sigra OAuth smoketest received the callback. You can close this tab."
      )
    end

    def call(conn, _opts), do: send_resp(conn, 404, "Not found")
  end
end
