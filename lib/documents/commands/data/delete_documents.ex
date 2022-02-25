defmodule Ravix.Documents.Commands.Data.DeleteDocument do
  @derive {Jason.Encoder, only: [:Id, :Type]}
  defstruct Id: nil,
            Type: "DELETE"

  alias Ravix.Documents.Commands.Data.DeleteDocument

  @type t :: %DeleteDocument{
          Id: binary(),
          Type: String.t()
        }
end
