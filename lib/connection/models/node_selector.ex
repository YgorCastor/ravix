defmodule Ravix.Connection.NodeSelector do
  defstruct topology: nil,
            current_node_index: nil

  alias Ravix.Connection.NodeSelector
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.Topology

  @type t :: %NodeSelector{
          topology: Topology.t(),
          current_node_index: non_neg_integer()
        }

  @spec current_node(Ravix.Connection.NodeSelector.t()) :: ServerNode.t()
  def current_node(node_selector = %NodeSelector{}) do
    node_selector.topology.nodes[node_selector.current_node_index]
  end
end
