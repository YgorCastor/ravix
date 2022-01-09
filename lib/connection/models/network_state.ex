defmodule Ravix.Connection.Network.State do
  defstruct database_name: nil,
            certificate: nil,
            topology_etag: nil,
            last_return_response: nil,
            conventions: nil,
            node_selector: nil,
            last_known_urls: nil,
            disable_topology_updates: nil,
            cluster_token: nil,
            topology_nodes: []

  alias Ravix.Connection.Network.State
  alias Ravix.Connection.Topology
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.NodeSelector
  alias Ravix.Documents.Conventions

  @type t :: %State{
          database_name: String.t(),
          certificate: String.t(),
          topology_etag: String.t(),
          last_return_response: non_neg_integer(),
          conventions: Conventions.t(),
          node_selector: NodeSelector.t(),
          last_known_urls: list(String.t()),
          disable_topology_updates: boolean(),
          cluster_token: String.t(),
          topology_nodes: Topology.t()
        }

  def initial_state(urls, database, conventions = %Conventions{}, certificate) do
    topology = initial_topology(urls, database)

    %State{
      database_name: database,
      conventions: conventions,
      certificate: certificate,
      topology_etag: 0,
      topology_nodes: topology,
      node_selector: %NodeSelector{
        topology: topology,
        current_node_index: 0
      }
    }
  end

  defp initial_topology(urls, database) when urls != [] do
    nodes = urls |> Enum.map(fn url -> ServerNode.from_url(url, database) end)

    %Topology{
      etag: -1,
      nodes: nodes
    }
  end
end
