defmodule Ravix.Documents.Commands.Data.DeleteDocument do
  @derive {Jason.Encoder, only: [:Id, :Type]}
  defstruct Id: nil,
            Type: "DELETE"
end
