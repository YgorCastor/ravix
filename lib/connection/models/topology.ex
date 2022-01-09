defmodule Ravix.Connection.Topology do
  defstruct etag: nil,
            nodes: []

  alias Ravix.Connection.Topology
  alias Ravix.Connection.ServerNode

  @type t :: %Topology{
          etag: String.t(),
          nodes: list(ServerNode.t())
        }
end
