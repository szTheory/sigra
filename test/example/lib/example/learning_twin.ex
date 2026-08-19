defmodule Example.LearningTwin.Lease do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "learning_twin_leases" do
    field :account_partition, :string
    field :issued_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    belongs_to :user, Example.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(lease, attrs),
    do:
      cast(lease, attrs, [:user_id, :account_partition, :issued_at, :expires_at])
      |> validate_required([:user_id, :account_partition, :issued_at, :expires_at])
end

defmodule Example.LearningTwin.ReplayReceipt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @schema_prefix "auth"

  schema "learning_twin_replay_receipts" do
    field :account_partition, :string
    field :client_mutation_id, :string
    field :idempotency_key, :string
    field :base_checkpoint, :string
    field :outcome, :string
    field :terminal_at, :utc_datetime_usec
    belongs_to :user, Example.Accounts.User
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(receipt, attrs),
    do:
      cast(receipt, attrs, [
        :user_id,
        :account_partition,
        :client_mutation_id,
        :idempotency_key,
        :base_checkpoint,
        :outcome,
        :terminal_at
      ])
      |> validate_required([
        :user_id,
        :account_partition,
        :client_mutation_id,
        :idempotency_key,
        :base_checkpoint,
        :outcome,
        :terminal_at
      ])
      |> unique_constraint([:account_partition, :idempotency_key])
end

