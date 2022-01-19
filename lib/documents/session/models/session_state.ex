defmodule Ravix.Documents.Session.State do
  defstruct session_id: nil,
            database: nil,
            conventions: nil,
            documents_by_id: %{},
            included_documents_by_id: [],
            known_missing_ids: [],
            defer_commands: [],
            deleted_entities: [],
            number_of_requests: 0

  require OK

  alias Ravix.Documents.Session.State
  alias Ravix.Documents.Conventions

  @type t :: %State{
          session_id: String.t(),
          database: String.t(),
          conventions: Conventions.t(),
          documents_by_id: map(),
          included_documents_by_id: list(String.t()),
          known_missing_ids: list(String.t()),
          defer_commands: list(%{key: any()}),
          deleted_entities: list(%{id: any()}),
          number_of_requests: non_neg_integer()
        }

  @spec increment_request_count(State.t()) :: State.t()
  def increment_request_count(session_state = %State{}) do
    %State{
      session_state
      | number_of_requests: session_state.number_of_requests + 1
    }
  end

  @spec register_document(State.t(), binary, map(), binary(), map(), map() | nil, map() | nil) ::
          {:error, any} | {:ok, State.t()}
  def register_document(
        state = %State{},
        key,
        entity,
        change_vector,
        metadata,
        original_metadata,
        original_document
      ) do
    OK.for do
      _ <- document_not_in_deferred_command(state, key)
      _ <- document_not_deleted(state, key)
      _ <- document_not_stored(state, key)
    after
      %State{
        state
        | documents_by_id:
            Map.put(state.documents_by_id, key, %{
              entity: entity,
              key: key,
              original_value: original_document,
              change_vector: change_vector,
              metadata: metadata,
              original_metadata: original_metadata
            })
      }
    end
  end

  @spec update_session(State.t(), maybe_improper_list) :: State.t()
  def update_session(session_state = %State{}, []), do: session_state

  def update_session(session_state = %State{}, updates) when is_list(updates) do
    update = Enum.at(updates, 0)

    updated_state =
      case update do
        {:ok, :update_document, document} ->
          %State{
            session_state
            | documents_by_id: Map.put(session_state.documents_by_id, document.key, document)
          }

        {:error, :not_implemented, _action_type} ->
          session_state
      end

    remaining_updates = Enum.drop(updates, 1)

    update_session(updated_state, remaining_updates)
  end

  @spec fetch_document(State.t(), any) :: map()
  def fetch_document(_state = %State{}, document_id) when document_id == nil, do: nil

  def fetch_document(state = %State{}, document_id), do: state.documents_by_id[document_id]

  @spec clear_deferred_commands(State.t()) :: State.t()
  def clear_deferred_commands(state = %State{}) do
    %State{
      state
      | defer_commands: []
    }
  end

  @spec clear_deleted_entities(State.t()) :: State.t()
  def clear_deleted_entities(state = %State{}) do
    %State{
      state
      | deleted_entities: []
    }
  end

  @spec document_not_in_deferred_command(State.t(), binary()) ::
          {:ok, binary()} | {:error, :document_already_deferred}
  defp document_not_in_deferred_command(state = %State{}, entity_id) do
    state.defer_commands
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.key == entity_id, do: {:error, :document_already_deferred}
    end)
  end

  @spec document_not_deleted(State.t(), binary()) :: {:ok, binary()} | {:error, :document_deleted}
  defp document_not_deleted(state = %State{}, entity_id) do
    state.deleted_entities
    |> Enum.find_value({:ok, entity_id}, fn elmn ->
      if elmn.id == entity_id, do: {:error, :document_deleted}
    end)
  end

  @spec document_not_stored(State.t(), binary()) ::
          {:ok, binary()} | {:error, :document_already_stored}
  defp document_not_stored(state = %State{}, entity_id) do
    case Map.has_key?(state.documents_by_id, entity_id) do
      true -> {:error, :document_already_stored}
      false -> {:ok, entity_id}
    end
  end
end
