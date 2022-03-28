defmodule Ravix.Documents.Session.State do
  @moduledoc """
  A session state representation

  ## Fields
  - store: The Store module for which the session belongs
  - session_id: The uuid of this session
  - database: for which database this session belongs
  - conventions: Document conventions for this session
  - documents_by_id: Loaded documents in this session
  - defer_commands: Commands that will be deferred when the session is persisted
  - deleted_entities: Documents that will be deleted when the session is persisted
  - running_queries: RQL queries running for this session
  - last_session_call: When the last session call was executed
  - number_of_requests: Number os requests that will be executed at this session persistence
  """
  defstruct store: nil,
            session_id: nil,
            database: nil,
            conventions: nil,
            documents_by_id: %{},
            defer_commands: [],
            deleted_entities: [],
            running_queries: %{},
            last_session_call: nil,
            number_of_requests: 0

  require OK

  alias Ravix.Documents.Session.State, as: SessionState
  alias Ravix.Documents.Session.Validations
  alias Ravix.Documents.Session.SessionDocument
  alias Ravix.Documents.Conventions

  @type t :: %SessionState{
          store: atom() | nil,
          session_id: bitstring(),
          database: String.t(),
          conventions: Conventions.t(),
          documents_by_id: map(),
          defer_commands: list(),
          deleted_entities: list(),
          running_queries: map(),
          last_session_call: DateTime.t() | nil,
          number_of_requests: non_neg_integer()
        }

  @doc """
  Increments the number of requests count

  ## Parameters
  - session_state: the session state

  ## Returns
  - updated session state
  """
  @spec increment_request_count(SessionState.t()) :: SessionState.t()
  def increment_request_count(%SessionState{} = session_state) do
    %SessionState{
      session_state
      | number_of_requests: session_state.number_of_requests + 1
    }
  end

  @doc """
  Updates the last session call time

  ## Parameters
  - session_state: the session state

  ## Returns
  - updated session state
  """
  @spec update_last_session_call(SessionState.t()) :: SessionState.t()
  def update_last_session_call(%SessionState{} = session_state) do
    %SessionState{
      session_state
      | last_session_call: Timex.now()
    }
  end

  @doc """
  Adds a document to the session

  ## Parameters
  - state: the session state
  - key: the key where the document will be related to
  - entity: the document to be persisted
  - change_vector: the concurrency change vector string
  - original_document: if it's a update, this is the document before the change

  ## Returns
  - `{:ok, updated_state}`
  - `{:error, :document_already_deferred}` if the document id is in a deferred command
  - `{:error, :document_deleted}` if the document is marked for delete
  - `{:error, :document_already_stored}` if the document is already in the session
  """
  def register_document(
        %SessionState{} = state,
        key,
        entity,
        change_vector,
        original_document \\ nil
      ) do
    OK.for do
      _ <- Validations.document_not_in_deferred_command(state, key)
      _ <- Validations.document_not_deleted(state, key)
      _ <- Validations.document_not_stored(state, key)
    after
      %SessionState{
        state
        | documents_by_id:
            Map.put(state.documents_by_id, key, %SessionDocument{
              entity: entity,
              key: key,
              original_value: original_document,
              change_vector: change_vector
            })
      }
    end
  end

  @doc """
  Marks a document to be deleted

  ## Parameters
  - state: the session state
  - document_id: the document id to be deleted

  ## Returns
  - `{:ok, state}`
  - `{:error, :document_already_deferred}` if the document id is in a deferred command
  - `{:error, :document_deleted}` if the document is already marked for delete
  - `{:error, :document_not_in_session}` is the document is not loaded in the session
  """
  @spec mark_document_for_exclusion(SessionState.t(), bitstring()) ::
          {:error, atom()} | {:ok, SessionState.t()}
  def mark_document_for_exclusion(
        %SessionState{} = state,
        document_id
      ) do
    OK.for do
      _ <- Validations.document_not_in_deferred_command(state, document_id)
      _ <- Validations.document_not_deleted(state, document_id)
      document <- Validations.document_in_session?(state, document_id)
    after
      {_, updated_documents} = Map.pop(state.documents_by_id, document_id)

      %SessionState{
        state
        | deleted_entities: state.deleted_entities ++ [document],
          documents_by_id: updated_documents
      }
    end
  end

  @doc """
  Updates the session with RavenDB responses

  ## Parameters
  - session_state: the session state
  - updates: List of updates to be applied to the session

  ## Returns
  - the updated session
  """
  @spec update_session(SessionState.t(), maybe_improper_list) :: SessionState.t()
  def update_session(%SessionState{} = session_state, []), do: session_state

  def update_session(%SessionState{} = session_state, updates) when is_list(updates) do
    update = Enum.at(updates, 0)

    updated_state =
      case update do
        {:ok, :update_document, document} ->
          update_document(session_state, document)

        {:ok, :delete_document, document_id} ->
          delete_document(session_state, document_id)

        {:error, :not_implemented, _action_type} ->
          session_state
      end

    remaining_updates = Enum.drop(updates, 1)

    update_session(updated_state, remaining_updates)
  end

  @doc """
  Fetches a document from the session

  ## Paremeters
  - state: the session state
  - document_id: the document id

  ## Returns
  - `{:ok, document}`
  - `{:error, :document_not_found}` if there is no document with the informed id on the session
  """
  @spec fetch_document(SessionState.t(), any) :: {:error, :document_not_found} | {:ok, map()}
  def fetch_document(_state, document_id) when document_id == nil,
    do: {:error, :document_not_found}

  def fetch_document(%SessionState{} = state, document_id) do
    case state.documents_by_id[document_id] do
      nil -> {:error, :document_not_found}
      document -> {:ok, document}
    end
  end

  @doc """
  Clear the deferred commands from the session
  """
  @spec clear_deferred_commands(SessionState.t()) :: SessionState.t()
  def clear_deferred_commands(%SessionState{} = state) do
    %SessionState{
      state
      | defer_commands: []
    }
  end

  @doc """
  Clear the deleted entities from the session
  """
  @spec clear_deleted_entities(SessionState.t()) :: SessionState.t()
  def clear_deleted_entities(%SessionState{} = state) do
    %SessionState{
      state
      | deleted_entities: []
    }
  end

  defp update_document(session_state, document) do
    %SessionState{
      session_state
      | documents_by_id: Map.put(session_state.documents_by_id, document.key, document)
    }
  end

  defp delete_document(session_state, document_id) do
    %SessionState{
      session_state
      | documents_by_id: Map.delete(session_state.documents_by_id, document_id)
    }
  end
end
