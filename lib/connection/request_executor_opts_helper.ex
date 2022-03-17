defmodule Ravix.Connection.RequestExecutorHelper do
  alias Ravix.Documents.Store.State, as: StoreState

  def parse_retry_options(%StoreState{} = store_state) do
    [
      should_retry: store_state.retry_on_failure,
      retry_backoff: store_state.retry_backoff,
      retry_count: store_state.retry_count
    ]
  end
end
