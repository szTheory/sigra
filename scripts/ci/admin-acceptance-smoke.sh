#!/usr/bin/env bash
# scripts/ci/admin-acceptance-smoke.sh
#
# Scaffolds a fresh Phoenix app, installs Sigra, patches in a deterministic
# admin policy + seed data, boots the generated host, and runs the focused
# Phase 27 Playwright acceptance smoke against the generated admin routes.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test chrome
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test errors
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test audit-export
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/admin-acceptance-smoke.sh --test impersonation-controller
#
# Every --test target (including slices above) runs the bash HTTP parity probes
# first, then the filtered or full Playwright suite — probes are never skipped.

set -euo pipefail

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
PLAYWRIGHT_DIR="${SIGRA_REPO}/test/example/priv/playwright"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/sigra_admin_smoke}"
APP_NAME="sigra_admin_smoke"
APP_MODULE="SigraAdminSmoke"
WEB_MODULE="SigraAdminSmokeWeb"
CONTEXT_MODULE="SigraAdminSmoke.Accounts"
PORT="${PORT:-4017}"
TEST_TARGET="all"
SERVER_LOG="${TMP_APP_DIR}/server.log"
PLAYWRIGHT_SPEC="tests/admin-generated.spec.ts"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export MIX_ENV="${MIX_ENV:-dev}"
export APP_MODULE
# test-only: deterministic Cloak key for the ephemeral smoke DB; NEVER
# reuse in any non-test environment. The default value only takes effect
# when CLOAK_KEY is unset, so CI / local runs can override.
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

export SIGRA_PLATFORM_ADMIN_EMAIL="${SIGRA_PLATFORM_ADMIN_EMAIL:-platform-admin@example.test}"
export SIGRA_ORG_ADMIN_EMAIL="${SIGRA_ORG_ADMIN_EMAIL:-org-admin@example.test}"
# test-only: deterministic smoke admin password; NEVER reuse in any
# non-test environment. Matches the shared Playwright TEST_PASSWORD
# fixture so the scaffolded admin user can log in from the spec side.
export SIGRA_ADMIN_PASSWORD="${SIGRA_ADMIN_PASSWORD:-CorrectHorseBatteryStaple123!}"
export SIGRA_ALLOWED_ORG_SLUG="${SIGRA_ALLOWED_ORG_SLUG:-allowed-org}"
export SIGRA_ALLOWED_ORG_NAME="${SIGRA_ALLOWED_ORG_NAME:-Allowed Org}"
export SIGRA_OTHER_ORG_SLUG="${SIGRA_OTHER_ORG_SLUG:-other-scope}"
export SIGRA_IMPERSONATION_TARGET_EMAIL="${SIGRA_IMPERSONATION_TARGET_EMAIL:-impersonation-target@example.test}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      TEST_TARGET="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,48p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

