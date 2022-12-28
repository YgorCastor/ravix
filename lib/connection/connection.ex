defmodule Ravix.Connection do
  @moduledoc false
  use GenServer

  require OK

  alias Ravix.Connection.State, as: ConnectionState

  def init(network_state) do
    {:ok, network_state}
  end

  @doc """
    Receives the reference of a  RavenDB store and a initial store state and starts a connection, the connection
  is registered in the :connections register under the naming StoreModule.Connection

  Returns:
    `{:ok, pid}` if the connection is started
    `{:error, cause}` if the connection start failed
  """
  @spec start_link(atom(), ConnectionState.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(store, %ConnectionState{} = conn_state) do
    conn_state = put_in(conn_state.store, store)
    conn_state = ConnectionState.Manager.initialize(conn_state)

    GenServer.start_link(__MODULE__, conn_state,
      name: ConnectionState.Manager.connection_id(store)
    )
  end

  @doc """
    Fetches the connection state for the specified Ravix.Document.Store

    Returns:
      - `{:ok, Ravix.Connection.State}` if the connection exists
      - `{:error, :connection_not_found` if the connection does not exists
  """
  @spec fetch_state(atom()) :: {:error, :connection_not_found} | {:ok, ConnectionState.t()}
  def fetch_state(store) do
    try do
      {:ok,
       ConnectionState.Manager.connection_id(store)
       |> :sys.get_state()}
    catch
      :exit, _ -> {:error, :connection_not_found}
    end
  end

  @doc """
    Triggers a topology update for the specified Ravix.Document.Store, this operation
    is asynchronous and will be done on background

    Returns `:ok`
  """
  @spec update_topology(atom) :: :ok
  def update_topology(store) do
    store
    |> ConnectionState.Manager.connection_id()
    |> GenServer.cast(:update_topology)
  end

  ####################
  #     Handlers     #
  ####################
  def handle_cast(:update_topology, %ConnectionState{} = state) do
    case ConnectionState.Manager.update_topology(state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      _ -> {:noreply, state}
    end
  end
end
