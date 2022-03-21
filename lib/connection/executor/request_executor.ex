defmodule Ravix.Connection.RequestExecutor do
  use GenServer
  use Retry

  require OK
  require Logger

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, NodeSelector, Response}
  alias Ravix.Documents.Protocols.CreateRequest

  def init(%ServerNode{} = node) do
    {:ok, conn_params} = build_params(node.certificate, node.protocol)

    case Mint.HTTP.connect(node.protocol, node.url, node.port, conn_params) do
      {:ok, conn} -> {:ok, %ServerNode{node | conn: conn}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @spec start_link(ServerNode.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%ServerNode{} = node) do
    GenServer.start_link(
      __MODULE__,
      node,
      name: executor_id(node.url)
    )
  end

  @spec execute(map, ConnectionState.t(), any, keyword()) :: Response.t()
  def execute(
        command,
        %ConnectionState{} = network_state,
        headers \\ {},
        _opts \\ []
      ) do
    node_pid = NodeSelector.current_node(network_state)

    GenServer.call(node_pid, {:request, command, headers})
  end

  @spec execute_for_node(map(), bitstring | pid, any, keyword()) :: Response.t()
  def execute_for_node(command, pid_or_url, headers \\ {}, _opts \\ [])

  def execute_for_node(command, pid_or_url, headers, _opts) when is_pid(pid_or_url) do
    GenServer.call(pid_or_url, {:request, command, headers})
  end

  def execute_for_node(command, pid_or_url, headers, _opts) when is_bitstring(pid_or_url) do
    GenServer.call(executor_id(pid_or_url), {:request, command, headers})
  end

  defp executor_id(url), do: {:via, Registry, {:request_executors, url}}

  ####################
  #     Handlers     #
  ####################
  def handle_call({:request, command, headers}, from, %ServerNode{} = node) do
    request = CreateRequest.create_request(command, node)

    case Mint.HTTP.request(
           node.conn,
           request.method,
           request.url,
           @default_headers ++ [headers],
           request.data
         ) do
      {:ok, conn, request_ref} ->
        node = put_in(node.conn, conn)
        node = put_in(node.requests[request_ref], %{from: from, response: %{}})
        {:noreply, node}

      {:error, conn, reason} ->
        state = put_in(node.conn, conn)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(message, %ServerNode{} = node) do
    case Mint.HTTP.stream(node.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, node}

      {:ok, conn, responses} ->
        node = put_in(node.conn, conn)
        state = Enum.reduce(responses, node, &process_response/2)
        {:noreply, state}

      {:error, _conn, error, _headers} when is_struct(error, Mint.HTTPError) ->
        {:error, error.reason}

      {:error, _conn, error, _headers} when is_struct(error, Mint.TransportError) ->
        {:error, error.reason}
    end
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, new_data}, state) do
    put_in(state.requests[request_ref].response[:data], decode_body(new_data))
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])

    parsed_response =
      case response do
        %{status: 404} ->
          {:non_retryable_error, :document_not_found}

        %{status: 403} ->
          {:non_retryable_error, :unauthorized}

        %{status: 410} ->
          {:error, :node_gone}

        %{data: data} when is_map_key(data, "Error") ->
          {:non_retryable_error, data["Message"]}

        error_response when error_response.status in [408, 502, 503, 504] ->
          parse_error(error_response)

        {:error, err} ->
          {:non_retryable_error, err}

        parsed_response ->
          {:ok, parsed_response}
      end
      |> check_if_needs_topology_update(state)

    GenServer.reply(from, parsed_response)

    state
  end

  defp check_if_needs_topology_update({:ok, response}, %ServerNode{} = _node) do
    case Enum.find(response.headers, fn header -> elem(header, 0) == "Refresh-Topology" end) do
      nil ->
        response

      _ ->
        response
    end
  end

  defp check_if_needs_topology_update({error_kind, err}, _), do: {error_kind, err}

  defp parse_error(error_response) do
    case Enum.find(error_response.headers, fn header -> elem(header, 0) == "Database-Missing" end) do
      nil ->
        {:retryable_error, error_response.data["Message"]}

      _ ->
        {:error, error_response.data["Message"]}
    end
  end

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

  defp decode_body(raw_response) do
    case Jason.decode(raw_response.data) do
      {:ok, body} -> Map.replace(raw_response, :data, body)
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_response_payload}
    end
  end
end
