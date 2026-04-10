defmodule Example.OAuthTest do
  @moduledoc """
  Plan 10-06 D-17 #5: OAuth callback smoke test (mocked).

  Uses `Sigra.Testing.mock_oauth_callback/1` (or equivalent shipped helper)
  to simulate an OAuth provider response without making real network calls.
  """
  use Example.DataCase, async: true
  @moduletag :example_app

  test "Sigra.Testing exposes mock_oauth_callback helper" do
    Code.ensure_loaded!(Sigra.Testing)
    # mock_oauth_callback/0 and /1 exist (optional keyword opts).
    assert function_exported?(Sigra.Testing, :mock_oauth_callback, 0) or
             function_exported?(Sigra.Testing, :mock_oauth_callback, 1)
  end

  test "mock_oauth_callback builds a valid provider payload shape" do
    # Shipped helper returns a mocked callback payload with provider,
    # user_info, and token fields.
    result = Sigra.Testing.mock_oauth_callback(provider: :google, email: "alice@example.com")
    assert is_map(result)
    assert result.provider == :google
    assert result.user_info["email"] == "alice@example.com"
    assert is_binary(result.token["access_token"])
  end
end
