defmodule Ravix.Documents.Store do
  use GenServer
  require OK

  alias Ravix.Documents.Store.State, as: StoreState
  alias Ravix.Documents.Store.Configs
  alias Ravix.Documents.DatabaseManager
  alias Ravix.Documents.Session.State, as: SessionState
  alias Ravix.Documents.Session.SessionsSupervisor
  alias Ravix.Connection.NetworkStateManager

  @spec init(any) :: {:ok, any}
  def init(opts) do
    {:ok, opts}
  end

  @spec start_link(Configs.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%Configs{} = opts) do
    initial_state = StoreState.from_map(opts)
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, from_configs_file(), name: __MODULE__)
  end

  @spec open_session(String.t()) :: String.t()
  def open_session(database) do
    GenServer.call(__MODULE__, {:open_session, database})
  end

  @spec create_database(String.t(), maybe_improper_list()) :: {:ok, map()} | {:error, any()}
  def create_database(database, opts \\ []) do
    GenServer.call(__MODULE__, {:create_database, database, opts})
  end

  defp from_configs_file() do
    {:ok, ravix_configs} = Configs.read_from_config_file()
    StoreState.from_map(ravix_configs)
  end

  defp create_new_session(database, %StoreState{} = store_state) do
    session_id = UUID.uuid4()

    session_initial_state = %SessionState{
      session_id: session_id,
      database: database,
      conventions: store_state.document_conventions
    }

    {:ok, _} = SessionsSupervisor.create_session(session_initial_state)

    {:ok, session_id}
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:open_session, database}, _from, %StoreState{} = state) do
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

  def handle_call({:create_database, database, opts}, _from, %StoreState{} = state) do
    OK.try do
      _pid <-
        NetworkStateManager.create_network_state(
          state.urls,
          database,
          state.document_conventions,
          nil
        )

      response <- DatabaseManager.create_database(database, opts)
    after
      {:reply, {:ok, response}, state}
    rescue
      error -> {:reply, {:error, error}, state}
    end
  end
end
