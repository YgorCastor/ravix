defmodule Ravix.Documents.Commands.Data.PutDocument do
  @derive {Jason.Encoder, only: [:Id, :Document, :ChangeVector, :Type]}
  defstruct Id: nil,
            Document: nil,
            ChangeVector: nil,
            Type: "PUT"

  alias Ravix.Documents.Commands.Data.PutDocument

  @type t :: %PutDocument{
          Id: binary(),
          Document: map(),
          ChangeVector: String.t(),
          Type: String.t()
        }
end
