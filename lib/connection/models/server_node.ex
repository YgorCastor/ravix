defmodule Ravix.Connection.ServerNode do
  defstruct url: nil,
            port: nil,
            protocol: nil,
            database: nil,
            cluster_tag: nil

  alias Ravix.Connection.ServerNode

  @type t :: %ServerNode{
          url: String.t(),
          port: non_neg_integer(),
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil
        }

  @spec from_url(binary | URI.t(), String.t()) :: ServerNode.t()
  def from_url(url, database) do
    parsed_url = URI.new!(url)

    %ServerNode{
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
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
