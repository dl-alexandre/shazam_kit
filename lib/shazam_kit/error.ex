defmodule ShazamKit.Error do
  @moduledoc """
  Structured exception for ShazamKit API failures.
  """

  defexception [:message, :status, :details]

  @type t :: %__MODULE__{
          message: String.t(),
          status: integer() | nil,
          details: map() | nil
        }

  @doc "Create an error from an HTTP response."
  @spec from_http(integer(), binary() | map() | nil) :: t()
  def from_http(status, body) when is_binary(body) and body != "" do
    # Try to parse JSON body
    details =
      case Jason.decode(body) do
        {:ok, decoded} when is_map(decoded) -> decoded
        _ -> %{"raw" => body}
      end

    from_http(status, details)
  end

  def from_http(status, body) when is_map(body) do
    %__MODULE__{
      message: body["message"] || body["error"] || http_reason(status),
      status: status,
      details: body
    }
  end

  def from_http(status, _) do
    %__MODULE__{
      message: http_reason(status),
      status: status,
      details: nil
    }
  end

  @doc "Check if the error indicates no match was found."
  @spec no_match?(t()) :: boolean()
  def no_match?(%__MODULE__{status: 404}), do: true
  def no_match?(%__MODULE__{details: %{"error" => "no_match"}}), do: true
  def no_match?(%__MODULE__{details: %{"message" => "No match found"}}), do: true
  def no_match?(_), do: false

  # HTTP status code meanings
  defp http_reason(200), do: "Success"
  defp http_reason(400), do: "Bad request - invalid signature format"
  defp http_reason(401), do: "Unauthorized - invalid or expired token"
  defp http_reason(404), do: "No match found in catalog"
  defp http_reason(429), do: "Too many requests"
  defp http_reason(500), do: "Internal server error"
  defp http_reason(status), do: "HTTP #{status}"
end
