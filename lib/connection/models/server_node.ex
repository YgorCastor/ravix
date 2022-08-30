defmodule Ravix.Connection.ServerNode do
  @moduledoc """
  State of a RavenDB connection executor node

      - store: Atom of the RavenDB Store, E.g: Ravix.Test.Store
      - url: URL of this node
      - port: port of this node
      - conn: TCP Connection State
      - protocol: http or https
      - database: For which database is this executor
      - cluster_tag: Tag of this node in the RavenDB cluster
      - adapter: Tesla Adapter
      - settings: General node settings
  """
  defstruct store: nil,
            url: nil,
            port: nil,
            client: nil,
            protocol: nil,
            database: nil,
            cluster_tag: nil,
            adapter: Tesla.Adapter.Hackney,
            settings: nil

  alias Ravix.Connection.ServerNode
  alias Ravix.Connection.State, as: ConnectionState

  @type t :: %ServerNode{
          store: atom(),
          url: String.t(),
          port: non_neg_integer(),
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil,
          adapter: Tesla.Adapter,
          settings: ServerNode.Settings.t()
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
        database: conn_state.database,
        adapter: conn_state.adapter,
        settings: ServerNode.Settings.build(conn_state)
      }
    end)
  end

  def from_api_response(node_response, conn_state = %ConnectionState{}) do
    parsed_url = URI.new!(node_response["Url"])

    %ServerNode{
      store: conn_state.store,
      url: parsed_url.host,
      port: parsed_url.port,
      protocol: String.to_atom(parsed_url.scheme),
      database: node_response["Database"],
      cluster_tag: node_response["ClusterTag"],
      adapter: conn_state.adapter,
      settings: ServerNode.Settings.build(conn_state)
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

  defmodule Settings do
    @moduledoc """
     - retry_on_failure: Automatic retry in retryable errors
     - retry_on_stale: Automatic retry when the query is stale
     - retry_backoff: Amount of time between retries (in ms)
     - retry_count: Amount of retries
     - allow_stale_indexes: Indexes that can be stale queried
    """
    defstruct retry_on_failure: true,
              retry_on_stale: true,
              retry_backoff: 500,
              retry_count: 3,
              max_url_length: 1024,
              allowed_stale_indexes: []

    alias __MODULE__

    @type t :: %__MODULE__{
            retry_on_failure: boolean(),
            retry_on_stale: boolean(),
            retry_backoff: non_neg_integer(),
            retry_count: non_neg_integer(),
            max_url_length: non_neg_integer(),
            allowed_stale_indexes: list(String.t())
          }

    def build(conn_state) do
      %Settings{
        retry_on_failure: conn_state.retry_on_failure,
        retry_on_stale: conn_state.retry_on_stale,
        retry_backoff: conn_state.retry_backoff,
        retry_count: conn_state.retry_count,
        max_url_length: conn_state.conventions.max_length_of_query_using_get_url,
        allowed_stale_indexes: conn_state.conventions.allowed_stale_indexes
      }
    end
  end
end
