defmodule Ravix.Documents.Session.SessionManager do
  require OK

  alias Ravix.Documents.Session.State, as: SessionState
  alias Ravix.Documents.Session.{SaveChangesData, Validations}
  alias Ravix.Documents.Commands.{BatchCommand, GetDocumentsCommand}
  alias Ravix.Documents.Conventions
  alias Ravix.Connection.Network.State, as: NetworkState
  alias Ravix.Connection.NetworkStateManager
  alias Ravix.Connection.RequestExecutor

  @spec load_documents(SessionState.t(), list, any) :: {:ok, [{any, any}, ...]}
  def load_documents(%SessionState{} = state, document_ids, includes) do
    OK.try do
      already_loaded_ids = fetch_loaded_documents(state, document_ids)
      ids_to_load <- Validations.all_ids_are_not_already_loaded(document_ids, already_loaded_ids)
      {pid, _} <- NetworkStateManager.find_existing_network(state.database)
      network_state = Agent.get(pid, fn ns -> ns end)
      response <- execute_load_request(network_state, ids_to_load, includes)
      parsed_response = GetDocumentsCommand.parse_response(state, response)
      updated_state = SessionState.update_session(state, parsed_response[:results])
      updated_state = SessionState.update_session(updated_state, parsed_response[:includes])
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

  @spec store_entity(SessionState.t(), map(), binary(), binary()) :: {:error, any} | {:ok, [...]}
  def store_entity(%SessionState{} = state, entity, key, change_vector) do
    OK.try do
      metadata = Conventions.build_default_metadata(entity)

      updated_state <-
        SessionState.register_document(state, key, entity, change_vector, metadata, %{}, nil)
    after
      {:ok, [entity, updated_state]}
    rescue
      err -> {:error, err}
    end
  end

  @spec save_changes(SessionState.t()) :: {:error, any} | {:ok, any}
  def save_changes(%SessionState{} = state) do
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
        SessionState.update_session(
          result[:updated_state],
          parsed_updates
        )
    after
      {:ok, [result: result[:request_response], updated_state: updated_session]}
    end
  end

  @spec delete_document(SessionState.t(), binary) :: {:error, atom()} | {:ok, SessionState.t()}
  def delete_document(%SessionState{} = state, document_id) do
    OK.for do
      updated_state <- SessionState.mark_document_for_exclusion(state, document_id)
    after
      updated_state
    end
  end

  defp fetch_loaded_documents(%SessionState{} = state, document_ids) do
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

  defp execute_load_request(%NetworkState{} = network_state, ids, includes) when is_list(ids) do
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

  defp execute_save_request(%SessionState{} = state, %NetworkState{} = network_state) do
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
        |> SessionState.increment_request_count()
        |> SessionState.clear_deferred_commands()
        |> SessionState.clear_deleted_entities()
    after
      [request_response: parsed_response, updated_state: updated_state]
    end
  end
end
