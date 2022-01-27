defmodule Ravix.Documents.Session do
  use GenServer

  require OK

  alias Ravix.Documents.Session
  alias Ravix.Documents.Session.SaveChangesData
  alias Ravix.Documents.Session.Validations
  alias Ravix.Documents.Commands.{BatchCommand, GetDocumentsCommand}
  alias Ravix.Documents.Conventions
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

  @spec load(binary, binary() | list(binary()), list() | nil) :: any
  def load(session_id, ids, includes \\ nil)
  def load(_session_id, nil, _includes), do: {:error, :document_ids_not_informed}

  def load(session_id, ids, includes) when is_list(ids) do
    session_id
    |> session_id()
    |> GenServer.call({:load, [document_ids: ids, includes: includes]})
  end

  def load(session_id, id, includes) do
    session_id
    |> session_id()
    |> GenServer.call({:load, [document_ids: [id], includes: includes]})
  end

  def delete(session_id, entity) when is_map_key(entity, "id") do
    delete(session_id, entity.id)
  end

  def delete(session_id, id) when is_binary(id) do
    session_id
    |> session_id()
    |> GenServer.call({:delete, id})
  end

  @spec store(binary(), map(), binary() | nil, binary() | nil) :: any
  def store(session_id, entity, key \\ nil, change_vector \\ nil)

  def store(_session_id, entity, _key, _change_vector) when entity == nil,
    do: {:error, :null_entity}

  def store(session_id, entity, key, change_vector) do
    session_id
    |> session_id()
    |> GenServer.call({:store, [entity: entity, key: key, change_vector: change_vector]})
  end

  @spec save_changes(binary) :: any
  def save_changes(session_id) do
    session_id
    |> session_id()
    |> GenServer.call({:save_changes})
  end

  defp do_load_documents(state = %Session.State{}, document_ids, includes) do
    OK.try do
      already_loaded_ids = fetch_loaded_documents(state, document_ids)
      ids_to_load <- Validations.all_ids_are_not_already_loaded(document_ids, already_loaded_ids)
      {pid, _} <- NetworkStateManager.find_existing_network(state.database)
      network_state = Agent.get(pid, fn ns -> ns end)
      response <- execute_load_request(network_state, ids_to_load, includes)
      parsed_response = GetDocumentsCommand.parse_response(state, response)
      updated_state = Session.State.update_session(state, parsed_response[:results])
      updated_state = Session.State.update_session(updated_state, parsed_response[:includes])
    after
      {:ok,
       [
         response: Map.put(response, "already_loaded_ids", already_loaded_ids),
         updated_state: updated_state
       ]}
    rescue
      :all_ids_already_loaded ->
        {:ok,
         [
           response:
             Map.new()
             |> Map.put("Results", [])
             |> Map.put("Includes", [])
             |> Map.put("already_loaded_ids", document_ids),
           updated_state: state
         ]}
    end
  end

  defp fetch_loaded_documents(state = %Session.State{}, document_ids) do
    document_ids
    |> Enum.map(fn id ->
      with {:ok, _} <- Validations.document_not_stored(state, id) do
        nil
      else
        {:error, {:document_already_stored, stored_document}} ->
          stored_document["@metadata"]["@id"]
      end
    end)
    |> Enum.reject(fn item -> item == nil end)
  end

  defp execute_load_request(network_state = %Network.State{}, ids, includes) when is_list(ids) do
    OK.try do
      response <-
        %GetDocumentsCommand{ids: ids, includes: includes}
        |> RequestExecutor.execute(network_state)

      decoded_response <- Jason.decode(response.data)
    after
      {:ok, decoded_response}
    rescue
      err -> err
    end
  end

  defp do_store_entity(state = %Session.State{}, entity, key, change_vector) do
    OK.try do
      metadata = Conventions.build_default_metadata(entity)

      updated_state <-
        Session.State.register_document(state, key, entity, change_vector, metadata, %{}, nil)
    after
      {:reply, {:ok, entity}, updated_state}
    rescue
      err -> {:reply, {:error, err}, state}
    end
  end

  defp do_save_changes(state = %Session.State{}) do
    OK.for do
      {pid, _} <- NetworkStateManager.find_existing_network(state.database)
      network_state = Agent.get(pid, fn ns -> ns end)
      result <- execute_save_request(state, network_state)
    after
      {:ok, result}
    end
  end

  defp execute_save_request(state = %Session.State{}, network_state = %Network.State{}) do
    OK.for do
      data_to_save =
        %SaveChangesData{}
        |> SaveChangesData.add_deferred_commands(state.defer_commands)
        |> SaveChangesData.add_delete_commands(state.deleted_entities)
        |> SaveChangesData.add_put_commands(state.documents_by_id)

      response <-
        %BatchCommand{Commands: data_to_save.commands}
        |> RequestExecutor.execute(network_state)

      parsed_response <- Jason.decode(response.data)

      updated_state =
        state
        |> Session.State.increment_request_count()
        |> Session.State.clear_deferred_commands()
        |> Session.State.clear_deleted_entities()
    after
      [request_response: parsed_response, updated_state: updated_state]
    end
  end

  @spec session_id(String.t()) :: {:via, Registry, {:sessions, String.t()}}
  defp session_id(id) when id != nil, do: {:via, Registry, {:sessions, id}}

  ####################
  #     Handlers     #
  ####################
  def handle_call(
        {:load, [document_ids: ids, includes: includes]},
        _from,
        state = %Session.State{}
      ) do
    OK.try do
      result <- do_load_documents(state, ids, includes)
    after
      {:reply, {:ok, result[:response]}, result[:updated_state]}
    rescue
      err -> {:reply, err, state}
    end
  end

  def handle_call(
        {:store, [entity: entity, key: key, change_vector: change_vector]},
        _from,
        state = %Session.State{}
      )
      when key != nil,
      do: do_store_entity(state, entity, key, change_vector)

  def handle_call(
        {:store, [entity: entity, key: _, change_vector: change_vector]},
        _from,
        state = %Session.State{}
      )
      when entity.id != nil,
      do: do_store_entity(state, entity, entity.id, change_vector)

  def handle_call(
        {:store, [entity: _, key: _, change_vector: _]},
        _from,
        state = %Session.State{}
      ),
      do: {:reply, {:error, :no_valid_id_informed}, state}

  def handle_call({:fetch_state}, _from, state = %Session.State{}),
    do: {:reply, {:ok, state}, state}

  def handle_call({:save_changes}, _from, state = %Session.State{}) do
    OK.try do
      [request_response: response, updated_state: updated_state] <-
        do_save_changes(state)

      parsed_updates = BatchCommand.parse_batch_response(response["Results"], updated_state)

      updated_session = Session.State.update_session(updated_state, parsed_updates)
    after
      {:reply, {:ok, response}, updated_session}
    rescue
      err -> err
    end
  end
end
