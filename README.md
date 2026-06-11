# ShazamKit

Elixir client for the [ShazamKit API](https://developer.apple.com/documentation/shazamkit).

It covers the server-side Shazam catalog endpoints used for:

- matching a Shazam audio signature
- searching by ISRC
- searching tracks by text
- retrieving track details

## Installation

Add to your `mix.exs`:

```elixir
defp deps do
  [
    {:shazam_kit, "~> 0.3.0"}
  ]
end
```

## Configuration

```elixir
config :shazam_kit,
  team_id: System.get_env("APPLE_TEAM_ID"),
  key_id: System.get_env("SHAZAM_KEY_ID"),
  private_key_path: System.get_env("SHAZAM_PRIVATE_KEY_PATH")
```

Supported options:

- `team_id` - Apple Developer Team ID
- `key_id` - ShazamKit key ID
- `private_key` - inline `.p8` contents
- `private_key_path` - path to the `.p8` file
- `base_url` - defaults to `https://api.shazam.com`
- `token_ttl_seconds` - defaults to `1200`

## Quick Start

```elixir
# Match a client-generated signature
{:ok, result} = ShazamKit.match_signature(signature)

# Search by ISRC
{:ok, result} = ShazamKit.search_by_isrc("USUG12002836")

# Search tracks by text
{:ok, result} = ShazamKit.search_tracks("The Beatles", limit: 5)

# Fetch a track by Shazam ID
{:ok, track} = ShazamKit.get_track("548587123")
```

## Audio Signatures

This library does not generate Shazam signatures itself.

Generate signatures on the client side with:

- Apple’s `SHSignatureGenerator` on iOS
- a supported Shazam SDK integration on other platforms

Then send the base64 signature to your Elixir service.

## Notes

- `match_signature/2` accepts either a base64 signature or raw binary with `raw_audio: true`.
- `get_chart/1` and `list_cities/1` are included, but availability may vary by endpoint and account access.
- Tokens are cached in `ShazamKit.TokenCache`.

## License

MIT
