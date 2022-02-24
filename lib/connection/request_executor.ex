defmodule Ravix.Connection.RequestExecutor do
  require OK

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.Network
  alias Ravix.Connection.NodeSelector
  alias Ravix.Documents.Protocols.CreateRequest

  @spec execute(map(), Network.State.t()) :: {:error, any} | {:ok, map()}
  def execute(command, %Network.State{} = network_state) do
    OK.for do
      current_node = NodeSelector.current_node(network_state.node_selector)
      request = CreateRequest.create_request(command, current_node)
      conn_params <- build_params(network_state, current_node.protocol)

      conn <-
        Mint.HTTP.connect(current_node.protocol, current_node.url, current_node.port, conn_params)

      {:ok, conn, _ref} =
        Mint.HTTP.request(conn, request.method, request.url, @default_headers, request.data)
    after
      receive do
        message ->
          case Mint.HTTP.stream(conn, message) do
            {:ok, _conn, responses} ->
              case parse_response(responses) do
                %{headers: _, status: 404} -> {:error, :document_not_found}
                parsed_response -> {:ok, parsed_response}
              end

            {:error, _conn, error, _headers} when is_struct(error, Mint.HTTPError) ->
              {:error, error.reason}

            {:error, _conn, error, _headers} when is_struct(error, Mint.TransportError) ->
              {:error, error.reason}

            _ ->
              {:error, :unexpected_request_error}
          end
      end
    end
  end

  defp build_params(_network_state, :http), do: {:ok, []}

  defp build_params(%Network.State{} = network_state, :https) do
    case network_state do
      %Network.State{certificate: nil, certificate_file: file} ->
        {:ok, transport_opts: [cacertfile: file]}

      %Network.State{certificate: cert, certificate_file: nil} ->
        {:ok, transport_opts: [cacert: cert]}

      _ ->
        {:error, :invalid_ssl_certificate}
    end
  end

  defp parse_response(responses) do
    responses
    |> Enum.take_while(fn response -> elem(response, 0) != :done end)
    |> Enum.map(fn content -> Map.put(%{}, elem(content, 0), elem(content, 2)) end)
    |> Enum.reduce(fn x, y ->
      Map.merge(x, y, fn _k, v1, v2 -> v2 ++ v1 end)
    end)
  end
end
