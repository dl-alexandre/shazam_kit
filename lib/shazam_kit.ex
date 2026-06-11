defmodule ShazamKit do
  @moduledoc """
  Elixir client for the [ShazamKit API](https://developer.apple.com/documentation/shazamkit).

  ShazamKit allows you to match audio signatures against Shazam's vast music catalog.
  Use it to:
  - Identify songs from audio fingerprints
  - Build custom audio recognition features
  - Match user-generated audio against the Shazam database

  ## Quick Start

      # Match a pre-generated audio signature
      ShazamKit.match_signature(signature_data)

      # Search Shazam catalog by ISRC
      ShazamKit.search_by_isrc("USUG12002836")

  ## Configuration

      config :shazam_kit,
        team_id: System.get_env("APPLE_TEAM_ID"),
        key_id: System.get_env("SHAZAM_KEY_ID"),
        private_key: System.get_env("SHAZAM_PRIVATE_KEY"),
        base_url: "https://api.shazam.com"

  ## Audio Signatures

  Audio signatures (fingerprints) must be generated on the client side using:
  - iOS: `SHSignatureGenerator` from ShazamKit framework
  - Android: Shazam SDK
  - Custom implementation following Shazam's signature format

  The signature is a binary blob that ShazamKit uses to match against its catalog.
  """

  alias ShazamKit.{Client, Token}

  @type opts :: keyword()
  @type response :: {:ok, map()} | {:error, term()}

  @doc "Return a cached ShazamKit **access token** (after JWT generation)."
  @spec token(opts) :: {:ok, String.t()} | {:error, term()}
  def token(opts \\ []), do: Token.access_token(opts)

  @doc """
  Match an audio signature against the Shazam catalog.

  ## Parameters

    - `signature`: Audio signature data (base64 encoded string or binary)
    - `opts`:
      - `:raw_audio` - Set to true if signature is raw audio data (signature will be generated server-side)
      - `:limit` - Maximum results (default 1)

  ## Returns

    - `{:ok, %{"matches" => [%{"track" => track_data}]}}` - Match found
    - `{:ok, %{"matches" => []}}` - No match found
    - `{:error, %ShazamKit.Error{}}` - API error

  ## Examples

      signature = "AQAsFU4eASQ..."  # base64 encoded signature from iOS ShazamKit
      ShazamKit.match_signature(signature)

  ## Notes

  Audio signatures should be generated using Apple's ShazamKit framework on iOS,
  or the Shazam SDK on other platforms. The signature format is proprietary to Shazam.
  """
  @spec match_signature(String.t() | binary(), opts) :: response
  def match_signature(signature, opts \\ []) when is_binary(signature) do
    # Check if signature is base64 encoded or raw binary
    body =
      if Keyword.get(opts, :raw_audio, false) do
        %{
          audio: Base.encode64(signature),
          raw: true
        }
      else
        %{
          signature: signature
        }
      end

    body = if limit = Keyword.get(opts, :limit), do: Map.put(body, :limit, limit), else: body

    Client.post("/v1/signature/match", body, opts)
  end

  @doc """
  Search the Shazam catalog by ISRC (International Standard Recording Code).

  ## Parameters

    - `isrc`: ISRC code (e.g., "USUG12002836")

  ## Examples

      ShazamKit.search_by_isrc("USUG12002836")
  """
  @spec search_by_isrc(String.t(), opts) :: response
  def search_by_isrc(isrc, opts \\ []) when is_binary(isrc) do
    Client.get("/v1/catalog/search", Keyword.put(opts, :isrc, isrc))
  end

  @doc """
  Get detailed information about a track by its Shazam ID.

  ## Parameters

    - `track_id`: Shazam track identifier

  ## Examples

      ShazamKit.get_track("548587123")
  """
  @spec get_track(String.t(), opts) :: response
  def get_track(track_id, opts \\ []) when is_binary(track_id) do
    Client.get("/v1/catalog/tracks/#{URI.encode_www_form(track_id)}", opts)
  end

  @doc """
  Search for tracks by artist and title.

  ## Parameters

    - `query`: Search query (artist name, track title, or both)
    - `opts`:
      - `:limit` - Maximum results (1-50, default 10)
      - `:offset` - Pagination offset

  ## Examples

      ShazamKit.search_tracks("The Beatles Yesterday")
      ShazamKit.search_tracks("Billie Eilish", limit: 5)
  """
  @spec search_tracks(String.t(), opts) :: response
  def search_tracks(query, opts \\ []) when is_binary(query) do
    params = [
      term: query,
      limit: Keyword.get(opts, :limit, 10),
      offset: Keyword.get(opts, :offset, 0)
    ]

    Client.get("/v1/catalog/search", Keyword.put(opts, :params, Enum.into(params, %{})))
  end

  @doc """
  Get the Shazam chart (most popular tracks).

  ## Parameters

    - `opts`:
      - `:city_id` - City ID for local charts (optional)
      - `:limit` - Maximum results (default 10)

  ## Examples

      ShazamKit.get_chart()
      ShazamKit.get_chart(city_id: "12345", limit: 20)
  """
  @spec get_chart(opts) :: response
  def get_chart(opts \\ []) do
    endpoint =
      if city_id = Keyword.get(opts, :city_id) do
        "/v1/charts/cities/#{URI.encode_www_form(to_string(city_id))}"
      else
        "/v1/charts/world"
      end

    Client.get(endpoint, opts)
  end

  @doc """
  List available chart cities.

  ## Examples

      ShazamKit.list_cities()
  """
  @spec list_cities(opts) :: response
  def list_cities(opts \\ []) do
    Client.get("/v1/charts/cities", opts)
  end

  @doc """
  Validate if a signature format is valid (basic validation).

  ## Examples

      ShazamKit.valid_signature?("AQAsFU4eASQ...")
  """
  @spec valid_signature?(String.t()) :: boolean()
  def valid_signature?(signature) when is_binary(signature) do
    # Basic validation: signatures are typically base64 and have minimum length
    case Base.decode64(signature) do
      # Shazam signatures have a specific header format
      {:ok, decoded} -> byte_size(decoded) >= 16
      :error -> false
    end
  end

  def valid_signature?(_), do: false
end
