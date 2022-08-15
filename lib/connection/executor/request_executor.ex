defmodule Ravix.Connection.RequestExecutor do
  @moduledoc false
  use Retry

  require OK
  require Logger

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, NodeSelector, Response}
  alias Ravix.Connection.RequestExecutor

  @doc """
  Executes a RavenDB command for the informed connection

  ## Parameters

  - command: The command that will be executed, must be a RavenCommand
  - conn_state: The connection state for which this execution will be linked
  - headers: HTTP headers to send to RavenDB
  - opts: Request options

  ## Returns
  - `{:ok, Ravix.Connection.Response}` for a successful synchronous call
  - `{:ok, Enumerable}` if it's a streammed command
  - `{:error, cause}` if the request fails
  """
  @spec execute(struct(), ConnectionState.t(), tuple(), keyword()) ::
          {:ok, Response.t()} | {:ok, Enumerable.t()} | {:error, any()}
  def execute(
        %{is_stream: is_stream} = command,
        %ConnectionState{} = conn_state,
        headers \\ {},
        opts \\ []
      ) do
    opts = opts ++ RequestExecutor.Options.from_connection_state(conn_state)

    should_retry = Keyword.get(opts, :retry_on_failure, false) and not is_stream
    retry_backoff = Keyword.get(opts, :retry_backoff, 100)

    retry_count =
      case should_retry do
        true -> Keyword.get(opts, :retry_count, 3)
        false -> 0
      end

    headers =
      case conn_state.disable_topology_updates do
        true -> headers
        false -> [{"Topology-Etag", conn_state.topology_etag}]
      end

    retry with: constant_backoff(retry_backoff) |> Stream.take(retry_count) do
      pool_name = NodeSelector.current_node(conn_state)
      execute_with_node_pool(command, pool_name, headers, opts)
    after
      {:ok, result} ->
        {:ok, result}

      {:error, :not_found} ->
        {:error, :not_found}

      {_, response} ->
        Logger.error("[RAVIX] Error received from RavenDB: #{inspect(response)}")
        {:error, response}
    else
      err -> err
    end
  end

  @doc """
  Executes a RavenDB command on the informed node

  ## Parameters

  - command: The command that will be executed, must be a RavenCommand
  - pid: The PID of the node
  - headers: HTTP headers to send to RavenDB
  - opts: Request options

  ## Returns
  - `{:ok, Ravix.Connection.Response}` for a successful synchronous call
  - `{:ok, Enumerable}` if it's a streammed command
  - `{:error, cause}` if the request fails
  """
  @spec execute_with_node(struct(), pid(), tuple(), keyword()) ::
          {:ok, Response.t()} | {:ok, Enumerable.t()} | {:error, any()}
  def execute_with_node(command, pid, headers \\ {}, opts \\ []) do
    case call_raven(pid, command, headers, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, :not_found} ->
        {:error, :not_found}

      {_, response} ->
        Logger.error("[RAVIX] Error received from RavenDB: #{inspect(response)}")
        {:error, response}
    end
  end

  defp execute_with_node_pool(command, pool_name, headers, opts) do
    :poolboy.transaction(
      pool_id(pool_name),
      fn pid ->
        call_raven(pid, command, headers, opts)
      end
    )
  end

  defp call_raven(pid, %{is_stream: false} = command, headers, opts) do
    timeout = Keyword.get(opts, :timeout, 15000)

    GenServer.call(pid, {:request, command, headers, opts}, timeout)
  end

  defp call_raven(pid, command, headers, opts) do
    init_request = fn ->
      GenServer.call(pid, {:request, command, headers, opts})
    end

    read_buffer = fn {:ok, request_ref} ->
      case GenServer.call(pid, {:read_request_buffer, request_ref}) do
        {:ok, :halt} -> {:halt, {:ok, request_ref}}
        {:ok, chunk} -> {[chunk], {:ok, request_ref}}
      end
    end

    no_op = fn _request_ref ->
      nil
    end

    {:ok,
     Stream.resource(init_request, read_buffer, no_op)
     |> Jaxon.Stream.from_enumerable()
     |> Jaxon.Stream.query([:root, "Results", :all])}
  end

  @doc """
  Fetches the current node executor state

  ## Parameters
  pid = The PID of the node

  ## Returns
  - `{:ok, Ravix.Connection.ServerNode}` if there's a node
  - `{:error, :node_not_found}` if there's not a node with the informed pid
  """
  @spec fetch_node_state(pid) :: {:ok, ServerNode.t()} | {:error, :node_not_found}
  def fetch_node_state(pid) when is_pid(pid) do
    try do
      {:ok, pid |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :node_not_found}
    end
  end

  @spec start_link(any, ServerNode.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attrs, %ServerNode{} = node) do
    poolboy_config = [
      {:name, pool_registry(node)},
      {:worker_module, Ravix.Connection.RequestExecutor.Worker},
      {:size, node.min_pool_size},
      {:max_overflow, node.max_pool_size}
    ]

    executor_config =
      Keyword.new(Map.from_struct(node), fn {k, v} ->
        {k, v}
      end)

    :poolboy.start_link(
      poolboy_config,
      executor_config
    )
  end

  @spec child_spec(ServerNode.t()) :: %{
          id: atom,
          start: {RequestExecutor, :start_link, [map, ...]}
        }
  def child_spec(%ServerNode{} = node) do
    %{
      id: String.to_atom(node.url <> "_" <> node.database),
      start: {__MODULE__, :start_link, [node]}
    }
  end

  defp pool_registry(%ServerNode{} = node) do
    {:via, Registry, {:request_executor_pools, NodeSelector.node_id(node), node}}
  end

  defp pool_id(pool_id) do
    {:via, Registry, {:request_executor_pools, pool_id}}
  end
end
