defmodule Ravix.Connection.RequestExecutor.Supervisor do
  @moduledoc false
  require Logger

  alias Ravix.Connection.{RequestExecutor, ServerNode, Topology}
  alias Ravix.Telemetry

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store) do
    children = [
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: supervisor_name(store)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def register_node(%ServerNode{} = node) do
    Logger.debug(
      "[RAVIX] Registering the connection with the node '#{node.url}' for the store '#{node.store}'"
    )

    DynamicSupervisor.start_child(
      {:via, PartitionSupervisor, {supervisor_name(node.store), ServerNode.node_id(node)}},
      {RequestExecutor, node}
    )
  end

  @doc """
  Fetches the nodes running for a specific store
  ## Parameters
  - store: the store module: E.g: Ravix.Test.Store
  ## Returns
  - list({pod, Ravix.Connection.ServerNode})
  """
  def fetch_nodes(store) do
    PartitionSupervisor.which_children(supervisor_name(store))
    |> Enum.map(&fetch_pid/1)
    |> Enum.flat_map(&DynamicSupervisor.which_children/1)
    |> Enum.map(&fetch_pid/1)
    |> Enum.map(&node_state_from_pid/1)
    |> Enum.filter(&filter_valid_nodes/1)
    |> Enum.map(fn {pid, {:ok, node}} -> {pid, node} end)
  end

  defp fetch_pid({_, pid, _kind, _modules}), do: pid

  defp node_state_from_pid(pid), do: {pid, RequestExecutor.fetch_node_state(pid)}

  defp filter_valid_nodes({_, node}), do: elem(node, 0) == :ok

  @doc """
  Triggers a topology update for all nodes of a specific store
  ## Parameters
  - store: the store module. E.g: Ravix.Test.Store
  - topology: The `Ravix.Connection.Topology` to be used
  ## Returns
  - List of nodes `[new_nodes: list(Ravix.Connection.ServerNode), updated_nodes: list(Ravix.Connection.ServerNode)]`
  """
  @spec update_topology(atom(), Ravix.Connection.Topology.t()) :: [
          {:new_nodes, list} | {:updated_nodes, list}
        ]
  def update_topology(store, %Topology{} = topology) do
    Telemetry.topology_updated(store)

    current_nodes = fetch_nodes(store)
    remaining_nodes = remove_old_nodes(current_nodes, topology)
    updated_nodes = update_existing_nodes(remaining_nodes, topology)
    new_nodes = add_new_nodes(store, remaining_nodes, topology)

    [updated_nodes: updated_nodes, new_nodes: new_nodes]
  end

  @spec remove_node(ServerNode.t(), pid) :: :ok | {:error, :not_found}
  defp remove_node(node, pid) do
    Logger.info(
      "[RAVIX] Removing cluster node '#{inspect(node.url)}' for the store '#{inspect(node.store)}'"
    )

    DynamicSupervisor.terminate_child(
      {:via, PartitionSupervisor, {supervisor_name(node.store), node.url}},
      pid
    )
  end

  defp remove_old_nodes(current_nodes, %Topology{} = topology) do
    new_nodes_urls = Enum.map(topology.nodes, fn node -> node.url end)

    nodes_to_delete =
      current_nodes
      |> Enum.reject(fn {_, node} -> Enum.member?(new_nodes_urls, node.url) end)

    nodes_to_delete
    |> Enum.each(fn {pid, node} -> remove_node(node, pid) end)

    current_nodes -- nodes_to_delete
  end

  defp update_existing_nodes(nodes, %Topology{} = topology) do
    nodes
    |> Enum.map(fn {_pid, node} ->
      [
        url: node.url,
        database: node.database,
        cluster_tag: Topology.cluster_tag_for_node(topology, node.url)
      ]
    end)
    |> Enum.map(fn [url: url, database: database, cluster_tag: cluster_tag] ->
      Logger.info(
        "[RAVIX] Updating node '#{inspect(url)}' for the database '#{inspect(database)}' with cluster tag '#{inspect(cluster_tag)}'"
      )

      %{url: url, updated: RequestExecutor.update_cluster_tag(url, database, cluster_tag)}
    end)
  end

  defp add_new_nodes(store, existing_nodes, %Topology{} = topology) do
    existing_nodes_urls = Enum.map(existing_nodes, fn {_pid, node} -> node.url end)

    topology.nodes
    |> Enum.reject(fn node -> Enum.member?(existing_nodes_urls, node.url) end)
    |> Enum.map(fn new_node ->
      Logger.info(
        "[RAVIX] Registering new node '#{inspect(new_node.url)}' for the store '#{inspect(store)}'"
      )

      RequestExecutor.Supervisor.register_node(new_node)
    end)
  end

  defp supervisor_name(store) do
    :"#{store}.Executor"
  end
end
