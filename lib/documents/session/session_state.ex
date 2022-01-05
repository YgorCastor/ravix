defmodule Ravix.Documents.Session.State do
  defstruct session_id: nil,
            database: nil,
            request_executor: nil,
            documents_by_id: [],
            included_documents_by_id: [],
            known_missing_ids: [],
            number_of_requests: 0

  alias Ravix.Documents.Session.State

  @type t :: %State{
          session_id: UUID.t(),
          database: String.t(),
          request_executor: UUID.t(),
          documents_by_id: list(String.t()),
          included_documents_by_id: list(String.t()),
          known_missing_ids: list(String.t()),
          number_of_requests: non_neg_integer()
        }

  @spec increment_request_count(State.t()) :: State.t()
  def increment_request_count(session_state = %State{}) do
    %State{
      session_state
      | number_of_requests: session_state.number_of_requests + 1
    }
  end
end
