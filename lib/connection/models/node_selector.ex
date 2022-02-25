defmodule Ravix.Connection.NodeSelector do
  defstruct topology: nil,
            current_node_index: 0

  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.Topology

  @type t :: %NodeSelector{
          topology: Topology.t(),
          current_node_index: non_neg_integer()
        }

  @spec current_node(NodeSelector.t()) :: ServerNode.t()
  def current_node(%NodeSelector{} = node_selector) do
    Enum.at(node_selector.topology.nodes, node_selector.current_node_index)
  end
end
