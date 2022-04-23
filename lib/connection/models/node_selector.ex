defmodule Ravix.Connection.NodeSelector do
  @moduledoc false
  defstruct current_node_index: 0

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.RequestExecutor.Supervisor, as: ExecutorSupervisor

  @type t :: %NodeSelector{
          current_node_index: non_neg_integer()
        }

  @doc """
    Fetch the current node for the informed connection

  Returns `pid` with the executor pid
  """
  @spec current_node(ConnectionState.t()) :: pid()
  def current_node(%ConnectionState{} = state) do
    Enum.at(ExecutorSupervisor.fetch_nodes(state.store), state.node_selector.current_node_index)
  end
end
