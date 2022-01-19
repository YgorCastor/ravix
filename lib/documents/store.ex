defmodule Ravix.Documents.Store do
  use GenServer

  alias Ravix.Documents.Store
  alias Ravix.Documents.Session
  alias Ravix.Documents.Session.SessionsManager
  alias Ravix.Connection.NetworkStateManager

  def init(attr) do
    {:ok, attr}
  end

  def start_link(_attrs) do
    GenServer.start_link(__MODULE__, initial_state(), name: __MODULE__)
  end

  def open_session(database) do
    GenServer.call(__MODULE__, {:open_session, database})
  end

  defp initial_state() do
    {:ok, ravix_configs} = Store.Configs.read_configs()

    Store.State.from_config(ravix_configs)
  end

  defp create_new_session(database, store_state = %Store.State{}) do
    session_id = UUID.uuid4()

    session_initial_state = %Session.State{
      session_id: session_id,
      database: database,
      conventions: store_state.document_conventions
    }

    {:ok, _} = SessionsManager.create_session(session_initial_state)

    {:ok, session_id}
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:open_session, database}, _from, state = %Store.State{}) do
    session_id = create_new_session(database, state)

    {:ok, _pid} =
      NetworkStateManager.create_network_state(
        state.urls,
        database,
        state.document_conventions,
        nil
      )

    {:reply, session_id, state}
  end
end
