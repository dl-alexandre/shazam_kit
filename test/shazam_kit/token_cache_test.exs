defmodule ShazamKit.TokenCacheTest do
  @moduledoc """
  Tests for ShazamKit.TokenCache GenServer.
  """

  use ExUnit.Case, async: false

  alias ShazamKit.TokenCache

  setup do
    # Configure the application env for the test
    private_key = ShazamKit.TestKey.generate_private_key()

    original_env = Application.get_all_env(:shazam_kit)

    Application.put_all_env(
      shazam_kit: [
        team_id: "TEAMID1234",
        key_id: "KEYID56789",
        private_key: private_key
      ]
    )

    # Start the TokenCache for the test
    start_supervised!(ShazamKit.TokenCache)

    on_exit(fn ->
      # Restore original env
      Application.put_all_env(shazam_kit: original_env)
    end)

    :ok
  end

  describe "fetch/0" do
    test "generates new token on first call" do
      assert {:ok, token1} = TokenCache.fetch()
      assert is_binary(token1)

      # Verify it's a valid JWT (has 3 parts)
      assert String.split(token1, ".") |> length() == 3
    end

    test "returns cached token on subsequent calls" do
      assert {:ok, token1} = TokenCache.fetch()
      assert {:ok, token2} = TokenCache.fetch()

      assert token1 == token2
    end
  end

  describe "clear/0" do
    test "clears cache so next fetch generates new token" do
      assert {:ok, token1} = TokenCache.fetch()
      :ok = TokenCache.clear()
      assert {:ok, token2} = TokenCache.fetch()

      # Tokens should be different (different timestamps)
      assert token1 != token2
    end
  end
end
