defmodule Ravix.Connection.ServerNode do
  @moduledoc """
  State of a RavenDB connection executor node

      - store: Atom of the RavenDB Store, E.g: Ravix.Test.Store
      - url: URL of this node
      - port: port of this node
      - conn: TCP Connection State
      - ssl_config: User SSL certificate config for this node
      - protocol: http or https
      - database: For which database is this executor
      - cluster_tag: Tag of this node in the RavenDB cluster
      - min_pool_size: Minimum amount of parallel connections to the node
      - max_pool_size: Maximum amount of parallel connections to the node
      - timeout: Maximum amount of time to wait for a execution (in ms)
      - opts: General node Options
  """
  defstruct store: nil,
            url: nil,
            port: nil,
            client: nil,
            ssl_config: nil,
            protocol: nil,
            database: nil,
            cluster_tag: nil,
            settings: nil

  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.State, as: ConnectionState

  @type t :: %ServerNode{
          store: atom(),
          url: String.t(),
          port: non_neg_integer(),
          ssl_config: Keyword.t() | nil,
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil
        }

  def bootstrap(conn_state = %ConnectionState{}) do
    conn_state.urls
    |> Enum.map(fn url ->
      parsed_url = URI.parse(url)

      %ServerNode{
        store: conn_state.store,
        url: parsed_url.host,
        port: parsed_url.port,
        protocol: String.to_atom(parsed_url.scheme),
        ssl_config: conn_state.ssl_config,
        database: conn_state.database,
        settings: ServerNode.Settings.build(conn_state)
      }
    end)
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

  defmodule Settings do
    @moduledoc """
     - retry_on_failure: Automatic retry in retryable errors
     - retry_on_stale: Automatic retry when the query is stale
     - retry_backoff: Amount of time between retries (in ms)
     - retry_count: Amount of retries
     - min_pool_size: Minimum pool size for the Http Pool
     - max_pool_size: Maximum pool size for the Http pool
    """
    defstruct retry_on_failure: true,
              retry_on_stale: true,
              retry_backoff: 500,
              retry_count: 3,
              min_pool_size: 1,
              max_pool_size: 10

    alias __MODULE__

    def build(conn_state) do
      %Settings{
        retry_on_failure: conn_state.retry_on_failure,
        retry_on_stale: conn_state.retry_on_stale,
        retry_backoff: conn_state.retry_backoff,
        retry_count: conn_state.retry_count
      }
    end
  end
end
