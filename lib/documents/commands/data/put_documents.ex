defmodule Ravix.Documents.Commands.Data.PutDocument do
  @derive {Jason.Encoder, only: [:Id, :Document, :Type]}
  defstruct Id: nil,
            Document: nil,
            Type: "PUT"
end
