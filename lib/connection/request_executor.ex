defmodule Ravix.Connection.RequestExecutor do
  require OK

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.Network
  alias Ravix.Connection.NodeSelector
  alias Ravix.Documents.Protocols.CreateRequest

  def execute(command, network_state = %Network.State{}) do
    OK.for do
      current_node = NodeSelector.current_node(network_state.node_selector)
      request = CreateRequest.create_request(command, current_node)
      conn <- Mint.HTTP.connect(current_node.protocol, current_node.url, current_node.port)
    after
      {:ok, conn, _ref} =
        Mint.HTTP.request(conn, request.method, request.url, @default_headers, request.data)

      receive do
        message ->
          case Mint.HTTP.stream(conn, message) do
            {:ok, _conn, responses} ->
              handle_responses(responses)

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

  defp handle_responses(responses) do
    result =
      responses
      |> Enum.take_while(fn response -> elem(response, 0) != :done end)
      |> Enum.map(fn content -> Map.put(%{}, elem(content, 0), elem(content, 2)) end)
      |> Enum.reduce(fn x, y ->
        Map.merge(x, y, fn _k, v1, v2 -> v2 ++ v1 end)
      end)

    {:ok, result}
  end
end
