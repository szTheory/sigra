defmodule Sigra.WebhooksSignatureTest do
  use ExUnit.Case, async: true

  alias Sigra.Webhooks.Signature

  @delivery_id "del_123"
  @secret "whsec_test_secret"
  @rotated_secret "whsec_rotated_secret"
  @raw_body ~s({"id":"evt_123","type":"user.created"})
  @timestamp 1_778_070_400

  test "builds the exact Phase 97 header contract and canonical string" do
    headers = Signature.headers(@delivery_id, @raw_body, @secret, timestamp: @timestamp)

    assert Signature.header_names() == %{
             id: "Sigra-Webhook-Id",
             timestamp: "Sigra-Webhook-Timestamp",
             signature: "Sigra-Webhook-Signature"
           }

    assert Signature.canonical_string(@delivery_id, @timestamp, @raw_body) ==
             "#{@delivery_id}.#{@timestamp}.#{@raw_body}"

    expected_digest =
      :crypto.mac(:hmac, :sha256, @secret, "#{@delivery_id}.#{@timestamp}.#{@raw_body}")
      |> Base.encode16(case: :lower)

    assert headers == %{
             "Sigra-Webhook-Id" => @delivery_id,
             "Sigra-Webhook-Timestamp" => Integer.to_string(@timestamp),
             "Sigra-Webhook-Signature" => "v1=#{expected_digest}"
           }
  end

  test "verifies signatures case-insensitively on headers and supports multiple v1 values" do
    current = Signature.sign(@delivery_id, @timestamp, @raw_body, @secret)
    rotated = Signature.sign(@delivery_id, @timestamp, @raw_body, @rotated_secret)

    headers = %{
      "sigra-webhook-id" => @delivery_id,
      "sigra-webhook-timestamp" => Integer.to_string(@timestamp),
      "sigra-webhook-signature" => Enum.join([current, rotated], ", ")
    }

    assert {:ok, %{delivery_id: @delivery_id, timestamp: @timestamp}} =
             Signature.verify(headers, @raw_body, [@secret], now: @timestamp, tolerance: 300)

    assert {:ok, %{delivery_id: @delivery_id, timestamp: @timestamp}} =
             Signature.verify(headers, @raw_body, [@rotated_secret],
               now: @timestamp,
               tolerance: 300
             )
  end

  test "emits one timestamp with two v1 signatures during overlap" do
    headers =
      Signature.headers(@delivery_id, @raw_body, [@secret, @rotated_secret], timestamp: @timestamp)

    assert headers["Sigra-Webhook-Timestamp"] == Integer.to_string(@timestamp)

    assert [first, second] =
             headers["Sigra-Webhook-Signature"]
             |> String.split(",")
             |> Enum.map(&String.trim/1)

    assert first == Signature.sign(@delivery_id, @timestamp, @raw_body, @secret)
    assert second == Signature.sign(@delivery_id, @timestamp, @raw_body, @rotated_secret)
    refute headers["Sigra-Webhook-Signature"] =~ "kid="
  end

  test "rejects stale timestamps and malformed timestamps explicitly" do
    headers = Signature.headers(@delivery_id, @raw_body, @secret, timestamp: @timestamp)

    assert {:error, :stale_timestamp} =
             Signature.verify(headers, @raw_body, @secret, now: @timestamp + 301, tolerance: 300)

    malformed =
      Map.put(headers, "Sigra-Webhook-Timestamp", "not-a-timestamp")

    assert {:error, :invalid_timestamp} =
             Signature.verify(malformed, @raw_body, @secret, now: @timestamp, tolerance: 300)
  end

  test "rejects missing and malformed signature headers without leaking payload details" do
    headers = Signature.headers(@delivery_id, @raw_body, @secret, timestamp: @timestamp)

    assert {:error, :missing_signature} =
             headers
             |> Map.delete("Sigra-Webhook-Signature")
             |> then(&Signature.verify(&1, @raw_body, @secret, now: @timestamp))

    malformed =
      Map.put(headers, "Sigra-Webhook-Signature", "v1=short")

    assert {:error, :malformed_signature} =
             Signature.verify(malformed, @raw_body, @secret, now: @timestamp)
  end

  test "rejects digest mismatches after constant-time comparison path" do
    headers = Signature.headers(@delivery_id, @raw_body, @secret, timestamp: @timestamp)

    assert {:error, :invalid_signature} =
             Signature.verify(headers, @raw_body <> " ", @secret, now: @timestamp)
  end
end
