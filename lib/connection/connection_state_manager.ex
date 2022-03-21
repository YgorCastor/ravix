defmodule Ravix.Connection.State.Manager do
  require OK

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, RequestExecutor, Topology, NodeSelector}
  alias Ravix.Connection.Commands.GetTopology
  alias Ravix.Connection.RequestExecutor.Supervisor, as: ExecutorSupervisor
  alias Ravix.Operations.Database.Maintenance, as: DatabaseMaintenance

  @spec initialize(ConnectionState.t()) :: ConnectionState.t()
  def initialize(%ConnectionState{} = state) do
    OK.try do
      node_pids <- register_nodes(state)

      _ =
        case state.force_create_database do
          true ->
            node_pids
            |> Enum.at(0)
            |> DatabaseMaintenance.create_database(state.database)

          false ->
            :ok
        end

      topology <- ConnectionState.Manager.request_topology(node_pids, state.database)
      _ = ExecutorSupervisor.update_topology(state.store, topology)
      state = put_in(state.node_selector, %NodeSelector{current_node_index: 0})
    after
      state
    rescue
      :invalid_cluster_topology -> raise "Unable to fetch the cluster topology"
      :no_node_registered -> raise "No nodes were registered successfully"
    end
  end

  @spec request_topology(list(pid()), String.t()) ::
          {:error, :invalid_cluster_topology} | {:ok, Ravix.Connection.Topology.t()}
  def request_topology(node_pids, database) do
    topology =
      node_pids
      |> Enum.map(fn node ->
        RequestExecutor.execute_for_node(
          %GetTopology{database_name: database},
          node
        )
      end)
      |> Enum.find(fn topology_response -> elem(topology_response, 0) == :ok end)

    case topology do
      {:ok, response} ->
        {:ok,
         %Topology{
           etag: response.data["Etag"],
           nodes: response.data["Nodes"] |> Enum.map(&ServerNode.from_api_response/1)
         }}

      _ ->
        {:error, :invalid_cluster_topology}
    end
  end

  def connection_id(state), do: {:via, Registry, {:sessions, state}}

  defp register_nodes(%ConnectionState{} = state) do
    registered_nodes =
      state.urls
      |> Enum.map(fn url -> ServerNode.from_url(url, state.database, state.certificate) end)
      |> Enum.map(fn node ->
        RequestExecutor.Supervisor.register_node_executor(state.store, node)
      end)
      |> Enum.filter(fn pids -> elem(pids, 0) == :ok end)
      |> Enum.map(fn pid -> elem(pid, 1) end)

    case registered_nodes do
      pids when is_nil(pids) or pids == [] -> {:error, :no_node_registered}
      pids -> {:ok, pids}
    end
  end
end