patch_generated_sigra_runtime_config() {
  local config_file="config/config.exs"
  local patch_script

  if grep -q "webhook_subscription_schema: ${APP_MODULE}.Accounts.WebhookSubscription" "${config_file}" &&
    grep -q "webhook_event_schema: ${APP_MODULE}.Accounts.WebhookEvent" "${config_file}" &&
    grep -q "webhook_delivery_schema: ${APP_MODULE}.Accounts.WebhookDelivery" "${config_file}" &&
    grep -q "webhook_delivery_attempt_schema: ${APP_MODULE}.Accounts.WebhookDeliveryAttempt" "${config_file}" &&
    grep -q "endpoint_policy: &${APP_MODULE}.Accounts.webhook_endpoint_policy/1" "${config_file}"; then
    echo "==> admin-acceptance: generated host sigra_config.webhooks already present"
    return 0
  fi

  patch_script="$(mktemp)"
  cat > "${patch_script}" <<EOF
path = hd(System.argv())
content = File.read!(path)
module_header = "config :${APP_NAME}, :sigra_config,"

webhooks_block = """
  webhooks: [
    enabled: true,
    webhook_subscription_schema: ${APP_MODULE}.Accounts.WebhookSubscription,
    webhook_event_schema: ${APP_MODULE}.Accounts.WebhookEvent,
    webhook_delivery_schema: ${APP_MODULE}.Accounts.WebhookDelivery,
    webhook_delivery_attempt_schema: ${APP_MODULE}.Accounts.WebhookDeliveryAttempt,
    endpoint_policy: &${APP_MODULE}.Accounts.webhook_endpoint_policy/1,
    oban_queue: "sigra_webhooks",
    oban_concurrency: 10,
    signature_tolerance: 300
  ]
"""


required_keys = [
  "webhook_subscription_schema: ${APP_MODULE}.Accounts.WebhookSubscription",
  "webhook_event_schema: ${APP_MODULE}.Accounts.WebhookEvent",
  "webhook_delivery_schema: ${APP_MODULE}.Accounts.WebhookDelivery",
  "webhook_delivery_attempt_schema: ${APP_MODULE}.Accounts.WebhookDeliveryAttempt",
  "endpoint_policy: &${APP_MODULE}.Accounts.webhook_endpoint_policy/1"
]

webhooks_present? = Enum.all?(required_keys, &String.contains?(content, &1))

new_content =
  if webhooks_present? do
    IO.puts("==> admin-acceptance: generated host sigra_config.webhooks already included")
    content
  else
    lines = String.split(content, "\n", trim: false)

    state =
      Enum.reduce(lines, %{lines: [], inserted?: false, inside?: false, audit_open?: false}, fn line,
                                                                                             state ->
        cond do
          line == module_header ->
            %{state | lines: state.lines ++ [line], inside?: true, audit_open?: false}

          state.inside? and String.starts_with?(line, "config :") ->
            %{state | lines: state.lines ++ [line], inside?: false, audit_open?: false}

          state.inside? and line == "  audit: [" ->
            %{state | lines: state.lines ++ [line], audit_open?: true}

          state.inside? and state.audit_open? and String.trim_trailing(line) in ["  ]", "  ],"] ->
            audit_close =
              if String.contains?(line, "],") do
                line
              else
                String.trim_trailing(line) <> ","
              end

            %{
              state
              | lines: state.lines ++ [audit_close, webhooks_block],
                inserted?: true,
                audit_open?: false
            }

          true ->
            %{state | lines: state.lines ++ [line]}
        end
      end)

    unless state.inserted? do
      IO.puts(:stderr, "FAIL: unable to locate generated sigra_config audit block for webhooks insertion")
      System.halt(1)
    end

    Enum.join(state.lines, "\n")
  end

missing_keys = Enum.reject(required_keys, &String.contains?(new_content, &1))

if missing_keys != [] do
  IO.puts(:stderr, "FAIL: generated host sigra_config.webhooks is missing keys: #{Enum.join(missing_keys, ", ")}")
  System.halt(1)
end

File.write!(path, new_content)

if webhooks_present? do
  IO.puts("==> admin-acceptance: generated host sigra_config.webhooks already included")
else
  IO.puts("==> admin-acceptance: patched generated host sigra_config.webhooks")
end
EOF

  elixir "${patch_script}" "${config_file}"
  rm -f "${patch_script}"
}

echo "==> admin-acceptance: using Sigra repo at ${SIGRA_REPO}"
echo "==> admin-acceptance: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

mix phx.new "${APP_NAME}" \
  --no-install \
  --no-dashboard \
  --database postgres

cd "${TMP_APP_DIR}"

