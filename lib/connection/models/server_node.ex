defmodule Ravix.Connection.ServerNode do
  @moduledoc """
  State of a RavenDB connection executor node

      - store: Atom of the RavenDB Store, E.g: Ravix.Test.Store
      - url: URL of this node
      - port: port of this node
      - conn: TCP Connection State
      - ssl_config: User SSL certificate config for this node
      - requests: Currently executing request calls to RavenDB
      - protocol: http or https
      - database: For which database is this executor
      - cluster_tag: Tag of this node in the RavenDB cluster
      - healthcheck_every: Checks the node health every x seconds
      - timeout: Maximum amount of time to wait for a execution (in ms)
      - opts: General node Options
  """
  defstruct store: nil,
            url: nil,
            port: nil,
            conn: nil,
            ssl_config: nil,
            requests: %{},
            protocol: nil,
            database: nil,
            cluster_tag: nil,
            healthcheck_every: 60,
            timeout: 15000,
            state: :initializing,
            opts: []

  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.State, as: ConnectionState

  @type t :: %ServerNode{
          store: atom(),
          url: String.t(),
          port: non_neg_integer(),
          conn: Mint.HTTP.t() | nil,
          ssl_config: Keyword.t() | nil,
          requests: map(),
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil,
          healthcheck_every: non_neg_integer(),
          timeout: non_neg_integer(),
          state: :healthy | :unhealthy | :initializing,
          opts: keyword()
        }

  @doc """
    Creates a new node state from the url, database name and ssl certificate
  """
  @spec from_url(binary | URI.t(), ConnectionState.t()) :: ServerNode.t()
  def from_url(url, %ConnectionState{
        ssl_config: ssl_config,
        database: database,
        healthcheck_every: healthcheck_every
      }) do
    parsed_url = URI.new!(url)

    %ServerNode{
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
      ssl_config: ssl_config,
      healthcheck_every: healthcheck_every,
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

  @spec retry_on_stale?(ServerNode.t()) :: boolean()
  def retry_on_stale?(%ServerNode{} = node), do: Keyword.get(node.opts, :retry_on_stale, false)

  defimpl String.Chars, for: Ravix.Connection.ServerNode do
    def to_string(nil) do
      ""
    end

    def to_string(node) do
      "#{node.protocol}://#{node.url}:#{node.port}"
    end
  end
end
