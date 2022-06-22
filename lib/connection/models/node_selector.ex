defmodule Ravix.Connection.NodeSelector do
  @moduledoc false
  defstruct [:current_node_index]

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.RequestExecutor.Supervisor, as: ExecutorSupervisor

  @type t :: %NodeSelector{
          current_node_index: :counters.counters_ref()
        }

  @spec new :: NodeSelector.t()
  def new() do
    counter = :counters.new(1, [:atomics])
    :counters.put(counter, 1, 0)

    %NodeSelector{
      current_node_index: counter
    }
  end

  @doc """
    Fetches the current node in the cluster in a round-robin way

    Returns `pid` with the executor pid
  """
  @spec current_node(ConnectionState.t()) :: pid()
  def current_node(%ConnectionState{} = state) do
    current_nodes =
      ExecutorSupervisor.fetch_nodes(state.store)
      |> Enum.filter(fn {_pid, node} -> node.state == :healthy end)
      |> Enum.map(fn {pid, _node} -> pid end)

    if length(current_nodes) == 0 do
      raise "No nodes available to execute the request!"
    end

    counter = state.node_selector.current_node_index |> :counters.get(1)
    current_index = rem(counter, length(current_nodes))

    state.node_selector.current_node_index |> :counters.add(1, 1)

    Enum.at(current_nodes, current_index)
  end
end
