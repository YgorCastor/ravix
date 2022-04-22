defmodule Ravix.Documents.Session.Validations do
  @moduledoc """
  Validation rules for session states
  """
  alias Ravix.Documents.Session.State, as: SessionState

  @doc """
  Returns an error if the document is in a deferred command
  """
  @spec document_not_in_deferred_command(SessionState.t(), binary()) ::
          {:ok, binary()} | {:error, :document_already_deferred}
  def document_not_in_deferred_command(%SessionState{} = state, entity_id) do
    state.defer_commands
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.key == entity_id, do: {:error, :document_already_deferred}
    end)
  end

  @doc """
  Returns an error if the document is already marked for deletion
  """
  @spec document_not_deleted(SessionState.t(), binary()) ::
          {:ok, binary()} | {:error, :document_deleted}
  def document_not_deleted(%SessionState{} = state, entity_id) do
    state.deleted_entities
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.key == entity_id, do: {:error, :document_deleted}
    end)
  end

  @doc """
  Returns an error if the document is already stored in the session
  """
  @spec document_not_stored(SessionState.t(), binary()) ::
          {:error, {:document_already_stored, map()}} | {:ok, map()}
  def document_not_stored(%SessionState{} = state, entity_id) do
    case Map.get(state.documents_by_id, entity_id) do
      nil -> {:ok, entity_id}
      document -> {:error, {:document_already_stored, document}}
    end
  end

  @doc """
  Return an error if the document is not in the session
  """
  @spec document_in_session?(SessionState.t(), any) ::
          {:error, :document_not_in_session} | {:ok, map}
  def document_in_session?(%SessionState{} = state, entity_id) do
    case Map.get(state.documents_by_id, entity_id) do
      nil -> {:error, :document_not_in_session}
      document -> {:ok, document}
    end
  end

  @doc """
  Returns an error if all the informed ids are already loaded in the session
  """
  @spec all_ids_are_not_already_loaded(list, list) ::
          {:error, :all_ids_already_loaded} | {:ok, [...]}
  def all_ids_are_not_already_loaded(document_ids, already_loaded_ids) do
    case document_ids -- already_loaded_ids do
      [] -> {:error, :all_ids_already_loaded}
      ids_to_load -> {:ok, ids_to_load}
    end
  end

  @spec session_request_limit_reached(SessionState.t()) ::
          {:error, :max_amount_of_requests_reached} | {:ok, -1}
  def session_request_limit_reached(%SessionState{} = state) do
    case state.number_of_requests + 1 > state.conventions.max_number_of_requests_per_session do
      false -> {:ok, -1}
      true -> {:error, :max_amount_of_requests_reached}
    end
  end

  @spec load_documents_limit_reached(SessionState.t(), list) ::
          {:error, :max_amount_of_ids_reached} | {:ok, -1}
  def load_documents_limit_reached(%SessionState{} = state, document_ids) do
    case (Map.keys(state.documents_by_id) |> length) + length(document_ids) >
           state.conventions.max_ids_to_catch do
      false -> {:ok, -1}
      true -> {:error, :max_amount_of_ids_reached}
    end
  end
end
