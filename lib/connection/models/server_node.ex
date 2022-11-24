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
      - settings: General node settings
  """
  defstruct store: nil,
            url: nil,
            port: nil,
            client: nil,
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
          protocol: atom(),
          database: String.t(),
          cluster_tag: String.t() | nil,
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
      settings: ServerNode.Settings.build(conn_state)
    }
  end

  @doc """
    Helper method to build the base path for Database specific API requests
  """
  @spec node_database_path(ServerNode.t()) :: String.t()
  def node_database_path(%ServerNode{} = server_node),
    do: "/databases/#{server_node.database}"

  @doc """
    Node host and port
  """
  @spec node_url(ServerNode.t()) :: String.t()
  def node_url(%ServerNode{} = node), do: "#{node.protocol}://#{node.url}:#{node.port}"

  defimpl String.Chars, for: Ravix.Connection.ServerNode do
    def to_string(nil) do
      ""
    end

    def to_string(node) do
      ServerNode.node_url(node)
    end
  end

  defmodule Settings do
    @moduledoc """
     - retry_on_failure: Automatic retry in retryable errors
     - retry_on_stale: Automatic retry when the query is stale
     - retry_backoff: Amount of time between retries (in ms)
     - retry_count: Amount of retries
     - http_client_name: Name of the Finch http client to use with this node,
     - not_allowed_stale_indexes: Indexes that cant be stale queried
     - stale_is_error: Treat stale as an error
    """
    defstruct retry_on_failure: true,
              retry_on_stale: true,
              retry_backoff: 500,
              retry_count: 3,
              http_client_name: Ravix.Finch,
              max_url_length: 1024,
              not_allowed_stale_indexes: [],
              stale_is_error: false

    alias __MODULE__

    @type t :: %__MODULE__{
            retry_on_failure: boolean(),
            retry_on_stale: boolean(),
            retry_backoff: non_neg_integer(),
            retry_count: non_neg_integer(),
            http_client_name: atom(),
            max_url_length: non_neg_integer(),
            not_allowed_stale_indexes: list(String.t()),
            stale_is_error: boolean()
          }

    def build(conn_state) do
      %Settings{
        retry_on_failure: conn_state.retry_on_failure,
        retry_on_stale: conn_state.retry_on_stale,
        retry_backoff: conn_state.retry_backoff,
        retry_count: conn_state.retry_count,
        http_client_name: conn_state.http_client_name,
        max_url_length: conn_state.conventions.max_length_of_query_using_get_url,
        not_allowed_stale_indexes: conn_state.conventions.not_allowed_stale_indexes,
        stale_is_error: conn_state.conventions.stale_is_error
      }
    end
  end
end
