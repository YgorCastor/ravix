defmodule Ravix.Connection.RequestExecutor do
  use GenServer

  alias Ravix.Connection.RequestExecutor.State

  def init(state = %State{}) do
    {:ok, state}
  end
end
