defmodule Ravix.Connection do
  use GenServer

  require OK

  alias Ravix.Connection.State, as: ConnectionState

  def init(network_state) do
    {:ok, network_state}
  end

  @spec start_link(atom(), ConnectionState.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store, %ConnectionState{} = conn_state) do
    conn_state = put_in(conn_state.store, store)
    conn_state = ConnectionState.Manager.initialize(conn_state)

    GenServer.start_link(__MODULE__, conn_state,
      name: ConnectionState.Manager.connection_id(store)
    )
  end

  @spec fetch_state(atom()) :: ConnectionState.t()
  def fetch_state(store) do
    state =
      ConnectionState.Manager.connection_id(store)
      |> :sys.get_state()

    state
  end
end
