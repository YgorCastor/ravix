defmodule Ravix.Connection.RequestExecutor do
  use GenServer
  use Retry

  require OK
  require Logger

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, NodeSelector, Response}
  alias Ravix.Documents.Protocols.CreateRequest

  @spec init(ServerNode.t()) ::
          {:ok, ServerNode.t()}
          | {:stop,
             %{
               :__exception__ => any,
               :__struct__ => Mint.HTTPError | Mint.TransportError,
               :reason => any,
               optional(:module) => any
             }}
  def init(%ServerNode{} = node) do
    {:ok, conn_params} = build_params(node.certificate, node.protocol)

    case Mint.HTTP.connect(node.protocol, node.url, node.port, conn_params) do
      {:ok, conn} -> {:ok, %ServerNode{node | conn: conn}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @spec start_link(any, Ravix.Connection.ServerNode.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attrs, %ServerNode{} = node) do
    GenServer.start_link(
      __MODULE__,
      node,
      name: executor_id(node.database, node.url)
    )
  end

  @spec execute(map, ConnectionState.t(), any, keyword) :: {:error, any} | {:ok, Response.t()}
  def execute(
        command,
        %ConnectionState{} = conn_state,
        headers \\ {},
        opts \\ []
      ) do
    node_pid = NodeSelector.current_node(conn_state)

    headers =
      case conn_state.disable_topology_updates do
        false -> headers
        true -> [{"Topology-Etag", conn_state.topology_etag}]
      end

    execute_for_node(command, node_pid, nil, headers, opts)
  end

  @spec execute_for_node(map(), binary | pid, String.t() | nil, any, keyword) :: any
  def execute_for_node(command, pid_or_url, database, headers \\ {}, opts \\ [])

  def execute_for_node(command, pid_or_url, _database, headers, opts) when is_pid(pid_or_url) do
    call_raven(pid_or_url, command, headers, opts)
  end

  def execute_for_node(command, pid_or_url, database, headers, opts)
      when is_bitstring(pid_or_url) do
    call_raven(executor_id(database, pid_or_url), command, headers, opts)
  end

  defp call_raven(executor, command, headers, opts) do
    should_retry = Keyword.get(opts, :should_retry, false)
    retry_backoff = Keyword.get(opts, :retry_backoff, 100)

    retry_count =
      case should_retry do
        true -> Keyword.get(opts, :retry_count, 3)
        false -> 0
      end

    retry with: constant_backoff(retry_backoff) |> Stream.take(retry_count) do
      GenServer.call(executor, {:request, command, headers})
    after
      {:ok, result} -> {:ok, result}
      {:non_retryable_error, response} -> {:error, response}
      {:error, error_response} -> {:error, error_response}
    else
      err -> err
    end
  end

  @spec update_cluster_tag(String.t(), String.t(), String.t()) :: :ok
  def update_cluster_tag(url, database, cluster_tag) do
    GenServer.cast(executor_id(url, database), {:update_cluster_tag, cluster_tag})
  end

  @spec fetch_node_state(bitstring | pid) :: {:ok, ServerNode.t()} | {:error, :node_not_found}
  def fetch_node_state(pid) when is_pid(pid) do
    try do
      {:ok, pid |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  @spec fetch_node_state(binary, binary) :: {:ok, ServerNode.t()} | {:error, :node_not_found}
  def fetch_node_state(url, database) when is_bitstring(url) do
    try do
      {:ok, executor_id(url, database) |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  defp executor_id(url, database),
    do: {:via, Registry, {:request_executors, url <> "/" <> database}}

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

  def handle_cast({:update_cluster_tag, cluster_tag}, %ServerNode{} = node) do
    {:noreply, %ServerNode{node | cluster_tag: cluster_tag}}
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

        %{data: :invalid_response_payload} ->
          {:non_retryable_error, "Unable to parse the response payload"}

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
        {:ok, response}

      _ ->
        {:ok, response}
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
    case Jason.decode(raw_response) do
      {:ok, parsed_response} -> parsed_response
      {:error, %Jason.DecodeError{}} -> :invalid_response_payload
    end
  end
end
