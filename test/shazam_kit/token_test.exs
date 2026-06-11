defmodule ShazamKit.TokenTest do
  @moduledoc """
  Tests for ShazamKit.Token module.
  """

  use ExUnit.Case, async: true

  alias ShazamKit.Token

  setup do
    private_key = ShazamKit.TestKey.generate_private_key()

    opts = [
      team_id: "TEAMID1234",
      key_id: "KEYID56789",
      private_key: private_key
    ]

    {:ok, %{opts: opts}}
  end

  describe "generate_jwt/1" do
    test "returns a valid JWT token string", %{opts: opts} do
      assert {:ok, token} = Token.generate_jwt(opts)
      assert is_binary(token)
      assert String.split(token, ".") |> length() == 3
    end

    test "JWT contains correct header", %{opts: opts} do
      {:ok, token} = Token.generate_jwt(opts)
      [header_b64 | _] = String.split(token, ".")
      {:ok, header} = Base.url_decode64(header_b64, padding: false)
      header_json = Jason.decode!(header)

      assert header_json["alg"] == "ES256"
      assert header_json["kid"] == "KEYID56789"
      assert header_json["typ"] == "JWT"
    end

    test "JWT contains correct claims", %{opts: opts} do
      {:ok, token} = Token.generate_jwt(opts)
      [_, payload_b64 | _] = String.split(token, ".")
      {:ok, payload} = Base.url_decode64(payload_b64, padding: false)
      claims = Jason.decode!(payload)

      assert claims["iss"] == "TEAMID1234"
      assert is_integer(claims["iat"])
      assert is_integer(claims["exp"])
      assert claims["exp"] > claims["iat"]
      assert claims["exp"] == claims["iat"] + 1200
    end

    test "returns error for missing fields" do
      opts = [
        team_id: nil,
        key_id: nil,
        private_key: nil
      ]

      assert {:error, {:missing_config, _}} = Token.generate_jwt(opts)
    end

    test "returns an error tuple for malformed PEM", %{opts: opts} do
      assert {:error, {:token_generation_failed, message}} =
               Token.generate_jwt(Keyword.put(opts, :private_key, "not a pem"))

      assert is_binary(message)
    end
  end
end
