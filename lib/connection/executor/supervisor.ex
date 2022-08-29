defmodule Ravix.Connection.RequestExecutor.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  alias Ravix.Connection.{RequestExecutor, ServerNode, Topology}

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

  def register_node(node = %ServerNode{}) do
    Logger.debug(
      "[RAVIX] Registering the connection with the node '#{node.url}' for the store '#{node.store}'"
    )

    DynamicSupervisor.start_child(supervisor_name(node.store), {RequestExecutor, node})
  end

  @spec remove_node(atom(), pid) :: :ok | {:error, :not_found}
  def remove_node(store, pid) do
    Logger.debug(
      "[RAVIX] Removing cluster node '#{inspect(pid)}' for the store '#{inspect(store)}'"
    )

    DynamicSupervisor.terminate_child(supervisor_name(store), pid)
  end

  @doc """
  Fetches the nodes running for a specific store
  ## Parameters
  - store: the store module: E.g: Ravix.Test.Store
  ## Returns
  - list({pod, Ravix.Connection.ServerNode})
  """
  def fetch_nodes(store) do
    DynamicSupervisor.which_children(supervisor_name(store))
    |> Enum.map(fn {_, pid, _kind, _modules} -> pid end)
    |> Enum.map(fn pid -> {pid, RequestExecutor.fetch_node_state(pid)} end)
    |> Enum.filter(fn {_, response} -> elem(response, 0) == :ok end)
    |> Enum.map(fn {pid, {:ok, node}} -> {pid, node} end)
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
    current_nodes = fetch_nodes(store)
    remaining_nodes = remove_old_nodes(store, current_nodes, topology)
    updated_nodes = update_existing_nodes(remaining_nodes, topology)
    new_nodes = add_new_nodes(store, remaining_nodes, topology)

    [updated_nodes: updated_nodes, new_nodes: new_nodes]
  end

  defp remove_old_nodes(store, current_nodes, %Topology{} = topology) do
    new_nodes_urls = Enum.map(topology.nodes, fn node -> node.url end)

    nodes_to_delete =
      current_nodes
      |> Enum.reject(fn {_, node} -> Enum.member?(new_nodes_urls, node.url) end)

    nodes_to_delete
    |> Enum.each(fn {pid, _node} ->
      RequestExecutor.Supervisor.remove_node(store, pid)
    end)

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
        "[RAVIX] Registering new node '#{inspect(new_node)}' for the store '#{inspect(store)}'"
      )

      RequestExecutor.Supervisor.register_node(new_node)
    end)
  end

  defp supervisor_name(store) do
    :"#{store}.Executor"
  end
end
