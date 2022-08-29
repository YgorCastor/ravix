defmodule Ravix.Connection.State do
  @moduledoc """
  Represents the state of a RavenDB connection

     - store: Store atom for this state. E.g: Ravix.Test.Store
     - database: Name of the database.
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
  """
  defstruct store: nil,
            database: nil,
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
            cluster_token: nil,
            adapter: nil

  @type t :: %Ravix.Connection.State{
          store: any(),
          database: String.t(),
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
          cluster_token: String.t() | nil
        }
end
