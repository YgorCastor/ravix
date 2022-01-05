defmodule Ravix.Documents.Store.State do
  defstruct urls: [],
            default_database: nil,
            document_conventions: nil,
            request_executors: []

  alias Ravix.Documents.Store.State
  alias Ravix.Documents.Conventions

  @type t :: %State{
          urls: list(String.t()),
          default_database: String.t(),
          document_conventions: Conventions.t(),
          request_executors: list(UUID.t())
        }
end
