defmodule Ravix.Documents.Session.SessionDocument do
  defstruct entity: nil,
            key: nil,
            original_value: nil,
            change_vector: "",
            metadata: %{},
            original_metadata: %{}

  alias Ravix.Documents.Session.SessionDocument

  @type t :: %SessionDocument{
          entity: map(),
          key: binary(),
          original_metadata: map(),
          change_vector: binary(),
          metadata: map(),
          original_value: map()
        }

  @spec merge_entity(SessionDocument.t()) :: map
  def merge_entity(session_document = %SessionDocument{}) do
    session_document.entity
    |> Map.put("@metadata", session_document.metadata)
    |> Morphix.stringmorphiform!()
  end
end
