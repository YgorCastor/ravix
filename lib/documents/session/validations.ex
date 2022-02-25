defmodule Ravix.Documents.Session.Validations do
  alias Ravix.Documents.Session.State
  alias Ravix.Documents.Session.SessionDocument

  @spec document_not_in_deferred_command(State.t(), binary()) ::
          {:ok, binary()} | {:error, :document_already_deferred}
  def document_not_in_deferred_command(%State{} = state, entity_id) do
    state.defer_commands
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.key == entity_id, do: {:error, :document_already_deferred}
    end)
  end

  @spec document_not_deleted(State.t(), binary()) :: {:ok, binary()} | {:error, :document_deleted}
  def document_not_deleted(%State{} = state, entity_id) do
    state.deleted_entities
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.id == entity_id, do: {:error, :document_deleted}
    end)
  end

  @spec document_not_stored(State.t(), binary()) ::
          {:error, {:document_already_stored, map()}} | {:ok, map()}
  def document_not_stored(%State{} = state, entity_id) do
    case Map.get(state.documents_by_id, entity_id) do
      nil -> {:ok, entity_id}
      document -> {:error, {:document_already_stored, SessionDocument.merge_entity(document)}}
    end
  end

  @spec document_in_session?(State.t(), any) :: {:error, :document_not_in_session} | {:ok, map}
  def document_in_session?(%State{} = state, entity_id) do
    case Map.get(state.documents_by_id, entity_id) do
      nil -> {:error, :document_not_in_session}
      document -> {:ok, SessionDocument.merge_entity(document)}
    end
  end

  @spec all_ids_are_not_already_loaded(list, list) ::
          {:error, :all_ids_already_loaded} | {:ok, [...]}
  def all_ids_are_not_already_loaded(document_ids, already_loaded_ids) do
    case document_ids -- already_loaded_ids do
      [] -> {:error, :all_ids_already_loaded}
      ids_to_load -> {:ok, ids_to_load}
    end
  end
end