defmodule Example.LearningTwin do
  import Ecto.Query
  alias Example.LearningTwin.{Lease, ReplayReceipt}
  alias Example.Repo

  @default_lease_ttl_seconds 604_800
  @max_lease_ttl_seconds 604_800
  @replay_checkpoint "market-morning-v1"
  @max_replay_identifier_bytes 128
  @max_replay_answer_bytes 120

  @image "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 320 180\" role=\"img\" aria-label=\"Market morning fruit stall\"><rect width=\"320\" height=\"180\" fill=\"#f6dfae\"/><circle cx=\"104\" cy=\"96\" r=\"36\" fill=\"#d96b3b\"/><circle cx=\"186\" cy=\"92\" r=\"36\" fill=\"#e7b543\"/><path d=\"M104 60v-18m82 14V38\" stroke=\"#3c7537\" stroke-width=\"8\"/></svg>"
  @audio "market-morning-audio-v1"

  def bootstrap(%{user: %{id: user_id}}, _opts) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    lease = active_or_new_lease(user_id, now)

    bootstrap_payload(lease)
  end

  def bootstrap_for_current_scope(%{user: %{id: user_id}} = scope, requested_partition) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    case active_lease(scope, as_of: now) do
      {:ok, lease} ->
        case authorize_requested_partition(scope, requested_partition, now) do
          {:ok, _lease} -> {:ok, bootstrap_payload(lease)}
          {:error, reason} -> {:error, reason}
        end

      {:error, :unavailable} when is_nil(requested_partition) ->
        {:ok, bootstrap_payload(active_or_new_lease(user_id, now))}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def bootstrap_for_current_scope(_, _), do: {:error, :unavailable}

  defp bootstrap_payload(lease) do
    %{
      partition: lease.account_partition,
      expires_at: DateTime.to_iso8601(lease.expires_at),
      lesson: lesson(),
      media: Enum.map([:image, :audio], &media/1)
    }
  end

  def lease_ttl_seconds do
    case Application.get_env(:example, __MODULE__, [])
         |> Keyword.get(:offline_lease_ttl_seconds, @default_lease_ttl_seconds) do
      ttl when is_integer(ttl) and ttl > 0 and ttl <= @max_lease_ttl_seconds -> {:ok, ttl}
      _ -> {:error, :invalid_lease_ttl}
    end
  end

  def lease_valid?(%Lease{expires_at: %DateTime{} = expires_at}, %DateTime{} = as_of),
    do: DateTime.compare(as_of, expires_at) == :lt

  def lease_valid?(_, _), do: false

  def active_lease(scope, opts \\ [])

  def active_lease(%{user: %{id: user_id}}, opts) when is_list(opts) do
    as_of = Keyword.get(opts, :as_of, DateTime.utc_now() |> DateTime.truncate(:microsecond))

    case Repo.one(
           from l in Lease, where: l.user_id == ^user_id, order_by: [desc: l.expires_at], limit: 1
         ) do
      nil -> {:error, :unavailable}
      lease -> if(lease_valid?(lease, as_of), do: {:ok, lease}, else: {:error, :expired})
    end
  end

  def active_lease(_, _), do: {:error, :unavailable}

  def authorize_partition(scope, partition, opts \\ []) when is_list(opts) do
    with {:ok, lease} <- active_lease(scope, opts),
         true <- is_binary(partition) and partition == lease.account_partition do
      {:ok, lease}
    else
      false -> {:error, :partition_mismatch}
      {:error, _reason} = error -> error
    end
  end

  defp authorize_requested_partition(_scope, nil, _as_of), do: {:ok, nil}

  defp authorize_requested_partition(scope, partition, as_of),
    do: authorize_partition(scope, partition, as_of: as_of)

  def media(:image), do: manifest(:image, @image, "image/svg+xml", "/app/lesson/media/image/v1")
  def media(:audio), do: manifest(:audio, @audio, "audio/mpeg", "/app/lesson/media/audio/v1")
  def media("image"), do: media(:image)
  def media("audio"), do: media(:audio)
  def media(_), do: nil

  def media_body(:image), do: @image
  def media_body(:audio), do: @audio

  def replay(%{user: %{id: user_id}} = scope, params, _opts) when is_map(params) do
    with {:ok, normalized} <- normalize_replay(params),
         {:ok, lease} <- active_lease(scope),
         {:ok, receipt} <- persist_terminal_receipt(user_id, lease.account_partition, normalized) do
      {:ok, receipt}
    else
      {:error, :invalid_replay} = error -> error
      {:error, _reason} -> {:error, :unauthorized_partition}
    end
  end

  def replay(_, _, _), do: {:error, :unauthorized_partition}

  defp normalize_replay(params) do
    required = ["client_mutation_id", "idempotency_key", "base_checkpoint", "action", "answer"]

    identifiers = required -- ["answer"]

    if Map.keys(params) |> Enum.sort() == Enum.sort(required) and
         Enum.all?(identifiers, &bounded_scalar?(Map.get(params, &1), @max_replay_identifier_bytes)) and
         bounded_answer?(params["answer"]) do
      {:ok, Map.take(params, required)}
    else
      {:error, :invalid_replay}
    end
  end

  defp persist_terminal_receipt(user_id, partition, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.transaction(fn ->
      attrs = %{
        user_id: user_id,
        account_partition: partition,
        idempotency_key: params["idempotency_key"],
        client_mutation_id: params["client_mutation_id"],
        base_checkpoint: params["base_checkpoint"],
        outcome: terminal_outcome(params),
        terminal_at: now
      }

      case Repo.insert(ReplayReceipt.changeset(%ReplayReceipt{}, attrs),
             on_conflict: :nothing,
             conflict_target: [:account_partition, :idempotency_key]
           ) do
        {:ok, _receipt} -> stored_replay_receipt!(partition, params["idempotency_key"])
      end
    end)
  end

  defp stored_replay_receipt!(partition, idempotency_key) do
    Repo.one!(
      from r in ReplayReceipt,
        where: r.account_partition == ^partition and r.idempotency_key == ^idempotency_key
    )
  end

  defp terminal_outcome(%{"base_checkpoint" => checkpoint}) when checkpoint != @replay_checkpoint,
    do: "conflict"

  defp terminal_outcome(%{"action" => "answer", "answer" => answer}) when byte_size(answer) > 0,
    do: "accepted"

  defp terminal_outcome(_), do: "rejected"

  defp bounded_scalar?(value, max_bytes),
    do: is_binary(value) and byte_size(value) > 0 and byte_size(value) <= max_bytes

  defp bounded_answer?(value), do: is_binary(value) and byte_size(value) <= @max_replay_answer_bytes

  defp active_or_new_lease(user_id, now) do
    case Repo.one(
           from l in Lease,
             where: l.user_id == ^user_id and l.expires_at > ^now,
             order_by: [desc: l.expires_at],
             limit: 1
         ) do
      nil ->
        Repo.insert!(
          Lease.changeset(%Lease{}, %{
            user_id: user_id,
            account_partition:
              "lt_" <> Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false),
            issued_at: now,
            expires_at: DateTime.add(now, lease_ttl_seconds!(), :second)
          })
        )

      lease ->
        lease
    end
  end

  defp lesson,
    do: %{
      id: "market-morning-v1",
      title: "Market morning",
      prompt: "Name the fruits you can see before you leave the market.",
      transcript: "Good morning. I would like two apples and one orange, please."
    }

  defp manifest(kind, body, content_type, url),
    do: %{
      kind: Atom.to_string(kind),
      version: "v1",
      url: url,
      byte_size: byte_size(body),
      sha256: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower),
      content_type: content_type
    }

  defp lease_ttl_seconds! do
    case lease_ttl_seconds() do
      {:ok, ttl} ->
        ttl

      {:error, :invalid_lease_ttl} ->
        raise ArgumentError,
              "offline_lease_ttl_seconds must be a positive integer up to #{@max_lease_ttl_seconds}"
    end
  end
