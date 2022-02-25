defmodule Ravix.Documents.Session.SessionDocument do
  defstruct entity: nil,
            key: nil,
            original_value: nil,
            change_vector: "",
            metadata: %{},
            original_metadata: %{}

  alias Ravix.Documents.Session.{State, SessionDocument}

  @type t :: %SessionDocument{
          entity: map(),
          key: binary(),
          original_metadata: map(),
          change_vector: binary(),
          metadata: map(),
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
            metadata: document_metadata,
            original_metadata: existing_document.metadata,
            original_value: existing_document.entity
        }

      _ ->
        %SessionDocument{
          key: document_metadata["@id"],
          entity: document_without_metadata,
          change_vector: document_metadata["@change-vector"],
          metadata: document_metadata
        }
    end
  end

  @spec upsert_document(State.t(), any, any) :: nil | SessionDocument.t()
  def upsert_document(session_state, document_id, document) do
    case State.fetch_document(session_state, document_id) do
      {:ok, existing_document} ->
        %SessionDocument{
          existing_document
          | change_vector: document["@change-vector"],
            key: document_id,
            metadata: %{
              "@change-vector": document["@change-vector"],
              "@collection": document["@collection"],
              "@id": document_id,
              "@last-modified": document["@last-modified"]
            },
            original_metadata: existing_document.metadata,
            original_value: existing_document.entity
        }

      _ ->
        %SessionDocument{
          key: document_id,
          entity: document,
          change_vector: document["@metadata"]["@change-vector"],
          metadata: document["@metadata"]
        }
    end
  end

  @spec merge_entity(SessionDocument.t()) :: map
  def merge_entity(%SessionDocument{} = session_document) do
    session_document.entity
    |> Map.put("@metadata", session_document.metadata)
    |> Morphix.stringmorphiform!()
  end
end
