defmodule Sigra.Passkeys.MigrationTemplateTest do
  use ExUnit.Case, async: true

  @template_path Path.join([
                   File.cwd!(),
                   "priv",
                   "templates",
                   "sigra.install",
                   "passkeys",
                   "create_user_passkeys.exs"
                 ])

  test "postgres migration uses uuid aaguid and unique credential_id index" do
    content = render_template(adapter: :postgres, binary_id: true)

    assert content =~ "create table(:user_passkeys, primary_key: false)"
    assert content =~ "add :aaguid, :uuid"
    assert content =~ "add :public_key, :binary, null: false"
    assert content =~ "create index(:user_passkeys, [:user_id])"
    assert content =~ "create unique_index(:user_passkeys, [:credential_id])"
  end

  test "mysql and sqlite migrations fall back to fixed-width binary aaguid" do
    for adapter <- [:mysql, :sqlite] do
      content = render_template(adapter: adapter, binary_id: false)

      assert content =~ "add :aaguid, :binary, size: 16"
      assert content =~ "create unique_index(:user_passkeys, [:credential_id])"
    end
  end

  defp render_template(opts) do
    binding = [
      repo_module: "TemplateApp.Repo",
      table_name: "users",
      binary_id: Keyword.fetch!(opts, :binary_id),
      adapter: Keyword.fetch!(opts, :adapter)
    ]

    EEx.eval_file(@template_path, binding)
  end
end
