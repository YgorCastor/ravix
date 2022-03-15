defmodule Ravix.Connection.InMemoryNetworkState do
  use GenServer

  require OK

  alias Ravix.Connection.Network.State, as: NetworkState
  alias Ravix.Connection.{NetworkStateSupervisor, NetworkStateManager, NodeSelector, ServerNode}

  def init(network_state) do
    {:ok, network_state}
  end

  @spec start_link(any, map) :: {:error, any} | {:ok, pid}
  def start_link(_attrs, params) do
    GenServer.start_link(
      __MODULE__,
      NetworkState.initial_state(
        params[:urls],
        params[:database_name],
        params[:document_conventions],
        params[:certificate]
      ),
      name: NetworkStateSupervisor.network_state_for_database(params[:database_name])
    )
  end

  def update_topology(database_name) do
    database_name
    |> NetworkStateSupervisor.network_state_for_database()
    |> GenServer.cast({:update_topology})
  end

  def fetch_state(database_name) do
    database_name
    |> NetworkStateSupervisor.network_state_for_database()
    |> GenServer.call({:fetch_state})
  end

  def handle_node_failure(%ServerNode{} = node) do
    node.database
    |> NetworkStateSupervisor.network_state_for_database()
    |> GenServer.cast({:handle_node_failure, node})
  end

  ####################
  #     Handlers     #
  ####################
  def handle_cast(
        {:update_topology},
        _from,
        %NetworkState{
          database_name: database,
          certificate: cert,
          certificate_file: cert_file,
          last_known_urls: urls
        } = state
      ) do
    OK.try do
      certificates = [castore: cert, castore_file: cert_file]
      updated_topology <- NetworkStateManager.request_topology(urls, database, certificates)

      updated_state = %NetworkState{
        state
        | node_selector: %NodeSelector{
            topology: updated_topology,
            current_node_index: 0
          }
      }
    after
      {:noreply, updated_state}
    rescue
      _ -> {:noreply, state}
    end
  end

  def handle_cast({:handle_node_failure, %ServerNode{} = node}, _from, %NetworkState{} = state) do
    state_with_unhealthy_node = NetworkStateManager.set_node_as_unhealthy(node, state)

    case NetworkStateManager.change_to_next_healthy_node(state_with_unhealthy_node) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _} -> raise "Unable to fetch next healthy node!"
    end
  end

  def handle_call({:fetch_state}, _from, %NetworkState{} = state) do
    {:reply, {:ok, state}, state}
  end
end
