defmodule Sigra.Passkeys.UserPasskeyTemplateTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.{CoseKey, Credential}
  alias Sigra.Test.Support.PasskeyFixtures

  @template_path Path.join([
                   File.cwd!(),
                   "priv",
                   "templates",
                   "sigra.install",
                   "passkeys",
                   "user_passkey.ex"
                 ])

  test "template renders and compiles" do
    binding = template_binding()
    rendered = EEx.eval_file(@template_path, binding)
    assert rendered =~ "defmodule #{binding[:context_module]}.UserPasskey do"

    define_support_modules(binding)

    [{mod, _} | _] = Code.compile_string(rendered)
    assert function_exported?(mod, :create_changeset, 2)
    assert function_exported?(mod, :update_changeset, 2)
  end

  test "create_changeset accepts encrypted public_key payloads and normalizes transports" do
    binding = template_binding()
    rendered = EEx.eval_file(@template_path, binding)
    define_support_modules(binding)
    [{mod, _} | _] = Code.compile_string(rendered)

    fixture = PasskeyFixtures.passkey_fixture(Ecto.UUID.generate())

    attrs =
      fixture
      |> Credential.to_params()
      |> Map.update!(:public_key, fn value ->
        value
        |> CoseKey.deserialize()
        |> CoseKey.serialize()
      end)
      |> Map.put(:transports, ["internal", "hybrid", "internal"])

    changeset = mod.create_changeset(struct(mod), attrs)
    assert changeset.valid?

    applied = Ecto.Changeset.apply_changes(changeset)
    assert applied.public_key == attrs.public_key
    assert applied.aaguid == fixture.aaguid
    assert applied.transports == ["internal", "hybrid"]
  end

  defp template_binding do
    suffix = System.unique_integer([:positive, :monotonic])
    app_module = "TemplateApp#{suffix}"

    [
      app_module: app_module,
      context_module: "#{app_module}.Accounts",
      schema_alias: "User",
      binary_id: true
    ]
  end

  defp define_support_modules(binding) do
    Code.ensure_compiled!(Ecto.Schema)

    context_module = binding[:context_module]

    Code.compile_string("""
    defmodule #{context_module}.User do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: true}
      schema "users" do
      end
    end

    defmodule #{context_module}.Encrypted.Binary do
      use Ecto.Type

      def type, do: :binary
      def cast(value) when is_binary(value), do: {:ok, value}
      def cast(nil), do: {:ok, nil}
      def cast(_), do: :error
      def dump(value) when is_binary(value), do: {:ok, value}
      def dump(nil), do: {:ok, nil}
      def dump(_), do: :error
      def load(value) when is_binary(value), do: {:ok, value}
      def load(nil), do: {:ok, nil}
      def load(_), do: :error
    end
    """)
  end
end
