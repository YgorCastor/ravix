defmodule Ravix.Connection.NodeSelector do
  @moduledoc false
  defstruct [:current_node_index]

  alias Ravix.Connection.State, as: ConnectionState
  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.ServerNode
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
    Fetches the current node pool for the cluster in a round-robin way

    Returns the pool name
  """
  @spec current_node(ConnectionState.t()) :: {pid(), ServerNode.t()}
  def current_node(%ConnectionState{} = state) do
    current_nodes = ExecutorSupervisor.fetch_nodes(state.store)

    if length(current_nodes) == 0 do
      raise "No nodes available to execute the request!"
    end

    counter = state.node_selector.current_node_index |> :counters.get(1)
    current_index = rem(counter, length(current_nodes))

    state.node_selector.current_node_index |> :counters.add(1, 1)

    Enum.at(current_nodes, current_index)
  end

  @spec random_executor_for(atom()) :: {pid(), ServerNode.t()}
  def random_executor_for(store) do
    ExecutorSupervisor.fetch_nodes(store) |> Enum.random()
  end

  def node_id(node) do
    "#{node.url}.#{node.port}.#{node.database}"
  end
end
