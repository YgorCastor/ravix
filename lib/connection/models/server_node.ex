defmodule Ravix.Connection.ServerNode do
  @moduledoc """
  State of a RavenDB connection executor node

      - store: Atom of the RavenDB Store, E.g: Ravix.TestStore
      - url: URL of this node
      - port: port of this node
      - conn: TCP Connection State
      - certificate: User SSL certificate for this node
      - requests: Currently executing request calls to RavenDB
      - protocol: http or https
      - database: For which database is this executor
      - cluster_tag: Tag of this node in the RavenDB cluster
  """
  defstruct store: nil,
            url: nil,
            port: nil,
            conn: nil,
            certificate: nil,
            requests: %{},
            protocol: nil,
            database: nil,
            cluster_tag: nil

  alias Ravix.Connection.ServerNode

  @type t :: %ServerNode{
          store: atom(),
          url: String.t(),
          port: non_neg_integer(),
          conn: Mint.HTTP.t() | nil,
          certificate: map() | nil,
          requests: map(),
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil
        }

  @doc """
    Creates a new node state from the url, database name and ssl certificate
  """
  @spec from_url(binary | URI.t(), any, any) :: ServerNode.t()
  def from_url(url, database, certificate) do
    parsed_url = URI.new!(url)

    %ServerNode{
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
      certificate: certificate,
      database: database
    }
  end

  @doc """
    Create a new node state based on the RavenDB Topology response
  """
  @spec from_api_response(map) :: ServerNode.t()
  def from_api_response(node_response) do
    parsed_url = URI.new!(node_response["Url"])

    %ServerNode{
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
      database: node_response["Database"],
      cluster_tag: node_response["ClusterTag"]
    }
  end

  @doc """
    Helper method to build the url for Database specific API requests
  """
  @spec node_url(ServerNode.t()) :: String.t()
  def node_url(%ServerNode{} = server_node),
    do: "/databases/#{server_node.database}"

  defimpl String.Chars, for: Ravix.Connection.ServerNode do
    def to_string(nil) do
      ""
    end

    def to_string(node) do
      "#{node.protocol}://#{node.url}:#{node.port}"
    end
  end
end
