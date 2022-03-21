defmodule Ravix.Connection do
  use GenServer

  require OK

  alias Ravix.Connection.State, as: ConnectionState

  def init(network_state) do
    {:ok, network_state}
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

  def handle_call({:fetch_state}, _from, %ConnectionState{} = state) do
    {:reply, {:ok, state}, state}
  end
end
