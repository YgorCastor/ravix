defmodule Ravix.Connection.RequestExecutor.Options do
  @moduledoc false
  alias Ravix.Connection.State, as: ConnectionState

  def from_connection_state(%ConnectionState{} = conn_state) do
    [
      {:retry_on_failure, conn_state.retry_on_failure},
      {:retry_on_stale, conn_state.retry_on_stale},
      {:retry_backoff, conn_state.retry_backoff},
      {:retry_count, conn_state.retry_count},
      {:max_length_of_query_using_get_url,
       conn_state.conventions.max_length_of_query_using_get_url}
    ]
  end
end