echo "==> admin-acceptance: patching mix.exs with local Sigra path dep"
export SIGRA_REPO
elixir -e '
  path = "mix.exs"
  content = File.read!(path)
  sigra_dep = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n      {:oban, \"~> 2.17\"},\n      {:phoenix,"
  new_content = String.replace(content, "      {:phoenix,", sigra_dep, global: false)
  if new_content == content do
    IO.puts(:stderr, "FAIL: anchor '"'"'      {:phoenix,'"'"' not found in mix.exs; mix phx.new output shape changed")
    System.halt(1)
  end
  File.write!(path, new_content)
'

echo "==> admin-acceptance: fetching deps"
mix deps.get

echo "==> admin-acceptance: running mix sigra.install --yes Accounts User users --no-passkeys"
mix sigra.install --yes Accounts User users --no-passkeys

echo "==> admin-acceptance: patching config/config.exs with Oban"
elixir -e '
  path = "config/config.exs"
  content = File.read!(path)
  oban_config = """
  config :sigra_admin_smoke, Oban,
    repo: SigraAdminSmoke.Repo,
    plugins: [Oban.Plugins.Pruner],
    queues: [default: 10, sigra_webhooks: 10]
  """
  new_content = content <> "\n" <> oban_config
  File.write!(path, new_content)
'

echo "==> admin-acceptance: patching lib/${APP_NAME}/application.ex to start Oban"
elixir -e '
  path = "lib/sigra_admin_smoke/application.ex"
  content = File.read!(path)
  new_content = String.replace(content, "SigraAdminSmoke.Repo,", "SigraAdminSmoke.Repo,\n      {Oban, Application.fetch_env!(:sigra_admin_smoke, Oban)},")
  File.write!(path, new_content)
'

echo "==> admin-acceptance: installing Oban migrations"
cat > "priv/repo/migrations/$(date +%Y%m%d%H%M%S)_add_oban.exs" <<'EOF'
defmodule SigraAdminSmoke.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
EOF

echo "==> admin-acceptance: installing webhook_receipts migration"
# Sleep 1 second to ensure the timestamp for the second migration is greater than the Oban migration
sleep 1
cat > "priv/repo/migrations/$(date +%Y%m%d%H%M%S)_create_webhook_receipts.exs" <<'EOF'
defmodule SigraAdminSmoke.Repo.Migrations.CreateWebhookReceipts do
  use Ecto.Migration

  def change do
    create table(:webhook_receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :delivery_id, :string, null: false
      add :event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :raw_body_sha256, :string, null: false
      add :signature_timestamp, :integer, null: false
      add :verified_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:webhook_receipts, [:delivery_id])
  end
end
EOF

echo "==> admin-acceptance: patching generated admin policy"
cat > "lib/${APP_NAME}/sigra_admin_policy.ex" <<'EOF'
defmodule SigraAdminSmoke.SigraAdminPolicy do
  @moduledoc """
  Deterministic admin policy used by the generated-host acceptance smoke.
  """

  @behaviour Sigra.Admin.Policy

  import Ecto.Query, only: [from: 2]

  alias SigraAdminSmoke.Accounts.OrganizationMembership
  alias SigraAdminSmoke.Repo

  @platform_admin_prefix "platform-admin+"
  @org_admin_prefix "org-admin+"

  @impl true
  def platform_admin?(%{user: %{email: email}}) when is_binary(email) do
    String.starts_with?(email, @platform_admin_prefix)
  end
  def platform_admin?(_scope), do: false

  @impl true
  def admin_org_ids(%{user: %{id: user_id, email: email}})
      when is_binary(user_id) and is_binary(email) do
    if String.starts_with?(email, @org_admin_prefix) do
      from(membership in OrganizationMembership,
        where: membership.user_id == ^user_id,
        select: %{organization_id: membership.organization_id, role: membership.role}
      )
      |> Repo.all()
      |> Sigra.Admin.Policy.admin_org_ids_from_memberships(roles: [:owner, :admin])
    else
      []
    end
  end

  def admin_org_ids(_scope), do: []
end
EOF

echo "==> admin-acceptance: patching generated webhook test harness"
cat > "lib/${APP_NAME}/accounts/webhook_receipt.ex" <<'EOF'
defmodule SigraAdminSmoke.Accounts.WebhookReceipt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_receipts" do
    field :delivery_id, :string
    field :event_id, :string
    field :event_type, :string
    field :payload, :map, default: %{}
    field :raw_body_sha256, :string
    field :signature_timestamp, :integer
    field :verified_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(receipt, attrs) do
    receipt
    |> cast(attrs, [
      :delivery_id,
      :event_id,
      :event_type,
      :payload,
      :raw_body_sha256,
      :signature_timestamp,
      :verified_at
    ])
    |> validate_required([
      :delivery_id,
      :event_id,
      :event_type,
      :payload,
      :raw_body_sha256,
      :signature_timestamp,
      :verified_at
    ])
    |> unique_constraint(:delivery_id)
  end
end
EOF

cat > "lib/${APP_NAME}_web/webhook_body_reader.ex" <<'EOF'
defmodule SigraAdminSmokeWeb.WebhookBodyReader do
  import Plug.Conn

  def read_body(conn, opts), do: read_body(conn, opts, [])

  defp read_body(conn, opts, acc) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        raw_body = IO.iodata_to_binary(Enum.reverse([body | acc]))
        {:ok, raw_body, assign(conn, :raw_body, raw_body)}

      {:more, body, conn} ->
        read_body(conn, opts, [body | acc])
    end
  end
end
EOF

cat > "lib/${APP_NAME}_web/controllers/sigra_webhook_controller.ex" <<EOF
defmodule ${WEB_MODULE}.SigraWebhookController do
  use ${WEB_MODULE}, :controller

  alias Sigra.Webhooks.Signature
  alias SigraAdminSmoke.Accounts.WebhookReceipt
  alias SigraAdminSmoke.Repo

  def create(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    with {:ok, secrets} <- receiver_secrets(),
         {:ok, %{delivery_id: delivery_id, timestamp: timestamp}} <-
           Signature.verify(conn.req_headers, raw_body, secrets, tolerance: signature_tolerance()),
         {:ok, _receipt, _state} <- record_webhook_receipt(delivery_id, raw_body, timestamp) do
      if receiver_fail_after_verify?() do
        send_resp(conn, 503, "receiver downstream unavailable")
      else
        send_resp(conn, 202, "")
      end
    else
      {:error, :missing_id} -> send_resp(conn, 400, "missing webhook id")
      {:error, :missing_timestamp} -> send_resp(conn, 400, "missing webhook timestamp")
      {:error, :missing_signature} -> send_resp(conn, 400, "missing webhook signature")
      {:error, :invalid_timestamp} -> send_resp(conn, 400, "invalid webhook timestamp")
      {:error, :stale_timestamp} -> send_resp(conn, 400, "stale webhook timestamp")
      {:error, :malformed_signature} -> send_resp(conn, 400, "malformed webhook signature")
      {:error, :invalid_signature} -> send_resp(conn, 401, "invalid webhook signature")
      {:error, :missing_secret_configuration} ->
        send_resp(conn, 500, "missing webhook secret configuration")

      {:error, _changeset} -> send_resp(conn, 422, "unable to persist webhook receipt")
    end
  end

  defp receiver_secrets do
    case Application.get_env(:sigra_admin_smoke, :webhook_receiver_secrets, []) do
      [] -> {:error, :missing_secret_configuration}
      secrets -> {:ok, secrets}
    end
  end

  defp receiver_fail_after_verify? do
    Application.get_env(:sigra_admin_smoke, :webhook_receiver_mode, :healthy) == :fail_after_verify
  end

  defp signature_tolerance do
    Application.get_env(:sigra_admin_smoke, :sigra_config, [])
    |> Keyword.get(:webhooks, [])
    |> Keyword.get(:signature_tolerance, 300)
  end

  defp record_webhook_receipt(delivery_id, raw_body, timestamp)
       when is_binary(delivery_id) and is_binary(raw_body) do
    payload = Jason.decode!(raw_body)

    attrs = %{
      delivery_id: delivery_id,
      event_id: payload["id"],
      event_type: payload["type"],
      payload: payload,
      raw_body_sha256: :crypto.hash(:sha256, raw_body) |> Base.encode16(case: :lower),
      signature_timestamp: timestamp,
      verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %WebhookReceipt{}
    |> WebhookReceipt.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, receipt} -> {:ok, receipt, :created}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
EOF

cat > "lib/${APP_NAME}_web/controllers/test_db_probe_controller.ex" <<EOF
defmodule ${WEB_MODULE}.TestDbProbeController do
  use ${WEB_MODULE}, :controller
  import Ecto.Query
  alias SigraAdminSmoke.Accounts.{WebhookDelivery, WebhookEvent, WebhookReceipt, WebhookSubscription}
  alias SigraAdminSmoke.Repo

  def show(conn, %{"table" => "webhook_subscription_secrets", "subscription_id" => subscription_id}) do
    case Repo.get(WebhookSubscription, subscription_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "subscription not found"})

      subscription ->
        json(conn, %{
          subscription_id: subscription.id,
          current_secret: subscription.signing_secret,
          next_secret: Map.get(subscription, :next_signing_secret),
          rotation_state: Map.get(subscription, :rotation_state) || :stable
        })
    end
  end

  def show(conn, %{"table" => "webhook_proof", "delivery_id" => delivery_id}) do
    case get_webhook_proof_bundle(delivery_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "delivery not found"})
      bundle -> json(conn, bundle)
    end
  end

  def show(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "unsupported probe"})
  end

  def create(conn, %{"table" => "webhook_receiver_config"} = params) do
    Application.put_env(
      :sigra_admin_smoke,
      :webhook_receiver_secrets,
      [
        blank_to_nil(Map.get(params, "current_secret")),
        blank_to_nil(Map.get(params, "previous_secret"))
      ]
      |> Enum.filter(&(&1 not in [nil, ""]))
    )

    Application.put_env(
      :sigra_admin_smoke,
      :webhook_receiver_mode,
      normalize_mode(Map.get(params, "mode"))
    )

    json(conn, %{
      ok: true,
      current_secret: blank_to_nil(Map.get(params, "current_secret")),
      previous_secret: blank_to_nil(Map.get(params, "previous_secret")),
      mode: Application.get_env(:sigra_admin_smoke, :webhook_receiver_mode, :healthy)
    })
  end

  if Code.ensure_loaded?(Oban) do
    def create(conn, %{"table" => "webhook_drain"} = _params) do
      result = Oban.drain_queue(queue: :sigra_webhooks, with_recursion: true, with_scheduled: true, with_safety: false)
      json(conn, %{ok: true, result: result})
    end
  else
    def create(conn, %{"table" => "webhook_drain"} = _params) do
      json(conn, %{ok: false, result: "oban_unavailable"})
    end
  end

  def create(conn, %{"table" => "webhook_endpoint_policy"} = params) do
    Application.put_env(:sigra_admin_smoke, :webhook_endpoint_policy, %{
      mode: normalize_mode(Map.get(params, "mode")),
      endpoint_url: blank_to_nil(Map.get(params, "endpoint_url")),
      detail: blank_to_nil(Map.get(params, "detail")) || "blocked by deployment callback"
    })

    json(conn, %{ok: true, config: webhook_endpoint_policy_config()})
  end

  def create(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "unsupported probe"})
  end

  defp webhook_endpoint_policy_config do
    Application.get_env(:sigra_admin_smoke, :webhook_endpoint_policy,
      %{mode: :healthy, endpoint_url: nil, detail: "blocked by deployment callback"}
    )
  end

  defp get_webhook_proof_bundle(delivery_id) when is_binary(delivery_id) do
    case Repo.get_by(WebhookDelivery, delivery_id: delivery_id) do
      nil ->
        nil

      delivery ->
        event = Repo.get(WebhookEvent, delivery.webhook_event_id)
        subscription = Repo.get(WebhookSubscription, delivery.webhook_subscription_id)
        receipt = Repo.get_by(WebhookReceipt, delivery_id: delivery_id)
        replay_parent = if delivery.replayed_from_webhook_delivery_id, do: Repo.get(WebhookDelivery, delivery.replayed_from_webhook_delivery_id)
        replay_root = if delivery.replay_root_webhook_delivery_id || delivery.id, do: Repo.get(WebhookDelivery, delivery.replay_root_webhook_delivery_id || delivery.id)
        source_delivery = replay_parent || delivery
        replay_child =
          from(d in WebhookDelivery,
            where: d.replayed_from_webhook_delivery_id == ^source_delivery.id,
            order_by: [asc: d.inserted_at, asc: d.id],
            limit: 1
          )
          |> Repo.one()

        source_receipt = Repo.get_by(WebhookReceipt, delivery_id: source_delivery.delivery_id)
        replay_receipt = if replay_child, do: Repo.get_by(WebhookReceipt, delivery_id: replay_child.delivery_id)

        %{
          delivery_id: delivery.delivery_id,
          delivery_status: delivery.status,
          endpoint_url: delivery.endpoint_url,
          event_id: event && event.event_id,
          event_type: event && event.type,
          subscription_id: subscription && subscription.id,
          subscription_description: subscription && subscription.description,
          lineage: %{
            source_delivery_id: source_delivery.delivery_id,
            replay_delivery_id: replay_child && replay_child.delivery_id,
            root_delivery_id: (replay_root || source_delivery).delivery_id,
            replay_parent_delivery_id: replay_parent && replay_parent.delivery_id
          },
          receiver_verification: %{
            current_delivery: build_receipt_proof(receipt),
            source_delivery: build_receipt_proof(source_receipt),
            replay_delivery: build_receipt_proof(replay_receipt)
          },
          receipt: build_receipt_proof(receipt)
        }
    end
  end

  defp build_receipt_proof(nil), do: nil
  defp build_receipt_proof(receipt) do
    %{verified_at: receipt.verified_at, raw_body_sha256: receipt.raw_body_sha256, signature_timestamp: receipt.signature_timestamp}
  end

  defp normalize_mode(mode) when mode in [nil, ""], do: :healthy
  defp normalize_mode(:healthy), do: :healthy
  defp normalize_mode(:fail_after_verify), do: :fail_after_verify
  defp normalize_mode(:deny_exact_endpoint), do: :deny_exact_endpoint
  defp normalize_mode("healthy"), do: :healthy
  defp normalize_mode("fail_after_verify"), do: :fail_after_verify
  defp normalize_mode("deny_exact_endpoint"), do: :deny_exact_endpoint
  defp normalize_mode(_), do: :healthy

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value
end
EOF

