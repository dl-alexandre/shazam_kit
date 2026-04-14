defmodule ShazamKit.Client do
  @moduledoc """
  HTTP client for ShazamKit API.
  """

  alias ShazamKit.{Config, Error, Token, TokenCache}

  @config_keys [
    :team_id,
    :key_id,
    :private_key,
    :private_key_path,
    :base_url,
    :token_ttl_seconds,
    :req_options
  ]

  @doc """
  Perform a signed GET request to the ShazamKit API.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(endpoint, opts \\ []) do
    {config_opts, request_opts} = Keyword.split(opts, @config_keys)
    config = Config.load(config_opts)

    with {:ok, token} <- fetch_access_token(config_opts) do
      url = build_url(config.base_url, endpoint, request_opts)

      req =
        Req.new(
          base_url: config.base_url,
          headers: [{"authorization", "Bearer #{token}"}]
        )
        |> Req.merge(config.req_options)

      req
      |> Req.get(url: url, params: request_opts[:params] || %{})
      |> normalize()
    end
  end

  @doc """
  Perform a signed POST request to the ShazamKit API.
  """
  @spec post(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(endpoint, body, opts \\ []) do
    {config_opts, request_opts} = Keyword.split(opts, @config_keys)
    config = Config.load(config_opts)

    with {:ok, token} <- fetch_access_token(config_opts) do
      url = build_url(config.base_url, endpoint, request_opts)

      req =
        Req.new(
          base_url: config.base_url,
          headers: [
            {"authorization", "Bearer #{token}"},
            {"content-type", "application/json"}
          ]
        )
        |> Req.merge(config.req_options)

      req
      |> Req.post(url: url, json: body)
      |> normalize()
    end
  end

  defp fetch_access_token([]), do: TokenCache.fetch()
  defp fetch_access_token(config_opts), do: Token.access_token(config_opts)

  defp build_url(_base_url, endpoint, opts) do
    # Handle URL path replacement for any path parameters
    Enum.reduce(opts[:path_params] || %{}, endpoint, fn {key, value}, acc ->
      String.replace(acc, "{#{key}}", URI.encode(value))
    end)
  end

  defp normalize({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body || %{}}
  end

  defp normalize({:ok, %Req.Response{status: status, body: body}}) do
    {:error, Error.from_http(status, body)}
  end

  defp normalize({:error, reason}) do
    {:error, {:transport_error, reason}}
  end
end
