defmodule Ravix.Connection do
  use GenServer

  require OK

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.ServerNode

  def init(network_state) do
    {:ok, network_state, {:continue, :schedule_next_healthcheck}}
  end

  def start_link(store, %ConnectionState{} = conn_state) do
    conn_state = put_in(conn_state.store, store)
    conn_state = ConnectionState.Manager.initialize(conn_state)

    GenServer.start_link(__MODULE__, conn_state,
      name: ConnectionState.Manager.connection_id(store)
    )
  end

  def update_topology(store) do
    ConnectionState.Manager.connection_id(store)
    |> GenServer.cast({:update_topology})
  end

  @spec fetch_state(any) :: {:ok, ConnectionState.t()} | {:error, any}
  def fetch_state(store) do
    ConnectionState.Manager.connection_id(store)
    |> GenServer.call({:fetch_state})
  end

  def handle_node_failure(store, %ServerNode{} = node) do
    ConnectionState.Manager.connection_id(store)
    |> GenServer.cast({:handle_node_failure, node})
  end

  ####################
  #     Handlers     #
  ####################
  def handle_cast(
        {:update_topology},
        _from,
        %ConnectionState{} = state
      ) do
    {:noreply, state}
  end

  def handle_cast(
        {:handle_node_failure, %ServerNode{} = _node},
        _from,
        %ConnectionState{} = state
      ) do
    {:noreply, state}
  end

  def handle_call({:fetch_state}, _from, %ConnectionState{} = state) do
    {:reply, {:ok, state}, state}
  end

  def handle_info(:nodes_healthcheck, _from, state) do
    {:noreply, state}
  end

  def handle_continue(:schedule_next_healthcheck, %ConnectionState{} = state) do
    Process.send_after(self(), :nodes_healthcheck, 5000)

    {:noreply, state}
  end
end
