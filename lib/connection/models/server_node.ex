defmodule Ravix.Connection.ServerNode do
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

  @spec node_url(ServerNode.t()) :: String.t()
  def node_url(%ServerNode{} = server_node),
    do: "/databases/#{server_node.database}"
end
