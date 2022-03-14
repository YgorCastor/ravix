defmodule Ravix.Connection.RequestExecutor do
  require OK

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.{Network, NodeSelector, Response, ServerNode, InMemoryNetworkState}
  alias Ravix.Documents.Protocols.CreateRequest

  @spec execute(map(), Ravix.Connection.Network.State.t(), any) ::
          {:error, any} | {:ok, Response.t()}
  def execute(command, network_state, headers \\ nil)

  def execute(command, %Network.State{} = network_state, nil),
    do: execute(command, network_state, {})

  def execute(command, %Network.State{} = network_state, headers) do
    current_node = NodeSelector.current_node(network_state.node_selector)
    execute_for_node(command, network_state, current_node, headers)
  end

  @spec execute_for_node(
          map(),
          %{:certificate => any, :certificate_file => any, optional(any) => any},
          Ravix.Connection.ServerNode.t(),
          any
        ) :: {:error, any} | {:ok, any}
  def execute_for_node(
        command,
        %{certificate: _, certificate_file: _} = certificate,
        %ServerNode{} = node,
        headers \\ {}
      ) do
    OK.for do
      request = CreateRequest.create_request(command, node)
      conn_params <- build_params(certificate, node.protocol)

      conn <-
        Mint.HTTP.connect(node.protocol, node.url, node.port, conn_params)

      {:ok, conn, _ref} =
        Mint.HTTP.request(
          conn,
          request.method,
          request.url,
          @default_headers ++ [headers],
          request.data
        )
    after
      receive do
        message ->
          case Mint.HTTP.stream(conn, message) do
            {:ok, _conn, responses} ->
              case parse_response(responses) do
                %{status: 404} -> {:error, :document_not_found}
                %{status: 503} -> {:error, :database_not_found}
                %{data: data} when is_map_key(data, "Error") -> {:error, data["Message"]}
                {:error, err} -> {:error, err}
                parsed_response -> {:ok, parsed_response}
              end
              |> check_if_needs_topology_update(node.database)

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

  defp check_if_needs_topology_update({:ok, response}, database_name) do
    case Enum.find(response.headers, fn header -> elem(header, 0) == "Refresh-Topology" end) do
      nil ->
        response

      _ ->
        InMemoryNetworkState.update_topology(database_name)
        response
    end
  end

  defp check_if_needs_topology_update({:error, err}, _), do: {:error, err}

  defp build_params(_, :http), do: {:ok, []}

  defp build_params(certificate, :https) do
    case certificate do
      %{certificate: nil, certificate_file: file} ->
        {:ok, transport_opts: [cacertfile: file]}

      %{certificate: cert, certificate_file: nil} ->
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
    |> decode_body()
  end

  defp decode_body(raw_response) when is_map_key(raw_response, :data) do
    case Jason.decode(raw_response.data) do
      {:ok, body} -> Map.replace(raw_response, :data, body)
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_response_payload}
    end
  end

  defp decode_body(raw_response), do: raw_response
end