end

defmodule ExampleWeb.LearningTwinController do
  use ExampleWeb, :controller
  alias Example.LearningTwin

  def bootstrap(conn, params) do
    case LearningTwin.bootstrap_for_current_scope(
           conn.assigns.current_scope,
           Map.get(params, "account_partition")
         ) do
      {:ok, bootstrap} -> json(conn, bootstrap)
      {:error, _reason} -> conn |> put_status(:forbidden) |> json(%{outcome: "unavailable"})
    end
  end

  def media(conn, %{"kind" => kind, "version" => "v1"}) do
    case LearningTwin.media(kind) do
      nil ->
        send_resp(conn, 404, "not found")

      manifest ->
        conn
        |> put_resp_content_type(manifest.content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_resp(200, LearningTwin.media_body(String.to_existing_atom(kind)))
    end
  end

  def media(conn, _), do: send_resp(conn, 404, "not found")

  def replay(conn, params) do
    case LearningTwin.replay(conn.assigns.current_scope, params, []) do
      {:ok, receipt} ->
        json(conn, %{
          client_mutation_id: receipt.client_mutation_id,
          status: receipt.outcome,
          terminal_at: DateTime.to_iso8601(receipt.terminal_at)
        })

      {:error, :invalid_replay} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid_replay"})

      {:error, :unauthorized_partition} ->
        conn |> put_status(:forbidden) |> json(%{error: "replay_unavailable"})
    end
  end
end

defmodule ExampleWeb.LearningTwinLive do
  use ExampleWeb, :live_view
  alias Example.LearningTwin
  alias ExampleWeb.Layouts
  alias Phoenix.LiveView.JS

  def mount(params, _session, socket) do
    case LearningTwin.bootstrap_for_current_scope(
           socket.assigns.current_scope,
           Map.get(params, "account_partition")
         ) do
      {:ok, twin} -> {:ok, socket |> assign(:twin, twin) |> assign(:twin_state, :lesson)}
      {:error, _reason} -> {:ok, socket |> assign(:twin, nil) |> assign(:twin_state, :expired)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} user_organizations={[]}>
      <%= if @twin_state == :lesson do %>
        <section class="vt-page-intro" data-testid="twin-lesson" data-twin-ready="true">
          <p class="vt-kicker">Language practice</p>
          <h1>{@twin.lesson.title}</h1>
          <p>{@twin.lesson.prompt}</p>
          <img src={Enum.at(@twin.media, 0).url} alt="Market morning fruit stall" />
          <section>
            <h2>Listen</h2>
            <audio controls src={Enum.at(@twin.media, 1).url}></audio>
            <h2>Transcript</h2>
            <p>{@twin.lesson.transcript}</p>
          </section>
          <section data-testid="twin-offline-panel" aria-busy="false" aria-live="polite">
            <p data-testid="twin-offline-status">Not available offline</p>
            <button data-testid="twin-offline-action" type="button">Make available offline</button>
          </section>
          <button data-testid="twin-record-practice" type="button">Record practice</button>
          <p data-testid="twin-replay-receipts"></p>
        </section>
        <script defer src="/assets/js/learning_twin.js">
        </script>
      <% else %>
        <section class="vt-page-intro" data-testid="twin-expired" data-twin-ready="true">
          <p class="vt-kicker">Language practice</p>
          <h1
            id="twin-expired-heading"
            tabindex="-1"
            phx-mounted={JS.focus(to: "#twin-expired-heading")}
          >
            Offline study has expired. Connect and sign in to continue.
          </h1>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
