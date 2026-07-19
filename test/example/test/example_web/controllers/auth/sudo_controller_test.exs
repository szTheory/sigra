defmodule ExampleWeb.Auth.SudoControllerTest do
  use ExampleWeb.ConnCase, async: true

  @moduletag :example_app

  describe "GET /users/sudo (demo Fill-password band dev-gating)" do
    setup :register_and_log_in_user

    test "under mix test (dev_routes=false) the demo band is compiled out", %{conn: conn} do
      body =
        conn
        |> get(~p"/users/sudo")
        |> html_response(200)

      # The dev-only demo Fill-password band (SudoHTML + SudoController.demo_persona_for/1)
      # must never render outside a dev_routes build — mirrors the session_controller refutes.
      refute body =~ ~s(data-testid="demo-bar")
      refute body =~ "data-demo-fill-password"
      refute body =~ "data-demo-persona-switch"
    end
  end
end