echo "==> admin-acceptance: patching generated sigra_config webhooks runtime block"
patch_generated_sigra_runtime_config

echo "==> admin-acceptance: patching generated webhook routes and receiver body reader"
elixir -e '
  router_path = "lib/'"${APP_NAME}"'_web/router.ex"
  endpoint_path = "lib/'"${APP_NAME}"'_web/endpoint.ex"
  accounts_path = "lib/'"${APP_NAME}"'/accounts.ex"

  router_content = File.read!(router_path)

  router_injection = """

  scope "/test", SigraAdminSmokeWeb do
    pipe_through :api

    get "/db_probe", TestDbProbeController, :show
    post "/db_probe", TestDbProbeController, :create
  end

  scope "/", SigraAdminSmokeWeb do
    pipe_through :api

    post "/webhooks/sigra", SigraWebhookController, :create
  end
"""

  new_router_content =
    String.replace(
      router_content,
      """
  # Other scopes may use custom stacks.
  # scope "/api", SigraAdminSmokeWeb do
  #   pipe_through :api
  # end
""",
      """
  # Other scopes may use custom stacks.
  # scope "/api", SigraAdminSmokeWeb do
  #   pipe_through :api
  # end
#{router_injection}
""",
      global: false
    )

  if new_router_content == router_content do
    IO.puts(:stderr, "FAIL: failed to inject generated test/db_probe and webhooks routes")
    System.halt(1)
  end

  File.write!(router_path, new_router_content)

  endpoint_content = File.read!(endpoint_path)
  endpoint_anchor = """
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
"""

  endpoint_replacement = """
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    body_reader: {SigraAdminSmokeWeb.WebhookBodyReader, :read_body, []}
"""

  new_endpoint_content = String.replace(endpoint_content, endpoint_anchor, endpoint_replacement, global: false)

  if new_endpoint_content == endpoint_content do
    IO.puts(:stderr, "FAIL: failed to inject webhook body_reader into endpoint.ex")
    System.halt(1)
  end

  File.write!(endpoint_path, new_endpoint_content)

  accounts_content = File.read!(accounts_path)
  old_policy = "  def webhook_endpoint_policy(_context), do: :ok"
  new_policy = """
  def webhook_endpoint_policy(%{uri: %URI{} = uri}) do
    case webhook_endpoint_policy_config() do
      %{mode: :deny_exact_endpoint, endpoint_url: endpoint_url, detail: detail} ->
        if deny_endpoint?(uri, endpoint_url) do
          {:error, :policy_denied, detail}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  def webhook_endpoint_policy(_context), do: :ok

  defp webhook_endpoint_policy_config do
    Application.get_env(:sigra_admin_smoke, :webhook_endpoint_policy,
      %{mode: :healthy, endpoint_url: nil, detail: "blocked by deployment callback"}
    )
  end

  defp deny_endpoint?(%URI{}, expected_endpoint_url) when expected_endpoint_url in [nil, ""], do: true
  defp deny_endpoint?(%URI{} = actual_uri, expected_endpoint_url) when is_binary(expected_endpoint_url) do
    case URI.new(expected_endpoint_url) do
      {:ok, %URI{} = expected_uri} ->
        actual_uri.scheme == expected_uri.scheme and
          actual_uri.host == expected_uri.host and
          effective_port(actual_uri) == effective_port(expected_uri) and
          actual_uri.path == expected_uri.path

      _ ->
        true
    end
  end

  defp deny_endpoint?(_, _), do: true

  defp effective_port(%URI{scheme: "https", port: nil}), do: 443
  defp effective_port(%URI{scheme: "http", port: nil}), do: 80
  defp effective_port(%URI{port: port}) when is_integer(port), do: port
  defp effective_port(_), do: nil
"""

  new_accounts_content =
    accounts_content
    |> String.replace(old_policy, new_policy, global: false)
    |> String.replace("enabled: false,", "enabled: true,", global: false)

  if new_accounts_content == accounts_content do
    IO.puts(:stderr, "FAIL: failed to patch generated webhook endpoint policy callback")
    System.halt(1)
  end
  File.write!(accounts_path, new_accounts_content)
