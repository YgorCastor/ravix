defmodule Ravix.Documents.Commands.Data.DeleteDocument do
  @derive {Jason.Encoder, only: [:Id, :ChangeVector, :Type]}
  defstruct Id: nil,
            ChangeVector: nil,
            Type: "DELETE"

  alias Ravix.Documents.Commands.Data.DeleteDocument

  @type t :: %DeleteDocument{
          Id: binary(),
          ChangeVector: String.t(),
          Type: String.t()
        }
end
