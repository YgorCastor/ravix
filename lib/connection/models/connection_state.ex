defmodule Ravix.Connection.State do
  @moduledoc """
  Represents the state of a RavenDB connection

     - store: Store atom for this state. E.g: Ravix.Test.Store
     - database: Name of the database.
     - ssl_config: SSL Configurations, E.g: https://www.erlang.org/doc/man/ssl.html
     - conventions: Document Configuration conventions
     - retry_on_failure: Automatic retry in retryable errors
     - retry_on_stale: Automatic retry when the query is stale
     - retry_backoff: Amount of time between retries (in ms)
     - retry_count: Amount of retries
     - node_selector: Module that selects the nodes based on different strategies. E.g: Ravix.Connection.NodeSelector
     - urls: List of the urls of RavenDB servers
     - topology_etag: ETAG of the RavenDB cluster topology
     - disable_topology_updates: If true, the topology will not be updated automatically when requested by the ravendb server
     - force_create_database: If true, when the database does not exist, it will be created
     - last_topology_update: DateTime when the topology was last updated
     - cluster_token: Security Token for the members of the cluster
     - healthcheck_every: Checks the node health every x seconds
  """
  defstruct store: nil,
            database: nil,
            ssl_config: [],
            retry_on_failure: true,
            retry_on_stale: false,
            retry_backoff: 100,
            retry_count: 3,
            conventions: %Ravix.Documents.Conventions{},
            node_selector: nil,
            urls: [],
            topology_etag: nil,
            disable_topology_updates: false,
            force_create_database: false,
            last_topology_update: nil,
            healthcheck_every: 60,
            cluster_token: nil

  use Vex.Struct

  @type t :: %Ravix.Connection.State{
          store: any(),
          database: String.t(),
          ssl_config: Keyword.t(),
          retry_on_failure: boolean(),
          retry_on_stale: boolean(),
          retry_backoff: non_neg_integer(),
          retry_count: non_neg_integer(),
          conventions: Ravix.Documents.Conventions.t(),
          node_selector: Ravix.Connection.NodeSelector.t(),
          urls: list(String.t()),
          topology_etag: String.t() | nil,
          disable_topology_updates: boolean(),
          force_create_database: boolean(),
          last_topology_update: DateTime.t() | nil,
          healthcheck_every: non_neg_integer(),
          cluster_token: String.t() | nil
        }

  @spec validate_configs(Ravix.Connection.State.t()) ::
          {:error, list} | {:ok, Ravix.Connection.State.t()}
  def validate_configs(%Ravix.Connection.State{} = configs) do
    case Vex.valid?(configs) do
      true -> {:ok, configs}
      false -> {:error, Vex.errors(configs)}
    end
  end
end
