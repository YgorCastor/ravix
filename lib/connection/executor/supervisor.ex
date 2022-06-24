defmodule Ravix.Connection.RequestExecutor.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  alias Ravix.Connection.{RequestExecutor, ServerNode, Topology, NodeSelector}

  def init(init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [init_arg]
    )
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store) do
    DynamicSupervisor.start_link(__MODULE__, %{}, name: supervisor_name(store))
  end

  @doc """
  Register a new RavenDB Database node for the informed store

  ## Parameters
  - store: the store module. E.g: Ravix.Test.Store
  - node: the node to be registered
  """
  @spec register_node_pool(any, ServerNode.t()) ::
          :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def register_node_pool(store, %ServerNode{} = node) do
    Logger.debug(
      "[RAVIX] Registering the connection pool with the node '#{node.url}' for the store '#{inspect(store)}'"
    )

    node = %ServerNode{node | store: store}
    DynamicSupervisor.start_child(supervisor_name(store), {RequestExecutor, node})
  end

  @spec remove_node_pool(atom(), pid) :: :ok | {:error, :not_found}
  def remove_node_pool(store, pid) do
    Logger.debug(
      "[RAVIX] Removing cluster node '#{inspect(pid)}' for the store '#{inspect(store)}'"
    )

    DynamicSupervisor.terminate_child(supervisor_name(store), pid)
  end

  @doc """
  Fetch the Node pools for the informed store

  ## Parameters
  - store: the store module: E.g: Ravix.Test.Store
  """
  @spec fetch_node_pools(atom()) :: list({pid(), binary(), ServerNode.t()})
  def fetch_node_pools(store) do
    Registry.select(:request_executor_pools, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.filter(fn {_pool_name, _pid, node} -> node.store == store end)
    |> Enum.map(fn {pool_name, pid, node} -> {pid, pool_name, node} end)
  end

  @doc """
  Fetch all the executors for the informed Store

  ## Parameters
  - store: the store module: E.g: Ravix.Test.Store
  """
  @spec fetch_executors(atom()) :: list(pid())
  def fetch_executors(store) do
    Registry.select(:request_executors, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {executor_store, _pid} -> executor_store == store end)
    |> Enum.map(fn {_executor_store, pid} -> pid end)
  end

  @doc """
  Triggers a topology update for all nodes of a specific store

  ## Parameters
  - store: the store module. E.g: Ravix.Test.Store
  - topology: The `Ravix.Connection.Topology` to be used

  ## Returns
  - List of nodes `[new_nodes: list(Ravix.Connection.ServerNode), updated_nodes: list(Ravix.Connection.ServerNode)]`
  """
  @spec update_topology(any, Ravix.Connection.Topology.t()) :: [
          {:new_nodes, list} | {:updated_nodes, list}
        ]
  def update_topology(store, %Topology{} = topology) do
    current_nodes = fetch_node_pools(store)
    remaining_nodes = remove_old_nodes(store, current_nodes, topology)
    updated_nodes = update_existing_nodes(remaining_nodes, topology)
    new_nodes = add_new_nodes(store, remaining_nodes, topology)

    [updated_nodes: updated_nodes, new_nodes: new_nodes]
  end

  defp remove_old_nodes(store, current_nodes, %Topology{} = topology) do
    new_nodes_ids = Enum.map(topology.nodes, &NodeSelector.node_id(&1))

    nodes_to_delete =
      current_nodes
      |> Enum.reject(fn {_pid, pool_id, _node} -> Enum.member?(new_nodes_ids, pool_id) end)

    nodes_to_delete
    |> Enum.each(fn {pid, _, _} ->
      RequestExecutor.Supervisor.remove_node_pool(store, pid)
    end)

    current_nodes -- nodes_to_delete
  end

  defp update_existing_nodes(nodes, %Topology{} = topology) do
    nodes
    |> Enum.map(fn {pid, _, node} ->
      {pid,
       %ServerNode{
         node
         | cluster_tag: Topology.cluster_tag_for_node(topology, node.url)
       }}
    end)
    |> Enum.map(fn {pid, node} ->
      RequestExecutor.Supervisor.remove_node_pool(node.store, pid)

      Logger.info(
        "[RAVIX] Updating node '#{inspect(node.url)}' for the database '#{inspect(node.database)}' with cluster tag '#{inspect(node.cluster_tag)}'"
      )

      RequestExecutor.Supervisor.register_node_pool(node.store, node)
    end)
  end

  defp add_new_nodes(store, existing_nodes, %Topology{} = topology) do
    existing_nodes = Enum.map(existing_nodes, fn {_pid, pool_id, _node} -> pool_id end)

    topology.nodes
    |> Enum.reject(&Enum.member?(existing_nodes, NodeSelector.node_id(&1)))
    |> Enum.map(fn new_node ->
      Logger.info(
        "[RAVIX] Registering new node '#{inspect(new_node)}' for the store '#{inspect(store)}'"
      )

      RequestExecutor.Supervisor.register_node_pool(store, new_node)
    end)
  end

  defp supervisor_name(store) do
    :"#{store}.Executor"
  end
end