'

echo "==> admin-acceptance: compiling generated host"
mix compile --warnings-as-errors

echo "==> admin-acceptance: resetting database"
mix ecto.drop || true
mix ecto.create
mix ecto.migrate

echo "==> admin-acceptance: seeding deterministic admin fixtures"
SEED_FILE="${TMP_APP_DIR}/sigra_admin_acceptance_seed.exs"
cat > "${SEED_FILE}" <<'EOF'
alias SigraAdminSmoke.Repo
alias SigraAdminSmoke.Accounts
alias SigraAdminSmoke.Accounts.User
alias SigraAdminSmoke.Accounts.Organization
alias SigraAdminSmoke.Accounts.OrganizationMembership

platform_admin_email = System.fetch_env!("SIGRA_PLATFORM_ADMIN_EMAIL")
org_admin_email = System.fetch_env!("SIGRA_ORG_ADMIN_EMAIL")
password = System.fetch_env!("SIGRA_ADMIN_PASSWORD")
allowed_org_slug = System.fetch_env!("SIGRA_ALLOWED_ORG_SLUG")
allowed_org_name = System.fetch_env!("SIGRA_ALLOWED_ORG_NAME")
other_org_slug = System.fetch_env!("SIGRA_OTHER_ORG_SLUG")
impersonation_target_email = System.fetch_env!("SIGRA_IMPERSONATION_TARGET_EMAIL")

