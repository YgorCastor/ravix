defmodule Ravix.Connection.Network.State do
  defstruct database_name: nil,
            certificate: nil,
            certificate_file: nil,
            topology_etag: 0,
            conventions: nil,
            node_selector: nil,
            last_known_urls: [],
            disable_topology_updates: false,
            cluster_token: nil,
            topology_nodes: []

  alias Ravix.Connection.Network.State, as: NetworkState
  alias Ravix.Connection.Topology
  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.NodeSelector
  alias Ravix.Documents.Conventions

  @type t :: %NetworkState{
          database_name: String.t(),
          certificate: String.t() | nil,
          certificate_file: String.t() | nil,
          topology_etag: non_neg_integer(),
          conventions: Conventions.t(),
          node_selector: NodeSelector.t(),
          last_known_urls: list(String.t()),
          disable_topology_updates: boolean(),
          cluster_token: String.t() | nil,
          topology_nodes: Topology.t()
        }

  @spec initial_state([binary], binary, Conventions.t(), nil | binary) :: NetworkState.t()
  def initial_state(urls, database, %Conventions{} = conventions, certificate) do
    topology = initial_topology(urls, database)
    parsed_certificate = parse_certificate(certificate)

    %NetworkState{
      database_name: database,
      conventions: conventions,
      certificate: parsed_certificate[:castore],
      certificate_file: parsed_certificate[:castorefile],
      topology_etag: 0,
      topology_nodes: topology,
      node_selector: %NodeSelector{
        topology: topology,
        current_node_index: 0
      }
    }
  end

  @spec initial_topology(list(String.t()), String.t()) :: Topology.t()
  defp initial_topology(urls, database) do
    nodes = urls |> Enum.map(fn url -> ServerNode.from_url(url, database) end)

    %Topology{
      etag: -1,
      nodes: nodes
    }
  end

  @spec parse_certificate(String.t() | nil) :: [
          castore: binary() | nil,
          castorefile: binary() | nil
        ]
  defp parse_certificate(nil), do: [castore: nil, castorefile: nil]

  defp parse_certificate(certificate) do
    uri = URI.parse(certificate)

    case uri do
      %URI{path: nil} -> [castore: certificate, castorefile: nil]
      _ -> [castore: nil, castorefile: certificate]
    end
  end
end
