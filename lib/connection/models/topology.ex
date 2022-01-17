defmodule Ravix.Connection.Topology do
  defstruct etag: 0,
            nodes: []

  alias Ravix.Connection.Topology
  alias Ravix.Connection.ServerNode

  @type t :: %Topology{
          etag: String.t(),
          nodes: list(ServerNode.t())
        }
end
