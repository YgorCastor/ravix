defmodule Ravix.Documents.Session do
  use GenServer

  require OK

  alias Ravix.Documents.Session
  alias Ravix.Documents.Session.SaveChangesData
  alias Ravix.Documents.Commands.BatchCommand
  alias Ravix.Connection.Network
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Connection.RequestExecutor

  def init(session_state) do
    {:ok, session_state}
  end

  @spec start_link(any, Session.State.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_attr, initial_state = %Session.State{}) do
    GenServer.start_link(
      __MODULE__,
      initial_state,
      name: session_id(initial_state.session_id)
    )
  end

  @spec fetch_state(binary()) :: Session.State.t()
  def fetch_state(session_id) do
    session_id
    |> session_id()
    |> GenServer.call({:fetch_state})
  end

  @spec load(binary(), any()) :: any()
  def load(session_id, id) do
    session_id
    |> session_id()
    |> GenServer.call({:load, id})
  end

  @spec store(binary(), any(), binary() | nil) :: {:ok, any()} | {:error, atom()}
  def store(session_id, entity, key \\ nil)

  def store(_session_id, entity, _key) when entity == nil, do: {:error, :null_entity}

  def store(session_id, entity, key) do
    session_id
    |> session_id()
    |> GenServer.call({:store, [entity | key]})
  end

  def save_changes(session_id) do
    session_id
    |> session_id()
    |> GenServer.call({:save_changes})
  end

  @spec session_id(String.t()) :: {:via, Registry, {:sessions, String.t()}}
  defp session_id(id), do: {:via, Registry, {:sessions, id}}

  @spec do_store_entity(State.t(), any, binary) ::
          {:reply, {:error, atom} | {:ok, any}, State.t()}
  defp do_store_entity(state = %Session.State{}, entity, key) do
    OK.try do
      updated_state <- Session.State.register_document(state, key, entity)
    after
      {:reply, {:ok, entity}, updated_state}
    rescue
      err -> {:reply, {:error, err}, state}
    end
  end

  defp do_save_changes(state = %Session.State{}, network_state = %Network.State{}) do
    data_to_save =
      %SaveChangesData{}
      |> SaveChangesData.add_deferred_commands(state.defer_commands)
      |> SaveChangesData.add_delete_commands(state.deleted_entities)
      |> SaveChangesData.add_put_commands(state.documents_by_id)

    updated_state =
      state
      |> Session.State.clear_deferred_commands()
      |> Session.State.clear_deleted_entities()
      |> Session.State.clear_documents()

    response =
      %BatchCommand{Commands: data_to_save.commands} |> RequestExecutor.execute(network_state)

    [request_response: response, updated_state: updated_state]
  end

  ####################
  #     Handlers     #
  ####################
  def handle_call({:store, [entity | key]}, _from, state = %Session.State{}) when key != nil,
    do: do_store_entity(state, entity, key)

  def handle_call({:store, [entity | _key]}, _from, state = %Session.State{})
      when entity.id != nil,
      do: do_store_entity(state, entity, entity.id)

  def handle_call({:store, [_entity | _key]}, _from, state = %Session.State{}),
    do: {:reply, {:error, :no_valid_id_informed}, state}

  def handle_call({:fetch_state}, _from, state = %Session.State{}),
    do: {:reply, {:ok, state}, state}

  def handle_call({:save_changes}, _from, state = %Session.State{}) do
    {_, result} =
      OK.for do
        {pid, _} <- NetworkStateManager.find_existing_network(state.database)
        network_state = Agent.get(pid, fn ns -> ns end)
        result = do_save_changes(state, network_state)
      after
        case result[:request_response] do
          {:ok, request_response} -> {:reply, {:ok, request_response}, result[:updated_state]}
          {:error, error} -> {:reply, {:error, error}, result[:updated_state]}
        end
      end

    result
  end
end
