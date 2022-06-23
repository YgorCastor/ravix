defmodule Ravix.Connection.State.Manager do
  @moduledoc false
  require OK
  require Logger

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.{ServerNode, RequestExecutor, Topology, NodeSelector}
  alias Ravix.Connection.Commands.GetTopology
  alias Ravix.Connection.RequestExecutor.Supervisor, as: ExecutorSupervisor
  alias Ravix.Operations.Database.Maintenance, as: DatabaseMaintenance

  @doc """
  Initializes a Store Connection

  First it register the nodes executors for the connection, then it pools
  the RavenDB asking for a topology update.

  Returns `Ravix.Connection.State`

  Raises if it's unable to register at least one node and if the topology is invalid
  """
  @spec initialize(ConnectionState.t()) :: ConnectionState.t()
  def initialize(%ConnectionState{} = state) do
    Logger.info("[RAVIX] Initializing connection for the repository '#{inspect(state.store)}'")

    OK.try do
      pools <- register_node_pools(state)

      Logger.info(
        "[RAVIX] '#{length(pools)}' Node pools were registered successfully for the repository '#{inspect(state.store)}'"
      )

      _ =
        case state.force_create_database do
          true ->
            Logger.info(
              "[RAVIX] Forcing the database creation is enabled, it will create the #{inspect(state.database)} if it does not exists"
            )

            NodeSelector.random_node_for(state.store)
            |> DatabaseMaintenance.create_database(state.database)

          false ->
            :ok
        end

      state = put_in(state.node_selector, NodeSelector.new())
      state <- __MODULE__.update_topology(state)
    after
      Logger.info("[RAVIX] Connection stabilished for the Store '#{inspect(state.store)}'")
      state
    rescue
      :invalid_cluster_topology -> raise "Unable to fetch the cluster topology"
      :no_node_registered -> raise "No nodes were registered successfully"
    end
  end

  @doc """
     Updates the topology for the informed connection state.

     Returns:
      - `{:ok, Ravix.Connection.State}` with the topology updated
      - `{:error, cause}` if it was unable to update the topology
  """
  @spec update_topology(ConnectionState.t()) :: {:error, any} | {:ok, ConnectionState.t()}
  def update_topology(%ConnectionState{} = state) do
    OK.for do
      Logger.debug("[RAVIX] Updating the topology for the store '#{inspect(state.store)}'")
      random_node = NodeSelector.random_node_for(state.store)
      topology <- __MODULE__.request_topology(random_node, state.database)
      _ = ExecutorSupervisor.update_topology(state.store, topology)

      state = put_in(state.topology_etag, topology.etag)
      state = put_in(state.node_selector, NodeSelector.new())
      state = put_in(state.last_topology_update, Timex.now())
    after
      Logger.debug(
        "[RAVIX] Topology for the store '#{inspect(state.store)}' was updated successfully"
      )

      state
    end
  end

  @doc """
    Request the topology for the informed database store, receives a list of the Executors PIDs and the database name.

    Returns:
     - `{:ok, Ravix.Connection.Topology}` if the topology request was successful
     - `{:error, :invalid_cluster_topology}` if it fails to pool the topology
  """
  @spec request_topology(pid(), String.t()) ::
          {:error, :invalid_cluster_topology} | {:ok, Ravix.Connection.Topology.t()}
  def request_topology(node_pid, database) do
    Logger.debug(
      "[RAVIX] Requesting the cluster topology for the database '#{inspect(database)}'"
    )

    case RequestExecutor.execute_with_node(%GetTopology{database_name: database}, node_pid) do
      {:ok, response} ->
        topology = %Topology{
          etag: response.data["Etag"],
          nodes: response.data["Nodes"] |> Enum.map(&ServerNode.from_api_response/1)
        }

        Logger.info(
          "[RAVIX] The topology for the database '#{inspect(database)}' has the etag '#{inspect(topology.etag)}'"
        )

        {:ok, topology}

      err ->
        Logger.error(
          "[RAVIX] Failed to request the topology for the database '#{inspect(database)}, cause: #{inspect(err)}'"
        )

        {:error, :invalid_cluster_topology}
    end
  end

  @doc """
   Helper method to wrap the Ravix.Store into it's connection identifier
  """
  @spec connection_id(atom()) :: {:via, Registry, {:connections, atom()}}
  def connection_id(state), do: {:via, Registry, {:connections, state}}

  defp register_node_pools(%ConnectionState{} = state) do
    registered_node_pools =
      state.urls
      |> Enum.map(&ServerNode.from_url(&1, state))
      |> Enum.map(&RequestExecutor.Supervisor.register_node_pool(state.store, &1))
      |> Enum.filter(fn pid -> elem(pid, 0) == :ok end)
      |> Enum.map(fn pid -> elem(pid, 1) end)

    case registered_node_pools do
      nodes when is_nil(nodes) or nodes == [] -> {:error, :no_node_registered}
      nodes -> {:ok, nodes}
    end
  end
end
