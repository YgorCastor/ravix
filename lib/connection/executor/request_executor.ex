defmodule Ravix.Connection.RequestExecutor do
  use GenServer

  require Logger
  require OK

  alias Ravix.Telemetry
  alias Ravix.Connection
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.RequestExecutor
  alias Ravix.Connection.RequestExecutor.Client
  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Documents.Protocols.CreateRequest

  @default_headers [{"content-type", "application/json"}, {"accept", "application/json"}]

  def init(%ServerNode{} = node) do
    Logger.debug(
      "[RAVIX] Creating a connection to node '#{inspect(node.url)}:#{inspect(node.port)}' for store '#{inspect(node.store)}'"
    )

    case RequestExecutor.Client.build(node) do
      {:ok, node} -> {:ok, node}
      {:error, err} -> {:stop, err}
    end
  end

  @spec start_link(any, ServerNode.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attrs, %ServerNode{} = node) do
    GenServer.start_link(
      __MODULE__,
      node,
      name: executor_id(node.url, node.database)
    )
  end

  def execute(
        command,
        %ConnectionState{} = conn_state,
        headers \\ []
      ) do
    {pid, _} = NodeSelector.current_node(conn_state)

    headers =
      case conn_state.disable_topology_updates do
        true -> headers
        false -> headers ++ [{"Topology-Etag", Integer.to_string(conn_state.topology_etag)}]
      end

    execute_with_node(command, pid, headers)
  end

  def execute_with_node(command, pid, headers \\ []) do
    case call_raven(pid, command, headers) do
      {:ok, result} ->
        {:ok, result}

      {:error, err} when err in [:not_found, :conflict] ->
        {:error, err}

      {_, response} ->
        Logger.error("[RAVIX] Error: #{inspect(response)}")
        {:error, response}
    end
  end

  @doc """
  Fetches the current node executor state
  ## Parameters
  pid = The PID of the node
  ## Returns
  - `{:ok, Ravix.Connection.ServerNode}` if there's a node
  - `{:error, :node_not_found}` if there's not a node with the informed pid
  """
  @spec fetch_node_state(bitstring | pid) :: {:ok, ServerNode.t()} | {:error, :node_not_found}
  def fetch_node_state(pid) when is_pid(pid) do
    try do
      {:ok, pid |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  @doc """
  Fetches the current node executor state
  ## Parameters
  url = The node url
  database = the node database name
  ## Returns
  - `{:ok, Ravix.Connection.ServerNode}` if there's a node
  - `{:error, :node_not_found}` if there's not a node with the informed pid
  """
  @spec fetch_node_state(binary, binary) :: {:ok, ServerNode.t()} | {:error, :node_not_found}
  def fetch_node_state(url, database) when is_bitstring(url) do
    try do
      {:ok, executor_id(url, database) |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  @doc """
  Asynchronously updates the cluster tag for the current node
  ## Parameters
  - url: Node url
  - database:  Database name
  - cluster_tag: new cluster tag
  ## Returns
  - :ok
  """
  @spec update_cluster_tag(String.t(), String.t(), String.t()) :: :ok
  def update_cluster_tag(url, database, cluster_tag) do
    GenServer.cast(executor_id(url, database), {:update_cluster_tag, cluster_tag})
  end

  defp call_raven(pid, command, headers) do
    OK.for do
      node <- fetch_node_state(pid)
      request = CreateRequest.create_request(command, node)
      _ <- maximum_url_length_reached?(node, request.url)

      result <-
        Client.request(
          node,
          request.method,
          request.url,
          request.headers ++ headers ++ @default_headers,
          request.data,
          is_stream: command.is_stream
        )

      result <- parse_result(result, node)
    after
      result
    end
  end

  defp parse_result(response, node) do
    case response do
      %{status: 404} ->
        Telemetry.request_error(node, 404)

        {:error, :document_not_found}

      %{status: 403} ->
        Telemetry.request_error(node, 403)

        {:error, :unauthorized}

      %{status: 409} ->
        Telemetry.request_error(node, 409)

        {:error, :conflict}

      %{status: 410} ->
        Telemetry.request_error(node, 410)

        {:error, :node_gone}

      %{body: body} when is_map_key(body, "Error") ->
        Telemetry.request_error(node, 500)

        {:error, body["Message"]}

      %{body: %{"IsStale" => true, "IndexName" => index_name}} = response ->
        Telemetry.request_stale(node, index_name)

        case stale_is_error(node.settings.stale_is_error, index_name, node) do
          true -> {:error, :stale}
          false -> {:ok, response}
        end

      error_response when error_response.status in [408, 502, 503, 504] ->
        Telemetry.request_error(node, error_response.status)

        parse_error(error_response)

      response ->
        Telemetry.request_success(node)

        {:ok, response}
    end
    |> check_if_needs_topology_update(node)
    |> parse_body()
  end

  defp check_if_needs_topology_update({:ok, response}, %ServerNode{} = node) do
    case Enum.find(response.headers, fn header -> elem(header, 0) == "Refresh-Topology" end) do
      nil ->
        {:ok, response}

      _ ->
        Logger.info(
          "[RAVIX] The database requested a topology refresh for the store '#{inspect(node.store)}'"
        )

        Connection.update_topology(node.store)

        {:ok, response}
    end
  end

  defp check_if_needs_topology_update({error_kind, err}, _), do: {error_kind, err}

  @spec maximum_url_length_reached?(ServerNode.t(), String.t()) ::
          {:ok, nil} | {:error, :maximum_url_length_reached}
  defp maximum_url_length_reached?(node, url) do
    max_url_length = node.settings.max_url_length

    case String.length(url) > max_url_length do
      true -> {:error, :maximum_url_length_reached}
      false -> {:ok, nil}
    end
  end

  defp parse_error(error_response) do
    {:error, error_response.body["Message"]}
  end

  defp executor_id(url, database),
    do: {:via, Registry, {:request_executors, url <> "/" <> database}}

  defp stale_is_error(false, index, node),
    do: Enum.member?(node.settings.not_allowed_stale_indexes, index)

  defp stale_is_error(true, _, _),
    do: true

  defp parse_body({:ok, response}), do: {:ok, response.body}

  defp parse_body({:error, error}), do: {:error, error}

  def handle_cast({:update_cluster_tag, cluster_tag}, %ServerNode{} = node) do
    {:noreply, %ServerNode{node | cluster_tag: cluster_tag}}
  end
end
