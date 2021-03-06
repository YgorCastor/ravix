defmodule Ravix.Documents.Session.SessionDocument do
  @moduledoc """
  Representation of a document inside the Store Session

  ## Fields
  - entity: The document itself
  - key: The document key identity
  - original_value: the document value as it is in the database
  - change_vector: The change_vector string to deal with cluster concurrency
  """
  defstruct entity: nil,
            key: nil,
            metadata: %{},
            original_value: nil,
            change_vector: ""

  alias Ravix.Documents.Session.{State, SessionDocument}
  alias Ravix.Documents.Metadata

  @type t :: %SessionDocument{
          entity: map(),
          key: binary(),
          metadata: map(),
          change_vector: binary(),
          original_value: map()
        }

  @doc """
  Upserts a document in the informed session state

  ## Parameters
  - session_state: the session to be updated
  - document: the document to be upserted

  ## Returns
  - `{:error, :document_is_null}` if the document is not informed
  - `Ravix.Documents.Session.SessionDocument` if the session was updated correctly
  """
  @spec upsert_document(State.t(), nil | map) ::
          nil | {:error, :document_is_null} | SessionDocument.t()
  def upsert_document(_session_state, nil), do: {:error, :document_is_null}

  def upsert_document(session_state, document) when is_map_key(document, "@id") do
    upsert_document(session_state, document["@id"], document)
  end

  def upsert_document(session_state, document) when is_map_key(document, "@metadata") do
    document_metadata = document["@metadata"]
    document_without_metadata = Map.drop(document, ["@metadata"])

    case State.fetch_document(session_state, document_metadata["@id"]) do
      {:ok, existing_document} ->
        %SessionDocument{
          existing_document
          | entity: document_without_metadata,
            key: document["@id"],
            metadata: document_metadata,
            change_vector: document_metadata["@change-vector"],
            original_value: existing_document.entity
        }

      _ ->
        %SessionDocument{
          key: document_metadata["@id"],
          entity: document_without_metadata,
          metadata: document_metadata,
          change_vector: document_metadata["@change-vector"]
        }
    end
  end

  @doc """
  Upserts a document in the informed session state

  ## Parameters
  - session_state: the session to be updated
  - document_id: the key of the document to be upserted
  - metadata: The metadata of the document

  ## Returns
  - `{:error, :document_is_null}` if the document is not informed
  - `Ravix.Documents.Session.SessionDocument` if the session was updated correctly
  """
  @spec upsert_document(State.t(), any, any) :: nil | SessionDocument.t()
  def upsert_document(session_state, document_id, metadata) do
    case State.fetch_document(session_state, document_id) do
      {:ok, existing_document} ->
        updated_document = Metadata.add_metadata(existing_document.entity, metadata)

        %SessionDocument{
          existing_document
          | change_vector: metadata["@change-vector"],
            key: document_id,
            entity: updated_document,
            metadata: metadata,
            original_value: existing_document.entity
        }

      _ ->
        %SessionDocument{
          key: document_id,
          entity: nil,
          metadata: metadata,
          change_vector: metadata["@change-vector"]
        }
    end
  end
end
