defmodule ShazamKit.ClientTest do
  @moduledoc """
  Tests for ShazamKit.Client module using Bypass for HTTP mocking.
  """

  use ExUnit.Case, async: false

  alias ShazamKit.Client

  setup do
    bypass = Bypass.open()
    private_key = ShazamKit.TestKey.generate_private_key()

    # Configure the application env for the test
    original_env = Application.get_all_env(:shazam_kit)

    Application.put_all_env(
      shazam_kit: [
        team_id: "TEAMID1234",
        key_id: "KEYID56789",
        private_key: private_key,
        base_url: "http://localhost:#{bypass.port}"
      ]
    )

    # Start the TokenCache for the test
    start_supervised!(ShazamKit.TokenCache)

    on_exit(fn ->
      # Restore original env
      Application.put_all_env(shazam_kit: original_env)
    end)

    {:ok, %{bypass: bypass}}
  end

  describe "get/2" do
    test "successfully makes authenticated request", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/catalog/search"

        # Check authorization header exists
        headers = Enum.map(conn.req_headers, fn {k, _} -> k end)
        assert "authorization" in headers

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"tracks" => []}))
      end)

      assert {:ok, body} = Client.get("/v1/catalog/search", [])
      assert Jason.decode!(body) == %{"tracks" => []}
    end

    test "handles 404 no match", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => "no_match",
            "message" => "No match found in catalog"
          })
        )
      end)

      assert {:error, %ShazamKit.Error{status: 404}} =
               Client.get("/v1/catalog/tracks/invalid", [])
    end
  end

  describe "post/3" do
    test "successfully matches signature", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/signature/match"

        headers = Enum.map(conn.req_headers, fn {k, _} -> k end)
        assert "authorization" in headers
        assert "content-type" in headers

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["signature"] == "AQAsFU4eASQ"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "matches" => [
              %{
                "track" => %{
                  "id" => "12345",
                  "title" => "Yesterday",
                  "artist" => "The Beatles"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, body} = Client.post("/v1/signature/match", %{signature: "AQAsFU4eASQ"}, [])
      assert Jason.decode!(body)["matches"] |> length() == 1
    end
  end
end
