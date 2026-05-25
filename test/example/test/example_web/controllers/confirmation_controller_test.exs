defmodule ExampleWeb.ConfirmationControllerTest do
  use ExampleWeb.ConnCase, async: false

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))
  defp route_info(method, path), do: Phoenix.Router.route_info(ExampleWeb.Router, method, path, "localhost")

  describe "confirmed-email passkey enrollment handoff" do
    test "GET /users/confirm/:token?enroll_passkey=1 hands off through sudo-gated passkey settings" do
      controller = source("lib/example_web/controllers/confirmation_controller.ex")

      assert controller =~ ~S("enroll_passkey" => "1")
      assert controller =~ "passkey_bootstrap_return_to"
      assert controller =~ "bootstrap_passkey=1"
      assert controller =~ "/users/settings/mfa?bootstrap_passkey=1#passkeys"
      assert controller =~ "URI.encode_www_form"
      assert controller =~ "UserAuth.log_in_user(user, %{})"
      assert controller =~ "Your email has been confirmed."
    end

    test "normal /users/confirm/:token preserves the existing non-enrollment redirect behavior" do
      controller = source("lib/example_web/controllers/confirmation_controller.ex")

      assert controller =~ "def confirm(conn,"
      assert controller =~ "redirect(to: ~p\"/\")"
      assert controller =~ "Your email has been confirmed."
      refute controller =~ "UserAuth.log_in_user(_user)"
    end

    test "controller source keeps the enroll_passkey redirect and flash explicit" do
      controller = source("lib/example_web/controllers/confirmation_controller.ex")

      assert controller =~ "passkey_bootstrap_return_to"
      assert controller =~ "bootstrap_passkey=1"
      assert controller =~ "Your email has been confirmed"
      assert controller =~ "enroll_passkey"
    end

    test "router serves token confirmation through ConfirmationController and keeps code entry on LiveView" do
      assert route_info("GET", "/users/confirm/example-token").plug == ExampleWeb.ConfirmationController
      assert route_info("GET", "/users/confirm/example-token").plug_opts == :confirm
      assert route_info("GET", "/users/confirm").plug == Phoenix.LiveView.Plug
    end
  end
end
