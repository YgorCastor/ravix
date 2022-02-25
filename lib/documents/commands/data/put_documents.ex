defmodule Ravix.Documents.Commands.Data.PutDocument do
  @derive {Jason.Encoder, only: [:Id, :Document, :Type]}
  defstruct Id: nil,
            Document: nil,
            Type: "PUT"

  alias Ravix.Documents.Commands.Data.PutDocument

  @type t :: %PutDocument{
    Id: binary(),
    Document: map(),
    Type: String.t()
  }
end
