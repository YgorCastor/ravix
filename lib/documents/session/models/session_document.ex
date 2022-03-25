defmodule Ravix.Documents.Session.SessionDocument do
  defstruct entity: nil,
            key: nil,
            original_value: nil,
            change_vector: ""

  alias Ravix.Documents.Session.{State, SessionDocument}
  alias Ravix.Documents.Metadata

  @type t :: %SessionDocument{
          entity: map(),
          key: binary(),
          change_vector: binary(),
          original_value: map()
        }

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
            change_vector: document_metadata["@change-vector"],
            original_value: existing_document.entity
        }


      _ ->
        %SessionDocument{
          key: document_metadata["@id"],
          entity: document_without_metadata,
          change_vector: document_metadata["@change-vector"]
        }
    end
  end

  @spec upsert_document(State.t(), any, any) :: nil | SessionDocument.t()
  def upsert_document(session_state, document_id, metadata) do
    case State.fetch_document(session_state, document_id) do
      {:ok, existing_document} ->
        {:ok, updated_document} = Metadata.add_metadata(existing_document.entity, metadata)

        %SessionDocument{
          existing_document
          | change_vector: metadata["@change-vector"],
            key: document_id,
            entity: updated_document,
            original_value: existing_document.entity
        }

      _ ->
        %SessionDocument{
          key: document_id,
          entity: metadata,
          change_vector: metadata["@metadata"]["@change-vector"]
        }
    end
  end
end
