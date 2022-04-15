defmodule Ravix.Connection.RequestExecutor.Options do
  alias Ravix.Connection.State, as: ConnectionState

  def from_connection_state(%ConnectionState{} = conn_state) do
    [
      {:retry_on_failure, conn_state.retry_on_failure},
      {:retry_on_stale, conn_state.retry_on_stale},
      {:retry_backoff, conn_state.retry_backoff},
      {:retry_count, conn_state.retry_count}
    ]
  end
end