confirm! = fn user ->
  user
  |> User.confirm_changeset()
  |> Repo.update!()
end

{:ok, platform_admin} =
  Accounts.register_user(%{"email" => platform_admin_email, "password" => password})

platform_admin = confirm!.(platform_admin)

{:ok, org_admin} =
  Accounts.register_user(%{"email" => org_admin_email, "password" => password})

org_admin = confirm!.(org_admin)

allowed_org =
  %Organization{}
  |> Organization.changeset(%{name: allowed_org_name, slug: allowed_org_slug})
  |> Repo.insert!()

_other_org =
  %Organization{}
  |> Organization.changeset(%{name: "Other Scope", slug: other_org_slug})
  |> Repo.insert!()

%OrganizationMembership{}
|> OrganizationMembership.changeset(%{
  role: :admin,
  user_id: org_admin.id,
  organization_id: allowed_org.id
})
|> Repo.insert!()

{:ok, impersonation_target} =
  Accounts.register_user(%{
    "email" => impersonation_target_email,
    "password" => password
  })

impersonation_target = confirm!.(impersonation_target)

IO.puts(
  "seeded #{platform_admin.email}, #{org_admin.email}, #{impersonation_target.email}, #{allowed_org.slug}, #{other_org_slug}"
)
EOF

mix run "${SEED_FILE}"

