defmodule Ravix.Documents.Session.Manager do
  @moduledoc """
  Functions to manage session changes
  """
  require OK

  alias Ravix.Documents.Session.State, as: SessionState
  alias Ravix.Documents.Session.{SaveChangesData, Validations}

  alias Ravix.Documents.Commands.{
    BatchCommand,
    GetDocumentsCommand,
    ExecuteQueryCommand,
    ExecuteStreamQueryCommand
  }

  alias Ravix.Documents.Metadata
  alias Ravix.Connection
  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.RequestExecutor
  alias Ravix.RQL.Query
  alias Ravix.Telemetry

  @spec load_documents(SessionState.t(), list, any, any) ::
          {:error, any} | {:ok, [{any, any}, ...]}
  def load_documents(%SessionState{} = state, document_ids, includes, nil),
    do: load_documents(state, document_ids, includes, [])

  def load_documents(%SessionState{} = state, document_ids, includes, opts) do
    OK.try do
      _ <- Validations.load_documents_limit_reached(state, document_ids)
      already_loaded_ids = fetch_loaded_documents(state, document_ids)
      ids_to_load <- Validations.all_ids_are_not_already_loaded(document_ids, already_loaded_ids)
      network_state <- Connection.fetch_state(state.store)
      response <- execute_load_request(network_state, ids_to_load, includes, opts)
      parsed_response = GetDocumentsCommand.parse_response(state, response)
      updated_state = SessionState.update_session(state, parsed_response[:results])
      updated_state = SessionState.update_session(updated_state, parsed_response[:includes])
      updated_state = SessionState.update_last_session_call(updated_state)
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

  @spec store_entity(SessionState.t(), map, any, String.t(), keyword()) ::
          {:error, any} | {:ok, [...]}
  def store_entity(%SessionState{} = state, entity, key, change_vector, opts)
      when is_struct(entity) do
    entity
    |> do_store_entity(key, change_vector, state, opts)
  end

  def store_entity(%SessionState{} = state, entity, key, change_vector, opts)
      when is_map(entity) do
    entity
    |> Morphix.atomorphiform!()
    |> do_store_entity(key, change_vector, state, opts)
  end

  defp do_store_entity(entity, key, change_vector, %SessionState{} = state, opts) do
    OK.try do
      _ <- Validations.session_request_limit_reached(state)

      _ <-
        case Keyword.get(opts, :upsert, true) do
          false -> Validations.document_not_stored(state, key)
          true -> {:ok, nil}
        end

      change_vector =
        case state.conventions.use_optimistic_concurrency do
          true -> change_vector
          false -> nil
        end

      local_key <- ensure_key(key)
      metadata = Metadata.build_default_metadata(entity)
      entity = Metadata.add_metadata(entity, metadata)
      original_document = Map.get(state.documents_by_id, local_key)

      updated_state <-
        state
        |> SessionState.increment_request_count()
        |> SessionState.update_last_session_call()
        |> SessionState.register_document(local_key, entity, change_vector, original_document)
    after
      {:ok, [entity, updated_state]}
    rescue
      err -> {:error, err}
    end
  end

  @spec save_changes(SessionState.t()) :: {:error, any} | {:ok, keyword()}
  def save_changes(%SessionState{} = state) do
    OK.for do
      network_state <- Connection.fetch_state(state.store)
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

  @spec delete_document(SessionState.t(), bitstring()) ::
          {:error, atom()} | {:ok, SessionState.t()}
  def delete_document(%SessionState{} = state, document_id) do
    OK.for do
      updated_state <-
        state
        |> SessionState.increment_request_count()
        |> SessionState.update_last_session_call()
        |> SessionState.mark_document_for_exclusion(document_id)
    after
      updated_state
    end
  end

  @spec execute_query(SessionState.t(), Query.t(), any) ::
          {:error, any} | {:ok, Connection.Response.t()}
  def execute_query(%SessionState{} = session_state, %Query{} = query, method) do
    OK.for do
      network_state <- Connection.fetch_state(session_state.store)

      command = %ExecuteQueryCommand{
        Query: query.query_string,
        QueryParameters: query.query_params,
        method: method
      }

      result <- RequestExecutor.execute(command, network_state)
    after
      result
    end
  end

  @spec stream_query(SessionState.t(), Query.t(), any) :: {:error, any} | {:ok, Enumerable.t()}
  def stream_query(%SessionState{} = session_state, %Query{} = query, "GET") do
    OK.for do
      network_state <- Connection.fetch_state(session_state.store)

      command = %ExecuteStreamQueryCommand{
        Query: query.query_string,
        QueryParameters: query.query_params,
        method: :get,
        is_stream: true
      }

      stream <- RequestExecutor.execute(command, network_state)
    after
      stream
    end
  end

  defp fetch_loaded_documents(%SessionState{} = state, document_ids) do
    document_ids
    |> Enum.map(fn id ->
      case Validations.document_not_stored(state, id) do
        {:ok, _} -> nil
        {:error, {:document_already_stored, stored_document}} -> stored_document.key
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp execute_load_request(%ConnectionState{} = network_state, ids, includes, opts)
       when is_list(ids) do
    start = Keyword.get(opts, :start)
    page_size = Keyword.get(opts, :page_size)
    metadata_only = Keyword.get(opts, :metadata_only)

    case RequestExecutor.execute(
           %GetDocumentsCommand{
             ids: ids,
             includes: includes,
             start: start,
             page_size: page_size,
             metadata_only: metadata_only
           },
           network_state
         ) do
      {:ok, response} -> {:ok, response}
      {:error, err} -> {:error, err}
    end
  end

  defp execute_save_request(%SessionState{} = state, %ConnectionState{} = network_state) do
    OK.for do
      data_to_save =
        %SaveChangesData{}
        |> SaveChangesData.add_deferred_commands(state.defer_commands)
        |> SaveChangesData.add_delete_commands(state.deleted_entities)
        |> SaveChangesData.add_put_commands(state.documents_by_id)

      response <-
        %BatchCommand{Commands: data_to_save.commands}
        |> RequestExecutor.execute(network_state)

      updated_state =
        state
        |> SessionState.update_last_session_call()
        |> SessionState.clear_deferred_commands()
        |> SessionState.clear_deleted_entities()
        |> SessionState.clear_tmp_keys()
    after
      [request_response: response, updated_state: updated_state]
    end
  end

  defp ensure_key(nil), do: {:error, :no_valid_id_informed}

  defp ensure_key(key) when is_bitstring(key) do
    key =
      case String.last(key) do
        "/" -> "tmp_" <> key <> UUID.uuid4()
        "|" -> "tmp_" <> key <> UUID.uuid4()
        _ -> key
      end

    {:ok, key}
  end

  defp ensure_key(key), do: {:ok, key}
end
