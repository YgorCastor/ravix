defmodule Ravix.Documents.Session.SessionManager do
  require OK

  alias Ravix.Documents.Session
  alias Ravix.Documents.Session.SaveChangesData
  alias Ravix.Documents.Session.Validations
  alias Ravix.Documents.Commands.{BatchCommand, GetDocumentsCommand}
  alias Ravix.Documents.Conventions
  alias Ravix.Connection.Network
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Connection.RequestExecutor

  @spec load_documents(Session.State.t(), list, any) :: {:ok, [{any, any}, ...]}
  def load_documents(state = %Session.State{}, document_ids, includes) do
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

      err ->
        {:error, err}
    end
  end

  @spec store_entity(Session.State.t(), map, binary, binary) ::
          {:reply, {:error, any} | {:ok, map}, Session.State.t()}
  def store_entity(state = %Session.State{}, entity, key, change_vector) do
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

  @spec save_changes(Session.State.t()) :: {:error, any} | {:ok, any}
  def save_changes(state = %Session.State{}) do
    OK.for do
      {pid, _} <- NetworkStateManager.find_existing_network(state.database)
      network_state = Agent.get(pid, fn ns -> ns end)
      result <- execute_save_request(state, network_state)

      parsed_updates =
        BatchCommand.parse_batch_response(
          result[:request_response]["Results"],
          result[:updated_state]
        )

      updated_session =
        Session.State.update_session(
          result[:updated_state],
          parsed_updates
        )
    after
      {:ok, [result: result[:request_response], updated_state: updated_session]}
    end
  end

  @spec delete_document(Session.State.t(), binary) :: {:error, any} | {:ok, any}
  def delete_document(state = %Session.State{}, document_id) do
    OK.for do
      updated_state <- Session.State.mark_document_for_exclusion(state, document_id)
    after
      updated_state
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
      err -> {:error, err}
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
end
