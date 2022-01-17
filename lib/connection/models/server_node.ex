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
          cluster_tag: String.t()
        }

  def from_url(url, database) do
    parsed_url = URI.new!(url)

    %ServerNode{
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
      database: database
    }
  end

  def node_url(server_node = %ServerNode{}),
    do: "/databases/#{server_node.database}"
end
