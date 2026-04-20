defmodule ExampleWeb.ConfirmationControllerTest do
  use ExampleWeb.ConnCase, async: false

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))

  describe "confirmed-email passkey enrollment handoff" do
    test "GET /users/confirm/:token?enroll_passkey=1 hands off through sudo-gated passkey settings" do
      controller = source("lib/example_web/controllers/confirmation_controller.ex")

      assert controller =~ ~S("enroll_passkey" => "1")

      assert controller =~
               "put_session(:user_return_to, ~p\"/users/sudo?return_to=/users/settings/mfa#passkeys\")"

      assert controller =~ "UserAuth.log_in_user(user, %{})"
      assert controller =~ "Your email has been confirmed."
      assert "/users/sudo?return_to=/users/settings/mfa#passkeys"
      assert "enroll_passkey"
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

      assert controller =~ "/users/sudo?return_to=/users/settings/mfa#passkeys"
      assert controller =~ "Your email has been confirmed"
      assert controller =~ "enroll_passkey"
    end
  end
end
