defmodule Ravix.Connection.Topology do
  defstruct etag: 0,
            nodes: []

  alias Ravix.Connection.Topology
  alias Ravix.Connection.ServerNode

  @type t :: %Topology{
          etag: integer(),
          nodes: list(ServerNode.t())
        }

  @spec cluster_tag_for_node(Topology.t(), String.t()) :: String.t() | nil
  def cluster_tag_for_node(%Topology{} = topology, url) do
    case topology.nodes |> Enum.find(fn node -> node.url == url end) do
      nil -> nil
      node -> node.cluster_tag
    end
  end
end
