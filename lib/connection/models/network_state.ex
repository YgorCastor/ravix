defmodule Ravix.Connection.Network.State do
  defstruct database_name: nil,
            certificate: nil,
            certificate_file: nil,
            conventions: nil,
            node_selector: nil,
            last_known_urls: [],
            disable_topology_updates: false,
            cluster_token: nil

  alias Ravix.Connection.Network.State, as: NetworkState

  alias Ravix.Connection.{
    NodeSelector,
    NetworkStateManager
  }

  alias Ravix.Documents.Conventions

  @type t :: %NetworkState{
          database_name: String.t(),
          certificate: String.t() | nil,
          certificate_file: String.t() | nil,
          conventions: Conventions.t(),
          node_selector: NodeSelector.t(),
          last_known_urls: list(String.t()),
          disable_topology_updates: boolean(),
          cluster_token: String.t() | nil
        }

  @spec initial_state([binary], binary, Conventions.t(), nil | binary) :: NetworkState.t()
  def initial_state(urls, database, %Conventions{} = conventions, certificate) do
    parsed_certificate = parse_certificate(certificate)

    topology =
      case NetworkStateManager.request_topology(urls, database, parsed_certificate) do
        {:ok, server_topology} -> server_topology
        _ -> raise "Invalid server topology"
      end

    %NetworkState{
      database_name: database,
      conventions: conventions,
      certificate: parsed_certificate[:castore],
      certificate_file: parsed_certificate[:castorefile],
      node_selector: %NodeSelector{
        topology: topology,
        current_node_index: 0
      },
      last_known_urls: urls
    }
  end

  defp parse_certificate(nil), do: [castore: nil, castorefile: nil]

  defp parse_certificate(certificate) do
    case URI.parse(certificate) do
      %URI{path: nil} -> [castore: certificate, castorefile: nil]
      _ -> [castore: nil, castorefile: certificate]
    end
  end
end