if [[ ! -d "${PLAYWRIGHT_DIR}/node_modules" ]]; then
  echo "==> admin-acceptance: installing Playwright npm deps"
  (cd "${PLAYWRIGHT_DIR}" && npm ci)
fi

echo "==> admin-acceptance: booting generated host on port ${PORT}"
PORT="${PORT}" PHX_SERVER=true mix phx.server > "${SERVER_LOG}" 2>&1 &
SERVER_PID=$!

for i in $(seq 1 60); do
  if curl -sf "http://localhost:${PORT}/" > /dev/null; then
    echo "==> admin-acceptance: app responded after ${i}s"
    break
  fi

  if [[ "${i}" -eq 60 ]]; then
    echo "FAIL: generated host did not boot within 60 seconds"
    cat "${SERVER_LOG}"
    exit 1
  fi

  sleep 1
done

for path in /users/log_in /organizations /organizations/new /admin "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}"; do
  curl -s -o /dev/null "http://localhost:${PORT}${path}" || true
done

# --- Phase 31 generated-host runtime parity probes --------------------------
# Phase 30 `30-VERIFICATION.md` flagged an open gap: audit routes and CSV
# export were proven in the example app via ExUnit/LiveViewTest but never
# exercised through a booted generated-host app. Phase 31 D-10/D-11/D-17
# closes that gap here with a narrow set of real-HTTP checks. These stay
# intentionally thin: status-only probes for audit explorer and export
# routes, without duplicating the example app's ExUnit matrix.
echo "==> admin-acceptance: probing generated-host audit runtime parity"
GEN_PARITY_FAIL=0

