defmodule Ravix.Documents.Session.SaveChangesData do
  defstruct deferredCommands: [],
            sessionCommands: [],
            entities: [],
            batchOptions: nil
end
