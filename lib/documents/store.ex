defmodule Ravix.Documents.Store do
  use GenServer

  alias Ravix.Documents.Store.{State, Configs}
  alias Ravix.Documents.Conventions
  alias Ravix.Documents.Session

  def init(attr) do
    {:ok, attr}
  end

  def start_link(_attrs) do
    GenServer.start_link(__MODULE__, initial_state(), name: __MODULE__)
  end

  @spec open_session(any, any) :: any
  def open_session(database, request_executor) when request_executor != nil do
    GenServer.call(__MODULE__, {:open_session, [database | request_executor]})
  end

  defp initial_state() do
    {:ok, ravix_configs} = Configs.read_configs()

    %State{
      urls: ravix_configs.urls,
      default_database: ravix_configs.database,
      document_conventions: %Conventions{
        max_number_of_requests_per_session:
          ravix_configs.document_conventions.max_number_of_requests_per_session,
        max_ids_to_catch: ravix_configs.document_conventions.max_ids_to_catch,
        timeout: ravix_configs.document_conventions.timeout,
        use_optimistic_concurrency: ravix_configs.document_conventions.use_optimistic_concurrency,
        max_length_of_query_using_get_url:
          ravix_configs.document_conventions.max_length_of_query_using_get_url,
        identity_parts_separator: ravix_configs.document_conventions.identity_parts_separator,
        disable_topology_update: ravix_configs.document_conventions.disable_topology_update
      }
    }
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:open_session, [database | request_executor]}, _from, state = %State{}) do
    session_id = UUID.uuid4()

    session_initial_state = %Session.State{
      session_id: session_id,
      database: database,
      request_executor: request_executor
    }

    {:ok, _} = Session.Supervisor.create_supervised_session(session_initial_state)

    {:reply, {:ok, session_id}, state}
  end
end
