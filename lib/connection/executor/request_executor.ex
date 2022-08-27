defmodule Ravix.Connection.RequestExecutor do
  use GenServer

  require Logger
  require OK

  alias Ravix.Connection
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.State, as: ConnectionState

  alias Ravix.Documents.Protocols.CreateRequest

  def init(%ServerNode{} = node) do
    Logger.debug(
      "[RAVIX] Creating a connection to node '#{inspect(node.url)}:#{inspect(node.port)}' for store '#{inspect(node.store)}'"
    )

    case client(node) do
      {:ok, node} -> {:ok, node}
      {:error, node} -> {:stop, node}
    end
  end

  def start_link(_attrs, node) do
    GenServer.start_link(__MODULE__, node)
  end

  def execute(
        command,
        %ConnectionState{} = conn_state,
        headers \\ {},
        opts \\ []
      ),
      do: execute_with_node(command, NodeSelector.current_node(conn_state), headers, opts)

  def execute_with_node(command, pid, headers \\ {}, opts \\ []) do
    case call_raven(pid, command, headers, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, :not_found} ->
        {:error, :not_found}

      {_, response} ->
        Logger.error("[RAVIX] Error: #{inspect(response)}")
        {:error, response}
    end
  end

  defp fetch_state(executor_pid) do
    try do
      {:ok,
       executor_pid
       |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  defp call_raven(pid, command, headers, opts) do
    OK.for do
      node <- fetch_state(pid)
      request = CreateRequest.create_request(command, node)

      result <-
        Tesla.request(
          node.client,
          url: request.url,
          method: request.method,
          body: request.data,
          headers: request.headers
        )
        |> IO.inspect()

      result <- parse_result(result, node)
    after
      result
    end
  end

  defp parse_result(response, node) do
    case response do
      %{status: 404} ->
        {:error, :document_not_found}

      %{status: 403} ->
        {:error, :unauthorized}

      %{status: 409} ->
        {:error, :conflict}

      %{status: 410} ->
        {:error, :node_gone}

      %{body: body} when is_map_key(body, "Error") ->
        {:error, body["Message"]}

      %{body: %{"IsStale" => true}} ->
        {:error, :stale}

      error_response when error_response.status in [408, 502, 503, 504] ->
        parse_error(error_response)

      response ->
        {:ok, response.body}
    end
    |> check_if_needs_topology_update(node)
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

  defp parse_error(error_response) do
    {:error, error_response.body["Message"]}
  end

  defp build_ssl_params(_, :http), do: {:ok, []}

  defp build_ssl_params(ssl_config, :https) do
    case ssl_config do
      [] ->
        {:error, :no_ssl_configurations_informed}

      transport_ops ->
        {:ok, transport_opts: transport_ops}
    end
  end

  defp client(node) do
    OK.for do
      ssl_params <- build_ssl_params(node.ssl_config, node.protocol)
      base_url = {Tesla.Middleware.BaseUrl, "#{node.protocol}://#{node.url}:#{node.port}"}
      adapter = {Tesla.Adapter.Finch, name: Ravix.Finch}
    after
      %ServerNode{node | client: Tesla.client([base_url, Tesla.Middleware.JSON], adapter)}
    end
  end
end