gen_expect_non_5xx() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5 \
    "http://localhost:${PORT}${path}")
  if [[ "${code}" -ge 500 ]]; then
    echo "FAIL: ${path} returned ${code} on generated host"
    GEN_PARITY_FAIL=1
  else
    echo "OK:   ${path} -> ${code}"
  fi
}

# Admin-critical routes must be mounted and reachable on the generated
# host, matching example-app wiring. The original four entries prove
# Phase 30 audit + export reachability; the two `/users` entries prove
# Phase 32 INT-01 closure (UsersIndexLive in global + organization
# live_session blocks). Authorization policy truth stays in ExUnit;
# these checks only prove route shape + no 5xx.
GENERATED_HOST_AUDIT_ROUTES=(
  "/admin/audit"
  "/admin/audit/export.csv"
  "/admin/users"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/audit/export.csv"
  "/admin/organizations/${SIGRA_ALLOWED_ORG_SLUG}/users"
)

for path in "${GENERATED_HOST_AUDIT_ROUTES[@]}"; do
  gen_expect_non_5xx "${path}"
done

# Phase 32 INT-02 closure: prove the ImpersonationController template is
# emitted by the installer and reachable as a routed controller module in
# the generated host. `mix compile --warnings-as-errors` does NOT catch
# undefined-module route references (Phoenix resolves controllers at
# dispatch time, not compile time) — so a missing template would produce
# a runtime 500 on POST, not a compile error. This unauthenticated probe
# hits the route with a bogus UUID and asserts the response is NOT 5xx;
# any non-5xx status (302 login redirect, 403, 404, 422) proves the
# controller module loaded and authorization ran. Full authenticated
# impersonation flow stays in Phase 34 Playwright.
echo "==> admin-acceptance: probing generated-host impersonation controller emission (INT-02)"
imp_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "http://localhost:${PORT}/admin/users/00000000-0000-0000-0000-000000000000/impersonation")
if [[ "${imp_code}" -ge 500 ]]; then
  echo "FAIL: POST /admin/users/.../impersonation returned ${imp_code} (controller module likely missing — INT-02 regressed)"
  GEN_PARITY_FAIL=1
else
  echo "OK:   POST /admin/users/.../impersonation -> ${imp_code}"
fi

# Per D-12/D-13, also assert one explicit denial-semantic probe: unknown
# organization slug must NOT return a 200 on the generated host, so a
# wiring regression that collapsed unknown-org to global admin would
# fail loudly here rather than silently leak data.
echo "==> admin-acceptance: probing generated-host unknown-org denial semantics"
unknown_org_code=$(curl -s -o /dev/null -w "%{http_code}" \
  "http://localhost:${PORT}/admin/organizations/definitely-not-an-org/audit")
if [[ "${unknown_org_code}" == "200" ]]; then
  echo "FAIL: /admin/organizations/definitely-not-an-org/audit returned 200 on generated host"
  GEN_PARITY_FAIL=1
else
  echo "OK:   /admin/organizations/definitely-not-an-org/audit -> ${unknown_org_code}"
fi

if [[ "${GEN_PARITY_FAIL}" -eq 1 ]]; then
  echo "==> admin-acceptance: generated-host parity probe failed"
  echo "==> admin-acceptance: dumping server log for diagnostics"
  tail -n 200 "${SERVER_LOG}" || true
  exit 1
fi

case "${TEST_TARGET}" in
  all)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}")
    ;;
  chrome)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin shell renders on desktop and mobile")
    ;;
  errors)
    PLAYWRIGHT_ARGS=("${PLAYWRIGHT_SPEC}" "-g" "generated host admin denial responses show explicit copy")
    ;;
  audit-export)
    PLAYWRIGHT_ARGS=(
      "${PLAYWRIGHT_SPEC}"
      "-g"
      "VFY-01 generated host audit CSV export"
    )
    ;;
  impersonation-controller)
    PLAYWRIGHT_ARGS=(
      "${PLAYWRIGHT_SPEC}"
      "-g"
      "VFY-01 generated host impersonation start"
    )
    ;;
  *)
    echo "unknown --test target: ${TEST_TARGET}" >&2
    exit 1
    ;;
esac

echo "==> admin-acceptance: running Playwright target ${TEST_TARGET}"
(
  cd "${PLAYWRIGHT_DIR}"
  CI=true \
  SIGRA_EXAMPLE_URL="http://localhost:${PORT}" \
  npx playwright test "${PLAYWRIGHT_ARGS[@]}"
)

echo "==> admin-acceptance: success"
